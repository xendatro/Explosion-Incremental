-- ExploderConfig.luau
-- Tuning for the Exploder machine.

return {

	-- Gem payout multipliers per rarity.
	-- Gems awarded = floor(BaseGemValue × RarityGemMultipliers[rarity])
	-- where BaseGemValue comes from the item's definition in ItemConfig.
	RarityGemMultipliers = {
		Common    = 1,
		Uncommon  = 2,
		Rare      = 5,
		Epic      = 12,
		Legendary = 30,
		Mythic    = 80,
		Exotic    = 250,
	},

}
