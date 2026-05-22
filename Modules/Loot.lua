local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Loot = MRT:NewModule("Loot", "AceEvent-3.0")
MRT.Loot = Loot

local pendingItems = {}

function Loot:OnEnable()
    self:RegisterEvent("LOOT_OPENED",   "OnLootOpened")
    self:RegisterEvent("LOOT_CLOSED",   "OnLootClosed")
    self:RegisterEvent("CHAT_MSG_LOOT", "OnChatLoot")
end

function Loot:OnLootOpened()
    if GetLootMethod and GetLootMethod() ~= "master" then return end
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then return end

    pendingItems = {}
    for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local quality = link and select(5, GetLootSlotInfo(slot))
        if link and quality and quality >= 4 then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                table.insert(pendingItems, { itemID = itemID, link = link, slot = slot })
            end
        end
    end
    if #pendingItems > 0 and MRT.UI and MRT.UI.OpenAwardWindow then
        MRT.UI:OpenAwardWindow(pendingItems)
    end
end

function Loot:OnLootClosed()
end

function Loot:OnChatLoot(_, msg)
    -- Could parse loot received messages for history. Out of scope for v0.2.
end

function Loot:Award(itemEntry, winner, note)
    if not itemEntry or not winner then return end
    table.insert(MRT.db.global.lootHistory, {
        timestamp = time(),
        itemID    = itemEntry.itemID,
        link      = itemEntry.link,
        winner    = winner,
        note      = note,
        raid      = MRT.SoftReserve and MRT.SoftReserve:GetCurrentRaid(),
    })
    local raidLink = itemEntry.link or ("item:" .. itemEntry.itemID)
    if MRT.db.profile.loot.announceWinner then
        SendChatMessage(L["loot_announce"]:format(raidLink, winner, note or ""), MRT.db.profile.loot.announceChannel)
    end

    if MRT.SoftReserve and MRT.SoftReserve.GetCurrentRaid then
        -- Best effort: remove the awarded item from the winner's reserves so it doesn't show up next time.
        local res = MRT.SoftReserve:GetAll()[winner]
        if res then
            for i, id in ipairs(res) do
                if id == itemEntry.itemID then
                    table.remove(res, i)
                    if MRT.Comm then
                        MRT.Comm:Send(MRT.Comm.MSG.RESERVE_DEL, { player = winner, itemID = id })
                    end
                    break
                end
            end
        end
    end
end

function Loot:GetPendingItems()
    return pendingItems
end
