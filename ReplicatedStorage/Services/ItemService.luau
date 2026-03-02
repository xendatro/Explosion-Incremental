-- ItemService (Client)
-- Manages the drop UI (xenterface) and fires DropItem to the server.

local ItemService = {}

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local xenterface = require(ReplicatedStorage.Frameworks.xenterface)

local ItemsComm     = ReplicatedStorage:WaitForChild("Communication"):WaitForChild("Items")
local DropItemEvent = ItemsComm:WaitForChild("DropItem") :: RemoteEvent

local localPlayer = Players.LocalPlayer

-- ── Drop button ───────────────────────────────────────────────────────────────
-- Re-wire the button every time a new DropItemButton element appears in PlayerGui.
-- This handles the PlayerGui reset that happens on each respawn.

local dropController = xenterface:Controller("DropItem")

local function wireDropButton(obj: GuiObject)
	if obj:GetAttribute("ElementId") ~= "DropItemButton" then return end
	obj.Activated:Connect(function()
		DropItemEvent:FireServer()
	end)
end

-- Connect any buttons that appear after this script loads.
CollectionService:GetInstanceAddedSignal("Element"):Connect(function(obj)
	wireDropButton(obj)
end)

-- Connect buttons already in the tree (e.g. loaded before this script).
for _, obj in CollectionService:GetTagged("Element") do
	wireDropButton(obj)
end

-- ── Show / hide drop UI via xenterface controller ─────────────────────────────
-- The server stamps HoldingItem = true/false on the player; we react here.

localPlayer:GetAttributeChangedSignal("HoldingItem"):Connect(function()
	local holding = localPlayer:GetAttribute("HoldingItem") or false
	if holding then
		dropController:Fire("Open")
	else
		dropController:Fire("Close")
	end
end)

-- On respawn the PlayerGui is rebuilt, so the controller's Active state is stale.
-- Reset it so the next Fire() call is never skipped.
localPlayer.CharacterAdded:Connect(function()
	dropController.Active = nil
end)

-- Pickup failure feedback now handled by NotificationService (server-side).

return ItemService
