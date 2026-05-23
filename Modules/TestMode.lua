local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local TestMode = MRT:NewModule("TestMode", "AceEvent-3.0")
MRT.TestMode = TestMode

local enabled = false
local BOT_NAMES = { "Бот1", "Бот2", "Бот3", "Бот4", "Бот5" }

function TestMode:IsOn()
    return enabled
end

function TestMode:Toggle()
    self:Set(not enabled)
end

function TestMode:Set(on)
    enabled = on and true or false
    MRT:Print(enabled and L["test_on"] or L["test_off"])
    MRT:SendMessage("MRT_TEST_TOGGLED")
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    MRT:SendMessage("MRT_POOL_CHANGED")
end

function TestMode:HandleSlash(rest)
    rest = (rest or ""):trim():lower()
    if rest == "on" then self:Set(true)
    elseif rest == "off" then self:Set(false)
    else self:Toggle() end
end

-- ============================================================
-- Bots roster (only valid when test mode is on)
-- ============================================================

function TestMode:GetBots()
    return BOT_NAMES
end

-- Return a roster list that includes the local player + bots, for dropdowns
-- when not actually in a raid.
function TestMode:VirtualRoster()
    local list = {}
    local me = UnitName("player")
    if me then list[me] = me end
    for _, b in ipairs(BOT_NAMES) do list[b] = b end
    return list
end

-- ============================================================
-- Simulate boss drop: pick `count` random epic itemIDs out of the
-- current raid's curated loot table, push them into the pool tied
-- to a random boss.
-- ============================================================

function TestMode:SimulateDrop(count)
    if not enabled then MRT:Print(L["test_need_on"]); return end
    local SR = MRT.SoftReserve
    local raidID = SR and SR:GetCurrentRaid()
    if not raidID then MRT:Print(L["hint_pick_raid"]); return end
    local raid = ns.RaidsByID[raidID]
    if not raid then return end

    -- Pick a random boss that actually has items in the curated table.
    local candidates = {}
    for bossIndex in ipairs(raid.bosses) do
        local items = MRT.RaidLoot:GetItems(raidID, bossIndex)
        if items and #items > 0 then
            table.insert(candidates, { bossIndex = bossIndex, items = items })
        end
    end
    if #candidates == 0 then
        MRT:Print(L["test_no_curated"])
        return
    end
    local pick = candidates[math.random(#candidates)]
    local bossName = ns.BossName(raid.bosses[pick.bossIndex])

    local shuffled = {}
    for i, id in ipairs(pick.items) do shuffled[i] = id end
    -- Fisher-Yates partial shuffle
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local added = 0
    for i = 1, math.min(count or 3, #shuffled) do
        local itemID = shuffled[i]
        local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)
        MRT.Loot:AddToPool({
            itemID    = itemID,
            link      = link,
            raidID    = raidID,
            bossIndex = pick.bossIndex,
            bossName  = bossName,
            source    = "test",
        })
        added = added + 1
    end
    MRT:Print(L["test_dropped"]:format(added, bossName))
    MRT:SendMessage("MRT_POOL_CHANGED", raidID)
end

-- ============================================================
-- Simulate rolls: inject N fake bot rolls into the currently
-- active roll. Respects SR-only mode: bots only roll if they're
-- on the allowed list (which won't normally happen with the bot
-- names, so use SimulateBotReserves first if you want SR-roll testing).
-- ============================================================

function TestMode:SimulateRolls(count)
    if not enabled then MRT:Print(L["test_need_on"]); return end
    local roll = MRT.Loot:GetActiveRoll()
    if not roll or roll.ended then
        MRT:Print(L["test_no_roll"])
        return
    end

    local pool
    if roll.allowed then
        pool = {}
        for name in pairs(roll.allowed) do table.insert(pool, name) end
    else
        pool = {}
        local me = UnitName("player")
        if me then table.insert(pool, me) end
        for _, b in ipairs(BOT_NAMES) do table.insert(pool, b) end
    end

    if #pool == 0 then
        MRT:Print(L["test_no_roll"])
        return
    end

    -- Shuffle and pick up to `count` rollers
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local n = math.min(count or 3, #pool)
    for i = 1, n do
        local p = pool[i]
        if not roll.rolls[p] then
            roll.rolls[p] = math.random(1, 100)
        end
    end
    MRT:SendMessage("MRT_ROLL_UPDATE")
end

-- ============================================================
-- Simulate reserves: have bots reserve random items from the current
-- raid so SR-roll mode can be tested.
-- ============================================================

function TestMode:SimulateBotReserves()
    if not enabled then MRT:Print(L["test_need_on"]); return end
    local SR = MRT.SoftReserve
    local raidID = SR and SR:GetCurrentRaid()
    if not raidID then MRT:Print(L["hint_pick_raid"]); return end
    local raid = ns.RaidsByID[raidID]
    if not raid then return end

    local allItems = {}
    for bossIndex in ipairs(raid.bosses) do
        for _, id in ipairs(MRT.RaidLoot:GetItems(raidID, bossIndex)) do
            table.insert(allItems, id)
        end
    end
    if #allItems == 0 then MRT:Print(L["test_no_curated"]); return end

    local reserves = SR:GetAll()
    for _, bot in ipairs(BOT_NAMES) do
        reserves[bot] = reserves[bot] or {}
        if #reserves[bot] == 0 then
            local pick = allItems[math.random(#allItems)]
            table.insert(reserves[bot], pick)
        end
    end
    MRT:SendMessage("MRT_SR_STATE_CHANGED")
    MRT:Print(L["test_bot_reserves_done"])
end
