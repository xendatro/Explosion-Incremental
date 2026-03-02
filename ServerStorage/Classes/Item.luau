-- Item.luau
-- Wraps a world item model. One instance per "Item"-tagged model in workspace.
-- Created by the Tagger; attributes (BiomeId, RolledWeight, etc.) are stamped
-- onto the model by ItemSpawnService before tagging.

local Item = {}
Item.__index = Item

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EN              = require(ReplicatedStorage.Classes.EternityNum)
local RarityConfig    = require(ReplicatedStorage.Configs.RarityConfig)
local ItemSpawnConfig = require(ReplicatedStorage.Configs.ItemSpawnConfig)
local BiomeConfig     = require(ReplicatedStorage.Configs.BiomeConfig)

local ItemGui = ReplicatedStorage:WaitForChild("Props")
	:WaitForChild("UI")
	:WaitForChild("ItemGui")

local CARRY_CLEARANCE = 4 -- default studs above HumanoidRootPart.Y for the item's bottom

function Item.new(model: Model)
	local self = setmetatable({}, Item)

	self.Model      = model
	self.Definition = nil    :: any?
	self.Weight     = model:GetAttribute("RolledWeight") :: number?
	self.BiomeId    = model:GetAttribute("BiomeId")      :: number?
	self.CarriedBy  = nil    :: Player?
	self._locked    = false
	self._consumed  = false  -- set permanently in Consume(); drives the billboard loop exit
	self._onExploder = false -- true while the item is anchored on an Exploder slot

	-- Weld handles
	self._root      = nil :: BasePart?
	self._partWelds = nil :: {WeldConstraint}?
	self._hrpWeld   = nil :: WeldConstraint?

	-- Despawn timer (managed by ItemSpawnService)
	self._despawnRemaining  = nil :: number?
	self._despawnThread     = nil :: thread?
	self._despawnStartTime  = nil :: number?

	-- Billboard GUI
	self._gui           = nil :: BillboardGui?
	self._guiTimeLabel  = nil :: TextLabel?

	return self
end

-- ── Billboard ──────────────────────────────────────────────────────────────────
-- Sets up and clones the ItemGui BillboardGui onto a transparent anchor part
-- positioned at the very top of the model's bounding box.
-- Must be called after _despawnRemaining and StartDespawnTimer are already set.

function Item:SetupBillboard()
	local model = self.Model
	local def   = self.Definition
	if not def then return end

	-- Create a tiny transparent anchor part at the top of the model's bounding box.
	-- Parented to the model so it participates automatically in Pickup/Drop anchor and
	-- weld loops. The IsBillboardAnchor attribute tells Pickup() to skip it for root.
	local bbCF, bbSize = model:GetBoundingBox()
	local anchorPart = Instance.new("Part")
	anchorPart.Name         = "BillboardAnchor"
	anchorPart.Size         = Vector3.new(0.1, 0.1, 0.1)
	anchorPart.Transparency = 1
	anchorPart.CanCollide   = false
	anchorPart.CanTouch     = false
	anchorPart.CastShadow   = false
	anchorPart.Anchored     = true
	anchorPart.CFrame       = CFrame.new(bbCF.Position.X, bbCF.Position.Y + bbSize.Y / 2, bbCF.Position.Z)
	anchorPart:SetAttribute("IsBillboardAnchor", true)
	anchorPart.Parent = model

	local gui = ItemGui:Clone()
	self._gui = gui

	local mainFrame = gui:FindFirstChild("Main")
	if mainFrame then
		local titleLabel  = mainFrame:FindFirstChild("Title")
		local weightLabel = mainFrame:FindFirstChild("Weight")
		local rarityLabel = mainFrame:FindFirstChild("Rarity")
		local valueFrame  = mainFrame:FindFirstChild("Value")
		local timeFrame   = mainFrame:FindFirstChild("Time")

		if titleLabel  then titleLabel.Text  = def.Name end
		if weightLabel then weightLabel.Text = string.format("%.1f kg", self.Weight or 0) end

		-- Rarity was rolled at spawn time and stamped on the model.
		local rarity = self.Model:GetAttribute("Rarity") or "Common"

		if rarityLabel then
			rarityLabel.Text = rarity
			local rc = RarityConfig[rarity]
			if rc then rarityLabel.TextColor3 = rc.Color end
		end

		if valueFrame then
			local valueAmount = valueFrame:FindFirstChild("Amount")
			if valueAmount then
				local rarityMult = ItemSpawnConfig.RarityMultipliers[rarity] or 1
				local biomeMult  = BiomeConfig.BiomeCoinMultipliers[self.BiomeId or 1] or 1
				local displayVal = math.floor(def.BaseValue * rarityMult * biomeMult)
				valueAmount.Text = tostring(EN.short(EN.convert(displayVal)))
			end
		end

		if timeFrame then
			local timeAmount = timeFrame:FindFirstChild("Amount")
			if timeAmount then
				timeAmount.Text    = tostring(math.floor(ItemSpawnConfig.GroundDespawnTime)) .. "s"
				self._guiTimeLabel = timeAmount
			end
		end
	end

	gui.Adornee = anchorPart
	gui.Parent  = anchorPart

	-- Countdown loop: updates Time.Amount every second until the item is consumed.
	-- Uses _consumed (not _locked) so the loop survives pickup/drop cycles.
	-- When the timer is paused (carried or on the exploder), text is left alone —
	-- it freezes at whatever value it last showed.
	task.spawn(function()
		while not self._consumed do
			local timeLabel = self._guiTimeLabel
			if timeLabel and self._despawnThread and self._despawnStartTime then
				local remaining = math.max(0, self._despawnRemaining - (tick() - self._despawnStartTime))
				timeLabel.Text  = math.ceil(remaining) .. "s"
			end
			task.wait(1)
		end
	end)
