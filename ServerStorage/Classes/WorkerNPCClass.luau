-- WorkerNPCClass (Server Class)
-- Drives the full movement cycle for a single Worker NPC.
-- Instantiated by the Tagger when a "WorkerNPC"-tagged model enters workspace.
--
-- Required attributes on the NPC model (set by WorkerService before tagging):
--   OwnerUserId  (number) — UserId of the owning player
--   WorkerIndex  (number) — index in profile.Data.Workers
--
-- Cycle:
--   Idle at WorkerBase → find & reserve nearest item in unlocked biomes
--   → MoveTo item → PickupByNPC → MoveTo NPCExploder.StandPoint
--   → AwardWorkerPayout → ConsumeItem → return to WorkerBase → repeat
--
-- Portal teleportation (biome 2+):
--   When the target item is in biome N > 1, the worker walks to the plot's
--   WorkerPortal, instantly teleports to the BiomePortal for biome N, walks
--   to the item, picks it up, walks back to the BiomePortal, teleports back
--   to the plot WorkerPortal, then walks to the NPCExploder as normal.

local WorkerNPCClass = {}
WorkerNPCClass.__index = WorkerNPCClass

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- Ensure the collision group exists (safe to call even if already set up in Studio).
pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, "Worker")

local WorkerConfig = require(ReplicatedStorage.Configs.WorkerConfig)

-- Lazy requires to avoid load-order issues between services
local function getItemSpawnService()
	return require(ServerStorage.Services.ItemSpawnService)
end

local function getExploderService()
	return require(ServerStorage.Services.ExploderService)
end

local function getPlayerStatsService()
	return require(ServerStorage.Services.PlayerStatsService)
end

local function getDataSaveService()
	return require(ServerStorage.Services.DataSaveService)
end

local function getPlotService()
	return require(ServerStorage.Services.PlotService)
end

-- ── Constants ─────────────────────────────────────────────────────────────────

local PICKUP_RADIUS       = 5    -- studs: close enough to pick up item
local ARRIVAL_RADIUS      = 3    -- studs: close enough to a fixed waypoint
local IDLE_WAIT           = 2    -- seconds to idle at WorkerBase between cycles
local RETRY_WAIT          = 5    -- seconds to wait when no items are available
local BASE_WALKSPEED      = 16   -- default WalkSpeed; SpeedLevel adds 2 per level
local DETONATE_ITEM_DELAY = 1.2  -- seconds between consecutive detonations
local PORTAL_RADIUS       = 5    -- studs: close enough to a portal to teleport

-- Returns the Main part of the BiomePortal for the given biomeIndex, or nil.
local function getBiomePortalPart(biomeIndex: number): BasePart?
	for _, model in CollectionService:GetTagged("BiomePortal") do
		if model:GetAttribute("BiomeIndex") == biomeIndex then
			local main = model:FindFirstChild("Main") :: BasePart?
			return main
		end
	end
	return nil
end

-- ── Constructor ───────────────────────────────────────────────────────────────

function WorkerNPCClass.new(npcModel: Model)
	local ownerUserId = npcModel:GetAttribute("OwnerUserId")
	local workerIndex = npcModel:GetAttribute("WorkerIndex")

	if not ownerUserId or not workerIndex then
		warn("WorkerNPCClass: missing OwnerUserId or WorkerIndex on", npcModel:GetFullName())
		return nil
	end

	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	local hrp      = npcModel:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not humanoid or not hrp then
		warn("WorkerNPCClass: NPC missing Humanoid or HumanoidRootPart —", npcModel.Name)
		return nil
	end

	local self = setmetatable({}, WorkerNPCClass)
	self.Model       = npcModel
	self.Humanoid    = humanoid
	self.HRP         = hrp
	self.OwnerUserId = ownerUserId
	self.WorkerIndex = workerIndex
	self._running    = true
	self._heldItem   = nil

	humanoid.WalkSpeed = BASE_WALKSPEED
	hrp:SetNetworkOwner(nil)  -- server owns NPC physics from the start

	-- Apply "Worker" collision group to every BasePart on the NPC model.
	for _, part in npcModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Worker"
		end
	end
	-- Catch any accessories or attachments streamed in after spawn.
	npcModel.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Worker"
		end
	end)

	-- Load R15 walk and idle animations via Animator so they replicate to all clients.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://507766388"
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = "rbxassetid://507777826"

	self._idleTrack = animator:LoadAnimation(idleAnim)
	self._walkTrack = animator:LoadAnimation(walkAnim)
	self._idleTrack.Priority = Enum.AnimationPriority.Idle
	self._walkTrack.Priority = Enum.AnimationPriority.Movement
	self._idleTrack.Looped = true
	self._walkTrack.Looped = true
	self._idleTrack:Play()

	-- Start cycle asynchronously so .new() returns immediately (Tagger needs the return value).
	self._cycleThread = task.spawn(function() self:_cycle() end)

	return self
end

-- ── Private helpers ───────────────────────────────────────────────────────────

