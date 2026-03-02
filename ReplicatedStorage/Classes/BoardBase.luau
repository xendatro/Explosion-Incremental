-- BoardBase (Client Class)
-- Shared base for all plot board classes.
-- Handles ownership check (only sets up if board belongs to this player's plot),
-- GUI clone from RS.Props.UI, and Adornee assignment.
--
-- Usage in a subclass:
--   local base = BoardBase.new(boardModel, "MyBoardGui")
--   if not base then return end  -- not our board, or template missing
--   local self = setmetatable(base, SubClass)

local BoardBase = {}
BoardBase.__index = BoardBase

-- Shared color constants available to all board subclasses.
BoardBase.COLOR_BUY  = Color3.fromRGB(85, 255, 127)
BoardBase.COLOR_POOR = Color3.fromRGB(255, 0, 0)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local UIFolder    = ReplicatedStorage:WaitForChild("Props"):WaitForChild("UI")

-- Yields until the server has set AssignedPlotName, then returns the plot model.
local function waitForMyPlot(): Model?
	local name = localPlayer:GetAttribute("AssignedPlotName")
	if not name then
		localPlayer:GetAttributeChangedSignal("AssignedPlotName"):Wait()
		name = localPlayer:GetAttribute("AssignedPlotName")
	end
	return if name then workspace:FindFirstChild(name) :: Model? else nil
end

-- Returns a new base table if boardModel is in this player's plot, nil otherwise.
function BoardBase.new(boardModel: Model, guiTemplateName: string)
	local plot = waitForMyPlot()
	if not plot or not boardModel:IsDescendantOf(plot) then return nil end

	local template = UIFolder:FindFirstChild(guiTemplateName)
	if not template then
		warn("[BoardBase] GUI template not found in Props.UI:", guiTemplateName)
		return nil
	end

	local main = boardModel:WaitForChild("Main") :: BasePart
	local gui  = template:Clone() :: SurfaceGui
	gui.Adornee = main
	gui.Parent  = playerGui

	local self       = {}
	self.Board       = boardModel
	self.Gui         = gui
	self.Connections = {}
	return self
end

function BoardBase:AddConnection(conn: RBXScriptConnection)
	table.insert(self.Connections, conn)
end

-- Disconnects all registered connections and destroys the cloned GUI.
-- Subclasses should call this if they are ever torn down (e.g. plot reassignment).
function BoardBase:Destroy()
	for _, conn in self.Connections do
		conn:Disconnect()
	end
	self.Connections = {}
	if self.Gui and self.Gui.Parent then
		self.Gui:Destroy()
	end
end

return BoardBase
