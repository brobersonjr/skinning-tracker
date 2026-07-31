-- SkinningTracker.lua
-- Tracks daily Renowned Beast skinning for Midnight profession skinner characters.
-- Daily reset is read from the client (C_DateAndTime.GetSecondsUntilDailyReset),
-- so it is correct for every region without a hardcoded offset.

SkinningTracker = {}
local ST = SkinningTracker

-- Fallback daily reset hour in UTC, used only if the client API is unavailable.
-- Blizzard anchors US resets to a fixed UTC time, which is why the wall-clock
-- time shifts by an hour across DST; 15:00 UTC is the US boundary year-round.
-- This is US-specific and is exactly why the API above is preferred.
local RESET_HOUR_UTC = 15

local SECONDS_PER_DAY = 86400

-- Current server time as a Unix epoch, falling back to local time.
-- Centralised so the convention lives in one place instead of four call sites.
function ST:GetServerNow()
    if C_DateAndTime and C_DateAndTime.GetServerTime then
        local ok, t = pcall(C_DateAndTime.GetServerTime)
        if ok and type(t) == "number" then return t end
    end
    return time()
end

-- Seconds until the next daily reset, straight from the client.
-- Returns nil when the API is missing or returns something unusable, which is
-- the signal for callers to fall back to the hardcoded UTC math below.
local function GetSecondsUntilReset()
    if not (C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset) then return nil end
    local ok, secs = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
    if not ok or type(secs) ~= "number" then return nil end
    -- A non-positive or absurd value means the client has nothing useful yet
    if secs <= 0 or secs > SECONDS_PER_DAY then return nil end
    return secs
end

ST.BEASTS = {
    { id = "gloomclaw",   name = "Gloomclaw",   zone = "Eversong Woods", coords = "41.95, 79.70", npcId = 245688  },
    { id = "silverscale", name = "Silverscale", zone = "Zul'Aman",       coords = "47.55, 53.65", npcId = 245699  },
    { id = "lumenfin",    name = "Lumenfin",    zone = "Harandar",       coords = "66.63, 47.83", npcId = 245690  },
    { id = "umbrafang",   name = "Umbrafang",   zone = "Voidstorm",      coords = "54.15, 65.27", npcId = 247096  },
    { id = "netherscythe",name = "Netherscythe",zone = "Voidstorm",      coords = "43.13, 82.81", npcId = 247101  },
}

-- Returns the Unix timestamp of the most recent daily reset.
-- Optional serverTime allows callers to reuse a shared time value.
function ST:GetLastResetTime(serverTime)
    serverTime = serverTime or self:GetServerNow()

    -- Preferred: derive from the client's own countdown to the next reset.
    -- Correct for every region and immune to DST, unlike a fixed UTC hour.
    local secs = GetSecondsUntilReset()
    if secs then
        return serverTime + secs - SECONDS_PER_DAY
    end

    -- Fallback: fixed reset hour in UTC (US boundary).
    -- Calculate today's reset in UTC: floor to today then add reset hour
    local date = date("!*t", serverTime) -- UTC table
    local todayReset = serverTime
        - (date.hour * 3600)
        - (date.min * 60)
        - date.sec
        + (RESET_HOUR_UTC * 3600)

    -- If today's reset hasn't happened yet, use yesterday's reset
    if serverTime < todayReset then
        todayReset = todayReset - SECONDS_PER_DAY
    end

    return todayReset
end

-- Returns a unique key for the current character: "Name-Realm"
local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Public accessor so the UI and any other file share this one definition
-- instead of rebuilding the key inline.
function ST:GetCharKey()
    return GetCharKey()
end

-- Initialize SavedVariables and per-character data
local function InitDB()
    if not SkinningTrackerDB then
        SkinningTrackerDB = {}
    end
    local key = GetCharKey()
    if not SkinningTrackerDB[key] then
        SkinningTrackerDB[key] = {
            isMidnightSkinner = false,
            beasts = {},
            class = nil,
            items = {},
            -- nil = follow auto-detection; true/false = explicit /skt toggle choice
            manualOverride = nil,
            autoDetected = false,
        }
    end
    -- Migrate existing entries that predate the items field
    if not SkinningTrackerDB[key].items then
        SkinningTrackerDB[key].items = {}
    end
end

-- Returns the current character's data table
function ST:GetCharData()
    return SkinningTrackerDB[GetCharKey()]
end

-- Returns true if the beast was skinned after the last reset
function ST:HasSkinnedToday(beastId)
    local data = self:GetCharData()
    local ts = data.beasts[beastId]
    if not ts then return false end
    return ts >= self:GetLastResetTime()
