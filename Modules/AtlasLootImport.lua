local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Importer = MRT:NewModule("AtlasLootImport", "AceEvent-3.0")
MRT.AtlasLootImport = Importer

-- Map our raid IDs → AtlasLootClassic content keys (confirmed via /mrt atlasdump
-- against AtlasLootClassic_DungeonsAndRaids).
local CONTENT_KEYS = {
    karazhan    = { "Karazhan" },
    gruul       = { "GruulsLair" },
    magtheridon = { "MagtheridonsLair" },
    ssc         = { "SerpentshrineCavern" },
    tk          = { "TempestKeep" },
    za          = { "ZulAman" },
    hyjal       = { "HyjalSummit" },
    bt          = { "BlackTemple" },
    sunwell     = { "SunwellPlateau" },
}

-- AtlasLoot module names we probe (in order). AtlasLootClassic bundles all
-- TBC raids inside AtlasLootClassic_DungeonsAndRaids.
local MODULE_CANDIDATES = {
    "AtlasLootClassic_DungeonsAndRaids",
    "AtlasLootClassic_BurningCrusade",
    "AtlasLoot_BurningCrusade",
}

local function isAtlasLootLoaded()
    if ns.compat.IsAddOnLoaded then
        for _, name in ipairs({"AtlasLootClassic", "AtlasLoot"}) do
            if ns.compat.IsAddOnLoaded(name) then return name end
        end
    end
    return nil
end

local function findItemDB()
    -- Try the modern Classic structure first.
    if _G.AtlasLoot and _G.AtlasLoot.ItemDB and _G.AtlasLoot.ItemDB.Storage then
        return _G.AtlasLoot.ItemDB.Storage
    end
    -- Older "AtlasLoot_Data" tables (TBC-era AtlasLoot 4.x):
    if _G.AtlasLoot_Data then return _G.AtlasLoot_Data end
    return nil
end

local function loadModuleIfPossible()
    if not _G.AtlasLoot then return end
    if _G.AtlasLoot.Loader and _G.AtlasLoot.Loader.LoadModule then
        for _, mod in ipairs(MODULE_CANDIDATES) do
            pcall(_G.AtlasLoot.Loader.LoadModule, _G.AtlasLoot.Loader, mod)
        end
    end
end

-- AtlasLootClassic stores each boss as:
--   bossEntry = {
--       name  = "Boss Name",
--       npcID = N,
--       [1] = { -- "difficulty 1" / Normal item table
--           { rowIdx, itemID, "modifier..." },  -- one row per visible slot
--           ...
--       },
--       [2] = { ... },  -- another difficulty (Heroic/Mythic) if any
--       __atlaslootdata = <reference to global module data>,  -- metadata
--   }
--
-- We pull only row[2] from each row inside bossEntry[1] (the main item
-- table). We deliberately skip the deep walk because __atlaslootdata
-- transitively links back to every loot table in the game, which caused
-- v0.7.2 to leak unrelated craft / classic items into the import.
local function extractItemIDs(bossEntry)
    local ids, seen = {}, {}
    if type(bossEntry) ~= "table" then return ids end

    local function pull(rowTable)
        if type(rowTable) ~= "table" then return end
        for _, row in ipairs(rowTable) do
            if type(row) == "table" then
                local itemID = tonumber(row[2])
                if itemID and itemID > 0 and not seen[itemID] then
                    seen[itemID] = true
                    -- Quality filter (rare+) when item is already cached.
                    -- Uncached items return nil; include them rather than
                    -- silently drop loot.
                    local _, _, quality = GetItemInfo(itemID)
                    if not quality or quality >= 3 then
                        table.insert(ids, itemID)
                    end
                end
            end
        end
    end

    -- Boss difficulties live at numeric keys. Most TBC raids have only [1].
    -- Some bosses also expose [2] (Heroic on later content); we take both
    -- since the same drop list typically repeats.
    for i = 1, 5 do
        if bossEntry[i] then pull(bossEntry[i]) end
    end

    return ids
end

local function readBossName(v)
    local n = v and (v.name or v.Name or v.title)
    if type(n) == "table" then
        n = n[GetLocale()] or n.enUS or n[1] or nil
    end
    if type(n) ~= "string" then return nil end
    return n
end

-- Return the array of boss-entries for an AtlasLoot content table.
local function bossArrayOf(content)
    if type(content) ~= "table" then return nil end
    if type(content.items) == "table" then return content.items end
    -- Some old layouts store boss array right on content.
    if type(content[1]) == "table" then return content end
    return nil
end

