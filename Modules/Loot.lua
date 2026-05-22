local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Loot = MRT:NewModule("Loot", "AceEvent-3.0", "AceTimer-3.0")
MRT.Loot = Loot

local RESPONSE = {
    PASS  = "pass",
    GREED = "greed",
    NEED  = "need",
    OS    = "os",
    TMOG  = "tmog",
}
Loot.RESPONSE = RESPONSE

local activeSession = nil

function Loot:OnEnable()
    local Comm = MRT.Comm
    Comm:On(Comm.MSG.LOOT_OPEN,  function(p, s) self:OnRemoteOpen(p, s) end)
    Comm:On(Comm.MSG.LOOT_VOTE,  function(p, s) self:OnRemoteVote(p, s) end)
    Comm:On(Comm.MSG.LOOT_CLOSE, function(p, s) self:OnRemoteClose(p, s) end)
    Comm:On(Comm.MSG.LOOT_AWARD, function(p, s) self:OnRemoteAward(p, s) end)

    self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
end

function Loot:OnLootOpened()
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then return end
    if GetLootMethod() ~= "master" then return end

    local items = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local quality = select(5, GetLootSlotInfo(slot))
        if link and quality and quality >= 4 then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                table.insert(items, { itemID = itemID, link = link, slot = slot })
            end
        end
    end
    if #items == 0 then return end
    self:OpenSession(items)
end

function Loot:OpenSession(items)
    local sessionID = string.format("%s-%d", UnitName("player"), GetServerTime and GetServerTime() or time())
    activeSession = {
        id      = sessionID,
        host    = UnitName("player"),
        items   = items,
        votes   = {},
        opened  = GetServerTime and GetServerTime() or time(),
        timeout = MRT.db.profile.loot.voteTimeout,
        awarded = {},
    }
    MRT.Comm:Send(MRT.Comm.MSG.LOOT_OPEN, {
        sessionID = sessionID,
        items     = items,
        timeout   = activeSession.timeout,
    })
    if MRT.UI and MRT.UI.OpenLootCouncil then
        MRT.UI:OpenLootCouncil(activeSession)
    end
    self:ScheduleTimer(function() self:CloseIfExpired(sessionID) end, activeSession.timeout + 5)
end

function Loot:CloseIfExpired(sessionID)
    if activeSession and activeSession.id == sessionID then
        self:CloseSession()
    end
end

function Loot:CloseSession()
    if not activeSession then return end
    MRT.Comm:Send(MRT.Comm.MSG.LOOT_CLOSE, { sessionID = activeSession.id })
    activeSession = nil
end

function Loot:Vote(itemIndex, response, comment)
    if not activeSession then
        if MRT.pendingSession then
            activeSession = MRT.pendingSession
        else
            return
        end
    end
    local payload = {
        sessionID = activeSession.id,
        itemIndex = itemIndex,
        response  = response,
        comment   = comment,
        ilvl      = GetAverageItemLevel and select(2, GetAverageItemLevel()) or nil,
    }
    if activeSession.host == UnitName("player") then
        self:OnRemoteVote(payload, UnitName("player"))
    else
        MRT.Comm:Send(MRT.Comm.MSG.LOOT_VOTE, payload, "WHISPER", activeSession.host)
    end
end

function Loot:OnRemoteOpen(payload, sender)
    if not payload or not payload.sessionID or not payload.items then return end
    if not MRT:IsCouncilMember(sender) and not (sender == UnitName("player")) then
        local incoming = {
            id      = payload.sessionID,
            host    = sender,
            items   = payload.items,
            votes   = {},
            opened  = GetServerTime and GetServerTime() or time(),
            timeout = payload.timeout or MRT.db.profile.loot.voteTimeout,
            awarded = {},
        }
        MRT.pendingSession = incoming
        if MRT.UI and MRT.UI.OpenLootVote then
            MRT.UI:OpenLootVote(incoming)
        end
        return
    end
    MRT.pendingSession = {
        id      = payload.sessionID,
        host    = sender,
        items   = payload.items,
        votes   = {},
        opened  = GetServerTime and GetServerTime() or time(),
        timeout = payload.timeout or MRT.db.profile.loot.voteTimeout,
        awarded = {},
    }
    if MRT.UI and MRT.UI.OpenLootVote then
        MRT.UI:OpenLootVote(MRT.pendingSession)
    end
end

function Loot:OnRemoteVote(payload, sender)
    if not payload or not activeSession or payload.sessionID ~= activeSession.id then return end
    local player = Ambiguate(sender, "short")
    activeSession.votes[payload.itemIndex] = activeSession.votes[payload.itemIndex] or {}
    activeSession.votes[payload.itemIndex][player] = {
        response = payload.response,
        comment  = payload.comment,
        ilvl     = payload.ilvl,
        sr       = MRT.SoftReserve and self:PlayerReservedItem(player, activeSession.items[payload.itemIndex].itemID) or false,
    }
    if MRT.UI and MRT.UI.RefreshLootCouncil then
        MRT.UI:RefreshLootCouncil(activeSession)
    end
end

function Loot:PlayerReservedItem(player, itemID)
    if not MRT.SoftReserve then return false end
    local all = MRT.SoftReserve:GetAll()
    local list = all[player] or all[Ambiguate(player, "short")]
    if not list then return false end
    for _, id in ipairs(list) do if id == itemID then return true end end
    return false
end

function Loot:OnRemoteClose(payload)
    if MRT.pendingSession and payload and MRT.pendingSession.id == payload.sessionID then
        MRT.pendingSession = nil
        if MRT.UI and MRT.UI.CloseLootVote then MRT.UI:CloseLootVote() end
    end
end

function Loot:Award(itemIndex, winner, reason)
    if not activeSession then return end
    local item = activeSession.items[itemIndex]
    if not item then return end
    activeSession.awarded[itemIndex] = { winner = winner, reason = reason }
    MRT.Comm:Send(MRT.Comm.MSG.LOOT_AWARD, {
        sessionID = activeSession.id,
        itemID    = item.itemID,
        link      = item.link,
        winner    = winner,
        reason    = reason,
    })

    table.insert(MRT.db.global.lootHistory, {
        sessionID = activeSession.id,
        timestamp = GetServerTime and GetServerTime() or time(),
        itemID    = item.itemID,
        link      = item.link,
        winner    = winner,
        reason    = reason,
    })

    if MRT.db.profile.loot.announceWinner then
        local channel = MRT.db.profile.loot.announceChannel
        SendChatMessage(L["loot_announce"]:format(item.link, winner, reason or ""), channel)
    end
end

function Loot:OnRemoteAward(payload, sender)
    if not payload then return end
    MRT:Print(L["loot_awarded"]:format(payload.link or payload.itemID, payload.winner, payload.reason or ""))
end

function Loot:OnEncounterEnd()
end

function Loot:GetSession()
    return activeSession
end
