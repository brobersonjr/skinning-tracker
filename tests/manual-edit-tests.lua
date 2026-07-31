-- Regression tests for Manual Edit mode (1.4.8).
--
-- Covers the state transitions that are pure logic: marking, unmarking, the
-- auto-detection promotion rule, the daily-reset boundary, /skt reset, and the
-- slash-command parity path. Anything requiring frames or the client is out of
-- scope here and listed in the PR's in-game checklist instead.

package.path = (TEST_DIR or "tests") .. "/?.lua;" .. package.path
local stubs = require("wow-stubs")
stubs.install(_G)
stubs.spellKnown = true

-- Load the addon under the stubs
local chunk, err = loadfile(ADDON_DIR and (ADDON_DIR .. "/SkinningTracker.lua") or "SkinningTracker.lua")
if not chunk then error("could not load SkinningTracker.lua: " .. tostring(err)) end
chunk()

local ST = _G.SkinningTracker

-- ---------------------------------------------------------------------------
-- Tiny assertion harness
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

-- Fire PLAYER_LOGIN on the addon's load frame so InitDB runs
local function login()
    for _, f in ipairs(stubs.frames) do
        if f._events["PLAYER_LOGIN"] then f:Fire("PLAYER_LOGIN") end
    end
end

local function freshDB()
    stubs.reset()
    stubs.now = 1000000
    login()
end

local KEY = "Tester-TestRealm"
local BEAST = "gloomclaw"

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------
freshDB()
check("InitDB creates the character row", SkinningTrackerDB[KEY] ~= nil)
check("InitDB creates manualBeasts", type(SkinningTrackerDB[KEY].manualBeasts) == "table")

-- Legacy row predating manualBeasts is migrated, not overwritten
stubs.reset()
stubs.now = 1000000
SkinningTrackerDB = { [KEY] = { isMidnightSkinner = true, beasts = { gloomclaw = 999999 }, items = {} } }
login()
check("legacy row gains manualBeasts", type(SkinningTrackerDB[KEY].manualBeasts) == "table")
eq("legacy beast timestamp preserved", SkinningTrackerDB[KEY].beasts.gloomclaw, 999999)

-- ---------------------------------------------------------------------------
-- 2. Manual mark / unmark round trip
-- ---------------------------------------------------------------------------
freshDB()
eq("starts unskinned", ST:HasSkinnedToday(BEAST), false)
eq("starts not manual", ST:WasManuallyMarked(BEAST), false)

ST:ToggleSkinnedManual(BEAST)
eq("manual mark sets skinned", ST:HasSkinnedToday(BEAST), true)
eq("manual mark sets manual flag", ST:WasManuallyMarked(BEAST), true)

ST:ToggleSkinnedManual(BEAST)
eq("manual unmark clears skinned", ST:HasSkinnedToday(BEAST), false)
eq("manual unmark clears manual flag", ST:WasManuallyMarked(BEAST), false)

-- ---------------------------------------------------------------------------
-- 3. Auto-detection outranks a manual mark
-- ---------------------------------------------------------------------------
freshDB()
ST:MarkSkinned(BEAST)
eq("auto mark sets skinned", ST:HasSkinnedToday(BEAST), true)
eq("auto mark is not manual", ST:WasManuallyMarked(BEAST), false)

freshDB()
ST:ToggleSkinnedManual(BEAST)
eq("manual first: flagged", ST:WasManuallyMarked(BEAST), true)
ST:MarkSkinned(BEAST)
eq("auto detection promotes to auto", ST:WasManuallyMarked(BEAST), false)
eq("auto detection keeps it skinned", ST:HasSkinnedToday(BEAST), true)

-- ---------------------------------------------------------------------------
-- 4. Daily reset boundary: a stale manual flag must go inert on its own
-- ---------------------------------------------------------------------------
freshDB()
ST:ToggleSkinnedManual(BEAST)
eq("marked before reset", ST:HasSkinnedToday(BEAST), true)
stubs.now = stubs.now + 86400 -- cross one daily reset while still "logged in"
eq("unskinned after reset", ST:HasSkinnedToday(BEAST), false)
eq("manual flag inert after reset", ST:WasManuallyMarked(BEAST), false)
check("stale manual flag was left in place, not cleaned up",
    SkinningTrackerDB[KEY].manualBeasts[BEAST] ~= nil)

-- Guard: manual flag fresh but beast row stale must not read as marked
freshDB()
SkinningTrackerDB[KEY].manualBeasts[BEAST] = stubs.now
SkinningTrackerDB[KEY].beasts[BEAST] = ST:GetLastResetTime() - 1
eq("fresh flag + stale beast row reads unmarked", ST:WasManuallyMarked(BEAST), false)

