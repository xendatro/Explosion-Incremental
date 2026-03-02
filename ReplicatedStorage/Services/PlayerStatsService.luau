-- Client-side mirror of player stats. Read-only — server is the authority.
local PlayerStatsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EN = require(ReplicatedStorage.Classes.EternityNum)

local commsStats   = ReplicatedStorage:WaitForChild("Communication"):WaitForChild("Stats")
local StatUpdated  = commsStats:WaitForChild("StatUpdated")  :: RemoteEvent
local AllStatsInit = commsStats:WaitForChild("AllStatsInit") :: RemoteEvent

-- Stats that are EternityNum on the server. The server sends these as EN strings
-- ("Layer;Exp"). GetStat returns an EN table for these; use EN.short() for display.
local BIG_STATS: { [string]: true } = {
	Coins    = true,
	Strength = true,
}

-- { [statName]: EN | number }
local stats: { [string]: any } = {}

-- { [statName]: { callback } }
local listeners: { [string]: { (any) -> () } } = {}

local function notify(statName: string, value: any)
	if listeners[statName] then
		for _, cb in listeners[statName] do
			cb(value)
		end
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Returns an EN table for big stats (Coins, Strength), a plain number otherwise.
-- Display big stats with EN.short(value).
function PlayerStatsService:GetStat(statName: string): any
	if stats[statName] ~= nil then
		return stats[statName]
	end
	return BIG_STATS[statName] and EN.convert(0) or 0
end

-- Register a callback that fires whenever a specific stat changes.
-- Returns a disconnect function.
function PlayerStatsService:OnStatChanged(statName: string, callback: (any) -> ()): () -> ()
	if not listeners[statName] then
		listeners[statName] = {}
	end
	table.insert(listeners[statName], callback)

	return function()
		local list = listeners[statName]
		if list then
			table.remove(list, table.find(list, callback))
		end
	end
end

-- ── Receive updates from server ───────────────────────────────────────────────

AllStatsInit.OnClientEvent:Connect(function(allStats: { [string]: any })
	for name, value in allStats do
		-- Big stats arrive as EN strings; convert to EN tables locally.
		stats[name] = BIG_STATS[name] and EN.convert(value) or value
		notify(name, stats[name])
	end
end)

StatUpdated.OnClientEvent:Connect(function(statName: string, value: any)
	local converted = BIG_STATS[statName] and EN.convert(value) or value
	stats[statName] = converted
	notify(statName, converted)

	-- ── UI ANIMATION HOOKS ────────────────────────────────────────────────────
	-- Add custom visual feedback for stat updates here.
	-- `statName` is the key; `converted` is the new value.
	--
	-- "Strength" fires on EVERY strength update — both manual clicks AND autotrain.
	--   converted = EN table (use EN.short() to display)
	--
	-- "Coins" fires on every explosion payout and generator tick.
	--   converted = EN table (use EN.short() to display)
	--
	-- "Gems" fires whenever gems are awarded from a manual explosion.
	--   converted = plain number
	--
	-- Example:
	--   if statName == "Strength" then
	--       -- e.g., pulse the Strength label, play a flash
	--   elseif statName == "Coins" then
	--       -- e.g., coin counter bounce animation
	--   elseif statName == "Gems" then
	--       -- e.g., gem counter glow
	--   end
	-- ─────────────────────────────────────────────────────────────────────────
end)

return PlayerStatsService
