local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Custom Frame-API panel for the Reserves tab.
-- Replaces the AceGUI BuildReservesTab.
-- ============================================================

local panel, topBar, scroll, child
local raidDD, btnToggle, btnEdit, btnClear, btnImport, btnTest, btnBotReserves
local counterFS
local editMode = false
local sectionPool, rowPool, editRowPool = {}, {}, {}

local TOPBAR_H        = 30
local COUNTER_H       = 22
local ROW_HEIGHT      = 30
local EDITROW_HEIGHT  = 32
local SECTION_GAP     = 4
local PAD             = 6

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

local function releaseSections()
    for _, s in ipairs(sectionPool) do s._inUse = false; s.frame:Hide() end
end

local function releaseRows()
    for _, r in ipairs(rowPool) do r._inUse = false; r.frame:Hide() end
    for _, r in ipairs(editRowPool) do r._inUse = false; r.frame:Hide() end
end

-- ============================================================
-- Item rows
-- ============================================================

local function createItemRow(parent)
    local row = {}
    row.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(row.frame, Skin.color.bgAlt, Skin.color.border)
    row.frame:SetHeight(ROW_HEIGHT)

    row.starBtn = Skin:CreateButton(row.frame, "☆", 36, 22)
    row.starBtn:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.starBtn:GetFontString():SetTextColor(unpack(Skin.color.accent))

    row.iconBtn = Skin:CreateIconButton(row.frame, 24)
    row.iconBtn:SetPoint("LEFT", row.starBtn, "RIGHT", 4, 0)
    row.iconBtn:SetScript("OnEnter", function(b)
        if not row.itemID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. row.itemID)
        GameTooltip:Show()
    end)
    row.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    row.nameFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameFS:SetPoint("LEFT", row.iconBtn, "RIGHT", 6, 0)
    row.nameFS:SetWidth(280)
    row.nameFS:SetJustifyH("LEFT")

    row.resFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resFS:SetPoint("RIGHT", row.frame, "RIGHT", -8, 0)
    row.resFS:SetWidth(220)
    row.resFS:SetJustifyH("RIGHT")

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

local function createEditRow(parent)
    local row = {}
    row.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(row.frame, Skin.color.bgAlt, Skin.color.border)
    row.frame:SetHeight(EDITROW_HEIGHT)

    row.rmBtn = Skin:CreateButton(row.frame, "✕", 28, 22)
    row.rmBtn:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.rmBtn:GetFontString():SetTextColor(unpack(Skin.color.danger))

    row.iconBtn = Skin:CreateIconButton(row.frame, 24)
    row.iconBtn:SetPoint("LEFT", row.rmBtn, "RIGHT", 4, 0)
    row.iconBtn:SetScript("OnEnter", function(b)
        if not row.itemID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. row.itemID)
        GameTooltip:Show()
    end)
    row.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    row.nameFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameFS:SetPoint("LEFT", row.iconBtn, "RIGHT", 6, 0)
    row.nameFS:SetWidth(420)
    row.nameFS:SetJustifyH("LEFT")
    return row
end

