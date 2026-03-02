-- RarityConfig.luau
-- Defines display properties for each rarity tier.
-- Tiers ordered from worst (Common) to best (Exotic).
--
-- Color is used for rarity text in the item BillboardGui, and for any future
-- rarity-tinted UI elements (border glows, leaderboard icons, etc.).

return {
	Common = {
		Color = Color3.fromRGB(180, 180, 180), -- Light grey
	},
	Uncommon = {
		Color = Color3.fromRGB(100, 210, 90),  -- Fresh green
	},
	Rare = {
		Color = Color3.fromRGB(80, 145, 255),  -- Vivid blue
	},
	Epic = {
		Color = Color3.fromRGB(180, 75, 245),  -- Deep purple
	},
	Legendary = {
		Color = Color3.fromRGB(255, 175, 45),  -- Bright gold
	},
	Mythic = {
		Color = Color3.fromRGB(255, 75, 150),  -- Hot magenta
	},
	Exotic = {
		Color = Color3.fromRGB(0, 225, 255),   -- Radiant cyan
	},
}
