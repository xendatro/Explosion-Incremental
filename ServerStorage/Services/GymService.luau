-- GymService (Server)
-- Handles manual click-training and autotrain loops.
-- Zone detection is entirely client-side; the server just processes events.

local GymService = {}

print("GymService: loading")

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local PlayerStatsService = require(ServerStorage.Services.PlayerStatsService)
local GymConfig          = require(ReplicatedStorage.Configs.GymConfig)
local UpgradeConfig      = require(ReplicatedStorage.Configs.UpgradeConfig)

local CommGym           = ReplicatedStorage.Communication:WaitForChild("Gym")
local GymClickEvent     = CommGym:WaitForChild("GymClick")     :: RemoteEvent
local SetAutotrainEvent = CommGym:WaitForChild("SetAutotrain") :: RemoteEvent

-- ── Per-player state ──────────────────────────────────────────────────────────

local lastClickTime  : { [Player]: number } = {}
local autotrainOn    : { [Player]: boolean } = {}
local autotrainThread: { [Player]: thread? } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getStrengthGain(player: Player): number
	local gymLevel = PlayerStatsService:GetStat(player, "GymLevel")
	return UpgradeConfig.GymLevel.Value(gymLevel)
end

-- ── Autotrain ─────────────────────────────────────────────────────────────────

local function stopAutotrain(player: Player)
	autotrainOn[player] = false
	autotrainThread[player] = nil
end

local function startAutotrain(player: Player)
	if autotrainThread[player] then return end
	autotrainOn[player] = true

	autotrainThread[player] = task.spawn(function()
		while autotrainOn[player] do
			task.wait(GymConfig.AutotrainInterval)
			if autotrainOn[player] then
				PlayerStatsService:IncrementStat(player, "Strength", getStrengthGain(player))
			end
		end
		autotrainThread[player] = nil
	end)
end

-- ── Remote handlers ───────────────────────────────────────────────────────────

GymClickEvent.OnServerEvent:Connect(function(player: Player)
	if player:GetAttribute("HoldingItem") then return end
	local now = tick()
	if (now - (lastClickTime[player] or 0)) < GymConfig.ClickDebounce then return end
	lastClickTime[player] = now

	local gain = getStrengthGain(player)
	print("GymService: click from", player.Name, "| GymLevel", PlayerStatsService:GetStat(player, "GymLevel"), "| gain", gain)
	PlayerStatsService:IncrementStat(player, "Strength", gain)
end)

SetAutotrainEvent.OnServerEvent:Connect(function(player: Player, enabled: boolean)
	if player:GetAttribute("HoldingItem") and enabled then return end
	if enabled then
		startAutotrain(player)
	else
		stopAutotrain(player)
	end
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	lastClickTime[player]   = 0
	autotrainOn[player]     = false
	autotrainThread[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
	stopAutotrain(player)
	lastClickTime[player]   = nil
	autotrainOn[player]     = nil
	autotrainThread[player] = nil
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

return GymService
