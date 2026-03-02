-- UpgradeBoardService (Server)
-- Handles single and max upgrade purchases from the client.
--
-- PurchaseUpgrade:InvokeServer(upgradeType)
--   Returns { success: boolean, message: string }
--   Buys exactly one level.
--
-- MaxPurchaseUpgrade:InvokeServer(upgradeType)
--   Returns { success: boolean, levelsGained: number, message: string }
--   Calculates the maximum levels the player can afford in one shot (no round-trip loop),
--   deducts the total cost once, then increments the stat once.
--
-- Nil MaxLevel in UpgradeConfig = no cap; the level check is skipped.

local UpgradeBoardService = {}

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")

local UpgradeConfig       = require(ReplicatedStorage.Configs.UpgradeConfig)
local PlotService         = require(ServerStorage.Services.PlotService)
local PlayerStatsService  = require(ServerStorage.Services.PlayerStatsService)
local NotificationService = require(ServerStorage.Services.NotificationService)
local EN                  = require(ReplicatedStorage.Classes.EternityNum)

-- ── Communication ─────────────────────────────────────────────────────────────

local CommUpgrades = ReplicatedStorage.Communication:WaitForChild("Upgrades")

local function getOrMakeFunction(name: string): RemoteFunction
	local existing = CommUpgrades:FindFirstChild(name)
	if existing then return existing :: RemoteFunction end
	local rf  = Instance.new("RemoteFunction")
	rf.Name   = name
	rf.Parent = CommUpgrades
	return rf
end

local PurchaseUpgradeFunction    = getOrMakeFunction("PurchaseUpgrade")
local MaxPurchaseUpgradeFunction = getOrMakeFunction("MaxPurchaseUpgrade")

-- ── Currency router ───────────────────────────────────────────────────────────

local function deductCurrency(player: Player, config: any, cost: any): boolean
	if config.Currency == "Strength" then
		return PlayerStatsService:DeductStrength(player, cost)
	else
		return PlayerStatsService:DeductCoins(player, cost)
	end
end

local function currencyErrorMsg(config: any): string
	if config.Currency == "Strength" then
		return "Not enough Strength."
	else
		return "Not enough Coins."
	end
end

-- ── Shared validation ─────────────────────────────────────────────────────────

local function validate(player: Player, upgradeType: string): (any?, any?, string?)
	if type(upgradeType) ~= "string" then
		return nil, nil, "Invalid request."
	end
	local config = UpgradeConfig[upgradeType]
	if not config then
		return nil, nil, "Unknown upgrade type."
	end
	local plot = PlotService:GetPlotForPlayer(player)
	if not plot then
		return nil, nil, "No plot assigned."
	end
	return config, plot, nil
end

-- ── Single purchase ───────────────────────────────────────────────────────────

PurchaseUpgradeFunction.OnServerInvoke = function(player: Player, upgradeType: string)
	local config, _, err = validate(player, upgradeType)
	if err then return { success = false, message = err } end

	local currentLevel = PlayerStatsService:GetStat(player, upgradeType)

	-- nil MaxLevel = no cap.
	if config.MaxLevel and currentLevel >= config.MaxLevel then
		NotificationService:Message(player, "Error", "Max Level", upgradeType .. " is already at max level.")
		return { success = false, message = "Already at max level." }
	end

	if not deductCurrency(player, config, config.Cost(currentLevel)) then
		NotificationService:Message(player, "Error", "Not Enough " .. (config.Currency or "Coins"), "You can't afford this upgrade.")
		return { success = false, message = currencyErrorMsg(config) }
	end

	PlayerStatsService:IncrementStat(player, upgradeType, 1)
	NotificationService:Message(player, "Success", "Upgrade Purchased", upgradeType .. " is now level " .. (currentLevel + 1) .. "!")
	print(string.format("UpgradeBoardService: %s bought %s → level %d", player.Name, upgradeType, currentLevel + 1))

	return { success = true, message = "" }
end

-- ── Max purchase ──────────────────────────────────────────────────────────────
-- Calculates how many levels can be afforded up front, then applies in one shot:
-- one deduct call and one IncrementStat call (one StatUpdated fired).

local MAX_ITER = 500  -- safety cap; loops exit early when currency runs out

MaxPurchaseUpgradeFunction.OnServerInvoke = function(player: Player, upgradeType: string)
	local config, _, err = validate(player, upgradeType)
	if err then return { success = false, levelsGained = 0, message = err } end

	local startLevel = PlayerStatsService:GetStat(player, upgradeType)
	local currency   = PlayerStatsService:GetStat(player, config.Currency or "Coins")

	-- Accumulate cost level by level until we can't afford the next step.
	local totalCost   = EN.convert(0)
	local levelsGained = 0

	for i = 1, MAX_ITER do
		local lvl = startLevel + i - 1

		-- Respect cap if one is set.
		if config.MaxLevel and lvl >= config.MaxLevel then break end

		local newTotal = EN.add(totalCost, EN.convert(config.Cost(lvl)))

		-- Stop if currency < cumulative cost.
		if EN.le(currency, newTotal) then break end

		totalCost   = newTotal
		levelsGained += 1
	end

	if levelsGained == 0 then
		NotificationService:Message(player, "Error", "Not Enough " .. (config.Currency or "Coins"), "You can't afford any levels of " .. upgradeType .. ".")
		return { success = false, levelsGained = 0, message = "Cannot purchase." }
	end

	-- Atomic deduct (re-validates in case another request raced).
	if not deductCurrency(player, config, totalCost) then
		NotificationService:Message(player, "Error", "Not Enough " .. (config.Currency or "Coins"), "You can't afford this upgrade.")
		return { success = false, levelsGained = 0, message = currencyErrorMsg(config) }
	end

	PlayerStatsService:IncrementStat(player, upgradeType, levelsGained)
	NotificationService:Message(player, "Success", "Upgrade Purchased",
		upgradeType .. " +" .. levelsGained .. " → level " .. (startLevel + levelsGained) .. "!")
	print(string.format("UpgradeBoardService: %s max-bought %s ×%d", player.Name, upgradeType, levelsGained))

	return { success = true, levelsGained = levelsGained, message = "" }
end

return UpgradeBoardService
