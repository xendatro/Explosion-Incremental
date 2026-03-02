local DialogueService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local xenterface = require(ReplicatedStorage.Frameworks.xenterface)

local TYPEWRITER_SPEED = 0.05 -- seconds per character

-- ElementIds — designer sets these as ElementId attributes in Studio
local NAME_ID = "DialogueName"
local TEXT_ID = "DialogueText"

-- Wait for remotes created by server DialogueService
local Communication = ReplicatedStorage:WaitForChild("Communication")
local DialogueFolder = Communication:WaitForChild("Dialogue")
local ShowRemote: RemoteEvent = DialogueFolder:WaitForChild("Show") :: RemoteEvent
local HideRemote: RemoteEvent = DialogueFolder:WaitForChild("Hide") :: RemoteEvent

-- Open the dialogue frame (fires all Pages in the "Dialogue" group with PageId "Main")
function DialogueService:Open()
	xenterface:Controller("Dialogue"):Fire("Main")
end

-- Close the dialogue frame (deactivates all Pages in the "Dialogue" group)
function DialogueService:Close()
	xenterface:Controller("Dialogue"):Fire("")
end

-- Set the name and text labels, typewriting the text via MaxVisibleGraphemes
local typewriterTween: Tween? = nil

function DialogueService:Set(name: string?, text: string?)
	local nameLabel = xenterface:Get(NAME_ID)
	local textLabel = xenterface:Get(TEXT_ID)

	if nameLabel and name then nameLabel.Text = name end

	if textLabel then
		-- Cancel any in-progress typewriter tween
		if typewriterTween then
			typewriterTween:Cancel()
			typewriterTween = nil
		end

		textLabel.Text = text
		textLabel.MaxVisibleGraphemes = 0

		local duration = utf8.len(text) * TYPEWRITER_SPEED
		typewriterTween = TweenService:Create(
			textLabel,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ MaxVisibleGraphemes = utf8.len(text) }
		)
		typewriterTween:Play()
	end
end

-- Open the frame, optionally setting name and text first
function DialogueService:Show(name: string?, text: string?)
	if name or text then
		self:Set(name, text)
	end
	self:Open()
end

-- Close the frame
function DialogueService:Hide()
	self:Close()
end

-- Register remote listeners (self-initialize)
ShowRemote.OnClientEvent:Connect(function(name: string, text: string)
	DialogueService:Show(name, text)
end)

HideRemote.OnClientEvent:Connect(function()
	DialogueService:Hide()
end)

return DialogueService
