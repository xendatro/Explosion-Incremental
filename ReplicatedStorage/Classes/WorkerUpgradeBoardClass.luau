-- WorkerUpgradeBoardClass (Client Class)
-- Handles the Worker upgrade board UI.
-- Clones WorkerUpgradeBoardGui, adorns it, and populates one entry per worker.
--
-- RS.Props.UI templates:
--   WorkerUpgradeBoardGui  — the SurfaceGui (Adornee = Main)
--   WorkerUpgradeEntry     — one row per worker; cloned into scroll at runtime
--
-- Dynamic ElementIds stamped per entry (N = 1-indexed worker number):
--   WorkerSpeedUpgradeBtn_N      — speed upgrade ImageButton
--   WorkerStrengthUpgradeBtn_N   — strength upgrade ImageButton

local WorkerUpgradeBoardClass = {}
WorkerUpgradeBoardClass.__index = WorkerUpgradeBoardClass
setmetatable(WorkerUpgradeBoardClass, { __index = require(game:GetService("ReplicatedStorage").Classes.BoardBase) })

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardBase          = require(ReplicatedStorage.Classes.BoardBase)
local WorkerConfig       = require(ReplicatedStorage.Configs.WorkerConfig)
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)
local NotificationService = require(ReplicatedStorage.Services.NotificationService)

local ENTRY_TEMPLATE = ReplicatedStorage:WaitForChild("Props")
	:WaitForChild("UI")
	:WaitForChild("WorkerUpgradeEntry")

-- ── Constructor ───────────────────────────────────────────────────────────────

