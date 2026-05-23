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
    -- Hide custom Frame-API panels owned by the previous tab.
    if UI.HideDistributePanel then UI:HideDistributePanel() end
    if UI.HideReservesPanel   then UI:HideReservesPanel()   end
    local ok, err = pcall(function()
        if group == "reserves" then
            UI:BuildReservesTab(container)
        elseif group == "distribute" then
            UI:BuildDistributeTab(container)
        elseif group == "consumables" then
            UI:BuildConsumablesTab(container)
        elseif group == "status" then
            UI:BuildStatusTab(container)
        elseif group == "history" then
            UI:BuildHistoryTab(container)
        elseif group == "sr_history" then
            UI:BuildSRHistoryTab(container)
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
    self:RegisterMessage("MRT_POOL_CHANGED",      "RefreshLater")
    self:RegisterMessage("MRT_ROLL_UPDATE",       "RefreshLater")
    self:RegisterMessage("MRT_TEST_TOGGLED",      "OnTestToggled")
end

function UI:OnTestToggled()
    if main then
        if MRT.TestMode and MRT.TestMode:IsOn() then
            main:SetTitle("Meteora Raid Tool   |cffffaa00[" .. L["test_badge"] .. "]|r")
        else
            main:SetTitle("Meteora Raid Tool")
        end
    end
    self:RefreshLater()
end

function UI:RefreshLater()
    if main and main:IsShown() then
        self:Refresh()
    end
end

function UI:Build()
    if main then return main end

    main = AceGUI:Create("Frame")
    local titleSuffix = (MRT.TestMode and MRT.TestMode:IsOn())
        and ("   |cffffaa00[" .. L["test_badge"] .. "]|r") or ""
    main:SetTitle("Meteora Raid Tool" .. titleSuffix)
    main:SetStatusText(L["status_ready"])
    main:SetLayout("Fill")
    main:SetWidth(700)
    main:SetHeight(520)
    main:EnableResize(true)
    main:SetCallback("OnClose", function(w) w:Hide() end)

    tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Flow")
    tabGroup:SetTabs({
        { value = "reserves",    text = L["tab_reserves"]    },
        { value = "distribute",  text = L["tab_distribute"]  },
        { value = "consumables", text = L["tab_consumables"] },
        { value = "status",      text = L["tab_status"]      },
        { value = "history",     text = L["tab_history"]     },
        { value = "sr_history",  text = L["tab_sr_history"]  },
    })
    tabGroup:SetCallback("OnGroupSelected", function(_, _, group) safeBuild(group, tabGroup) end)
    tabGroup:SelectTab("reserves")
    main:AddChild(tabGroup)

    return main
end

function UI:OpenTab(tabValue)
    self:Build()
    if not main then return end
    if not main:IsShown() then main:Show() end
    if tabGroup then tabGroup:SelectTab(tabValue) end
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
        raidID and ns.RaidsByID[raidID] and ns.RaidName(ns.RaidsByID[raidID]) or L["none"],
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

        local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
        link = link or ("item:" .. itemID)
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"

        local icon = AceGUI:Create("Icon")
        icon:SetImage(iconTex)
        icon:SetImageSize(20, 20)
        icon:SetWidth(26)
        icon:SetHeight(26)
        icon:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. itemID)
            GameTooltip:Show()
        end)
        icon:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        row:AddChild(icon)

        local nameLbl = AceGUI:Create("InteractiveLabel")
        nameLbl:SetText(link)
        nameLbl:SetWidth(254)
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

-- ============================================================
-- SR History tab
-- ============================================================

function UI:BuildSRHistoryTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local history = MRT.SoftReserve and MRT.SoftReserve:GetHistory() or {}
    if #history == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["sr_history_empty"])
        lbl:SetFullWidth(true)
        scroll:AddChild(lbl)
        return
    end

    for i = #history, 1, -1 do
        local entry = history[i]
        local raid = entry.raidID and ns.RaidsByID[entry.raidID]
        local raidName = raid and ns.RaidName(raid) or (entry.raidID or "?")

        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(string.format("%s — %s",
            date("%Y-%m-%d %H:%M", entry.timestamp), raidName))
        group:SetFullWidth(true)
        group:SetLayout("List")
        scroll:AddChild(group)

        local players = {}
        for player in pairs(entry.reserves or {}) do table.insert(players, player) end
        table.sort(players)

        if #players == 0 then
            local empty = AceGUI:Create("Label")
            empty:SetText("|cff888888" .. L["sr_history_no_reserves"] .. "|r")
            empty:SetFullWidth(true)
            group:AddChild(empty)
        else
            for _, player in ipairs(players) do
                local items = entry.reserves[player] or {}
                local linkParts = {}
                for _, itemID in ipairs(items) do
                    local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)
                    table.insert(linkParts, link)
                end
                local row = AceGUI:Create("Label")
                row:SetFullWidth(true)
                row:SetText(string.format("|cffffd200%s|r — %s", player, table.concat(linkParts, ", ")))
                group:AddChild(row)
            end
        end
    end
end
