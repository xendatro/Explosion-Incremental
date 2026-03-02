-- ExploderService (Server)
-- Manages all Exploder machines in the game.
--
-- Flow:
--   1. Player carries one or more items and triggers PlacePrompt.
--      → PlacePrompt is only enabled while the plot owner is actively holding items.
--      → ALL carried items transfer to the exploder as a FIFO queue, stacked visually.
--   2. Player triggers DetonatePrompt.
--      → DetonatePrompt is only enabled when items are queued AND the owner is not holding.
--      → Items are processed one at a time, bottom to top (FIFO).
--      → Per item: server fires ExplosionReady to client → yields → client fires
--        ExplosionConfirm back at the explosion moment → server awards coins/gems.
--      → Both prompts are disabled during detonation; appropriate ones re-enable after.
--
-- Client events (ReplicatedStorage.Communication.Exploder):
--   ExplosionReady   — server→client, fired before each explosion.
--     Payload: {
--       Coins       : string   — EternityNum string; use EN.convert() then EN.short() to display
--       Gems        : number   — plain integer
--       ItemName    : string
--       Rarity      : string
--       IsFirstTime : boolean  — true only on the player's very first explosion
--       Exploder    : Model    — the Exploder model that is detonating
--     }
--   ExplosionConfirm — client→server, fired at the explosion frame (or immediately).
--   ExplosionPayout  — server→client, fired after coins/gems are awarded (HUD / workers).

local ExploderService = {}

print("ExploderService: loading")

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local ItemSpawnService   = require(ServerStorage.Services.ItemSpawnService)
local PlotService        = require(ServerStorage.Services.PlotService)
local PlayerStatsService = require(ServerStorage.Services.PlayerStatsService)

-- Lazy-required to avoid load-order issues
local function getIndexService()
	return require(ServerStorage.Services.IndexService)
end
local function getDataSaveService()
	return require(ServerStorage.Services.DataSaveService)
end
local ItemSpawnConfig    = require(ReplicatedStorage.Configs.ItemSpawnConfig)
local ExploderConfig     = require(ReplicatedStorage.Configs.ExploderConfig)
local UpgradeConfig      = require(ReplicatedStorage.Configs.UpgradeConfig)
local BiomeConfig        = require(ReplicatedStorage.Configs.BiomeConfig)
local EN                 = require(ReplicatedStorage.Classes.EternityNum)

-- ── Communication ─────────────────────────────────────────────────────────────

local CommExploder = ReplicatedStorage.Communication:WaitForChild("Exploder")

local function getOrMakeRemote(name: string): RemoteEvent
	local existing = CommExploder:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local r = Instance.new("RemoteEvent")
	r.Name   = name
	r.Parent = CommExploder
	return r
end

local ExplosionPayoutEvent  = getOrMakeRemote("ExplosionPayout")
local ExplosionReadyEvent   = getOrMakeRemote("ExplosionReady")
local ExplosionConfirmEvent = getOrMakeRemote("ExplosionConfirm")

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Seconds between processing consecutive items in the queue.
local DETONATE_ITEM_DELAY = 1.2

-- Rich-text colour strings used in the Panel label.
local COLOR_BUY = "rgb(85,255,127)"
local COLOR_WHITE = "rgb(255,255,255)"
local COLOR_RED   = "rgb(255,0,0)"

-- ── State ─────────────────────────────────────────────────────────────────────

local exploderQueue:       { [Model]: { any } }   = {}
local exploderProcessing:  { [Model]: boolean }   = {}
-- Maps each exploder model → the player who owns that plot (nil when unassigned).
local plotOwnerByExploder: { [Model]: Player? }   = {}
-- Closures that recompute and apply prompt enabled states for each exploder.
local promptUpdaters:      { [Model]: () -> () }  = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Shifts all parts of an anchored item model down by the consumed item's height.
local function shiftItemDown(item, consumedHeight: number)
	for _, desc in item.Model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CFrame = desc.CFrame - Vector3.new(0, consumedHeight, 0)
		end
	end
end

