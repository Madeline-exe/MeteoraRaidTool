local ADDON_NAME, ns = ...
local MRT = ns.MRT

local RaidLoot = MRT:NewModule("RaidLoot", "AceEvent-3.0")
MRT.RaidLoot = RaidLoot

-- Storage shape:
-- MRT.db.global.raidLoot[raidID] = {
--     [bossIndex] = { itemID1, itemID2, ... },
--     ...
-- }

function RaidLoot:OnInitialize()
    MRT.db.global.raidLoot = MRT.db.global.raidLoot or {}
end

function RaidLoot:OnEnable()
    local Comm = MRT.Comm
    if Comm and Comm.MSG then
        Comm.MSG.RAIDLOOT_SYNC = Comm.MSG.RAIDLOOT_SYNC or "rlSync"
        Comm:On(Comm.MSG.RAIDLOOT_SYNC,    function(p, s) self:OnRemoteSync(p, s) end)
        Comm:On(Comm.MSG.RAIDLOOT_REQUEST, function(p, s) self:OnRemoteRequest(p, s) end)
    end
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnGroupChanged")
end

local wasInRaid = false
local lastRequestAt = 0

function RaidLoot:OnGroupChanged()
    local inRaid = IsInRaid()
    if inRaid and not wasInRaid then
        -- Just joined a raid. If we're not the RL, ask whoever IS for data.
        if not MRT:CanLead() then
            local now = GetTime()
            if now - lastRequestAt > 5 then
                lastRequestAt = now
                MRT.Comm:Send(MRT.Comm.MSG.RAIDLOOT_REQUEST, { wantAll = true })
            end
        else
            -- We're the RL. Re-broadcast everything we have so newly joined
            -- players catch up immediately.
            for raidID in pairs(MRT.db.global.raidLoot or {}) do
                if self:HasAnyItems(raidID) then self:Broadcast(raidID) end
            end
        end
    end
    wasInRaid = inRaid
end

function RaidLoot:OnRemoteRequest(payload, sender)
    if not MRT:CanLead() then return end
    -- Reply with whatever we have. Throttle a tiny bit to avoid flooding
    -- if multiple players request simultaneously.
    for raidID in pairs(MRT.db.global.raidLoot or {}) do
        if self:HasAnyItems(raidID) then self:Broadcast(raidID) end
    end
end

local function ensureBossSlot(raidID, bossIndex)
    local db = MRT.db.global.raidLoot
    db[raidID] = db[raidID] or {}
    db[raidID][bossIndex] = db[raidID][bossIndex] or {}
    return db[raidID][bossIndex]
end

local function parseItemID(input)
    if type(input) == "number" then return input end
    if type(input) ~= "string" then return nil end
    local id = input:match("item:(%d+)")
    if id then return tonumber(id) end
    return tonumber(input)
end

-- ===========================================================
-- Read API
-- ===========================================================

function RaidLoot:GetRaid(raidID)
    return ns.RaidsByID[raidID]
end

function RaidLoot:GetBoss(raidID, bossIndex)
    local raid = ns.RaidsByID[raidID]
    if not raid then return nil end
    return raid.bosses[bossIndex]
end

function RaidLoot:GetItems(raidID, bossIndex)
    local db = MRT.db.global.raidLoot
    if not db[raidID] then return {} end
    return db[raidID][bossIndex] or {}
end

function RaidLoot:HasAnyItems(raidID)
    local db = MRT.db.global.raidLoot[raidID]
    if not db then return false end
    for _, items in pairs(db) do
        if #items > 0 then return true end
    end
    return false
end

-- ===========================================================
-- Mutations (RL only)
-- ===========================================================

local function canEdit()
    return MRT:CanLead()
end

function RaidLoot:AddItem(raidID, bossIndex, itemInput)
    if not canEdit() then
        MRT:Print(ns.L["sr_need_lead"])
        return false
    end
    local itemID = parseItemID(itemInput)
    if not itemID then
        MRT:Print(ns.L["loot_bad_item"])
        return false
    end
    local items = ensureBossSlot(raidID, bossIndex)
    for _, id in ipairs(items) do
        if id == itemID then return false end
    end
    table.insert(items, itemID)
    self:Broadcast(raidID)
    return true
end

function RaidLoot:RemoveItem(raidID, bossIndex, itemID)
    if not canEdit() then return false end
    local items = ensureBossSlot(raidID, bossIndex)
    for i, id in ipairs(items) do
        if id == itemID then
            table.remove(items, i)
            self:Broadcast(raidID)
            return true
        end
    end
    return false
end

function RaidLoot:ClearRaid(raidID)
    if not canEdit() then return false end
    MRT.db.global.raidLoot[raidID] = {}
    self:Broadcast(raidID)
    return true
end

-- ===========================================================
-- Sync
-- ===========================================================

function RaidLoot:Broadcast(raidID)
    local Comm = MRT.Comm
    if not (Comm and Comm.MSG and Comm.MSG.RAIDLOOT_SYNC) then return end
    Comm:Send(Comm.MSG.RAIDLOOT_SYNC, {
        raidID = raidID,
        bosses = MRT.db.global.raidLoot[raidID] or {},
    })
    MRT:SendMessage("MRT_RAIDLOOT_CHANGED", raidID)
end

function RaidLoot:OnRemoteSync(payload, sender)
    if type(payload) ~= "table" or not payload.raidID then return end
    MRT.db.global.raidLoot[payload.raidID] = payload.bosses or {}
    MRT:SendMessage("MRT_RAIDLOOT_CHANGED", payload.raidID)
end

function RaidLoot:RequestSync(raidID)
    -- Anyone (esp. RL) can rebroadcast their current data so late joiners catch up.
    if self:HasAnyItems(raidID) then
        self:Broadcast(raidID)
    end
end
