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

local dtFrame -- reference captured on first OnEvent, used by ST:RefreshDataText()
local DT      -- ElvUI DataTexts module, set in InitElvUI

local function UpdateText(self)
    if not ST or not ST.GetCharData then return end
    local data = ST:GetCharData()
    if not data or not data.isMidnightSkinner then
        self.text:SetText(C_GREY .. "Not a Skinner" .. C_RESET)
        return
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
        self.text:SetText(C_GREEN .. "Skins: Done!" .. C_RESET)
    else
        self.text:SetText(C_YELLOW .. "Skins: " .. remaining .. "/" .. total .. C_RESET)
    end
end

-- Called by ST:MarkSkinned / ST:ToggleSkinned to keep the datatext live
function ST:RefreshDataText()
    if dtFrame then UpdateText(dtFrame) end
end

local function OnEvent(self, event, ...)
    dtFrame = self -- capture frame reference for RefreshDataText
    UpdateText(self)
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
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
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
