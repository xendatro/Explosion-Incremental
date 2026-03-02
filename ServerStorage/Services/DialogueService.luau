local DialogueService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShowRemote: RemoteEvent = ReplicatedStorage.Communication.Dialogue.Show
local HideRemote: RemoteEvent = ReplicatedStorage.Communication.Dialogue.Hide

-- Show dialogue to a specific player
function DialogueService:Show(player: Player, name: string, text: string)
	ShowRemote:FireClient(player, name, text)
end

-- Show dialogue to all players
function DialogueService:ShowAll(name: string, text: string)
	ShowRemote:FireAllClients(name, text)
end

-- Hide dialogue for a specific player
function DialogueService:Hide(player: Player)
	HideRemote:FireClient(player)
end

-- Hide dialogue for all players
function DialogueService:HideAll()
	HideRemote:FireAllClients()
end

return DialogueService
