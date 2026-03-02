local PlotService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local TagService        = require(ReplicatedStorage.Services.TagService)

-- ── Plot cloning ───────────────────────────────────────────────────────────────

local PLOT_CFRAMES = {
	CFrame.new(-373.628174, 1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	CFrame.new(-253.628174, 1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	CFrame.new(-133.628174, 1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	CFrame.new(-13.6281738, 1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	CFrame.new(106.371826,  1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	CFrame.new(226.371826,  1.59570301, -136.720459, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

local templatePlot = Workspace:WaitForChild("Plot")
for i, cf in PLOT_CFRAMES do
	local clone = templatePlot:Clone()
	clone.Name = "Plot_" .. i
	clone:SetAttribute("PlotIndex", i)
	clone:PivotTo(cf)
	clone.Parent = Workspace
end
templatePlot:Destroy()

-- Populated by the Tagger as "Plot"-tagged models enter workspace
-- { [Model]: Plot }
local plotInstances: { [Model]: any } = {}

-- Fast lookups
local playerToPlot: { [Player]: any } = {}
local plotToPlayer: { [any]: Player } = {}

-- RemoteEvent — tells the owning client which Plot model is theirs
local PlotAssigned = ReplicatedStorage:WaitForChild("Communication")
	:WaitForChild("Plot")
	:WaitForChild("PlotAssigned") :: RemoteEvent

-- ── Internal ──────────────────────────────────────────────────────────────────

-- Called by Tagger when a Plot model is tagged and its class is instantiated
function PlotService:_register(plot)
	plotInstances[plot.Model] = plot
end

function PlotService:_unregister(plot)
	plotInstances[plot.Model] = nil
end

local function findFreePlot()
	for _, plot in plotInstances do
		if not plot.Owner then
			return plot
		end
	end
	return nil
end

-- ── Public API ────────────────────────────────────────────────────────────────

function PlotService:GetPlotForPlayer(player: Player)
	return playerToPlot[player]
end

function PlotService:GetPlayerForPlot(plot)
	return plotToPlayer[plot]
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	-- Wait for at least one plot to register (Tagger runs after services load)
	local attempts = 0
	while not next(plotInstances) do
		task.wait(0.1)
		attempts += 1
		if attempts > 50 then
			warn("PlotService: no Plot instances found after 5s")
			break
		end
	end

	local plot = findFreePlot()
	if not plot then
		player:Kick("Server is full — no plots available.")
		return
	end

	plot:Assign(player)
	playerToPlot[player] = plot
	plotToPlayer[plot]   = player

	-- Move the player's spawn to their plot once their character loads
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root     = character:WaitForChild("HumanoidRootPart")
		root.CFrame    = plot:GetSpawnCFrame()
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	-- Tell the client which plot model is theirs.
	-- Also set an attribute so services that connect to PlotAssigned late can
	-- still find their plot (attribute replicates immediately).
	player:SetAttribute("AssignedPlotName", plot.Model.Name)
	PlotAssigned:FireClient(player, plot.Model)
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = playerToPlot[player]
	if not plot then return end

	plot:Release()
	playerToPlot[player] = nil
	plotToPlayer[plot]   = nil
end)

return PlotService
