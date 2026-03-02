-- UpgradeBoardClass (Client Class)
-- Handles both UpgradeBoard variants (BoardType = "Plot" or "Player").
-- Clones the matching SurfaceGui, adorns it, wires buttons via xenterface,
-- and refreshes labels on stat changes.
--
-- ElementIds — PlotBoardGui:
--   ExploderUpgradeBtn / ExploderUpgradeMaxBtn / ExploderLevelLabel / ExploderCostLabel
--   GymUpgradeBtn      / GymUpgradeMaxBtn      / GymLevelLabel      / GymCostLabel
--   GymMultUpgradeBtn  / GymMultUpgradeMaxBtn  / GymMultLevelLabel  / GymMultCostLabel
-- ElementIds — PlayerBoardGui:
--   SpeedUpgradeBtn    / SpeedUpgradeMaxBtn    / SpeedLevelLabel    / SpeedCostLabel
--   CarryKgUpgradeBtn  / CarryKgUpgradeMaxBtn  / CarryKgLevelLabel  / CarryKgCostLabel
--   StrengthValueLabel (display only)

local UpgradeBoardClass = {}
UpgradeBoardClass.__index = UpgradeBoardClass
setmetatable(UpgradeBoardClass, { __index = require(game:GetService("ReplicatedStorage").Classes.BoardBase) })

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardBase              = require(ReplicatedStorage.Classes.BoardBase)
local UpgradeConfig          = require(ReplicatedStorage.Configs.UpgradeConfig)
local PlayerStatsService     = require(ReplicatedStorage.Services.PlayerStatsService)
local NotificationService    = require(ReplicatedStorage.Services.NotificationService)
local xenterface             = require(ReplicatedStorage.Frameworks.xenterface)
local EN                     = require(ReplicatedStorage.Classes.EternityNum)

-- ── Constants ─────────────────────────────────────────────────────────────────

local BOARD_GUI = {
	Plot   = "PlotBoardGui",
	Player = "PlayerBoardGui",
}

local UPGRADE_ELEMENTS = {
	ExploderLevel      = { btn = "ExploderUpgradeBtn",   maxBtn = "ExploderUpgradeMaxBtn",   level = "ExploderLevelLabel",   cost = "ExploderCostLabel"   },
	GymLevel           = { btn = "GymUpgradeBtn",        maxBtn = "GymUpgradeMaxBtn",        level = "GymLevelLabel",        cost = "GymCostLabel"        },
SprintSpeedLevel   = { btn = "SpeedUpgradeBtn",      maxBtn = "SpeedUpgradeMaxBtn",      level = "SpeedLevelLabel",      cost = "SpeedCostLabel"      },
	CarryKgLimit       = { btn = "CarryKgUpgradeBtn",    maxBtn = "CarryKgUpgradeMaxBtn",    level = "CarryKgLevelLabel",    cost = "CarryKgCostLabel"    },
}

local COLOR_BUY  = Color3.fromRGB(85, 255, 127)
local COLOR_POOR = Color3.fromRGB(255, 0, 0)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function setBtnText(btn: GuiButton, text: string)
	if btn:IsA("TextButton") then
		(btn :: TextButton).Text = text
	else
		local label = btn:FindFirstChildOfClass("TextLabel")
		if label then label.Text = text end
	end
end

local function applyBtnState(btnEl: GuiButton?, maxBtnEl: GuiButton?, singleText: string, maxText: string, _active: boolean, color: Color3)
	if btnEl then
		setBtnText(btnEl, singleText)
		btnEl.Active           = _active
		btnEl.AutoButtonColor  = _active
		btnEl.BackgroundColor3 = color
	end
	if maxBtnEl then
		setBtnText(maxBtnEl, maxText)
		maxBtnEl.Active           = _active
		maxBtnEl.AutoButtonColor  = _active
		maxBtnEl.BackgroundColor3 = color
	end
end

-- ── Constructor ───────────────────────────────────────────────────────────────

