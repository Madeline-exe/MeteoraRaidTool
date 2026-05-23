local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local function isRL()
    return MRT:CanLead()
end

local function raidDropdownList()
    local list = {}
    for _, raid in ipairs(ns.Raids) do
        list[raid.id] = string.format("P%d — %s", raid.phase or 0, ns.RaidName(raid))
    end
    return list
end

local function raidDropdownOrder()
    local order = {}
    for _, raid in ipairs(ns.Raids) do table.insert(order, raid.id) end
    return order
end

local function parseItemIDFromInput(text)
    if not text then return nil end
    text = text:trim()
    if text == "" then return nil end
    local id = text:match("item:(%d+)")
    if id then return tonumber(id) end
    return tonumber(text)
end

local function buildItemRow(parent, itemID, raidID, bossIndex)
    local SR = MRT.SoftReserve
    local me = UnitName("player")
    local reserved = SR:HasReserved(me, itemID)
    local reservers = SR:GetReservesForItem(itemID)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)

    if UI.editMode then
        local rm = AceGUI:Create("Button")
        rm:SetText("X")
        rm:SetWidth(40)
        rm:SetCallback("OnClick", function()
            MRT.RaidLoot:RemoveItem(raidID, bossIndex, itemID)
            UI:Refresh()
        end)
        row:AddChild(rm)
    else
        local star = AceGUI:Create("Button")
        star:SetText(reserved and "★" or "☆")
        star:SetWidth(45)
        star:SetDisabled(not SR:CanReserve())
        star:SetCallback("OnClick", function()
            SR:ToggleReserve(itemID)
            UI:Refresh()
        end)
        row:AddChild(star)
    end

    local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
    link = link or ("item:" .. itemID)
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"

    local icon = AceGUI:Create("Icon")
    icon:SetImage(iconTex)
    icon:SetImageSize(22, 22)
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetCallback("OnEnter", function(w)
        GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. itemID)
        GameTooltip:Show()
    end)
    icon:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    row:AddChild(icon)

    local lbl = AceGUI:Create("InteractiveLabel")
    lbl:SetText(link)
    lbl:SetWidth(290)
    lbl:SetCallback("OnEnter", function(w)
        GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. itemID)
        GameTooltip:Show()
    end)
    lbl:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    row:AddChild(lbl)

    if not UI.editMode and #reservers > 0 then
        local meta = AceGUI:Create("Label")
        meta:SetWidth(220)
        meta:SetText(string.format("|cffffd200%d|r: %s", #reservers, table.concat(reservers, ", ")))
        row:AddChild(meta)
    end

    parent:AddChild(row)
end

local function buildAddItemRow(parent, raidID, bossIndex)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)

    local edit = AceGUI:Create("EditBox")
    edit:SetWidth(440)
    edit:SetLabel(L["edit_add_hint"])

    local function commit(widget, _, value)
        local itemID = parseItemIDFromInput(value)
        if not itemID then
            MRT:Print(L["loot_bad_item"])
            return
        end
        local ok = MRT.RaidLoot:AddItem(raidID, bossIndex, itemID)
        if ok then
            widget:SetText("")
            UI:Refresh()
        end
    end
    edit:SetCallback("OnEnterPressed", commit)
    row:AddChild(edit)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L["btn_add_item"])
    addBtn:SetWidth(80)
    addBtn:SetCallback("OnClick", function()
        commit(edit, nil, edit:GetText())
    end)
    row:AddChild(addBtn)

    parent:AddChild(row)
end