end

-- Record an automatically detected successful skinning
function ST:MarkSkinned(beastId)
    local data = self:GetCharData()
    data.beasts[beastId] = self:GetServerNow()
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
    end
    if ST.RefreshDataText then
        ST:RefreshDataText()
    end
end

-- Toggle the current character as a Midnight profession skinner.
-- Records the choice in manualOverride so login auto-detection stops
-- overriding it on every reload.
function ST:ToggleSkinner()
    local data = self:GetCharData()
    data.isMidnightSkinner = not data.isMidnightSkinner
    data.manualOverride = data.isMidnightSkinner
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
    end
    if ST.RefreshDataText then
        ST:RefreshDataText()
    end
end

-- Returns true if current character is flagged as a Midnight skinner
function ST:IsMidnightSkinner()
    return self:GetCharData().isMidnightSkinner
end

-- Returns how many beasts are left to skin today for the current character
function ST:GetRemainingCount()
    local count = 0
    for _, beast in ipairs(self.BEASTS) do
        if not self:HasSkinnedToday(beast.id) then
            count = count + 1
        end
    end
    return count
end

-- Returns time (in seconds) until the next reset
function ST:GetTimeUntilReset()
    -- Use the client's countdown directly when it is available
    local secs = GetSecondsUntilReset()
    if secs then return secs end

    local serverTime = self:GetServerNow()
    local nextReset = self:GetLastResetTime(serverTime) + SECONDS_PER_DAY
    return nextReset - serverTime
end

-- Returns a formatted "Xh Ym" string for time until reset
function ST:GetResetCountdown()
    local secs = self:GetTimeUntilReset()
    if secs <= 0 then return "Resetting..." end
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    return string.format("%dh %02dm", h, m)
end

-- Returns all skinner character keys in the DB and their data
function ST:GetAllCharacters()
    local chars = {}
    for key, data in pairs(SkinningTrackerDB) do
        if data.isMidnightSkinner then
            table.insert(chars, { key = key, data = data })
        end
    end
    table.sort(chars, function(a, b) return a.key < b.key end)
    return chars
end

