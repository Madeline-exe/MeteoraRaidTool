local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local function isRL()
    return MRT:CanLead()
end

local function raidRosterList()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then list[name] = name end
        end
    else
        local me = UnitName("player")
        if me then list[me] = me end
        for i = 1, (GetNumGroupMembers() or 0) - 1 do
            local name = UnitName("party" .. i)
            if name then list[name] = name end
        end
    end
    if MRT.TestMode and MRT.TestMode:IsOn() then
        for _, bot in ipairs(MRT.TestMode:GetBots()) do list[bot] = bot end
    end
    return list
end

local function colorPlayer(name)
    if not name then return "?" end
    if RAID_CLASS_COLORS then
        for i = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid" .. i) or ((i == 1) and "player" or ("party" .. (i - 1)))
            if UnitExists(unit) and UnitName(unit) == name then
                local _, class = UnitClass(unit)
                local c = class and RAID_CLASS_COLORS[class]
                if c then return string.format("|c%s%s|r", c.colorStr, name) end
            end
        end
    end
    return name
end

-- ============================================================
-- One row per pooled item
-- ============================================================

local function buildItemRow(parent, entry)
    local SR = MRT.SoftReserve
    local reservers = SR and SR:GetReservesForItem(entry.itemID) or {}

    local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(entry.itemID)
    link = link or entry.link or ("item:" .. entry.itemID)
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"

    local sourceTag = ""
    if entry.source == "chat" then
        sourceTag = "   |cffaaaaaa[" .. L["pool_chat_tag"] .. "]|r"
    elseif entry.source == "test" then
        sourceTag = "   |cffffaa00[" .. (L["test_badge"] or "TEST") .. "]|r"
    end

    local group = AceGUI:Create("InlineGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    group:SetTitle(link .. sourceTag)
    parent:AddChild(group)

    -- Header row: icon + SR list
    local headRow = AceGUI:Create("SimpleGroup")
    headRow:SetLayout("Flow")
    headRow:SetFullWidth(true)
    group:AddChild(headRow)

    local icon = AceGUI:Create("Icon")
    icon:SetImage(iconTex)
    icon:SetImageSize(28, 28)
    icon:SetWidth(36)
    icon:SetHeight(36)
    icon:SetCallback("OnEnter", function(w)
        GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. entry.itemID)
        GameTooltip:Show()
    end)
    icon:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    headRow:AddChild(icon)

    local srLbl = AceGUI:Create("Label")
    srLbl:SetWidth(440)
    if #reservers > 0 then
        srLbl:SetText("|cffff8800" .. L["award_sr"] .. ":|r " .. table.concat(reservers, ", "))
    else
        srLbl:SetText("|cff888888" .. L["award_no_sr"] .. "|r")
    end
    headRow:AddChild(srLbl)

    -- Action row
    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    group:AddChild(actions)

    -- SR-roll button (only if there are reservers)
    if #reservers > 0 then
        local srRoll = AceGUI:Create("Button")
        srRoll:SetText(L["btn_roll_sr"])
        srRoll:SetWidth(110)
        srRoll:SetCallback("OnClick", function()
            MRT.Loot:StartRoll(entry, "sr", reservers, 30)
            UI:Refresh()
        end)
        actions:AddChild(srRoll)
    end

    local freeRoll = AceGUI:Create("Button")
    freeRoll:SetText(L["btn_roll_free"])
    freeRoll:SetWidth(140)
    freeRoll:SetCallback("OnClick", function()
        MRT.Loot:StartRoll(entry, "free", nil, 30)
        UI:Refresh()
    end)
    actions:AddChild(freeRoll)

    -- Award dropdown
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(L["award_to"])
    dd:SetList(raidRosterList())
    if reservers[1] then dd:SetValue(reservers[1]) end
    dd:SetWidth(180)
    group:AddChild(dd)

    local awardBtn = AceGUI:Create("Button")
    awardBtn:SetText(L["btn_award"])
    awardBtn:SetWidth(110)
    awardBtn:SetCallback("OnClick", function()
        local winner = dd:GetValue()
        if not winner or winner == "" then
            MRT:Print(L["award_pick_winner"])
            return
        end
        MRT.Loot:Award(entry, winner, nil)
        UI:Refresh()
    end)
    group:AddChild(awardBtn)

    local rmBtn = AceGUI:Create("Button")
    rmBtn:SetText("✕")
    rmBtn:SetWidth(40)
    rmBtn:SetCallback("OnClick", function()
        MRT.Loot:RemoveFromPool(entry.uid)
        UI:Refresh()
    end)
    group:AddChild(rmBtn)

    -- Live rolls panel (if this item has an active roll)
    local activeRoll = MRT.Loot:GetActiveRoll()
    if activeRoll and activeRoll.entry and activeRoll.entry.uid == entry.uid then
        local hd = AceGUI:Create("Heading")
        hd:SetText(activeRoll.mode == "sr"
            and L["roll_panel_sr"]
            or L["roll_panel_free"])
        hd:SetFullWidth(true)
        group:AddChild(hd)

        local allowedSet = activeRoll.allowed
        local sorted = {}
        for player, roll in pairs(activeRoll.rolls) do
            table.insert(sorted, { p = player, r = roll })
        end
        table.sort(sorted, function(a, b) return a.r > b.r end)

        if #sorted == 0 then
            local wait = AceGUI:Create("Label")
            wait:SetFullWidth(true)
            wait:SetText("|cffaaaaaa" .. L["roll_waiting"] .. "|r")
            group:AddChild(wait)
        else
            for i, e in ipairs(sorted) do
                local rowLbl = AceGUI:Create("Label")
                rowLbl:SetFullWidth(true)
                local marker = (i == 1) and "|cffffd200▶|r " or "   "
                local star = allowedSet and "|cffff8800★|r " or ""
                rowLbl:SetText(string.format("%s%3d  %s%s", marker, e.r, star, colorPlayer(e.p)))
                group:AddChild(rowLbl)
            end
        end

        local stopBtn = AceGUI:Create("Button")
        stopBtn:SetText(activeRoll.ended and L["btn_roll_clear"] or L["btn_roll_stop"])
        stopBtn:SetWidth(140)
        stopBtn:SetCallback("OnClick", function()
            if activeRoll.ended then
                MRT.Loot:ClearRoll()
            else
                MRT.Loot:StopRoll()
            end
            UI:Refresh()
        end)
        group:AddChild(stopBtn)
    end
