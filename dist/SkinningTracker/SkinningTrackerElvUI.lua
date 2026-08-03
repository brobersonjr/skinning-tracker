-- SkinningTrackerElvUI.lua
-- Registers a Data Text plugin for ElvUI showing today's beast skinning progress.
-- Gracefully skips registration if ElvUI is not installed.

local ST = SkinningTracker

local C_GREEN  = "|cff00ff96"
local C_YELLOW = "|cffffff00"
local C_RED    = "|cffff4444"
local C_ORANGE = "|cffff9900"
local C_GREY   = "|cff888888"
local C_RESET  = "|r"

-- Panels ElvUI has handed us, mapped to the exact string we last wrote there.
-- ElvUI allows the same datatext on several panels, so a single reference would
-- only ever refresh whichever one fired its event last.
--
-- The stored string is what makes releasing a panel possible. ElvUI reuses these
-- frames: assign a slot to a different datatext and the same frame object is
-- handed to that datatext instead. Holding the reference forever would let our
-- ticker overwrite whatever now owns the slot. Rather than reach into ElvUI
-- internals to detect that, we simply check whether the panel still shows the
-- text we put there, and let go of it if it does not.
local dtFrames = {}
local DT      -- ElvUI DataTexts module, set in InitElvUI

-- Builds the datatext string, or nil when there is nothing to show
local function BuildText()
    if not ST or not ST.GetCharData then return nil end
    local data = ST:GetCharData()
    if not data or not data.isMidnightSkinner then
        return C_GREY .. "Not a Skinner" .. C_RESET
    end
    local total = #ST.BEASTS
    local done = 0
    for _, beast in ipairs(ST.BEASTS) do
        if ST:HasSkinnedToday(beast.id) then
            done = done + 1
        end
    end
    local remaining = total - done
    if remaining == 0 then
        return C_GREEN .. "Skins: Done!" .. C_RESET
    end
    return C_YELLOW .. "Skins: " .. remaining .. "/" .. total .. C_RESET
end

local function UpdateText(self)
    local text = BuildText()
    if not text or not self.text then return end
    self.text:SetText(text)
    dtFrames[self] = text -- remember exactly what we wrote
end

-- True while the panel still displays the string we last wrote to it
local function StillOurs(frame, lastText)
    if not frame.text or not frame.text.GetText then return false end
    local ok, current = pcall(frame.text.GetText, frame.text)
    return ok and current == lastText
end

-- Called by ST:MarkSkinned / ST:ToggleSkinnedManual and the UI ticker to keep
-- every datatext panel live
function ST:RefreshDataText()
    -- Clearing existing keys during traversal is well-defined in Lua; only
    -- adding new ones would be, and UpdateText only ever rewrites keys already
    -- present here.
    for frame, lastText in pairs(dtFrames) do
        if StillOurs(frame, lastText) then
            UpdateText(frame)
        else
            dtFrames[frame] = nil -- ElvUI gave this slot to something else
        end
    end
end

local function OnEvent(self, event, ...)
    UpdateText(self) -- also registers the panel for RefreshDataText
end

local function OnClick(self, btn)
    if ST and ST.UI then
        if ST.UI.frame:IsShown() then
            ST.UI.frame:Hide()
        else
            ST.UI.frame:Show()
            ST.UI:Refresh()
        end
    end
end

local function OnEnter(self)
    -- ANCHOR_TOP grows the tooltip upward from the panel, which is what a
    -- datatext bar wants: the bar is a thin strip and every line we add moves
    -- the tooltip further away from the screen edge it sits on. The previous
    -- ANCHOR_BOTTOMLEFT pinned the tooltip's top-right to the panel's
    -- bottom-left, so it grew down and to the left and ended up beside the bar
    -- rather than above it. Matches the ANCHOR_TOP used throughout the UI file.
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Skinning Tracker", 0, 1, 0.59)

    if not ST or not ST.GetCharData then
        GameTooltip:Show()
        return
    end

    local data = ST:GetCharData()
    if not data or not data.isMidnightSkinner then
        GameTooltip:AddLine("Not a Midnight Skinner", 1, 1, 1)
        GameTooltip:Show()
        return
    end

    -- Beast progress
    GameTooltip:AddLine(" ")
    for _, beast in ipairs(ST.BEASTS) do
        local skinned = ST:HasSkinnedToday(beast.id)
        local r, g, b = skinned and 0 or 1, skinned and 1 or 0.27, skinned and 0.59 or 0.27
        local status = skinned and "Done" or "Remaining"
        GameTooltip:AddDoubleLine(beast.name, status, 1, 1, 1, r, g, b)
    end

    -- Majestic item totals (lifetime, per character)
    if ST.MAJESTIC_ITEMS and data.items then
        local anyMajestic = false
        for _, item in ipairs(ST.MAJESTIC_ITEMS) do
            if (data.items[item.id] or 0) > 0 then
                anyMajestic = true
                break
            end
        end
        if anyMajestic then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Majestic Items:", 1, 0.8, 0)
            for _, item in ipairs(ST.MAJESTIC_ITEMS) do
                local qty = data.items[item.id] or 0
                GameTooltip:AddDoubleLine(item.name, "x" .. qty, 1, 1, 1, qty > 0 and 1 or 0.5, qty > 0 and 1 or 0.5, qty > 0 and 0 or 0.5)
            end

            -- Auctionator valuation of this session, when it is installed and
            -- has prices. Silent otherwise: this tooltip belongs to the beast
            -- tracker, and a "no price data" line here would be noise for
            -- anyone who does not use Auctionator at all.
            if ST.HasPriceSource and ST:HasPriceSource() then
                local copper, unpriced = ST:GetSessionValue()
                if copper > 0 then
                    GameTooltip:AddDoubleLine("Session value",
                        ST:FormatMoney(copper) .. (unpriced > 0 and " *" or ""),
                        0.8, 0.8, 0.8, 0, 1, 0.59)
                end
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Reset in: " .. ST:GetResetCountdown(), 1, 0.6, 0)
    GameTooltip:AddLine("Click to open Skinning Tracker", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

local function InitElvUI()
    if not C_AddOns.IsAddOnLoaded("ElvUI") then return end
    local E = unpack(ElvUI)
    if not E then return end
    DT = E:GetModule("DataTexts")
    if not DT then return end

    DT:RegisterDatatext("SkinningTracker", "SkinningTracker", {"PLAYER_LOGIN"}, OnEvent, nil, OnClick, OnEnter, OnLeave, "Skinning Tracker")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    -- Defer by one frame so ElvUI finishes its own PLAYER_LOGIN setup first
    C_Timer.After(0, InitElvUI)
end)