-- Slash command handler
local PlayChaChing
local MAJESTIC_SOUND_ID = 891 -- coin/cash-register style cue
local function SlashHandler(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "toggle" then
        ST:ToggleSkinner()
        local state = ST:IsMidnightSkinner() and "enabled" or "disabled"
        print("|cff00ff96[SkinningTracker]|r Midnight Skinner " .. state .. " for " .. GetCharKey())
    elseif cmd == "reset" then
        -- Clear tracked progress but keep the skinner flags: wiping them drops
        -- the character out of the table until the next login.
        local prev = ST:GetCharData()
        local fresh = {
            isMidnightSkinner = (prev and prev.isMidnightSkinner) or false,
            autoDetected = (prev and prev.autoDetected) or false,
            beasts = {},
            class = select(2, UnitClass("player")),
            items = {},
        }
        -- Assigned separately so an explicit `false` override is not lost
        if prev then fresh.manualOverride = prev.manualOverride end
        SkinningTrackerDB[GetCharKey()] = fresh
        print("|cff00ff96[SkinningTracker]|r Progress reset for " .. GetCharKey())
        if ST.UI and ST.UI.Refresh then ST.UI:Refresh() end
        if ST.RefreshDataText then ST:RefreshDataText() end
    elseif cmd == "mark" or cmd:sub(1, 5) == "mark " then
        print("|cff00ff96[SkinningTracker]|r Manual beast marking is unavailable; progress is tracked automatically.")
    elseif cmd == "debug" then
        ST.debug = not ST.debug
        local state = ST.debug and "|cff00ff96ON|r" or "|cffff4444OFF|r"
        print("|cff00ff96[SkinningTracker]|r Debug mode " .. state .. ". Cast any skinning spell to inspect events and target GUID.")
    elseif cmd == "testsound" then
        PlayChaChing()
        print("|cff00ff96[SkinningTracker]|r Played test sound ID " .. tostring(MAJESTIC_SOUND_ID) .. ".")
    elseif cmd:sub(1, 9) == "testsound " then
        local id = tonumber(strtrim(cmd:sub(10)))
        if not id then
            print("|cff00ff96[SkinningTracker]|r Usage: /skt testsound <soundId>")
            return
        end
        local ok = PlaySound(id, "Master")
        print("|cff00ff96[SkinningTracker]|r Test sound ID " .. tostring(id) .. (ok and " played." or " failed."))
    else
        if ST.UI then
            if ST.UI.frame:IsShown() then
                ST.UI.frame:Hide()
            else
                ST.UI.frame:Show()
                ST.UI:Refresh()
            end
        end
    end
end

SLASH_SKINNINGTRACKER1 = "/skt"
SlashCmdList["SKINNINGTRACKER"] = SlashHandler

-- ---------------------------------------------------------------------------
-- Auto-detection: listen for Midnight skinning spell (ID 8613)
-- ---------------------------------------------------------------------------
local SKINNING_SPELL_ID = 8613

-- Is the skinning spell known by this character?
--
-- IsSpellKnown is the path confirmed working on the current client, so it stays
-- FIRST on purpose. The alternatives exist only so that a future client which
-- removes the global degrades instead of erroring on every SPELLS_CHANGED.
-- Do not promote them above IsSpellKnown: they are not exact synonyms for
-- profession spells, and reordering would swap a verified check for an
-- unverified one. Returning false when nothing is callable is safe, because
-- ApplySkinnerDetection never clears an existing true.
-- Listed as explicit branches rather than a table: a nil first entry would put
-- a hole in the array and ipairs would stop before reaching any fallback.
local function IsSkinningKnown()
    local function try(fn)
        if type(fn) ~= "function" then return nil end
        local ok, known = pcall(fn, SKINNING_SPELL_ID)
        if not ok then return nil end
        return known and true or false
    end

    local known = try(IsSpellKnown)
    if known ~= nil then return known end

    known = try(C_Spell and C_Spell.IsSpellKnown)
    if known ~= nil then return known end

    known = try(IsPlayerSpell)
    if known ~= nil then return known end

    return false
end

-- Apply skinning auto-detection to the current character.
-- Two rules keep characters from silently disappearing from the tracker:
--   1. An explicit /skt toggle (manualOverride) always wins over detection.
--   2. Detection only ever sets the flag true. The spellbook can still be
--      empty at PLAYER_LOGIN, and clearing the flag there would drop the
--      character out of GetAllCharacters() and blank its row.
local function ApplySkinnerDetection()
    if not SkinningTrackerDB then return end
    local data = ST:GetCharData()
    if not data then return end

    local before = data.isMidnightSkinner
    data.autoDetected = IsSkinningKnown()

    if data.manualOverride ~= nil then
        data.isMidnightSkinner = data.manualOverride
    elseif data.autoDetected then
        data.isMidnightSkinner = true
    end

    if data.isMidnightSkinner ~= before then
        if ST.UI and ST.UI.Refresh then ST.UI:Refresh() end
        if ST.RefreshDataText then ST:RefreshDataText() end
    end
end

-- Build lookups: npcId -> beast id, and name (lowercase) -> beast id (fallback)
local beastNpcIdLookup  = {}
local beastNameLookup   = {}
for _, beast in ipairs(ST.BEASTS) do
    if beast.npcId then
        beastNpcIdLookup[beast.npcId] = beast.id
    end
    beastNameLookup[beast.name:lower()] = beast.id
end

local function SafeLowerString(value)
    if not value then return nil end
    local ok, lowered = pcall(strlower, value)
    return ok and lowered or nil
end

local function SafeDebugString(value)
    if value == nil then return "nil" end
    local ok, text = pcall(tostring, value)
    return ok and text or "<secret>"
end

-- Extract the NPC ID (decimal) from a WoW creature GUID.
-- GUID format: "Creature-0-REALM-SERVER-INSTANCE-NPCID-SPAWNUID"
local function GetNPCIDFromGUID(guid)
    if not guid then return nil end
    local ok, result = pcall(function()
        return tonumber((select(6, strsplit("-", guid))))
    end)
    return ok and result or nil
end

-- Unit tokens to inspect, in priority order. "softinteract" covers players who
-- skin with an interact keybind or soft-target interact, where the corpse is
-- never made the hard target and UnitGUID("target") is nil or something else.
local SKIN_UNITS = { "target", "softinteract" }

-- Both wrapped: "softinteract" is not guaranteed to be a valid token on every
-- client, and these calls can return protected values inside delves.
local function SafeUnitGUID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    return ok and guid or nil
end

local function SafeUnitName(unit)
    local ok, name = pcall(UnitName, unit)
    return ok and name or nil
end

-- Resolve which Renowned Beast (if any) is currently targeted.
-- Prefers NPC ID match; falls back to name match for beasts without IDs yet.
local function GetTargetBeastId()
    -- Try NPC ID across every unit first: it is the reliable signal, so a name
    -- match on one unit must never win over an ID match on another.
    for _, unit in ipairs(SKIN_UNITS) do
        local npcId = GetNPCIDFromGUID(SafeUnitGUID(unit))
        if npcId and beastNpcIdLookup[npcId] then
            return beastNpcIdLookup[npcId]
        end
    end
    for _, unit in ipairs(SKIN_UNITS) do
        local loweredName = SafeLowerString(SafeUnitName(unit))
        if loweredName and beastNameLookup[loweredName] then
            return beastNameLookup[loweredName]
        end
    end
    return nil
end

-- Store which beast is being skinned between SPELLCAST_START and SUCCEEDED
local pendingBeastId = nil
local pendingInterrupted = false  -- true if the cast was interrupted before CHANNEL_STOP fires

-- Forward declaration: defined after sound helpers below
local AutoSkinBeast

local trackFrame = CreateFrame("Frame")
trackFrame:RegisterEvent("UNIT_SPELLCAST_START")
trackFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
trackFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
trackFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
trackFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
trackFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
trackFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if unit ~= "player" then return end

    -- Debug mode: print all player spellcasts to help diagnose issues
    if ST.debug then
        local guid = UnitGUID("target")
        local ok, npcIdRaw = pcall(function() return guid and tonumber((select(6, strsplit("-", guid)))) end)
        local npcId = (ok and npcIdRaw) or "nil"
        local name  = SafeDebugString(UnitName("target"))
        print(string.format("|cffffff00[SKT Debug]|r %s spellID=%s target=%s npcId=%s name=%s",
            event, tostring(spellID), SafeDebugString(guid), tostring(npcId), name))
    end

    if spellID ~= SKINNING_SPELL_ID then return end

    -- Both regular cast start and channel start capture the target
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        pendingBeastId = GetTargetBeastId()
        pendingInterrupted = false
        if ST.debug then
            print("|cffffff00[SKT Debug]|r Skinning spell detected, pending beast: " .. tostring(pendingBeastId))
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if pendingBeastId then
            AutoSkinBeast(pendingBeastId)
            pendingBeastId = nil
        end

    -- CHANNEL_STOP fires on both success and interruption.
    -- Defer by one frame so INTERRUPTED (if it follows) can set pendingInterrupted first.
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local beastId = pendingBeastId
        pendingBeastId = nil
        C_Timer.After(0, function()
            if beastId and not pendingInterrupted then
                AutoSkinBeast(beastId)
            end
            pendingInterrupted = false
        end)

    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        pendingInterrupted = true
        pendingBeastId = nil
    end
end)

