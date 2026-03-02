-- DevCommandsService (Server)
-- Chat-based cheat commands. Require this module from your main server Script to activate.
--
-- Usage (in-game chat):
--   /give <playerName> coins <amount>
--   /give <playerName> gems <amount>
--   /give <playerName> strength <amount>
--
-- Only players whose names are in WHITELIST can run commands.

local DevCommandsService = {}

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage  = game:GetService("ServerStorage")

local PlayerStatsService = require(ServerStorage.Services.PlayerStatsService)
local EN                 = require(ReplicatedStorage.Classes.EternityNum)

-- ── Whitelist ─────────────────────────────────────────────────────────────────

local WHITELIST: { string } = {
	"xendatro",
}

local function isAllowed(player: Player): boolean
	local name = player.Name:lower()
	for _, allowed in WHITELIST do
		if name == allowed:lower() then return true end
	end
	return false
end

-- ── Command parser ────────────────────────────────────────────────────────────

local function findPlayer(name: string): Player?
	local lower = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == lower then return p end
	end
	return nil
end

local function handleCommand(sender: Player, message: string)
	local parts = message:split(" ")
	if #parts < 4 then return end
	if parts[1]:lower() ~= "/give" then return end

	local target = findPlayer(parts[2])
	if not target then
		warn(string.format("[DevCommands] Player not found: %s", parts[2]))
		return
	end

	local stat   = parts[3]:lower()
	local amount = tonumber(parts[4])
	if not amount then
		warn("[DevCommands] Invalid amount: " .. parts[4])
		return
	end

	if stat == "coins" then
		PlayerStatsService:IncrementStat(target, "Coins", EN.convert(amount))
		print(string.format("[DevCommands] Gave %s %s Coins → %s", target.Name, amount, EN.short(PlayerStatsService:GetStat(target, "Coins"))))
	elseif stat == "gems" then
		PlayerStatsService:IncrementStat(target, "Gems", amount)
		print(string.format("[DevCommands] Gave %s %d Gems", target.Name, amount))
	elseif stat == "strength" then
		PlayerStatsService:IncrementStat(target, "Strength", EN.convert(amount))
		print(string.format("[DevCommands] Gave %s %s Strength → %s", target.Name, amount, EN.short(PlayerStatsService:GetStat(target, "Strength"))))
	else
		warn("[DevCommands] Unknown stat: " .. parts[3] .. " (use coins, gems, or strength)")
	end
end

-- ── Wire chat listeners ───────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	player.Chatted:Connect(function(message: string)
		if not isAllowed(player) then return end
		handleCommand(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

return DevCommandsService
