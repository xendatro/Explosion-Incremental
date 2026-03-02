-- BiomeConfig.luau
-- Per-biome scaling multipliers.
-- All three tables use the same index (BiomeId integer, starting at 1).
-- Each step up multiplies by a fixed factor:
--   Weight  : ×4 per biome  (1 → 4 → 16 → 64 → 256)
--   Coins   : ×5 per biome  (1 → 5 → 25 → 125 → 625)
--   Gems    : ×3 per biome  (1 → 3 → 9  → 27  → 81)
--
-- Add new entries here when new biomes are designed.

return {

	-- Multiplier applied to an item's rolled base weight.
	-- Higher biome → heavier items → more Strength required.
	BiomeWeightMultipliers = {
		[1] = 1,
		[2] = 4,
		[3] = 16,
		[4] = 64,
		[5] = 256,
	},

	-- Multiplier applied to BaseValue before the rarity coin multiplier.
	-- Higher biome → more coins per explosion.
	BiomeCoinMultipliers = {
		[1] = 1,
		[2] = 5,
		[3] = 25,
		[4] = 125,
		[5] = 625,
	},

	-- Multiplier applied to BaseGemValue before the rarity gem multiplier.
	-- Higher biome → more gems per explosion.
	BiomeGemMultipliers = {
		[1] = 1,
		[2] = 3,
		[3] = 9,
		[4] = 27,
		[5] = 81,
	},

}
