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

-- Returns the Unix timestamp of the most recent 7 AM PST reset
local function GetLastResetTime()
    local now = time() -- local time (seconds since epoch)
    -- Use server time if available for accuracy
    local serverTime = C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or now

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
    -- Top-level: SkinningTrackerDB[charKey] = { isMidnightSkinner = bool, beasts = { beastId = timestamp } }
    local key = GetCharKey()
    if not SkinningTrackerDB[key] then
        SkinningTrackerDB[key] = {
            isMidnightSkinner = false,
            beasts = {},
        }
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
    return ts >= GetLastResetTime()
end

-- Mark a beast as skinned right now
function ST:MarkSkinned(beastId)
    local data = self:GetCharData()
    local serverTime = C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or time()
    data.beasts[beastId] = serverTime
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
    end
end

-- Toggle a beast's skinned state (for manual checking via UI)
function ST:ToggleSkinned(beastId)
    if self:HasSkinnedToday(beastId) then
        -- Unmark: set timestamp to before last reset
        self:GetCharData().beasts[beastId] = GetLastResetTime() - 1
    else
        self:MarkSkinned(beastId)
    end
    if ST.UI and ST.UI.Refresh then
        ST.UI:Refresh()
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
    local lastReset = GetLastResetTime()
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

-- Returns all character keys in the DB and their data
function ST:GetAllCharacters()
    local chars = {}
    for key, data in pairs(SkinningTrackerDB) do
        table.insert(chars, { key = key, data = data })
    end
    table.sort(chars, function(a, b) return a.key < b.key end)
    return chars
end

-- Slash command handler
local function SlashHandler(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "toggle" then
        ST:ToggleSkinner()
        local state = ST:IsMidnightSkinner() and "enabled" or "disabled"
        print("|cff00ff96[SkinningTracker]|r Midnight Skinner " .. state .. " for " .. GetCharKey())
    elseif cmd == "reset" then
        SkinningTrackerDB[GetCharKey()] = { isMidnightSkinner = false, beasts = {} }
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
-- Auto-detection: listen for Midnight skinning spell (ID 471014)
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

-- Extract the NPC ID (decimal) from a WoW creature GUID.
-- GUID format: "Creature-0-REALM-SERVER-INSTANCE-NPCID-SPAWNUID"
local function GetNPCIDFromGUID(guid)
    if not guid then return nil end
    return tonumber((select(6, strsplit("-", guid))))
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
    if name then
        return beastNameLookup[name:lower()]
    end
    return nil
end

-- Store which beast is being skinned between SPELLCAST_START and SUCCEEDED
local pendingBeastId = nil

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
        local npcId = guid and tonumber((select(6, strsplit("-", guid)))) or "nil"
        local name  = UnitName("target") or "nil"
        print(string.format("|cffffff00[SKT Debug]|r %s spellID=%s target=%s npcId=%s name=%s",
            event, tostring(spellID), tostring(guid), tostring(npcId), name))
    end

    if spellID ~= SKINNING_SPELL_ID then return end

    -- Both regular cast start and channel start capture the target
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        pendingBeastId = GetTargetBeastId()
        if ST.debug then
            print("|cffffff00[SKT Debug]|r Skinning spell detected, pending beast: " .. tostring(pendingBeastId))
        end

    -- Both regular succeeded and channel stop (which fires on successful finish) confirm the skin
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if pendingBeastId then
            ST:MarkSkinned(pendingBeastId)
            local beastName = pendingBeastId
            for _, beast in ipairs(ST.BEASTS) do
                if beast.id == pendingBeastId then
                    beastName = beast.name
                    break
                end
            end
            print("|cff00ff96[SkinningTracker]|r Auto-tracked: |cffffff00" .. beastName .. "|r skinned!")
            pendingBeastId = nil
        end

    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        pendingBeastId = nil
    end
end)

-- ---------------------------------------------------------------------------
-- Majestic item loot detection + cha-ching sound
-- ---------------------------------------------------------------------------
local MAJESTIC_ITEMS = {
    [238528] = "Majestic Claw",
    [238529] = "Majestic Hide",
    [238530] = "Majestic Fin",
}

-- Play a money sound using the Midnight C_Sound API.
local function PlayChaChing()
    C_Sound.PlaySound({ soundID = SOUNDKIT.IG_TREASURE_OPEN, channel = "Master" })
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:SetScript("OnEvent", function(self, event, msg)
    -- Item links in loot messages contain the item ID: |Hitem:ITEMID:...|h[Name]|h
    local itemId = tonumber(msg:match("|Hitem:(%d+)"))
    if itemId and MAJESTIC_ITEMS[itemId] then
        PlayChaChing()
        print("|cff00ff96[SkinningTracker]|r |cffffff00" .. MAJESTIC_ITEMS[itemId] .. "|r looted!")
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
        print("|cff00ff96[SkinningTracker]|r Loaded. |cffffff00/skt|r to open · |cffffff00/skt toggle|r to flag skinner · |cffffff00/skt debug|r to diagnose tracking.")
    end
end)
