-- SkinningTrackerUI.lua
-- Builds the tracker window: per-character beast checklist with daily reset countdown.

local ST = SkinningTracker
ST.UI = {}
local UI = ST.UI

-- Colour constants
local C_GREEN   = "|cff00ff96"
local C_YELLOW  = "|cffffff00"
local C_RED     = "|cffff4444"
local C_GREY    = "|cff888888"
local C_ORANGE  = "|cffff9900"
local C_WHITE   = "|cffffffff"
local C_RESET   = "|r"

local FRAME_WIDTH  = 700
local FRAME_HEIGHT = 480
local ROW_HEIGHT   = 20
local COL_CHAR     = 210  -- character column width
local COL_BEAST    = 90   -- each beast column width
local COL_ITEM     = 145  -- each item count column width

-- ---------------------------------------------------------------------------
-- Helper: create a FontString label
-- ---------------------------------------------------------------------------
local function MakeLabel(parent, text, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text)
    return fs
end

-- ---------------------------------------------------------------------------
-- Window position persistence (SkinningTrackerUIDB, account-wide)
-- ---------------------------------------------------------------------------
local function EnsureUIDB()
    if not SkinningTrackerUIDB then SkinningTrackerUIDB = {} end
    return SkinningTrackerUIDB
end

-- Save only the anchor values, never the relativeTo frame returned second by
-- GetPoint(): a frame object cannot be serialised into SavedVariables, and
-- UIParent is the only anchor this window uses.
local function SavePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint()
    if not point then return end
    EnsureUIDB().pos = {
        point         = point,
        relativePoint = relativePoint or point,
        x             = x or 0,
        y             = y or 0,
    }
end

local function RestorePosition(f)
    local pos = EnsureUIDB().pos
    f:ClearAllPoints()
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end
end