local function acquireEditRow()
    for _, r in ipairs(editRowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createEditRow(child)
    r._inUse = true
    table.insert(editRowPool, r)
    return r
end

-- ============================================================
-- Add-item input row (edit-mode only, one per section)
-- ============================================================

local addRowPool = {}
local function createAddRow(parent)
    local row = {}
    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetHeight(28)

    row.edit = CreateFrame("EditBox", nil, row.frame, "InputBoxTemplate")
    row.edit:SetPoint("LEFT", row.frame, "LEFT", 12, 0)
    row.edit:SetSize(380, 22)
    row.edit:SetAutoFocus(false)
    row.edit:SetFontObject("GameFontHighlight")

    row.btn = Skin:CreateButton(row.frame, L["btn_add_item"], 80, 22)
    row.btn:SetPoint("LEFT", row.edit, "RIGHT", 6, 0)

    row.hint = row.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.hint:SetPoint("LEFT", row.btn, "RIGHT", 8, 0)
    row.hint:SetText(L["edit_add_hint"])
    return row
end

local function acquireAddRow()
    for _, r in ipairs(addRowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createAddRow(child)
    r._inUse = true
    table.insert(addRowPool, r)
    return r
end

local function releaseAddRows()
    for _, r in ipairs(addRowPool) do
        r._inUse = false
        r.frame:Hide()
        r.edit:SetText("")
        r.edit:ClearFocus()
    end
end

-- ============================================================
-- Native UIDropDownMenu for raid picker
-- ============================================================

local function initRaidDropdown()
    UIDropDownMenu_Initialize(raidDD, function(_, level)
        local SR = MRT.SoftReserve
        local current = SR and SR:GetCurrentRaid()
        for _, raid in ipairs(ns.Raids) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = string.format("P%d — %s", raid.phase or 0, ns.RaidName(raid))
            info.value = raid.id
            info.checked = (raid.id == current)
            info.func = function()
                SR:SetCurrentRaid(raid.id)
                UI:Refresh()
            end
            UIDropDownMenu_AddButton(info, level or 1)
        end
    end)
    local SR = MRT.SoftReserve
    local current = SR and SR:GetCurrentRaid()
    if current then
        local raid = ns.RaidsByID[current]
        UIDropDownMenu_SetText(raidDD, raid and ns.RaidName(raid) or current)
    else
        UIDropDownMenu_SetText(raidDD, L["pick_raid"])
    end
end

-- ============================================================
-- Panel construction
-- ============================================================

local function buildPanel(parentFrame)
    panel = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    Skin:ApplyDark(panel)
    panel:SetAllPoints(parentFrame)

    -- Top bar
    topBar = CreateFrame("Frame", nil, panel)
    topBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD)
    topBar:SetHeight(TOPBAR_H)

    raidDD = CreateFrame("Frame", "MRTReservesRaidDD", topBar, "UIDropDownMenuTemplate")
    raidDD:SetPoint("LEFT", topBar, "LEFT", -12, 0)
    UIDropDownMenu_SetWidth(raidDD, 180)

    btnToggle = Skin:CreateButton(topBar, L["btn_open"], 140, 22)
    btnToggle:SetPoint("LEFT", raidDD, "RIGHT", 8, 2)
    btnToggle:SetScript("OnClick", function()
        local SR = MRT.SoftReserve
        SR:SetOpen(not SR:IsOpen())
        UI:Refresh()
    end)

    btnEdit = Skin:CreateButton(topBar, L["btn_edit"], 130, 22)
    btnEdit:SetPoint("LEFT", btnToggle, "RIGHT", 4, 0)
    btnEdit:SetScript("OnClick", function()
        editMode = not editMode
        UI:Refresh()
    end)

    btnImport = Skin:CreateButton(topBar, L["btn_import_atlas"], 170, 22)
    btnImport:SetPoint("LEFT", btnEdit, "RIGHT", 4, 0)
    btnImport:SetScript("OnClick", function()
        local SR = MRT.SoftReserve
        local raidID = SR:GetCurrentRaid()
        if not raidID then MRT:Print(L["hint_pick_raid"]); return end
        local raid = ns.RaidsByID[raidID]
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs["MRT_CONFIRM_IMPORT_FRAME"] = {
            text = L["popup_confirm_import"]:format(ns.RaidName(raid)),
            button1 = YES, button2 = NO,
            OnAccept = function()
                local ok, bosses, items, err = MRT.AtlasLootImport:ImportRaid(raidID)
                if ok then MRT:Print(L["import_done"]:format(bosses, items)); UI:Refresh()
                else MRT:Print("|cffff5555" .. (err or "?") .. "|r") end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MRT_CONFIRM_IMPORT_FRAME")
    end)

    btnClear = Skin:CreateButton(topBar, L["btn_clear_all"], 120, 22)
    btnClear:SetPoint("RIGHT", topBar, "RIGHT", 0, 0)
    btnClear:SetScript("OnClick", function()
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs["MRT_CLEAR_RES_FRAME"] = {
            text = L["popup_clear_all"], button1 = YES, button2 = NO,
            OnAccept = function() MRT.SoftReserve:ClearAll(); UI:Refresh() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MRT_CLEAR_RES_FRAME")
    end)

    -- Second row of the top bar (test + bot reserves)
    btnTest = Skin:CreateButton(panel, L["btn_test_on"], 150, 22)
    btnTest:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -4)
    btnTest:SetScript("OnClick", function()
        if MRT.TestMode then MRT.TestMode:Toggle() end
        UI:Refresh()
    end)

    btnBotReserves = Skin:CreateButton(panel, L["btn_sim_bot_reserves"], 170, 22)
    btnBotReserves:SetPoint("LEFT", btnTest, "RIGHT", 4, 0)
    btnBotReserves:SetScript("OnClick", function()
        if MRT.TestMode then MRT.TestMode:SimulateBotReserves(); UI:Refresh() end
    end)

    counterFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    counterFS:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD, -(PAD + TOPBAR_H + 8))

    -- Scroll
    scroll = CreateFrame("ScrollFrame", "MRTReservesScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", btnTest, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
end

-- ============================================================
-- Layout
-- ============================================================

local function layoutItemRow(row, itemID, raidID, bossIndex)
    row.itemID = itemID
    local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
    link = link or ("item:" .. itemID)
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
    row.iconBtn.icon:SetTexture(iconTex)
    row.nameFS:SetText(link)

    local SR = MRT.SoftReserve
    local me = UnitName("player")
    local reserved = SR:HasReserved(me, itemID)
    local reservers = SR:GetReservesForItem(itemID)

    row.starBtn:GetFontString():SetText(reserved and "★" or "☆")
    if SR:CanReserve() then row.starBtn:Enable() else row.starBtn:Disable() end
    row.starBtn:SetScript("OnClick", function()
        SR:ToggleReserve(itemID); UI:Refresh()
    end)

    if #reservers > 0 then
        row.resFS:SetText(string.format("|cffffd200%d|r — %s",
            #reservers, table.concat(reservers, ", ")))
    else
        row.resFS:SetText("")
    end
end

local function layoutEditRow(row, itemID, raidID, bossIndex)
    row.itemID = itemID
    local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
    link = link or ("item:" .. itemID)
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
    row.iconBtn.icon:SetTexture(iconTex)
    row.nameFS:SetText(link)
    row.rmBtn:SetScript("OnClick", function()
        MRT.RaidLoot:RemoveItem(raidID, bossIndex, itemID)
        UI:Refresh()
    end)
end

local function parseItemID(text)
    if not text then return nil end
    text = text:trim()
    if text == "" then return nil end
    local id = text:match("item:(%d+)")
    if id then return tonumber(id) end
    return tonumber(text)
end

local function layoutAddRow(row, raidID, bossIndex)
    row.edit:SetText("")
    row.edit:SetScript("OnEnterPressed", function(e)
        local id = parseItemID(e:GetText())
        if not id then MRT:Print(L["loot_bad_item"]); return end
        if MRT.RaidLoot:AddItem(raidID, bossIndex, id) then UI:Refresh() end
    end)
    row.btn:SetScript("OnClick", function()
        local id = parseItemID(row.edit:GetText())
        if not id then MRT:Print(L["loot_bad_item"]); return end
        if MRT.RaidLoot:AddItem(raidID, bossIndex, id) then UI:Refresh() end
    end)
end

local function refresh()
    if not panel then return end
    releaseSections()
    releaseRows()
    releaseAddRows()

    local SR    = MRT.SoftReserve
    local rl    = MRT:CanLead()
    local raidID = SR and SR:GetCurrentRaid()
    local raid   = raidID and ns.RaidsByID[raidID] or nil
    local on     = MRT.TestMode and MRT.TestMode:IsOn()

    -- Update top bar widgets
    initRaidDropdown()
    if rl then raidDD:Show() else raidDD:Hide() end
    btnToggle:SetText(SR:IsOpen() and L["btn_close"] or L["btn_open"])
    btnToggle:SetShown(rl)
    btnEdit:SetText(editMode and L["btn_edit_done"] or L["btn_edit"])
    btnEdit:SetShown(rl)
    btnImport:SetShown(rl)
    btnClear:SetShown(rl)
    btnTest:SetText(on and L["btn_test_off"] or L["btn_test_on"])
    btnBotReserves:SetShown(on and rl)

    -- Counter
    local me = UnitName("player")
    local count = SR and SR:CountForPlayer(me) or 0
    local maxN = MRT.db.profile.softReserve.maxPerPlayer
    counterFS:SetText(string.format("|cffffd200%s:|r %d / %d%s",
        L["you_reserved"], count, maxN,
        editMode and ("   |cffff8800[" .. L["edit_mode_on"] .. "]|r") or ""))

    -- Width
    local width = scroll:GetWidth()
    if not width or width < 1 then width = 600 end
    child:SetWidth(width)

    if not raidID or not raid then
        child:SetHeight(60)
        local hint = child.hintFS or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hintFS = hint
        hint:Show()
        hint:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        hint:SetText(L["hint_pick_raid"])
        return
    end
    if child.hintFS then child.hintFS:Hide() end

    -- Sections by boss
    local y = -2
    for bossIndex, boss in ipairs(raid.bosses) do
        local items = MRT.RaidLoot:GetItems(raidID, bossIndex)
        local hasItems = #items > 0
        local section = acquireSection()
        section.frame:ClearAllPoints()
        section.frame:SetParent(child)
        section.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        section.frame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        section:SetTitle(ns.BossName(boss))

        local totalReserves = 0
        for _, itemID in ipairs(items) do
            totalReserves = totalReserves + #SR:GetReservesForItem(itemID)
        end
        local meta = string.format("%d %s", #items, L["items_short"])
        if totalReserves > 0 then
            meta = meta .. string.format("  ·  %d %s", totalReserves, L["reserves_short"])
        end
        section:SetMeta(meta)
        section.onToggle = function() UI:Refresh() end

        local contentH = PAD
        if section.expanded then
            local rowY = -PAD
            local rowH = editMode and EDITROW_HEIGHT or ROW_HEIGHT
            if hasItems then
                for _, itemID in ipairs(items) do
                    local r = editMode and acquireEditRow() or acquireRow()
                    r.frame:ClearAllPoints()
                    r.frame:SetParent(section.content)
                    r.frame:SetPoint("TOPLEFT", section.content, "TOPLEFT", 4, rowY)
                    r.frame:SetPoint("TOPRIGHT", section.content, "TOPRIGHT", -4, rowY)
                    if editMode then layoutEditRow(r, itemID, raidID, bossIndex)
                    else layoutItemRow(r, itemID, raidID, bossIndex) end
                    rowY = rowY - rowH - 3
                    contentH = contentH + rowH + 3
                end
            else
                local emptyFS = section.content.emptyFS
                if not emptyFS then
                    emptyFS = section.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    section.content.emptyFS = emptyFS
                end
                emptyFS:Show()
                emptyFS:ClearAllPoints()
                emptyFS:SetPoint("TOPLEFT", section.content, "TOPLEFT", 14, rowY - 2)
                emptyFS:SetText(L["boss_no_items"])
                rowY = rowY - 20
                contentH = contentH + 20
            end

            -- "empty" hint above the add row gets cleared if we have items
            if hasItems and section.content.emptyFS then section.content.emptyFS:Hide() end

            -- Add-item row in edit mode
            if editMode then
                local ar = acquireAddRow()
                ar.frame:ClearAllPoints()
                ar.frame:SetParent(section.content)
                ar.frame:SetPoint("TOPLEFT", section.content, "TOPLEFT", 4, rowY - 2)
                ar.frame:SetPoint("TOPRIGHT", section.content, "TOPRIGHT", -4, rowY - 2)
                layoutAddRow(ar, raidID, bossIndex)
                contentH = contentH + 32
            end
            contentH = contentH + PAD
        end
        section:Layout(contentH)
        y = y - section.frame:GetHeight() - SECTION_GAP
    end

    child:SetHeight(math.max(60, -y + 4))
end

-- ============================================================
-- Hook into UI module
-- ============================================================

function UI:BuildReservesTab(container)
    local parentFrame = container.content or container.frame
    if not parentFrame then return end
    if not panel then buildPanel(parentFrame)
    else
        panel:SetParent(parentFrame)
        panel:ClearAllPoints()
        panel:SetAllPoints(parentFrame)
        panel:Show()
    end
    refresh()
end

function UI:HideReservesPanel()
    if panel then panel:Hide() end
end
