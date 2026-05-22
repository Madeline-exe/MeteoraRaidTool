local ADDON_NAME, ns = ...

local function boss(name) return { name = name } end

ns.Raids = {
    {
        id = "karazhan",
        name = "Karazhan",
        shortName = "Kara",
        size = 10,
        phase = 1,
        bosses = {
            boss("Attumen the Huntsman"),
            boss("Moroes"),
            boss("Maiden of Virtue"),
            boss("Opera Event"),
            boss("The Curator"),
            boss("Terestian Illhoof"),
            boss("Shade of Aran"),
            boss("Netherspite"),
            boss("Chess Event"),
            boss("Prince Malchezaar"),
            boss("Nightbane"),
        },
    },
    {
        id = "gruul",
        name = "Gruul's Lair",
        shortName = "Gruul",
        size = 25,
        phase = 1,
        bosses = {
            boss("High King Maulgar"),
            boss("Gruul the Dragonkiller"),
        },
    },
    {
        id = "magtheridon",
        name = "Magtheridon's Lair",
        shortName = "Mag",
        size = 25,
        phase = 1,
        bosses = {
            boss("Magtheridon"),
        },
    },
    {
        id = "ssc",
        name = "Serpentshrine Cavern",
        shortName = "SSC",
        size = 25,
        phase = 2,
        bosses = {
            boss("Hydross the Unstable"),
            boss("The Lurker Below"),
            boss("Leotheras the Blind"),
            boss("Fathom-Lord Karathress"),
            boss("Morogrim Tidewalker"),
            boss("Lady Vashj"),
        },
    },
    {
        id = "tk",
        name = "The Eye (Tempest Keep)",
        shortName = "TK",
        size = 25,
        phase = 2,
        bosses = {
            boss("Al'ar"),
            boss("Void Reaver"),
            boss("High Astromancer Solarian"),
            boss("Kael'thas Sunstrider"),
        },
    },
    {
        id = "za",
        name = "Zul'Aman",
        shortName = "ZA",
        size = 10,
        phase = 3,
        bosses = {
            boss("Nalorakk"),
            boss("Akil'zon"),
            boss("Jan'alai"),
            boss("Halazzi"),
            boss("Hex Lord Malacrass"),
            boss("Zul'jin"),
        },
    },
    {
        id = "hyjal",
        name = "Hyjal Summit",
        shortName = "MH",
        size = 25,
        phase = 3,
        bosses = {
            boss("Rage Winterchill"),
            boss("Anetheron"),
            boss("Kaz'rogal"),
            boss("Azgalor"),
            boss("Archimonde"),
        },
    },
    {
        id = "bt",
        name = "Black Temple",
        shortName = "BT",
        size = 25,
        phase = 3,
        bosses = {
            boss("High Warlord Naj'entus"),
            boss("Supremus"),
            boss("Shade of Akama"),
            boss("Teron Gorefiend"),
            boss("Gurtogg Bloodboil"),
            boss("Reliquary of Souls"),
            boss("Mother Shahraz"),
            boss("Illidari Council"),
            boss("Illidan Stormrage"),
        },
    },
    {
        id = "sunwell",
        name = "Sunwell Plateau",
        shortName = "SWP",
        size = 25,
        phase = 4,
        bosses = {
            boss("Kalecgos"),
            boss("Brutallus"),
            boss("Felmyst"),
            boss("The Eredar Twins"),
            boss("M'uru"),
            boss("Kil'jaeden"),
        },
    },
}

ns.RaidsByID = {}
for _, raid in ipairs(ns.Raids) do
    ns.RaidsByID[raid.id] = raid
end
