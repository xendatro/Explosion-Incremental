-- ExploderService (Client)
-- Listens for ExplosionReady from the server and fires ExplosionConfirm back
-- at the exact moment the explosion should be "registered" (i.e. the frame
-- where coins/gems are awarded server-side).
--
-- On the player's very first explosion, IsFirstTime = true.
-- Play the intro cutscene here and fire ExplosionConfirm at the explosion frame.
-- On all subsequent explosions, ExplosionConfirm is fired immediately.
--
-- ExplosionReady payload: {
--   Coins       : string   — EternityNum string; use EN.convert() then EN.short() to display
--   Gems        : number   — plain integer
--   ItemName    : string
--   Rarity      : string
--   IsFirstTime : boolean  — true only on the player's very first explosion
--   Exploder    : Model    — the Exploder model that is detonating
-- }

local ExploderService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommExploder      = ReplicatedStorage:WaitForChild("Communication"):WaitForChild("Exploder")
local ExplosionReady    = CommExploder:WaitForChild("ExplosionReady")    :: RemoteEvent
local ExplosionConfirm  = CommExploder:WaitForChild("ExplosionConfirm")  :: RemoteEvent

local Particle2DService = require(ReplicatedStorage.Services.Particle2DService)
local Particle3DService = require(ReplicatedStorage.Services.Particle3DService)
local ShakeService      = require(ReplicatedStorage.Services.ShakeService)

-- Returns how many visual particles to spawn for a given plain integer amount.
-- Scale: 1→1, 3→2, 8→3, ... capped at 30.
local LOG_BASE = math.log(2.5)
local function visualCount(amount: number): number
	if amount <= 0 then return 0 end
	return math.clamp(1 + math.floor(math.log(amount) / LOG_BASE), 1, 30)
end

-- Converts an EternityNum "Layer;Exp" string to a visual particle count.
-- Layer 0: value = 10^Exp, so log_2.5(10^Exp) = Exp * log(10)/log(2.5).
-- Layer ≥ 1: astronomically large → max out at 30.
local LOG10_OVER_LOG25 = math.log(10) / LOG_BASE  -- ≈ 2.513
local function visualCountEN(enStr: string): number
	local layerStr, expStr = enStr:match("^(%d+);(.+)$")
	local layer = tonumber(layerStr) or 0
	local exp   = tonumber(expStr)   or 0
	if layer >= 1 then return 30 end
	if exp   <= 0 then return 1  end
	return math.clamp(1 + math.floor(exp * LOG10_OVER_LOG25), 1, 30)
end

ExplosionReady.OnClientEvent:Connect(function(payload)
	local coinVisuals = visualCountEN(payload.Coins)
	local gemVisuals  = visualCount(payload.Gems)

	local function explode()
		Particle2DService:Emit("Explode", payload.Exploder.ItemSlot.Position, coinVisuals)
		Particle3DService:Emit("Explode", payload.Exploder.ItemSlot.Position, gemVisuals)
		ShakeService:Create({
			ShakeType = "Once",
			Preset = "Jumpscare",
			ID = ""
		})
	end
	
	if payload.IsFirstTime then
		-- TODO: play the explosion intro cutscene via CutsceneService.
		-- Fire ExplosionConfirm:FireServer() at the cutscene's explosion frame,
		-- then return so the line below does not also fire it.
		-- Example:
		--   local CutsceneService = require(ReplicatedStorage.Services.CutsceneService)
		--   local cs = CutsceneService:Create({ Name = "ExplosionIntro", ... })
		--   cs:OnMarker("Explode", function() ExplosionConfirm:FireServer() end)
		--   cs:Play()
		--   return
	end
	
	
	explode()

	-- Non-first-time path (and fallthrough until cutscene is implemented).
	ExplosionConfirm:FireServer()
end)

return ExploderService