end

-- ── Pickup ────────────────────────────────────────────────────────────────────

-- carryBottomY: studs above HumanoidRootPart.Y where the item's BOTTOM should sit.
-- Defaults to CARRY_CLEARANCE (same as before single-carry). ItemSpawnService passes
-- the cumulative sum of items below so each new item stacks directly on the previous.
function Item:Pickup(player: Player, carryBottomY: number?): boolean
	if self._locked then return false end
	if self.CarriedBy then return false end
	self._locked = true

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		self._locked = false
		return false
	end

	local model = self.Model

	-- Capture bounding box BEFORE unanchoring
	local bbCFrame, bbSize = model:GetBoundingBox()

	-- Pick any non-billboard BasePart as weld root.
	-- The BillboardAnchor part is excluded so it doesn't become root; it will still
	-- be welded to the chosen root in the loop below and move with the item correctly.
	local root: BasePart?
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and not desc:GetAttribute("IsBillboardAnchor") then
			root = desc
			break
		end
	end
	if not root then
		self._locked = false
		return false
	end

	-- Unanchor all parts and disable collision while carried
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored   = false
			desc.CanCollide = false
		end
	end

	-- Weld all non-root parts to root (relative offsets captured now, before any move)
	local partWelds: {WeldConstraint} = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= root then
			local weld    = Instance.new("WeldConstraint")
			weld.Part0    = root
			weld.Part1    = desc
			weld.Parent   = model
			table.insert(partWelds, weld)
		end
	end

	-- Position root so the item's bottom sits at carryBottomY above HRP.
	local bottomY     = carryBottomY or CARRY_CLEARANCE
	local halfHeight  = bbSize.Y / 2
	local bbToRoot    = root.CFrame.Position - bbCFrame.Position
	local targetBBCen = hrp.CFrame.Position + Vector3.new(0, bottomY + halfHeight, 0)
	root.CFrame = CFrame.new(targetBBCen + bbToRoot)

	-- Weld root to HRP
	local hrpWeld   = Instance.new("WeldConstraint")
	hrpWeld.Part0   = hrp
	hrpWeld.Part1   = root
	hrpWeld.Parent  = model

	self.CarriedBy  = player
	self._root      = root
	self._partWelds = partWelds
	self._hrpWeld   = hrpWeld

	if self._gui then self._gui.Enabled = false end

	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = false end

	return true
end

-- ── Drop ──────────────────────────────────────────────────────────────────────

