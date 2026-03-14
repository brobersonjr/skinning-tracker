-- SkinningTracker.lua
-- Tracks daily Renowned Beast skinning for Midnight profession skinner characters.
-- Daily reset: 7:00 AM PST = 15:00 UTC

SkinningTracker = {}
local ST = SkinningTracker

-- Daily reset hour in UTC (7 AM PST = 15:00 UTC, accounts for PST = UTC-8)
local RESET_HOUR_UTC = 15

ST.BEASTS = {
    { id = "gloomclaw",   name = "Gloomclaw",   zone = "Eversong Woods", coords = "41.95, 79.70", npcId = 245688  },
    { id = "silverscale", name = "Silverscale", zone = "Zul'Aman",       coords = "47.55, 53.65", npcId = 245699  },
    { id = "lumenfin",    name = "Lumenfin",    zone = "Harandar",       coords = "66.63, 47.83", npcId = 245690  },
    { id = "umbrafang",   name = "Umbrafang",   zone = "Voidstorm",      coords = "54.15, 65.27", npcId = 247096  },
    { id = "netherscythe",name = "Netherscythe",zone = "Voidstorm",      coords = "43.13, 82.81", npcId = 247101  },
}

-- Returns the Unix timestamp of the most recent 7 AM PST reset.
-- Optional serverTime allows callers to reuse a shared time value.
function ST:GetLastResetTime(serverTime)
    local now = time() -- local time (seconds since epoch)
    -- Use server time if available for accuracy
    serverTime = serverTime or (C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or now)

    -- Calculate today's reset in UTC: floor to today then add reset hour
    local date = date("!*t", serverTime) -- UTC table
    local todayReset = serverTime
        - (date.hour * 3600)
        - (date.min * 60)
        - date.sec
        + (RESET_HOUR_UTC * 3600)

    -- If today's reset hasn't happened yet, use yesterday's reset
    if serverTime < todayReset then
        todayReset = todayReset - 86400
    end

    return todayReset
end

-- Returns a unique key for the current character: "Name-Realm"
local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
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

-- Mark a beast as skinned right now
function ST:MarkSkinned(beastId)
    local data = self:GetCharData()
    local serverTime = C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or time()
    data.beasts[beastId] = serverTime
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
    end
    if ST.RefreshDataText then
        ST:RefreshDataText()
    end
end

-- Toggle a beast's skinned state (for manual checking via UI)
function ST:ToggleSkinned(beastId)
    if self:HasSkinnedToday(beastId) then
        -- Unmark: set timestamp to before last reset
        self:GetCharData().beasts[beastId] = self:GetLastResetTime() - 1
    else
        self:MarkSkinned(beastId)
        return -- MarkSkinned already calls RefreshDataText
    end
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
    end
    if ST.RefreshDataText then
        ST:RefreshDataText()
    end
end

-- Toggle the current character as a Midnight profession skinner
function ST:ToggleSkinner()
    local data = self:GetCharData()
    data.isMidnightSkinner = not data.isMidnightSkinner
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
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
    local serverTime = C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or time()
    local lastReset = self:GetLastResetTime()
    local nextReset = lastReset + 86400
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
        SkinningTrackerDB[GetCharKey()] = {
            isMidnightSkinner = false,
            beasts = {},
            class = select(2, UnitClass("player")),
            items = {},
        }
        print("|cff00ff96[SkinningTracker]|r Data reset for " .. GetCharKey())
        if ST.UI and ST.UI.Refresh then ST.UI:Refresh() end
    elseif cmd:sub(1, 4) == "mark" then
        local beastName = strtrim(cmd:sub(5)):lower()
        local found = false
        for _, beast in ipairs(ST.BEASTS) do
            if beast.name:lower() == beastName or beast.id == beastName then
                ST:MarkSkinned(beast.id)
                print("|cff00ff96[SkinningTracker]|r Manually marked |cffffff00" .. beast.name .. "|r as skinned.")
                found = true
                break
            end
        end
        if not found then
            print("|cff00ff96[SkinningTracker]|r Unknown beast: |cffff4444" .. beastName .. "|r")
            print("Valid names: Gloomclaw, Silverscale, Lumenfin, Umbrafang, Netherscythe")
        end
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

-- Resolve which Renowned Beast (if any) is currently targeted.
-- Prefers NPC ID match; falls back to name match for beasts without IDs yet.
local function GetTargetBeastId()
    local guid = UnitGUID("target")
    local npcId = GetNPCIDFromGUID(guid)
    if npcId and beastNpcIdLookup[npcId] then
        return beastNpcIdLookup[npcId]
    end
    local name = UnitName("target")
    local loweredName = SafeLowerString(name)
    if loweredName then
        return beastNameLookup[loweredName]
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

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:SetScript("OnEvent", function(self, event, msg)
    -- Only track the current player's own loot (locale-safe)
    local function BuildLootPattern(fmt)
        if not fmt then return nil end
        -- Escape Lua pattern metacharacters, then replace %s with a capture
        local escaped = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        return escaped:gsub("%%s", "(.+)")
    end

    local selfSingle = BuildLootPattern(LOOT_ITEM_SELF)
    local selfMulti  = BuildLootPattern(LOOT_ITEM_SELF_MULTIPLE)
    if selfSingle or selfMulti then
        if not ((selfSingle and msg:match(selfSingle)) or (selfMulti and msg:match(selfMulti))) then
            return
        end
    else
        if not msg:find("^You receive loot:") then return end
    end

    -- Item links in loot messages contain the item ID: |Hitem:ITEMID:...|h[Name]|h
    local itemId = tonumber(msg:match("|Hitem:(%d+)"))

    if ST.debug then
        local data = ST:GetCharData()
        print(string.format("|cffffff00[SKT Debug]|r LOOT itemId=%s name=%s hasData=%s items=%s",
            tostring(itemId),
            tostring(majesticLookup[itemId]),
            tostring(data ~= nil),
            data and data.items and tostring(data.items[itemId]) or "nil"))
    end

    if itemId and majesticLookup[itemId] then
        local qty = tonumber(msg:match("x(%d+)")) or tonumber(msg:match(" x(%d+)")) or 1
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
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SkinningTracker" then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        -- Ensure DB is ready after all saved vars load
        InitDB()
        -- Reset session item counts for this login
        ST.sessionItems = {}
        -- Auto-detect Midnight Skinning via the skinning spell; store class for UI coloring
        local data = ST:GetCharData()
        data.isMidnightSkinner = IsSpellKnown(SKINNING_SPELL_ID)
        data.class = select(2, UnitClass("player"))
        if data.isMidnightSkinner then
            print("|cff00ff96[SkinningTracker]|r Loaded. Midnight Skinning detected — |cffffff00/skt|r to open · |cffffff00/skt debug|r to diagnose tracking.")
        end
    end
end)

