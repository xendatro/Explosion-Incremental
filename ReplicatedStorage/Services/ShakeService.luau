local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraShaker = require(ReplicatedStorage.Classes.CameraShaker)

local Camera = workspace.CurrentCamera

local function ShakeCamera(shakeCf)
	-- shakeCf: CFrame value that represents the offset to apply for shake effect.
	-- Apply the effect:
	Camera.CFrame = Camera.CFrame * shakeCf
end

-- Create CameraShaker instance:
local renderPriority = Enum.RenderPriority.Camera.Value + 1
local camShake = CameraShaker.new(renderPriority, ShakeCamera)

-- Start the instance:

local Preset = {
	Scare = function()
		local scare do
			scare = CameraShaker.CameraShakeInstance.new(3, 20, 0, 1.5)
			scare.PositionInfluence = Vector3.new(1, 1, 1)
			scare.RotationInfluence = Vector3.new(1, 1, 1)
		end
		return scare
	end,
	Small = function()
		local small do
			small = CameraShaker.CameraShakeInstance.new(1, 5, 0, 1.5)
			small.PositionInfluence = Vector3.new(0.1, 0.1, 0.1)
			small.RotationInfluence = Vector3.new(1, 1, 1)
		end
		return small
	end,
	Jumpscare = function()
		local scare do
			scare = CameraShaker.CameraShakeInstance.new(2, 50, 0, 1.5)
			scare.PositionInfluence = Vector3.new(0.3, 0.3, 0)
			scare.RotationInfluence = Vector3.new(0.5, 0.5, 0.5)
		end
		return scare
	end,
}

camShake:Start()

type ShakeData = {
	ID: string,
	ShakeType: "Once" | "Sustained",
	Preset: string
}

local Rumble = {}
Rumble.__index = Rumble

function Rumble.new(start: number)
	local self = setmetatable({}, Rumble)
	
	self.Value = start
	local rumble do
		rumble = CameraShaker.CameraShakeInstance.new(self.Value, 20, 0, 1.5)
		rumble.PositionInfluence = Vector3.new(0.1, 0.1, 0.1)
		rumble.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)
	end
	self.Shake = rumble
	
	self:Start()
	
	return self
end

function Rumble:Start()
	camShake:ShakeSustain(self.Shake)
end

function Rumble:AdjustValue(newValue: number)
	self.Value = newValue
	self.Shake.Magnitude = self.Value*5
	self.Shake.PositionInfluence = Vector3.new(newValue/2, newValue/2, newValue/2)
end

function Rumble:Stop()
	self.Shake:StartFadeOut(0)
end

local ShakeService = {}

ShakeService.SustainedShakes = {}

local function shakeOnce(preset: string)
	camShake:Shake(Preset[preset]())
end

local function shakeSustained(id: string, preset: string)
	ShakeService.SustainedShakes[id] = camShake:ShakeSustain(Preset[preset])
end

function ShakeService:Create(shakeData: ShakeData)
	if shakeData.ShakeType == "Once" then
		shakeOnce(shakeData.Preset)
	elseif shakeData.ShakeType == "Sustained" then
		shakeSustained(shakeData.ID, shakeData.Preset)
	end
end

function ShakeService:Delete(ID: string)
	local instance = ShakeService.SustainedShakes[ID]
	if instance then
		instance:StartFadeOut(0)
	end
end

function ShakeService:CreateDynamicRumble(startValue: number)
	return Rumble.new(startValue)
end


return ShakeService