end

-- ============================================================
-- Distribute tab
-- ============================================================

function UI:BuildDistributeTab(container)
    local raidID = MRT.SoftReserve and MRT.SoftReserve:GetCurrentRaid() or nil

    if not isRL() then
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        lbl:SetText("\n" .. L["dist_need_lead"])
        container:AddChild(lbl)
        return
    end

    if not raidID then
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        lbl:SetText("\n" .. L["hint_pick_raid"])
        container:AddChild(lbl)
        return
    end

    local bar = AceGUI:Create("SimpleGroup")
    bar:SetLayout("Flow")
    bar:SetFullWidth(true)
    container:AddChild(bar)

    local raid = ns.RaidsByID[raidID]
    local hdr = AceGUI:Create("Label")
    hdr:SetText(string.format("|cffffd200%s:|r %s", L["dist_pool_title"], raid and ns.RaidName(raid) or raidID))
    hdr:SetFontObject(GameFontHighlight)
    hdr:SetWidth(360)
    bar:AddChild(hdr)

    local clearBtn = AceGUI:Create("Button")
    clearBtn:SetText(L["btn_clear_pool"])
    clearBtn:SetWidth(170)
    clearBtn:SetCallback("OnClick", function()
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs["MRT_CLEAR_POOL"] = {
            text = L["popup_clear_pool"],
            button1 = YES, button2 = NO,
            OnAccept = function() MRT.Loot:ClearPool(raidID); UI:Refresh() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MRT_CLEAR_POOL")
    end)
    bar:AddChild(clearBtn)

    if MRT.TestMode and MRT.TestMode:IsOn() then
        local simDrop = AceGUI:Create("Button")
        simDrop:SetText(L["btn_sim_drop"])
        simDrop:SetWidth(170)
        simDrop:SetCallback("OnClick", function()
            MRT.TestMode:SimulateDrop(3)
            UI:Refresh()
        end)
        bar:AddChild(simDrop)

        local simRoll = AceGUI:Create("Button")
        simRoll:SetText(L["btn_sim_rolls"])
        simRoll:SetWidth(170)
        simRoll:SetCallback("OnClick", function()
            MRT.TestMode:SimulateRolls(3)
            UI:Refresh()
        end)
        bar:AddChild(simRoll)
    end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local pool = MRT.Loot:GetPool(raidID)
    local hasItems = false
    for _, items in pairs(pool) do
        if #items > 0 then hasItems = true; break end
    end
    if not hasItems then
        local lbl = AceGUI:Create("Label")
        lbl:SetText("\n" .. L["dist_pool_empty"])
        lbl:SetFullWidth(true)
        scroll:AddChild(lbl)
        return
    end

    -- Group by boss
    local bossOrder = {}
    if raid then
        for i in ipairs(raid.bosses) do table.insert(bossOrder, i) end
    end
    table.insert(bossOrder, 0) -- unmapped bucket last

    for _, bossIndex in ipairs(bossOrder) do
        local items = pool[bossIndex]
        if items and #items > 0 then
            local bossName
            if bossIndex > 0 and raid and raid.bosses[bossIndex] then
                bossName = ns.BossName(raid.bosses[bossIndex])
            else
                bossName = L["dist_unmapped"]
            end
            local bossHeader = AceGUI:Create("Heading")
            bossHeader:SetText(bossName .. "   |cffaaaaaa(" .. #items .. ")|r")
            bossHeader:SetFullWidth(true)
            scroll:AddChild(bossHeader)
            for _, entry in ipairs(items) do
                buildItemRow(scroll, entry)
            end
        end
    end
end

