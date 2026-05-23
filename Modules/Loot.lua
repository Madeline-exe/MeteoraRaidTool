local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Loot = MRT:NewModule("Loot", "AceEvent-3.0", "AceTimer-3.0")
MRT.Loot = Loot

-- ============================================================
-- Loot pool: items waiting to be distributed.
-- Shape:
--   MRT.db.global.lootPool[raidID][bossIndex] = {
--       { uid="...", itemID=12345, link="[item]", time=..., source="ml"|"chat", bossName="..." },
--       ...
--   }
-- bossIndex 0 = unmapped (chat-parsed, encounter unknown).
-- ============================================================

local lastEncounter = nil -- { id, name, time, bossIndex (or nil) }
local seenAwards    = {}  -- key=ts..itemID..player → true, dedupe across ml/chat in same window

local function newUID()
    return string.format("%s-%s-%d", tostring(time()), tostring(math.random(0, 65535)), math.random(0, 65535))
end

local function currentRaidID()
    return MRT.SoftReserve and MRT.SoftReserve:GetCurrentRaid() or nil
end

local function resolveBossIndex(encName)
    if not encName then return 0, nil end
    local raidID = currentRaidID()
    if not raidID then return 0, encName end
    local raid = ns.RaidsByID[raidID]
    if not raid then return 0, encName end
    local lower = encName:lower()
    for i, b in ipairs(raid.bosses) do
        if (b.name and b.name:lower() == lower)
           or (b.nameRU and b.nameRU:lower() == lower) then
            return i, b.name
        end
    end
    return 0, encName
end

local function ensurePoolSlot(raidID, bossIndex)
    MRT.db.global.lootPool = MRT.db.global.lootPool or {}
    MRT.db.global.lootPool[raidID] = MRT.db.global.lootPool[raidID] or {}
    MRT.db.global.lootPool[raidID][bossIndex] = MRT.db.global.lootPool[raidID][bossIndex] or {}
    return MRT.db.global.lootPool[raidID][bossIndex]
end

function Loot:OnInitialize()
    MRT.db.global.lootPool = MRT.db.global.lootPool or {}
end

function Loot:OnEnable()
    self:RegisterEvent("LOOT_OPENED",     "OnLootOpened")
    self:RegisterEvent("CHAT_MSG_LOOT",   "OnChatLoot")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnChatSystem")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END",   "OnEncounterEnd")

    if MRT.Comm and MRT.Comm.MSG.LOOT_AWARD then
        MRT.Comm:On(MRT.Comm.MSG.LOOT_AWARD, function(p, s) self:OnRemoteAward(p, s) end)
    end
end

function Loot:OnRemoteAward(payload, sender)
    if type(payload) ~= "table" or not payload.winner or not payload.itemID then return end
    if appendHistoryUnique(payload) then
        if MRT.UI and MRT.UI.RefreshLater then MRT.UI:RefreshLater() end
    end
end

-- ============================================================
-- Encounter tracking
-- ============================================================

function Loot:OnEncounterStart(_, encounterID, encounterName)
    local bossIndex = select(1, resolveBossIndex(encounterName))
    lastEncounter = {
        id        = encounterID,
        name      = encounterName,
        bossIndex = bossIndex,
        time      = time(),
    }
end

function Loot:OnEncounterEnd(_, encounterID, encounterName, _, _, success)
    if success == 1 or success == true then
        local bossIndex = select(1, resolveBossIndex(encounterName))
        lastEncounter = {
            id        = encounterID,
            name      = encounterName,
            bossIndex = bossIndex,
            time      = time(),
        }
    end
end

function Loot:GetLastEncounter()
    return lastEncounter
end

-- ============================================================
-- Master-loot scrape → pool
-- ============================================================

function Loot:OnLootOpened()
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then return end
    if GetLootMethod and GetLootMethod() ~= "master" then return end

    local raidID = currentRaidID()
    if not raidID then return end

    local bossIndex = lastEncounter and lastEncounter.bossIndex or 0
    local bossName  = lastEncounter and lastEncounter.name or nil

    local added = 0
    for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local quality = link and select(5, GetLootSlotInfo(slot))
        if link and quality and quality >= 4 then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                self:AddToPool({
                    itemID   = itemID,
                    link     = link,
                    raidID   = raidID,
                    bossIndex = bossIndex,
                    bossName  = bossName,
                    source    = "ml",
                })
                added = added + 1
            end
        end
    end
    if added > 0 then
        MRT:Print(L["pool_added_ml"]:format(added))
        MRT:SendMessage("MRT_POOL_CHANGED", raidID)
    end
end

-- ============================================================
-- Chat-loot fallback (covers Personal/Group loot or missed scrapes)
-- Patterns are built from WoW's localized loot strings.
-- ============================================================

local function buildLootPattern(template)
    if not template then return nil end
    local escaped = template
        :gsub("%%%%", "%%%%")
        :gsub("([%(%)%.%-%+%[%]%?%^%$])", "%%%1")
    escaped = escaped:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
    return "^" .. escaped .. "$"
end

