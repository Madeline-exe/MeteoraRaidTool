local ADDON_NAME, ns = ...

ns.Consumables = ns.Consumables or {}
local C = ns.Consumables

C.FLASKS = {
    [28518] = "Flask of Fortification",
    [28519] = "Flask of Mighty Restoration",
    [28520] = "Flask of Pure Death",
    [28521] = "Flask of Relentless Assault",
    [28540] = "Flask of Blinding Light",
    [28521] = "Flask of Relentless Assault",
    [41608] = "Shattrath Flask of Fortification",
    [41609] = "Shattrath Flask of Mighty Restoration",
    [41610] = "Shattrath Flask of Pure Death",
    [41611] = "Shattrath Flask of Relentless Assault",
    [41612] = "Shattrath Flask of Blinding Light",
    [42735] = "Flask of Distilled Wisdom",
    [42736] = "Flask of Supreme Power",
}

C.BATTLE_ELIXIRS = {
    [28490] = "Elixir of Major Strength",
    [28491] = "Healing Power",
    [28493] = "Elixir of Major Frost Power",
    [28497] = "Elixir of Mastery",
    [28501] = "Elixir of Major Shadow Power",
    [28502] = "Elixir of Major Defense",
    [28503] = "Elixir of Major Firepower",
    [33726] = "Elixir of Mastery",
    [33720] = "Adept's Elixir",
    [33721] = "Elixir of Major Agility",
    [54452] = "Adept's Elixir",
    [11406] = "Elixir of Demonslaying",
    [45373] = "Bloodied Arcanum",
    [45427] = "Earthen Vitality",
}

C.GUARDIAN_ELIXIRS = {
    [39627] = "Elixir of Empowerment",
    [39626] = "Elixir of Major Mageblood",
    [28494] = "Elixir of Major Defense",
    [11348] = "Elixir of Superior Defense",
    [54212] = "Earthen Elixir",
    [11405] = "Elixir of the Mongoose",
}

C.FOOD_BUFFS = {
    [33256] = "Spicy Crawdad",
    [33257] = "Blackened Sporefish",
    [33259] = "Grilled Mudfish",
    [33261] = "Poached Bluefish",
    [33263] = "Roasted Clefthoof",
    [33265] = "Warp Burger",
    [33267] = "Ravager Dog",
    [33268] = "Talbuk Steak",
    [33269] = "Crunchy Serpent",
    [33272] = "Golden Fish Sticks",
    [44958] = "Hyjal Heated Honey Mead",
    [46687] = "Stormchops",
    [46682] = "Fisherman's Feast",
    [57291] = "Fish Feast",
}

C.SCROLLS = {
    [33077] = "Scroll of Strength V",
    [33078] = "Scroll of Agility V",
    [33079] = "Scroll of Stamina V",
    [33080] = "Scroll of Intellect V",
    [33081] = "Scroll of Spirit V",
    [33082] = "Scroll of Protection V",
}

C.WEAPON_OILS = {
    [28583] = "Superior Wizard Oil",
    [28590] = "Superior Mana Oil",
    [25123] = "Adamantite Sharpening Stone",
    [29453] = "Adamantite Weightstone",
    [25124] = "Adamantite Sharpening Stone",
    [46939] = "Brilliant Wizard Oil",
    [25555] = "Sharpen Blade V",
}

C.RUNES = {
    [54730] = "Brilliant Mana Oil",
    [29335] = "Demonic Rune",
    [29336] = "Demonic Rune",
}

C.BATTLE_POTIONS = {
    [11406] = "Elixir of Demonslaying",
    [17539] = "Greater Arcane Elixir",
    [22850] = "Elemental Sharpening Stone",
    [22844] = "Night Dragon's Breath",
    [22845] = "Whipper Root Tuber",
    [22729] = "Heroic Potion",
    [22730] = "Ironshield Potion",
    [22744] = "Insane Strength Potion",
    [28548] = "Haste Potion",
    [28507] = "Destruction Potion",
    [28494] = "Major Frost Protection Potion",
    [28538] = "Restoration Potion",
    [22835] = "Dreamtonic",
    [22836] = "Dreamshard Elixir",
    [22837] = "Dreamtonic",
}