function Item:Drop()
	if not self.CarriedBy then return end

	local model = self.Model

	-- Remove player weld first (synchronous — physics hasn't run yet this frame)
	if self._hrpWeld then
		self._hrpWeld:Destroy()
		self._hrpWeld = nil
	end

	-- Build exclusion list: this model, all characters, all other item models
	local exclude = { model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, itemModel in CollectionService:GetTagged("Item") do
		if itemModel ~= model then
			table.insert(exclude, itemModel)
		end
	end

	local bbCFrame, bbSize = model:GetBoundingBox()
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = exclude
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result  = workspace:Raycast(
		bbCFrame.Position,
		Vector3.new(0, -(bbSize.Y / 2 + 500), 0),
		rayParams
	)
	local groundY = result and result.Position.Y or (bbCFrame.Position.Y - bbSize.Y / 2)

	-- Move root so the bounding box bottom lands at groundY
	local halfHeight = bbSize.Y / 2
	local bbToRoot   = self._root.CFrame.Position - bbCFrame.Position
	self._root.CFrame = CFrame.new(
		bbCFrame.Position.X,
		groundY + halfHeight + bbToRoot.Y,
		bbCFrame.Position.Z
	)

	-- Anchor all parts and restore collision (skip the transparent billboard anchor)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			if not desc:GetAttribute("IsBillboardAnchor") then
				desc.CanCollide = true
			end
		end
	end
	if self._partWelds then
		for _, weld in self._partWelds do weld:Destroy() end
		self._partWelds = nil
	end

	self._root     = nil
	self.CarriedBy = nil
	self._locked   = false

	if self._gui then self._gui.Enabled = true end

	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = true end
end

-- ── Place on Exploder ─────────────────────────────────────────────────────────

-- Detaches the item from the carrying player and anchors it centred on slotCFrame.
-- Call ItemSpawnService:_clearCarry(player) immediately after this returns true.
-- _locked stays true so no other player can pick up the item while it waits.
-- Returns false if the item is not currently being carried.
function Item:PlaceOnExploder(slotCFrame: CFrame): boolean
	if not self._hrpWeld then return false end

	local model = self.Model

	-- Step 1: Remove HRP weld only; keep inter-part welds so the model stays
	-- assembled when we reposition the root in the next step.
	if self._hrpWeld then
		self._hrpWeld:Destroy()
		self._hrpWeld = nil
	end

	-- Step 2: Place the item centred on the slot with identity rotation.
	--
	-- The problem with using GetBoundingBox() from the carry state is that items
	-- are rotated with the player (HRP weld), so the axis-aligned bounding box and
	-- bbToRoot offset are wrong for placement at identity rotation. Instead:
	--   (a) Capture each part's CFrame relative to root (pure translation, since
	--       partWelds were created at identity rotation on the ground).
	--   (b) Snap everything to a temp origin at identity rotation.
	--   (c) GetBoundingBox on the correctly-oriented model → correct bbToRoot.
	--   (d) Move to final slot position and re-apply relative CFrames.
	-- This completely bypasses WeldConstraint propagation and player-rotation issues.

	-- (a) Capture relative CFrames before any movement.
	local relCFrames: { [BasePart]: CFrame } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= self._root then
			relCFrames[desc] = self._root.CFrame:Inverse() * desc.CFrame
		end
	end

	-- (b) Snap all parts to identity rotation at a temporary position.
	local TEMP = CFrame.new(0, -2000, 0)
	self._root.CFrame = TEMP
	for desc, relCF in relCFrames do
		desc.CFrame = TEMP * relCF
	end

	-- (c) Bounding box is now at identity rotation → correct bbToRoot and height.
	local bbCFrame, bbSize = model:GetBoundingBox()
	local bbToRoot     = self._root.CFrame.Position - bbCFrame.Position
	local targetCenter = slotCFrame.Position + Vector3.new(0, bbSize.Y / 2, 0)

	-- (d) Move root to the final slot position, reposition all other parts.
	self._root.CFrame = CFrame.new(targetCenter + bbToRoot)
	for desc, relCF in relCFrames do
		desc.CFrame = self._root.CFrame * relCF
	end

	-- Step 3: Anchor every part and keep collision off (item sits in the exploder queue).
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored   = true
			desc.CanCollide = false
		end
	end

	-- Step 4: Snap the BillboardAnchor precisely to the top of the placed item.
	local anchorPos = Vector3.new(slotCFrame.Position.X, slotCFrame.Position.Y + bbSize.Y, slotCFrame.Position.Z)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("IsBillboardAnchor") then
			desc.CFrame = CFrame.new(anchorPos)
			break
		end
	end

	-- Step 5: Destroy the now-redundant inter-part welds.
	if self._partWelds then
		for _, weld in self._partWelds do weld:Destroy() end
		self._partWelds = nil
	end

	self._root       = nil
	self.CarriedBy   = nil
	self._onExploder = true
	-- _locked stays true — no other player can pick this up while it waits.

	return true
end

-- ── Despawn timer ─────────────────────────────────────────────────────────────

-- Starts (or restarts) the countdown. Calls callback(self) when time runs out.
function Item:StartDespawnTimer(callback: (Item) -> ())
	if not self._despawnRemaining then return end
	if self._despawnThread then task.cancel(self._despawnThread) end

	self._despawnStartTime = tick()
	self._despawnThread    = task.delay(self._despawnRemaining, function()
		self._despawnThread = nil
		callback(self)
	end)
end

-- Freezes the countdown, preserving remaining time for the next StartDespawnTimer call.
function Item:PauseDespawnTimer()
	if not self._despawnThread then return end
	task.cancel(self._despawnThread)
	self._despawnThread = nil
	local elapsed = tick() - (self._despawnStartTime or tick())
	self._despawnRemaining = math.max(0, self._despawnRemaining - elapsed)
end

-- ── NPC Carry ─────────────────────────────────────────────────────────────────
-- Same weld mechanics as Pickup() but takes a BasePart (NPC HRP) instead of a Player.
-- Assumes the caller has already set _locked = true and paused the despawn timer.

function Item:PickupByNPC(hrp: BasePart, carryBottomY: number?): boolean
	if self._consumed then return false end
	self._locked = true  -- ensure locked regardless of caller state

	local model = self.Model
	local bbCFrame, bbSize = model:GetBoundingBox()

	local root: BasePart?
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and not desc:GetAttribute("IsBillboardAnchor") then
			root = desc
			break
		end
	end
	if not root then
		self._locked = false
		return false
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored   = false
			desc.CanCollide = false
		end
	end

	local partWelds: {WeldConstraint} = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= root then
			local weld    = Instance.new("WeldConstraint")
			weld.Part0    = root
			weld.Part1    = desc
			weld.Parent   = model
			table.insert(partWelds, weld)
		end
	end

	local bottomY     = carryBottomY or 4
	local halfHeight  = bbSize.Y / 2
	local bbToRoot    = root.CFrame.Position - bbCFrame.Position
	local targetBBCen = hrp.CFrame.Position + Vector3.new(0, bottomY + halfHeight, 0)
	root.CFrame = CFrame.new(targetBBCen + bbToRoot)

	local hrpWeld   = Instance.new("WeldConstraint")
	hrpWeld.Part0   = hrp
	hrpWeld.Part1   = root
	hrpWeld.Parent  = model

	self._root      = root
	self._partWelds = partWelds
	self._hrpWeld   = hrpWeld

	if self._gui then self._gui.Enabled = false end

	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = false end

	return true
end

-- Releases the NPC weld and anchors the item in place.
-- Call immediately before ConsumeItem so the weld is clean when the model is destroyed.
function Item:DropByNPC()
	if self._hrpWeld then
		self._hrpWeld:Destroy()
		self._hrpWeld = nil
	end
	if self._partWelds then
		for _, weld in self._partWelds do weld:Destroy() end
		self._partWelds = nil
	end
	for _, desc in self.Model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
	self._root = nil
	if self._gui then self._gui.Enabled = true end
	-- Re-enable the pickup prompt so players can collect the item if the NPC
	-- drops it back on the ground (e.g. on worker destroy / player disconnect).
	local prompt = self.Model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = true end
end

-- ── Consume / Destroy ─────────────────────────────────────────────────────────

function Item:Consume()
	self._locked   = true
	self._consumed = true   -- exits the billboard countdown loop
	self.CarriedBy = nil
end

function Item:Destroy()
	if self._despawnThread then
		task.cancel(self._despawnThread)
		self._despawnThread = nil
	end
	if self._hrpWeld then
		self._hrpWeld:Destroy()
		self._hrpWeld = nil
	end
	if self._partWelds then
		for _, weld in self._partWelds do weld:Destroy() end
		self._partWelds = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui          = nil
		self._guiTimeLabel = nil
	end
end

return Item
