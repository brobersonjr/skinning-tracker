-- SkinningTrackerPrices.lua
-- Values skinned Majestic materials using Auctionator's scanned auction prices.
--
-- Auctionator is optional. Everything here degrades to "no price" rather than
-- erroring when it is absent, out of date, or has never been used to scan the
-- auction house on this realm.

local ST = SkinningTracker

-- Auctionator identifies calling addons by a plain string and rejects an empty
-- one. The addon folder name is the convention its own API docs ask for.
local CALLER_ID = "SkinningTracker"

local COPPER_PER_GOLD   = 10000
local COPPER_PER_SILVER = 100

-- Prices are considered worth a warning past this many days since the last
-- scan. Auctionator itself stops reporting an age beyond 21 days, so anything
-- older than that surfaces as an unknown age rather than a large number.
ST.PRICE_STALE_DAYS = 7

-- ---------------------------------------------------------------------------
-- Auctionator access
-- ---------------------------------------------------------------------------

-- Every Auctionator v1 entry point calls InternalVerifyID, which raises via
-- error(), and the price/age calls raise again on a wrong argument type. Our
-- callers sit on the 30-second UI ticker, so an uncaught raise would spam the
-- chat frame indefinitely. pcall turns any future signature change into a
-- missing number instead of a broken window.
local function CallAuctionator(fnName, itemId)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local fn = api and api[fnName]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, CALLER_ID, itemId)
    if not ok then return nil end
    return value
end

-- Is Auctionator loaded and exposing the v1 price API?
-- Distinguishes "no addon" from "addon present but never scanned", which are
-- very different problems from the player's point of view.
function ST:HasPriceSource()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    return type(api and api.GetAuctionPriceByItemID) == "function"
end

-- Returns the scanned price of an item in copper, plus the age of that scan in
-- days. Both are nil when there is nothing usable.
--
-- The price is Auctionator's `m` field: the MINIMUM buyout seen on the last
-- scan, not a mean or a market average. That is the only figure the v1 API
-- exposes, so the totals built on it are "what this would fetch if undercutting
-- the current lowest listing", not an appraisal.
--
-- Age is nil both when the item has never been seen and when the data is more
-- than 21 days old, so a price with no age means very stale, not fresh.
function ST:GetItemPrice(itemId)
    if type(itemId) ~= "number" then return nil end

    local price = CallAuctionator("GetAuctionPriceByItemID", itemId)
    if type(price) ~= "number" or price <= 0 then return nil end

    local age = CallAuctionator("GetAuctionAgeByItemID", itemId)
    if type(age) ~= "number" then age = nil end

    return price, age
end

-- ---------------------------------------------------------------------------
-- Valuing a count table
-- ---------------------------------------------------------------------------

-- Value an itemId -> count table at current scanned prices.
-- Returns: copper, unpricedCount, oldestAgeInDays
--
-- unpricedCount is not cosmetic. Without it a missing scan silently understates
-- the total and the player cannot tell a cheap session from an unpriced one, so
-- every caller surfaces it. Only items with a nonzero count can be unpriced:
-- a material that never dropped is not a gap in the data.
--
-- oldestAgeInDays is the worst age among the items that did have a price, since
-- one stale component is enough to make the total stale.
function ST:GetValueOf(counts)
    if type(counts) ~= "table" then return 0, 0, nil end

    local copper, unpriced, oldestAge = 0, 0, nil
    for _, item in ipairs(ST.MAJESTIC_ITEMS) do
        local qty = counts[item.id] or 0
        if qty > 0 then
            local price, age = ST:GetItemPrice(item.id)
            if price then
                copper = copper + price * qty
                if age and (not oldestAge or age > oldestAge) then
                    oldestAge = age
                end
            else
                unpriced = unpriced + 1
            end
        end
    end
    return copper, unpriced, oldestAge
end

-- Value of what the current character has looted since login. ST.sessionItems
-- is cleared at PLAYER_LOGIN, so this figure disappears on logout or /reload
-- with no extra bookkeeping and nothing written to SavedVariables.
--
-- Session is deliberately the ONLY thing valued. The stored per-character
-- `items` counts look like they could give a lifetime figure for free, but they
-- only ever increment: nothing decrements them when materials are sold, mailed,
-- vendored or crafted with. Multiplying them by today's price would produce a
-- number that is neither gold earned nor the value of what is actually in the
-- bags, and it would move with the market for materials long since sold.
-- Reporting realized earnings needs prices banked at loot time, which is a
-- different feature with its own state.
function ST:GetSessionValue()
    return ST:GetValueOf(ST.sessionItems)
end

-- ---------------------------------------------------------------------------
-- Money formatting
-- ---------------------------------------------------------------------------

-- Exact gold/silver/copper string. Prefers Blizzard's own formatter so the
-- output matches the rest of the client, and falls back to plain arithmetic so
-- the same function is exercisable outside the game.
function ST:FormatMoney(copper)
    copper = math.floor(tonumber(copper) or 0)

    if type(GetMoneyString) == "function" then
        local ok, s = pcall(GetMoneyString, copper, true)
        if ok and type(s) == "string" and s ~= "" then return s end
    end

    local g = math.floor(copper / COPPER_PER_GOLD)
    local s = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local c = copper % COPPER_PER_SILVER
    -- Gold uses %.0f rather than %d because it is the only unbounded component.
    -- A capped character holds around 10^11 copper, which is exact as a double
    -- but is not guaranteed to have an integer representation in every Lua
    -- build; silver and copper are always 0-99 and safe as %d.
    if g > 0 then return string.format("%.0fg %02ds %02dc", g, s, c) end
    if s > 0 then return string.format("%ds %02dc", s, c) end
    return string.format("%dc", c)
end

-- Whole gold with thousands separators, for the places where silver and copper
-- are noise. Totals under a gold keep full precision instead of collapsing to a
-- misleading "0g".
--
-- The separator is inserted by hand rather than with BreakUpLargeNumbers: that
-- global is client-side, and this function is covered by the test harness.
function ST:FormatMoneyShort(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < COPPER_PER_GOLD then return ST:FormatMoney(copper) end

    -- %.0f rather than tostring: tostring renders a whole-number float as
    -- "1234567.0" in some Lua builds, and the separator loop would then produce
    -- "1,234,567.0".
    local text = string.format("%.0f", math.floor(copper / COPPER_PER_GOLD))
    local subs = 1
    while subs > 0 do
        text, subs = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
    end
    return text .. "g"
end

-- ---------------------------------------------------------------------------
-- Live updates after an auction house scan
-- ---------------------------------------------------------------------------

-- Auctionator fires this after a full scan and after incremental price updates.
-- Without it, a session total computed before the player scanned would sit at
-- zero until the next 30-second tick; with it, the number corrects itself the
-- moment prices land.
local function RegisterForScans()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if type(api and api.RegisterForDBUpdate) ~= "function" then return end

    -- Registration is permanent and has no matching unregister, so this must
    -- run exactly once per session.
    pcall(api.RegisterForDBUpdate, CALLER_ID, function()
        if ST.UI and ST.UI.Refresh then ST.UI:Refresh() end
        if ST.RefreshDataText then ST:RefreshDataText() end
    end)
end

local priceFrame = CreateFrame("Frame")
priceFrame:RegisterEvent("PLAYER_LOGIN")
priceFrame:SetScript("OnEvent", function()
    -- Deferred one frame so Auctionator finishes its own PLAYER_LOGIN setup
    -- first, the same way the ElvUI datatext waits for ElvUI.
    C_Timer.After(0, RegisterForScans)
end)
