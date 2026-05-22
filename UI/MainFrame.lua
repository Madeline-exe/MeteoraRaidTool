local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local UI = MRT:NewModule("UI", "AceEvent-3.0")
MRT.UI = UI

local AceGUI = LibStub("AceGUI-3.0")

local main, tabGroup
UI.editMode = false

local function safeBuild(group, container)
    container:ReleaseChildren()
    local ok, err = pcall(function()
        if group == "reserves" then
            UI:BuildReservesTab(container)
        elseif group == "status" then
            UI:BuildStatusTab(container)
        elseif group == "history" then
            UI:BuildHistoryTab(container)
        end
    end)
    if not ok then
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        lbl:SetText("|cffff5555UI error: " .. tostring(err) .. "|r")
        container:AddChild(lbl)
        MRT:Print("|cffff5555[UI]|r " .. tostring(err))
    end
end

function UI:OnEnable()
    self:RegisterMessage("MRT_SR_STATE_CHANGED",  "RefreshLater")
    self:RegisterMessage("MRT_RAIDLOOT_CHANGED",  "RefreshLater")
end

function UI:RefreshLater()
    if main and main:IsShown() then
        self:Refresh()
    end
end

function UI:Build()
    if main then return main end

    main = AceGUI:Create("Frame")
    main:SetTitle("Meteora Raid Tool")
    main:SetStatusText(L["status_ready"])
    main:SetLayout("Fill")
    main:SetWidth(700)
    main:SetHeight(520)
    main:EnableResize(true)
    main:SetCallback("OnClose", function(w) w:Hide() end)

    tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Flow")
    tabGroup:SetTabs({
        { value = "reserves", text = L["tab_reserves"] },
        { value = "status",   text = L["tab_status"]   },
        { value = "history",  text = L["tab_history"]  },
    })
    tabGroup:SetCallback("OnGroupSelected", function(_, _, group) safeBuild(group, tabGroup) end)
    tabGroup:SelectTab("reserves")
    main:AddChild(tabGroup)

    return main
end

function UI:Toggle()
    local ok, err = pcall(function() self:Build() end)
    if not ok or not main then
        MRT:Print("|cffff5555[UI Toggle]|r " .. tostring(err))
        main = nil
        return
    end
    if main:IsShown() then
        main:Hide()
    else
        main:Show()
        self:Refresh()
    end
end

function UI:Refresh()
    if main and main:IsShown() and tabGroup then
        local current = (tabGroup.localstatus and tabGroup.localstatus.selected) or "reserves"
        safeBuild(current, tabGroup)
    end
end

-- ============================================================
-- Status tab
-- ============================================================

function UI:BuildStatusTab(container)
    local SR = MRT.SoftReserve
    local raidID = SR:GetCurrentRaid()

    local header = AceGUI:Create("Label")
    header:SetFullWidth(true)
    header:SetText(L["status_current_raid"]:format(
        raidID and ns.RaidsByID[raidID] and ns.RaidsByID[raidID].name or L["none"],
        SR:IsOpen() and "|cff00ff00" .. L["state_open"] .. "|r" or "|cffff5555" .. L["state_closed"] .. "|r"
    ))
    header:SetFontObject(GameFontHighlight)
    container:AddChild(header)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local byItem = {}
    for player, items in pairs(SR:GetAll()) do
        for _, itemID in ipairs(items) do
            byItem[itemID] = byItem[itemID] or {}
            table.insert(byItem[itemID], player)
        end
    end

    local sortedIDs = {}
    for id in pairs(byItem) do table.insert(sortedIDs, id) end
    table.sort(sortedIDs, function(a, b) return #byItem[a] > #byItem[b] end)

    if #sortedIDs == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["status_empty"])
        lbl:SetFullWidth(true)
        scroll:AddChild(lbl)
        return
    end

    for _, itemID in ipairs(sortedIDs) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)

        local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)

        local nameLbl = AceGUI:Create("InteractiveLabel")
        nameLbl:SetText(link)
        nameLbl:SetWidth(280)
        nameLbl:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. itemID)
            GameTooltip:Show()
        end)
        nameLbl:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        row:AddChild(nameLbl)

        local players = AceGUI:Create("Label")
        players:SetWidth(360)
        players:SetText(string.format("|cffffd200%d|r — %s", #byItem[itemID], table.concat(byItem[itemID], ", ")))
        row:AddChild(players)

        scroll:AddChild(row)
    end
end

-- ============================================================
-- History tab
-- ============================================================

function UI:BuildHistoryTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local history = MRT.db.global.lootHistory or {}
    if #history == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["history_empty"])
        lbl:SetFullWidth(true)
        scroll:AddChild(lbl)
        return
    end

    for i = #history, math.max(1, #history - 100), -1 do
        local entry = history[i]
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        lbl:SetText(string.format("%s — %s → |cff00ff00%s|r%s",
            date("%Y-%m-%d %H:%M", entry.timestamp),
            entry.link or ("item:" .. entry.itemID),
            entry.winner or "?",
            entry.note and entry.note ~= "" and (" (" .. entry.note .. ")") or ""))
        scroll:AddChild(lbl)
    end
end