-- Calculates (but does NOT award) the payout for one item.
local function calcPayout(player: Player, item): { coinTotal: number, gemTotal: number, itemName: string, rarity: string }
	local rarity    = item.Model:GetAttribute("Rarity")    or "Common"
	local baseValue = item.Model:GetAttribute("BaseValue") or 0
	local biomeId   = item.BiomeId or 1
	local def       = item.Definition

	local exploderLevel  = PlayerStatsService:GetStat(player, "ExploderLevel")
	local exploderBonus  = UpgradeConfig.ExploderLevel.Value(exploderLevel)
	local coinRarityMult = ItemSpawnConfig.RarityMultipliers[rarity]  or 1
	local coinBiomeMult  = BiomeConfig.BiomeCoinMultipliers[biomeId]  or 1
	local coinTotal      = math.floor(baseValue * coinRarityMult * coinBiomeMult * exploderBonus)

	local gemRarityMult = ExploderConfig.RarityGemMultipliers[rarity] or 1
	local gemBiomeMult  = BiomeConfig.BiomeGemMultipliers[biomeId]    or 1
	local baseGem       = (def and def.BaseGemValue) or 1
	local gemTotal      = math.floor(baseGem * gemRarityMult * gemBiomeMult)

	local itemName = item.Model:GetAttribute("ItemName") or (def and def.Name) or "Unknown"

	return { coinTotal = coinTotal, gemTotal = gemTotal, itemName = itemName, rarity = rarity }
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Runs the full explosion sequence for a Worker NPC: fires VFX to the client,
-- yields for ExplosionConfirm (same handshake as the player exploder), awards
-- coins, and records the discovery. No gems are awarded for worker explosions.
-- The caller (WorkerNPCClass) is responsible for consuming the item afterwards.
function ExploderService:DetonateForWorker(player: Player, item, npcExploderModel: Model)
	local rarity    = item.Model:GetAttribute("Rarity")    or "Common"
	local baseValue = item.Model:GetAttribute("BaseValue") or 0
	local biomeId   = item.BiomeId or 1
	local def       = item.Definition

	local exploderLevel  = PlayerStatsService:GetStat(player, "ExploderLevel")
	local exploderBonus  = UpgradeConfig.ExploderLevel.Value(exploderLevel)
	local coinRarityMult = ItemSpawnConfig.RarityMultipliers[rarity] or 1
	local coinBiomeMult  = BiomeConfig.BiomeCoinMultipliers[biomeId] or 1
	local coinTotal      = math.floor(baseValue * coinRarityMult * coinBiomeMult * exploderBonus)

	local itemName = item.Model:GetAttribute("ItemName") or (def and def.Name) or "Worker Item"

	-- Tell the client what's about to explode (IsFirstTime is always false for workers).
	ExplosionReadyEvent:FireClient(player, {
		Coins       = EN.toString(EN.convert(coinTotal)),
		Gems        = 0,
		ItemName    = itemName,
		Rarity      = rarity,
		IsFirstTime = false,
		Exploder    = npcExploderModel,
	})

	-- Yield until ExplosionConfirm arrives (10s timeout so the server never hangs).
	local currentThread = coroutine.running()
	local confirmed     = false
	local conn
	conn = ExplosionConfirmEvent.OnServerEvent:Connect(function(p)
		if p ~= player then return end
		conn:Disconnect()
		confirmed = true
		task.spawn(currentThread)
	end)
	local timeoutTask = task.delay(10, function()
		conn:Disconnect()
		task.spawn(currentThread)
		warn("ExploderService: worker confirm timeout for", player.Name, "— awarding anyway")
	end)
	coroutine.yield()
	if confirmed then task.cancel(timeoutTask) end

	-- Award coins and record discovery now that the client hit the explosion frame.
	PlayerStatsService:IncrementStat(player, "Coins", EN.convert(coinTotal))
	getIndexService():Record(player, itemName)

	ExplosionPayoutEvent:FireClient(player, {
		Coins    = EN.toString(EN.convert(coinTotal)),
		Gems     = 0,
		ItemName = itemName,
		Rarity   = rarity,
	})
end

-- ── Per-exploder setup ─────────────────────────────────────────────────────────

