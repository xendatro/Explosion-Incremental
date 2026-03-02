-- HUDService (Client)
-- Keeps HUD TextLabels in sync with PlayerStatsService.
--
-- Two things can race: stat data arriving vs elements existing in the tree.
-- This handles both by keeping listeners alive at all times and re-syncing
-- whenever an element (re)appears (initial load, post-respawn PlayerGui reset).

local HUDService = {}

local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local EN                 = require(ReplicatedStorage.Classes.EternityNum)
local xenterface         = require(ReplicatedStorage.Frameworks.xenterface)
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)

-- ElementId → StatName.  Add new HUD labels here.
local HUD_LABELS = {
	Coins    = "Coins",
	Strength = "Strength",
	Gems     = "Gems",
}

-- Strips fractional part when EN.short returns a raw number with no unit suffix.
local function shortDisplay(value: any): string
	local s = tostring(EN.short(EN.convert(value)))
	if not s:match("%a") then
		s = tostring(math.floor(tonumber(s) or 0))
	end
	return s
end

-- Fetch the element fresh every call so we're never holding a stale reference.
local function updateLabel(elementId: string, value: any)
	local el = xenterface:Get(elementId)
	if not el then return end
	el.Text = shortDisplay(value)
end

-- ── Stat listeners — registered FIRST ─────────────────────────────────────────
-- Registered before any element scanning so we never miss AllStatsInit.
-- If the element doesn't exist yet, updateLabel is a no-op; the CollectionService
-- signal below will push the current value once the element appears.

for elementId, statName in HUD_LABELS do
	PlayerStatsService:OnStatChanged(statName, function(value)
		updateLabel(elementId, value)
	end)
end

-- ── Element appearance — sync on add/reappear ─────────────────────────────────
-- Fires on initial load AND whenever PlayerGui resets on respawn.
-- Reads the current stat at that moment; if stats haven't arrived yet, shows 0
-- briefly, which the OnStatChanged listener above will correct.

local function onElementAdded(obj: Instance)
	local elementId = obj:GetAttribute("ElementId") :: string?
	if not elementId then return end
	local statName = HUD_LABELS[elementId]
	if not statName then return end
	updateLabel(elementId, PlayerStatsService:GetStat(statName))
end

CollectionService:GetInstanceAddedSignal("Element"):Connect(onElementAdded)

for _, obj in CollectionService:GetTagged("Element") do
	onElementAdded(obj)
end

return HUDService
