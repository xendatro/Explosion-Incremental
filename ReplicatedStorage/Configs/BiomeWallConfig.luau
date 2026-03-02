-- BiomeWallConfig.luau
-- Names and unlock costs for each biome.
-- BiomeIndex 1 is always unlocked (starting biome, no wall).
-- Add new entries here when new biomes are built.

return {

	-- Display name per biome (shown on the unlock board).
	BiomeNames = {
		[1] = "Neighborhood",
		[2] = "Desert",
		[3] = "???",
		[4] = "???",
		[5] = "???",
	},

	-- Coin cost to unlock each biome (key = the biome being unlocked).
	-- Biome 1 has no entry — it's always unlocked.
	UnlockCosts = {
		[2] = 1_000,
		[3] = 10_000,
		[4] = 100_000,
		[5] = 1_000_000,
	},

	-- Total number of biomes. Caps MaxBiomeUnlocked on the server.
	MaxBiome = 5,

}