local function setupExploder(exploderModel: Model)
	print("ExploderService: setting up", exploderModel:GetFullName())

	local promptContainer   = exploderModel:FindFirstChild("Prompt")
	local detonateContainer = exploderModel:FindFirstChild("Detonate")
	local placePrompt       = promptContainer   and promptContainer:FindFirstChild("PlacePrompt")       :: ProximityPrompt?
	local detonatePrompt    = detonateContainer and detonateContainer:FindFirstChild("DetonatePrompt")  :: ProximityPrompt?
	local itemSlot          = exploderModel:FindFirstChild("ItemSlot") :: BasePart?

	if not placePrompt or not detonatePrompt or not itemSlot then
		warn(
			"ExploderService: missing required children on", exploderModel:GetFullName(),
			"— Prompt=", promptContainer ~= nil,
			"PlacePrompt=", placePrompt ~= nil,
			"Detonate=", detonateContainer ~= nil,
			"DetonatePrompt=", detonatePrompt ~= nil,
			"ItemSlot=", itemSlot ~= nil
		)
		return
	end

	-- Panel display — user explicitly asked for WaitForChild here.
	local panel    = exploderModel:WaitForChild("Panel", 10) :: BasePart?
	local panelGui = panel and panel:FindFirstChildOfClass("SurfaceGui")
	local label    = panelGui and panelGui:WaitForChild("Label", 5) :: TextLabel?
	if label then
		label.RichText = true
	end

	-- Initialise state. Both prompts start disabled; updatePrompts drives them.
	exploderQueue[exploderModel]      = {}
	exploderProcessing[exploderModel] = false
	placePrompt.Enabled    = false
	detonatePrompt.Enabled = false

	print("ExploderService:", exploderModel.Name, "ready (awaiting owner)")

	-- ── Panel update ───────────────────────────────────────────────────────────
	-- Recomputes the Panel label text from the current queue contents.

	local function updatePanel()
		if not label then return end
		local queue = exploderQueue[exploderModel]

		if #queue == 0 then
			label.Text = string.format('<font color="%s">No items detected</font>', COLOR_RED)
			return
		end

		local owner       = plotOwnerByExploder[exploderModel]
		local totalWeight = 0
		local totalCoins  = EN.convert(0)

		for _, item in queue do
			totalWeight += (item.Weight or 0)
			if owner then
				local rarity    = item.Model:GetAttribute("Rarity")    or "Common"
				local baseValue = item.Model:GetAttribute("BaseValue") or 0
				local biomeId   = item.BiomeId or 1
				local exploderLevel  = PlayerStatsService:GetStat(owner, "ExploderLevel")
				local exploderBonus  = UpgradeConfig.ExploderLevel.Value(exploderLevel)
				local coinRarityMult = ItemSpawnConfig.RarityMultipliers[rarity] or 1
				local coinBiomeMult  = BiomeConfig.BiomeCoinMultipliers[biomeId] or 1
				local coinTotal      = math.floor(baseValue * coinRarityMult * coinBiomeMult * exploderBonus)
				totalCoins = EN.add(totalCoins, EN.convert(coinTotal))
			end
		end

		label.Text = string.format(
			'<font color="%s">Weight:</font> <font color="%s">%.1f kg</font>\n<font color="%s">Value:</font> <font color="%s">%s</font>',
			COLOR_WHITE, COLOR_BUY, totalWeight,
			COLOR_WHITE, COLOR_BUY, EN.short(totalCoins)
		)
	end

	-- ── Prompt update ──────────────────────────────────────────────────────────
	-- Recomputes which prompts should be enabled based on queue, processing, and
	-- whether the plot owner is currently holding an item.

	local function updatePrompts()
		local owner      = plotOwnerByExploder[exploderModel]
		local holding    = owner and owner:GetAttribute("HoldingItem") == true or false
		local queue      = exploderQueue[exploderModel]
		local hasItems   = #queue > 0
		local processing = exploderProcessing[exploderModel]

		placePrompt.Enabled    = holding and not hasItems and not processing
		detonatePrompt.Enabled = hasItems and not holding and not processing
	end

	promptUpdaters[exploderModel] = updatePrompts

	-- Run once now (owner may already be known if setup is late relative to join).
	updatePanel()
	updatePrompts()

	-- ── Place ─────────────────────────────────────────────────────────────────
	-- Transfers the player's entire carry stack onto the exploder queue.

	placePrompt.Triggered:Connect(function(player: Player)
		print("ExploderService: Place triggered by", player.Name)

		if exploderProcessing[exploderModel] then
			print("ExploderService: blocked — detonation in progress")
			return
		end

		local queue = exploderQueue[exploderModel]
		if #queue > 0 then
			print("ExploderService: blocked — already loaded")
			return
		end

		local stack = ItemSpawnService:GetCarryStack(player)
		if #stack == 0 then
			print("ExploderService: blocked —", player.Name, "not carrying anything")
			return
		end

		-- Place each item directly on top of the previous one using actual bounding-box heights.
		local placed = 0
		local slotY  = 0  -- accumulates: Y above itemSlot.Position where next item's bottom goes
		for _, item in stack do
			local _, itemBBSize = item.Model:GetBoundingBox()
			local slotCF = CFrame.new(itemSlot.CFrame.Position + Vector3.new(0, slotY, 0))
			if item:PlaceOnExploder(slotCF) then
				item._exploderSlotHeight = itemBBSize.Y  -- stored for shift calculations
				table.insert(queue, item)
				slotY  += itemBBSize.Y
				placed += 1
			end
		end

		if placed == 0 then return end

		ItemSpawnService:_clearCarryAll(player)

		updatePanel()
		updatePrompts()

		print(string.format("ExploderService: %s → Loaded with %d item(s)", exploderModel.Name, placed))
	end)

	-- ── Detonate ──────────────────────────────────────────────────────────────
	-- Processes the queue FIFO. Remaining items fall down one slot after each pop.

	detonatePrompt.Triggered:Connect(function(player: Player)
		print("ExploderService: Detonate triggered by", player.Name)

		-- Safety guard: reject if the player picked something up before the prompt
		-- could be disabled (race condition between prompt click and HoldingItem update).
		if player:GetAttribute("HoldingItem") == true then
			print("ExploderService: blocked — player is now holding an item")
			return
		end

		local queue = exploderQueue[exploderModel]
		if #queue == 0 then
			print("ExploderService: blocked — nothing loaded")
			return
		end

		if exploderProcessing[exploderModel] then
			print("ExploderService: blocked — already processing")
			return
		end

		exploderProcessing[exploderModel] = true
		updatePrompts()

		task.spawn(function()
			while #exploderQueue[exploderModel] > 0 do
				-- Guard: player may have disconnected during the wait between items.
				-- PlayerRemoving clears the queue, but an item could already be popped.
				if not player.Parent then break end

				-- Pop the bottom item (FIFO).
				local item = table.remove(exploderQueue[exploderModel], 1)

				-- Pre-calculate payout (no side-effects yet).
				local payout = calcPayout(player, item)

				-- Check and immediately flip the first-explosion flag so a disconnect
				-- mid-cutscene doesn't cause the intro to replay on reconnect.
				local profile    = getDataSaveService():Get(player)
				local isFirstTime = profile ~= nil and not profile.Data.HasExploded
				if isFirstTime then
					profile.Data.HasExploded = true
				end

				-- Tell the client what's about to explode.
				ExplosionReadyEvent:FireClient(player, {
					Coins       = EN.toString(EN.convert(payout.coinTotal)),
					Gems        = payout.gemTotal,
					ItemName    = payout.itemName,
					Rarity      = payout.rarity,
					IsFirstTime = isFirstTime,
					Exploder    = exploderModel,
				})

				-- Yield until the client fires ExplosionConfirm (explosion frame).
				-- A 10-second timeout awards the payout regardless so the server
				-- is never left hanging if the client errors or disconnects.
				local currentThread = coroutine.running()
				local confirmed     = false
				local conn
				conn = ExplosionConfirmEvent.OnServerEvent:Connect(function(p)
					if p ~= player then return end
					conn:Disconnect()
					confirmed = true
					task.spawn(currentThread)
				end)
				local timeoutTask = task.delay(10, function()
					conn:Disconnect()
					task.spawn(currentThread)
					warn("ExploderService: confirm timeout for", player.Name, "— awarding anyway")
				end)
				coroutine.yield()
				if confirmed then task.cancel(timeoutTask) end

				-- Award payout now that the client has hit the explosion frame.
				print(string.format(
					"ExploderService: PAYOUT — %s | %s (%s) | Coins: %d | Gems: %d",
					player.Name, payout.itemName, payout.rarity, payout.coinTotal, payout.gemTotal
				))
				PlayerStatsService:IncrementStat(player, "Coins", EN.convert(payout.coinTotal))
				if payout.gemTotal > 0 then
					PlayerStatsService:IncrementStat(player, "Gems", payout.gemTotal)
				end
				getIndexService():Record(player, payout.itemName)

				-- Notify client that coins/gems landed (HUD pop-ups etc.).
				ExplosionPayoutEvent:FireClient(player, {
					Coins    = EN.toString(EN.convert(payout.coinTotal)),
					Gems     = payout.gemTotal,
					ItemName = payout.itemName,
					Rarity   = payout.rarity,
				})

				-- Shift remaining items down by the consumed item's actual height.
				local consumedHeight = item._exploderSlotHeight or 4
				for _, remaining in exploderQueue[exploderModel] do
					shiftItemDown(remaining, consumedHeight)
				end

				-- Consume (destroys model, schedules biome respawn).
				ItemSpawnService:ConsumeItem(item)

				print(string.format(
					"ExploderService: consumed %s — %d item(s) remain in queue",
					payout.itemName, #exploderQueue[exploderModel]
				))

				updatePanel()
				updatePrompts()

				task.wait(DETONATE_ITEM_DELAY)
			end

			-- Queue drained → return to Idle.
			exploderProcessing[exploderModel] = false
			updatePanel()
			updatePrompts()

			print("ExploderService:", exploderModel.Name, "→ Idle")
		end)
	end)
