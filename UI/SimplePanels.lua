local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Helpers to build "scroll + list" panels in the dark Frame-API style.
-- Used by: Status, Loot History, SR History, Consumables tabs.
-- Each panel pools its own row Frames and lives across refreshes.
-- ============================================================

local function makePanel(parentFrame)
    local panel = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    Skin:ApplyDark(panel)
    panel:SetAllPoints(parentFrame)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)

    return panel, scroll, child
end

local function showHint(child, text)
    local fs = child.hintFS or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    child.hintFS = fs
    fs:Show()
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
    fs:SetText(text)
    child:SetHeight(60)
end

local function hideHint(child) if child.hintFS then child.hintFS:Hide() end end

-- ============================================================
-- Status tab
-- ============================================================

local statusPanel, statusChild
local statusRowPool = {}

local function createStatusRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, statusChild, "BackdropTemplate")
    Skin:ApplyDark(r.frame, Skin.color.bgAlt, Skin.color.border)
    r.frame:SetHeight(30)

    r.iconBtn = Skin:CreateIconButton(r.frame, 24)
    r.iconBtn:SetPoint("LEFT", r.frame, "LEFT", 4, 0)
    r.iconBtn:SetScript("OnEnter", function(b)
        if not r.itemID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. r.itemID)
        GameTooltip:Show()
    end)
    r.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    r.nameFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameFS:SetPoint("LEFT", r.iconBtn, "RIGHT", 6, 0)
    r.nameFS:SetWidth(260)
    r.nameFS:SetJustifyH("LEFT")

    r.metaFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.metaFS:SetPoint("RIGHT", r.frame, "RIGHT", -8, 0)
    r.metaFS:SetWidth(280)
    r.metaFS:SetJustifyH("RIGHT")
    return r
end

