local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Wishlist = MRT:NewModule("Wishlist", "AceEvent-3.0")
MRT.Wishlist = Wishlist

-- ============================================================
-- Long-term "I'd like this item eventually" lists.
-- Independent of raid SR — these are aspirational BIS lists each
-- player maintains for themselves. RL sees everyone's so they can
-- inform decisions ("Petya has this in his wishlist, give it to him
-- if nobody reserved").
--
-- Storage:
--   MRT.db.global.wishlist[playerName] = { itemID1, itemID2, ... }
-- ============================================================

local MAX_PER_PLAYER = 30
local wasInRaid = false
local lastRequestAt = 0

local function ambig(n) return Ambiguate(n or "", "short") end
local function me() return ambig(UnitName("player")) end

function Wishlist:OnInitialize()
    MRT.db.global.wishlist = MRT.db.global.wishlist or {}
end

function Wishlist:OnEnable()
    local Comm = MRT.Comm
    Comm:On(Comm.MSG.WISHLIST_SYNC,    function(p, s) self:OnRemoteSync(p, s) end)
    Comm:On(Comm.MSG.WISHLIST_REQUEST, function(p, s) self:OnRemoteRequest(p, s) end)

    self:RegisterEvent("GROUP_ROSTER_UPDATE",   "OnGroupChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnGroupChanged")
end

-- ============================================================
-- Read / Write API
-- ============================================================

function Wishlist:GetFor(player)
    return MRT.db.global.wishlist[ambig(player)] or {}
end

function Wishlist:GetAll()
    return MRT.db.global.wishlist
end

function Wishlist:Has(player, itemID)
    for _, id in ipairs(self:GetFor(player)) do
        if id == itemID then return true end
    end
    return false
end

function Wishlist:WantersOf(itemID)
    local out = {}
    for player, items in pairs(MRT.db.global.wishlist) do
        for _, id in ipairs(items) do
            if id == itemID then table.insert(out, player); break end
        end
    end
    return out
end

function Wishlist:Add(itemID)
    if not itemID then return false, "bad" end
    local name = me()
    local list = MRT.db.global.wishlist[name] or {}
    MRT.db.global.wishlist[name] = list
    for _, id in ipairs(list) do
        if id == itemID then return false, "already" end
    end
    if #list >= MAX_PER_PLAYER then return false, "max" end
    table.insert(list, itemID)
    self:Broadcast(name)
    MRT:SendMessage("MRT_WISHLIST_CHANGED")
    return true
end

function Wishlist:Remove(itemID)
    local name = me()
    local list = MRT.db.global.wishlist[name]
    if not list then return false end
    for i, id in ipairs(list) do
        if id == itemID then
            table.remove(list, i)
            self:Broadcast(name)
            MRT:SendMessage("MRT_WISHLIST_CHANGED")
            return true
        end
    end
    return false
end

function Wishlist:ClearMine()
    local name = me()
    MRT.db.global.wishlist[name] = {}
    self:Broadcast(name)
    MRT:SendMessage("MRT_WISHLIST_CHANGED")
end

-- ============================================================
-- Sync
-- ============================================================

function Wishlist:Broadcast(player)
    player = player or me()
    MRT.Comm:Send(MRT.Comm.MSG.WISHLIST_SYNC, {
        player = player,
        items  = MRT.db.global.wishlist[player] or {},
    })
end

function Wishlist:OnRemoteSync(payload, sender)
    if type(payload) ~= "table" or not payload.player then return end
    if type(payload.items) ~= "table" then return end
    MRT.db.global.wishlist[ambig(payload.player)] = payload.items
    MRT:SendMessage("MRT_WISHLIST_CHANGED")
end

function Wishlist:OnRemoteRequest(payload, sender)
    -- Reply with our own list
    self:Broadcast()
end

function Wishlist:OnGroupChanged()
    local inRaid = IsInRaid()
    if inRaid and not wasInRaid then
        local now = GetTime()
        if now - lastRequestAt > 5 then
            lastRequestAt = now
            -- Ask everyone for their wishlist; rebroadcast our own.
            MRT.Comm:Send(MRT.Comm.MSG.WISHLIST_REQUEST, {})
            self:Broadcast()
        end
    end
    wasInRaid = inRaid
end