-- ---------------------------------------------------------------------------
-- Build the main frame (called once)
-- ---------------------------------------------------------------------------
local function BuildFrame()
    local f = CreateFrame("Frame", "SkinningTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    f:SetClampedToScreen(true)
    RestorePosition(f)
    f:Hide()

    -- Let Escape close the window, like standard Blizzard frames
    table.insert(UISpecialFrames, "SkinningTrackerFrame")

    -- Title
    f.TitleText:SetText("Skinning Tracker - Renowned Beasts")

    -- Close button already provided by BasicFrameTemplateWithInset (CloseButton)

    -- Scroll frame for the character rows
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 40)
    f.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 40, 1)
    scroll:SetScrollChild(content)
    f.content = content

    -- Bottom bar: reset countdown on the left, Manual Edit toggle on the right.
    -- Note this is NOT the skinner-status button that was declined earlier: it
    -- does not touch manualOverride and never changes auto-detection.
    local bottomBar = CreateFrame("Frame", nil, f)
    bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    bottomBar:SetHeight(28)

    local resetLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetLabel:SetPoint("LEFT", bottomBar, "LEFT", 0, 0)
    resetLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    f.resetLabel = resetLabel

    local editBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    editBtn:SetSize(120, 22)
    editBtn:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
    editBtn:SetScript("OnClick", function() UI:SetManualEdit(not UI.manualEdit) end)
    editBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Manual Edit", 1, 1, 1)
        GameTooltip:AddLine("Unlock this character's checkboxes to record a kill the addon missed, or clear one it got wrong.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Re-locks when you close the window.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    editBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.editBtn = editBtn

    -- Manual Edit is a repair mode, not a preference: it is session-only and
    -- always off again the next time the window opens.
    f:SetScript("OnHide", function()
        UI.manualEdit = false
    end)

    UI.frame      = f
    UI.content    = content
    UI.rows       = {}
    UI.manualEdit = false
end

-- Set Manual Edit mode and rebuild so the rows pick up the new lock state.
function UI:SetManualEdit(on)
    self.manualEdit = on and true or false
    self:Refresh()
end

-- Keep the button label in step with the mode.
local function UpdateEditButton()
    local btn = UI.frame and UI.frame.editBtn
    if not btn then return end
    btn:SetText(UI.manualEdit and (C_ORANGE .. "Manual Edit: ON" .. C_RESET) or "Manual Edit")
end

-- ---------------------------------------------------------------------------
-- Build the column header row
-- ---------------------------------------------------------------------------
local function BuildHeader(content)
    local y = -6

    UI.header = UI.header or {}
    UI.header.beastHeaders = UI.header.beastHeaders or {}

    -- "Character" label
    if not UI.header.charHeader then
        UI.header.charHeader = MakeLabel(content, "", 12, "LEFT")
        UI.header.charHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    end
    UI.header.charHeader:SetText(C_YELLOW .. "Character" .. C_RESET)
    UI.header.charHeader:Show()

    -- Beast name headers
    for i, beast in ipairs(ST.BEASTS) do
        local x = COL_CHAR + (i - 1) * COL_BEAST
        local bHeader = UI.header.beastHeaders[i]
        if not bHeader then
            bHeader = MakeLabel(content, "", 10, "CENTER")
            bHeader:SetWidth(COL_BEAST)
            bHeader:EnableMouse(true)
            UI.header.beastHeaders[i] = bHeader
        end
        bHeader:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        bHeader:SetText(C_YELLOW .. beast.name .. C_RESET)

        -- Tooltip with zone/coords
        local zone = beast.zone
        local coords = beast.coords
        bHeader:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(beast.name, 1, 1, 1)
            GameTooltip:AddLine(zone, 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Coords: " .. coords, 0.7, 0.9, 0.7)
            GameTooltip:AddLine("Progress is recorded automatically when skinned.", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Use Manual Edit to correct a missed or wrong mark.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        bHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bHeader:Show()
    end

    -- Hide any extra beast headers if list shrank
    for i = #ST.BEASTS + 1, #UI.header.beastHeaders do
        UI.header.beastHeaders[i]:Hide()
    end

    -- Divider line
    if not UI.header.divider then
        UI.header.divider = content:CreateTexture(nil, "BACKGROUND")
        UI.header.divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        UI.header.divider:SetHeight(1)
        UI.header.divider:SetWidth(FRAME_WIDTH - 50)
    end
    UI.header.divider:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y - 16)
    UI.header.divider:Show()

    return y - 20
end

-- Returns a hex color code for a class file name (e.g. "WARRIOR"), or nil
local function GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
end

-- ---------------------------------------------------------------------------
-- Build or refresh all character rows
-- ---------------------------------------------------------------------------
local function BuildRows(content, startY)
    UI.rows = UI.rows or {}

    local chars = ST:GetAllCharacters()
    local y = startY

    for i, charEntry in ipairs(chars) do
        local charKey  = charEntry.key
        local charData = charEntry.data
        local row = UI.rows[i]
        if not row then
            row = { checkboxes = {} }
            row.charLabel = MakeLabel(content, "", 13, "LEFT")
            row.charLabel:SetWidth(COL_CHAR - 4)
            UI.rows[i] = row
        end

        -- Highlight current character row
        local isCurrent = (charKey == ST:GetCharKey())
        -- For the current character, read class live so color works before a relog
        local classFile = isCurrent and select(2, UnitClass("player")) or charData.class
        local charColor = GetClassColor(classFile) or (isCurrent and C_WHITE or C_GREY)

        -- Character name label
        row.charLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        row.charLabel:SetText(charColor .. charKey .. C_RESET)
        row.charLabel:Show()

        -- One checkbox per beast
        local serverTime = ST:GetServerNow()
        local lastReset = ST:GetLastResetTime(serverTime)
        for b, beast in ipairs(ST.BEASTS) do
            local cb = row.checkboxes[b]
            if not cb then
                cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                cb:SetSize(20, 20)
                row.checkboxes[b] = cb
            end

            local x = COL_CHAR + (b - 1) * COL_BEAST + (COL_BEAST / 2) - 8
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", x, y + 2)

            local ts = charData.beasts[beast.id]
            local skinnedToday = ts and (ts >= lastReset) or false
            cb:SetChecked(skinnedToday)

            local wasManual = skinnedToday
                and ST:WasManuallyMarked(beast.id, charData, lastReset)

            -- Tint the check itself so a hand-entered mark is distinguishable
            -- from a detected one. Set unconditionally on every pass: these
            -- checkbox frames are pooled and reused across rows, so leaving the
            -- colour unset would let a previous row's tint bleed through.
            local check = cb:GetCheckedTexture()
            if check then
                if wasManual then
                    check:SetVertexColor(0.45, 0.7, 1)
                else
                    check:SetVertexColor(1, 1, 1)
                end
            end

            -- Rows stay read-only unless Manual Edit is on, and only ever for
            -- the current character. Kept SetEnabled(true) in both states so the
            -- normal check texture is used rather than the greyed disabled one;
            -- RegisterForClicks is what actually gates interaction, because a
            -- CheckButton flips its own checked state on click before OnClick
            -- runs, so clearing the script alone would not stop it.
            local unlocked = UI.manualEdit and isCurrent
            cb:SetEnabled(true)
            if unlocked then
                local beastId = beast.id
                cb:RegisterForClicks("LeftButtonUp")
                cb:SetScript("OnClick", function()
                    ST:ToggleSkinnedManual(beastId)
                end)
            else
                cb:RegisterForClicks()
                cb:SetScript("OnClick", nil)
            end

            -- Tooltip works in both states; it is the only place the auto vs
            -- manual distinction is spelled out rather than just coloured.
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(beast.name, 1, 1, 1)
                GameTooltip:AddLine(charKey, 0.8, 0.8, 0.8)
                if skinnedToday then
                    local ago = SecondsToTime(math.max(0, ST:GetServerNow() - ts))
                    if wasManual then
                        GameTooltip:AddLine("Manually marked " .. ago .. " ago", 0.45, 0.7, 1)
                    else
                        GameTooltip:AddLine("Auto-detected " .. ago .. " ago", 0.4, 1, 0.6)
                    end
                else
                    GameTooltip:AddLine("Not skinned today", 0.7, 0.7, 0.7)
                end
                if unlocked then
                    GameTooltip:AddLine("Click to toggle.", 0.6, 0.6, 0.6)
                elseif isCurrent then
                    GameTooltip:AddLine("Enable Manual Edit to change this.", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cb:Show()
        end

        -- Hide any extra checkboxes if beasts list shrank
        for b = #ST.BEASTS + 1, #row.checkboxes do
            row.checkboxes[b]:Hide()
        end

        y = y - ROW_HEIGHT
    end

    -- Hide extra rows if character list shrank
    for i = #chars + 1, #UI.rows do
        local row = UI.rows[i]
        row.charLabel:Hide()
        for _, cb in ipairs(row.checkboxes) do
            cb:Hide()
        end
    end

    -- If no skinner characters yet, show a hint
    UI.hint = UI.hint or MakeLabel(content, "", 11, "LEFT")
    if #chars == 0 then
        UI.hint:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        UI.hint:SetWidth(FRAME_WIDTH - 60)
        UI.hint:SetText(C_GREY .. "No skinner characters tracked yet. Log in with a character that has Midnight Skinning." .. C_RESET)
        UI.hint:Show()
        y = y - ROW_HEIGHT
    else
        UI.hint:Hide()
    end

    return y
end

-- ---------------------------------------------------------------------------
-- Build item count section below beast rows
-- ---------------------------------------------------------------------------
local function BuildLootSection(content, startY)
    UI.loot = UI.loot or {}
    UI.loot.itemHeaders = UI.loot.itemHeaders or {}
    UI.loot.rows = UI.loot.rows or {}

    -- Divider
    if not UI.loot.divider then
        UI.loot.divider = content:CreateTexture(nil, "BACKGROUND")
        UI.loot.divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        UI.loot.divider:SetHeight(1)
        UI.loot.divider:SetWidth(FRAME_WIDTH - 50)
    end
    UI.loot.divider:SetPoint("TOPLEFT", content, "TOPLEFT", 2, startY - 8)
    UI.loot.divider:Show()

    local y = startY - 20

    -- Section header
    if not UI.loot.header then
        UI.loot.header = MakeLabel(content, "", 12, "LEFT")
    end
    UI.loot.header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    UI.loot.header:SetText(C_YELLOW .. "Item Counts" .. C_GREY .. "  (session / total)" .. C_RESET)
    UI.loot.header:Show()
    y = y - ROW_HEIGHT

    -- Item name column headers
    for i, item in ipairs(ST.MAJESTIC_ITEMS) do
        local x = COL_CHAR + (i - 1) * COL_ITEM
        local h = UI.loot.itemHeaders[i]
        if not h then
            h = MakeLabel(content, "", 10, "CENTER")
            h:SetWidth(COL_ITEM)
            UI.loot.itemHeaders[i] = h
        end
        h:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        h:SetText(C_YELLOW .. item.name .. C_RESET)
        h:Show()
    end
    for i = #ST.MAJESTIC_ITEMS + 1, #UI.loot.itemHeaders do
        UI.loot.itemHeaders[i]:Hide()
    end
    y = y - ROW_HEIGHT

    -- Per-character rows
    local chars = ST:GetAllCharacters()
    for i, charEntry in ipairs(chars) do
        local charKey  = charEntry.key
        local charData = charEntry.data
        local row = UI.loot.rows[i]
        if not row then
            row = { counts = {} }
            row.nameLabel = MakeLabel(content, "", 11, "LEFT")
            row.nameLabel:SetWidth(COL_CHAR - 4)
            UI.loot.rows[i] = row
        end

        local isCurrent = (charKey == ST:GetCharKey())
        local classFile = isCurrent and select(2, UnitClass("player")) or charData.class
        local charColor = GetClassColor(classFile) or (isCurrent and C_WHITE or C_GREY)

        row.nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        row.nameLabel:SetText(charColor .. charKey .. C_RESET)
        row.nameLabel:Show()

        for j, item in ipairs(ST.MAJESTIC_ITEMS) do
            local x = COL_CHAR + (j - 1) * COL_ITEM
            local label = row.counts[j]
            if not label then
                label = MakeLabel(content, "", 11, "CENTER")
                label:SetWidth(COL_ITEM)
                row.counts[j] = label
            end
            local session = isCurrent and (ST.sessionItems[item.id] or 0) or "-"
            local total   = (charData.items and charData.items[item.id]) or 0
            label:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
            label:SetText(C_GREEN .. tostring(session) .. C_GREY .. " / " .. C_WHITE .. tostring(total) .. C_RESET)
            label:Show()
        end
        for j = #ST.MAJESTIC_ITEMS + 1, #row.counts do
            row.counts[j]:Hide()
        end

        y = y - ROW_HEIGHT
    end

    -- Hide extra rows if character list shrank
    for i = #chars + 1, #UI.loot.rows do
        local row = UI.loot.rows[i]
        row.nameLabel:Hide()
        for _, label in ipairs(row.counts) do
            label:Hide()
        end
    end

    return y
end

-- ---------------------------------------------------------------------------
-- Public: Refresh the entire UI
-- ---------------------------------------------------------------------------
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    local y = BuildHeader(self.content)
    y = BuildRows(self.content, y)
    y = BuildLootSection(self.content, y)
    self.content:SetHeight(math.abs(y) + 20)

    UpdateEditButton()

    -- Update reset countdown
    self.frame.resetLabel:SetText("Reset in: " .. C_ORANGE .. ST:GetResetCountdown() .. C_RESET)
end

-- ---------------------------------------------------------------------------
-- Countdown ticker: refresh reset label every 30s while open, and keep the
-- ElvUI datatext current even while closed
-- ---------------------------------------------------------------------------
local ticker
local function StartTicker()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(30, function()
        if UI.frame and UI.frame:IsShown() then
            UI:Refresh()
        end
        -- The datatext registers only PLAYER_LOGIN, so without this it keeps
        -- showing yesterday's progress after the daily reset until the player
        -- skins something or reloads. It must update while the window is shut.
        if ST.RefreshDataText then
            ST:RefreshDataText()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Init: called after PLAYER_LOGIN gives us a valid player name
-- ---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        BuildFrame()
        StartTicker()

        -- Hook the frame Show to always refresh on open
        UI.frame:HookScript("OnShow", function()
            UI:Refresh()
        end)
    end
end)
