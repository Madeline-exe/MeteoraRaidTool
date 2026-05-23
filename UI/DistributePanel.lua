local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Custom Frame-API panel for the Distribute tab (ElvUI-like).
-- Replaces the AceGUI-based BuildDistributeTab.
--
-- Hierarchy:
--   panel (Frame, parent=AceGUI container.frame)
--   ├── topBar (Frame)
--   │   ├── headerFS
--   │   └── action buttons
--   ├── scroll (ScrollFrame, UIPanelScrollFrameTemplate)
--   └── child (Frame)
--       └── sections[] (Skin:CreateSection)
--           └── itemRows[] inside each section.content
-- ============================================================

local panel              -- root Frame
local topBar             -- Frame
local headerFS           -- FontString
local btnClear, btnSimDrop, btnSimRoll  -- Buttons
local scroll             -- ScrollFrame
local child              -- scroll child Frame
local sectionPool = {}   -- reusable Section objects
local rowPool     = {}   -- reusable item-row Frames
local rollWidgetPool = {} -- reusable roll-panel Frames

local ROW_HEIGHT      = 56  -- item row total height
local ROLL_LINE_HEIGHT = 16
local SECTION_HEADER  = 22
local SECTION_GAP     = 4
local TOPBAR_HEIGHT   = 28
local ITEM_PAD        = 6

-- ============================================================
-- Roster (extended with test bots when test mode is on)
-- ============================================================

