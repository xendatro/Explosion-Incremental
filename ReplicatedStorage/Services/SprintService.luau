-- SprintService.luau (Client)
-- Toggles sprint on Shift press. ContextActionService adds a mobile button.
-- Sprint speed is determined by the SprintSpeedLevel upgrade.

local Players              = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

local UpgradeConfig      = require(ReplicatedStorage.Configs.UpgradeConfig)
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)

local localPlayer = Players.LocalPlayer
local isSprinting = false

local BASE_SPEED = 16  -- default WalkSpeed; also SprintSpeedLevel 1

local function getSprintSpeed(): number
	local level = PlayerStatsService:GetStat("SprintSpeedLevel")
	level = math.max(1, level or 1)
	return UpgradeConfig.SprintSpeedLevel.Value(level)
end

local function applySpeed(humanoid: Humanoid)
	humanoid.WalkSpeed = isSprinting and getSprintSpeed() or BASE_SPEED
end

local function getHumanoid(): Humanoid?
	local char = localPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

-- ContextActionService callback — toggle on Begin, ignore all other states.
local function onSprintAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState == Enum.UserInputState.Begin then
		isSprinting = not isSprinting
		local humanoid = getHumanoid()
		if humanoid then
			applySpeed(humanoid)
		end
	end
	-- Pass through so other systems still receive Shift (e.g. chat).
	return Enum.ContextActionResult.Pass
end

-- Rewire each time the character respawns (Humanoid is a new instance).
local function onCharacterAdded(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	-- Always start grounded after respawn.
	isSprinting = false
	applySpeed(humanoid)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- createButton = true adds an on-screen touch button for mobile players.
ContextActionService:BindAction(
	"Sprint",
	onSprintAction,
	true,  -- createButton (mobile)
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift
)

-- If the player upgrades SprintSpeedLevel while already sprinting, apply immediately.
PlayerStatsService:OnStatChanged("SprintSpeedLevel", function()
	if isSprinting then
		local humanoid = getHumanoid()
		if humanoid then
			applySpeed(humanoid)
		end
	end
end)

return {}