C.GUILD_DRUMS = {
    [35476] = "Drums of Battle",
    [35475] = "Drums of War",
    [35477] = "Drums of Speed",
    [35474] = "Drums of Panic",
    [35478] = "Drums of Restoration",
}

C.CATEGORIES = {
    flask   = { name = "Flask",            db = C.FLASKS },
    battle  = { name = "Battle Elixir",    db = C.BATTLE_ELIXIRS },
    guard   = { name = "Guardian Elixir",  db = C.GUARDIAN_ELIXIRS },
    food    = { name = "Food Buff",        db = C.FOOD_BUFFS },
    scroll  = { name = "Scroll",           db = C.SCROLLS },
    oil     = { name = "Weapon Enhance",   db = C.WEAPON_OILS },
    pot     = { name = "Combat Potion",    db = C.BATTLE_POTIONS },
    drums   = { name = "Drums",            db = C.GUILD_DRUMS },
}

function C:Lookup(spellID)
    for category, info in pairs(self.CATEGORIES) do
        if info.db[spellID] then
            return category, info.db[spellID]
        end
    end
end

-- Name-based fallback. TBC Anniversary sometimes returns slightly different
-- spell IDs than the captured ones in C.* tables (server-side variants /
-- ranks), so we also match by substring of the buff name.
-- Name-based fallback. TBC Anniversary often returns slightly different
-- spell IDs than the captured ones in C.* tables (server-side variants /
-- ranks), so we also match by substring of the buff name. "Well Fed" is
-- the generic food buff name in TBC — most reliable food signal.
C.NAME_PATTERNS = {
    flask  = {
        "Flask of",          -- en: all TBC flasks
        "Фласка",            -- ru
        "Shattrath Flask",
    },
    battle = {
        "Elixir of Major Strength",   "Elixir of Major Agility",
        "Elixir of Major Firepower",  "Elixir of Major Shadow Power",
        "Elixir of Major Frost Power","Elixir of Mastery",
        "Adept's Elixir",             "Elixir of Demonslaying",
        "Bloodied Arcanum",           "Lesser Arcane Elixir",
        "Greater Arcane Elixir",      "Onslaught Elixir",
        "Эликсир мастерства",         "Эликсир огромной силы",
        "Эликсир огромной ловкости",  "Эликсир магической мощи",
        "Эликсир тени",
    },
    guard  = {
        "Elixir of Major Defense",   "Elixir of Major Mageblood",
        "Elixir of Empowerment",     "Earthen Elixir",
        "Elixir of the Mongoose",    "Elixir of Superior Defense",
        "Elixir of Major Fortitude", "Elixir of Ironskin",
        "Elixir of Draenic Wisdom",  "Elixir of Healing Power",
        "Эликсир мангуста",          "Эликсир огромной защиты",
        "Эликсир огромной выносливости",
    },
    food   = {
        "Well Fed",                  -- en: generic food buff (covers ALL TBC food)
        "Хорошо накормлен",          -- ru
    },
    scroll = {
        "Scroll of ",                -- en
        "Свиток ",                   -- ru
    },
    oil    = {
        "Wizard Oil",      "Mana Oil",       "Sharpening Stone",
        "Weightstone",     "Sharpen Blade",  "Brilliant Wizard",
        "Brilliant Mana",  "Superior Wizard","Superior Mana",
        "Adamantite Sharpening", "Adamantite Weightstone",
        "Точильный камень", "Утяжелитель",
        "Чародейское масло", "Магическое масло",
    },
    pot    = {
        "Potion of",       "Heroic Potion",  "Ironshield Potion",
        "Insane Strength", "Destruction Potion", "Haste Potion",
        "Free Action",     "Living Action",  "Major Healing Potion",
        "Зелье",
    },
    drums  = {
        "Drums of ",
        "Барабаны ",
    },
}

function C:LookupByName(buffName)
    if type(buffName) ~= "string" then return nil end
    for category, patterns in pairs(self.NAME_PATTERNS) do
        for _, p in ipairs(patterns) do
            if buffName:find(p, 1, true) then return category, buffName end
        end
    end
end
