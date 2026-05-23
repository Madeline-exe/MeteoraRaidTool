local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Modal popup that lists every loot drop a single player received.
-- Triggered by clicking a row in the Stats tab.
-- ============================================================

local frame, titleFS, scroll, child, copyBtn
local rowPool = {}
local currentPlayer

local function plainLink(link, itemID)
    if not link then return "item:" .. (itemID or "?") end
    local name = link:match("%[(.-)%]")
    return name or link:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function createRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    Skin:ApplyDark(r.frame, Skin.color.bgAlt, Skin.color.border)
    r.frame:SetHeight(26)

    r.dateFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.dateFS:SetPoint("LEFT", r.frame, "LEFT", 8, 0)
    r.dateFS:SetWidth(120)
    r.dateFS:SetJustifyH("LEFT")

    r.iconBtn = Skin:CreateIconButton(r.frame, 20)
    r.iconBtn:SetPoint("LEFT", r.dateFS, "RIGHT", 4, 0)
    r.iconBtn:SetScript("OnEnter", function(b)
        if not r.itemID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. r.itemID)
        GameTooltip:Show()
    end)
    r.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    r.nameFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameFS:SetPoint("LEFT", r.iconBtn, "RIGHT", 6, 0)
    r.nameFS:SetWidth(240)
    r.nameFS:SetJustifyH("LEFT")

    r.raidFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.raidFS:SetPoint("RIGHT", r.frame, "RIGHT", -8, 0)
    r.raidFS:SetWidth(140)
    r.raidFS:SetJustifyH("RIGHT")
    r.raidFS:SetTextColor(unpack(Skin.color.textDim))
    return r
end

local function acquireRow()
    for _, r in ipairs(rowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createRow()
    r._inUse = true
    table.insert(rowPool, r)
    return r
end

local function releaseRows()
    for _, r in ipairs(rowPool) do r._inUse = false; r.frame:Hide() end
end

-- Collect every history entry for a given player name (exact match,
-- short-form Ambiguate).
local function collect(player)
    local list = {}
    local target = Ambiguate(player or "", "short")
    for i = #(MRT.db.global.lootHistory or {}), 1, -1 do
        local e = MRT.db.global.lootHistory[i]
        if e.winner and Ambiguate(e.winner, "short") == target then
            table.insert(list, e)
        end
    end
    return list
end

local function build()
    if frame then return end
    frame = CreateFrame("Frame", "MeteoraPlayerHistory", UIParent, "BackdropTemplate")
    Skin:ApplyDark(frame)
    frame:SetSize(560, 460)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    tinsert(UISpecialFrames, "MeteoraPlayerHistory")

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    Skin:ApplyDark(titleBar, Skin.color.bgAlt, Skin.color.borderLight)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)

    titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleFS:SetTextColor(unpack(Skin.color.accent))

    local closeBtn = Skin:CreateButton(titleBar, "X", 24, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:GetFontString():SetTextColor(unpack(Skin.color.danger))
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    copyBtn = Skin:CreateButton(frame, L["btn_copy_export"], 130, 22)
    copyBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    copyBtn:SetScript("OnClick", function() UI:ExportPlayerHistory(currentPlayer) end)

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", copyBtn, "TOPRIGHT", -22, 6)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
end

function UI:ShowPlayerHistory(player)
    build()
    currentPlayer = player
    titleFS:SetText(string.format("%s — %s", L["player_history_title"] or "History", player))
    frame:Show()

    releaseRows()
    local list = collect(player)
    child:SetWidth(scroll:GetWidth())

    if #list == 0 then
        local fs = child.hint or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hint = fs
        fs:Show()
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        fs:SetText(L["player_history_empty"] or "Nothing yet.")
        child:SetHeight(60)
        return
    end
    if child.hint then child.hint:Hide() end

    local y = -2
    for _, e in ipairs(list) do
        local r = acquireRow()
        r.itemID = e.itemID
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, y)

        local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(e.itemID)
        link = link or e.link or ("item:" .. e.itemID)
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
        r.iconBtn.icon:SetTexture(iconTex)
        r.dateFS:SetText(e.timestamp and date("%Y-%m-%d %H:%M", e.timestamp) or "")
        r.nameFS:SetText(link)
        local raid = e.raid and ns.RaidsByID[e.raid]
        r.raidFS:SetText(raid and ns.RaidName(raid) or (e.raid or ""))
        y = y - 28
    end
    child:SetHeight(math.max(60, -y + 4))
end

-- Plain-text export for one player
function UI:ExportPlayerHistory(player)
    if not player then return end
    local list = collect(player)
    local rows = {}
    for _, e in ipairs(list) do
        local link = plainLink(e.link, e.itemID)
        local raid = e.raid and ns.RaidsByID[e.raid]
        local raidName = raid and ns.RaidName(raid) or (e.raid or "")
        local dt = e.timestamp and date("%Y-%m-%d %H:%M", e.timestamp) or ""
        table.insert(rows, { dt, link, raidName })
    end

    local headers = { L["stats_col_date"], L["stats_col_last"], L["pick_raid"] }
    local widths  = { 16, 36, 18 }

    local out = {}
    table.insert(out, string.format("**Meteora Raid Tool — %s: %s (%d)**",
        L["player_history_title"] or "History", player, #list))
    table.insert(out, "```")

    local function fmt(parts)
        local cells = {}
        for i, p in ipairs(parts) do
            cells[i] = Skin.padRight(p, widths[i])
        end
        return table.concat(cells, "  ")
    end

    table.insert(out, fmt(headers))
    local total = 0
    for _, w in ipairs(widths) do total = total + w end
    total = total + 2 * (#widths - 1)
    table.insert(out, string.rep("-", total))
    for _, row in ipairs(rows) do table.insert(out, fmt(row)) end
    table.insert(out, "```")

    self:ShowExport(L["export_title_player"] or "Player history — export",
        table.concat(out, "\n"))
end
