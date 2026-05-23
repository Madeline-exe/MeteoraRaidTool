local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local SoftReserve = MRT:NewModule("SoftReserve", "AceEvent-3.0")
MRT.SoftReserve = SoftReserve

-- reserves[player] = { itemID, itemID, ... }
local reserves = {}
local currentRaidID = nil
local reservesOpen = false

local function ambig(name) return Ambiguate(name, "short") end

function SoftReserve:OnEnable()
    local Comm = MRT.Comm
    Comm:On(Comm.MSG.RESERVE_SET,  function(p, s) self:OnRemoteSet(p, s) end)
    Comm:On(Comm.MSG.RESERVE_DEL,  function(p, s) self:OnRemoteDel(p, s) end)
    Comm:On(Comm.MSG.RESERVE_SYNC, function(p, s) self:OnRemoteSync(p, s) end)

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")

    MRT.db.global.reserveHistory = MRT.db.global.reserveHistory or {}
end

local HISTORY_LIMIT = 100

local function deepCopyReserves(src)
    local out = {}
    for player, items in pairs(src) do
        local copy = {}
        for i, id in ipairs(items) do copy[i] = id end
        out[player] = copy
    end
    return out
end

function SoftReserve:Snapshot(reason)
    if not currentRaidID then return end
    local hasAny = false
    for _, items in pairs(reserves) do
        if items and #items > 0 then hasAny = true; break end
    end
    if not hasAny then return end
    local hist = MRT.db.global.reserveHistory
    table.insert(hist, {
        timestamp = time(),
        raidID    = currentRaidID,
        reason    = reason,
        reserves  = deepCopyReserves(reserves),
    })
    while #hist > HISTORY_LIMIT do table.remove(hist, 1) end
end

-- ============================================================
-- Current raid & open/closed state (RL controls, all see)
-- ============================================================

function SoftReserve:GetCurrentRaid()
    return currentRaidID
end

function SoftReserve:IsOpen()
    return reservesOpen
end

function SoftReserve:SetCurrentRaid(raidID, open)
    if not MRT:CanLead() then
        MRT:Print(L["sr_need_lead"])
        return false
    end
    currentRaidID = raidID
    if open ~= nil then reservesOpen = open end
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, {
        currentRaidID = currentRaidID,
        reservesOpen  = reservesOpen,
        reserves      = reserves,
    })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return true
end

function SoftReserve:SetOpen(open)
    if not MRT:CanLead() then
        MRT:Print(L["sr_need_lead"])
        return false
    end
    local wasOpen = reservesOpen
    reservesOpen = open and true or false
    if wasOpen and not reservesOpen then
        self:Snapshot("closed")
    end
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, {
        currentRaidID = currentRaidID,
        reservesOpen  = reservesOpen,
        reserves      = reserves,
    })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return true
end

function SoftReserve:ClearAll()
    if not MRT:CanLead() then
        MRT:Print(L["sr_need_lead"])
        return false
    end
    reserves = {}
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, {
        currentRaidID = currentRaidID,
        reservesOpen  = reservesOpen,
        reserves      = reserves,
    })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return true
end

-- ============================================================
-- Player actions
-- ============================================================

function SoftReserve:CanReserve()
    return reservesOpen and currentRaidID ~= nil
end

function SoftReserve:HasReserved(player, itemID)
    local list = reserves[player]
    if not list then return false end
    for _, id in ipairs(list) do
        if id == itemID then return true end
    end
    return false
end

function SoftReserve:CountForPlayer(player)
    local list = reserves[player]
    return list and #list or 0
end

function SoftReserve:ToggleReserve(itemID)
    if not self:CanReserve() then
        MRT:Print(L["sr_closed"])
        return
    end
    local me = UnitName("player")
    reserves[me] = reserves[me] or {}
    local list = reserves[me]

    for i, id in ipairs(list) do
        if id == itemID then
            table.remove(list, i)
            MRT.Comm:Send(MRT.Comm.MSG.RESERVE_DEL, { player = me, itemID = itemID })
            MRT:SendMessage("MRT_SR_STATE_CHANGED")
            return
        end
    end

    local maxN = MRT.db.profile.softReserve.maxPerPlayer
    if #list >= maxN then
        MRT:Print(L["sr_max"]:format(maxN))
        return
    end

    table.insert(list, itemID)
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SET, { player = me, itemID = itemID })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

-- ============================================================
-- Comm handlers
-- ============================================================

function SoftReserve:OnRemoteSet(payload, sender)
    if not payload or not payload.itemID then return end
    if not reservesOpen and not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then
        -- Accept anyway; canonical state comes from sync
    end
    local player = payload.player or ambig(sender)
    reserves[player] = reserves[player] or {}
    for _, id in ipairs(reserves[player]) do
        if id == payload.itemID then return end
    end
    table.insert(reserves[player], payload.itemID)
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

function SoftReserve:OnRemoteDel(payload, sender)
    if not payload then return end
    local player = payload.player or ambig(sender)
    if payload.itemID then
        local list = reserves[player]
        if list then
            for i, id in ipairs(list) do
                if id == payload.itemID then table.remove(list, i); break end
            end
        end
    else
        reserves[player] = nil
    end
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

function SoftReserve:OnRemoteSync(payload, sender)
    if type(payload) ~= "table" then return end
    if payload.currentRaidID ~= nil then currentRaidID = payload.currentRaidID end
    if payload.reservesOpen ~= nil then reservesOpen = payload.reservesOpen end
    if type(payload.reserves) == "table" then reserves = payload.reserves end
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

-- ============================================================
-- Read API for UI / Loot
-- ============================================================

function SoftReserve:GetAll() return reserves end

function SoftReserve:GetReservesForItem(itemID)
    local out = {}
    for player, items in pairs(reserves) do
        for _, id in ipairs(items) do
            if id == itemID then table.insert(out, player); break end
        end
    end
    return out
end

function SoftReserve:OnEncounterStart()
    if MRT.db.profile.softReserve.lockedAfterPull and reservesOpen then
        if MRT:IsRaidLeader() then
            self:SetOpen(false)
        end
    end
end

function SoftReserve:GetHistory()
    return MRT.db.global.reserveHistory or {}
end
