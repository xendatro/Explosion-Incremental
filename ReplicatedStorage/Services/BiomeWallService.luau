-- BiomeWallService (Client)
-- Manages wall passthrough (CanCollide) for "BiomeWall" tagged models.
-- When MaxBiomeUnlocked increases, walls at or below that biome index become
-- non-collidable for this client only.
--
-- Board UI and unlock purchases are handled by BiomeWallBoardClass.

local BiomeWallService = {}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)

local CommBiomeWalls  = ReplicatedStorage.Communication:WaitForChild("BiomeWalls")
local REBiomeUnlocked = CommBiomeWalls:WaitForChild("BiomeUnlocked") :: RemoteEvent

-- ── Wall passthrough ──────────────────────────────────────────────────────────

local function setWallPassthrough(wall: Model, passthrough: boolean)
	for _, part in wall:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = not passthrough
		end
	end
end

local function refreshWalls()
	local unlocked = PlayerStatsService:GetStat("MaxBiomeUnlocked") :: number
	for _, wall in CollectionService:GetTagged("BiomeWall") do
		local biomeIndex = wall:GetAttribute("BiomeIndex") :: number?
		if biomeIndex and biomeIndex <= unlocked then
			setWallPassthrough(wall, true)
		end
	end
end

-- Handle walls that stream in after service start.
CollectionService:GetInstanceAddedSignal("BiomeWall"):Connect(function(wall)
	local biomeIndex = wall:GetAttribute("BiomeIndex") :: number?
	if not biomeIndex then return end
	local unlocked = PlayerStatsService:GetStat("MaxBiomeUnlocked") :: number
	if biomeIndex <= unlocked then
		task.defer(function() setWallPassthrough(wall, true) end)
	end
end)

-- Refresh whenever MaxBiomeUnlocked changes (stat load or purchase).
PlayerStatsService:OnStatChanged("MaxBiomeUnlocked", refreshWalls)

-- ── BiomeUnlocked — cutscene hook ─────────────────────────────────────────────

REBiomeUnlocked.OnClientEvent:Connect(function(biomeIndex: number)
	-- TODO: trigger unlock cutscene via CutsceneService
	-- e.g. CutsceneService:PlayBiomeUnlock(biomeIndex)
	print("[BiomeWallService] Biome " .. biomeIndex .. " unlocked — cutscene hook (not yet implemented)")
end)

return BiomeWallService
