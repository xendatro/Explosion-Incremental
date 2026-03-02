local CutsceneService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cutscene = require(ReplicatedStorage.Classes.Cutscene)

type InstanceSettings = {
	Model:  Instance,
	Clone:  boolean?,
	CFrame: CFrame?,
}

type CreateSettings = {
	Name:    string,
	Parent:  Instance?,
	Rigs:    { [string]: InstanceSettings }?,
	Objects: { [string]: InstanceSettings }?,
}

-- Shared logic: clone, pivot, and replace for any named item
local function applyInstanceSettings(cs, name: string, settings: InstanceSettings, parent: Instance)
	local idx = cs:Find(name)
	if not idx then return end

	local instance = settings.Model

	if instance then
		if settings.Clone then
			instance = instance:Clone()
			instance.Parent = parent
		end

		if settings.CFrame then
			instance:PivotTo(settings.CFrame)
		end

		cs:Replace(idx, instance)
	elseif settings.Clone then
		warn("CutsceneService: Clone = true but no Model provided for '" .. name .. "'")
		return
	end

	-- SetOffset applies whether or not a model was swapped in —
	-- useful for things like Camera where the instance is always already resolved
	if settings.CFrame then
		cs:SetOffset(idx, settings.CFrame)
	end
end

-- Creates and configures a Cutscene instance.
-- Returns the Cutscene so you can call :OnMarker(), :Play(), etc.
--
-- Example:
--   local cs = CutsceneService:Create({
--       Name    = "Test1",
--       Parent  = workspace.Map,
--       Rigs    = {
--           ["Player"] = { Model = player.Character, CFrame = CFrame.new(0, 0, 0) },
--           ["Caden"]  = { Model = ReplicatedStorage.NPCs.Caden, Clone = true },
--       },
--       Objects = {
--           ["MyPart"] = { Model = ReplicatedStorage.Props.MyPart, Clone = true, CFrame = CFrame.new(5, 0, 0) },
--       },
--   })
--   cs:Play()

function CutsceneService:Create(settings: CreateSettings)
	local file   = ReplicatedStorage.Cutscenes[settings.Name]
	local parent = settings.Parent or workspace

	local cs = Cutscene.new(file, parent)

	for name, instanceSettings in settings.Rigs or {} do
		applyInstanceSettings(cs, name, instanceSettings, parent)
	end

	for name, instanceSettings in settings.Objects or {} do
		applyInstanceSettings(cs, name, instanceSettings, parent)
	end

	return cs
end

return CutsceneService
