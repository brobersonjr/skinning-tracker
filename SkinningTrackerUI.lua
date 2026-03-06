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
-- Helper: create a standard button
-- ---------------------------------------------------------------------------
local function MakeButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

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
-- Build the main frame (called once)
-- ---------------------------------------------------------------------------
local function BuildFrame()
    local f = CreateFrame("Frame", "SkinningTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

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

    -- Bottom bar: reset countdown + current char toggle button
    local bottomBar = CreateFrame("Frame", nil, f)
    bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    bottomBar:SetHeight(28)

    local resetLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetLabel:SetPoint("LEFT", bottomBar, "LEFT", 0, 0)
    resetLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    f.resetLabel = resetLabel


    UI.frame   = f
    UI.content = content
    UI.rows    = {}
end

-- ---------------------------------------------------------------------------
-- Build the column header row
-- ---------------------------------------------------------------------------
local function BuildHeader(content)
    local y = -6
    -- "Character" label
    local charHeader = MakeLabel(content, C_YELLOW .. "Character" .. C_RESET, 12, "LEFT")
    charHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)

    -- Beast name headers
    for i, beast in ipairs(ST.BEASTS) do
        local x = COL_CHAR + (i - 1) * COL_BEAST
        local bHeader = MakeLabel(content, C_YELLOW .. beast.name .. C_RESET, 10, "CENTER")
        bHeader:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        bHeader:SetWidth(COL_BEAST)

        -- Tooltip with zone/coords
        bHeader:EnableMouse(true)
        local zone = beast.zone
        local coords = beast.coords
        bHeader:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(beast.name, 1, 1, 1)
            GameTooltip:AddLine(zone, 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Coords: " .. coords, 0.7, 0.9, 0.7)
            GameTooltip:AddLine("Click checkboxes to toggle skinned state.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        bHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Divider line
    local line = content:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y - 16)
    line:SetWidth(FRAME_WIDTH - 50)

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
    -- Wipe old rows
    for _, row in ipairs(UI.rows) do
        for _, widget in ipairs(row) do
            widget:Hide()
            if widget.SetText then widget:SetText("") end
        end
    end
    UI.rows = {}

    local chars = ST:GetAllCharacters()
    local y = startY

    for _, charEntry in ipairs(chars) do
        local charKey  = charEntry.key
        local charData = charEntry.data
        local rowWidgets = {}

        -- Highlight current character row
        local isCurrent = (charKey == (UnitName("player") .. "-" .. GetRealmName()))
        -- For the current character, read class live so color works before a relog
        local classFile = isCurrent and select(2, UnitClass("player")) or charData.class
        local charColor = GetClassColor(classFile) or (isCurrent and C_WHITE or C_GREY)

        -- Character name label (truncate if long)
        local charLabel = MakeLabel(content, charColor .. charKey .. C_RESET, 13, "LEFT")
        charLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        charLabel:SetWidth(COL_CHAR - 4)
        table.insert(rowWidgets, charLabel)

        -- One checkbox per beast
        for i, beast in ipairs(ST.BEASTS) do
            local x = COL_CHAR + (i - 1) * COL_BEAST + (COL_BEAST / 2) - 8

            -- Check skinned state using the beast id and the stored timestamps vs last reset
            -- We compute per-char directly since ST methods use the current char
            local ts = charData.beasts[beast.id]
            local lastReset = ST:GetTimeUntilReset() -- we use this path for current char only
            -- For all chars compute independently:
            local serverTime = C_DateAndTime and C_DateAndTime.GetServerTime and C_DateAndTime.GetServerTime() or time()
            local function GetLastResetFor()
                local d = date("!*t", serverTime)
                local todayReset = serverTime - (d.hour * 3600) - (d.min * 60) - d.sec + (15 * 3600)
                if serverTime < todayReset then todayReset = todayReset - 86400 end
                return todayReset
            end
            local skinnedToday = ts and (ts >= GetLastResetFor())

            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetSize(20, 20)
            cb:SetPoint("TOPLEFT", content, "TOPLEFT", x, y + 2)
            cb:SetChecked(skinnedToday)

            -- Only allow toggling the current character
            if isCurrent then
                local beastId = beast.id
                cb:SetScript("OnClick", function(self)
                    ST:ToggleSkinned(beastId)
                end)
            else
                cb:SetEnabled(false)
            end

            table.insert(rowWidgets, cb)
        end

        table.insert(UI.rows, rowWidgets)
        y = y - ROW_HEIGHT
    end

    -- If no skinner characters yet, show a hint
    if #chars == 0 then
        local hint = MakeLabel(content, C_GREY .. "No skinner characters tracked yet. Log in with a character that has Midnight Skinning." .. C_RESET, 11, "LEFT")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        hint:SetWidth(FRAME_WIDTH - 60)
        table.insert(UI.rows, { hint })
        y = y - ROW_HEIGHT
    end

    return y
end

-- ---------------------------------------------------------------------------
-- Build item count section below beast rows
-- ---------------------------------------------------------------------------
local function BuildLootSection(content, startY)
    -- Divider
    local line = content:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 2, startY - 8)
    line:SetWidth(FRAME_WIDTH - 50)

    local y = startY - 20

    -- Section header
    local header = MakeLabel(content, C_YELLOW .. "Item Counts" .. C_RESET, 12, "LEFT")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    y = y - ROW_HEIGHT

    -- Item name column headers
    for i, item in ipairs(ST.MAJESTIC_ITEMS) do
        local x = COL_CHAR + (i - 1) * COL_ITEM
        local h = MakeLabel(content, C_YELLOW .. item.name .. C_RESET, 10, "CENTER")
        h:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        h:SetWidth(COL_ITEM)
    end
    y = y - ROW_HEIGHT

    -- Per-character rows
    local chars = ST:GetAllCharacters()
    for _, charEntry in ipairs(chars) do
        local charKey  = charEntry.key
        local charData = charEntry.data
        local isCurrent = (charKey == (UnitName("player") .. "-" .. GetRealmName()))
        local classFile = isCurrent and select(2, UnitClass("player")) or charData.class
        local charColor = GetClassColor(classFile) or (isCurrent and C_WHITE or C_GREY)

        local nameLabel = MakeLabel(content, charColor .. charKey .. C_RESET, 11, "LEFT")
        nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        nameLabel:SetWidth(COL_CHAR - 4)

        for i, item in ipairs(ST.MAJESTIC_ITEMS) do
            local x = COL_CHAR + (i - 1) * COL_ITEM
            local count = (charData.items and charData.items[item.id]) or 0
            local countLabel = MakeLabel(content, C_WHITE .. tostring(count) .. C_RESET, 11, "CENTER")
            countLabel:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
            countLabel:SetWidth(COL_ITEM)
        end

        y = y - ROW_HEIGHT
    end

    return y
end

-- ---------------------------------------------------------------------------
-- Public: Refresh the entire UI
-- ---------------------------------------------------------------------------
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    -- Wipe content
    for _, child in pairs({ self.content:GetChildren() }) do
        child:Hide()
    end
    for _, region in pairs({ self.content:GetRegions() }) do
        region:Hide()
    end
    UI.rows = {}

    local y = BuildHeader(self.content)
    y = BuildRows(self.content, y)
    y = BuildLootSection(self.content, y)
    self.content:SetHeight(math.abs(y) + 20)

    -- Update reset countdown
    self.frame.resetLabel:SetText("Reset in: " .. C_ORANGE .. ST:GetResetCountdown() .. C_RESET)
end

-- ---------------------------------------------------------------------------
-- Countdown ticker: refresh reset label every 30s while open
-- ---------------------------------------------------------------------------
local ticker
local function StartTicker()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(30, function()
        if UI.frame and UI.frame:IsShown() then
            UI:Refresh()
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