function WorkerNPCClass:_getPlayer(): Player?
	return Players:GetPlayerByUserId(self.OwnerUserId)
end

function WorkerNPCClass:_getMaxBiome(): number
	local player = self:_getPlayer()
	if not player then return 1 end
	return getPlayerStatsService():GetStat(player, "MaxBiomeUnlocked") or 1
end

function WorkerNPCClass:_getSpeedLevel(): number
	local player = self:_getPlayer()
	if not player then return 0 end
	local profile = getDataSaveService():Get(player)
	if not profile then return 0 end
	local entry = profile.Data.Workers[self.WorkerIndex]
	return entry and entry.SpeedLevel or 0
end

function WorkerNPCClass:_getStrengthLevel(): number
	local player = self:_getPlayer()
	if not player then return 0 end
	local profile = getDataSaveService():Get(player)
	if not profile then return 0 end
	local entry = profile.Data.Workers[self.WorkerIndex]
	return entry and entry.StrengthLevel or 0
end

function WorkerNPCClass:_playWalk()
	if self._idleTrack.IsPlaying then self._idleTrack:Stop() end
	if not self._walkTrack.IsPlaying then self._walkTrack:Play() end
end

function WorkerNPCClass:_playIdle()
	if self._walkTrack.IsPlaying then self._walkTrack:Stop() end
	if not self._idleTrack.IsPlaying then self._idleTrack:Play() end
end

-- Instantly teleports the NPC's HumanoidRootPart to a target position.
-- Preserves the Y offset so the NPC lands at ground level above the target.
function WorkerNPCClass:_teleportTo(targetPos: Vector3)
	self.Humanoid:Move(Vector3.new(0, 0, 0), false)
	self.HRP.CFrame = CFrame.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
	self.HRP:SetNetworkOwner(nil)
end

-- MoveTo refresh loop: calls MoveTo repeatedly until arrived or cancelled.
-- Returns true if arrived, false if _running became false.
-- Arrival uses XZ-only distance so the constant Y gap between the HRP and
-- ground-level target positions doesn't prevent the check from passing.
-- Network ownership is re-asserted on each call so Roblox cannot hand the
-- NPC's physics to the nearby player, which causes premature stopping.
function WorkerNPCClass:_moveTo(targetPos: Vector3, arrivalDist: number): boolean
	-- Force server ownership at the start of every movement leg.
	self.HRP:SetNetworkOwner(nil)
	self:_playWalk()
	while self._running do
		local offset = self.HRP.Position - targetPos
		if math.sqrt(offset.X * offset.X + offset.Z * offset.Z) <= arrivalDist then
			self.Humanoid:Move(Vector3.new(0, 0, 0), false)
			-- Re-assert on arrival so the NPC stays server-owned while stationary.
			self.HRP:SetNetworkOwner(nil)
			self:_playIdle()
			return true
		end
		-- Refresh WalkSpeed each iteration so speed upgrades apply mid-movement.
		self.Humanoid.WalkSpeed = BASE_WALKSPEED + self:_getSpeedLevel() * 2
		self.Humanoid:MoveTo(targetPos)
		self.Humanoid.MoveToFinished:Wait()
		-- If timed out (8 s, returned false), loop runs again and calls MoveTo again.
		-- If arrived (returned true), distance check at top of loop exits cleanly.
	end
	self.Humanoid:Move(Vector3.new(0, 0, 0), false)
	self:_playIdle()
	return false
end

-- ── Main cycle ────────────────────────────────────────────────────────────────

