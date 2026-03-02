-- NotificationService (Server)
-- Sends notifications to a specific player or to all players.
--
-- Usage:
--   NotificationService:Message(target, notifType, title, body)
--   target:     Player instance  — sends to that player only
--               "All"            — sends to every connected player
--   notifType:  "Error" | "Info" | "Success"
--   title:      string
--   body:       string

local NotificationService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Communication setup ───────────────────────────────────────────────────────
-- Creates Communication/Notifications/ShowNotification if it doesn't exist yet.
-- The client NotificationService watches for this remote via WaitForChild.

local showEvent: RemoteEvent
do
	local comm   = ReplicatedStorage:WaitForChild("Communication")
	local folder = comm:FindFirstChild("Notifications")
	if not folder then
		folder        = Instance.new("Folder")
		folder.Name   = "Notifications"
		folder.Parent = comm
	end

	local existing = folder:FindFirstChild("ShowNotification")
	if existing then
		showEvent = existing :: RemoteEvent
	else
		showEvent        = Instance.new("RemoteEvent")
		showEvent.Name   = "ShowNotification"
		showEvent.Parent = folder
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Sends a notification to one player or all players.
--   target:    Player | "All"
--   notifType: "Error" | "Info" | "Success"
function NotificationService:Message(
	target:    Player | string,
	notifType: string,
	title:     string,
	body:      string
)
	if target == "All" then
		showEvent:FireAllClients(notifType, title, body)
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		showEvent:FireClient(target, notifType, title, body)
	else
		warn("NotificationService: invalid target —", tostring(target))
	end
end

return NotificationService
