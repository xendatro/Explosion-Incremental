-- NotificationService (Client)
-- Displays toast notifications at the top-centre of the screen.
--
-- NotificationGui lives in StarterGui (auto-replicates to PlayerGui).
-- NotificationCard template lives in RS.Props.UI — edit freely in Studio.
--
-- Per-type runtime changes (icon + bar colour only):
--   IconBg      (Frame)     — background colour set per type
--     IconLabel (TextLabel) — icon character + text colour set per type
--   ProgFill    (Frame)     — bar colour set per type
--
-- Everything else on the card stays exactly as designed in Studio.
--
-- Usage:
--   NotificationService:Message(notifType, title, body)
--   notifType: "Error" | "Info" | "Success"

local NotificationService = {}

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Templates ─────────────────────────────────────────────────────────────────
-- NotificationGui lives in StarterGui → auto-replicates to PlayerGui at runtime.
-- NotificationCard stays in RS.Props.UI so it can be freely edited in Studio.

local propsUI       = ReplicatedStorage:WaitForChild("Props"):WaitForChild("UI")
local CARD_TEMPLATE = propsUI:WaitForChild("NotificationCard")

-- ── Animation / timing constants ─────────────────────────────────────────────
-- Layout and sizing live in the Studio templates; only timing lives here.

local CARD_H      = 0.08125 -- scale height; must match template card Y size
local DISPLAY_DUR = 4     -- seconds before auto-dismiss
local MAX_ACTIVE  = 5

local T_IN       = 0.38
local T_OUT_FADE = 0.20
local T_OUT_SIZE = 0.26

-- Per-type accent colours and icon characters.
-- Colour tints: Accent bar, icon circle, icon text, progress fill, stroke.
local TYPES = {
	Error   = { color = Color3.fromRGB(239, 68,  68),  icon = "!" },
	Info    = { color = Color3.fromRGB(99,  102, 241), icon = "i" },
	Success = { color = Color3.fromRGB(34,  197, 94),  icon = "✓" },
}

-- ── GUI scaffold (from StarterGui → PlayerGui replication) ───────────────────

local screenGui = PlayerGui:WaitForChild("NotificationGui")
local container = screenGui:WaitForChild("Container") :: Frame

-- ── State ─────────────────────────────────────────────────────────────────────

local activeCount  = 0
local orderCounter = 1000000   -- decrement → newest card gets lowest order → top

-- ── TweenInfo presets ────────────────────────────────────────────────────────

