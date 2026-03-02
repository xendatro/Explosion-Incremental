local Plot = {}
Plot.__index = Plot

local CollectionService = game:GetService("CollectionService")

-- Helper: find the first descendant of `model` that has `tag`
local function findTagged(model: Model, tag: string): Instance?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(model) then
			return instance
		end
	end
	return nil
end

-- Helper: find both UpgradeBoard descendants, split by BoardType attribute
local function findBoards(model: Model): (Instance?, Instance?)
	local plotBoard, playerBoard
	for _, instance in CollectionService:GetTagged("UpgradeBoard") do
		if instance:IsDescendantOf(model) then
			local boardType = instance:GetAttribute("BoardType")
			if boardType == "Plot" then
				plotBoard = instance
			elseif boardType == "Player" then
				playerBoard = instance
			end
		end
	end
	return plotBoard, playerBoard
end

-- Called by Tagger with the tagged Model instance
function Plot.new(model: Model)
	local self = setmetatable({}, Plot)

	self.Model       = model
	self.Index       = model:GetAttribute("PlotIndex") :: number
	self.Owner       = nil :: Player?

	-- Resolve systems by tag search within this plot's hierarchy
	self.Exploder        = findTagged(model, "Exploder")
	self.Gym             = findTagged(model, "GymEquipment")
	self.GemDisplayBoard = findTagged(model, "GemDisplayBoard")
	self.PlotBoard, self.PlayerBoard = findBoards(model)

	-- SpawnAnchor is still a plain named part (no tag needed)
	self.SpawnAnchor = model:FindFirstChild("SpawnAnchor")

	return self
end

-- Assign this plot to a player
function Plot:Assign(player: Player)
	self.Owner = player
	self.Model:SetAttribute("Owner", player.UserId)
end

-- Free the plot and clear any owner state
function Plot:Release()
	self.Owner = nil
	self.Model:SetAttribute("Owner", nil)
end

-- Get the world CFrame a player should spawn at
function Plot:GetSpawnCFrame(): CFrame
	if self.SpawnAnchor then
		return self.SpawnAnchor.CFrame + Vector3.new(0, 3, 0)
	end
	-- Fallback: above the platform centre
	return self.Model.PrimaryPart.CFrame + Vector3.new(0, 4, 0)
end

function Plot:Destroy()
	-- Tagger cleanup stub — model itself stays in workspace
end

return Plot
