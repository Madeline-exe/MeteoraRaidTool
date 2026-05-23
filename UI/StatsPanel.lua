local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Stats tab: per-player loot counts with period / raid filters
-- plus "Copy" button that opens UI:ShowExport with TSV text.
-- ============================================================

local panel, scroll, child
local periodDD, raidDD, copyBtn
local headerFrame
local rowPool = {}

local periodSec = nil       -- nil = all-time
local raidFilter = nil      -- nil/"all" = every raid

local function stripColor(text)
    if not text then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function plainLink(link, itemID)
    if not link then return "item:" .. (itemID or "?") end
    -- "|cff...|Hitem:30663:..|h[Name]|h|r" → "Name"
    local name = link:match("%[(.-)%]")
    return name or stripColor(link)
end

local function aggregate()
    local stats = {}
    local now = time()
    for _, e in ipairs(MRT.db.global.lootHistory or {}) do
        local ts = e.timestamp or 0
        local periodOK = not periodSec or (now - ts) <= periodSec
        local raidOK   = not raidFilter or raidFilter == "all" or e.raid == raidFilter
        if periodOK and raidOK and e.winner then
            local s = stats[e.winner] or { count = 0, lastTime = 0 }
            s.count = s.count + 1
            if ts > s.lastTime then
                s.lastTime = ts
                s.lastLink = e.link or ("item:" .. (e.itemID or "?"))
            end
            stats[e.winner] = s
        end
    end
    local list = {}
    for player, s in pairs(stats) do
        list[#list + 1] = {
            player = player, count = s.count,
            lastLink = s.lastLink, lastTime = s.lastTime,
        }
    end
    table.sort(list, function(a, b)
        if a.count == b.count then return a.player < b.player end
        return a.count > b.count
    end)
    return list
end

-- ============================================================
-- Row pooling
-- ============================================================

local function createRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    Skin:ApplyDark(r.frame, Skin.color.bgAlt, Skin.color.border)
    r.frame:SetHeight(26)

    r.nameFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameFS:SetPoint("LEFT", r.frame, "LEFT", 8, 0)
    r.nameFS:SetWidth(160)
    r.nameFS:SetJustifyH("LEFT")

    r.countFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.countFS:SetPoint("LEFT", r.frame, "LEFT", 170, 0)
    r.countFS:SetWidth(60)
    r.countFS:SetJustifyH("CENTER")
    r.countFS:SetTextColor(unpack(Skin.color.accent))

    r.lastFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.lastFS:SetPoint("LEFT", r.frame, "LEFT", 240, 0)
    r.lastFS:SetWidth(280)
    r.lastFS:SetJustifyH("LEFT")

    r.dateFS = r.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.dateFS:SetPoint("RIGHT", r.frame, "RIGHT", -8, 0)
    r.dateFS:SetWidth(130)
    r.dateFS:SetJustifyH("RIGHT")
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

-- ============================================================
-- Dropdowns
-- ============================================================

local PERIOD_OPTIONS = {
    { key = "all",   label = L["stats_period_all"]   or "All time",  sec = nil },
    { key = "30",    label = L["stats_period_30"]    or "Last 30d",  sec = 30*86400 },
    { key = "7",     label = L["stats_period_7"]     or "Last 7d",   sec = 7*86400 },
}

