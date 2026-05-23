local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local COLUMNS = { "flask", "battle", "guard", "food", "scroll", "oil", "pot", "drums" }
local COLUMN_LABELS = {
    flask  = "Flask",
    battle = "Battle",
    guard  = "Guard",
    food   = "Food",
    scroll = "Scroll",
    oil    = "Oil",
    pot    = "Pot",
    drums  = "Drums",
}

function UI:BuildConsumablesTab(container)
    local refresh = AceGUI:Create("Button")
    refresh:SetText(L["cons_refresh"])
    refresh:SetWidth(160)
    refresh:SetCallback("OnClick", function()
        MRT.Consumables:RefreshRoster()
        UI:RefreshConsumablesTab(container)
    end)
    container:AddChild(refresh)

    local list = AceGUI:Create("ScrollFrame")
    list:SetLayout("List")
    list:SetFullWidth(true)
    list:SetFullHeight(true)
    container:AddChild(list)

    self._consList = list
    self:RefreshConsumablesTab(container)
end

function UI:RefreshConsumablesTab()
    local list = self._consList
    if not list then return end
    list:ReleaseChildren()

    MRT.Consumables:RefreshRoster()
    local roster = MRT.Consumables:GetRoster()
    local players = {}
    for name in pairs(roster) do table.insert(players, name) end
    table.sort(players)

    if #players == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["cons_no_raid"])
        lbl:SetFullWidth(true)
        list:AddChild(lbl)
        return
    end

    local header = AceGUI:Create("Label")
    header:SetFullWidth(true)
    local parts = { string.format("%-14s", L["cons_player"]) }
    for _, col in ipairs(COLUMNS) do
        parts[#parts + 1] = string.format("|cffaaaaaa%-8s|r", COLUMN_LABELS[col])
    end
    header:SetText(table.concat(parts, " "))
    list:AddChild(header)

    for _, name in ipairs(players) do
        local data = roster[name]
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        local class = data.class
        local color = class and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr) or "ffffffff"
        local rowParts = { string.format("|c%s%-14s|r", color, name:sub(1, 14)) }
        for _, col in ipairs(COLUMNS) do
            if data.buffs[col] then
                rowParts[#rowParts + 1] = "|cff00ff00   ok   |r"
            else
                rowParts[#rowParts + 1] = "|cff666666   --   |r"
            end
        end
        row:SetText(table.concat(rowParts, " "))
        list:AddChild(row)
    end
end

