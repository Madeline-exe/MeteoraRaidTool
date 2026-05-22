local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local DB = ns.Consumables

local Consumables = MRT:NewModule("Consumables", "AceEvent-3.0", "AceTimer-3.0")
MRT.Consumables = Consumables

local roster = {}
local scanTimer

function Consumables:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END",   "OnEncounterEnd")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",  "OnCombatEnd")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
end

function Consumables:OnEncounterStart()
    self:ScanRaid("pull")
    if scanTimer then self:CancelTimer(scanTimer) end
    scanTimer = self:ScheduleRepeatingTimer("ScanRaid", 5, "fight")
end

function Consumables:OnEncounterEnd()
    if scanTimer then self:CancelTimer(scanTimer); scanTimer = nil end
end

function Consumables:OnCombatStart()
    self:ScanRaid("combat")
end

function Consumables:OnCombatEnd()
end

function Consumables:OnUnitAura(_, unit)
    if not unit or not UnitIsPlayer(unit) then return end
    if not UnitInRaid(unit) and not UnitInParty(unit) then return end
    self:ScanUnit(unit)
end

function Consumables:RefreshRoster()
    roster = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            self:ScanUnit(unit)
        end
    elseif IsInGroup() then
        self:ScanUnit("player")
        for i = 1, GetNumGroupMembers() - 1 do
            self:ScanUnit("party" .. i)
        end
    else
        self:ScanUnit("player")
    end
end

function Consumables:ScanRaid(reason)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            self:ScanUnit("raid" .. i)
        end
    else
        self:ScanUnit("player")
        for i = 1, (GetNumGroupMembers() - 1) do
            self:ScanUnit("party" .. i)
        end
    end
    if reason == "pull" and MRT.db.profile.consumables.warnMissingAtPull then
        self:WarnMissing()
    end
end

function Consumables:ScanUnit(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    if not name then return end
    local data = roster[name] or { name = name, class = (select(2, UnitClass(unit))), buffs = {} }
    wipe(data.buffs)

    for i = 1, 40 do
        local auraName, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
        if not auraName then break end
        if spellID then
            local category, label = DB:Lookup(spellID)
            if category then
                data.buffs[category] = label
            end
        end
    end
    roster[name] = data
end

function Consumables:GetRoster()
    return roster
end

function Consumables:WarnMissing()
    local missing = {}
    for name, data in pairs(roster) do
        local lacks = {}
        if MRT.db.profile.consumables.trackFlasks and not data.buffs.flask
           and not (data.buffs.battle and data.buffs.guard) then
            table.insert(lacks, "flask/elix")
        end
        if MRT.db.profile.consumables.trackFood and not data.buffs.food then
            table.insert(lacks, "food")
        end
        if #lacks > 0 then
            table.insert(missing, name .. " (" .. table.concat(lacks, ", ") .. ")")
        end
    end
    if #missing > 0 then
        MRT:Print(L["cons_missing"] .. ": " .. table.concat(missing, ", "))
    end
end

function Consumables:OpenWindow()
    if MRT.UI and MRT.UI.OpenConsumables then
        self:RefreshRoster()
        MRT.UI:OpenConsumables(roster)
    end
end
