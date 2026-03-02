-- GymConfig.luau
-- Tunable values for the Gym system.
-- All timing values are in seconds.

return {
	-- How often the server polls each player's position against the Zone part.
	ZoneCheckInterval = 0.5,

	-- How often an autotrain tick fires (awards one Strength increment).
	AutotrainInterval = 1.0,

	-- Minimum seconds between two valid manual clicks (server-side debounce).
	ClickDebounce = 0.05,
}
