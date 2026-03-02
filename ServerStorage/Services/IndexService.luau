-- IndexService (Server)
-- Tracks every unique item name a player has ever exploded.
--
-- DataStore field: profile.Data.ItemIndex  { [itemName: string]: true }
-- A new entry is written the FIRST time a player explodes that item type.
-- Subsequent explosions of the same item are silently ignored.
--
-- Remotes (Communication/Index/):
--   IndexUpdated  (RemoteEvent)    → fires to the client with the new itemName
--                                     only when a truly new discovery is made
--   GetIndex      (RemoteFunction) → returns the full { [itemName]: true } table

local IndexService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local DataSaveService = require(ServerStorage.Services.DataSaveService)

-- ── Communication ─────────────────────────────────────────────────────────────

local commFolder
do
	local parent = ReplicatedStorage:WaitForChild("Communication")
	commFolder = parent:FindFirstChild("Index")
	if not commFolder then
		commFolder        = Instance.new("Folder")
		commFolder.Name   = "Index"
		commFolder.Parent = parent
	end
end

local function makeRE(name: string): RemoteEvent
	local e = commFolder:FindFirstChild(name)
	if e then return e :: RemoteEvent end
	local r      = Instance.new("RemoteEvent")
	r.Name       = name
	r.Parent     = commFolder
	return r
end

local function makeRF(name: string): RemoteFunction
	local e = commFolder:FindFirstChild(name)
	if e then return e :: RemoteFunction end
	local r      = Instance.new("RemoteFunction")
	r.Name       = name
	r.Parent     = commFolder
	return r
end

local REIndexUpdated = makeRE("IndexUpdated")
local RFGetIndex     = makeRF("GetIndex")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function countEntries(t: { [string]: any }): number
	local n = 0
	for _ in t do n += 1 end
	return n
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Records an item explosion for a player.
-- If itemName has not been seen before, it is added to their ItemIndex and
-- IndexUpdated fires on the client so UI can react to new discoveries.
function IndexService:Record(player: Player, itemName: string)
	if itemName == "" or itemName == "Unknown" or itemName == "Worker Item" then
		return  -- skip placeholder names
	end

	local profile = DataSaveService:Get(player)
	if not profile then return end

	local index = profile.Data.ItemIndex
	if index[itemName] then return end   -- already discovered

	index[itemName] = true

	local total = countEntries(index)
	print(string.format(
		"IndexService: %s discovered \"%s\" (%d unique item(s) total)",
		player.Name, itemName, total
	))

	-- Notify the client — future UI can show a "New discovery!" pop-up etc.
	REIndexUpdated:FireClient(player, itemName, total)
end

-- Returns the player's full ItemIndex table.
-- Used by the future Index UI to display discovered vs. undiscovered items.
function IndexService:GetIndex(player: Player): { [string]: true }
	local profile = DataSaveService:Get(player)
	if not profile then return {} end
	return profile.Data.ItemIndex
end

-- ── Remote handler ────────────────────────────────────────────────────────────

RFGetIndex.OnServerInvoke = function(player: Player)
	return IndexService:GetIndex(player)
end

return IndexService
