-- Regression tests for Auctionator-backed session and lifetime gold (1.5.0).
--
-- Covers the pure-logic half of the feature: reading prices through the
-- Auctionator v1 API, summing counts into a value, reporting what could not be
-- priced, and money formatting. The frames, tooltips and the bottom-bar label
-- itself are stubbed to no-ops and still need an in-game /reload.

package.path = (TEST_DIR or "tests") .. "/?.lua;" .. package.path
local stubs = require("wow-stubs")
stubs.install(_G)
stubs.spellKnown = true

local function loadAddonFile(name)
    local chunk, err = loadfile(ADDON_DIR and (ADDON_DIR .. "/" .. name) or name)
    if not chunk then error("could not load " .. name .. ": " .. tostring(err)) end
    chunk()
end

loadAddonFile("SkinningTracker.lua")
loadAddonFile("SkinningTrackerPrices.lua")

local ST = _G.SkinningTracker

-- ---------------------------------------------------------------------------
-- Tiny assertion harness (same shape as manual-edit-tests.lua)
-- ---------------------------------------------------------------------------
local pass, fail = 0, 0
local failures = {}

local function check(name, cond, detail)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        table.insert(failures, name .. (detail and ("  -- " .. detail) or ""))
    end
end

local function eq(name, got, want)
    check(name, got == want, string.format("got %s, want %s", tostring(got), tostring(want)))
end

local function login()
    for _, f in ipairs(stubs.frames) do
        if f._events["PLAYER_LOGIN"] then f:Fire("PLAYER_LOGIN") end
    end
end

local function fireLoot(msg)
    for _, f in ipairs(stubs.frames) do
        if f._events["CHAT_MSG_LOOT"] then f:Fire("CHAT_MSG_LOOT", msg) end
    end
end

local CLAW, HIDE, FIN = 238528, 238529, 238530
local GOLD = 10000

-- Reset everything a test could have dirtied, including the Auctionator stub.
local function fresh(auctionatorOpts)
    stubs.reset()
    stubs.now = 1000000
    stubs.prices = {}
    stubs.ages = {}
    if auctionatorOpts == nil then
        stubs.installAuctionator(_G, {})
    elseif auctionatorOpts == false then
        stubs.removeAuctionator(_G)
    else
        stubs.installAuctionator(_G, auctionatorOpts)
    end
    login()
end

local function charData()
    return SkinningTrackerDB[ST:GetCharKey()]
end

-- ---------------------------------------------------------------------------
-- 1. Auctionator absent
-- ---------------------------------------------------------------------------
fresh(false)
eq("no Auctionator: HasPriceSource is false", ST:HasPriceSource(), false)
eq("no Auctionator: GetItemPrice is nil", ST:GetItemPrice(CLAW), nil)

ST.sessionItems[CLAW] = 5
local copper, unpriced = ST:GetSessionValue()
eq("no Auctionator: session value is zero", copper, 0)
eq("no Auctionator: the looted item counts as unpriced", unpriced, 1)

-- ---------------------------------------------------------------------------
-- 2. Auctionator loaded but its database is not built yet
-- ---------------------------------------------------------------------------
fresh({ hasDB = false })
eq("no DB: HasPriceSource is still true", ST:HasPriceSource(), true)
eq("no DB: GetItemPrice is nil", ST:GetItemPrice(CLAW), nil)
ST.sessionItems[CLAW] = 3
copper, unpriced = ST:GetSessionValue()
eq("no DB: value is zero", copper, 0)
eq("no DB: reported as unpriced", unpriced, 1)

-- ---------------------------------------------------------------------------
-- 3. An API that raises must not escape the wrapper
-- ---------------------------------------------------------------------------
fresh({ throws = true })
stubs.prices[CLAW] = 5 * GOLD
local ok, err = pcall(function() return ST:GetItemPrice(CLAW) end)
check("throwing API does not propagate out of GetItemPrice", ok, tostring(err))
eq("throwing API yields no price", ST:GetItemPrice(CLAW), nil)

ST.sessionItems[CLAW] = 2
ok = pcall(function() return ST:GetSessionValue() end)
check("throwing API does not propagate out of GetSessionValue", ok)
copper, unpriced = ST:GetSessionValue()
eq("throwing API values at zero", copper, 0)
eq("throwing API reports unpriced", unpriced, 1)

-- ---------------------------------------------------------------------------
-- 4. Fully priced session
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 12 * GOLD
stubs.prices[HIDE] = 30 * GOLD
stubs.prices[FIN]  = 7 * GOLD

ST.sessionItems[CLAW] = 4      -- 48g
ST.sessionItems[HIDE] = 2      -- 60g

copper, unpriced = ST:GetSessionValue()
eq("session value sums priced counts", copper, 108 * GOLD)
eq("session value has nothing unpriced", unpriced, 0)

-- Items that never dropped are not a gap in the data
eq("zero-count items are not counted as unpriced", select(2, ST:GetSessionValue()), 0)