function WorkerUpgradeBoardClass.new(boardModel: Model)
	local base = BoardBase.new(boardModel, "WorkerUpgradeBoardGui")
	if not base then return end

	local self = setmetatable(base, WorkerUpgradeBoardClass)
	self.Workers = {}

	-- Tracks the last reroll timestamp per worker index for the 5s cooldown.
	local rerollCooldowns: { [number]: number } = {}

	local CommWorkers      = ReplicatedStorage.Communication:WaitForChild("Workers")
	local RFUpgradeWorker  = CommWorkers:WaitForChild("UpgradeWorker")  :: RemoteFunction
	local RFRerollWorker   = CommWorkers:WaitForChild("RerollWorker")   :: RemoteFunction
	local RFGetWorkers     = CommWorkers:WaitForChild("GetWorkers")     :: RemoteFunction
	local REWorkersUpdated = CommWorkers:WaitForChild("WorkersUpdated") :: RemoteEvent

	-- Navigate to the ScrollingFrame: Gui → Holder(Frame) → Holder(Frame) → Holder(ScrollingFrame)
	local scroll = self.Gui
		:WaitForChild("Holder")
		:WaitForChild("Holder")
		:WaitForChild("Holder") :: ScrollingFrame

	-- ── Entry building ────────────────────────────────────────────────────────

	local function buildEntries()
		-- Remove previously built entries.
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then child:Destroy() end
		end

		local gems = PlayerStatsService:GetStat("Gems") :: number

		for i, worker in ipairs(self.Workers) do
			local entry = ENTRY_TEMPLATE:Clone()
			entry.Name = "Entry_" .. i

			-- Headshot ImageLabel
			local viewport = entry:FindFirstChild("Viewport") :: ImageLabel?
			if viewport then
				local appearanceId = worker.AppearanceId
				if appearanceId and appearanceId > 0 then
					viewport.Image = "rbxthumb://type=AvatarHeadShot&id=" .. appearanceId .. "&w=352&h=352"
				else
					viewport.Image = ""
				end
			end

			local info = entry:FindFirstChild("Info")
			if info then
				-- Worker name label — shows rolled friend's DisplayName, or fallback
				local nameLabel = info:FindFirstChild("Name") :: TextLabel?
				if nameLabel then
					local dn = worker.DisplayName
					nameLabel.Text = (dn and dn ~= "") and dn or ("Worker #" .. i)
				end

				-- Speed row
				local speedRow = info:FindFirstChild("SpeedRow")
				if speedRow then
					local speedLevel = worker.SpeedLevel or 0
					local speedCost  = math.ceil(WorkerConfig.SpeedBaseCost * (WorkerConfig.SpeedPriceScale ^ speedLevel))
					local txt = speedRow:FindFirstChild("Text")
					if txt then
						local lv = txt:FindFirstChild("Level") :: TextLabel?
						local co = txt:FindFirstChild("Cost")  :: TextLabel?
						if lv then lv.Text = "Speed Lv. " .. speedLevel end
						if co then co.Text = speedCost .. " Gems" end
					end
					local btn = speedRow:FindFirstChild("UpgradeBtn") :: ImageButton?
					if btn then
						btn.BackgroundColor3 = gems >= speedCost and BoardBase.COLOR_BUY or BoardBase.COLOR_POOR
						btn:SetAttribute("ElementId", "WorkerSpeedUpgradeBtn_" .. i)
						CollectionService:AddTag(btn, "Element")
					end
				end

				-- Strength row
				local strengthRow = info:FindFirstChild("StrengthRow")
				if strengthRow then
					local strengthLevel = worker.StrengthLevel or 0
					local strengthCost  = math.ceil(WorkerConfig.StrengthBaseCost * (WorkerConfig.StrengthPriceScale ^ strengthLevel))
					local txt = strengthRow:FindFirstChild("Text")
					if txt then
						local lv = txt:FindFirstChild("Level") :: TextLabel?
						local co = txt:FindFirstChild("Cost")  :: TextLabel?
						if lv then lv.Text = "Strength Lv. " .. strengthLevel end
						if co then co.Text = strengthCost .. " Gems" end
					end
					local btn = strengthRow:FindFirstChild("UpgradeBtn") :: ImageButton?
					if btn then
						btn.BackgroundColor3 = gems >= strengthCost and BoardBase.COLOR_BUY or BoardBase.COLOR_POOR
						btn:SetAttribute("ElementId", "WorkerStrengthUpgradeBtn_" .. i)
						CollectionService:AddTag(btn, "Element")
					end
				end

				-- RerollBtn — stamp ElementId and tag so tryWireButton picks it up.
				local reroll = info:FindFirstChild("RerollBtn")
				if reroll then
					reroll:SetAttribute("ElementId", "WorkerRerollBtn_" .. i)
					CollectionService:AddTag(reroll, "Element")
				end
			end

			entry.Parent = scroll
		end
	end

	-- ── Button wiring ─────────────────────────────────────────────────────────
	-- Buttons are stamped with ElementIds when entries are built, so they arrive
	-- via GetInstanceAddedSignal("Element") after buildEntries() parents the entry.

	local function tryWireButton(obj: Instance)
		if not obj:IsDescendantOf(self.Gui) then return end
		local elementId = obj:GetAttribute("ElementId") :: string?
		if not elementId then return end

		local speedIndex = tonumber(elementId:match("^WorkerSpeedUpgradeBtn_(%d+)$"))
		if speedIndex then
			local btn = obj :: GuiButton
			btn.Activated:Connect(function()
				btn.Active = false
				local ok, err = RFUpgradeWorker:InvokeServer(speedIndex, "Speed")
				btn.Active = true
				if not ok then warn("[WorkerUpgradeBoardClass] Speed upgrade failed:", err) end
			end)
			return
		end

		local strengthIndex = tonumber(elementId:match("^WorkerStrengthUpgradeBtn_(%d+)$"))
		if strengthIndex then
			local btn = obj :: GuiButton
			btn.Activated:Connect(function()
				btn.Active = false
				local ok, err = RFUpgradeWorker:InvokeServer(strengthIndex, "Strength")
				btn.Active = true
				if not ok then warn("[WorkerUpgradeBoardClass] Strength upgrade failed:", err) end
			end)
			return
		end

		local rerollIndex = tonumber(elementId:match("^WorkerRerollBtn_(%d+)$"))
		if rerollIndex then
			local btn = obj :: GuiButton
			btn.Activated:Connect(function()
				local now = os.clock()
				if rerollCooldowns[rerollIndex] and now - rerollCooldowns[rerollIndex] < 5 then
					local remaining = math.ceil(5 - (now - rerollCooldowns[rerollIndex]))
					NotificationService:Message("Info", "Reroll Cooldown", "Wait " .. remaining .. " more second" .. (remaining == 1 and "" or "s") .. " before rerolling.")
					return
				end
				rerollCooldowns[rerollIndex] = now
				btn.Active = false
				local ok, err = RFRerollWorker:InvokeServer(rerollIndex)
				btn.Active = true
				if not ok then warn("[WorkerUpgradeBoardClass] Reroll failed:", err) end
			end)
			return
		end
	end

	self:AddConnection(CollectionService:GetInstanceAddedSignal("Element"):Connect(tryWireButton))
	for _, obj in CollectionService:GetTagged("Element") do
		task.spawn(tryWireButton, obj)
	end

	-- ── Data listeners ────────────────────────────────────────────────────────

	self:AddConnection(REWorkersUpdated.OnClientEvent:Connect(function(workers)
		self.Workers = workers
		buildEntries()
	end))

	-- Rebuild when gems change so button colors stay accurate.
	PlayerStatsService:OnStatChanged("Gems", buildEntries)

	-- Fetch initial worker list and build the first time.
	task.spawn(function()
		local workers = RFGetWorkers:InvokeServer()
		if workers then
			self.Workers = workers
			buildEntries()
		end
	end)

	return self
end

return WorkerUpgradeBoardClass