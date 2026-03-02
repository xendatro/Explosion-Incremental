local CurtainService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShowRemote: RemoteEvent = ReplicatedStorage.Communication.Curtain.Show
local HideRemote: RemoteEvent = ReplicatedStorage.Communication.Curtain.Hide
local PlayRemote: RemoteEvent = ReplicatedStorage.Communication.Curtain.Play

-- Show a curtain for a specific player
function CurtainService:Show(player: Player, pageId: string)
	ShowRemote:FireClient(player, pageId)
end

-- Show a curtain for all players
function CurtainService:ShowAll(pageId: string)
	ShowRemote:FireAllClients(pageId)
end

-- Hide the active curtain for a specific player
function CurtainService:Hide(player: Player)
	HideRemote:FireClient(player)
end

-- Hide the active curtain for all players
function CurtainService:HideAll()
	HideRemote:FireAllClients()
end

-- Show, wait, then hide for a specific player
function CurtainService:Play(player: Player, pageId: string, duration: number)
	PlayRemote:FireClient(player, pageId, duration)
end

-- Show, wait, then hide for all players
function CurtainService:PlayAll(pageId: string, duration: number)
	PlayRemote:FireAllClients(pageId, duration)
end

return CurtainService
