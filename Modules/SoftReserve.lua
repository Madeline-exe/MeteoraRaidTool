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
    Comm:On(Comm.MSG.RESERVE_SET,     function(p, s) self:OnRemoteSet(p, s) end)
    Comm:On(Comm.MSG.RESERVE_DEL,     function(p, s) self:OnRemoteDel(p, s) end)
    Comm:On(Comm.MSG.RESERVE_SYNC,    function(p, s) self:OnRemoteSync(p, s) end)
    Comm:On(Comm.MSG.RESERVE_REQUEST, function(p, s) self:OnRemoteRequest(p, s) end)
    Comm:On(Comm.MSG.RESERVE_SNAPSHOT,function(p, s) self:OnRemoteSnapshot(p, s) end)

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnGroupChanged")

    MRT.db.global.reserveHistory = MRT.db.global.reserveHistory or {}
    -- Authoritative max-per-player lives in global so RL can broadcast a
    -- value that overrides each client's local default.
    MRT.db.global.softReserve = MRT.db.global.softReserve or {}
    if not MRT.db.global.softReserve.maxPerPlayer then
        MRT.db.global.softReserve.maxPerPlayer = MRT.db.profile.softReserve.maxPerPlayer or 2
    end
end

function SoftReserve:GetMaxPerPlayer()
    return MRT.db.global.softReserve and MRT.db.global.softReserve.maxPerPlayer
        or MRT.db.profile.softReserve.maxPerPlayer or 2
end

local function buildSyncPayload()
    return {
        currentRaidID = currentRaidID,
        reservesOpen  = reservesOpen,
        reserves      = reserves,
        maxPerPlayer  = MRT.db.global.softReserve and MRT.db.global.softReserve.maxPerPlayer,
    }
end

function SoftReserve:SetMaxPerPlayer(n)
    if not MRT:CanLead() then
        MRT:Print(L["sr_need_lead"])
        return false
    end
    n = tonumber(n) or 2
    if n < 1 then n = 1 elseif n > 20 then n = 20 end
    MRT.db.global.softReserve.maxPerPlayer = n
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return true
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

local function appendSnapshotUnique(record)
    local hist = MRT.db.global.reserveHistory
    for i = #hist, math.max(1, #hist - 20), -1 do
        local e = hist[i]
        if e.raidID == record.raidID
           and math.abs((e.timestamp or 0) - record.timestamp) < 30 then
            return false
        end
    end
    table.insert(hist, record)
    while #hist > HISTORY_LIMIT do table.remove(hist, 1) end
    return true
end

function SoftReserve:Snapshot(reason)
    if not currentRaidID then return end
    local hasAny = false
    for _, items in pairs(reserves) do
        if items and #items > 0 then hasAny = true; break end
    end
    if not hasAny then return end
    local record = {
        timestamp = time(),
        raidID    = currentRaidID,
        reason    = reason,
        reserves  = deepCopyReserves(reserves),
    }
    appendSnapshotUnique(record)
    if MRT.Comm and MRT.Comm.MSG.RESERVE_SNAPSHOT then
        MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SNAPSHOT, record)
    end
end

function SoftReserve:OnRemoteSnapshot(payload, sender)
    if type(payload) ~= "table" or not payload.raidID then return end
    if appendSnapshotUnique(payload) then
        if MRT.UI and MRT.UI.RefreshLater then MRT.UI:RefreshLater() end
    end
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
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
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
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return true
end

function SoftReserve:ClearAll()
    if not MRT:CanLead() then
        MRT:Print(L["sr_need_lead"])
        return false
    end
    reserves = {}
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
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

-- How many of their SR slots this player has spent on a specific item.
-- Multi-reserve lets a player stack the same item to increase their priority.
function SoftReserve:GetReserveCountForItem(player, itemID)
    local list = reserves[player]
    if not list then return 0 end
    local n = 0
    for _, id in ipairs(list) do
        if id == itemID then n = n + 1 end
    end
    return n
end

-- Mark which players reserved through a whisper flow (no addon installed).
-- Cleared when the player is removed entirely.
local viaWhisper = {}

function SoftReserve:IsViaWhisper(player)
    return viaWhisper[player] == true
end

