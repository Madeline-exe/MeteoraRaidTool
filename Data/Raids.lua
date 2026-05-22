local ADDON_NAME, ns = ...

ns.Raids = {
    {
        id = "karazhan",
        name = "Karazhan",
        shortName = "Kara",
        size = 10,
        phase = 1,
        ejInstanceID = 745,
    },
    {
        id = "gruul",
        name = "Gruul's Lair",
        shortName = "Gruul",
        size = 25,
        phase = 1,
        ejInstanceID = 746,
    },
    {
        id = "magtheridon",
        name = "Magtheridon's Lair",
        shortName = "Mag",
        size = 25,
        phase = 1,
        ejInstanceID = 747,
    },
    {
        id = "ssc",
        name = "Serpentshrine Cavern",
        shortName = "SSC",
        size = 25,
        phase = 2,
        ejInstanceID = 748,
    },
    {
        id = "tk",
        name = "The Eye (Tempest Keep)",
        shortName = "TK",
        size = 25,
        phase = 2,
        ejInstanceID = 749,
    },
    {
        id = "za",
        name = "Zul'Aman",
        shortName = "ZA",
        size = 10,
        phase = 3,
        ejInstanceID = 77,
    },
    {
        id = "hyjal",
        name = "Hyjal Summit",
        shortName = "MH",
        size = 25,
        phase = 3,
        ejInstanceID = 733,
    },
    {
        id = "bt",
        name = "Black Temple",
        shortName = "BT",
        size = 25,
        phase = 3,
        ejInstanceID = 564,
    },
    {
        id = "sunwell",
        name = "Sunwell Plateau",
        shortName = "SWP",
        size = 25,
        phase = 4,
        ejInstanceID = 580,
    },
}

ns.RaidsByID = {}
for _, raid in ipairs(ns.Raids) do
    ns.RaidsByID[raid.id] = raid
end
