-- UpgradeConfig.luau
-- Defines every purchasable upgrade shown on the Upgrade Boards.
--
-- Fields per upgrade entry:
--   Currency   "Coins" or "Strength" — which stat is deducted on purchase.
--   BoardType  "Plot" or "Player" — which board shows this upgrade.
--   MaxLevel   Level cap; no purchase possible at or above this. nil = no cap.
--   Cost(level)  Returns the currency cost to upgrade FROM the given level to level+1.
--                Receives the player's current level (1-indexed).
--   Value(level) Returns the effective stat value AT the given level.
--
-- The key MUST exactly match the stat name in PlayerStatsService.

return {

	-- ── Plot Upgrader board ───────────────────────────────────────────────────

	ExploderLevel = {
		Currency  = "Coins",
		BoardType = "Plot",
		MaxLevel  = nil,

		Cost = function(level: number): number
			return level * 10
		end,

		-- Coin payout multiplier at this level (used by ExploderService).
		Value = function(level: number): number
			return level
		end,
	},

	GymLevel = {
		Currency  = "Coins",
		BoardType = "Plot",
		MaxLevel  = nil,

		Cost = function(level: number): number
			return level * 10
		end,

		-- Base strength gained per gym action at this level (used by GymService).
		Value = function(level: number): number
			return level
		end,
	},

	-- ── Player Upgrader board ─────────────────────────────────────────────────

	SprintSpeedLevel = {
		Currency  = "Coins",
		BoardType = "Player",
		MaxLevel  = nil,

		-- Quadratic cost: 50 at level 1, grows as 50 * level^2.
		Cost = function(level: number): number
			return 50 * level * level
		end,

		-- +1 walkspeed per level, starting from 16 at level 1.
		Value = function(level: number): number
			return 16 + (level - 1)
		end,
	},

	CarryKgLimit = {
		Currency  = "Strength",
		BoardType = "Player",
		MaxLevel  = nil,

		-- Costs Strength (an EternityNum stat); plain numbers are accepted by DeductStrength.
		Cost = function(level: number): number
			return level * 10
		end,

		-- Level 1 = 0 kg (can't carry anything), +1 kg per level.
		Value = function(level: number): number
			return level - 1
		end,
	},

}
