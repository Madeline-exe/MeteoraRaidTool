local ADDON_NAME, ns = ...

-- Compat shims: TBC Classic Anniversary 2.5.5 moved several globals into namespaces.
-- Keep both code paths so the addon works on old 2.5.4 builds and on 2.5.5+.
local function _getAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    end
    return _G.GetAddOnMetadata and _G.GetAddOnMetadata(name, field) or nil
end

local function _isAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name) or false
end

local function _unitBuff(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local d = C_UnitAuras.GetBuffDataByIndex(unit, index, filter)
        if not d then return nil end
        return d.name, d.icon, d.applications or d.charges, d.dispelName, d.duration,
               d.expirationTime, d.sourceUnit, d.isStealable, d.nameplateShowPersonal, d.spellId
    end
    return _G.UnitBuff and _G.UnitBuff(unit, index, filter)
end

ns.compat = {
    GetAddOnMetadata = _getAddOnMetadata,
    IsAddOnLoaded    = _isAddOnLoaded,
    UnitBuff         = _unitBuff,
}

local MRT = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceHook-3.0"
)

_G.MeteoraRaidTool = MRT
ns.MRT = MRT
ns.ADDON_NAME = ADDON_NAME

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true) or setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

MRT.version = ns.compat.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
MRT.commPrefix = "MRT1"

local defaults = {
    profile = {
        ui = {
            scale = 1.0,
            locked = false,
            mainFramePoint = { "CENTER", nil, "CENTER", 0, 0 },
        },
        loot = {
            councilRanks = { [0] = true, [1] = true },
            councilPlayers = {},
            voteTimeout = 60,
            announceWinner = true,
            announceChannel = "RAID",
        },
        softReserve = {
            maxPerPlayer = 2,
            allowDuplicates = false,
            lockedAfterPull = true,
        },
        consumables = {
            trackFlasks = true,
            trackFood = true,
            trackScrolls = true,
            trackWeaponOils = true,
            trackBattleElixirs = true,
            trackGuardianElixirs = true,
            warnMissingAtPull = true,
        },
        minimap = {
            hide = false,
        },
    },
    global = {
        lootHistory = {},
        reserveHistory = {},
        consumableLog = {},
        lootPool = {},
    },
    char = {
        epgp = { ep = 0, gp = 0 },
        dkp = 0,
    },
}

function MRT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MeteoraRaidToolDB", defaults, true)
    self.charDB = LibStub("AceDB-3.0"):New("MeteoraRaidToolCharDB", { profile = {} }, true)

    self:RegisterChatCommand("mrt", "OnSlashCommand")
    self:RegisterChatCommand("meteora", "OnSlashCommand")

    self.modules = self.modules or {}
end

function MRT:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:SetupMinimapButton()
    self:Print(L["loaded"]:format(self.version))
end

function MRT:SetupMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not Icon then return end

    local dataObj = LDB:NewDataObject(ADDON_NAME, {
        type  = "launcher",
        label = "Meteora",
        icon  = "Interface\\Icons\\INV_Misc_Dice_01",
        OnClick = function(_, button)
            if button == "RightButton" then
                MRT:OpenConfig()
            else
                if MRT.UI and MRT.UI.Toggle then MRT.UI:Toggle() end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Meteora Raid Tool")
            tooltip:AddLine("|cffeda55fЛКМ|r — " .. (L["minimap_lmb"] or "открыть"), 1, 1, 1)
            tooltip:AddLine("|cffeda55fПКМ|r — " .. (L["minimap_rmb"] or "настройки"), 1, 1, 1)
        end,
    })
    Icon:Register(ADDON_NAME, dataObj, self.db.profile.minimap)
end

function MRT:OnPlayerEnteringWorld(_, isInitial)
    if isInitial then
        self:ScheduleTimer(function()
            if self.Comm and self.Comm.AnnounceVersion then
                self.Comm:AnnounceVersion()
            end
        end, 3)
    end
end

