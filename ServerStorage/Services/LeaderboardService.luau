local LeaderboardService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local EN = require(ReplicatedStorage.Classes.EternityNum)

-- Update a player's Coins leaderstats value.
-- Called by PlayerStatsService whenever Coins changes.
-- EN.toNumber() is used for leaderstats display (loses precision above ~1e308, but fine
-- for the Roblox leaderboard widget). A proper OrderedDataStore leaderboard should use
-- EN.lbencode() to preserve large-number ordering.
function LeaderboardService:SetCoins(player: Player, amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = EN.toNumber(EN.convert(amount))
	end
end

Players.PlayerAdded:Connect(function(player)
	local PlayerStatsService = require(ServerStorage.Services.PlayerStatsService)

	local leaderstats  = Instance.new("Folder")
	leaderstats.Name   = "leaderstats"

	local coins        = Instance.new("NumberValue")
	coins.Name         = "Coins"
	coins.Value        = EN.toNumber(PlayerStatsService:GetStat(player, "Coins"))
	coins.Parent       = leaderstats

	leaderstats.Parent = player
end)

return LeaderboardService
