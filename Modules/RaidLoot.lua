local ADDON_NAME, ns = ...
local MRT = ns.MRT

local RaidLoot = MRT:NewModule("RaidLoot")
MRT.RaidLoot = RaidLoot

local function ensureEJLoaded()
    if not _G.EncounterJournal then
        if type(_G.UIParentLoadAddOn) == "function" then
            pcall(_G.UIParentLoadAddOn, "Blizzard_EncounterJournal")
        elseif type(_G.LoadAddOn) == "function" then
            pcall(_G.LoadAddOn, "Blizzard_EncounterJournal")
        elseif _G.C_AddOns and type(_G.C_AddOns.LoadAddOn) == "function" then
            pcall(_G.C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
        end
    end
end

local function ejAvailable()
    ensureEJLoaded()
    return type(_G.EJ_SelectInstance) == "function"
        and type(_G.EJ_GetEncounterInfoByIndex) == "function"
        and type(_G.EJ_SelectEncounter) == "function"
        and (type(_G.EJ_GetLootInfoByIndex) == "function" or type(_G.EJ_GetLootInfo) == "function")
end

local function getCache(raidID)
    local db = MRT.db.global.raidLootCache
    db[raidID] = db[raidID] or { fetchedAt = 0, bosses = {} }
    return db[raidID]
end

function RaidLoot:OnInitialize()
    MRT.db.global.raidLootCache = MRT.db.global.raidLootCache or {}
end

function RaidLoot:ScanRaid(raidID)
    local raid = ns.RaidsByID[raidID]
    if not raid then return nil end
    if not ejAvailable() then return getCache(raidID) end

    local ok = pcall(_G.EJ_SelectInstance, raid.ejInstanceID)
    if not ok then return getCache(raidID) end

    local cache = getCache(raidID)
    cache.fetchedAt = time()
    cache.bosses = {}

    for i = 1, 30 do
        local name, _, encounterID = _G.EJ_GetEncounterInfoByIndex(i)
        if not name or not encounterID then break end

        local boss = { name = name, encounterID = encounterID, items = {} }
        pcall(_G.EJ_SelectEncounter, encounterID)

        for j = 1, 60 do
            local itemID, itemName, link
            if _G.EJ_GetLootInfoByIndex then
                local info = _G.EJ_GetLootInfoByIndex(j)
                if type(info) == "table" then
                    itemID, itemName, link = info.itemID, info.name, info.link
                end
            end
            if not itemID and _G.EJ_GetLootInfo then
                local id, _, n, l = pcall(_G.EJ_GetLootInfo, j)
                if id then itemID, itemName, link = id, n, l end
            end
            if not itemID then break end
            table.insert(boss.items, { itemID = itemID, name = itemName, link = link })
        end
        table.insert(cache.bosses, boss)
    end
    return cache
end

function RaidLoot:Get(raidID)
    local cache = getCache(raidID)
    if #cache.bosses == 0 then
        return self:ScanRaid(raidID)
    end
    return cache
end

function RaidLoot:Refresh(raidID)
    MRT.db.global.raidLootCache[raidID] = nil
    return self:ScanRaid(raidID)
end
