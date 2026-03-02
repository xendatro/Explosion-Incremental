local CurtainService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local xenterface = require(ReplicatedStorage.Frameworks.xenterface)

-- Wait for remotes created by server CurtainService
local Communication = ReplicatedStorage:WaitForChild("Communication")
local CurtainFolder = Communication:WaitForChild("Curtain")
local ShowRemote: RemoteEvent = CurtainFolder:WaitForChild("Show") :: RemoteEvent
local HideRemote: RemoteEvent = CurtainFolder:WaitForChild("Hide") :: RemoteEvent
local PlayRemote: RemoteEvent = CurtainFolder:WaitForChild("Play") :: RemoteEvent

-- Show a curtain by pageId
function CurtainService:Show(pageId: string)
	xenterface:Controller("Curtain"):Fire(pageId)
end

-- Hide the active curtain
function CurtainService:Hide()
	xenterface:Controller("Curtain"):Fire("")
end

-- Show, wait duration, then hide
function CurtainService:Play(pageId: string, duration: number)
	self:Show(pageId)
	task.wait(duration)
	self:Hide()
end

-- Register remote listeners (self-initialize)
ShowRemote.OnClientEvent:Connect(function(pageId: string)
	CurtainService:Show(pageId)
end)

HideRemote.OnClientEvent:Connect(function()
	CurtainService:Hide()
end)

PlayRemote.OnClientEvent:Connect(function(pageId: string, duration: number)
	CurtainService:Play(pageId, duration)
end)

return CurtainService
