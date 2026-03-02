
-- BiomeWallBoardClass (Client Class)
-- Handles the BiomeWall unlock board UI.
-- Clones BiomeWallBoardGui, adorns it, wires the unlock button via xenterface,
-- and refreshes labels on MaxBiomeUnlocked / Coins stat changes.
--
-- ElementIds on BiomeWallBoardGui:
--   BiomeWallStatusLabel  — biome name + locked/unlocked state
--   BiomeWallCostLabel    — coin cost
--   BiomeWallUnlockBtn    — purchase button

local BiomeWallBoardClass = {}
BiomeWallBoardClass.__index = BiomeWallBoardClass
setmetatable(BiomeWallBoardClass, { __index = require(game:GetService("ReplicatedStorage").Classes.BoardBase) })

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardBase          = require(ReplicatedStorage.Classes.BoardBase)
local BiomeWallConfig    = require(ReplicatedStorage.Configs.BiomeWallConfig)
local PlayerStatsService = require(ReplicatedStorage.Services.PlayerStatsService)
local xenterface         = require(ReplicatedStorage.Frameworks.xenterface)
local EN                 = require(ReplicatedStorage.Classes.EternityNum)

-- ── Constructor ───────────────────────────────────────────────────────────────

function BiomeWallBoardClass.new(boardModel: Model)
	local biomeIndex = boardModel:GetAttribute("BiomeIndex") :: number?
	if not biomeIndex then return end

	local base = BoardBase.new(boardModel, "BiomeWallBoardGui")
	if not base then return end

	local self = setmetatable(base, BiomeWallBoardClass)
	self.BiomeIndex = biomeIndex

	-- Remote — fetched inside the spawned constructor.
	local CommBiomeWalls = ReplicatedStorage.Communication:WaitForChild("BiomeWalls")
	local RFUnlockBiome  = CommBiomeWalls:WaitForChild("UnlockBiome") :: RemoteFunction

	-- ── Refresh ───────────────────────────────────────────────────────────────

	local function refresh()
		local statusEl = xenterface:Get("BiomeWallStatusLabel") :: TextLabel?
		local costEl   = xenterface:Get("BiomeWallCostLabel")   :: TextLabel?
		local buyBtn   = xenterface:Get("BiomeWallUnlockBtn")   :: GuiButton?
		if not (statusEl and costEl and buyBtn) then return end

		local unlocked  = PlayerStatsService:GetStat("MaxBiomeUnlocked") :: number
		local biomeName = BiomeWallConfig.BiomeNames[biomeIndex] or ("Biome " .. biomeIndex)
		local cost      = BiomeWallConfig.UnlockCosts[biomeIndex]

		if biomeIndex <= unlocked then
			statusEl.Text  = biomeName .. " — Unlocked ✓"
			costEl.Text    = ""
			buyBtn.Visible = false

		elseif biomeIndex == unlocked + 1 then
			statusEl.Text   = biomeName .. " — Locked"
			local coins     = PlayerStatsService:GetStat("Coins")
			local canAfford = EN.meeq(coins, EN.convert(cost))
			costEl.Text     = EN.short(EN.convert(cost)) .. " Coins"
			buyBtn.Visible          = true
			buyBtn.AutoButtonColor  = canAfford
			buyBtn.BackgroundColor3 = canAfford
				and Color3.fromRGB(85, 255, 127)
				or  Color3.fromRGB(255, 80,  80)

		else
			statusEl.Text  = biomeName .. " — Locked"
			costEl.Text    = "Unlock previous biomes first"
			buyBtn.Visible = false
		end
	end

	-- ── Stat listeners ────────────────────────────────────────────────────────

	PlayerStatsService:OnStatChanged("MaxBiomeUnlocked", refresh)
	PlayerStatsService:OnStatChanged("Coins", refresh)

	-- ── Button wiring ─────────────────────────────────────────────────────────

	local function tryWireButton(obj: Instance)
		if not obj:IsDescendantOf(self.Gui) then return end
		if obj:GetAttribute("ElementId") ~= "BiomeWallUnlockBtn" then return end
		local btn = obj :: GuiButton
		btn.Activated:Connect(function()
			btn.Active = false
			local success, err = RFUnlockBiome:InvokeServer(biomeIndex)
			btn.Active = true
			if not success then
				warn("[BiomeWallBoardClass] Unlock failed:", err)
			end
		end)
	end

	self:AddConnection(CollectionService:GetInstanceAddedSignal("Element"):Connect(tryWireButton))
	for _, obj in CollectionService:GetTagged("Element") do
		tryWireButton(obj)
	end

	task.defer(refresh)
	return self
end

return BiomeWallBoardClass