-- Add a reservation on behalf of a player (e.g. a pug who whispered us).
-- Returns one of: "ok", "already", "max", "not_in_pool", "no_raid", "closed".
function SoftReserve:AddForPlayer(player, itemID, opts)
    if not MRT:CanLead() then return "denied" end
    if not currentRaidID then return "no_raid" end
    if not reservesOpen then return "closed" end

    reserves[player] = reserves[player] or {}
    if #reserves[player] >= self:GetMaxPerPlayer() then return "max" end

    -- Item must be in this raid's drop table to count.
    local found = false
    local raid = ns.RaidsByID[currentRaidID]
    if raid then
        for bossIndex in ipairs(raid.bosses) do
            for _, id in ipairs(MRT.RaidLoot:GetItems(currentRaidID, bossIndex)) do
                if id == itemID then found = true; break end
            end
            if found then break end
        end
    end
    if not found then return "not_in_pool" end

    table.insert(reserves[player], itemID)
    if opts and opts.viaWhisper then viaWhisper[player] = true end
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SET, { player = player, itemID = itemID })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    return "ok"
end

function SoftReserve:AddReserveForSelf(itemID)
    if not self:CanReserve() then
        MRT:Print(L["sr_closed"])
        return
    end
    local me = UnitName("player")
    reserves[me] = reserves[me] or {}
    local list = reserves[me]

    local maxN = self:GetMaxPerPlayer()
    if #list >= maxN then
        MRT:Print(L["sr_max"]:format(maxN))
        return
    end

    table.insert(list, itemID)
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SET, { player = me, itemID = itemID })
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

function SoftReserve:RemoveReserveForSelf(itemID)
    if not self:CanReserve() then
        MRT:Print(L["sr_closed"])
        return
    end
    local me = UnitName("player")
    local list = reserves[me]
    if not list then return end

    for i = #list, 1, -1 do
        if list[i] == itemID then
            table.remove(list, i)
            MRT.Comm:Send(MRT.Comm.MSG.RESERVE_DEL, { player = me, itemID = itemID })
            MRT:SendMessage("MRT_SR_STATE_CHANGED")
            return
        end
    end
end

-- ============================================================
-- Comm handlers
-- ============================================================

function SoftReserve:OnRemoteSet(payload, sender)
    if not payload or not payload.itemID then return end
    -- AceComm delivers our own RAID broadcast back to us. We already applied
    -- the change locally in AddReserveForSelf / AddForPlayer, so accepting the
    -- echo here would double the reserve count on every single click. Skip.
    if sender and Ambiguate(sender, "short") == UnitName("player") then return end
    if not reservesOpen and not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then
        -- Accept anyway; canonical state comes from sync
    end
    local player = payload.player or ambig(sender)
    reserves[player] = reserves[player] or {}
    -- No duplicate check: multi-reserve is intentional.
    table.insert(reserves[player], payload.itemID)
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
end

function SoftReserve:OnRemoteDel(payload, sender)
    if not payload then return end
    -- Same self-echo guard as OnRemoteSet: RemoveReserveForSelf already
    -- removed the local entry before broadcasting.
    if sender and Ambiguate(sender, "short") == UnitName("player") then return end
    local player = payload.player or ambig(sender)
    if payload.itemID then
        local list = reserves[player]
        if list then
            if payload.all then
                for i = #list, 1, -1 do
                    if list[i] == payload.itemID then table.remove(list, i) end
                end
            else
                for i, id in ipairs(list) do
                    if id == payload.itemID then table.remove(list, i); break end
                end
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
    if type(payload.maxPerPlayer) == "number" then
        MRT.db.global.softReserve = MRT.db.global.softReserve or {}
        MRT.db.global.softReserve.maxPerPlayer = payload.maxPerPlayer
    end
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

local srWasInRaid = false
local srLastReqAt = 0

function SoftReserve:OnGroupChanged()
    local inRaid = IsInRaid()
    if inRaid and not srWasInRaid then
        if not MRT:CanLead() then
            local now = GetTime()
            if now - srLastReqAt > 5 then
                srLastReqAt = now
                MRT.Comm:Send(MRT.Comm.MSG.RESERVE_REQUEST, {})
            end
        else
            -- RL: rebroadcast current SR state to anyone who just joined.
            MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
        end
    end
    srWasInRaid = inRaid
end

function SoftReserve:OnRemoteRequest(payload, sender)
    if not MRT:CanLead() then return end
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, buildSyncPayload())
end

function SoftReserve:GetHistory()
    return MRT.db.global.reserveHistory or {}
end