function UI:BuildReservesTab(container)
    local SR = MRT.SoftReserve

    -- ---------- TOP BAR ----------
    local bar = AceGUI:Create("SimpleGroup")
    bar:SetLayout("Flow")
    bar:SetFullWidth(true)
    container:AddChild(bar)

    if isRL() then
        local dd = AceGUI:Create("Dropdown")
        dd:SetLabel(L["pick_raid"])
        dd:SetList(raidDropdownList(), raidDropdownOrder())
        dd:SetWidth(220)
        dd:SetValue(SR:GetCurrentRaid())
        dd:SetCallback("OnValueChanged", function(_, _, value)
            SR:SetCurrentRaid(value)
            UI:Refresh()
        end)
        bar:AddChild(dd)

        local toggle = AceGUI:Create("Button")
        toggle:SetText(SR:IsOpen() and L["btn_close"] or L["btn_open"])
        toggle:SetWidth(140)
        toggle:SetCallback("OnClick", function()
            SR:SetOpen(not SR:IsOpen())
            UI:Refresh()
        end)
        bar:AddChild(toggle)

        local edit = AceGUI:Create("Button")
        edit:SetText(UI.editMode and L["btn_edit_done"] or L["btn_edit"])
        edit:SetWidth(120)
        edit:SetCallback("OnClick", function()
            UI.editMode = not UI.editMode
            UI:Refresh()
        end)
        bar:AddChild(edit)

        local importBtn = AceGUI:Create("Button")
        importBtn:SetText(L["btn_import_atlas"])
        importBtn:SetWidth(180)
        importBtn:SetCallback("OnClick", function()
            local raidID = SR:GetCurrentRaid()
            if not raidID then MRT:Print(L["hint_pick_raid"]); return end
            local raid = ns.RaidsByID[raidID]
            StaticPopupDialogs = StaticPopupDialogs or {}
            StaticPopupDialogs["MRT_CONFIRM_IMPORT"] = {
                text = L["popup_confirm_import"]:format(ns.RaidName(raid)),
                button1 = YES, button2 = NO,
                OnAccept = function()
                    local ok, bosses, items, err = MRT.AtlasLootImport:ImportRaid(raidID)
                    if ok then
                        MRT:Print(L["import_done"]:format(bosses, items))
                        UI:Refresh()
                    else
                        MRT:Print("|cffff5555" .. (err or "?") .. "|r")
                    end
                end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("MRT_CONFIRM_IMPORT")
        end)
        bar:AddChild(importBtn)

        local clear = AceGUI:Create("Button")
        clear:SetText(L["btn_clear_all"])
        clear:SetWidth(120)
        clear:SetCallback("OnClick", function()
            StaticPopupDialogs = StaticPopupDialogs or {}
            StaticPopupDialogs["MRT_CLEAR_RESERVES"] = {
                text = L["popup_clear_all"],
                button1 = YES, button2 = NO,
                OnAccept = function() SR:ClearAll(); UI:Refresh() end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("MRT_CLEAR_RESERVES")
        end)
        bar:AddChild(clear)

        if MRT.TestMode and MRT.TestMode:IsOn() then
            local botRes = AceGUI:Create("Button")
            botRes:SetText(L["btn_sim_bot_reserves"])
            botRes:SetWidth(170)
            botRes:SetCallback("OnClick", function()
                MRT.TestMode:SimulateBotReserves()
                UI:Refresh()
            end)
            bar:AddChild(botRes)
        end
    else
        local raidID = SR:GetCurrentRaid()
        local raid = raidID and ns.RaidsByID[raidID]
        local raidName = raid and ns.RaidName(raid) or L["none"]
        local statusLbl = AceGUI:Create("Label")
        statusLbl:SetFullWidth(true)
        statusLbl:SetText(L["player_current_raid"]:format(
            raidName,
            SR:IsOpen() and "|cff00ff00" .. L["state_open"] .. "|r" or "|cffff5555" .. L["state_closed"] .. "|r"
        ))
        statusLbl:SetFontObject(GameFontHighlight)
        bar:AddChild(statusLbl)
    end

    -- Test mode toggle — visible to anyone, lets a solo player exercise the addon.
    local testBtn = AceGUI:Create("Button")
    local on = MRT.TestMode and MRT.TestMode:IsOn()
    testBtn:SetText(on and L["btn_test_off"] or L["btn_test_on"])
    testBtn:SetWidth(150)
    testBtn:SetCallback("OnClick", function()
        if MRT.TestMode then MRT.TestMode:Toggle() end
        UI:Refresh()
    end)
    bar:AddChild(testBtn)

    -- ---------- COUNTER ----------
    local me = UnitName("player")
    local count = SR:CountForPlayer(me)
    local maxN = MRT.db.profile.softReserve.maxPerPlayer
    local counter = AceGUI:Create("Label")
    counter:SetFullWidth(true)
    counter:SetFontObject(GameFontNormal)
    counter:SetText(string.format("|cffffd200%s:|r %d / %d%s",
        L["you_reserved"], count, maxN,
        UI.editMode and ("   |cffff8800[" .. L["edit_mode_on"] .. "]|r") or ""))
    container:AddChild(counter)

    -- ---------- BOSS TREE ----------
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local raidID = SR:GetCurrentRaid()
    if not raidID then
        local hint = AceGUI:Create("Label")
        hint:SetFullWidth(true)
        hint:SetText("\n" .. L["hint_pick_raid"])
        scroll:AddChild(hint)
        return
    end

    local raid = ns.RaidsByID[raidID]
    if not raid then return end

    if UI.editMode then
        local tip = AceGUI:Create("Label")
        tip:SetFullWidth(true)
        tip:SetText("|cffaaaaaa" .. L["edit_tip"] .. "|r")
        scroll:AddChild(tip)
    end

    for bossIndex, boss in ipairs(raid.bosses) do
        local items = MRT.RaidLoot:GetItems(raidID, bossIndex)
        local totalReserves = 0
        for _, itemID in ipairs(items) do
            totalReserves = totalReserves + #SR:GetReservesForItem(itemID)
        end

        local title = ns.BossName(boss)
        if #items > 0 then
            title = string.format("%s   |cffaaaaaa[%d %s]|r",
                title, #items, L["items_short"])
            if totalReserves > 0 then
                title = title .. string.format("   |cffffd200%d %s|r",
                    totalReserves, L["reserves_short"])
            end
        end

        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(title)
        group:SetFullWidth(true)
        group:SetLayout("List")
        scroll:AddChild(group)

        if #items == 0 then
            local empty = AceGUI:Create("Label")
            empty:SetText("|cff888888" .. L["boss_no_items"] .. "|r")
            empty:SetFullWidth(true)
            group:AddChild(empty)
        else
            for _, itemID in ipairs(items) do
                buildItemRow(group, itemID, raidID, bossIndex)
            end
        end

        if UI.editMode then
            buildAddItemRow(group, raidID, bossIndex)
        end
    end
end
