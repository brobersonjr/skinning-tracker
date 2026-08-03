-- Minimal WoW API stubs, enough to load SkinningTracker.lua in a plain Lua VM.
--
-- Only the surface the addon actually touches at load time or in the pure-logic
-- paths under test. Anything genuinely client-side (frames, timers, tooltips)
-- is a no-op recorder: the point is to exercise state transitions, not to
-- simulate the client. In-game verification is still required.

local M = {}

-- Controllable clock. Tests drive this directly instead of waiting.
M.now = 1000000
M.secondsUntilReset = 43200 -- 12h, so lastReset = now - 43200

M.printed = {}
M.events = {}
M.frames = {}

local function makeFrame()
    local f = {
        _events = {},
        _scripts = {},
    }
    function f:RegisterEvent(e) self._events[e] = true end
    function f:UnregisterEvent(e) self._events[e] = nil end
    function f:SetScript(k, fn) self._scripts[k] = fn end
    function f:GetScript(k) return self._scripts[k] end
    -- Fire an event as the client would
    function f:Fire(...) if self._scripts.OnEvent then self._scripts.OnEvent(self, ...) end end
    table.insert(M.frames, f)
    return f
end

function M.install(env)
    env.time = os.time
    env.date = os.date

    env.CreateFrame = function() return makeFrame() end

    env.C_DateAndTime = {
        GetServerTime = function() return M.now end,
        GetSecondsUntilDailyReset = function() return M.secondsUntilReset end,
    }

    env.C_Timer = {
        -- Run immediately: every deferred call in the addon is a one-frame
        -- defer, and the tests want the resulting state synchronously.
        After = function(_, fn) fn() end,
        NewTicker = function() return { Cancel = function() end } end,
    }

    env.UnitName    = function() return M.playerName or "Tester" end
    env.GetRealmName= function() return M.realmName or "TestRealm" end
    env.UnitClass   = function() return "Hunter", "HUNTER" end
    env.UnitGUID    = function() return nil end
    env.IsSpellKnown= function() return M.spellKnown end
    env.PlaySound   = function() return true end
    env.SecondsToTime = function(s) return tostring(math.floor(s)) .. "s" end

    env.SlashCmdList   = {}
    env.UISpecialFrames = {}

    env.LOOT_ITEM_SELF          = "You receive loot: %s."
    env.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

    env.strtrim = function(s, chars)
        chars = chars or " \t\r\n"
        local pat = "[" .. chars:gsub("(%W)", "%%%1") .. "]"
        return (s:gsub("^" .. pat .. "+", ""):gsub(pat .. "+$", ""))
    end
    env.strsplit = function(sep, s)
        local out = {}
        for part in tostring(s):gmatch("([^" .. sep .. "]+)") do table.insert(out, part) end
        return table.unpack(out)
    end

    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        table.insert(M.printed, table.concat(parts, " "))
    end

    return env
end

-- ---------------------------------------------------------------------------
-- Auctionator stub
-- ---------------------------------------------------------------------------
-- Mirrors the shape of the real v1 API rather than the addon's own wrapper, so
-- the tests exercise the same access path the client does — including the fact
-- that every entry point raises via error() on a bad caller ID or argument
-- type, which is what the wrapper's pcall exists to absorb.

M.prices = {}   -- itemId -> copper
M.ages   = {}   -- itemId -> days since last scan
M.auctionatorThrows = false  -- simulate an API that raises on every call
M.auctionatorHasDB  = true   -- Auctionator loaded but DB not built yet

-- opts.throws / opts.hasDB override the module defaults for one install
function M.installAuctionator(env, opts)
    opts = opts or {}
    local throws = opts.throws
    if throws == nil then throws = M.auctionatorThrows end
    local hasDB = opts.hasDB
    if hasDB == nil then hasDB = M.auctionatorHasDB end

    local function verify(callerID, itemID)
        if type(callerID) ~= "string" or callerID == "" then
            error("Invalid callerID. Use the name of your add-on.")
        end
        if itemID ~= nil and type(itemID) ~= "number" then
            error("Usage: expected a number")
        end
        if throws then error("simulated Auctionator failure") end
    end

    env.Auctionator = {
        API = {
            v1 = {
                GetAuctionPriceByItemID = function(callerID, itemID)
                    verify(callerID, itemID)
                    if not hasDB then return nil end
                    return M.prices[itemID]
                end,
                GetAuctionAgeByItemID = function(callerID, itemID)
                    verify(callerID, itemID)
                    if not hasDB then return nil end
                    return M.ages[itemID]
                end,
                RegisterForDBUpdate = function(callerID, callback)
                    verify(callerID)
                    if type(callback) ~= "function" then error("Usage: expected a function") end
                    M.dbUpdateCallback = callback
                end,
            },
        },
    }
end

function M.removeAuctionator(env)
    env.Auctionator = nil
    M.dbUpdateCallback = nil
end

-- Reset per-test state. Deliberately does NOT clear M.frames: the addon creates
-- its event frames once at load, so dropping them would leave later tests with
-- no PLAYER_LOGIN handler to fire.
function M.reset()
    M.printed = {}
    _G.SkinningTrackerDB = nil
end

return M
