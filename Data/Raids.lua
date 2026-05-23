local ADDON_NAME, ns = ...

local function boss(name, nameRU) return { name = name, nameRU = nameRU } end

ns.Raids = {
    {
        id = "karazhan",
        name = "Karazhan",
        nameRU = "Каражан",
        shortName = "Kara",
        size = 10,
        phase = 1,
        bosses = {
            boss("Attumen the Huntsman", "Аттумен Охотник"),
            boss("Moroes", "Мороэс"),
            boss("Maiden of Virtue", "Дева Добродетели"),
            boss("Opera Event", "Опера"),
            boss("The Curator", "Куратор"),
            boss("Terestian Illhoof", "Терестиан Зловещекопыт"),
            boss("Shade of Aran", "Призрак Арана"),
            boss("Netherspite", "Хранитель Пустоты"),
            boss("Chess Event", "Шахматное событие"),
            boss("Prince Malchezaar", "Принц Малчезаар"),
            boss("Nightbane", "Полуночник"),
        },
    },
    {
        id = "gruul",
        name = "Gruul's Lair",
        nameRU = "Логово Груула",
        shortName = "Gruul",
        size = 25,
        phase = 1,
        bosses = {
            boss("High King Maulgar", "Верховный король Молгар"),
            boss("Gruul the Dragonkiller", "Груул Драконобой"),
        },
    },
    {
        id = "magtheridon",
        name = "Magtheridon's Lair",
        nameRU = "Логово Магтеридона",
        shortName = "Mag",
        size = 25,
        phase = 1,
        bosses = {
            boss("Magtheridon", "Магтеридон"),
        },
    },
    {
        id = "ssc",
        name = "Serpentshrine Cavern",
        nameRU = "Змеиное Святилище",
        shortName = "SSC",
        size = 25,
        phase = 2,
        bosses = {
            boss("Hydross the Unstable", "Гидрос Нестабильный"),
            boss("The Lurker Below", "Подводный Кошмар"),
            boss("Leotheras the Blind", "Леотера Слепой"),
            boss("Fathom-Lord Karathress", "Лорд Глубин Каратресс"),
            boss("Morogrim Tidewalker", "Морогрим Волноход"),
            boss("Lady Vashj", "Леди Вайш"),
        },
    },
    {
        id = "tk",
        name = "The Eye (Tempest Keep)",
        nameRU = "Око (Крепость Бурь)",
        shortName = "TK",
        size = 25,
        phase = 2,
        bosses = {
            boss("Al'ar", "Алар"),
            boss("Void Reaver", "Опустошитель Бездны"),
            boss("High Astromancer Solarian", "Верховный астромант Соларианна"),
            boss("Kael'thas Sunstrider", "Кель'тас Солнечный Скиталец"),
        },
    },
    {
        id = "za",
        name = "Zul'Aman",
        nameRU = "Зул'Аман",
        shortName = "ZA",
        size = 10,
        phase = 3,
        bosses = {
            boss("Nalorakk", "Налоракк"),
            boss("Akil'zon", "Акил'зон"),
            boss("Jan'alai", "Жан'алай"),
            boss("Halazzi", "Халаззи"),
            boss("Hex Lord Malacrass", "Властитель Порчи Малакрасс"),
            boss("Zul'jin", "Зул'джин"),
        },
    },
    {
        id = "hyjal",
        name = "Hyjal Summit",
        nameRU = "Вершина Хиджала",
        shortName = "MH",
        size = 25,
        phase = 3,
        bosses = {
            boss("Rage Winterchill", "Гнев Хладозимья"),
            boss("Anetheron", "Анетерон"),
            boss("Kaz'rogal", "Каз'рогал"),
            boss("Azgalor", "Азгалор"),
            boss("Archimonde", "Архимонд"),
        },
    },
    {
        id = "bt",
        name = "Black Temple",
        nameRU = "Чёрный Храм",
        shortName = "BT",
        size = 25,
        phase = 3,
        bosses = {
            boss("High Warlord Naj'entus", "Верховный военачальник Надж'ентус"),
            boss("Supremus", "Супремус"),
            boss("Shade of Akama", "Призрак Акамы"),
            boss("Teron Gorefiend", "Терон Кровожад"),
            boss("Gurtogg Bloodboil", "Гуртогг Бойлекровь"),
            boss("Reliquary of Souls", "Хранилище Душ"),
            boss("Mother Shahraz", "Мать Шахраз"),
            boss("Illidari Council", "Совет Иллидари"),
            boss("Illidan Stormrage", "Иллидан Ярость Бури"),
        },
    },
    {
        id = "sunwell",
        name = "Sunwell Plateau",
        nameRU = "Плато Солнечного Колодца",
        shortName = "SWP",
        size = 25,
        phase = 4,
        bosses = {
            boss("Kalecgos", "Калесгос"),
            boss("Brutallus", "Бруталлус"),
            boss("Felmyst", "Скверноскользь"),
            boss("The Eredar Twins", "Близнецы Эредар"),
            boss("M'uru", "М'уру"),
            boss("Kil'jaeden", "Кил'джеден"),
        },
    },
}

ns.RaidsByID = {}
for _, raid in ipairs(ns.Raids) do
    ns.RaidsByID[raid.id] = raid
end

function ns.RaidName(raid)
    if not raid then return "" end
    if GetLocale and GetLocale() == "ruRU" and raid.nameRU then return raid.nameRU end
    return raid.name
end

function ns.BossName(boss)
    if not boss then return "" end
    if GetLocale and GetLocale() == "ruRU" and boss.nameRU then return boss.nameRU end
    return boss.name
end