function MRT:OnRosterUpdate()
    if self.Consumables and self.Consumables.RefreshRoster then
        self.Consumables:RefreshRoster()
    end
    -- Roster change can flip our RL status (we lost lead, someone gave us
    -- assist, etc.). Refresh UI so the right set of buttons is visible.
    if self.UI and self.UI.RefreshLater then self.UI:RefreshLater() end
end

function MRT:OnSlashCommand(input)
    input = (input or ""):trim():lower()
    local cmd, rest = input:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "show" or cmd == "toggle" then
        if self.UI and self.UI.Toggle then self.UI:Toggle() end
    elseif cmd == "sync" then
        if self.RaidLoot and self.SoftReserve then
            local raidID = self.SoftReserve:GetCurrentRaid()
            if raidID then
                self.RaidLoot:RequestSync(raidID)
                self.SoftReserve:SetOpen(self.SoftReserve:IsOpen())
                self:Print(L["sync_done"])
            else
                self:Print(L["sync_no_raid"])
            end
        end
    elseif cmd == "consumables" or cmd == "cons" then
        if self.UI and self.UI.OpenTab then
            self.UI:OpenTab("consumables")
        end
    elseif cmd == "distribute" or cmd == "dist" then
        if self.UI and self.UI.OpenTab then
            self.UI:OpenTab("distribute")
        end
    elseif cmd == "test" then
        if self.TestMode then self.TestMode:HandleSlash(rest) end
    elseif cmd == "atlasdump" then
        if self.AtlasLootImport then
            local raidID = self.SoftReserve and self.SoftReserve:GetCurrentRaid() or nil
            self.AtlasLootImport:Dump(raidID)
        end
    elseif cmd == "buffs" then
        if self.Consumables and self.Consumables.DumpBuffs then
            self.Consumables:DumpBuffs()
        end
    elseif cmd == "askpug" then
        if self.WhisperReserve then self.WhisperReserve:AskAllPugs() end
    elseif cmd == "config" or cmd == "options" then
        self:OpenConfig()
    elseif cmd == "version" then
        self:Print(L["version"]:format(self.version))
    else
        self:PrintHelp()
    end
end

function MRT:PrintHelp()
    self:Print("|cffffd200/mrt|r " .. L["help_show"])
    self:Print("|cffffd200/mrt sync|r " .. L["help_sync"])
    self:Print("|cffffd200/mrt dist|r " .. L["help_dist"])
    self:Print("|cffffd200/mrt cons|r " .. L["help_cons"])
    self:Print("|cffffd200/mrt test|r " .. L["help_test"])
end

function MRT:OpenConfig()
    if self.UI and self.UI.OpenConfig then
        self.UI:OpenConfig()
    else
        self:Print(L["config_unavailable"])
    end
end

function MRT:IsRaidLeader(unit)
    unit = unit or "player"
    if not IsInRaid() then return false end
    local _, rank = GetRaidRosterInfo(self:UnitRaidIndex(unit) or 0)
    return rank == 2
end

function MRT:IsRaidAssistant(unit)
    unit = unit or "player"
    if not IsInRaid() then return false end
    local _, rank = GetRaidRosterInfo(self:UnitRaidIndex(unit) or 0)
    return rank and rank >= 1
end

-- "Can act as RL" — true in raid as leader/assist, OR in test mode, OR solo.
-- Use this for permission gates that should soften in single-player testing.
function MRT:CanLead()
    if self.TestMode and self.TestMode:IsOn() then return true end
    if not IsInRaid() then return true end
    return self:IsRaidLeader() or self:IsRaidAssistant()
end

function MRT:UnitRaidIndex(unit)
    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit("raid" .. i, unit) then return i end
    end
end

function MRT:IsCouncilMember(name)
    name = Ambiguate(name, "short")
    if self.db.profile.loot.councilPlayers[name] then return true end
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        local gName, _, gRank = GetGuildRosterInfo(i)
        if gName and Ambiguate(gName, "short") == name then
            return self.db.profile.loot.councilRanks[gRank] == true
        end
    end
    return false
end
