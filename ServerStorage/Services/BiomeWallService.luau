-- BiomeWallService (Server)
-- Handles biome unlock purchases.
-- Biomes must be unlocked in order (can't skip).
-- Wall passthrough is handled client-side — this service only manages the stat.
--
-- Remotes (Communication/BiomeWalls/):
--   UnlockBiome  (RemoteFunction) Client → Server: biomeIndex → (success, errMsg?)
--   BiomeUnlocked (RemoteEvent)   Server → Client: biomeIndex — fires after success
--                                 Client uses this to trigger the unlock cutscene.

local BiomeWallService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local BiomeWallConfig      = require(ReplicatedStorage.Configs.BiomeWallConfig)
local PlayerStatsService   = require(ServerStorage.Services.PlayerStatsService)
local NotificationService  = require(ServerStorage.Services.NotificationService)

-- ── Communication ─────────────────────────────────────────────────────────────

local commFolder
do
	local parent = ReplicatedStorage:WaitForChild("Communication")
	commFolder = parent:FindFirstChild("BiomeWalls")
	if not commFolder then
		commFolder        = Instance.new("Folder")
		commFolder.Name   = "BiomeWalls"
		commFolder.Parent = parent
	end
end

local function makeRF(name: string): RemoteFunction
	local existing = commFolder:FindFirstChild(name)
	if existing then return existing :: RemoteFunction end
	local rf = Instance.new("RemoteFunction"); rf.Name = name; rf.Parent = commFolder
	return rf
end

local function makeRE(name: string): RemoteEvent
	local existing = commFolder:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local re = Instance.new("RemoteEvent"); re.Name = name; re.Parent = commFolder
	return re
end

local RFUnlockBiome   = makeRF("UnlockBiome")
local REBiomeUnlocked = makeRE("BiomeUnlocked")

-- ── Unlock handler ────────────────────────────────────────────────────────────

RFUnlockBiome.OnServerInvoke = function(player: Player, biomeIndex: number)
	-- Input validation
	if type(biomeIndex) ~= "number" then
		return false, "Invalid biome index"
	end

	biomeIndex = math.floor(biomeIndex)

	if biomeIndex < 2 or biomeIndex > BiomeWallConfig.MaxBiome then
		return false, "Biome index out of range"
	end

	-- Must unlock in order
	local current = PlayerStatsService:GetStat(player, "MaxBiomeUnlocked")
	if biomeIndex ~= current + 1 then
		if biomeIndex <= current then
			return false, "Already unlocked"
		end
		return false, "Must unlock previous biomes first"
	end

	-- Cost check and deduction
	local cost = BiomeWallConfig.UnlockCosts[biomeIndex]
	if not cost then
		return false, "No cost defined for biome " .. biomeIndex
	end

	if not PlayerStatsService:DeductCoins(player, cost) then
		NotificationService:Message(player, "Error", "Not Enough Coins", "You can't afford to unlock this biome.")
		return false, "Not enough coins"
	end

	-- Unlock
	PlayerStatsService:IncrementStat(player, "MaxBiomeUnlocked", 1)

	-- Notify client (for cutscene trigger)
	REBiomeUnlocked:FireClient(player, biomeIndex)

	local biomeName = BiomeWallConfig.BiomeNames[biomeIndex] or ("Biome " .. biomeIndex)
	NotificationService:Message(player, "Success", "Biome Unlocked", biomeName .. " is now accessible!")

	print(string.format("BiomeWallService: %s unlocked Biome %d (cost: %d coins)",
		player.Name, biomeIndex, cost))

	return true
end

return BiomeWallService
