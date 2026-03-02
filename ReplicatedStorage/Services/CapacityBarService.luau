-- CapacityBarService (Client)
-- Animates the carry-weight capacity bar when the player picks up / drops items.
-- Listens for CarryUpdate (fired by ItemSpawnService) and StatUpdated for
-- CarryKgLimit changes (fired by PlayerStatsService on upgrade).

local CapacityBarService = {}

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Configs.UpgradeConfig)
local xenterface    = require(ReplicatedStorage.Frameworks.xenterface)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Remotes ─────────────────────────────────────────────────────────────────
local ItemsComm       = ReplicatedStorage:WaitForChild("Communication"):WaitForChild("Items")
local CarryUpdateEvent = ItemsComm:WaitForChild("CarryUpdate") :: RemoteEvent

local StatsComm    = ReplicatedStorage:WaitForChild("Communication"):WaitForChild("Stats")
local StatUpdated  = StatsComm:WaitForChild("StatUpdated") :: RemoteEvent

-- ── Color constants ──────────────────────────────────────────────────────────
local COLOR_GREEN  = Color3.fromRGB(34, 197, 94)
local COLOR_YELLOW = Color3.fromRGB(250, 204, 21)
local COLOR_RED    = Color3.fromRGB(239, 68, 68)

-- ── TweenInfo presets ────────────────────────────────────────────────────────
local tiShow  = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local tiHide  = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local tiFill  = TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local tiColor = TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ── State ────────────────────────────────────────────────────────────────────
local isVisible     = false
local cachedWeight  = 0
local cachedMax     = 0
local cachedCount   = 0

-- GUI refs (re-acquired on each respawn)
local container: Frame?    = nil
local barFill: Frame?      = nil
local weightLabel: TextLabel? = nil
local percentLabel: TextLabel? = nil

-- Position-based show/hide (X > 1 = off-screen right)
local POS_SHOWN  = UDim2.new(0.94, 0, 0.5, 0)
local POS_HIDDEN = UDim2.new(1.08, 0, 0.5, 0)

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function lerpColor(pct: number): Color3
	if pct <= 0.5 then
		local t = pct / 0.5
		return COLOR_GREEN:Lerp(COLOR_YELLOW, t)
	else
		local t = (pct - 0.5) / 0.5
		return COLOR_YELLOW:Lerp(COLOR_RED, t)
	end
end

local function updateCapacityLabel(kgMax: number)
	local el = xenterface:Get("CarryCapacity")
	if not el then return end
	-- Show whole number if integer, one decimal otherwise
	if kgMax == math.floor(kgMax) then
		el.Text = tostring(math.floor(kgMax))
	else
		el.Text = string.format("%.1f", kgMax)
	end
end

local function acquireGui()
	local screenGui = PlayerGui:WaitForChild("CapacityBarGui", 10)
	if not screenGui then
		warn("CapacityBarService: CapacityBarGui not found")
		return false
	end
	container    = screenGui:WaitForChild("CapacityBarContainer") :: Frame
	local barBg  = container:WaitForChild("BarBackground") :: Frame
	barFill      = barBg:WaitForChild("BarFill") :: Frame
	weightLabel  = container:WaitForChild("WeightLabel") :: TextLabel
	percentLabel = container:WaitForChild("PercentLabel") :: TextLabel

	-- Start off-screen
	container.Position = POS_HIDDEN
	isVisible = false
	return true
end

local function showBar()
	if isVisible or not container then return end
	isVisible = true
	TweenService:Create(container, tiShow, {
		Position = POS_SHOWN,
	}):Play()
end

local function hideBar()
	if not isVisible or not container then return end
	isVisible = false
	TweenService:Create(container, tiHide, {
		Position = POS_HIDDEN,
	}):Play()
end

local function updateBar(currentWeight: number, maxWeight: number, itemCount: number)
	if not container or not barFill or not weightLabel or not percentLabel then return end

	local pct = if maxWeight > 0 then math.clamp(currentWeight / maxWeight, 0, 1) else 0

	-- Always update fill, color, and text — even when hiding
	TweenService:Create(barFill, tiFill, {
		Size = UDim2.new(1, 0, pct, 0),
	}):Play()

	TweenService:Create(barFill, tiColor, {
		BackgroundColor3 = lerpColor(pct),
	}):Play()

	weightLabel.Text  = string.format("%.1f / %.1f kg", currentWeight, maxWeight)
	percentLabel.Text = string.format("%d%%", math.floor(pct * 100))

	-- Show / hide based on item count
	if itemCount > 0 then
		showBar()
	else
		hideBar()
	end
end

-- ── Acquire GUI on first load ────────────────────────────────────────────────
task.spawn(function()
	acquireGui()
end)

-- ── Initialize capacity label from current stat ─────────────────────────────
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)
PlayerStatsService:OnStatChanged("CarryKgLimit", function(value)
	local kgMax = UpgradeConfig.CarryKgLimit.Value(value)
	updateCapacityLabel(kgMax)
end)

-- Set initial value if stats are already loaded
task.defer(function()
	local level = PlayerStatsService:GetStat("CarryKgLimit")
	if level and level > 0 then
		local kgMax = UpgradeConfig.CarryKgLimit.Value(level)
		cachedMax = kgMax
		updateCapacityLabel(kgMax)
	end
end)

-- ── CarryUpdate from server ─────────────────────────────────────────────────
CarryUpdateEvent.OnClientEvent:Connect(function(currentWeight: number, maxWeight: number, itemCount: number)
	cachedWeight = currentWeight
	cachedMax    = maxWeight
	cachedCount  = itemCount
	updateBar(currentWeight, maxWeight, itemCount)
	updateCapacityLabel(maxWeight)
end)

-- ── StatUpdated: react to CarryKgLimit upgrades ─────────────────────────────
StatUpdated.OnClientEvent:Connect(function(statName: string, value: any)
	if statName ~= "CarryKgLimit" then return end
	local newMax = UpgradeConfig.CarryKgLimit.Value(value)
	cachedMax = newMax
	updateBar(cachedWeight, cachedMax, cachedCount)
	updateCapacityLabel(newMax)
end)

-- ── Respawn: re-acquire GUI refs ─────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function()
	task.spawn(function()
		acquireGui()
	end)
end)

return CapacityBarService
