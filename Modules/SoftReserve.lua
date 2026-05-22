local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local SoftReserve = MRT:NewModule("SoftReserve", "AceEvent-3.0")
MRT.SoftReserve = SoftReserve

local reserves = {}
local locked = false

function SoftReserve:OnEnable()
    local Comm = MRT.Comm
    Comm:On(Comm.MSG.RESERVE_SET, function(payload, sender) self:OnRemoteSet(payload, sender) end)
    Comm:On(Comm.MSG.RESERVE_DEL, function(payload, sender) self:OnRemoteDel(payload, sender) end)
    Comm:On(Comm.MSG.RESERVE_SYNC, function(payload, sender) self:OnRemoteSync(payload, sender) end)

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END",   "OnEncounterEnd")
end

function SoftReserve:HandleSlash(rest)
    rest = (rest or ""):trim()
    if rest == "" or rest == "list" then
        self:PrintList()
        return
    end
    if rest == "clear" then
        self:ClearMine()
        return
    end
    if rest == "lock" then
        if MRT:IsRaidLeader() or MRT:IsRaidAssistant() then
            locked = true
            MRT:Print(L["sr_locked"])
        else
            MRT:Print(L["sr_need_lead"])
        end
        return
    end
    if rest == "unlock" then
        if MRT:IsRaidLeader() or MRT:IsRaidAssistant() then
            locked = false
            MRT:Print(L["sr_unlocked"])
        else
            MRT:Print(L["sr_need_lead"])
        end
        return
    end

    local itemID = self:ParseItem(rest)
    if not itemID then
        MRT:Print(L["sr_bad_item"])
        return
    end
    self:Reserve(itemID)
end

function SoftReserve:ParseItem(input)
    local id = input:match("item:(%d+)")
    if id then return tonumber(id) end
    local n = tonumber(input)
    if n then return n end
    return nil
end

function SoftReserve:Reserve(itemID)
    if locked and MRT.db.profile.softReserve.lockedAfterPull then
        MRT:Print(L["sr_locked_msg"])
        return
    end
    local me = UnitName("player")
    reserves[me] = reserves[me] or {}
    local list = reserves[me]
    local maxN = MRT.db.profile.softReserve.maxPerPlayer
    if #list >= maxN then
        MRT:Print(L["sr_max"]:format(maxN))
        return
    end
    if not MRT.db.profile.softReserve.allowDuplicates then
        for _, id in ipairs(list) do
            if id == itemID then
                MRT:Print(L["sr_dup"])
                return
            end
        end
    end
    table.insert(list, itemID)
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SET, { player = me, itemID = itemID })

    local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)
    MRT:Print(L["sr_added"]:format(link))
end

function SoftReserve:ClearMine()
    local me = UnitName("player")
    reserves[me] = nil
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_DEL, { player = me })
    MRT:Print(L["sr_cleared"])
end

function SoftReserve:OnRemoteSet(payload, sender)
    if not payload or not payload.itemID then return end
    local player = payload.player or Ambiguate(sender, "short")
    reserves[player] = reserves[player] or {}
    table.insert(reserves[player], payload.itemID)
end

function SoftReserve:OnRemoteDel(payload, sender)
    local player = (payload and payload.player) or Ambiguate(sender, "short")
    reserves[player] = nil
end

function SoftReserve:OnRemoteSync(payload, _)
    if type(payload) ~= "table" or type(payload.reserves) ~= "table" then return end
    for player, items in pairs(payload.reserves) do
        reserves[player] = items
    end
end

function SoftReserve:BroadcastFullSync()
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then return end
    MRT.Comm:Send(MRT.Comm.MSG.RESERVE_SYNC, { reserves = reserves })
end

function SoftReserve:GetAll()
    return reserves
end

function SoftReserve:GetReservesForItem(itemID)
    local out = {}
    for player, items in pairs(reserves) do
        for _, id in ipairs(items) do
            if id == itemID then table.insert(out, player) end
        end
    end
    return out
end

function SoftReserve:PrintList()
    local count = 0
    for player, items in pairs(reserves) do
        local parts = {}
        for _, id in ipairs(items) do
            parts[#parts + 1] = select(2, GetItemInfo(id)) or ("item:" .. id)
        end
        MRT:Print(player .. ": " .. table.concat(parts, ", "))
        count = count + 1
    end
    if count == 0 then MRT:Print(L["sr_empty"]) end
end

function SoftReserve:OnEncounterStart()
    if MRT.db.profile.softReserve.lockedAfterPull then locked = true end
end

function SoftReserve:OnEncounterEnd()
end
