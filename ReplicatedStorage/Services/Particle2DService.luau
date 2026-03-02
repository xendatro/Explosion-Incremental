-- Particle2DService
-- Emits template parts containing ParticleEmitters, looked up by name from
-- workspace.Particles. Mirrors the interface of Particle3DService.
--
-- Usage:
--   local Particle2DService = require(ReplicatedStorage.Services.Particle2DService)
--   Particle2DService:Emit("Explode", someModel)          -- PVInstance
--   Particle2DService:Emit("Explode", Vector3.new(0,5,0)) -- Vector3
--   Particle2DService:Emit("Explode", someCFrame)         -- CFrame
--
-- Templates live in ReplicatedStorage.Props.Particles as children named by effect name.
-- Each ParticleEmitter on a template may have optional attributes:
--   EmitCount (number) — argument passed to :Emit(n).    Default: 1
--   EmitDelay (number) — seconds to wait before emitting. Default: 0

local Particle2DService = {}

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Particles = ReplicatedStorage.Props.Particles

-- Cached references per effect name so we only do the folder lookup once.
local _cache: { [string]: PVInstance } = {}

local function getTemplate(name: string): PVInstance
	if not _cache[name] then
		_cache[name] = Particles:WaitForChild(name) :: PVInstance
	end
	return _cache[name]
end

function Particle2DService:Emit(name: string, target: CFrame | Vector3 | PVInstance, n: number?)
	task.spawn(function()
		local template = getTemplate(name)

		-- Resolve target to a CFrame.
		local cf: CFrame
		if typeof(target) == "CFrame" then
			cf = target
		elseif typeof(target) == "Vector3" then
			cf = CFrame.new(target)
		else
			cf = (target :: PVInstance):GetPivot()
		end

		local clone = template:Clone()

		-- Disable all emitters before parenting so they don't auto-emit on arrival.
		local emitters: { ParticleEmitter } = {}
		for _, desc in clone:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
				table.insert(emitters, desc)
			end
		end

		-- Anchor every BasePart so the clone doesn't fall.
		for _, desc in clone:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
			end
		end
		if clone:IsA("BasePart") then
			(clone :: BasePart).Anchored = true
		end

		clone.Parent = Workspace
		clone:PivotTo(cf)

		-- Particles don't fire reliably the same frame they're cloned in,
		-- so wait a short moment before emitting.
		task.wait(0.1)

		-- Emit each particle emitter with its own delay / count.
		-- Track the latest point at which any particle can still be alive so we
		-- know when it's safe to destroy the clone.
		local latestCleanup = 0

		for _, emitter in emitters do
			local emitDelay = emitter:GetAttribute("EmitDelay") or 0
			local emitCount = n or emitter:GetAttribute("EmitCount") or 1
			local maxLifetime = emitter.Lifetime.Max

			local cleanupAt = emitDelay + maxLifetime
			if cleanupAt > latestCleanup then
				latestCleanup = cleanupAt
			end

			if emitDelay > 0 then
				task.delay(emitDelay, function()
					if emitter.Parent then
						emitter:Emit(emitCount)
					end
				end)
			else
				emitter:Emit(emitCount)
			end
		end

		-- Destroy the clone once every particle has had time to die.
		task.delay(latestCleanup + 0.1, function()
			if clone.Parent then
				clone:Destroy()
			end
		end)
	end)
end

return Particle2DService