-- Stored lifetime counts must NOT be valued anywhere. They only ever increment,
-- so a figure built from them would be neither gold earned nor the worth of
-- what is actually in the bags. Removed in review; this guards the regression.
charData().items[CLAW] = 100
eq("stored item counts do not leak into the session value",
    ST:GetSessionValue(), 108 * GOLD)
eq("no lifetime valuation helper is exposed", ST.GetLifetimeValue, nil)

-- ---------------------------------------------------------------------------
-- 5. Partial pricing understates, and says so
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 12 * GOLD
-- HIDE deliberately has no price
ST.sessionItems[CLAW] = 4
ST.sessionItems[HIDE] = 2

copper, unpriced = ST:GetSessionValue()
eq("partial pricing sums only what it can price", copper, 48 * GOLD)
eq("partial pricing counts the missing material", unpriced, 1)

-- A price of zero is treated as no price, not as free
fresh()
stubs.prices[CLAW] = 0
ST.sessionItems[CLAW] = 4
copper, unpriced = ST:GetSessionValue()
eq("a zero price is rejected", copper, 0)
eq("a zero price counts as unpriced", unpriced, 1)

-- ---------------------------------------------------------------------------
-- 6. Empty input
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 12 * GOLD
copper, unpriced = ST:GetSessionValue()
eq("empty session values at zero", copper, 0)
eq("empty session has nothing unpriced", unpriced, 0)
eq("GetValueOf tolerates nil", ST:GetValueOf(nil), 0)
eq("GetValueOf tolerates a non-table", ST:GetValueOf("nonsense"), 0)

-- ---------------------------------------------------------------------------
-- 7. Scan age: the worst age across priced materials wins
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 12 * GOLD
stubs.prices[HIDE] = 30 * GOLD
stubs.ages[CLAW] = 2
stubs.ages[HIDE] = 9
ST.sessionItems[CLAW] = 1
ST.sessionItems[HIDE] = 1
local _, _, age = ST:GetSessionValue()
eq("oldest scan age is reported", age, 9)

-- Auctionator returns nil past 21 days, so a price with no age is very stale
fresh()
stubs.prices[CLAW] = 12 * GOLD
ST.sessionItems[CLAW] = 1
local price, itemAge = ST:GetItemPrice(CLAW)
eq("price with no age still returns the price", price, 12 * GOLD)
eq("unknown age is nil, not zero", itemAge, nil)

-- ---------------------------------------------------------------------------
-- 8. Only tracked materials are valued
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 12 * GOLD
stubs.prices[99999] = 500 * GOLD
copper = ST:GetValueOf({ [CLAW] = 1, [99999] = 10 })
eq("untracked items in the count table are ignored", copper, 12 * GOLD)

-- ---------------------------------------------------------------------------
-- 9. The real loot path feeds the session value
-- ---------------------------------------------------------------------------
fresh()
stubs.prices[CLAW] = 25 * GOLD
charData().isMidnightSkinner = true
fireLoot("You receive loot: |cffa335ee|Hitem:238528:0:0:0:0:0:0:0:0:0:0|h[Majestic Claw]|h|r.")
fireLoot("You receive loot: |cffa335ee|Hitem:238528:0:0:0:0:0:0:0:0:0:0|h[Majestic Claw]|h|rx3.")
eq("loot handler recorded the session count", ST.sessionItems[CLAW], 4)
eq("session value follows the loot handler", ST:GetSessionValue(), 100 * GOLD)

-- An auction house purchase must not inflate the figure
fireLoot("You receive item: |cffa335ee|Hitem:238528:0:0:0:0:0:0:0:0:0:0|h[Majestic Claw]|h|rx50.")
eq("a bought stack does not change the session value", ST:GetSessionValue(), 100 * GOLD)

-- ---------------------------------------------------------------------------
-- 10. Session value is session-only
-- ---------------------------------------------------------------------------
local storedBefore = charData().items[CLAW]
login() -- a fresh login on the same character, as /reload or a relog would be
eq("session value is cleared by login", ST:GetSessionValue(), 0)
eq("the stored item count still survives login", charData().items[CLAW], storedBefore)
eq("nothing was written to SavedVariables for the session",
    SkinningTrackerDB[ST:GetCharKey()].sessionValue, nil)

-- ---------------------------------------------------------------------------
-- 11. Money formatting
-- ---------------------------------------------------------------------------
_G.GetMoneyString = nil -- exercise the arithmetic fallback first

eq("format 0",            ST:FormatMoney(0),        "0c")
eq("format sub-silver",   ST:FormatMoney(7),        "7c")
eq("format 99 copper",    ST:FormatMoney(99),       "99c")
eq("format exact silver", ST:FormatMoney(100),      "1s 00c")
eq("format sub-gold",     ST:FormatMoney(9999),     "99s 99c")
eq("format exact gold",   ST:FormatMoney(GOLD),     "1g 00s 00c")
eq("format mixed",        ST:FormatMoney(123456),   "12g 34s 56c")
eq("format nil as zero",  ST:FormatMoney(nil),      "0c")

