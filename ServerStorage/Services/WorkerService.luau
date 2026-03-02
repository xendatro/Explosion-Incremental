-- WorkerService (Server)
-- Manages Worker data, purchase, upgrades, and NPC spawning.
-- Coin awarding is handled by WorkerNPCClass (Tagger-driven), not here.
--
-- DataStore: profile.Data.Workers = { {StrengthLevel=1, SpeedLevel=1, AppearanceId=0, DisplayName=""}, ... }
--   Index = worker ID. Workers are never removed once purchased.
--
-- Remotes (Communication/Workers/):
--   PurchaseWorker  (RemoteFunction) → (success: bool, indexOrErr: any)
--   UpgradeWorker   (RemoteFunction, workerIndex: number, upgradeType: "Strength"|"Speed")
--                   → (success: bool, errMsg?: string)
--   RerollWorker    (RemoteFunction, workerIndex: number) → (success: bool, errMsg?: string)
--   GetWorkers      (RemoteFunction) → { {StrengthLevel, SpeedLevel, AppearanceId, DisplayName}[] }
--   WorkersUpdated  (RemoteEvent)    → fires full workers array on any mutation
--   WorkerCycleTick (RemoteEvent)    → fires per completed cycle: { WorkerIndex, Coins }

local WorkerService = {}

print("WorkerService: loading")

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local DataSaveService     = require(ServerStorage.Services.DataSaveService)
local PlayerStatsService  = require(ServerStorage.Services.PlayerStatsService)
local NotificationService = require(ServerStorage.Services.NotificationService)
local WorkerConfig        = require(ReplicatedStorage.Configs.WorkerConfig)

-- Lazy-required to avoid service load-order issues
local function getPlotService()
	return require(ServerStorage.Services.PlotService)
end

local NPC_TEMPLATE = ReplicatedStorage:WaitForChild("Props")
	:WaitForChild("Workers")
	:WaitForChild("NPC")

-- ── Communication ─────────────────────────────────────────────────────────────

local commFolder
do
	local parent = ReplicatedStorage:WaitForChild("Communication")
	commFolder = parent:FindFirstChild("Workers")
	if not commFolder then
		commFolder        = Instance.new("Folder")
		commFolder.Name   = "Workers"
		commFolder.Parent = parent
	end
end

local function makeRF(name: string): RemoteFunction
	local existing = commFolder:FindFirstChild(name)
	if existing then return existing :: RemoteFunction end
	local rf      = Instance.new("RemoteFunction")
	rf.Name       = name
	rf.Parent     = commFolder
	return rf
end

local function makeRE(name: string): RemoteEvent
	local existing = commFolder:FindFirstChild(name)
	if existing then return existing :: RemoteEvent end
	local re      = Instance.new("RemoteEvent")
	re.Name       = name
	re.Parent     = commFolder
	return re
end

local RFPurchaseWorker  = makeRF("PurchaseWorker")
local RFUpgradeWorker   = makeRF("UpgradeWorker")
local RFRerollWorker    = makeRF("RerollWorker")
local RFGetWorkers      = makeRF("GetWorkers")
local REWorkersUpdated  = makeRE("WorkersUpdated")
makeRE("WorkerCycleTick")  -- created for client listeners; fired by WorkerNPCClass

-- ── State ─────────────────────────────────────────────────────────────────────

-- { [Player]: { [workerIndex]: Model } }
local activeNPCs: { [Player]: { [number]: Model } } = {}

-- { [Player]: { {UserId: number, DisplayName: string}[] } }
-- Player themselves is always included. Populated async on join.
local friendsCache: { [Player]: { { UserId: number, DisplayName: string } } } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Gem cost to purchase the Nth worker (1-indexed).
local function purchaseCost(n: number): number
	return math.ceil(WorkerConfig.BasePurchaseCost * (WorkerConfig.PurchasePriceScale ^ (n - 1)))
end

local function speedUpgradeCost(currentLevel: number): number
	return math.ceil(WorkerConfig.SpeedBaseCost * (WorkerConfig.SpeedPriceScale ^ currentLevel))
end

local function strengthUpgradeCost(currentLevel: number): number
	return math.ceil(WorkerConfig.StrengthBaseCost * (WorkerConfig.StrengthPriceScale ^ currentLevel))
end

-- Fetches the player's friends list and caches it along with the player themselves.
-- Called async on join; safe to call multiple times (overwrites previous cache).
local function cacheFriends(player: Player)
	local pool: { { UserId: number, DisplayName: string } } = {}

	-- Always include the player themselves so there is always at least one option.
	table.insert(pool, { UserId = player.UserId, DisplayName = player.DisplayName })

	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if ok and pages then
		while true do
			local pageOk, current = pcall(function() return pages:GetCurrentPage() end)
			if not pageOk then break end
			for _, friend in current do
				table.insert(pool, { UserId = friend.Id, DisplayName = friend.DisplayName })
			end
			if pages.IsFinished then break end
			local advOk = pcall(function() pages:AdvanceToNextPageAsync() end)
			if not advOk then break end
		end
	end

	friendsCache[player] = pool