-- ---------------------------------------------------------------------------
-- 5. Other characters' rows (may predate manualBeasts entirely)
-- ---------------------------------------------------------------------------
freshDB()
local legacyAlt = { isMidnightSkinner = true, beasts = { gloomclaw = stubs.now }, items = {} }
local ok = pcall(function()
    return ST:WasManuallyMarked(BEAST, legacyAlt, ST:GetLastResetTime())
end)
check("WasManuallyMarked tolerates a row with no manualBeasts", ok)
eq("legacy alt reads as auto, not manual",
    ST:WasManuallyMarked(BEAST, legacyAlt, ST:GetLastResetTime()), false)

-- ---------------------------------------------------------------------------
-- 6. /skt reset clears manual flags
-- ---------------------------------------------------------------------------
freshDB()
ST:ToggleSkinnedManual(BEAST)
SlashCmdList["SKINNINGTRACKER"]("reset")
eq("reset clears skinned", ST:HasSkinnedToday(BEAST), false)
eq("reset clears manual flag", ST:WasManuallyMarked(BEAST), false)
check("reset preserves skinner flag", SkinningTrackerDB[KEY].isMidnightSkinner == true)
check("reset recreates manualBeasts", type(SkinningTrackerDB[KEY].manualBeasts) == "table")

-- ---------------------------------------------------------------------------
-- 7. Slash parity: /skt mark and /skt unmark
-- ---------------------------------------------------------------------------
local function lastPrint()
    return stubs.printed[#stubs.printed] or ""
end

freshDB()
SlashCmdList["SKINNINGTRACKER"]("mark gloomclaw")
eq("/skt mark marks", ST:HasSkinnedToday(BEAST), true)
eq("/skt mark flags as manual", ST:WasManuallyMarked(BEAST), true)

-- Marking twice must be a no-op, not a toggle: the old prefix handler would
-- happily re-run and a naive toggle here would silently UNmark.
local tsBefore = SkinningTrackerDB[KEY].beasts[BEAST]
SlashCmdList["SKINNINGTRACKER"]("mark gloomclaw")
eq("/skt mark twice stays marked", ST:HasSkinnedToday(BEAST), true)
eq("/skt mark twice does not move the timestamp", SkinningTrackerDB[KEY].beasts[BEAST], tsBefore)
check("/skt mark twice explains itself", lastPrint():find("already") ~= nil, lastPrint())

SlashCmdList["SKINNINGTRACKER"]("unmark gloomclaw")
eq("/skt unmark clears", ST:HasSkinnedToday(BEAST), false)
eq("/skt unmark clears manual flag", ST:WasManuallyMarked(BEAST), false)

SlashCmdList["SKINNINGTRACKER"]("unmark gloomclaw")
eq("/skt unmark twice stays clear", ST:HasSkinnedToday(BEAST), false)
check("/skt unmark twice explains itself", lastPrint():find("already") ~= nil, lastPrint())

-- Accepts the display name as well as the id
freshDB()
SlashCmdList["SKINNINGTRACKER"]("mark Netherscythe")
eq("/skt mark accepts display name", ST:HasSkinnedToday("netherscythe"), true)

-- Bad input
freshDB()
SlashCmdList["SKINNINGTRACKER"]("mark nosuchbeast")
check("/skt mark rejects unknown beast", lastPrint():find("Gloomclaw") ~= nil, lastPrint())
SlashCmdList["SKINNINGTRACKER"]("mark")
check("/skt mark with no argument prints usage", lastPrint():find("Usage") ~= nil, lastPrint())
SlashCmdList["SKINNINGTRACKER"]("unmark")
check("/skt unmark with no argument prints usage", lastPrint():find("Usage") ~= nil, lastPrint())

-- "unmark" must not be swallowed by the "mark" branch
freshDB()
ST:ToggleSkinnedManual(BEAST)
SlashCmdList["SKINNINGTRACKER"]("unmark gloomclaw")
eq("unmark is not parsed as mark", ST:HasSkinnedToday(BEAST), false)

-- ---------------------------------------------------------------------------
-- 8. Manual marks are per-character
-- ---------------------------------------------------------------------------
freshDB()
SkinningTrackerDB["Alt-TestRealm"] = {
    isMidnightSkinner = true, beasts = {}, items = {}, manualBeasts = {},
}
ST:ToggleSkinnedManual(BEAST)
eq("alt is untouched by the current character's manual mark",
    SkinningTrackerDB["Alt-TestRealm"].beasts[BEAST], nil)

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
io.write(string.format("\nManual Edit tests: %d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do io.write("  FAIL  " .. f .. "\n") end
if fail > 0 then os.exit(1) end