-- ---------------------------------------------------------------------------
-- Majestic item loot detection + cha-ching sound
-- ---------------------------------------------------------------------------
ST.MAJESTIC_ITEMS = {
    { id = 238528, name = "Majestic Claw" },
    { id = 238529, name = "Majestic Hide" },
    { id = 238530, name = "Majestic Fin" },
}

-- Session counts: reset each login, not saved to DB
ST.sessionItems = {}

local majesticLookup = {}
for _, item in ipairs(ST.MAJESTIC_ITEMS) do
    majesticLookup[item.id] = item.name
end

-- Play a positive sound on Majestic item loot.
-- Uses a single sell/coin-style cue for Majestic loot alerts.
PlayChaChing = function()
    local ok = PlaySound(MAJESTIC_SOUND_ID, "Master")
    if ST.debug and not ok then
        print("|cffffff00[SKT Debug]|r PlayChaChing failed for sound ID " .. tostring(MAJESTIC_SOUND_ID) .. ".")
    end
end

-- Called when a beast is auto-skinned: marks it and prints chat feedback.
AutoSkinBeast = function(beastId)
    ST:MarkSkinned(beastId)
    local beastName = beastId
    for _, beast in ipairs(ST.BEASTS) do
        if beast.id == beastId then beastName = beast.name; break end
    end
    print("|cff00ff96[SkinningTracker]|r Auto-tracked: |cffffff00" .. beastName .. "|r skinned!")
end