end

-- Picks a random pool entry, excluding currentAppearanceId when pool has > 1 entry.
local function pickFromPool(player: Player, currentAppearanceId: number): { UserId: number, DisplayName: string }
	local pool = friendsCache[player] or { { UserId = player.UserId, DisplayName = player.DisplayName } }

	local available = {}
	for _, entry in pool do
		if entry.UserId ~= currentAppearanceId then
			table.insert(available, entry)
		end
	end

	-- If pool only contains the current person (e.g. no friends, already applied), allow repeat.
	if #available == 0 then
		available = pool
	end

	return available[math.random(1, #available)]
end

-- Applies a HumanoidDescription from the given UserId to the worker NPC.
-- Runs async (pcall-wrapped) since GetHumanoidDescriptionFromUserId yields.
local function applyAppearanceToNPC(player: Player, workerIndex: number, userId: number)
	-- Yield one frame so the engine fully registers the NPC before we swap its description.
	task.wait()

	local npc = activeNPCs[player] and activeNPCs[player][workerIndex]
	if not npc or not npc.Parent then return end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local descOk, desc = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, userId)
	if not descOk or not desc then
		warn("WorkerService: failed to get HumanoidDescription for userId", userId, desc)
		return
	end

	local applyOk, applyErr = pcall(humanoid.ApplyDescriptionResetAsync, humanoid, desc)
	if not applyOk then
		warn("WorkerService: failed to ApplyDescriptionResetAsync:", applyErr)
	end
end

-- Fires the full workers array to the client.
local function pushWorkers(player: Player)
	local profile = DataSaveService:Get(player)
	if not profile then return end
	REWorkersUpdated:FireClient(player, profile.Data.Workers)
end

-- ── NPC management ────────────────────────────────────────────────────────────

-- Waits up to 5s for the player's plot to be assigned, returns the plot Model or nil.
local function waitForPlotModel(player: Player): Model?
	local PlotService = getPlotService()
	local plot = PlotService:GetPlotForPlayer(player)
	local attempts = 0
	while not plot and player.Parent do
		task.wait(0.1)
		attempts += 1
		if attempts > 50 then
			warn("WorkerService: timed out waiting for plot for", player.Name)
			return nil
		end
		plot = PlotService:GetPlotForPlayer(player)
	end
	return plot and plot.Model or nil
end

-- Spawns the NPC for a given worker index and tags it "WorkerNPC" so the
-- Tagger fires WorkerNPCClass.new and the movement cycle starts automatically.
local function spawnWorkerNPC(player: Player, index: number)
	local plotModel = waitForPlotModel(player)
	if not plotModel then return end

	local workerBase = plotModel:FindFirstChild("WorkerBase")
	local spawnPart  = workerBase and workerBase:FindFirstChild("Main") :: BasePart?
	if not spawnPart then
		warn("WorkerService: WorkerBase.Main not found in", plotModel.Name)
		return
	end

	-- Grid layout: 4 columns, rows grow backward (-Z)
	local col    = (index - 1) % 4
	local row    = math.floor((index - 1) / 4)
	local offset = Vector3.new(col * 2.5 - 3.75, 0, row * 2.5)
	local spawnCF = CFrame.new(spawnPart.Position + Vector3.new(0, 4, 0) + offset)

	local npc = NPC_TEMPLATE:Clone()
	npc.Name = "Worker_" .. index

	-- Stamp ownership attributes BEFORE tagging so WorkerNPCClass.new can read them.
	npc:SetAttribute("OwnerUserId",  player.UserId)
	npc:SetAttribute("WorkerIndex",  index)

	npc:PivotTo(spawnCF)
	npc.Parent = plotModel

	-- Tag fires WorkerNPCClass.new via Tagger → starts the movement cycle.
	CollectionService:AddTag(npc, "WorkerNPC")

	if not activeNPCs[player] then
		activeNPCs[player] = {}
	end
	activeNPCs[player][index] = npc

	print(string.format("WorkerService: spawned Worker_%d NPC for %s", index, player.Name))
end

-- Destroys all spawned NPCs for a player.
-- Tagger fires WorkerNPCClass:Destroy() automatically when the model is destroyed.
local function destroyAllNPCs(player: Player)
	local npcs = activeNPCs[player]
	if not npcs then return end
	for _, npc in npcs do
		if npc and npc.Parent then
			npc:Destroy()
		end
	end
	activeNPCs[player] = nil
end

-- ── Remote handlers ───────────────────────────────────────────────────────────

-- Purchases a new worker for the player.
-- Returns (true, newWorkerIndex) on success, (false, errorMessage) on failure.
RFPurchaseWorker.OnServerInvoke = function(player: Player)
	local profile = DataSaveService:Get(player)
	if not profile then return false, "Profile not loaded" end

	local workers  = profile.Data.Workers
	local newIndex = #workers + 1

	if newIndex > WorkerConfig.MaxWorkers then
		NotificationService:Message(player, "Error", "Max Workers Reached", "You can have at most " .. WorkerConfig.MaxWorkers .. " workers.")
		return false, "Max workers reached"
	end

	local cost = purchaseCost(newIndex)

	if not PlayerStatsService:DeductGems(player, cost) then
		NotificationService:Message(player, "Error", "Not Enough Gems", "You need " .. cost .. " gems to hire a worker.")
		return false, "Not enough gems"
	end

	local picked = pickFromPool(player, 0)
	table.insert(workers, {
		StrengthLevel = 1,
		SpeedLevel    = 1,
		AppearanceId  = picked.UserId,
		DisplayName   = picked.DisplayName,
	})
	task.spawn(function()
		spawnWorkerNPC(player, newIndex)
		applyAppearanceToNPC(player, newIndex, picked.UserId)
	end)
	pushWorkers(player)

	NotificationService:Message(player, "Success", "Worker Hired", "Worker #" .. newIndex .. " is ready to work!")

	print(string.format("WorkerService: %s purchased Worker #%d (cost: %d gems)", player.Name, newIndex, cost))
	return true, newIndex
end

-- Upgrades one stat on a specific worker.
-- upgradeType must be "Speed" or "Weight".
-- Returns (true) on success, (false, errorMessage) on failure.
RFUpgradeWorker.OnServerInvoke = function(player: Player, workerIndex: number, upgradeType: string)
	if type(workerIndex) ~= "number" or type(upgradeType) ~= "string" then
		return false, "Invalid arguments"
	end

	local profile = DataSaveService:Get(player)
	if not profile then return false, "Profile not loaded" end

	local entry = profile.Data.Workers[workerIndex]
	if not entry then return false, "Worker not found" end

	local cost: number
	if upgradeType == "Speed" then
		cost = speedUpgradeCost(entry.SpeedLevel)
	elseif upgradeType == "Strength" then
		cost = strengthUpgradeCost(entry.StrengthLevel)
	else
		return false, "Unknown upgrade type: " .. upgradeType
	end

	if not PlayerStatsService:DeductGems(player, cost) then
		NotificationService:Message(player, "Error", "Not Enough Gems", "You need " .. cost .. " gems for this upgrade.")
		return false, "Not enough gems"
	end

	if upgradeType == "Speed" then
		entry.SpeedLevel    += 1
	elseif upgradeType == "Strength" then
		entry.StrengthLevel += 1
	end

	local newLevel = upgradeType == "Speed" and entry.SpeedLevel or entry.StrengthLevel
	NotificationService:Message(player, "Success", "Worker Upgraded",
		"Worker #" .. workerIndex .. " " .. upgradeType .. " is now level " .. newLevel .. "!")

	print(string.format(
		"WorkerService: %s upgraded Worker #%d %s to level %d",
		player.Name, workerIndex, upgradeType, newLevel
	))

	pushWorkers(player)
	return true
end

-- Rerolls the appearance of a specific worker, picking a new random friend.
RFRerollWorker.OnServerInvoke = function(player: Player, workerIndex: number)
	if type(workerIndex) ~= "number" then return false, "Invalid arguments" end

	local profile = DataSaveService:Get(player)
	if not profile then return false, "Profile not loaded" end

	local entry = profile.Data.Workers[workerIndex]
	if not entry then return false, "Worker not found" end

	local picked = pickFromPool(player, entry.AppearanceId or 0)
	entry.AppearanceId = picked.UserId
	entry.DisplayName  = picked.DisplayName

	task.spawn(applyAppearanceToNPC, player, workerIndex, picked.UserId)
	pushWorkers(player)

	NotificationService:Message(player, "Success", "Worker Rerolled",
		"Worker #" .. workerIndex .. " now looks like " .. picked.DisplayName .. "!")

	return true
end

-- Returns the current workers array for the requesting player.
RFGetWorkers.OnServerInvoke = function(player: Player)
	local profile = DataSaveService:Get(player)
	if not profile then return {} end
	return profile.Data.Workers
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	-- Cache friends list async (doesn't block worker spawning).
	task.spawn(cacheFriends, player)

	task.spawn(function()
		local profile = DataSaveService:Wait(player)
		local workers = profile.Data.Workers
		for i, worker in ipairs(workers) do
			task.spawn(function()
				spawnWorkerNPC(player, i)
				local appearanceId = worker.AppearanceId or 0
				if appearanceId > 0 then
					applyAppearanceToNPC(player, i, appearanceId)
				end
			end)
		end
		pushWorkers(player)
		print(string.format("WorkerService: %s loaded — %d worker(s)", player.Name, #workers))
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	friendsCache[player] = nil
	destroyAllNPCs(player)
end)

return WorkerService
