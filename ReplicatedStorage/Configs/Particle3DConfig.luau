-- Particle3DConfig
-- Named presets for Particle3DService:EmitAt().
-- Each entry maps directly onto Particle3D emitter properties.
-- "Part" must be a BasePart stored in ReplicatedStorage.Props.Particles3D.
--
-- Usage (inside an actor):
--   local Particle3DService = require(ReplicatedStorage.Services.Particle3DService)
--   actor:BindToMessage("Emit", function(position, n)
--       Particle3DService:EmitAt("Explosion", position, n)
--   end)

return {
	Explode = {
		Friction    = 5,
		TrailFix    = "Trail",
		Acceleration = Vector3.new(0, -300, 0),
		Bounce      = 0.3,
		Speed       = NumberRange.new(40, 60),
		Collisions  = true,
		Spread      = Vector2.new(25, 25),
		LifeTime    = NumberRange.new(3, 5),
	},
}
