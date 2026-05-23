local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local AutoTrade = MRT:NewModule("AutoTrade", "AceEvent-3.0")
MRT.AutoTrade = AutoTrade

-- ============================================================
-- Queue items the RL has awarded so they get auto-placed in the
-- next trade window with that player.
--
-- Storage:
--   MRT.db.global.pendingTrades[playerName] = {
--       { itemID = N, link = "[item]", awardedAt = ts }, ...
--   }
-- ============================================================

local function ambig(n) return Ambiguate(n or "", "short") end

function AutoTrade:OnInitialize()
    MRT.db.global.pendingTrades = MRT.db.global.pendingTrades or {}
end

function AutoTrade:OnEnable()
    self:RegisterEvent("TRADE_SHOW",        "OnTradeShow")
    self:RegisterEvent("TRADE_CLOSED",      "OnTradeClosed")
    self:RegisterEvent("TRADE_ACCEPT_UPDATE","OnTradeAcceptUpdate")
end

function AutoTrade:Queue(winner, itemID, link)
    if not winner or not itemID then return end
    local name = ambig(winner)
    local list = MRT.db.global.pendingTrades[name]
    if not list then
        list = {}
        MRT.db.global.pendingTrades[name] = list
    end
    table.insert(list, { itemID = itemID, link = link, awardedAt = time() })
end

function AutoTrade:GetPending(playerName)
    return MRT.db.global.pendingTrades[ambig(playerName)] or {}
end

function AutoTrade:ClearPending(playerName, itemID)
    local name = ambig(playerName)
    local list = MRT.db.global.pendingTrades[name]
    if not list then return end
    if not itemID then
        MRT.db.global.pendingTrades[name] = nil
        return
    end
    for i, entry in ipairs(list) do
        if entry.itemID == itemID then table.remove(list, i); return end
    end
end

-- ============================================================
-- Bag scanning + placement
-- ============================================================

local function getContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function getContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot) or nil
end

local function pickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        return C_Container.PickupContainerItem(bag, slot)
    end
    return PickupContainerItem and PickupContainerItem(bag, slot) or nil
end

local function findItemInBags(itemID)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, getContainerNumSlots(bag) do
            if getContainerItemID(bag, slot) == itemID then
                return bag, slot
            end
        end
    end
end

local function freeTradeSlot()
    -- MAX_TRADE_ITEMS=6 in TBC. Find the first slot with no item link.
    for i = 1, (MAX_TRADE_ITEMS or 6) do
        local link = GetTradePlayerItemLink and GetTradePlayerItemLink(i)
        if not link then return i end
    end
end

-- Drop a single bag item into the next free trade slot.
local function placeInTrade(bag, slot)
    local tradeSlot = freeTradeSlot()
    if not tradeSlot then return false end
    ClearCursor()
    pickupContainerItem(bag, slot)
    if CursorHasItem and CursorHasItem() then
        ClickTradeButton(tradeSlot)
        return true
    end
    return false
end

-- ============================================================
-- TRADE_SHOW handler
-- ============================================================

function AutoTrade:OnTradeShow()
    -- Who are we trading with?
    local partner = UnitName("NPC") or UnitName("npc")
    if not partner then return end

    local pending = self:GetPending(partner)
    if not pending or #pending == 0 then return end

    -- Try to auto-place each pending item. Iterate over a copy because we
    -- mutate the queue as items succeed.
    local copy = {}
    for i, e in ipairs(pending) do copy[i] = e end

    local placed, missing = 0, 0
    for _, entry in ipairs(copy) do
        local bag, slot = findItemInBags(entry.itemID)
        if bag then
            if placeInTrade(bag, slot) then
                placed = placed + 1
                self:ClearPending(partner, entry.itemID)
            end
        else
            missing = missing + 1
        end
    end

    if placed > 0 then
        MRT:Print(L["trade_placed"]:format(placed, partner))
    end
    if missing > 0 then
        MRT:Print(L["trade_missing"]:format(missing, partner))
    end
end

function AutoTrade:OnTradeClosed() end
function AutoTrade:OnTradeAcceptUpdate(_, playerAccepted, partnerAccepted)
    -- If trade actually went through (both accepted), we trust the items
    -- moved. Nothing to do — pending was already pruned in OnTradeShow.
end

-- ============================================================
-- Public utility for UI: get count of items still owed to a player
-- ============================================================

function AutoTrade:CountFor(playerName)
    local list = self:GetPending(playerName)
    return list and #list or 0
end
