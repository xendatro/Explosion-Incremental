-- ItemSpawnService (Server)
-- Owns the full lifecycle of world items: seeding biomes, pickup, drop, consume, respawn.
-- Items are server-authoritative; Roblox replication handles what clients see.

local ItemSpawnService = {}

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local TagService          = require(ReplicatedStorage.Services.TagService)
local PlayerStatsService  = require(ServerStorage.Services.PlayerStatsService)
local NotificationService = require(ServerStorage.Services.NotificationService)
local ItemConfig          = require(ReplicatedStorage.Configs.ItemConfig)
local ItemSpawnConfig     = require(ReplicatedStorage.Configs.ItemSpawnConfig)
local BiomeConfig         = require(ReplicatedStorage.Configs.BiomeConfig)
local UpgradeConfig       = require(ReplicatedStorage.Configs.UpgradeConfig)
local Item                = require(ServerStorage.Classes.Item)
local EN                  = require(ReplicatedStorage.Classes.EternityNum)

-- Must match CARRY_CLEARANCE in Item.luau — the starting offset above HRP for the
-- bottom of the first item in the carry stack.
local CARRY_CLEARANCE = 4

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
-- Created programmatically so the client only needs WaitForChild.

local ItemsComm = ReplicatedStorage.Communication:WaitForChild("Items")

local function getOrMakeRemote(name: string): RemoteEvent
	local existing = ItemsComm:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local remote = Instance.new("RemoteEvent")
	remote.Name   = name
	remote.Parent = ItemsComm
	return remote
end

local DropItemEvent        = getOrMakeRemote("DropItem")
local ItemPickupFailedEvent = getOrMakeRemote("ItemPickupFailed")
local CarryUpdateEvent      = getOrMakeRemote("CarryUpdate")

-- ── Item models folder ────────────────────────────────────────────────────────

local ItemModels = ReplicatedStorage:WaitForChild("ItemModels")

-- ── State ─────────────────────────────────────────────────────────────────────

-- biomeId → BiomeZone BasePart
local biomeZones: { [number]: BasePart } = {}

-- biomeId → current item count in that biome
local biomeItemCounts: { [number]: number } = {}

-- Model → Item object (populated by Tagger via _register)
local itemByModel: { [Model]: any } = {}

-- player → ordered array of Items (index 1 = bottom, last index = top / most-recently-picked)
local carryStacks: { [Player]: { any } } = {}

-- ── Per-biome item pool (built lazily on first use) ───────────────────────────

local biomeItemPool: { [number]: { any } } = {}

local function getBiomePool(biomeId: number): { any }
	if biomeItemPool[biomeId] then return biomeItemPool[biomeId] end
	local pool = {}
	for _, def in ItemConfig do
		local biomes = def.Biomes
		-- No Biomes field or empty list → eligible for every biome.
		if not biomes or #biomes == 0 or table.find(biomes, biomeId) then
			table.insert(pool, def)
		end
	end
	biomeItemPool[biomeId] = pool
	return pool
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Roll the final carried weight (kg) from base range × rarity mult × biome mult.
local function rollWeight(def, rarity: string, biomeId: number): number
	local base       = def.Weight or { 1, 1 }
	local rarityMult = ItemSpawnConfig.RarityWeightMultipliers[rarity] or 1
	local biomeMult  = BiomeConfig.BiomeWeightMultipliers[biomeId]     or 1
	local scaledMin  = base[1] * rarityMult * biomeMult
	local scaledMax  = base[2] * rarityMult * biomeMult
	local min10      = math.round(scaledMin * 10)
	local max10      = math.round(scaledMax * 10)
	if min10 >= max10 then return math.round(scaledMin * 10) / 10 end
	return math.random(min10, max10) / 10
end