local tiIn       = TweenInfo.new(T_IN,       Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local tiFade     = TweenInfo.new(T_OUT_FADE, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local tiSize     = TweenInfo.new(T_OUT_SIZE, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local tiProgress = TweenInfo.new(DISPLAY_DUR, Enum.EasingStyle.Linear)

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Snapshots every fadeable descendant's original transparency from the template,
-- then tweens between fully invisible (1) and the original value.
-- `alpha`: 0 = fully invisible, 1 = fully visible (template values).
type TransRecord = { obj: Instance, prop: string, original: number }

local function snapshotTransparencies(card: Frame): { TransRecord }
	local records: { TransRecord } = {}
	-- Include the card itself
	table.insert(records, { obj = card, prop = "BackgroundTransparency", original = card.BackgroundTransparency })
	for _, d in card:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(records, { obj = d, prop = "TextTransparency", original = d.TextTransparency })
		end
		if d:IsA("UIStroke") then
			table.insert(records, { obj = d, prop = "Transparency", original = d.Transparency })
		end
		if d:IsA("Frame") then
			table.insert(records, { obj = d, prop = "BackgroundTransparency", original = d.BackgroundTransparency })
		end
		if d:IsA("ImageLabel") then
			table.insert(records, { obj = d, prop = "BackgroundTransparency", original = d.BackgroundTransparency })
			table.insert(records, { obj = d, prop = "ImageTransparency", original = d.ImageTransparency })
		end
	end
	return records
end

local function fadeTo(records: { TransRecord }, ti: TweenInfo, alpha: number)
	for _, r in records do
		-- alpha 1 = original template value, alpha 0 = fully invisible (1)
		local target = r.original + (1 - r.original) * (1 - alpha)
		TweenService:Create(r.obj, ti, { [r.prop] = target }):Play()
	end
end

-- ── Card factory ──────────────────────────────────────────────────────────────

local function makeCard(notifType: string, title: string, body: string): (Frame, Frame?, { TransRecord })
	local data = TYPES[notifType] or TYPES.Info
	local col  = data.color
	local icon = data.icon

	orderCounter -= 1

	-- Clone the Studio-editable template
	local card = CARD_TEMPLATE:Clone()
	card.Name       = "NotifCard"
	card.LayoutOrder = orderCounter
	card.Size       = UDim2.new(1, 0, 0, 0)   -- scale height tweened from 0

	-- Only change icon + progress bar colour per type; everything else stays as-is from template
	local iconBg    = card:FindFirstChild("IconBg")        :: Frame?
	local iconLabel = iconBg and iconBg:FindFirstChild("IconLabel") :: TextLabel?
	local progTrack = card:FindFirstChild("ProgTrack")     :: Frame?
	local progFill  = progTrack and progTrack:FindFirstChild("ProgFill") :: Frame?

	if iconBg    then iconBg.BackgroundColor3         = col  end
	if iconLabel then iconLabel.TextColor3            = col
	                   iconLabel.Text                 = icon end
	if progFill  then progFill.BackgroundColor3       = col  end

	-- Set text content
	local titleLabel = card:FindFirstChild("Title") :: TextLabel?
	local bodyLabel  = card:FindFirstChild("Body")  :: TextLabel?
	if titleLabel then titleLabel.Text = title end
	if bodyLabel  then bodyLabel.Text  = body  end

	-- Snapshot original template transparencies, then start fully invisible
	local records = snapshotTransparencies(card)
	fadeTo(records, TweenInfo.new(0), 0) -- instant invisible
	card.Parent = container

	return card, progFill, records
end

-- ── Message ───────────────────────────────────────────────────────────────────

function NotificationService:Message(notifType: string, title: string, body: string)
	if activeCount >= MAX_ACTIVE then return end
	activeCount += 1

	task.spawn(function()
		local card, progFill, records = makeCard(notifType, title, body)

		-- ── Enter ────────────────────────────────────────────────────────────
		-- Height grows 0 → CARD_H.  ClipsDescendants reveals content top-down.
		-- UIListLayout reflows every frame, so existing cards slide down smoothly.
		TweenService:Create(card, tiIn, {
			Size = UDim2.new(1, 0, CARD_H, 0),
		}):Play()

		-- Give enter a head-start before fading in children (looks better)
		task.wait(T_IN * 0.25)
		fadeTo(records, tiIn, 1) -- fade to original template values

		task.wait(T_IN * 0.75)  -- wait out the rest of the enter tween

		-- ── Progress bar ─────────────────────────────────────────────────────
		if progFill then
			TweenService:Create(progFill, tiProgress, {
				Size = UDim2.new(0, 0, 1, 0),
			}):Play()
		end

		-- ── Auto-dismiss ─────────────────────────────────────────────────────
		local dismissed = false
		local function dismiss()
			if dismissed or not card.Parent then return end
			dismissed = true

			fadeTo(records, tiFade, 0) -- fade to fully invisible

			task.wait(T_OUT_FADE)

			local collapse = TweenService:Create(card, tiSize, {
				Size = UDim2.new(1, 0, 0, 0),
			})
			collapse:Play()
			collapse.Completed:Wait()

			card:Destroy()
			activeCount = math.max(0, activeCount - 1)
		end

		task.delay(DISPLAY_DUR, dismiss)
	end)
end

-- ── Remote listener ───────────────────────────────────────────────────────────

task.spawn(function()
	local comm   = ReplicatedStorage:WaitForChild("Communication")
	local folder = comm:WaitForChild("Notifications", 30)
	if not folder then
		warn("NotificationService: Communication/Notifications not found")
		return
	end
	local event = folder:WaitForChild("ShowNotification", 30) :: RemoteEvent?
	if not event then
		warn("NotificationService: ShowNotification remote not found")
		return
	end
	event.OnClientEvent:Connect(function(notifType: string, title: string, body: string)
		NotificationService:Message(notifType, title, body)
	end)
end)

return NotificationService
