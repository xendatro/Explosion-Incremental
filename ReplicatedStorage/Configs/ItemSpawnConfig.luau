-- ItemSpawnConfig.luau
-- Tuning values for item spawning and respawning.

return {
	-- Seconds after an item is consumed before a replacement spawns.
	RespawnDelay = 8,

	-- Maximum number of items that can exist at once in a single biome.
	MaxItemsPerBiome = 70,

	-- How high above the ground to place a spawned item (studs).
	SpawnHeightOffset = 0,

	-- Seconds a grounded item can sit untouched before it despawns and respawns.
	-- Timer pauses while the item is being carried or sitting on an Exploder.
	GroundDespawnTime = 90,

	-- Kept for potential future use (e.g. loot crates, random rerolls).
	-- Not used during normal item spawning — each item in ItemConfig has a fixed Rarity.
	RarityWeights = {
		Common    = 20,
		Uncommon  = 10,
		Rare      =  5,
		Epic      =  4,
		Legendary =  3,
		Mythic    =  2,
		Exotic    =  1,
	},

	-- Coin payout multiplier applied on top of BaseValue × BiomeCoinMultiplier.
	RarityMultipliers = {
		Common    =   1.0,
		Uncommon  =   1.5,
		Rare      =   3.0,
		Epic      =   7.0,
		Legendary =  20.0,
		Mythic    =  60.0,
		Exotic    = 200.0,
	},

	-- Physical weight multiplier applied on top of the item's base Weight range
	-- and the BiomeWeightMultiplier.
	-- Rarer items require more Strength to carry.
	RarityWeightMultipliers = {
		Common    =   1,
		Uncommon  =   3,
		Rare      =   8,
		Epic      =  20,
		Legendary =  60,
		Mythic    = 175,
		Exotic    = 500,
	},
}