-- Pick a random item from the biome pool (uniform).
-- Each item in ItemConfig has a fixed Rarity string — no rolling needed.
-- Returns (definition, rarity), or (nil, nil) if the pool is empty.
local function pickDefinition(biomeId: number): (any?, string?)
	local pool = getBiomePool(biomeId)
	if not pool or #pool == 0 then return nil, nil end

	local def = pool[math.random(1, #pool)]
	return def, def.Rarity
end

-- Pick a random ground position within a BiomeZone by raycasting downward.
local function getGroundPosition(zone: BasePart): Vector3?
	local cf   = zone.CFrame
	local size = zone.Size

	local localX = (math.random() - 0.5) * size.X
	local localZ = (math.random() - 0.5) * size.Z
	local origin = cf:PointToWorldSpace(Vector3.new(localX, size.Y / 2, localZ))

	local exclude = { zone }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclude, player.Character) end
	end
	for _, itemModel in CollectionService:GetTagged("Item") do
		table.insert(exclude, itemModel)
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = exclude
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, Vector3.new(0, -(size.Y + 200), 0), params)
	return result and result.Position or nil
end

-- ── Carry-state broadcast ─────────────────────────────────────────────────────
-- Fires current weight, max capacity, and item count to the client so the
-- CapacityBarService can animate the HUD bar.