end

-- ── CollectionService integration ─────────────────────────────────────────────

CollectionService:GetInstanceAddedSignal("Exploder"):Connect(function(obj: Instance)
	if obj:IsA("Model") then
		task.spawn(setupExploder, obj)
	end
end)

CollectionService:GetInstanceRemovedSignal("Exploder"):Connect(function(obj: Instance)
	exploderQueue[obj :: any]        = nil
	exploderProcessing[obj :: any]   = nil
	plotOwnerByExploder[obj :: any]  = nil
	promptUpdaters[obj :: any]       = nil
end)

for _, obj in CollectionService:GetTagged("Exploder") do
	if obj:IsA("Model") then
		task.spawn(setupExploder, obj)
	end
end

-- ── Player ownership + HoldingItem watcher ────────────────────────────────────
-- When a player joins, wait for PlotService to assign them a plot, then register
-- them as the owner of that plot's exploder and watch their HoldingItem attribute.

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(function()
		-- Retry until PlotService has assigned a plot to this player.
		local exploderModel: Model?
		for _ = 1, 100 do
			local plot = PlotService:GetPlotForPlayer(player)
			if plot then
				exploderModel = plot.Exploder
				break
			end
			task.wait(0.1)
		end

		if not exploderModel then
			warn("ExploderService: could not find plot/exploder for", player.Name, "after 10s")
			return
		end

		plotOwnerByExploder[exploderModel] = player

		-- Fire once now so the prompt state reflects this player's current HoldingItem.
		local updater = promptUpdaters[exploderModel]
		if updater then updater() end

		-- Re-fire whenever the player picks up or puts down an item.
		player:GetAttributeChangedSignal("HoldingItem"):Connect(function()
			local u = promptUpdaters[exploderModel]
			if u then u() end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for model, owner in plotOwnerByExploder do
		if owner == player then
			-- Consume every queued item so the exploder is clean for the next player.
			local queue = exploderQueue[model]
			if queue and #queue > 0 then
				for _, item in queue do
					ItemSpawnService:ConsumeItem(item)
				end
				exploderQueue[model]      = {}
				exploderProcessing[model] = false
			end

			plotOwnerByExploder[model] = nil
			local updater = promptUpdaters[model]
			if updater then updater() end
			break
		end
	end
end)

return ExploderService
