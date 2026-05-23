local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local WhisperReserve = MRT:NewModule("WhisperReserve", "AceEvent-3.0")
MRT.WhisperReserve = WhisperReserve

local function ambig(n) return Ambiguate(n or "", "short") end

function WhisperReserve:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end

-- ============================================================
-- Roster helpers
-- ============================================================

local function raidShortNames()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then list[ambig(name)] = true end
        end
    end
    return list
end

local function hasAddon(shortName)
    if not MRT.peers then return false end
    return MRT.peers[shortName] ~= nil
end

-- ============================================================
-- Outbound: ask players for their reserves
-- ============================================================

function WhisperReserve:AskPlayer(playerName)
    if not MRT:CanLead() then MRT:Print(L["sr_need_lead"]); return end
    local raidID = MRT.SoftReserve:GetCurrentRaid()
    if not raidID then MRT:Print(L["hint_pick_raid"]); return end
    if not MRT.SoftReserve:IsOpen() then MRT:Print(L["wr_open_first"]); return end
    local raid = ns.RaidsByID[raidID]
    local raidName = raid and ns.RaidName(raid) or raidID
    local maxN = MRT.SoftReserve:GetMaxPerPlayer()
    local msg = L["wr_request"]:format(raidName, maxN)
    SendChatMessage(msg, "WHISPER", nil, playerName)
end

function WhisperReserve:AskAllPugs()
    if not MRT:CanLead() then MRT:Print(L["sr_need_lead"]); return end
    local raidID = MRT.SoftReserve:GetCurrentRaid()
    if not raidID then MRT:Print(L["hint_pick_raid"]); return end
    if not MRT.SoftReserve:IsOpen() then MRT:Print(L["wr_open_first"]); return end

    local me = ambig(UnitName("player"))
    local count = 0
    for short in pairs(raidShortNames()) do
        if short ~= me and not hasAddon(short) then
            self:AskPlayer(short)
            count = count + 1
        end
    end
    MRT:Print(L["wr_asked"]:format(count))
end

-- ============================================================
-- Inbound: process whisper replies
-- ============================================================

function WhisperReserve:OnWhisper(_, msg, sender)
    if not MRT:CanLead() then return end
    if not MRT.SoftReserve:GetCurrentRaid() then return end
    if not MRT.SoftReserve:IsOpen() then return end

    local short = ambig(sender)
    if not raidShortNames()[short] then return end -- not in our raid

    -- Extract item IDs from any "|Hitem:N:...|h" links plus bare numbers.
    local ids = {}
    local seen = {}
    for itemID in msg:gmatch("item:(%d+)") do
        local n = tonumber(itemID)
        if n and not seen[n] then seen[n] = true; table.insert(ids, n) end
    end
    if #ids == 0 then
        -- fall back: bare item IDs ("12345 30000")
        for word in msg:gmatch("%d+") do
            local n = tonumber(word)
            if n and n > 1000 and not seen[n] then
                seen[n] = true; table.insert(ids, n)
            end
        end
    end
    if #ids == 0 then return end

    local added, denied = {}, {}
    for _, id in ipairs(ids) do
        local res = MRT.SoftReserve:AddForPlayer(short, id, { viaWhisper = true })
        if res == "ok" then
            table.insert(added, id)
        elseif res ~= "already" then
            table.insert(denied, { id = id, reason = res })
        end
    end

    if #added == 0 and #denied == 0 then return end

    -- Build reply
    local parts = {}
    if #added > 0 then
        local linkList = {}
        for _, id in ipairs(added) do
            local _, link = GetItemInfo(id)
            table.insert(linkList, link or ("item:" .. id))
        end
        table.insert(parts, L["wr_reply_ok"]:format(table.concat(linkList, ", ")))
    end
    for _, d in ipairs(denied) do
        local _, link = GetItemInfo(d.id)
        local item = link or ("item:" .. d.id)
        local reasonText = L["wr_reason_" .. d.reason] or d.reason
        table.insert(parts, L["wr_reply_deny"]:format(item, reasonText))
    end
    SendChatMessage(table.concat(parts, " "), "WHISPER", nil, sender)
    MRT:Print(string.format("|cffffd200[SR via whisper]|r %s: +%d / -%d",
        sender, #added, #denied))
end