local LOOT_PATTERNS

local function initLootPatterns()
    if LOOT_PATTERNS then return end
    LOOT_PATTERNS = {}
    -- "You receive loot: [item]." (and ru: "Вы получаете добычу: [item].")
    local selfPat = LOOT_ITEM_SELF and buildLootPattern(LOOT_ITEM_SELF)
    if selfPat then table.insert(LOOT_PATTERNS, { pat = selfPat, hasPlayer = false }) end
    local selfMultPat = LOOT_ITEM_SELF_MULTIPLE and buildLootPattern(LOOT_ITEM_SELF_MULTIPLE)
    if selfMultPat then table.insert(LOOT_PATTERNS, { pat = selfMultPat, hasPlayer = false }) end
    -- "%s receives loot: %s." (and ru)
    local othersPat = LOOT_ITEM and buildLootPattern(LOOT_ITEM)
    if othersPat then table.insert(LOOT_PATTERNS, { pat = othersPat, hasPlayer = true }) end
    local othersMultPat = LOOT_ITEM_MULTIPLE and buildLootPattern(LOOT_ITEM_MULTIPLE)
    if othersMultPat then table.insert(LOOT_PATTERNS, { pat = othersMultPat, hasPlayer = true }) end
end

local function isRecentEncounter()
    if not lastEncounter then return false end
    return (time() - lastEncounter.time) < 120
end

function Loot:OnChatLoot(_, msg)
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then return end
    if not isRecentEncounter() then return end
    local raidID = currentRaidID()
    if not raidID then return end

    initLootPatterns()
    local player, link
    for _, p in ipairs(LOOT_PATTERNS) do
        if p.hasPlayer then
            local a, b = msg:match(p.pat)
            if a and b then player, link = a, b; break end
        else
            local a = msg:match(p.pat)
            if a then player, link = UnitName("player"), a; break end
        end
    end
    if not link then return end

    local itemID, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, quality
    if GetItemInfo then
        local n, lk, qual = GetItemInfo(link)
        itemID = tonumber((lk or link):match("item:(%d+)"))
        quality = qual
    end
    if not itemID then itemID = tonumber(link:match("item:(%d+)")) end
    if not itemID then return end
    if quality and quality < 4 then return end

    local key = string.format("%d-%s-%d", itemID, tostring(player or "?"), math.floor(time() / 5))
    if seenAwards[key] then return end
    seenAwards[key] = true

    self:AddToPool({
        itemID    = itemID,
        link      = link,
        raidID    = raidID,
        bossIndex = lastEncounter.bossIndex or 0,
        bossName  = lastEncounter.name,
        source    = "chat",
        autoWinner = player,
    })
    MRT:Print(L["pool_added_chat"]:format(link, player or "?"))
    MRT:SendMessage("MRT_POOL_CHANGED", raidID)
end

-- ============================================================
-- Pool API
-- ============================================================

function Loot:AddToPool(entry)
    local raidID = entry.raidID
    local bossIndex = entry.bossIndex or 0
    local slot = ensurePoolSlot(raidID, bossIndex)
    -- Dedup window: identical itemID added within 5s.
    local now = time()
    for _, e in ipairs(slot) do
        if e.itemID == entry.itemID and math.abs((e.time or 0) - now) < 5 then
            return e
        end
    end
    entry.uid    = newUID()
    entry.time   = now
    entry.source = entry.source or "ml"
    table.insert(slot, entry)
    return entry
end

function Loot:RemoveFromPool(uid)
    for raidID, bosses in pairs(MRT.db.global.lootPool or {}) do
        for bossIndex, items in pairs(bosses) do
            for i, e in ipairs(items) do
                if e.uid == uid then
                    table.remove(items, i)
                    MRT:SendMessage("MRT_POOL_CHANGED", raidID)
                    return true
                end
            end
        end
    end
    return false
end

function Loot:GetPool(raidID)
    raidID = raidID or currentRaidID()
    if not raidID then return {} end
    return (MRT.db.global.lootPool and MRT.db.global.lootPool[raidID]) or {}
end

function Loot:GetPoolEntry(uid)
    for _, bosses in pairs(MRT.db.global.lootPool or {}) do
        for _, items in pairs(bosses) do
            for _, e in ipairs(items) do
                if e.uid == uid then return e end
            end
        end
    end
end

function Loot:ClearPool(raidID)
    raidID = raidID or currentRaidID()
    if not raidID then return end
    MRT.db.global.lootPool[raidID] = {}
    MRT:SendMessage("MRT_POOL_CHANGED", raidID)
end

-- ============================================================
-- Award (called from Distribute UI or chat-detected auto-award)
-- ============================================================

local function appendHistoryUnique(record)
    local hist = MRT.db.global.lootHistory
    -- Dedup: same player + same item within 30s of the recorded timestamp.
    for i = #hist, math.max(1, #hist - 50), -1 do
        local e = hist[i]
        if e.winner == record.winner and e.itemID == record.itemID
           and math.abs((e.timestamp or 0) - record.timestamp) < 30 then
            return false
        end
    end
    table.insert(hist, record)
    return true