function WorkerNPCClass:_cycle()
	-- Wait until the owning player's plot is available.
	local plotModel: Model?
	do
		local attempts = 0
		while not plotModel and self._running do
			local player = self:_getPlayer()
			if player then
				local plot = getPlotService():GetPlotForPlayer(player)
				if plot then
					plotModel = plot.Model
				end
			end
			if not plotModel then
				task.wait(0.5)
				attempts += 1
				if attempts > 40 then
					warn("WorkerNPCClass: could not find plot for userId", self.OwnerUserId)
					return
				end
			end
		end
	end
	if not plotModel or not self._running then return end

	local npcExploder = plotModel:FindFirstChild("NPCExploder")
	local standPart   = npcExploder and npcExploder:FindFirstChild("StandPoint") :: BasePart?
	local itemSlot    = npcExploder and npcExploder:FindFirstChild("ItemSlot")   :: BasePart?
	local workerBase  = plotModel:FindFirstChild("WorkerBase")
	local idlePart    = workerBase and workerBase:FindFirstChild("Main") :: BasePart?

	if not standPart or not itemSlot or not idlePart then
		warn("WorkerNPCClass: NPCExploder.StandPoint, NPCExploder.ItemSlot, or WorkerBase.Main missing in", plotModel.Name)
		return
	end

	local idlePos  = idlePart.Position
	local standPos = standPart.Position

	-- Plot portal — used to teleport workers to higher biomes.
	local workerPortal     = plotModel:FindFirstChild("WorkerPortal")
	local plotPortalPart   = workerPortal and workerPortal:FindFirstChild("Main") :: BasePart?
	local plotPortalPos    = plotPortalPart and plotPortalPart.Position

	local ItemSpawnService = getItemSpawnService()
	local ExploderService  = getExploderService()

	while self._running do
		-- 1. Find the highest-value carriable item in unlocked biomes.
		local maxBiome         = self:_getMaxBiome()
		local strengthCapacity = WorkerConfig.StrengthCapacity(self:_getStrengthLevel())
		local item = ItemSpawnService:GetAvailableItemForWorker(maxBiome, strengthCapacity)
		if not item then
			-- Nothing to do: return to base and wait before retrying.
			self:_moveTo(idlePos, ARRIVAL_RADIUS)
			task.wait(RETRY_WAIT)
			continue
		end

		-- 2. Reserve the item immediately so no player or other worker takes it.
		item._locked = true
		item:PauseDespawnTimer()

		-- 3. Walk to item — use portal teleportation for biome 2+.
		local biomeId = item.BiomeId or 1
		local usePortal = biomeId > 1 and plotPortalPos ~= nil
		local biomePortalPos: Vector3? = nil

		if usePortal then
			local biomePortalPart = getBiomePortalPart(biomeId)
			if biomePortalPart then
				biomePortalPos = biomePortalPart.Position
			else
				-- No portal for this biome; fall back to direct walk.
				usePortal = false
			end
		end

		local arrived: boolean
		if usePortal and biomePortalPos then
			-- Walk to plot portal, then teleport to biome portal.
			arrived = self:_moveTo(plotPortalPos, PORTAL_RADIUS)
			if arrived and self._running then
				self:_teleportTo(biomePortalPos)
				task.wait(0.1) -- brief settle after teleport
				-- Walk from biome portal to item.
				local bbCF = item.Model:GetBoundingBox()
				arrived = self:_moveTo(bbCF.Position, PICKUP_RADIUS)
			end
		else
			-- Biome 1 or no portal: walk directly.
			local bbCF = item.Model:GetBoundingBox()
			arrived = self:_moveTo(bbCF.Position, PICKUP_RADIUS)
		end

		if not arrived or item._consumed then
			-- Didn't make it or item vanished; release and retry.
			item._locked = false
			continue
		end

		-- 4. Pick up item (NPC carry — welds to HRP).
		local ok = item:PickupByNPC(self.HRP, 4)
		if not ok then
			item._locked = false
			continue
		end
		self._heldItem = item

		-- 5. Return via portal if we used one, then walk to NPCExploder.
		if usePortal and biomePortalPos then
			-- Walk back to biome portal with item.
			self:_moveTo(biomePortalPos, PORTAL_RADIUS)
			if self._running then
				-- Teleport back to plot portal.
				self:_teleportTo(plotPortalPos)
				task.wait(0.1)
			end
		end

		self:_moveTo(standPos, ARRIVAL_RADIUS)
		if not self._running then break end

		-- 6. Place item on NPCExploder's ItemSlot, run the full explosion sequence,
		--    then consume. Mirrors the player exploder flow (VFX handshake included).
		local player = self:_getPlayer()
		if player and self._heldItem then
			local slotCF = CFrame.new(itemSlot.Position)
			self._heldItem:PlaceOnExploder(slotCF)
			ExploderService:DetonateForWorker(player, self._heldItem, npcExploder)
		end
		if self._heldItem and not self._heldItem._consumed then
			ItemSpawnService:ConsumeItem(self._heldItem)
		end
		self._heldItem = nil

		task.wait(DETONATE_ITEM_DELAY)

		-- Immediately find the next item — no return-to-base between cycles.
	end

	self.Humanoid:Move(Vector3.new(0, 0, 0), false)
end

-- ── Cleanup ───────────────────────────────────────────────────────────────────

function WorkerNPCClass:Destroy()
	self._running = false

	if self._cycleThread then
		task.cancel(self._cycleThread)
		self._cycleThread = nil
	end

	if self._walkTrack then self._walkTrack:Stop() end
	if self._idleTrack then self._idleTrack:Stop() end

	-- Release any held item so it's not locked forever.
	-- The item may still be NPC-carried (has _hrpWeld) or already placed on the
	-- NPCExploder (anchored, no weld). Both cases need _locked and _onExploder
	-- cleared so the item becomes available again (or despawns naturally).
	if self._heldItem then
		local item = self._heldItem
		self._heldItem = nil
		item:DropByNPC()       -- no-op if already placed (no _hrpWeld), anchors parts
		item._locked     = false
		item._onExploder = false
		-- Restart the despawn timer. When it fires, go through ConsumeItem so
		-- biomeItemCounts is properly decremented and a replacement item spawns.
		item:StartDespawnTimer(function(expiredItem)
			getItemSpawnService():ConsumeItem(expiredItem)
		end)
	end

	-- Model is destroyed by WorkerService; do not destroy here.
end

return WorkerNPCClass
