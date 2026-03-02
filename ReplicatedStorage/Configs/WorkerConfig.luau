-- WorkerConfig.luau
-- Tuning values for the Worker passive income system.
-- All costs are in gems. All intervals are in seconds.

return {
	-- ── Cap ────────────────────────────────────────────────────────────────────
	MaxWorkers = 5,

	-- ── Purchase cost ──────────────────────────────────────────────────────────
	-- Gem cost for the Nth worker: floor(BasePurchaseCost × PurchasePriceScale^(N-1))
	-- Worker #1 = 50 gems, Worker #2 = 90 gems, Worker #3 = 162 gems, etc.
	BasePurchaseCost   = 50,
	PurchasePriceScale = 1.8,

	-- ── Cycle timing ──────────────────────────────────────────────────────────
	-- Full cycle time in seconds: BaseInterval × SpeedDecayRate^SpeedLevel
	-- SpeedLevel 0 = 15s, Level 1 ≈ 12.75s, Level 2 ≈ 10.8s, etc.
	BaseInterval   = 15,
	SpeedDecayRate = 0.85,

	-- ── Upgrade costs ─────────────────────────────────────────────────────────
	-- Speed upgrade gem cost: ceil(SpeedBaseCost × SpeedPriceScale^currentLevel)
	SpeedBaseCost      = 30,
	SpeedPriceScale    = 2.0,

	-- Strength upgrade gem cost: ceil(StrengthBaseCost × StrengthPriceScale^currentLevel)
	StrengthBaseCost   = 50,
	StrengthPriceScale = 2.0,

	-- ── Strength capacity ─────────────────────────────────────────────────────
	-- Maximum item weight (kg) the worker can carry at a given StrengthLevel.
	-- Workers start at level 1 (10 kg). Each upgrade adds 10×n kg where n is
	-- the upgrade number:  10 → 20 → 40 → 70 → 110 → 160 → ...
	-- Formula: 5L² − 5L + 10  (L = StrengthLevel, minimum 1)
	StrengthCapacity = function(level: number): number
		local L = math.max(level, 1)
		return 5 * L * L - 5 * L + 10
	end,
}
