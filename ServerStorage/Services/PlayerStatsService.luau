local PlayerStatsService = {}

print("PlayerStatsService: loading")

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local SprintSpeedConfig = require(ReplicatedStorage.Configs.SprintSpeedConfig)
local EN                = require(ReplicatedStorage.Classes.EternityNum)

local commsStats  = ReplicatedStorage.Communication.Stats
local StatUpdated  = commsStats.StatUpdated  :: RemoteEvent
local AllStatsInit = commsStats.AllStatsInit :: RemoteEvent

-- ── Big-stat registry ──────────────────────────────────────────────────────────
-- These stats can grow without bound. They are stored as EternityNum in the cache
-- (EN tables) and persisted as EN strings ("Layer;Exp") in the DataStore.
-- All arithmetic must use EN.add/sub/mul/div. Display via EN.short().
-- Gems will be added here when they become big numbers.

local BIG_STATS: { [string]: true } = {
	Coins    = true,
	Strength = true,
}

-- Flat stats tracked at runtime (synced to client via StatUpdated / AllStatsInit)
local STAT_NAMES = { "Coins", "Strength", "Gems", "ExploderLevel", "GymLevel", "SprintSpeedLevel", "CarryKgLimit", "MaxBiomeUnlocked" }

-- { [Player]: { [string]: EN | number } }
local cache: { [Player]: { [string]: any } } = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function applyWalkSpeed(player: Player, level: number)
	local speed = SprintSpeedConfig[level] or SprintSpeedConfig[1]
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end
end

-- Sends the stat to the client. Big stats are sent as EN strings; small stats as numbers.
local function syncToClient(player: Player, statName: string, value: any)
	local payload = BIG_STATS[statName] and EN.toString(value) or value
	StatUpdated:FireClient(player, statName, payload)
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Returns an EN table for big stats, a plain number for small stats.
function PlayerStatsService:GetStat(player: Player, statName: string): any
	local data = cache[player]
	if not data then
		return BIG_STATS[statName] and EN.convert(0) or 0
	end
	return data[statName] or (BIG_STATS[statName] and EN.convert(0) or 0)
end

function PlayerStatsService:SetStat(player: Player, statName: string, value: any)
	local data = cache[player]
	if not data then return end

	local DataSaveService = require(ServerStorage.Services.DataSaveService)

	if BIG_STATS[statName] then
		local enVal = EN.convert(value)
		data[statName] = enVal

		-- Persist as string
		local profile = DataSaveService:Get(player)
		if profile then
			profile.Data[statName] = EN.toString(enVal)
		end

		-- Side effect: coins leaderboard
		if statName == "Coins" then
			local LeaderboardService = require(ServerStorage.Services.LeaderboardService)
			LeaderboardService:SetCoins(player, enVal)
		end

		syncToClient(player, statName, enVal)
	else
		data[statName] = value

		local profile = DataSaveService:Get(player)
		if profile then
			profile.Data[statName] = value
		end

		-- Side effect: sprint speed
		if statName == "SprintSpeedLevel" then
			applyWalkSpeed(player, value)
		end

		syncToClient(player, statName, value)
	end
end

function PlayerStatsService:IncrementStat(player: Player, statName: string, delta: any)
	local current = self:GetStat(player, statName)
	if BIG_STATS[statName] then
		self:SetStat(player, statName, EN.add(current, delta))
	else
		self:SetStat(player, statName, current + delta)
	end
end

-- Atomically checks and deducts coins. Returns true on success.
function PlayerStatsService:DeductCoins(player: Player, amount: any): boolean
	local current = self:GetStat(player, "Coins")
	local cost    = EN.convert(amount)
	if EN.le(current, cost) then  -- current < cost → can't afford
		return false
	end
	self:SetStat(player, "Coins", EN.sub(current, cost))
	return true
end

-- Atomically checks and deducts Strength (EternityNum). Returns true on success.
function PlayerStatsService:DeductStrength(player: Player, amount: any): boolean
	local current = self:GetStat(player, "Strength")
	local cost    = EN.convert(amount)
	if EN.le(current, cost) then  -- current < cost → can't afford
		return false
	end
	self:SetStat(player, "Strength", EN.sub(current, cost))
	return true
end

-- ── Gem helpers ───────────────────────────────────────────────────────────────
-- Gems is a plain integer stat (in STAT_NAMES above). Use IncrementStat / GetStat
-- for reads and additions. DeductGems provides atomic check-and-deduct.

-- Atomically checks and deducts gems. Returns true on success.
function PlayerStatsService:DeductGems(player: Player, amount: number): boolean
	local current = self:GetStat(player, "Gems")
	if current < amount then return false end
	self:SetStat(player, "Gems", current - amount)
	return true
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	local DataSaveService = require(ServerStorage.Services.DataSaveService)
	local profile = DataSaveService:Wait(player)

	-- Populate cache. Big stats are converted from stored strings/numbers → EN tables.
	local data = {}
	for _, name in STAT_NAMES do
		if BIG_STATS[name] then
			-- EN.convert handles both legacy numbers (0) and stored strings ("1;6")
			data[name] = EN.convert(profile.Data[name])
		else
			local v = profile.Data[name]
			-- Coerce legacy non-number values (e.g. old Gems = {}) to 0.
			-- All current small stats are plain integers; type check keeps them safe.
			data[name] = type(v) == "number" and v or 0
		end
	end
	cache[player] = data

	print(string.format(
		"PlayerStatsService: %s loaded — Strength=%s | Coins=%s | Gems=%s | GymLevel=%s",
		player.Name,
		EN.short(data.Strength),
		EN.short(data.Coins),
		tostring(data.Gems),
		tostring(data.GymLevel)
	))

	-- Apply sprint speed immediately
	applyWalkSpeed(player, data.SprintSpeedLevel)

	-- Re-apply sprint speed on each respawn
	player.CharacterAdded:Connect(function()
		applyWalkSpeed(player, cache[player] and cache[player].SprintSpeedLevel or 1)
	end)

	-- Send all flat stats to client.
	-- Big stats are serialised as EN strings; small stats (including Gems) as plain numbers.
	local initPayload = {}
	for k, v in data do
		initPayload[k] = BIG_STATS[k] and EN.toString(v) or v
	end
	AllStatsInit:FireClient(player, initPayload)
end)

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

return PlayerStatsService
