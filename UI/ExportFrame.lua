local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Modal-style export popup with a multi-line EditBox the user
-- can Ctrl+A / Ctrl+C to grab a TSV / markdown block to paste
-- into Discord. WoW has no clipboard API, so this is the
-- best we can do.
-- ============================================================

local frame, edit, scroll, titleFS

local function build()
    if frame then return end

    frame = CreateFrame("Frame", "MeteoraExportFrame", UIParent, "BackdropTemplate")
    Skin:ApplyDark(frame)
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    tinsert(UISpecialFrames, "MeteoraExportFrame")

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
    titleFS:SetText(L["export_title"])

    local closeBtn = Skin:CreateButton(titleBar, "X", 24, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:GetFontString():SetTextColor(unpack(Skin.color.danger))
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -4)
    hint:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -8, -4)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["export_hint"])

    scroll = CreateFrame("ScrollFrame", "MeteoraExportScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)

    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetAutoFocus(false)
    edit:SetWidth(520)
    edit:SetScript("OnEscapePressed", function(e) e:ClearFocus(); frame:Hide() end)
    scroll:SetScrollChild(edit)
end

function UI:ShowExport(title, text)
    build()
    titleFS:SetText(title or L["export_title"])
    edit:SetText(text or "")
    -- Reset scroll to top.
    if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
    frame:Show()
    -- Auto-select all so user just hits Ctrl+C
    C_Timer.After(0.05, function()
        edit:SetFocus()
        edit:HighlightText()
    end)
end
