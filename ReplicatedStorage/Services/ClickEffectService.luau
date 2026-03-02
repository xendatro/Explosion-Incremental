local ClickEffectService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClickEffectConfig = require(ReplicatedStorage.Configs.ClickEffectConfig)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MouseGui = PlayerGui:WaitForChild("MouseGui")
local MouseFrame = MouseGui:WaitForChild("Mouse")
local EmitterConfig = MouseFrame:WaitForChild("Emitter")
local EmitBindable = EmitterConfig:WaitForChild("Emit")

-- Emit particles at a specific GUI position (2D screen coordinates)
function ClickEffectService:EmitAtPosition(position: Vector2)
	if not position then
		warn("ClickEffectService:EmitAtPosition requires a Vector2 position")
		return
	end

	-- Check if service is enabled
	if not ClickEffectConfig.Enabled then
		return
	end

	-- Set the mouse frame position to where the click/tap happened (2D GUI position)
	MouseFrame.Position = UDim2.fromOffset(position.X, position.Y)

	-- Fire the Emit bindable with the configured count (wait for GUI to render)
	task.wait()
	EmitBindable:Fire(ClickEffectConfig.EmitCount)
end

-- Emit particles at the current mouse position
function ClickEffectService:EmitAtMouse()
	local mouse = LocalPlayer:GetMouse()
	local mousePos = Vector2.new(mouse.X, mouse.Y)
	self:EmitAtPosition(mousePos)
end

-- Update a specific config value at runtime
function ClickEffectService:UpdateConfig(key: string, value: any)
	if ClickEffectConfig[key] == nil then
		warn("ClickEffectService:UpdateConfig - Unknown config key:", key)
		return
	end

	ClickEffectConfig[key] = value
end

-- Get current config
function ClickEffectService:GetConfig()
	return ClickEffectConfig
end

-- Enable click effects
function ClickEffectService:Enable()
	ClickEffectConfig.Enabled = true
end

-- Disable click effects
function ClickEffectService:Disable()
	ClickEffectConfig.Enabled = false
end

-- AUTO-INITIALIZATION: Set up click and tap listeners
-- Desktop: Mouse clicks
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Only emit if not typing in a textbox or interacting with UI
	if gameProcessed then
		return
	end

	-- Handle mouse clicks
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		ClickEffectService:EmitAtPosition(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- Mobile: Touch taps
UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	-- Only emit if not interacting with UI
	if gameProcessed then
		return
	end

	-- Emit at each tap position
	for _, position in ipairs(touchPositions) do
		ClickEffectService:EmitAtPosition(position)
	end
end)

return ClickEffectService
