local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI
local Skin = ns.Skin

-- ============================================================
-- Custom main window: replaces AceGUI Frame + TabGroup entirely.
-- Loaded last in the .toc so it overrides UI:Build/Toggle/Refresh/OpenTab
-- from UI/MainFrame.lua.
-- ============================================================

local main             -- root Frame
local titleBar         -- title bar Frame
local titleFS          -- title text
local closeBtn         -- × button
local resizer          -- bottom-right grip
local tabBar           -- container Frame for tab buttons
local contentArea      -- Frame where active panel is parented
local statusBar        -- status row (status text + version)
local statusFS, versionFS

local tabButtons = {}  -- { value → Button }
local currentTab = "reserves"

local MIN_WIDTH, MIN_HEIGHT = 640, 380

-- Tab definition (order matters)
local TABS = {
    { value = "reserves",    labelKey = "tab_reserves"    },
    { value = "distribute",  labelKey = "tab_distribute"  },
    { value = "consumables", labelKey = "tab_consumables" },
    { value = "status",      labelKey = "tab_status"      },
    { value = "history",     labelKey = "tab_history"     },
    { value = "sr_history",  labelKey = "tab_sr_history"  },
}

-- ============================================================
-- Helpers
-- ============================================================

local function setTabActive(button, isActive)
    if isActive then
        button:SetBackdropColor(Skin.color.bgActive[1], Skin.color.bgActive[2],
                                Skin.color.bgActive[3], Skin.color.bgActive[4])
        button:SetBackdropBorderColor(Skin.color.accent[1], Skin.color.accent[2],
                                      Skin.color.accent[3], Skin.color.accent[4])
        local fs = button:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.accent)) end
    else
        button:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                                Skin.color.bgAlt[3], Skin.color.bgAlt[4])
        button:SetBackdropBorderColor(Skin.color.border[1], Skin.color.border[2],
                                      Skin.color.border[3], Skin.color.border[4])
        local fs = button:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.textFg)) end
    end
end

local function applyTitle()
    local suffix = (MRT.TestMode and MRT.TestMode:IsOn())
        and ("   |cffffaa00[" .. (L["test_badge"] or "TEST") .. "]|r") or ""
    titleFS:SetText("Meteora Raid Tool" .. suffix)
end

local function savePosition()
    if not main then return end
    local point, _, relPoint, x, y = main:GetPoint(1)
    MRT.db.profile.ui = MRT.db.profile.ui or {}
    MRT.db.profile.ui.mainFramePoint = { point, "UIParent", relPoint, x, y }
    MRT.db.profile.ui.width  = main:GetWidth()
    MRT.db.profile.ui.height = main:GetHeight()
end

local function restorePosition()
    local ui = MRT.db.profile.ui or {}
    local p = ui.mainFramePoint
    main:ClearAllPoints()
    if p and p[1] then
        main:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
    else
        main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    main:SetSize(ui.width or 760, ui.height or 540)
end

-- ============================================================
-- Build
-- ============================================================

