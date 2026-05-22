local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local function isRL()
    return MRT:IsRaidLeader() or MRT:IsRaidAssistant() or not IsInRaid()
end

local function raidDropdownList()
    local list = {}
    for _, raid in ipairs(ns.Raids) do
        list[raid.id] = raid.name
    end
    return list
end

local function raidDropdownOrder()
    local order = {}
    for _, raid in ipairs(ns.Raids) do
        table.insert(order, raid.id)
    end
    return order
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
            if MRT.RaidLoot then MRT.RaidLoot:Get(value) end
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

        local clear = AceGUI:Create("Button")
        clear:SetText(L["btn_clear_all"])
        clear:SetWidth(140)
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
    else
        local raidID = SR:GetCurrentRaid()
        local raid = raidID and ns.RaidsByID[raidID]
        local raidName = raid and raid.name or L["none"]
        local statusLbl = AceGUI:Create("Label")
        statusLbl:SetFullWidth(true)
        statusLbl:SetText(L["player_current_raid"]:format(
            raidName,
            SR:IsOpen() and "|cff00ff00" .. L["state_open"] .. "|r" or "|cffff5555" .. L["state_closed"] .. "|r"
        ))
        statusLbl:SetFontObject(GameFontHighlight)
        bar:AddChild(statusLbl)
    end

    -- ---------- COUNTER ----------
    local me = UnitName("player")
    local count = SR:CountForPlayer(me)
    local maxN = MRT.db.profile.softReserve.maxPerPlayer
    local counter = AceGUI:Create("Label")
    counter:SetFullWidth(true)
    counter:SetFontObject(GameFontNormal)
    counter:SetText(string.format("|cffffd200%s:|r %d / %d", L["you_reserved"], count, maxN))
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

    local cache = MRT.RaidLoot and MRT.RaidLoot:Get(raidID) or nil
    if not cache or not cache.bosses or #cache.bosses == 0 then
        local hint = AceGUI:Create("Label")
        hint:SetFullWidth(true)
        hint:SetText("\n" .. L["hint_no_loot_data"])
        scroll:AddChild(hint)

        local refresh = AceGUI:Create("Button")
        refresh:SetText(L["btn_refresh_loot"])
        refresh:SetWidth(200)
        refresh:SetCallback("OnClick", function()
            if MRT.RaidLoot then MRT.RaidLoot:Refresh(raidID) end
            UI:Refresh()
        end)
        scroll:AddChild(refresh)
        return
    end

    local canReserve = SR:CanReserve()

    for _, boss in ipairs(cache.bosses) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(boss.name)
        group:SetFullWidth(true)
        group:SetLayout("List")
        scroll:AddChild(group)

        if #boss.items == 0 then
            local empty = AceGUI:Create("Label")
            empty:SetText(L["boss_no_items"])
            empty:SetFullWidth(true)
            group:AddChild(empty)
        end

        for _, item in ipairs(boss.items) do
            local itemID = item.itemID
            local reserved = SR:HasReserved(UnitName("player"), itemID)
            local reservers = SR:GetReservesForItem(itemID)

            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetFullWidth(true)

            local btn = AceGUI:Create("Button")
            btn:SetText(reserved and "★" or "☆")
            btn:SetWidth(50)
            btn:SetDisabled(not canReserve)
            btn:SetCallback("OnClick", function()
                SR:ToggleReserve(itemID)
                UI:Refresh()
            end)
            row:AddChild(btn)

            local link = item.link or select(2, GetItemInfo(itemID)) or item.name or ("item:" .. itemID)
            local lbl = AceGUI:Create("InteractiveLabel")
            lbl:SetText(link)
            lbl:SetWidth(320)
            lbl:SetCallback("OnEnter", function(w)
                GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. itemID)
                GameTooltip:Show()
            end)
            lbl:SetCallback("OnLeave", function() GameTooltip:Hide() end)
            row:AddChild(lbl)

            local meta = AceGUI:Create("Label")
            meta:SetWidth(180)
            if #reservers > 0 then
                meta:SetText(string.format("|cffffd200%d|r: %s", #reservers, table.concat(reservers, ", ")))
            else
                meta:SetText("")
            end
            row:AddChild(meta)

            group:AddChild(row)
        end
    end
end
