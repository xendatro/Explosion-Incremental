-- StrengthEffectService (Client)
-- Plays strength-gained visual feedback when the player clicks in the gym.
--
--   1. Fires every particle emitter inside PlayerGui.TrainGui (multiple configs).
--   2. Spawns "+N" popup labels near the cursor that tween upward and fade out.
--
-- Usage (from GymService or any other client handler):
--   StrengthEffectService:Play(strengthAmount: number)

local StrengthEffectService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local EN = require(ReplicatedStorage.Classes.EternityNum)

local localPlayer = Players.LocalPlayer
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")
local mouse       = localPlayer:GetMouse()

-- ── Particle emitters (TrainGui) ──────────────────────────────────────────────
-- TrainGui mirrors the MouseGui pattern: a top-level Frame is repositioned to
-- the cursor, then all Emit BindableEvents inside it are fired (one per config).

local TrainGui = PlayerGui:WaitForChild("TrainGui")

-- ── Popup label templates ─────────────────────────────────────────────────────

local StrongTemplate = ReplicatedStorage:WaitForChild("Props")
	:WaitForChild("UI")
	:WaitForChild("StrengthStrong")

local WeakTemplate = ReplicatedStorage:WaitForChild("Props")
	:WaitForChild("UI")
	:WaitForChild("StrengthWeak")

-- Dedicated ScreenGui for popup labels — persists across respawns.
local popupGui = Instance.new("ScreenGui")
popupGui.Name           = "StrengthPopupGui"
popupGui.ResetOnSpawn   = false
popupGui.IgnoreGuiInset = true
popupGui.Parent         = PlayerGui

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Format a strength gain: integer for small values, EN.short for large ones.
local function formatGain(amount: number): string
	local s = tostring(EN.short(EN.convert(amount)))
	if not s:match("%a") then
		s = tostring(math.floor(tonumber(s) or 0))
	end
	return "+" .. s
end

-- ── Public API ────────────────────────────────────────────────────────────────

function StrengthEffectService:Play(strengthAmount: number)
	-- 1. Position the TrainGui's top-level Frame at the cursor and fire all emitters.
	task.spawn(function()
		local trainFrame = TrainGui:FindFirstChildWhichIsA("Frame")
		if trainFrame then
			trainFrame.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			task.wait() -- wait one frame for the position to apply
			for _, desc in trainFrame:GetDescendants() do
				if desc:IsA("BindableEvent") and desc.Name == "Emit" then
					desc:Fire(desc.Parent:GetAttribute("EmitCount") or 1)
				end
			end
		end
	end)

	-- 2. Spawn "+N" popup labels near the cursor.
	local baseX = mouse.X
	local baseY = mouse.Y - 25  -- start slightly above the cursor

	local labelText = formatGain(strengthAmount)

	-- Strong label (main, front).
	task.spawn(function()
		local offX  = math.random(-20, 20)
		local strong = StrongTemplate:Clone()
		strong.Text     = labelText
		strong.Position = UDim2.fromOffset(baseX + offX, baseY)
		strong.Visible  = true
		strong.Parent   = popupGui

		TweenService:Create(
			strong,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position             = UDim2.fromOffset(baseX + offX, baseY - 90),
				TextTransparency     = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}
		):Play()

		task.wait(0.75)
		strong:Destroy()
	end)

	-- Weak label (shadow/backdrop) — slight random delay and offset for variation.
	task.spawn(function()
		task.wait(math.random() * 0.1)

		local offX = math.random(-12, 12)
		local offY = math.random(-8, 8)
		local weak = WeakTemplate:Clone()
		weak.Text     = labelText
		weak.Position = UDim2.fromOffset(baseX + offX, baseY + offY)
		weak.Visible  = true
		weak.Parent   = popupGui

		TweenService:Create(
			weak,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position             = UDim2.fromOffset(baseX + offX, baseY + offY - 75),
				TextTransparency     = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}
		):Play()

		task.wait(0.8)
		weak:Destroy()
	end)
end

return StrengthEffectService
