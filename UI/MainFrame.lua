local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local UI = MRT:NewModule("UI", "AceEvent-3.0")
MRT.UI = UI

local AceGUI = LibStub("AceGUI-3.0")

local TABS = {
    { key = "softreserve", label = "Soft Reserve" },
    { key = "loot",        label = "Loot Council" },
    { key = "consumables", label = "Consumables"  },
    { key = "casino",      label = "Casino"       },
    { key = "history",     label = "History"      },
}

local main, tabGroup

local function buildContent(container, group)
    container:ReleaseChildren()
    if group == "softreserve" then
        UI:BuildSoftReserveTab(container)
    elseif group == "loot" then
        UI:BuildLootTab(container)
    elseif group == "consumables" then
        UI:BuildConsumablesTab(container)
    elseif group == "casino" then
        UI:BuildCasinoTab(container)
    elseif group == "history" then
        UI:BuildHistoryTab(container)
    end
end

function UI:Build()
    if main then return main end

    main = AceGUI:Create("Frame")
    main:SetTitle("Meteora Raid Tool  v" .. MRT.version)
    main:SetStatusText(L["status_ready"])
    main:SetLayout("Fill")
    main:SetWidth(720)
    main:SetHeight(480)
    main:EnableResize(true)
    main:SetCallback("OnClose", function(widget) widget:Hide() end)

    tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Flow")
    local tabs = {}
    for _, t in ipairs(TABS) do
        tabs[#tabs + 1] = { value = t.key, text = t.label }
    end
    tabGroup:SetTabs(tabs)
    tabGroup:SetCallback("OnGroupSelected", function(_, _, group) buildContent(tabGroup, group) end)
    tabGroup:SelectTab("softreserve")
    main:AddChild(tabGroup)

    return main
end

function UI:Toggle()
    self:Build()
    if main:IsShown() then main:Hide() else main:Show() end
end

function UI:BuildHistoryTab(container)
    local sv = AceGUI:Create("ScrollFrame")
    sv:SetLayout("List")
    sv:SetFullWidth(true)
    sv:SetFullHeight(true)
    container:AddChild(sv)

    local history = MRT.db.global.lootHistory
    if #history == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["history_empty"])
        lbl:SetFullWidth(true)
        sv:AddChild(lbl)
        return
    end
    for i = #history, math.max(1, #history - 100), -1 do
        local entry = history[i]
        local label = AceGUI:Create("Label")
        label:SetFullWidth(true)
        label:SetText(string.format("%s — %s → |cff00ff00%s|r (%s)",
            date("%Y-%m-%d %H:%M", entry.timestamp),
            entry.link or ("item:" .. entry.itemID),
            entry.winner or "?",
            entry.reason or ""))
        sv:AddChild(label)
    end
end