local function build()
    if main then return end

    main = CreateFrame("Frame", "MeteoraRaidToolMain", UIParent, "BackdropTemplate")
    Skin:ApplyDark(main)
    main:SetSize(760, 540)
    main:SetMovable(true)
    main:SetResizable(true)
    if main.SetMinResize then main:SetMinResize(MIN_WIDTH, MIN_HEIGHT) end
    main:SetClampedToScreen(true)
    main:SetFrameStrata("MEDIUM")
    main:EnableMouse(true)
    main:Hide()
    tinsert(UISpecialFrames, "MeteoraRaidToolMain") -- Esc closes

    main:SetScript("OnHide", savePosition)

    -- Title bar
    titleBar = CreateFrame("Frame", nil, main, "BackdropTemplate")
    Skin:ApplyDark(titleBar, Skin.color.bgAlt, Skin.color.borderLight)
    titleBar:SetPoint("TOPLEFT",  main, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() main:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        main:StopMovingOrSizing(); savePosition()
    end)

    titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleFS:SetTextColor(unpack(Skin.color.accent))
    applyTitle()

    closeBtn = Skin:CreateButton(titleBar, "×", 24, 22)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    local cfs = closeBtn:GetFontString()
    if cfs then cfs:SetTextColor(unpack(Skin.color.danger)) end
    closeBtn:SetScript("OnClick", function() main:Hide() end)

    -- Tab bar
    tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  4, -4)
    tabBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -4, -4)
    tabBar:SetHeight(24)

    local x = 0
    for _, tab in ipairs(TABS) do
        local label = L[tab.labelKey] or tab.value
        local btn = Skin:CreateButton(tabBar, label, 110, 22)
        btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
        btn:SetScript("OnClick", function() UI:OpenTab(tab.value) end)
        tabButtons[tab.value] = btn
        x = x + 112
    end

    -- Content area (where active panel lives)
    contentArea = CreateFrame("Frame", nil, main, "BackdropTemplate")
    Skin:ApplyDark(contentArea, Skin.color.bg, Skin.color.border)
    contentArea:SetPoint("TOPLEFT",     tabBar, "BOTTOMLEFT",  0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", main,   "BOTTOMRIGHT", -4, 20)

    -- Status bar
    statusBar = CreateFrame("Frame", nil, main)
    statusBar:SetPoint("BOTTOMLEFT",  main, "BOTTOMLEFT",  4, 2)
    statusBar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -22, 2)
    statusBar:SetHeight(16)

    statusFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusFS:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
    statusFS:SetText(L["status_ready"] or "")

    versionFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionFS:SetPoint("RIGHT", statusBar, "RIGHT", 0, 0)
    versionFS:SetText("v" .. (MRT.version or "?"))

    -- Resize grip
    resizer = CreateFrame("Button", nil, main)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function() main:StartSizing("BOTTOMRIGHT") end)
    resizer:SetScript("OnMouseUp",   function() main:StopMovingOrSizing(); savePosition() end)

    restorePosition()
end

-- ============================================================
-- Tab switching and refresh
-- ============================================================

local function showTab(tabValue)
    if not main then build() end
    currentTab = tabValue

    -- Hide all panels first
    if UI.HideDistributePanel  then UI:HideDistributePanel()  end
    if UI.HideReservesPanel    then UI:HideReservesPanel()    end
    if UI.HideStatusPanel      then UI:HideStatusPanel()      end
    if UI.HideHistoryPanel     then UI:HideHistoryPanel()     end
    if UI.HideSRHistoryPanel   then UI:HideSRHistoryPanel()   end
    if UI.HideConsumablesPanel then UI:HideConsumablesPanel() end

    -- Update tab button states
    for value, btn in pairs(tabButtons) do
        setTabActive(btn, value == tabValue)
    end

    -- Call the appropriate Build*Tab with a container shim. All panels
    -- look for container.content or container.frame, so giving them
    -- contentArea as .content works identically.
    local container = { content = contentArea, frame = contentArea }
    local ok, err = pcall(function()
        if tabValue == "reserves" then       UI:BuildReservesTab(container)
        elseif tabValue == "distribute" then  UI:BuildDistributeTab(container)
        elseif tabValue == "consumables" then UI:BuildConsumablesTab(container)
        elseif tabValue == "status" then      UI:BuildStatusTab(container)
        elseif tabValue == "history" then     UI:BuildHistoryTab(container)
        elseif tabValue == "sr_history" then  UI:BuildSRHistoryTab(container)
        end
    end)
    if not ok then
        MRT:Print("|cffff5555[Tab " .. tabValue .. "]|r " .. tostring(err))
    end
end

-- ============================================================
-- UI module overrides
-- ============================================================

function UI:Build()
    build()
    return main
end

function UI:Toggle()
    build()
    if main:IsShown() then
        main:Hide()
    else
        main:Show()
        showTab(currentTab)
    end
end

function UI:Refresh()
    if main and main:IsShown() then
        showTab(currentTab)
    end
end

function UI:RefreshLater()
    if main and main:IsShown() then
        self:Refresh()
    end
end

function UI:OpenTab(tabValue)
    build()
    if not main:IsShown() then main:Show() end
    showTab(tabValue)
end

function UI:OnTestToggled()
    if main then applyTitle() end
    self:RefreshLater()
end
