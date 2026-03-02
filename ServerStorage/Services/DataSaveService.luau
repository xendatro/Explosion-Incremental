local DataSaveService = {}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- When true: profiles are in-memory only. Nothing is saved or loaded from DataStore.
local DEV_MODE = true

local PROFILE_TEMPLATE = {
	-- Big stats are stored as EternityNum strings ("Layer;Exp").
	-- EN.convert() handles both string and legacy number values on load.
	Coins             = "0;0",
	Strength          = "0;0",
	ExploderLevel      = 1,
	GymLevel           = 1,
	SprintSpeedLevel   = 1,
	CarryKgLimit       = 1,
	MaxBiomeUnlocked   = 1,
	-- Single gem balance (plain integer; will migrate to EN string when counts grow large).
	Gems              = 0,
	-- Workers: array of NPC workers the player has purchased.
	-- Each entry: { StrengthLevel = 0, SpeedLevel = 0, AppearanceId = 0, DisplayName = "" }
	--   AppearanceId: UserId whose HumanoidDescription is applied to this worker's NPC (0 = default)
	--   DisplayName:  display name shown in the upgrade board UI
	-- Index = worker ID. Workers are never removed once purchased.
	Workers           = {},
	-- Item index: set of item names the player has ever exploded (player or worker).
	-- { [itemName: string]: true }
	-- Compare against ItemConfig to determine completion.
	ItemIndex         = {},
	-- Set to true after the player's very first explosion; gates the intro cutscene.
	HasExploded       = false,
}

local Profiles = {}

-- ── Real ProfileService (production) ─────────────────────────────────────────
local ProfileStore
if not DEV_MODE then
	local ProfileService = require(ServerStorage.Services.ProfileService)
	ProfileStore = ProfileService.GetProfileStore("PlayerData", PROFILE_TEMPLATE)
end

-- ── Dev-mode mock profile factory ────────────────────────────────────────────
-- Deep-copies the template so each mock player gets fully independent data.
-- Without this, nested tables (e.g. AutoExploders) would be shared across players.
local function deepCopy(t: any): any
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in t do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function makeMockProfile()
	return {
		Data       = deepCopy(PROFILE_TEMPLATE),
		-- Stub out the ProfileService methods other code might call
		Reconcile  = function() end,
		Release    = function() end,
	}
end

-- ── Public API ────────────────────────────────────────────────────────────────

function DataSaveService:Get(player: Player)
	return Profiles[player]
end

function DataSaveService:Wait(player: Player)
	while not Profiles[player] do
		task.wait()
	end
	return Profiles[player]
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	if DEV_MODE then
		Profiles[player] = makeMockProfile()
		return
	end

	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick("Profile released")
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load data")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then
		profile:Release()
		Profiles[player] = nil
	end
end)

return DataSaveService