eq("short format keeps precision below a gold", ST:FormatMoneyShort(9999), "99s 99c")
eq("short format at one gold",     ST:FormatMoneyShort(GOLD),           "1g")
eq("short format truncates",       ST:FormatMoneyShort(GOLD + 9999),    "1g")
eq("short format thousands",       ST:FormatMoneyShort(1234 * GOLD),    "1,234g")
eq("short format nil as zero",     ST:FormatMoneyShort(nil),            "0c")

-- Written as a float multiply on purpose. fengari's integers wrap at 32 bits,
-- so `1234567 * 10000` as integers overflows here — but WoW's Lua 5.1 has no
-- integer subtype at all and represents every number as a double, so a float is
-- the faithful stand-in for what the client actually passes in. This is also
-- the case that would render as "1,234,567.0" if the formatter used tostring.
eq("short format millions", ST:FormatMoneyShort(1234567 * 10000.0), "1,234,567g")
eq("format millions exactly", ST:FormatMoney(1234567 * 10000.0), "1234567g 00s 00c")

-- Blizzard's formatter is preferred when the client provides one
_G.GetMoneyString = function(copperAmount) return "BLIZZ:" .. tostring(copperAmount) end
eq("Blizzard formatter is preferred", ST:FormatMoney(123456), "BLIZZ:123456")

-- ...but a broken one must not take the readout down with it
_G.GetMoneyString = function() error("boom") end
eq("a raising formatter falls back to arithmetic", ST:FormatMoney(123456), "12g 34s 56c")
_G.GetMoneyString = function() return "" end
eq("an empty formatter falls back to arithmetic", ST:FormatMoney(123456), "12g 34s 56c")
_G.GetMoneyString = nil

-- ---------------------------------------------------------------------------
-- 12. Scan callback refreshes the readout
-- ---------------------------------------------------------------------------
fresh()
check("RegisterForDBUpdate was called at login", type(stubs.dbUpdateCallback) == "function")

local refreshed = false
ST.UI = { Refresh = function() refreshed = true end }
stubs.dbUpdateCallback()
check("a completed scan refreshes the window", refreshed)
ST.UI = nil

-- ---------------------------------------------------------------------------
-- 13. /skt gold
-- ---------------------------------------------------------------------------
local function allPrinted()
    return table.concat(stubs.printed, "\n")
end

fresh(false)
SlashCmdList["SKINNINGTRACKER"]("gold")
check("/skt gold explains a missing Auctionator",
    allPrinted():find("Auctionator is not loaded") ~= nil, allPrinted())

fresh()
SlashCmdList["SKINNINGTRACKER"]("gold")
check("/skt gold with no loot says so",
    allPrinted():find("Nothing looted yet this session") ~= nil, allPrinted())

-- Stored lifetime counts alone must not make the command report anything:
-- only what was looted this session is valued.
fresh()
stubs.prices[CLAW] = 12 * GOLD
charData().items[CLAW] = 40
SlashCmdList["SKINNINGTRACKER"]("gold")
check("/skt gold ignores stored counts with an empty session",
    allPrinted():find("Nothing looted yet this session") ~= nil, allPrinted())

fresh()
stubs.prices[CLAW] = 12 * GOLD
stubs.ages[CLAW] = 3
ST.sessionItems[CLAW] = 4
SlashCmdList["SKINNINGTRACKER"]("gold")
check("/skt gold reports the material", allPrinted():find("Majestic Claw") ~= nil, allPrinted())
check("/skt gold reports the session total", allPrinted():find("Session value:") ~= nil, allPrinted())
check("/skt gold reports the scan age", allPrinted():find("scanned 3d ago") ~= nil, allPrinted())
check("/skt gold does not mention a lifetime figure",
    allPrinted():lower():find("lifetime") == nil, allPrinted())

fresh()
stubs.prices[CLAW] = 12 * GOLD
ST.sessionItems[CLAW] = 1
ST.sessionItems[HIDE] = 1 -- no price
SlashCmdList["SKINNINGTRACKER"]("gold")
check("/skt gold names the unpriced material",
    allPrinted():find("no price") ~= nil, allPrinted())
check("/skt gold marks the total as incomplete",
    allPrinted():find("incomplete") ~= nil, allPrinted())

-- `/skt value` is the same command
fresh()
stubs.prices[CLAW] = 12 * GOLD
ST.sessionItems[CLAW] = 1
SlashCmdList["SKINNINGTRACKER"]("value")
check("/skt value is an alias for /skt gold", allPrinted():find("Session value:") ~= nil, allPrinted())

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
io.write(string.format("\nPricing tests: %d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do io.write("  FAIL  " .. f .. "\n") end
if fail > 0 then os.exit(1) end