local function acquireStatusRow()
    for _, r in ipairs(statusRowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createStatusRow()
    r._inUse = true
    table.insert(statusRowPool, r)
    return r
end

local function releaseStatusRows()
    for _, r in ipairs(statusRowPool) do r._inUse = false; r.frame:Hide() end
end

function UI:BuildStatusTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not statusPanel then
        statusPanel, _, statusChild = makePanel(parent)
    else
        statusPanel:SetParent(parent); statusPanel:ClearAllPoints()
        statusPanel:SetAllPoints(parent); statusPanel:Show()
    end

    releaseStatusRows()
    local SR = MRT.SoftReserve
    if not SR then return end

    local byItem = {}
    for player, items in pairs(SR:GetAll()) do
        for _, itemID in ipairs(items) do
            byItem[itemID] = byItem[itemID] or {}
            table.insert(byItem[itemID], player)
        end
    end

    local sorted = {}
    for id in pairs(byItem) do table.insert(sorted, id) end
    table.sort(sorted, function(a, b) return #byItem[a] > #byItem[b] end)

    if #sorted == 0 then
        showHint(statusChild, L["status_empty"])
        return
    end
    hideHint(statusChild)

    local width = statusChild:GetParent():GetWidth()
    statusChild:SetWidth(width)
    local y = -2
    for _, itemID in ipairs(sorted) do
        local r = acquireStatusRow()
        r.itemID = itemID
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", statusChild, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", statusChild, "TOPRIGHT", -4, y)

        local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
        link = link or ("item:" .. itemID)
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
        r.iconBtn.icon:SetTexture(iconTex)
        r.nameFS:SetText(link)
        r.metaFS:SetText(string.format("|cffffd200%d|r — %s",
            #byItem[itemID], table.concat(byItem[itemID], ", ")))
        y = y - 32
    end
    statusChild:SetHeight(math.max(60, -y + 4))
end

function UI:HideStatusPanel() if statusPanel then statusPanel:Hide() end end

-- ============================================================
-- Loot History tab
-- ============================================================

local histPanel, histChild
local histRowPool = {}

local function createHistRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, histChild, "BackdropTemplate")
    Skin:ApplyDark(r.frame, Skin.color.bgAlt, Skin.color.border)
    r.frame:SetHeight(28)

    r.timeFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.timeFS:SetPoint("LEFT", r.frame, "LEFT", 6, 0)
    r.timeFS:SetWidth(120)
    r.timeFS:SetJustifyH("LEFT")

    r.iconBtn = Skin:CreateIconButton(r.frame, 22)
    r.iconBtn:SetPoint("LEFT", r.timeFS, "RIGHT", 4, 0)
    r.iconBtn:SetScript("OnEnter", function(b)
        if not r.itemID then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. r.itemID)
        GameTooltip:Show()
    end)
    r.iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    r.nameFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameFS:SetPoint("LEFT", r.iconBtn, "RIGHT", 6, 0)
    r.nameFS:SetWidth(260)
    r.nameFS:SetJustifyH("LEFT")

    r.winnerFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.winnerFS:SetPoint("RIGHT", r.frame, "RIGHT", -8, 0)
    r.winnerFS:SetWidth(160)
    r.winnerFS:SetJustifyH("RIGHT")
    r.winnerFS:SetTextColor(unpack(Skin.color.success))
    return r
end

local function acquireHistRow()
    for _, r in ipairs(histRowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createHistRow()
    r._inUse = true
    table.insert(histRowPool, r)
    return r
end

local function releaseHistRows()
    for _, r in ipairs(histRowPool) do r._inUse = false; r.frame:Hide() end
end

function UI:BuildHistoryTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not histPanel then
        histPanel, _, histChild = makePanel(parent)

        -- Copy-to-clipboard button anchored to the panel top-right
        local copyBtn = Skin:CreateButton(histPanel, L["btn_copy_export"], 130, 22)
        copyBtn:SetPoint("TOPRIGHT", histPanel, "TOPRIGHT", -34, -4)
        copyBtn:SetScript("OnClick", function() UI:ExportLootHistory() end)
        histPanel._copyBtn = copyBtn
    else
        histPanel:SetParent(parent); histPanel:ClearAllPoints()
        histPanel:SetAllPoints(parent); histPanel:Show()
    end
    releaseHistRows()

    local history = MRT.db.global.lootHistory or {}
    if #history == 0 then showHint(histChild, L["history_empty"]); return end
    hideHint(histChild)

    histChild:SetWidth(histChild:GetParent():GetWidth())
    local y = -2
    local first = math.max(1, #history - 100)
    for i = #history, first, -1 do
        local entry = history[i]
        local r = acquireHistRow()
        r.itemID = entry.itemID
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", histChild, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", histChild, "TOPRIGHT", -4, y)

        local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(entry.itemID)
        link = link or entry.link or ("item:" .. entry.itemID)
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
        r.iconBtn.icon:SetTexture(iconTex)
        r.timeFS:SetText(date("%Y-%m-%d %H:%M", entry.timestamp))
        r.nameFS:SetText(link)
        r.winnerFS:SetText(Skin:ColorName(entry.winner or "?"))

        y = y - 30
    end
    histChild:SetHeight(math.max(60, -y + 4))
end

function UI:HideHistoryPanel() if histPanel then histPanel:Hide() end end

-- ============================================================
-- SR History tab
-- ============================================================

local srhPanel, srhChild
local srhSectionPool = {}

local function acquireSRHSection()
    for _, s in ipairs(srhSectionPool) do
        if not s._inUse then s._inUse = true; s.frame:Show(); return s end
    end
    local s = Skin:CreateSection(srhChild, true)
    s._inUse = true
    table.insert(srhSectionPool, s)
    return s
end

local function releaseSRH()
    for _, s in ipairs(srhSectionPool) do s._inUse = false; s.frame:Hide() end
end

function UI:BuildSRHistoryTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not srhPanel then
        srhPanel, _, srhChild = makePanel(parent)
    else
        srhPanel:SetParent(parent); srhPanel:ClearAllPoints()
        srhPanel:SetAllPoints(parent); srhPanel:Show()
    end
    releaseSRH()

    local history = MRT.SoftReserve and MRT.SoftReserve:GetHistory() or {}
    if #history == 0 then showHint(srhChild, L["sr_history_empty"]); return end
    hideHint(srhChild)

    srhChild:SetWidth(srhChild:GetParent():GetWidth())
    local y = -2
    for i = #history, 1, -1 do
        local entry = history[i]
        local raid = entry.raidID and ns.RaidsByID[entry.raidID]
        local raidName = raid and ns.RaidName(raid) or (entry.raidID or "?")

        local s = acquireSRHSection()
        s.frame:ClearAllPoints()
        s.frame:SetParent(srhChild)
        s.frame:SetPoint("TOPLEFT", srhChild, "TOPLEFT", 0, y)
        s.frame:SetPoint("TOPRIGHT", srhChild, "TOPRIGHT", 0, y)
        s:SetTitle(string.format("%s — %s", date("%Y-%m-%d %H:%M", entry.timestamp), raidName))

        local players = {}
        for p in pairs(entry.reserves or {}) do table.insert(players, p) end
        table.sort(players)
        s:SetMeta(string.format("%d %s", #players, players[1] and "" or L["sr_history_no_reserves"]))

        s.onToggle = function() UI:Refresh() end

        local contentH = 6
        if s.expanded then
            local lineFSs = s.content.lineFSs or {}
            s.content.lineFSs = lineFSs
            for _, fs in ipairs(lineFSs) do fs:Hide() end

            local lineY = -6
            if #players == 0 then
                local fs = lineFSs[1] or s.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                lineFSs[1] = fs
                fs:Show()
                fs:SetPoint("TOPLEFT", s.content, "TOPLEFT", 14, lineY)
                fs:SetText(L["sr_history_no_reserves"])
                contentH = contentH + 18
            else
                for idx, player in ipairs(players) do
                    local items = entry.reserves[player] or {}
                    local linkParts = {}
                    for _, itemID in ipairs(items) do
                        local _, lk = GetItemInfo(itemID)
                        table.insert(linkParts, lk or ("item:" .. itemID))
                    end
                    local fs = lineFSs[idx] or s.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    lineFSs[idx] = fs
                    fs:Show()
                    fs:SetPoint("TOPLEFT", s.content, "TOPLEFT", 14, lineY)
                    fs:SetText(string.format("|cffffd200%s|r — %s", player, table.concat(linkParts, ", ")))
                    lineY = lineY - 16
                    contentH = contentH + 16
                end
            end
            contentH = contentH + 6
        end
        s:Layout(contentH)
        y = y - s.frame:GetHeight() - 4
    end
    srhChild:SetHeight(math.max(60, -y + 4))
end

function UI:HideSRHistoryPanel() if srhPanel then srhPanel:Hide() end end

-- ============================================================
-- Consumables tab
-- ============================================================

local COLUMNS = { "flask", "battle", "guard", "food", "scroll", "oil", "pot", "drums" }
local COL_LABELS = {
    flask = "Fla", battle = "Bat", guard = "Grd", food = "Fud",
    scroll = "Scr", oil = "Oil",   pot = "Pot",   drums = "Drm",
}

local consPanel, consChild
local consRowPool = {}
local consHeader  = nil
local consRefreshBtn = nil

local function createConsRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, consChild, "BackdropTemplate")
    Skin:ApplyDark(r.frame, Skin.color.bgAlt, Skin.color.border)
    r.frame:SetHeight(24)

    r.nameFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameFS:SetPoint("LEFT", r.frame, "LEFT", 8, 0)
    r.nameFS:SetWidth(130)
    r.nameFS:SetJustifyH("LEFT")

    r.cells = {}
    local x = 142
    for i, col in ipairs(COLUMNS) do
        local fs = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", r.frame, "LEFT", x, 0)
        fs:SetWidth(38)
        fs:SetJustifyH("CENTER")
        r.cells[col] = fs
        x = x + 42
    end
    return r
end

local function acquireConsRow()
    for _, r in ipairs(consRowPool) do
        if not r._inUse then r._inUse = true; r.frame:Show(); return r end
    end
    local r = createConsRow()
    r._inUse = true
    table.insert(consRowPool, r)
    return r
end

local function releaseConsRows()
    for _, r in ipairs(consRowPool) do r._inUse = false; r.frame:Hide() end
end

function UI:BuildConsumablesTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not consPanel then
        consPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        Skin:ApplyDark(consPanel)
        consPanel:SetAllPoints(parent)

        consRefreshBtn = Skin:CreateButton(consPanel, L["cons_refresh"], 160, 22)
        consRefreshBtn:SetPoint("TOPLEFT", consPanel, "TOPLEFT", 6, -6)
        consRefreshBtn:SetScript("OnClick", function()
            MRT.Consumables:RefreshRoster(); UI:Refresh()
        end)

        consHeader = CreateFrame("Frame", nil, consPanel, "BackdropTemplate")
        Skin:ApplyDark(consHeader, Skin.color.bg, Skin.color.borderLight)
        consHeader:SetPoint("TOPLEFT", consRefreshBtn, "BOTTOMLEFT", 0, -8)
        consHeader:SetPoint("RIGHT", consPanel, "RIGHT", -28, 0)
        consHeader:SetHeight(20)
        local fs = consHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", consHeader, "LEFT", 8, 0)
        fs:SetWidth(130)
        fs:SetJustifyH("LEFT")
        fs:SetText(L["cons_player"])
        fs:SetTextColor(unpack(Skin.color.accent))
        local x = 142
        for _, col in ipairs(COLUMNS) do
            local cfs = consHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cfs:SetPoint("LEFT", consHeader, "LEFT", x, 0)
            cfs:SetWidth(38)
            cfs:SetJustifyH("CENTER")
            cfs:SetText(COL_LABELS[col])
            cfs:SetTextColor(unpack(Skin.color.textDim))
            x = x + 42
        end

        local scroll = CreateFrame("ScrollFrame", nil, consPanel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", consHeader, "BOTTOMLEFT", 0, -2)
        scroll:SetPoint("BOTTOMRIGHT", consPanel, "BOTTOMRIGHT", -28, 6)
        consChild = CreateFrame("Frame", nil, scroll)
        consChild:SetSize(1, 1)
        scroll:SetScrollChild(consChild)
        consPanel._scroll = scroll
    else
        consPanel:SetParent(parent); consPanel:ClearAllPoints()
        consPanel:SetAllPoints(parent); consPanel:Show()
    end

    releaseConsRows()
    MRT.Consumables:RefreshRoster()
    local roster = MRT.Consumables:GetRoster()

    local players = {}
    for n in pairs(roster) do table.insert(players, n) end
    table.sort(players)

    consChild:SetWidth(consPanel._scroll:GetWidth())
    if #players == 0 then
        showHint(consChild, L["cons_no_raid"]); return
    end
    hideHint(consChild)

    local y = -2
    for _, name in ipairs(players) do
        local data = roster[name]
        local r = acquireConsRow()
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", consChild, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", consChild, "TOPRIGHT", -4, y)

        r.nameFS:SetText(Skin:ColorName(name))
        for _, col in ipairs(COLUMNS) do
            if data.buffs[col] then
                r.cells[col]:SetText("|cff00ff00ok|r")
            else
                r.cells[col]:SetText("|cff666666-|r")
            end
        end
        y = y - 26
    end
    consChild:SetHeight(math.max(60, -y + 4))
end

function UI:HideConsumablesPanel() if consPanel then consPanel:Hide() end end