local function initPeriodDD()
    UIDropDownMenu_Initialize(periodDD, function(_, level)
        for _, opt in ipairs(PERIOD_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.checked = (opt.sec == periodSec)
            info.func = function()
                periodSec = opt.sec
                UIDropDownMenu_SetText(periodDD, opt.label)
                UI:Refresh()
            end
            UIDropDownMenu_AddButton(info, level or 1)
        end
    end)
    UIDropDownMenu_SetText(periodDD, PERIOD_OPTIONS[1].label)
end

local function initRaidDD()
    UIDropDownMenu_Initialize(raidDD, function(_, level)
        local infoAll = UIDropDownMenu_CreateInfo()
        infoAll.text = L["stats_raid_all"] or "All raids"
        infoAll.checked = (not raidFilter or raidFilter == "all")
        infoAll.func = function()
            raidFilter = nil
            UIDropDownMenu_SetText(raidDD, infoAll.text)
            UI:Refresh()
        end
        UIDropDownMenu_AddButton(infoAll, level or 1)
        for _, raid in ipairs(ns.Raids) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = ns.RaidName(raid)
            info.checked = (raidFilter == raid.id)
            info.func = function()
                raidFilter = raid.id
                UIDropDownMenu_SetText(raidDD, info.text)
                UI:Refresh()
            end
            UIDropDownMenu_AddButton(info, level or 1)
        end
    end)
    UIDropDownMenu_SetText(raidDD, L["stats_raid_all"] or "All raids")
end

-- ============================================================
-- Build & refresh
-- ============================================================

local function build(parent)
    panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(panel)
    panel:SetAllPoints(parent)

    periodDD = CreateFrame("Frame", "MRTStatsPeriodDD", panel, "UIDropDownMenuTemplate")
    periodDD:SetPoint("TOPLEFT", panel, "TOPLEFT", -8, -4)
    UIDropDownMenu_SetWidth(periodDD, 140)
    initPeriodDD()

    raidDD = CreateFrame("Frame", "MRTStatsRaidDD", panel, "UIDropDownMenuTemplate")
    raidDD:SetPoint("LEFT", periodDD, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(raidDD, 180)
    initRaidDD()

    copyBtn = Skin:CreateButton(panel, L["btn_copy_export"], 130, 22)
    copyBtn:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
    copyBtn:SetPoint("TOP", panel, "TOP", 0, -8)
    copyBtn:SetScript("OnClick", function() UI:ExportStats() end)

    headerFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    Skin:ApplyDark(headerFrame, Skin.color.bg, Skin.color.borderLight)
    headerFrame:SetPoint("TOPLEFT", periodDD, "BOTTOMLEFT", 16, -2)
    headerFrame:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
    headerFrame:SetHeight(20)
    local function hdr(text, anchorX, w)
        local fs = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", headerFrame, "LEFT", anchorX, 0)
        fs:SetWidth(w); fs:SetJustifyH("LEFT")
        fs:SetTextColor(unpack(Skin.color.accent))
        fs:SetText(text)
    end
    hdr(L["stats_col_player"],   8,   160)
    hdr(L["stats_col_count"],    170, 60)
    hdr(L["stats_col_last"],     240, 280)
    local dateHdr = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dateHdr:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    dateHdr:SetWidth(130); dateHdr:SetJustifyH("RIGHT")
    dateHdr:SetTextColor(unpack(Skin.color.accent))
    dateHdr:SetText(L["stats_col_date"])

    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
end

local function refresh()
    if not panel then return end
    releaseRows()
    local list = aggregate()
    child:SetWidth(scroll:GetWidth())

    if #list == 0 then
        local fs = child.hint or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hint = fs
        fs:Show()
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        fs:SetText(L["stats_empty"])
        child:SetHeight(60)
        return
    end
    if child.hint then child.hint:Hide() end

    local y = -2
    for _, entry in ipairs(list) do
        local r = acquireRow()
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, y)
        r.nameFS:SetText(Skin:ColorName(entry.player))
        r.countFS:SetText(tostring(entry.count))
        r.lastFS:SetText(entry.lastLink or "")
        r.dateFS:SetText(entry.lastTime > 0 and date("%Y-%m-%d %H:%M", entry.lastTime) or "")
        y = y - 28
    end
    child:SetHeight(math.max(60, -y + 4))
end

function UI:BuildStatsTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not panel then build(parent)
    else
        panel:SetParent(parent); panel:ClearAllPoints()
        panel:SetAllPoints(parent); panel:Show()
    end
    refresh()
end

function UI:HideStatsPanel() if panel then panel:Hide() end end

-- ============================================================
-- Export helpers
-- ============================================================

function UI:ExportStats()
    local list = aggregate()
    local lines = { L["stats_col_player"] .. "\t" .. L["stats_col_count"]
                    .. "\t" .. L["stats_col_last"] .. "\t" .. L["stats_col_date"] }
    for _, e in ipairs(list) do
        local link = plainLink(e.lastLink)
        local dt = e.lastTime > 0 and date("%Y-%m-%d %H:%M", e.lastTime) or ""
        lines[#lines + 1] = string.format("%s\t%d\t%s\t%s",
            e.player, e.count, link, dt)
    end
    self:ShowExport(L["export_title_stats"], table.concat(lines, "\n"))
end

function UI:ExportLootHistory()
    local hist = MRT.db.global.lootHistory or {}
    local lines = { "Date\tItem\tWinner\tRaid" }
    for i = #hist, 1, -1 do
        local e = hist[i]
        local link = plainLink(e.link, e.itemID)
        local raid = e.raid and ns.RaidsByID[e.raid]
        local raidName = raid and ns.RaidName(raid) or (e.raid or "")
        local dt = e.timestamp and date("%Y-%m-%d %H:%M", e.timestamp) or ""
        lines[#lines + 1] = string.format("%s\t%s\t%s\t%s",
            dt, link, e.winner or "?", raidName)
    end
    self:ShowExport(L["export_title_loot"], table.concat(lines, "\n"))
end