local function fireCarryUpdate(player: Player)
	local stack = carryStacks[player] or {}
	local totalWeight = 0
	for _, carried in stack do
		totalWeight += carried.Weight or 0
	end
	local kgLimitLevel = PlayerStatsService:GetStat(player, "CarryKgLimit")
	local kgLimit      = UpgradeConfig.CarryKgLimit.Value(kgLimitLevel)
	CarryUpdateEvent:FireClient(player, totalWeight, kgLimit, #stack)
end

-- ── Tagger integration ────────────────────────────────────────────────────────
-- Called by Tagger apply/unapply functions.

function ItemSpawnService:_register(item)
	itemByModel[item.Model] = item
end

function ItemSpawnService:_unregister(item)
	itemByModel[item.Model] = nil
end

function ItemSpawnService:_registerZone(part: BasePart)
	local biomeId = part:GetAttribute("BiomeIndex") :: number?
	if not biomeId then return end
	biomeZones[biomeId]      = part
	biomeItemCounts[biomeId] = biomeItemCounts[biomeId] or 0
end

function ItemSpawnService:_unregisterZone(part: BasePart)
	local biomeId = part:GetAttribute("BiomeIndex") :: number?
	if biomeId then
		biomeZones[biomeId] = nil
	end
end

-- ── Core: spawn one item into a biome ────────────────────────────────────────

function ItemSpawnService:SpawnItem(biomeId: number)
	local zone = biomeZones[biomeId]
	if not zone then return end

	local count = biomeItemCounts[biomeId] or 0
	if count >= ItemSpawnConfig.MaxItemsPerBiome then return end

	local def, rolledRarity = pickDefinition(biomeId)
	if not def or not rolledRarity then
		warn("ItemSpawnService: no items defined for biome", biomeId)
		return
	end

	local template = ItemModels:FindFirstChild(def.ModelName)
	if not template then
		warn("ItemSpawnService: model not found:", def.ModelName)
		return
	end

	local groundPos = getGroundPosition(zone)
	if not groundPos then
		warn("ItemSpawnService: no ground found in biome", biomeId)
		return
	end

	-- Use template's bounding box to calculate the position delta before cloning,
	-- so the clone arrives in workspace already at the correct position.
	local templateBBCFrame, templateBBSize = template:GetBoundingBox()
	local templateBottomY = templateBBCFrame.Position.Y - templateBBSize.Y / 2
	local targetBottomY   = groundPos.Y + ItemSpawnConfig.SpawnHeightOffset

	local delta = Vector3.new(
		groundPos.X - templateBBCFrame.Position.X,
		targetBottomY - templateBottomY,
		groundPos.Z - templateBBCFrame.Position.Z
	)

	-- Clone and position all parts before parenting so clients see it in place.
	local model = template:Clone()
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CFrame = desc.CFrame + delta
		end
	end

	-- Roll and stamp attributes (read by Item.new when Tagger fires).
	local rolledWeight = rollWeight(def, rolledRarity, biomeId)
	model:SetAttribute("RolledWeight", rolledWeight)
	model:SetAttribute("BiomeId",      biomeId)
	model:SetAttribute("Rarity",       rolledRarity)
	model:SetAttribute("BaseValue",    def.BaseValue)
	model:SetAttribute("ItemName",     def.Name)

	-- Add ProximityPrompt to any BasePart before tagging.
	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	local prompt    = Instance.new("ProximityPrompt")
	prompt.ObjectText           = def.Name
	prompt.ActionText           = "Pick Up"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent               = firstPart

	-- Create and register the Item object BEFORE tagging, so when the Tagger
	-- fires (deferred) it finds the item already in itemByModel and skips re-creation.
	local item = Item.new(model)
	item.Definition = def
	ItemSpawnService:_register(item)

	-- Parent to workspace, then tag. Clients see it at the correct position.
	model.Parent = workspace
	CollectionService:AddTag(model, "Item")

	biomeItemCounts[biomeId] = count + 1

	-- Start the ground despawn timer immediately (item is on the ground from birth).
	item._despawnRemaining = ItemSpawnConfig.GroundDespawnTime
	item:StartDespawnTimer(function(expiredItem)
		ItemSpawnService:_despawnItem(expiredItem)
	end)

	-- Billboard is owned by the Item: text, colour, and countdown are all managed there.
	item:SetupBillboard()

	prompt.Triggered:Connect(function(player: Player)
		ItemSpawnService:_handlePickup(player, item)
	end)
end

-- Despawn an item whose ground timer expired: remove it and spawn a fresh one immediately.
function ItemSpawnService:_despawnItem(item)
	if item._locked then return end
	local biomeId = item.BiomeId
	item:Consume()
	item.Model:Destroy()
	biomeItemCounts[biomeId] = math.max(0, (biomeItemCounts[biomeId] or 1) - 1)
	ItemSpawnService:SpawnItem(biomeId)
end

-- Returns the Item object for a given model, if one has been registered.
-- Used by the Tagger to avoid re-creating items that SpawnItem already made.
function ItemSpawnService:GetItemForModel(model: Model)
	return itemByModel[model]
end

-- ── Pickup validation ─────────────────────────────────────────────────────────

function ItemSpawnService:_handlePickup(player: Player, item)
	if item._locked then return end

	local stack = carryStacks[player] or {}
	carryStacks[player] = stack

	-- Item count cap: fixed server-side limit to prevent monopolising spawns.
	local N_ITEM_CAP = 10
	if #stack >= N_ITEM_CAP then
		NotificationService:Message(player, "Error", "Carry Limit",
			string.format("You can only carry %d items at once.", N_ITEM_CAP))
		return
	end

	-- Kg limit check: total weight of the stack + this item must fit within the
	-- player's purchased CarryKgLimit. This is now a plain-number comparison.
	local kgLimitLevel = PlayerStatsService:GetStat(player, "CarryKgLimit")
	local kgLimit      = UpgradeConfig.CarryKgLimit.Value(kgLimitLevel)
	local totalWeight  = item.Weight or 0
	for _, carried in stack do
		totalWeight += carried.Weight or 0
	end
	if totalWeight > kgLimit then
		NotificationService:Message(player, "Error", "Too Heavy",
			string.format("Stack would be %.1f kg but your limit is %.1f kg. Spend Strength to upgrade.", totalWeight, kgLimit))
		return
	end

	-- Compute the Y offset above HRP where this item's bottom should sit.
	-- Each item in the stack occupies exactly its bounding-box height, stacked directly.
	local carryBottomY = CARRY_CLEARANCE
	for _, carried in stack do
		local _, bbs = carried.Model:GetBoundingBox()
		carryBottomY += bbs.Y
	end

	local success = item:Pickup(player, carryBottomY)
	if success then
		item:PauseDespawnTimer()
		table.insert(stack, item)
		player:SetAttribute("HoldingItem", true)
		fireCarryUpdate(player)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Returns the full carry stack (array, index 1 = bottom). Do not mutate directly.
function ItemSpawnService:GetCarryStack(player: Player): { any }
	return carryStacks[player] or {}
end

-- Clears all items from the player's carry stack without dropping them.
-- Called by ExploderService after all items have been handed off to the exploder.
function ItemSpawnService:_clearCarryAll(player: Player)
	carryStacks[player] = {}
	player:SetAttribute("HoldingItem", false)
	fireCarryUpdate(player)
end

-- Drops the TOP item (LIFO). HoldingItem stays true if more items remain.
-- Called by remote event, character death, and player leave.
function ItemSpawnService:DropItem(player: Player)
	local stack = carryStacks[player]
	if not stack or #stack == 0 then return end

	local item = table.remove(stack)  -- removes last element (top of carry stack)
	item:Drop()
	item:StartDespawnTimer(function(expiredItem)
		ItemSpawnService:_despawnItem(expiredItem)
	end)

	if #stack == 0 then
		player:SetAttribute("HoldingItem", false)
	end
	fireCarryUpdate(player)
end

-- Drops ALL items in the carry stack. Used on death and player leave.
function ItemSpawnService:DropAllItems(player: Player)
	local stack = carryStacks[player]
	if not stack then return end
	while #stack > 0 do
		self:DropItem(player)
	end
end

-- Destroys the item and schedules a biome respawn. Called by ExploderService.
function ItemSpawnService:ConsumeItem(item)
	-- Safety: if the item is somehow still tracked in a carry stack, remove it.
	local player = item.CarriedBy
	if player then
		local stack = carryStacks[player]
		if stack then
			for i, s in stack do
				if s == item then
					table.remove(stack, i)
					break
				end
			end
			if #stack == 0 then
				player:SetAttribute("HoldingItem", false)
			end
		end
	end

	local biomeId = item.BiomeId
	item:Consume()
	item.Model:Destroy()

	biomeItemCounts[biomeId] = math.max(0, (biomeItemCounts[biomeId] or 1) - 1)

	task.delay(ItemSpawnConfig.RespawnDelay, function()
		ItemSpawnService:SpawnItem(biomeId)
	end)
end

-- Returns the highest-value available item the worker can carry.
-- Filters: not locked, not consumed, not on an exploder, biome <= maxBiome,
-- item weight <= strengthCapacity (kg).
-- Value is estimated as BaseValue × RarityMultiplier × BiomeCoinMultiplier
-- (ExploderLevel bonus is uniform across all items so it doesn't affect ranking).
function ItemSpawnService:GetAvailableItemForWorker(maxBiome: number, strengthCapacity: number)
	local bestItem  = nil
	local bestValue = -1

	for _, item in itemByModel do
		if item._locked     then continue end
		if item._consumed   then continue end
		if item._onExploder then continue end

		local biomeId = item.BiomeId or 0
		if biomeId < 1 or biomeId > maxBiome then continue end

		if (item.Weight or 0) > strengthCapacity then continue end

		local rarity    = item.Model:GetAttribute("Rarity")    or "Common"
		local baseValue = item.Model:GetAttribute("BaseValue") or 0
		local rarityMult = ItemSpawnConfig.RarityMultipliers[rarity]           or 1
		local biomeMult  = BiomeConfig.BiomeCoinMultipliers[biomeId]           or 1
		local estimated  = baseValue * rarityMult * biomeMult

		if estimated > bestValue then
			bestValue = estimated
			bestItem  = item
		end
	end

	return bestItem
end

-- ── Initialisation ────────────────────────────────────────────────────────────
-- BiomeZone registration is handled by the Tagger (_registerZone).
-- Seeding is deferred so both the "Item" and "BiomeZone" Tagger listeners
-- are registered and all existing zones are collected before SpawnItem runs.

task.defer(function()
	for biomeId in biomeZones do
		for _ = 1, ItemSpawnConfig.MaxItemsPerBiome do
			ItemSpawnService:SpawnItem(biomeId)
		end
	end
end)

-- ── Remote handlers ───────────────────────────────────────────────────────────

DropItemEvent.OnServerEvent:Connect(function(player: Player)
	ItemSpawnService:DropItem(player)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

-- On death: drop every carried item and resume their despawn timers.
-- On leave: PlayerRemoving fires first and calls DropAllItems, so by the time
-- CharacterRemoving fires the stack is already empty — DropAllItems is a no-op.
local function onCharacterRemoving(player: Player)
	ItemSpawnService:DropAllItems(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterRemoving:Connect(function()
		onCharacterRemoving(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- PlayerRemoving fires before CharacterRemoving on disconnect.
-- Consume all carried items immediately so the plot resets cleanly (no orphaned items).
Players.PlayerRemoving:Connect(function(player: Player)
	local stack = carryStacks[player]
	if stack and #stack > 0 then
		local toConsume = table.clone(stack)
		carryStacks[player] = {}
		player:SetAttribute("HoldingItem", false)
		for _, item in toConsume do
			ItemSpawnService:ConsumeItem(item)
		end
	end
end)

return ItemSpawnService