end

function Loot:Award(entry, winner, note)
    if not entry or not winner then return end
    local record = {
        timestamp = time(),
        itemID    = entry.itemID,
        link      = entry.link,
        winner    = winner,
        note      = note,
        raid      = entry.raidID,
        boss      = entry.bossName,
    }
    appendHistoryUnique(record)
    -- Broadcast so every group member's local lootHistory stays in sync.
    if MRT.Comm and MRT.Comm.MSG.LOOT_AWARD then
        MRT.Comm:Send(MRT.Comm.MSG.LOOT_AWARD, record)
    end
    local raidLink = entry.link or ("item:" .. entry.itemID)
    if MRT.db.profile.loot.announceWinner then
        SendChatMessage(L["loot_announce"]:format(raidLink, winner, note or ""), MRT.db.profile.loot.announceChannel)
    end

    -- Best-effort: remove the awarded item from the winner's reserves.
    if MRT.SoftReserve then
        local res = MRT.SoftReserve:GetAll()[winner]
        if res then
            for i, id in ipairs(res) do
                if id == entry.itemID then
                    table.remove(res, i)
                    if MRT.Comm then
                        MRT.Comm:Send(MRT.Comm.MSG.RESERVE_DEL, { player = winner, itemID = id })
                    end
                    break
                end
            end
        end
    end

    -- Queue for auto-placement next time the RL opens trade with the winner.
    if MRT.AutoTrade and MRT.AutoTrade.Queue then
        MRT.AutoTrade:Queue(winner, entry.itemID, entry.link)
    end

    if entry.uid then self:RemoveFromPool(entry.uid) end
end

-- ============================================================
-- Roll engine
-- ============================================================

local activeRoll = nil

function Loot:StartRoll(entry, mode, allowedPlayers, timeoutSec)
    if activeRoll then self:StopRoll() end
    timeoutSec = timeoutSec or 30
    local allowedSet
    if mode == "sr" and allowedPlayers and #allowedPlayers > 0 then
        allowedSet = {}
        for _, p in ipairs(allowedPlayers) do allowedSet[p] = true end
    end

    activeRoll = {
        entry     = entry,
        mode      = mode,
        allowed   = allowedSet,
        rolls     = {},
        startedAt = time(),
        timeoutAt = time() + timeoutSec,
    }

    local link = entry.link or ("item:" .. entry.itemID)
    local announceMsg
    if mode == "sr" then
        announceMsg = L["roll_announce_sr"]:format(link, table.concat(allowedPlayers or {}, ", "), timeoutSec)
    else
        announceMsg = L["roll_announce_free"]:format(link, timeoutSec)
    end
    SendChatMessage(announceMsg, "RAID_WARNING")

    activeRoll.timer = self:ScheduleTimer(function() self:StopRoll() end, timeoutSec)
    MRT:SendMessage("MRT_ROLL_UPDATE")
end

function Loot:StopRoll()
    if not activeRoll then return end
    if activeRoll.timer then self:CancelTimer(activeRoll.timer); activeRoll.timer = nil end
    local link = activeRoll.entry.link or ("item:" .. activeRoll.entry.itemID)
    local top, topRoll
    for player, roll in pairs(activeRoll.rolls) do
        if not topRoll or roll > topRoll then top, topRoll = player, roll end
    end
    if top then
        SendChatMessage(L["roll_winner"]:format(link, top, topRoll), "RAID_WARNING")
    else
        SendChatMessage(L["roll_nobody"]:format(link), "RAID")
    end
    activeRoll.ended = true
    MRT:SendMessage("MRT_ROLL_UPDATE")
end

function Loot:ClearRoll()
    activeRoll = nil
    MRT:SendMessage("MRT_ROLL_UPDATE")
end

function Loot:GetActiveRoll()
    return activeRoll
end

local ROLL_PATTERN
local function buildRollPattern()
    if ROLL_PATTERN then return ROLL_PATTERN end
    -- RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)" on enUS; ruRU is different but uses same %s/%d slots.
    local tpl = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    local pat = tpl
        :gsub("([%(%)%.%-%+%[%]%?%^%$])", "%%%1")
        :gsub("%%s", "(.+)")
        :gsub("%%d", "(%%d+)")
    ROLL_PATTERN = "^" .. pat .. "$"
    return ROLL_PATTERN
end

function Loot:OnChatSystem(_, msg)
    if not activeRoll or activeRoll.ended then return end
    local pat = buildRollPattern()
    local player, roll, low, high = msg:match(pat)
    if not player then return end
    low, high = tonumber(low), tonumber(high)
    if low ~= 1 or high ~= 100 then return end
    local r = tonumber(roll)
    if not r then return end
    local short = Ambiguate(player, "short")
    if activeRoll.allowed and not activeRoll.allowed[short] then
        return -- SR-only mode and player isn't on the allowed list
    end
    if activeRoll.rolls[short] then return end -- first roll counts
    activeRoll.rolls[short] = r
    MRT:SendMessage("MRT_ROLL_UPDATE")
end
