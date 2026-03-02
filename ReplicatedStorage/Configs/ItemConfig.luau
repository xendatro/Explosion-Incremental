-- ItemConfig.luau
-- Defines every item in the game.
--
-- Fields:
--   Name          Display name shown in the ProximityPrompt and billboard.
--   Biomes        Optional list of biome IDs this item can spawn in.
--                 Absent or empty = spawns in any biome.
--   Rarity        Required. Single rarity string — the item always spawns at this rarity.
--                 Valid values: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Exotic"
--   Weight        Base weight range { min, max } in kg on a "normal" scale.
--                 Final carried weight = roll(min, max)
--                                       × RarityWeightMultipliers[rarity]
--                                       × BiomeWeightMultipliers[biome]
--   BaseValue     Base coin value before rarity and biome multipliers.
--   BaseGemValue  Base gem quantity before rarity and biome multipliers.
--   ModelName     Exact name of the Model inside ReplicatedStorage/ItemModels/.

return {

	-- ── Biome 1 ──────────────────────────────────────────────────────────────────
	-- Common (12)

	{
		Name         = "Wooden Table",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 5.0, 9.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Wooden Table",
	},

	{
		Name         = "Barrier",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 4.0, 7.0 },
		BaseValue    = 8,
		BaseGemValue = 1,
		ModelName    = "Barrier",
	},

	{
		Name         = "Bottle of Water",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Bottle of Water",
	},

	{
		Name         = "Lettuce",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Lettuce",
	},

	{
		Name         = "Milk",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 1.5, 2.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Milk",
	},

	{
		Name         = "Cheese Slice",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Cheese Slice",
	},

	{
		Name         = "Soda Can",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.8, 1.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Soda Can",
	},

	{
		Name         = "French Fries",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "French Fries",
	},

	{
		Name         = "Banana Bunch",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Banana Bunch",
	},

	{
		Name         = "Taco",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.4, 0.9 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Taco",
	},

	{
		Name         = "Sandwich",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.2 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Sandwich",
	},

	{
		Name         = "Pretzel",
		Biomes       = { 1 },
		Rarity       = "Common",
		Weight       = { 0.3, 0.7 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Pretzel",
	},

	-- Uncommon (7)

	{
		Name         = "Watermelon Slice",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 1.5, 3.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Watermelon Slice",
	},

	{
		Name         = "Cherry Soda",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Cherry Soda",
	},

	{
		Name         = "Orange Juice",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Orange Juice",
	},

	{
		Name         = "Donut",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Donut",
	},

	{
		Name         = "Pineapple",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 1.5, 3.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Pineapple",
	},

	{
		Name         = "Pizza Slice",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 0.8, 1.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Pizza Slice",
	},

	{
		Name         = "Croissant",
		Biomes       = { 1 },
		Rarity       = "Uncommon",
		Weight       = { 0.3, 0.7 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Croissant",
	},

	-- Rare (4)

	{
		Name         = "Steak",
		Biomes       = { 1 },
		Rarity       = "Rare",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Steak",
	},

	{
		Name         = "Cake",
		Biomes       = { 1 },
		Rarity       = "Rare",
		Weight       = { 2.0, 4.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Cake",
	},

	{
		Name         = "Choco Cookie",
		Biomes       = { 1 },
		Rarity       = "Rare",
		Weight       = { 0.3, 0.8 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Choco Cookie",
	},

	{
		Name         = "Sushi",
		Biomes       = { 1 },
		Rarity       = "Rare",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Sushi",
	},

	-- Epic (2)

	{
		Name         = "Gold Trophy",
		Biomes       = { 1 },
		Rarity       = "Epic",
		Weight       = { 2.0, 4.0 },
		BaseValue    = 8,
		BaseGemValue = 3,
		ModelName    = "Gold Trophy",
	},

	{
		Name         = "Television",
		Biomes       = { 1 },
		Rarity       = "Epic",
		Weight       = { 6.0, 12.0 },
		BaseValue    = 8,
		BaseGemValue = 3,
		ModelName    = "Television",
	},

	-- Legendary (1)

	{
		Name         = "Guitar",
		Biomes       = { 1 },
		Rarity       = "Legendary",
		Weight       = { 3.0, 5.0 },
		BaseValue    = 8,
		BaseGemValue = 4,
		ModelName    = "Guitar",
	},

	-- Mythic (1)

	{
		Name         = "Unknown Pie",
		Biomes       = { 1 },
		Rarity       = "Mythic",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 5,
		ModelName    = "Unknown Pie",
	},

	-- Exotic (1)

	{
		Name         = "Rubber Duck",
		Biomes       = { 1 },
		Rarity       = "Exotic",
		Weight       = { 0.1, 0.3 },
		BaseValue    = 8,
		BaseGemValue = 6,
		ModelName    = "Rubber Duck",
	},

	-- ── Biome 2 ──────────────────────────────────────────────────────────────────
	-- Common (12)

	{
		Name         = "Bed",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 8.0, 14.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Bed",
	},

	{
		Name         = "Cup of Coffee",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Cup of Coffee",
	},

	{
		Name         = "Granny Smith Apple",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.3, 0.8 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Granny Smith Apple",
	},

	{
		Name         = "Fuji Apple",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.3, 0.8 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Fuji Apple",
	},

	{
		Name         = "Waffle",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.4, 0.8 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Waffle",
	},

	{
		Name         = "Popcorn",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.2, 0.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Popcorn",
	},

	{
		Name         = "Carrot",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.2, 0.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Carrot",
	},

	{
		Name         = "Tomato",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.3, 0.6 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Tomato",
	},

	{
		Name         = "Lemon",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.2, 0.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Lemon",
	},

	{
		Name         = "Candle",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.3, 0.6 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Candle",
	},

	{
		Name         = "Book",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Book",
	},

	{
		Name         = "Pillow",
		Biomes       = { 2 },
		Rarity       = "Common",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Pillow",
	},

	-- Uncommon (7)

	{
		Name         = "Ice Cream",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Ice Cream",
	},

	{
		Name         = "Cupcake",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 0.3, 0.6 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Cupcake",
	},

	{
		Name         = "Fried Chicken",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 0.8, 1.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Fried Chicken",
	},

	{
		Name         = "Desk Lamp",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 1.5, 3.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Desk Lamp",
	},

	{
		Name         = "Backpack",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 1.0, 2.5 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Backpack",
	},

	{
		Name         = "Paint Bucket",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 2.0, 4.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Paint Bucket",
	},

	{
		Name         = "Umbrella",
		Biomes       = { 2 },
		Rarity       = "Uncommon",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Umbrella",
	},

	-- Rare (4)

	{
		Name         = "Wooden Chair",
		Biomes       = { 2 },
		Rarity       = "Rare",
		Weight       = { 4.0, 7.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Wooden Chair",
	},

	{
		Name         = "Fire Extinguisher",
		Biomes       = { 2 },
		Rarity       = "Rare",
		Weight       = { 4.0, 8.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Fire Extinguisher",
	},

	{
		Name         = "Bowling Pin",
		Biomes       = { 2 },
		Rarity       = "Rare",
		Weight       = { 1.0, 2.0 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Bowling Pin",
	},

	{
		Name         = "Teddy Bear",
		Biomes       = { 2 },
		Rarity       = "Rare",
		Weight       = { 0.5, 1.2 },
		BaseValue    = 8,
		BaseGemValue = 2,
		ModelName    = "Teddy Bear",
	},

	-- Epic (2)

	{
		Name         = "Skateboard",
		Biomes       = { 2 },
		Rarity       = "Epic",
		Weight       = { 2.0, 4.0 },
		BaseValue    = 8,
		BaseGemValue = 3,
		ModelName    = "Skateboard",
	},

	{
		Name         = "Traffic Cone",
		Biomes       = { 2 },
		Rarity       = "Epic",
		Weight       = { 1.5, 3.5 },
		BaseValue    = 8,
		BaseGemValue = 3,
		ModelName    = "Traffic Cone",
	},

	-- Legendary (1)

	{
		Name         = "Cardboard Box",
		Biomes       = { 2 },
		Rarity       = "Legendary",
		Weight       = { 1.0, 3.0 },
		BaseValue    = 8,
		BaseGemValue = 4,
		ModelName    = "Cardboard Box",
	},

	-- Mythic (1)

	{
		Name         = "Basketball",
		Biomes       = { 2 },
		Rarity       = "Mythic",
		Weight       = { 0.5, 1.0 },
		BaseValue    = 8,
		BaseGemValue = 5,
		ModelName    = "Basketball",
	},

	-- Exotic (1)

	{
		Name         = "Soccer Ball",
		Biomes       = { 2 },
		Rarity       = "Exotic",
		Weight       = { 0.4, 0.8 },
		BaseValue    = 8,
		BaseGemValue = 6,
		ModelName    = "Soccer Ball",
	},

}
