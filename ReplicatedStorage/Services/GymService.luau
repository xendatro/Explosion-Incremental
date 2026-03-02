-- GymService (Client)
-- Handles zone detection, gym click/tap input, and the AutoTrain button.
--
-- Zone detection runs locally every 0.5s using GetPartsInPart.
-- Any click/tap while in zone fires GymClick to the server — no raycasting.
--
-- AutoTrain button:
--   Tag "Element" + attribute ElementId = "AutoTrainButton"
--   Shown/hidden via xenterface Controller("AutoTrainButton") Fire("Open"/"Close").
--   Red = off, Green = on.

local GymService = {}

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GymConfig             = require(ReplicatedStorage.Configs.GymConfig)
local UpgradeConfig         = require(ReplicatedStorage.Configs.UpgradeConfig)
local xenterface            = require(ReplicatedStorage.Frameworks.xenterface)
local PlayerStatsService    = require(ReplicatedStorage.Services.PlayerStatsService)
local StrengthEffectService = require(ReplicatedStorage.Services.StrengthEffectService)

local localPlayer = Players.LocalPlayer

local CommGym           = ReplicatedStorage.Communication:WaitForChild("Gym")
local GymClickEvent     = CommGym:WaitForChild("GymClick")     :: RemoteEvent
local SetAutotrainEvent = CommGym:WaitForChild("SetAutotrain") :: RemoteEvent

-- ── State ─────────────────────────────────────────────────────────────────────

local inZone          = false
local autotrainActive = false

local COLOR_DISABLED = Color3.fromRGB(200, 50, 50)
local COLOR_ENABLED  = Color3.fromRGB(50, 180, 50)

-- ── AutoTrain button ──────────────────────────────────────────────────────────

local autoTrainController = xenterface:Controller("AutoTrainButton")
local autoTrainBtn: GuiObject? = nil

local function wireAutoTrainButton(obj: GuiObject)
	if obj:GetAttribute("ElementId") ~= "AutoTrainButton" then return end
	autoTrainBtn = obj
	obj.BackgroundColor3 = COLOR_DISABLED

	obj.Activated:Connect(function()
		if not inZone then return end
		autotrainActive = not autotrainActive
		obj.BackgroundColor3 = autotrainActive and COLOR_ENABLED or COLOR_DISABLED
		SetAutotrainEvent:FireServer(autotrainActive)
	end)
end

-- Wire any buttons that appear after this script loads (including post-respawn).
CollectionService:GetInstanceAddedSignal("Element"):Connect(function(obj)
	wireAutoTrainButton(obj)
end)

-- Wire buttons already present.
for _, obj in CollectionService:GetTagged("Element") do
	wireAutoTrainButton(obj)
end

-- ── Zone change handler ───────────────────────────────────────────────────────

local function onZoneChanged(nowInZone: boolean)
	-- Never allow training while carrying an item.
	if nowInZone and (localPlayer:GetAttribute("HoldingItem") or false) then return end

	inZone = nowInZone

	if nowInZone then
		autoTrainController:Fire("Open")
		if autoTrainBtn then
			autoTrainBtn.BackgroundColor3 = autotrainActive and COLOR_ENABLED or COLOR_DISABLED
		end
	else
		if autotrainActive then
			autotrainActive = false
			if autoTrainBtn then autoTrainBtn.BackgroundColor3 = COLOR_DISABLED end
			SetAutotrainEvent:FireServer(false)
		end
		autoTrainController:Fire("Close")
	end
end

-- ── Zone detection loop ───────────────────────────────────────────────────────

local function isInAnyGymZone(): boolean
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	for _, gym in CollectionService:GetTagged("GymEquipment") do
		local zone = gym:FindFirstChild("Zone") :: BasePart?
		if zone then
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = { hrp }
			params.FilterType = Enum.RaycastFilterType.Include
			if #workspace:GetPartsInPart(zone, params) > 0 then
				return true
			end
		end
	end
	return false
end

local zoneLoopGen = 0

local function startZoneLoop()
	zoneLoopGen += 1
	local myGen = zoneLoopGen

	task.spawn(function()
		while zoneLoopGen == myGen do
			task.wait(GymConfig.ZoneCheckInterval)
			if zoneLoopGen ~= myGen then break end

			local nowInZone = isInAnyGymZone()
			if nowInZone ~= inZone then
				onZoneChanged(nowInZone)
			end
		end
	end)
end

-- Restart loop on each respawn
localPlayer.CharacterAdded:Connect(function()
	-- Reset controller state so the next Fire() is never skipped.
	autoTrainController.Active = nil
	inZone = false
	autotrainActive = false
	task.wait(1)
	startZoneLoop()
end)

-- Start immediately if character already exists
if localPlayer.Character then
	task.spawn(startZoneLoop)
end

-- When the player picks up or drops an item, update zone state immediately.
localPlayer:GetAttributeChangedSignal("HoldingItem"):Connect(function()
	local holding = localPlayer:GetAttribute("HoldingItem") or false
	if holding then
		-- Treat as leaving zone: hides autotrain button and stops autotrain.
		if inZone then onZoneChanged(false) end
	else
		-- Re-check whether they're still in the zone now that hands are free.
		local nowInZone = isInAnyGymZone()
		if nowInZone ~= inZone then
			onZoneChanged(nowInZone)
		end
	end
end)

-- ── Gym click / tap ───────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if not inZone then return end

	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	if not (isClick or isTouch) then return end

	GymClickEvent:FireServer()

	-- Play strength-gained effect immediately (optimistic — matches server award).
	local gymLevel = PlayerStatsService:GetStat("GymLevel")
	local gain     = UpgradeConfig.GymLevel.Value(gymLevel)
	StrengthEffectService:Play(gain)
end)

return GymService
