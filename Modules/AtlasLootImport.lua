local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Importer = MRT:NewModule("AtlasLootImport", "AceEvent-3.0")
MRT.AtlasLootImport = Importer

-- Map our raid IDs → likely AtlasLoot ItemDB content keys.
-- AtlasLootClassic uses Title-Cased English keys; some have spaces or apostrophes.
-- We try multiple candidates per raid and accept the first match.
local CONTENT_KEYS = {
    karazhan    = { "Karazhan", "KARAZHAN" },
    gruul       = { "GruulsLair", "Gruul", "Gruul's Lair" },
    magtheridon = { "MagtheridonsLair", "Magtheridon", "Magtheridon's Lair" },
    ssc         = { "SerpentshrineCavern", "SerpentshrineCaverns", "Serpentshrine Cavern", "SSC" },
    tk          = { "TempestKeep", "TheEye", "The Eye", "TK" },
    za          = { "ZulAman", "Zul'Aman" },
    hyjal       = { "HyjalSummit", "Hyjal Summit", "MountHyjal", "Mount Hyjal" },
    bt          = { "BlackTemple", "Black Temple", "BT" },
    sunwell     = { "SunwellPlateau", "Sunwell Plateau", "SWP" },
}

-- AtlasLoot module names we'll probe (different forks call them differently).
local MODULE_CANDIDATES = {
    "AtlasLootClassic_BurningCrusade",
    "AtlasLootClassic_BurningCrusade_Raids",
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

-- Extract a flat list of itemIDs from an arbitrary AtlasLoot boss-table.
-- AtlasLootClassic stores rows as nested arrays: { rowIndex, itemID } or
-- { rowIndex, itemID, "extra", ... }. We pull anything that looks like an
-- item id (positive integer in the rough range of TBC item IDs).
local function extractItemIDs(bossData)
    local ids = {}
    local function walk(t, depth)
        if type(t) ~= "table" or depth > 4 then return end
        for k, v in pairs(t) do
            if type(v) == "table" then
                walk(v, depth + 1)
            elseif type(v) == "number" and v > 18000 and v < 60000 then
                -- Heuristic: TBC epics are 18000..50000.
                -- Avoid duplicates within the same boss.
                local seen = false
                for _, x in ipairs(ids) do if x == v then seen = true; break end end
                if not seen then table.insert(ids, v) end
            end
        end
    end
    walk(bossData, 0)
    return ids
end

local function findRaidContent(storage, raidID)
    for _, modName in ipairs(MODULE_CANDIDATES) do
        local mod = storage[modName]
        if mod and mod.items then
            for _, key in ipairs(CONTENT_KEYS[raidID] or {}) do
                if mod.items[key] then return mod.items[key], modName, key end
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
            MRT:Print("  findRaidContent → " ..
                (content and ("HIT mod=" .. tostring(modName) .. " key=" .. tostring(contentKey)) or "MISS"))
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

    -- AtlasLoot content can be: an array of boss tables, or a map keyed
    -- by bossID. We try to walk both shapes.
    local bossListByName = {}
    for k, v in pairs(content) do
        if type(v) == "table" then
            local name = v.name or v.Name or (type(k) == "string" and k) or nil
            if name then bossListByName[name:lower()] = v end
        end
    end

    local bossesFilled, totalItems = 0, 0
    for bossIndex, boss in ipairs(raid.bosses) do
        local hit
        for _, candidate in ipairs({ boss.name, boss.nameRU }) do
            if candidate then
                hit = bossListByName[candidate:lower()]
                if hit then break end
                -- Also try partial match: "Gruul" matches "Gruul the Dragonkiller"
                for lname, bossData in pairs(bossListByName) do
                    if lname:find(candidate:lower(), 1, true) then hit = bossData; break end
                end
                if hit then break end
            end
        end
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