function UpgradeBoardClass.new(boardModel: Model)
	local boardType = boardModel:GetAttribute("BoardType") :: string?
	if not boardType or not BOARD_GUI[boardType] then return end

	local base = BoardBase.new(boardModel, BOARD_GUI[boardType])
	if not base then return end

	local self = setmetatable(base, UpgradeBoardClass)

	-- Remotes — fetched here inside the spawned constructor, not at module level.
	local CommUpgrades  = ReplicatedStorage.Communication:WaitForChild("Upgrades")
	local RFPurchase    = CommUpgrades:WaitForChild("PurchaseUpgrade")    :: RemoteFunction
	local RFMaxPurchase = CommUpgrades:WaitForChild("MaxPurchaseUpgrade") :: RemoteFunction

	-- ── Refresh ───────────────────────────────────────────────────────────────

	local function refreshEntry(upgradeType: string)
		local config = UpgradeConfig[upgradeType]
		local ids    = UPGRADE_ELEMENTS[upgradeType]
		if not config or not ids then return end

		local currentLevel = PlayerStatsService:GetStat(upgradeType) :: number
		local maxLevel     = config.MaxLevel
		local atMax        = maxLevel ~= nil and currentLevel >= maxLevel

		local levelEl  = xenterface:Get(ids.level)  :: TextLabel?
		local costEl   = xenterface:Get(ids.cost)   :: TextLabel?
		local btnEl    = xenterface:Get(ids.btn)    :: GuiButton?
		local maxBtnEl = xenterface:Get(ids.maxBtn) :: GuiButton?

		if levelEl then
			levelEl.Text = maxLevel
				and ("Level " .. currentLevel .. " / " .. maxLevel)
				or  ("Level " .. currentLevel)
		end

		if atMax then
			if costEl then costEl.Text = "MAX" end
			applyBtnState(btnEl, maxBtnEl, "MAX", "MAX", false, COLOR_BUY)
			return
		end

		local cost     = config.Cost(currentLevel)
		local currency = config.Currency or "Coins"

		-- Afford check — both Coins and Strength are big stats (EN).
		local balance   = PlayerStatsService:GetStat(currency)
		local canAfford = EN.meeq(balance, EN.convert(cost))

		if costEl then
			costEl.Text = "Cost: " .. EN.short(EN.convert(cost)) .. " " .. currency
		end
		applyBtnState(btnEl, maxBtnEl, "Buy", "Max", canAfford, canAfford and COLOR_BUY or COLOR_POOR)
	end

	local function refreshAll()
		for upgradeType in UPGRADE_ELEMENTS do
			refreshEntry(upgradeType)
		end
		if boardType == "Player" then
			local strengthEl = xenterface:Get("StrengthValueLabel") :: TextLabel?
			if strengthEl then
				strengthEl.Text = EN.short(PlayerStatsService:GetStat("Strength"))
			end
		end
	end

	-- ── Stat listeners ────────────────────────────────────────────────────────

	local REFRESH_STATS = { "Coins", "Strength", "ExploderLevel", "GymLevel", "SprintSpeedLevel", "CarryKgLimit" }
	for _, statName in REFRESH_STATS do
		PlayerStatsService:OnStatChanged(statName, refreshAll)
	end

	-- ── Button wiring ─────────────────────────────────────────────────────────

	local function tryWireButton(obj: Instance)
		if not obj:IsDescendantOf(self.Gui) then return end
		local elementId = obj:GetAttribute("ElementId") :: string?
		if not elementId then return end

		for upgradeType, ids in UPGRADE_ELEMENTS do
			if ids.btn == elementId then
				local btn = obj :: GuiButton
				btn.Activated:Connect(function()
					local config = UpgradeConfig[upgradeType]
					if not config then return end
					if config.MaxLevel and PlayerStatsService:GetStat(upgradeType) >= config.MaxLevel then return end
					btn.Active = false
					local result = RFPurchase:InvokeServer(upgradeType)
					if not (result and result.success) then btn.Active = true return end
					if upgradeType == "SprintSpeedLevel" then
						local newLevel = PlayerStatsService:GetStat("SprintSpeedLevel")
						local newSpeed = UpgradeConfig.SprintSpeedLevel.Value(newLevel)
						NotificationService:Message("Success", "Speed Upgraded", "Walk speed: " .. newSpeed)
					end
				end)
				return
			end
			if ids.maxBtn == elementId then
				local btn = obj :: GuiButton
				btn.Activated:Connect(function()
					local config = UpgradeConfig[upgradeType]
					if not config then return end
					if config.MaxLevel and PlayerStatsService:GetStat(upgradeType) >= config.MaxLevel then return end
					btn.Active = false
					local result = RFMaxPurchase:InvokeServer(upgradeType)
					if not (result and result.success) then btn.Active = true return end
					if upgradeType == "SprintSpeedLevel" then
						local newLevel = PlayerStatsService:GetStat("SprintSpeedLevel")
						local newSpeed = UpgradeConfig.SprintSpeedLevel.Value(newLevel)
						NotificationService:Message("Success", "Speed Upgraded", "Walk speed: " .. newSpeed)
					end
				end)
				return
			end
		end
	end

	self:AddConnection(CollectionService:GetInstanceAddedSignal("Element"):Connect(tryWireButton))
	for _, obj in CollectionService:GetTagged("Element") do
		tryWireButton(obj)
	end

	task.defer(refreshAll)
	return self
end

return UpgradeBoardClass