local function findRaidContent(storage, raidID)
    for _, modName in ipairs(MODULE_CANDIDATES) do
        local mod = storage[modName]
        if mod then
            for _, key in ipairs(CONTENT_KEYS[raidID] or {}) do
                -- Modern AtlasLootClassic: content lives as fields directly on the module
                -- (mod.Karazhan, mod.GruulsLair, ...). Old layouts had a nested .items table.
                local raw = mod[key]
                if type(raw) == "table" then return raw, modName, key end
                if mod.items and mod.items[key] then return mod.items[key], modName, key end
            end
        end
    end
end

-- ============================================================
-- Public API: import drop tables for one raid.
-- Returns: ok (bool), bossesFilled (int), totalItems (int), errMsg (string)
-- ============================================================

-- ============================================================
-- Diagnostics: dump what AtlasLoot exposes so the user can paste it back.
-- Triggered via /mrt atlasdump
-- ============================================================

function Importer:Dump(raidID)
    MRT:Print("|cffffd200=== AtlasLoot dump ===|r")
    local addon = isAtlasLootLoaded()
    MRT:Print("Addon loaded: " .. tostring(addon))
    if not (_G.AtlasLoot and _G.AtlasLoot.ItemDB) then
        MRT:Print("|cffff5555AtlasLoot or ItemDB missing|r")
        return
    end

    -- Force-load TBC module if loader available
    loadModuleIfPossible()

    local ItemDB = _G.AtlasLoot.ItemDB
    if ItemDB.GetModuleList then
        local ok, list = pcall(ItemDB.GetModuleList, ItemDB)
        if ok and type(list) == "table" then
            MRT:Print("GetModuleList: " .. table.concat(list, ", "))
        else
            MRT:Print("GetModuleList failed: " .. tostring(list))
        end
    end

    if ItemDB.Storage then
        local snames = {}
        for k in pairs(ItemDB.Storage) do table.insert(snames, tostring(k)) end
        table.sort(snames)
        MRT:Print("Storage keys: " .. table.concat(snames, ", "))

        -- Inspect each module: list its content keys and the first few boss entries.
        for _, modName in ipairs(snames) do
            local mod = ItemDB.Storage[modName]
            if type(mod) == "table" then
                local subkeys = {}
                for k in pairs(mod) do table.insert(subkeys, tostring(k)) end
                table.sort(subkeys)
                MRT:Print("  [" .. modName .. "] fields: " .. table.concat(subkeys, ", "))

                -- Try every promising container: items, contentList, content
                for _, candidate in ipairs({ "items", "contentList", "content", "list" }) do
                    if type(mod[candidate]) == "table" then
                        local ck = {}
                        for k in pairs(mod[candidate]) do table.insert(ck, tostring(k)) end
                        table.sort(ck)
                        local preview = table.concat(ck, ", ")
                        if #preview > 220 then preview = preview:sub(1, 220) .. " ..." end
                        MRT:Print("    ." .. candidate .. ": " .. preview)
                    end
                end

                -- Sample the first content entry to see its boss table shape.
                if type(mod.items) == "table" then
                    for ckey, cval in pairs(mod.items) do
                        if type(cval) == "table" then
                            local bossFields = {}
                            local n = 0
                            for k, v in pairs(cval) do
                                n = n + 1
                                if n <= 5 then
                                    if type(v) == "table" then
                                        local nm = v.name or v.Name or v[1]
                                        table.insert(bossFields, tostring(k) .. "→" .. tostring(nm))
                                    else
                                        table.insert(bossFields, tostring(k) .. "=" .. tostring(v))
                                    end
                                end
                            end
                            MRT:Print(string.format("    sample content[%s]: %d entries, first: %s",
                                tostring(ckey), n, table.concat(bossFields, " | ")))
                            break
                        end
                    end
                end
            end
        end
    end

    -- Try the ItemDB methods directly with a TBC moduleName guess.
    if ItemDB.Get and ItemDB.Storage then
        for modName in pairs(ItemDB.Storage) do
            if tostring(modName):find("BurningCrusade") then
                MRT:Print("Probing methods on " .. modName .. ":")
                for _, methodName in ipairs({"GetContentList", "GetContentTable", "GetTable"}) do
                    local m = ItemDB.Storage[modName][methodName] or ItemDB[methodName]
                    if m then
                        local ok2, res = pcall(m, ItemDB.Storage[modName])
                        MRT:Print("  " .. methodName .. ": " .. tostring(ok2) .. " " ..
                            (type(res) == "table" and ("table#" .. (#res or 0)) or tostring(res)))
                    end
                end
                break
            end
        end
    end

    if raidID then
        MRT:Print("Mapping check for raidID=" .. raidID .. ":")
        local storage = findItemDB()
        if storage then
            local content, modName, contentKey = findRaidContent(storage, raidID)
            if content then
                MRT:Print("  findRaidContent → HIT mod=" .. tostring(modName) .. " key=" .. tostring(contentKey))

                -- Show top-level fields of the content table
                local fields = {}
                for k in pairs(content) do table.insert(fields, tostring(k)) end
                table.sort(fields)
                local preview = table.concat(fields, ", ")
                if #preview > 220 then preview = preview:sub(1, 220) .. " ..." end
                MRT:Print("  content fields: " .. preview)

                -- Sample first boss entry's shape
                for k, v in pairs(content) do
                    if type(v) == "table" then
                        local bossFields = {}
                        local i = 0
                        for k2, v2 in pairs(v) do
                            i = i + 1
                            if i <= 6 then
                                local desc = type(v2) == "table"
                                    and ("table#" .. (#v2 or 0))
                                    or ("(" .. type(v2) .. ") " .. tostring(v2):sub(1, 30))
                                table.insert(bossFields, tostring(k2) .. "=" .. desc)
                            end
                        end
                        MRT:Print(string.format("  sample boss [%s]: %s", tostring(k),
                            table.concat(bossFields, " | ")))
                        -- Drill one level: if v.items / v[1] is a table, show its first few rows
                        local probe = v.items or v[1] or v.Items
                        if type(probe) == "table" then
                            local sample = {}
                            for j = 1, math.min(3, #probe) do
                                local row = probe[j]
                                if type(row) == "table" then
                                    local rs = {}
                                    for ri = 1, math.min(4, #row) do rs[ri] = tostring(row[ri]) end
                                    table.insert(sample, "[" .. table.concat(rs, ",") .. "]")
                                end
                            end
                            MRT:Print("    items rows: " .. table.concat(sample, " "))
                        end
                        break
                    end
                end
            else
                MRT:Print("  findRaidContent → MISS")
            end
        end
    end
    MRT:Print("|cffffd200=== end dump ===|r")
end

function Importer:ImportRaid(raidID)
    local raid = ns.RaidsByID[raidID]
    if not raid then return false, 0, 0, L["import_unknown_raid"] end

    if not isAtlasLootLoaded() then
        return false, 0, 0, L["import_no_atlas"]
    end
    loadModuleIfPossible()

    local storage = findItemDB()
    if not storage then return false, 0, 0, L["import_no_db"] end

    local content, modName, contentKey = findRaidContent(storage, raidID)
    if not content then
        return false, 0, 0, L["import_no_data"]:format(ns.RaidName(raid))
    end

    local bossArray = bossArrayOf(content)
    if not bossArray then
        return false, 0, 0, L["import_no_data"]:format(ns.RaidName(raid))
    end

    -- Build a name → entry map so we can match by AtlasLoot's boss name.
    local byName = {}
    local sequential = {}
    for k, v in pairs(bossArray) do
        if type(v) == "table" then
            local nm = readBossName(v)
            if nm then byName[nm:lower()] = v end
            if type(k) == "number" then sequential[k] = v end
        end
    end

    local bossesFilled, totalItems = 0, 0
    for bossIndex, boss in ipairs(raid.bosses) do
        local hit
        -- Try exact match by either English or Russian boss name.
        for _, candidate in ipairs({ boss.name, boss.nameRU }) do
            if candidate then
                hit = byName[candidate:lower()]
                if hit then break end
            end
        end
        -- Partial match (e.g. our "Gruul" vs AtlasLoot's "Gruul the Dragonkiller").
        if not hit then
            for _, candidate in ipairs({ boss.name, boss.nameRU }) do
                if candidate then
                    local c = candidate:lower()
                    for lname, entry in pairs(byName) do
                        if lname:find(c, 1, true) or c:find(lname, 1, true) then
                            hit = entry; break
                        end
                    end
                    if hit then break end
                end
            end
        end
        -- Fallback: same index in AtlasLoot. AtlasLoot and our Data/Raids.lua
        -- both list bosses in encounter order, so this is usually right.
        if not hit then hit = sequential[bossIndex] end

        if hit then
            local ids = extractItemIDs(hit)
            if #ids > 0 then
                MRT.db.global.raidLoot[raidID] = MRT.db.global.raidLoot[raidID] or {}
                MRT.db.global.raidLoot[raidID][bossIndex] = ids
                bossesFilled = bossesFilled + 1
                totalItems = totalItems + #ids
            end
        end
    end

    if bossesFilled == 0 then
        return false, 0, 0, L["import_no_bosses"]
    end

    MRT.RaidLoot:Broadcast(raidID)
    return true, bossesFilled, totalItems, nil
end
