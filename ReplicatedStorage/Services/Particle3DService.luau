local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local Particle3DService = {}

-- Sends an emit message to all actors under Player.PlayerScripts.Particle3D[name].
function Particle3DService:Emit(name, position, n)
	task.spawn(function()
		local folder: Instance = Player.PlayerScripts.Particle3D[name]
		for _, v in folder:GetChildren() do
			if v:IsA("Actor") then
				v:SendMessage("Emit", position, n)
			end
		end
	end)
end

-- Called FROM inside an actor. Creates, configures, emits, and self-destructs
-- a Particle3D emitter using a named part and a named config preset.
-- Separating part from config lets multiple parts share the same emitter settings.
-- The actor script only needs:
--   actor:BindToMessage("Emit", function(position, n)
--       Particle3DService:EmitAt("Explode", "Explode", position, n)
--   end)
function Particle3DService:EmitAt(partName: string, configName: string, position: Vector3, n: number)
	local config = require(ReplicatedStorage.Configs.Particle3DConfig)[configName]
	if not config then
		warn("Particle3DService: no config found for '" .. configName .. "'")
		return
	end

	local part = ReplicatedStorage.Props.Particles3D:FindFirstChild(partName)
	if not part then
		warn("Particle3DService: no part found for '" .. partName .. "'")
		return
	end

	local Particle3D   = require(ReplicatedStorage.Classes.Particle3D)
	local partTemplate = ReplicatedStorage.Props.Misc.Emitter

	local emitPart = partTemplate:Clone()
	emitPart.CFrame = CFrame.lookAlong(position, Vector3.new(0, 1, 0))
	emitPart.Parent = workspace

	local emitter = Particle3D.new()
	emitter.EmmiterObject = emitPart
	emitter.Folder        = workspace.Particles
	emitter.Part          = part

	for key, value in config do
		emitter[key] = value
	end

	emitter:Emit(n)

	local maxLife = config.LifeTime and config.LifeTime.Max or 5
	task.delay(maxLife, function()
		emitter:Destroy()
		emitPart:Destroy()
	end)
end

return Particle3DService
