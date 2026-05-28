local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Wishlist tab: each player edits their own list; RL can browse
-- anyone's via dropdown. Add via item link / itemID.
-- ============================================================

local panel, topBar, viewerDD, addInput, addBtn, clearBtn, scroll, child
local headerFS, counterFS
local rowPool = {}
local viewedPlayer = nil  -- nil = self

local function me() return UnitName("player") end

local function activePlayer()
    return viewedPlayer or me()
end

local function isOwnList()
    return activePlayer() == me()
end

-- ============================================================
-- Rows
-- ============================================================

local function createRow()
    local r = {}
    r.frame = CreateFrame("Frame", nil, child, "BackdropTemplate")
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
    r.nameFS:SetPoint("RIGHT", r.frame, "RIGHT", -40, 0)
    r.nameFS:SetJustifyH("LEFT")

    r.rmBtn = Skin:CreateButton(r.frame, "X", 28, 22)
    r.rmBtn:SetPoint("RIGHT", r.frame, "RIGHT", -4, 0)
    r.rmBtn:GetFontString():SetTextColor(unpack(Skin.color.danger))
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
-- Player viewer dropdown (RL-only convenience)
-- ============================================================

local function initViewerDD()
    UIDropDownMenu_Initialize(viewerDD, function(_, level)
        local mine = me()
        local addEntry = function(name)
            local info = UIDropDownMenu_CreateInfo()
            info.text = (name == mine) and ("> " .. name) or name
            info.checked = (activePlayer() == name)
            info.func = function()
                viewedPlayer = (name == mine) and nil or name
                UIDropDownMenu_SetText(viewerDD, name)
                UI:Refresh()
            end
            UIDropDownMenu_AddButton(info, level or 1)
        end
        addEntry(mine)
        local seen = { [mine] = true }
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local n = GetRaidRosterInfo(i)
                if n then
                    local short = Ambiguate(n, "short")
                    if not seen[short] then seen[short] = true; addEntry(short) end
                end
            end
        end
        -- Out of raid we have no roster context, so just show self. Leftover
        -- wishlists from previous raids stay in the DB but aren't surfaced.
    end)
    UIDropDownMenu_SetText(viewerDD, activePlayer())
end

local function parseItemID(text)
    if not text then return nil end
    text = text:trim()
    if text == "" then return nil end
    local id = text:match("item:(%d+)")
    if id then return tonumber(id) end
    return tonumber(text)
end

-- ============================================================
-- Build / refresh
-- ============================================================

local function build(parent)
    panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(panel)
    panel:SetAllPoints(parent)

    topBar = CreateFrame("Frame", nil, panel)
    topBar:SetPoint("TOPLEFT",  panel, "TOPLEFT", 6, -6)
    topBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    topBar:SetHeight(28)

    viewerDD = CreateFrame("Frame", "MRTWishlistViewerDD", topBar, "UIDropDownMenuTemplate")
    viewerDD:SetPoint("LEFT", topBar, "LEFT", -12, 0)
    UIDropDownMenu_SetWidth(viewerDD, 160)

    addInput = CreateFrame("EditBox", nil, topBar, "InputBoxTemplate")
    addInput:SetSize(260, 22)
    addInput:SetAutoFocus(false)
    addInput:SetPoint("LEFT", viewerDD, "RIGHT", 12, 2)
    addInput:SetFontObject("GameFontHighlight")

    addBtn = Skin:CreateButton(topBar, L["btn_add_item"], 90, 22)
    addBtn:SetPoint("LEFT", addInput, "RIGHT", 6, 0)

    local function commit()
        local id = parseItemID(addInput:GetText())
        if not id then MRT:Print(L["loot_bad_item"]); return end
        local ok, reason = MRT.Wishlist:Add(id)
        if ok then
            addInput:SetText(""); UI:Refresh()
        elseif reason == "max" then
            MRT:Print(L["wish_max"]:format(30))
        elseif reason == "already" then
            -- silent
        end
    end
    addInput:SetScript("OnEnterPressed", commit)
    addBtn:SetScript("OnClick", commit)

    clearBtn = Skin:CreateButton(topBar, L["btn_clear_all"], 120, 22)
    clearBtn:SetPoint("RIGHT", topBar, "RIGHT", 0, 0)
    clearBtn:SetScript("OnClick", function()
        StaticPopupDialogs = StaticPopupDialogs or {}
        StaticPopupDialogs["MRT_CLEAR_WISH"] = {
            text = L["popup_clear_wish"], button1 = YES, button2 = NO,
            OnAccept = function() MRT.Wishlist:ClearMine(); UI:Refresh() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MRT_CLEAR_WISH")
    end)

    headerFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerFS:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 10, -6)
    headerFS:SetTextColor(unpack(Skin.color.accent))

    counterFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    counterFS:SetPoint("TOPRIGHT", topBar, "BOTTOMRIGHT", -10, -6)

    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerFS, "BOTTOMLEFT", -4, -6)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
end

local function refresh()
    if not panel then return end
    releaseRows()

    -- Drop a stale "view as someone else" selection if that someone has left
    -- the raid. Without this the dropdown text keeps their name but the
    -- dropdown menu won't list them.
    if viewedPlayer and IsInRaid() then
        local roster = ns.GetRaidRoster()
        if not roster[Ambiguate(viewedPlayer, "short")] then
            viewedPlayer = nil
        end
    end

    initViewerDD()

    local player = activePlayer()
    local list = MRT.Wishlist:GetFor(player)
    local own = isOwnList()

    headerFS:SetText(string.format("%s: %s",
        L["wish_header"] or "Wishlist", Skin:ColorName(player)))
    counterFS:SetText(string.format("|cffffd200%d|r / 30", #list))

    addInput:SetShown(own)
    addBtn:SetShown(own)
    clearBtn:SetShown(own)

    child:SetWidth(scroll:GetWidth())

    if #list == 0 then
        local fs = child.hint or child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        child.hint = fs
        fs:Show()
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
        fs:SetText(own and (L["wish_empty_self"] or "Empty. Paste an item link or itemID above.")
                       or (L["wish_empty_other"] or "This player hasn't set a wishlist."))
        child:SetHeight(60)
        return
    end
    if child.hint then child.hint:Hide() end

    local y = -2
    for _, itemID in ipairs(list) do
        local r = acquireRow()
        r.itemID = itemID
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y)
        r.frame:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, y)

        local _, link, _, _, _, _, _, _, _, iconTex = GetItemInfo(itemID)
        link = link or ("item:" .. itemID)
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
        r.iconBtn.icon:SetTexture(iconTex)
        r.nameFS:SetText(link)

        if own then
            r.rmBtn:Show()
            r.rmBtn:SetScript("OnClick", function()
                MRT.Wishlist:Remove(itemID); UI:Refresh()
            end)
        else
            r.rmBtn:Hide()
        end
        y = y - 32
    end
    child:SetHeight(math.max(60, -y + 4))
end

function UI:BuildWishlistTab(container)
    local parent = container.content or container.frame
    if not parent then return end
    if not panel then build(parent)
    else
        panel:SetParent(parent); panel:ClearAllPoints()
        panel:SetAllPoints(parent); panel:Show()
    end
    refresh()
end

function UI:HideWishlistPanel() if panel then panel:Hide() end end
