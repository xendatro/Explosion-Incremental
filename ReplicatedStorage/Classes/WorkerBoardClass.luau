-- WorkerBoardClass (Client Class)
-- Handles the Worker purchase board UI.
-- Clones WorkerBoardGui, adorns it, wires buy buttons via xenterface,
-- and refreshes count/cost labels on WorkersUpdated.
--
-- ElementIds on WorkerBoardGui:
--   WorkerCountLabel  — current worker count
--   WorkerCostLabel   — gem cost for next worker
--   WorkerBuyBtn      — buy one worker
--   WorkerBuyMaxBtn   — buy as many as affordable

local WorkerBoardClass = {}
WorkerBoardClass.__index = WorkerBoardClass
setmetatable(WorkerBoardClass, { __index = require(game:GetService("ReplicatedStorage").Classes.BoardBase) })

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardBase          = require(ReplicatedStorage.Classes.BoardBase)
local WorkerConfig       = require(ReplicatedStorage.Configs.WorkerConfig)
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)
local xenterface         = require(ReplicatedStorage.Frameworks.xenterface)

-- ── Constructor ───────────────────────────────────────────────────────────────

function WorkerBoardClass.new(boardModel: Model)
	local base = BoardBase.new(boardModel, "WorkerBoardGui")
	if not base then return end

	local self = setmetatable(base, WorkerBoardClass)
	self.Workers = {}

	-- Remotes — fetched inside the spawned constructor.
	local CommWorkers      = ReplicatedStorage.Communication:WaitForChild("Workers")
	local RFPurchaseWorker = CommWorkers:WaitForChild("PurchaseWorker") :: RemoteFunction
	local RFGetWorkers     = CommWorkers:WaitForChild("GetWorkers")     :: RemoteFunction
	local REWorkersUpdated = CommWorkers:WaitForChild("WorkersUpdated") :: RemoteEvent

	-- ── Refresh ───────────────────────────────────────────────────────────────

	local function refresh()
		local n      = #self.Workers
		local atMax  = n >= WorkerConfig.MaxWorkers

		local countEl = xenterface:Get("WorkerCountLabel") :: TextLabel?
		local costEl  = xenterface:Get("WorkerCostLabel")  :: TextLabel?
		local buyBtn  = xenterface:Get("WorkerBuyBtn")     :: GuiButton?
		local maxBtn  = xenterface:Get("WorkerBuyMaxBtn")  :: GuiButton?

		if countEl then countEl.Text = "Workers: " .. n .. " / " .. WorkerConfig.MaxWorkers end

		if atMax then
			if costEl then costEl.Text = "MAX" end
			for _, btn in { buyBtn, maxBtn } do
				if btn then
					btn.Active           = false
					btn.AutoButtonColor  = false
					btn.BackgroundColor3 = BoardBase.COLOR_POOR
				end
			end
		else
			local cost      = math.ceil(WorkerConfig.BasePurchaseCost * (WorkerConfig.PurchasePriceScale ^ n))
			local gems      = PlayerStatsService:GetStat("Gems") :: number
			local canAfford = gems >= cost

			if costEl then costEl.Text = tostring(cost) .. " Gems" end

			local color = canAfford and BoardBase.COLOR_BUY or BoardBase.COLOR_POOR
			for _, btn in { buyBtn, maxBtn } do
				if btn then
					btn.Active           = true
					btn.AutoButtonColor  = canAfford
					btn.BackgroundColor3 = color
				end
			end
		end
	end

	-- ── WorkersUpdated + Gems stat ────────────────────────────────────────────

	self:AddConnection(REWorkersUpdated.OnClientEvent:Connect(function(workers)
		self.Workers = workers
		refresh()
	end))

	PlayerStatsService:OnStatChanged("Gems", refresh)

	-- ── Button wiring ─────────────────────────────────────────────────────────

	local function tryWireButton(obj: Instance)
		if not obj:IsDescendantOf(self.Gui) then return end
		local elementId = obj:GetAttribute("ElementId") :: string?

		if elementId == "WorkerBuyBtn" then
			local btn = obj :: GuiButton
			btn.Activated:Connect(function()
				btn.Active = false
				local success, result = RFPurchaseWorker:InvokeServer()
				btn.Active = true
				if not success then
					warn("[WorkerBoardClass] Purchase failed:", result)
				end
			end)

		elseif elementId == "WorkerBuyMaxBtn" then
			local btn = obj :: GuiButton
			btn.Activated:Connect(function()
				btn.Active = false
				for _ = 1, 100 do
					local success = RFPurchaseWorker:InvokeServer()
					if not success then break end
					task.wait()
				end
				btn.Active = true
			end)
		end
	end

	self:AddConnection(CollectionService:GetInstanceAddedSignal("Element"):Connect(tryWireButton))
	for _, obj in CollectionService:GetTagged("Element") do
		tryWireButton(obj)
	end

	-- Fetch initial worker list then refresh.
	task.spawn(function()
		local workers = RFGetWorkers:InvokeServer()
		if workers then
			self.Workers = workers
			refresh()
		end
	end)

	return self
end

return WorkerBoardClass