-- Loot messages come from locale format templates:
--   LOOT_ITEM_SELF          = "You receive loot: %s."
--   LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
-- Turn a template into a Lua pattern with captures for the item link (%s) and,
-- where present, the stack size (%d). Escaping "%" is what makes this correct:
-- leaving it alone means the template's "%d" survives into the compiled pattern
-- as the character class "exactly one digit", which cannot match "x10." and up.
local function BuildLootPattern(fmt)
    if not fmt then return nil end
    -- Escape every Lua pattern metacharacter, "%" included
    local escaped = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
    -- Then turn the now-escaped format specifiers into captures
    escaped = escaped:gsub("%%%%s", "(.+)")
    escaped = escaped:gsub("%%%%d", "(%%d+)")
    return escaped
end

-- Compiled once at load: these templates never change during a session, and
-- CHAT_MSG_LOOT is a hot event in groups.
local LOOT_SELF_MULTI  = BuildLootPattern(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_SELF_SINGLE = BuildLootPattern(LOOT_ITEM_SELF)

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:SetScript("OnEvent", function(self, event, msg)
    -- Only track the current player's own loot (locale-safe).
    -- Match the multiple form first and take the quantity from its capture:
    -- the single-item pattern's greedy (.+) also matches "...x10." messages, so
    -- testing it first would swallow the count and always report 1.
    local qty
    if LOOT_SELF_MULTI then
        local _, count = msg:match(LOOT_SELF_MULTI)
        qty = tonumber(count)
    end
    if not qty then
        local isOwnLoot
        if LOOT_SELF_SINGLE then
            isOwnLoot = msg:match(LOOT_SELF_SINGLE) ~= nil
        else
            isOwnLoot = msg:find("^You receive loot:") ~= nil
        end
        if not isOwnLoot then
            -- Only "You receive loot:" counts, and that is deliberate.
            -- "You receive item:" (LOOT_ITEM_PUSHED_SELF) covers auction house
            -- purchases, mail, crafting and quest rewards. Counting those would
            -- inflate skinning yield with Majestic items the player bought
            -- rather than skinned. Do not widen this gate.
            if ST.debug then
                print("|cffffff00[SKT Debug]|r LOOT ignored (not own loot): " .. SafeDebugString(msg))
            end
            return
        end
        qty = 1
    end

    -- Item links in loot messages contain the item ID: |Hitem:ITEMID:...|h[Name]|h
    local itemId = tonumber(msg:match("|Hitem:(%d+)"))

    if ST.debug then
        local data = ST:GetCharData()
        print(string.format("|cffffff00[SKT Debug]|r LOOT itemId=%s name=%s qty=%s hasData=%s items=%s",
            tostring(itemId),
            tostring(majesticLookup[itemId]),
            tostring(qty),
            tostring(data ~= nil),
            data and data.items and tostring(data.items[itemId]) or "nil"))
    end

    if itemId and majesticLookup[itemId] then
        local itemName = majesticLookup[itemId]
        local data = ST:GetCharData()
        if data then
            data.items[itemId] = (data.items[itemId] or 0) + qty
            ST.sessionItems[itemId] = (ST.sessionItems[itemId] or 0) + qty
            if ST.UI and ST.UI.Refresh then ST.UI:Refresh() end
            if ST.RefreshDataText then ST:RefreshDataText() end
        end
        print("|cff00ff96[SkinningTracker]|r |cffffff00" .. itemName .. "|r x" .. qty .. " looted!")
        PlayChaChing()
    end
end)

-- ---------------------------------------------------------------------------
-- Addon load event
-- ---------------------------------------------------------------------------
-- Initialisation happens once, at PLAYER_LOGIN. ADDON_LOADED is deliberately
-- not used: GetCharKey() needs UnitName("player") and GetRealmName(), which are
-- not guaranteed ready that early, and SavedVariables are already loaded by the
-- time PLAYER_LOGIN fires. Until then SkinningTrackerDB stays nil, which the
-- SPELLS_CHANGED path below checks for.
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:RegisterEvent("SPELLS_CHANGED")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        InitDB()
        -- Reset session item counts for this login
        ST.sessionItems = {}
        -- Auto-detect Midnight Skinning via the skinning spell; store class for UI coloring
        local data = ST:GetCharData()
        data.class = select(2, UnitClass("player"))
        ApplySkinnerDetection()
        if data.isMidnightSkinner then
            local how = data.autoDetected and "Midnight Skinning detected" or "Skinner tracking enabled"
            print("|cff00ff96[SkinningTracker]|r Loaded. " .. how .. " — |cffffff00/skt|r to open · |cffffff00/skt debug|r to diagnose tracking.")
        end
    elseif event == "SPELLS_CHANGED" then
        -- The spellbook may not be populated at PLAYER_LOGIN; retry detection
        -- once it is, and after any profession change.
        ApplySkinnerDetection()
    end
end)