local function rosterList()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then list[#list + 1] = name end
        end
    else
        local me = UnitName("player")
        if me then list[#list + 1] = me end
        for i = 1, (GetNumGroupMembers() or 0) - 1 do
            local n = UnitName("party" .. i)
            if n then list[#list + 1] = n end
        end
    end
    if MRT.TestMode and MRT.TestMode:IsOn() then
        for _, bot in ipairs(MRT.TestMode:GetBots()) do list[#list + 1] = bot end
    end
    return list
end

-- ============================================================
-- Pool helpers
-- ============================================================

local function acquireSection()
    for _, s in ipairs(sectionPool) do
        if not s._inUse then s._inUse = true; s.frame:Show(); return s end
    end
    local s = Skin:CreateSection(child, true)
    s._inUse = true
    table.insert(sectionPool, s)
    return s
end

local function releaseAllSections()
    for _, s in ipairs(sectionPool) do
        s._inUse = false
        s.frame:Hide()
    end
end

local function releaseAllRows()
    for _, r in ipairs(rowPool) do
        r._inUse = false
        r.frame:Hide()
        if r.rollPanel then r.rollPanel:Hide() end
    end
end

-- ============================================================
-- Item row construction
-- ============================================================

local function createItemRow(parent)
    local row = { entry = nil }
    row.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(row.frame, Skin.color.bgAlt, Skin.color.border)
    row.frame:SetHeight(ROW_HEIGHT)

    -- icon
    row.iconBtn = Skin:CreateIconButton(row.frame, 36)
    row.iconBtn:SetPoint("LEFT", row.frame, "LEFT", 6, 0)
    row.iconBtn:SetScript("OnEnter", function(b)
        if not row.entry then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. row.entry.itemID)
        GameTooltip:Show()
    end)
    row.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- link FontString (acts like a hyperlink)
    row.nameFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.nameFS:SetPoint("TOPLEFT", row.iconBtn, "TOPRIGHT", 8, -2)
    row.nameFS:SetWidth(330)
    row.nameFS:SetJustifyH("LEFT")

    row.srFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.srFS:SetPoint("TOPLEFT", row.nameFS, "BOTTOMLEFT", 0, -2)
    row.srFS:SetWidth(330)
    row.srFS:SetJustifyH("LEFT")
    row.srFS:SetTextColor(unpack(Skin.color.accentSoft))

    -- action buttons
    row.btnSR = Skin:CreateButton(row.frame, L["btn_roll_sr"], 100, 22)
    row.btnSR:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -6, -4)

    row.btnFree = Skin:CreateButton(row.frame, L["btn_roll_free"], 120, 22)
    row.btnFree:SetPoint("TOPRIGHT", row.btnSR, "TOPLEFT", -4, 0)

    row.btnDel = Skin:CreateButton(row.frame, "X", 24, 22)
    row.btnDel:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", -6, 4)
    row.btnDel:GetFontString():SetTextColor(unpack(Skin.color.danger))

    row.btnAward = Skin:CreateButton(row.frame, L["btn_award"], 90, 22)
    row.btnAward:SetPoint("RIGHT", row.btnDel, "LEFT", -4, 0)

    -- award dropdown (native UIDropDownMenu)
    row.dd = CreateFrame("Frame", "MRTDistDD" .. (#rowPool + 1), row.frame, "UIDropDownMenuTemplate")
    row.dd:SetPoint("RIGHT", row.btnAward, "LEFT", -8, -2)
    UIDropDownMenu_SetWidth(row.dd, 130)

    row.selectedAward = nil
    row.refreshDropdown = function(reservers)
        UIDropDownMenu_Initialize(row.dd, function(_, level)
            level = level or 1
            local list = rosterList()
            for _, name in ipairs(list) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = name
                info.checked = (name == row.selectedAward)
                info.func = function()
                    row.selectedAward = name
                    UIDropDownMenu_SetText(row.dd, name)
                end
                if reservers then
                    for _, r in ipairs(reservers) do
                        if r == name then info.colorCode = "|cffff8800"; break end
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        if not row.selectedAward and reservers and reservers[1] then
            row.selectedAward = reservers[1]
        end
        UIDropDownMenu_SetText(row.dd, row.selectedAward or "—")
    end

    return row
end

local function acquireRow()
    for _, r in ipairs(rowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createItemRow(child)
    r._inUse = true
    table.insert(rowPool, r)
    return r
end

-- ============================================================
-- Roll panel (live rolls under an item)
-- ============================================================

local function createRollPanel(parent)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(p, Skin.color.bg, Skin.color.borderLight)
    p:SetHeight(60)

    p.titleFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.titleFS:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -4)

    p.btnStop = Skin:CreateButton(p, L["btn_roll_stop"], 110, 20)
    p.btnStop:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -4)

    p.rowFS = {}  -- reused FontStrings for each roller line
    return p
end

local function acquireRollPanel(rowFrame)
    for _, p in ipairs(rollWidgetPool) do
        if not p._inUse then
            p._inUse = true
            p:SetParent(rowFrame)
            p:Show()
            return p
        end
    end
    local p = createRollPanel(rowFrame)
    p._inUse = true
    table.insert(rollWidgetPool, p)
    return p
end

local function fillRollPanel(p, roll)
    p.titleFS:SetText(roll.mode == "sr" and L["roll_panel_sr"] or L["roll_panel_free"])
    -- clear old lines
    for _, fs in ipairs(p.rowFS) do fs:Hide() end

    local sorted = {}
    for player, r in pairs(roll.rolls) do table.insert(sorted, { p = player, r = r }) end
    table.sort(sorted, function(a, b) return a.r > b.r end)

    local y = -22
    if #sorted == 0 then
        local fs = p.rowFS[1] or p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        p.rowFS[1] = fs
        fs:Show()
        fs:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
        fs:SetText(L["roll_waiting"])
        y = y - ROLL_LINE_HEIGHT
    else
        for i, e in ipairs(sorted) do
            local fs = p.rowFS[i] or p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            p.rowFS[i] = fs
            fs:Show()
            fs:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
            local marker = (i == 1) and "|cffffd200>|r " or "  "
            local star   = (roll.allowed and roll.allowed[e.p]) and "|cffff8800*|r " or ""
            fs:SetText(string.format("%s%3d  %s%s", marker, e.r, star, Skin:ColorName(e.p)))
            y = y - ROLL_LINE_HEIGHT
        end
    end

    p.btnStop:SetText(roll.ended and L["btn_roll_clear"] or L["btn_roll_stop"])
    p.btnStop:SetScript("OnClick", function()
        if roll.ended then MRT.Loot:ClearRoll() else MRT.Loot:StopRoll() end
        UI:Refresh()
    end)

    local total = 22 + math.max(1, #sorted > 0 and #sorted or 1) * ROLL_LINE_HEIGHT + 28
    p:SetHeight(total)
    return total
end

-- ============================================================
-- Panel creation + lifecycle
-- ============================================================

local function buildPanel(parentFrame)
    panel = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    Skin:ApplyDark(panel)
    panel:SetAllPoints(parentFrame)

    topBar = CreateFrame("Frame", nil, panel)
    topBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
    topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    topBar:SetHeight(TOPBAR_HEIGHT)

    headerFS = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerFS:SetPoint("LEFT", topBar, "LEFT", 4, 0)
    headerFS:SetTextColor(unpack(Skin.color.accent))

    btnClear = Skin:CreateButton(topBar, L["btn_clear_pool"], 140, 22)
    btnClear:SetPoint("RIGHT", topBar, "RIGHT", 0, 0)
    btnClear:SetScript("OnClick", function()
        local raidID = MRT.SoftReserve and MRT.SoftReserve:GetCurrentRaid()
        if not raidID then return end
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs["MRT_CLEAR_POOL_FRAME"] = {
            text = L["popup_clear_pool"], button1 = YES, button2 = NO,
            OnAccept = function() MRT.Loot:ClearPool(raidID); UI:Refresh() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MRT_CLEAR_POOL_FRAME")
    end)

    btnSimDrop = Skin:CreateButton(topBar, L["btn_sim_drop"], 150, 22)
    btnSimDrop:SetPoint("RIGHT", btnClear, "LEFT", -6, 0)
    btnSimDrop:SetScript("OnClick", function()
        MRT.TestMode:SimulateDrop(3); UI:Refresh()
    end)

    btnSimRoll = Skin:CreateButton(topBar, L["btn_sim_rolls"], 150, 22)
    btnSimRoll:SetPoint("RIGHT", btnSimDrop, "LEFT", -6, 0)
    btnSimRoll:SetScript("OnClick", function()
        MRT.TestMode:SimulateRolls(3); UI:Refresh()
    end)

    scroll = CreateFrame("ScrollFrame", "MRTDistScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1) -- size set during layout
    scroll:SetScrollChild(child)
end

-- ============================================================
-- Layout
-- ============================================================

local function layoutItemRow(row, entry, width)
    row.entry = entry
    row.frame:SetWidth(width)
    row.frame:SetHeight(ROW_HEIGHT)

    local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(entry.itemID)
    link = link or entry.link or ("item:" .. entry.itemID)
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
    row.iconBtn.icon:SetTexture(iconTex)

    local sourceTag = ""
    if entry.source == "chat" then
        sourceTag = "   |cffaaaaaa[" .. L["pool_chat_tag"] .. "]|r"
    elseif entry.source == "test" then
        sourceTag = "   |cffffaa00[" .. (L["test_badge"] or "TEST") .. "]|r"
    end
    row.nameFS:SetText(link .. sourceTag)

    local SR = MRT.SoftReserve
    local reservers = SR and SR:GetReservesForItem(entry.itemID) or {}
    if #reservers > 0 then
        row.srFS:SetText("|cffff8800" .. L["award_sr"] .. ":|r " .. table.concat(reservers, ", "))
    else
        row.srFS:SetText("|cff666666" .. L["award_no_sr"] .. "|r")
    end

    -- SR roll button enabled only when there are reservers
    if #reservers > 0 then
        row.btnSR:Show()
        row.btnSR:SetScript("OnClick", function()
            MRT.Loot:StartRoll(entry, "sr", reservers, 30); UI:Refresh()
        end)
    else
        row.btnSR:Hide()
    end

    row.btnFree:SetScript("OnClick", function()
        MRT.Loot:StartRoll(entry, "free", nil, 30); UI:Refresh()
    end)

    row.refreshDropdown(reservers)

    row.btnAward:SetScript("OnClick", function()
        local winner = row.selectedAward or (reservers[1])
        if not winner then MRT:Print(L["award_pick_winner"]); return end
        MRT.Loot:Award(entry, winner, nil); UI:Refresh()
    end)

    row.btnDel:SetScript("OnClick", function()
        MRT.Loot:RemoveFromPool(entry.uid); UI:Refresh()
    end)

    -- Live roll panel
    local roll = MRT.Loot:GetActiveRoll()
    if roll and roll.entry and roll.entry.uid == entry.uid then
        local rp = acquireRollPanel(row.frame)
        rp:SetPoint("TOPLEFT", row.frame, "BOTTOMLEFT", 0, -2)
        rp:SetPoint("TOPRIGHT", row.frame, "BOTTOMRIGHT", 0, -2)
        local extra = fillRollPanel(rp, roll)
        row.rollPanel = rp
        return ROW_HEIGHT + 2 + extra
    else
        row.rollPanel = nil
    end

    return ROW_HEIGHT
end

local function refresh()
    if not panel then return end

    releaseAllSections()
    releaseAllRows()
    for _, p in ipairs(rollWidgetPool) do p._inUse = false; p:Hide() end

    local SR = MRT.SoftReserve
    local raidID = SR and SR:GetCurrentRaid()
    local raid = raidID and ns.RaidsByID[raidID] or nil

    headerFS:SetText(string.format("%s: %s", L["dist_pool_title"],
        raid and ns.RaidName(raid) or (raidID or "—")))

    local testOn = MRT.TestMode and MRT.TestMode:IsOn()
    if testOn then btnSimDrop:Show(); btnSimRoll:Show() else btnSimDrop:Hide(); btnSimRoll:Hide() end

    if not MRT:CanLead() then
        child:SetHeight(60)
        local hint = child.hintFS or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hintFS = hint
        hint:Show()
        hint:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        hint:SetText(L["dist_need_lead"])
        return
    end
    if child.hintFS then child.hintFS:Hide() end

    if not raidID then
        child:SetHeight(60)
        local hint = child.hintFS2 or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hintFS2 = hint
        hint:Show()
        hint:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        hint:SetText(L["hint_pick_raid"])
        return
    end
    if child.hintFS2 then child.hintFS2:Hide() end

    local pool = MRT.Loot:GetPool(raidID)
    local hasItems = false
    for _, items in pairs(pool) do
        if #items > 0 then hasItems = true; break end
    end
    if not hasItems then
        child:SetHeight(60)
        local hint = child.hintFS3 or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hintFS3 = hint
        hint:Show()
        hint:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        hint:SetText(L["dist_pool_empty"])
        return
    end
    if child.hintFS3 then child.hintFS3:Hide() end

    -- Lay out sections by boss index, unmapped (0) last.
    local bossOrder = {}
    if raid then
        for i in ipairs(raid.bosses) do table.insert(bossOrder, i) end
    end
    table.insert(bossOrder, 0)

    local width = scroll:GetWidth()
    if not width or width < 1 then width = 600 end
    child:SetWidth(width)

    local y = -2
    for _, bossIndex in ipairs(bossOrder) do
        local items = pool[bossIndex]
        if items and #items > 0 then
            local bossName
            if bossIndex > 0 and raid and raid.bosses[bossIndex] then
                bossName = ns.BossName(raid.bosses[bossIndex])
            else
                bossName = L["dist_unmapped"]
            end

            local section = acquireSection()
            section.frame:ClearAllPoints()
            section.frame:SetParent(child)
            section.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
            section.frame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
            section:SetTitle(bossName)
            section:SetMeta(string.format("%d %s", #items, L["items_short"]))

            section.onToggle = function() UI:Refresh() end

            local contentHeight = ITEM_PAD
            if section.expanded then
                local rowY = -ITEM_PAD
                for _, entry in ipairs(items) do
                    local r = acquireRow()
                    r.frame:ClearAllPoints()
                    r.frame:SetParent(section.content)
                    r.frame:SetPoint("TOPLEFT", section.content, "TOPLEFT", 4, rowY)
                    r.frame:SetPoint("TOPRIGHT", section.content, "TOPRIGHT", -4, rowY)

                    local rowH = layoutItemRow(r, entry, section.content:GetWidth() - 8)
                    rowY = rowY - rowH - 4
                    contentHeight = contentHeight + rowH + 4
                end
                contentHeight = contentHeight + ITEM_PAD
            end
            section:Layout(contentHeight)

            local sectionH = section.frame:GetHeight()
            y = y - sectionH - SECTION_GAP
        end
    end

    child:SetHeight(math.max(60, -y + 4))
end

-- ============================================================
-- Public API integration with UI module
-- ============================================================

function UI:BuildDistributeTab(container)
    -- AceGUI Container exposes .content (inner area) and .frame (outer).
    -- We parent to .content so AceGUI's own border/header stays around us.
    local parentFrame = container.content or container.frame
    if not parentFrame then return end

    if not panel then
        buildPanel(parentFrame)
    else
        panel:SetParent(parentFrame)
        panel:ClearAllPoints()
        panel:SetAllPoints(parentFrame)
        panel:Show()
    end
    refresh()
end

function UI:HideDistributePanel()
    if panel then panel:Hide() end
end
