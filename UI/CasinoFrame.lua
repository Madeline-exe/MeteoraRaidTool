local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local casinoFrame

function UI:BuildCasinoTab(container)
    local intro = AceGUI:Create("Label")
    intro:SetFullWidth(true)
    intro:SetText(L["casino_intro"])
    container:AddChild(intro)

    local prizeBox = AceGUI:Create("EditBox")
    prizeBox:SetLabel(L["casino_prize"])
    prizeBox:SetWidth(380)
    container:AddChild(prizeBox)

    local stakesCB = AceGUI:Create("CheckBox")
    stakesCB:SetLabel(L["casino_enable_stakes"])
    stakesCB:SetValue(MRT.db.profile.casino.enableStakes)
    stakesCB:SetCallback("OnValueChanged", function(_, _, val)
        MRT.db.profile.casino.enableStakes = val
    end)
    container:AddChild(stakesCB)

    local unitDD = AceGUI:Create("Dropdown")
    unitDD:SetLabel(L["casino_unit"])
    unitDD:SetList({ DKP = "DKP", EPGP = "EP/GP", Gold = "Gold" })
    unitDD:SetValue(MRT.db.profile.casino.stakeUnit)
    unitDD:SetWidth(120)
    unitDD:SetCallback("OnValueChanged", function(_, _, val)
        MRT.db.profile.casino.stakeUnit = val
    end)
    container:AddChild(unitDD)

    local openBtn = AceGUI:Create("Button")
    openBtn:SetText(L["casino_open"])
    openBtn:SetWidth(140)
    openBtn:SetCallback("OnClick", function()
        MRT.Casino:OpenRound(prizeBox:GetText())
    end)
    container:AddChild(openBtn)

    local closeBtn = AceGUI:Create("Button")
    closeBtn:SetText(L["casino_close"])
    closeBtn:SetWidth(140)
    closeBtn:SetCallback("OnClick", function()
        MRT.Casino:CloseRound()
    end)
    container:AddChild(closeBtn)

    local historyHeader = AceGUI:Create("Heading")
    historyHeader:SetText(L["casino_history"])
    historyHeader:SetFullWidth(true)
    container:AddChild(historyHeader)

    local list = AceGUI:Create("ScrollFrame")
    list:SetLayout("List")
    list:SetFullWidth(true)
    list:SetFullHeight(true)
    container:AddChild(list)

    local hist = MRT.db.global.casinoHistory or {}
    for i = #hist, math.max(1, #hist - 30), -1 do
        local entry = hist[i]
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        lbl:SetText(string.format("%s — %s → |cff00ff00%s|r (%s)",
            date("%Y-%m-%d %H:%M", entry.timestamp),
            entry.prize or "?",
            entry.winner or "no winner",
            entry.roll and ("roll " .. entry.roll) or ""))
        list:AddChild(lbl)
    end
end

function UI:OpenCasinoRound(round)
    if casinoFrame then casinoFrame:Release() end
    casinoFrame = AceGUI:Create("Frame")
    casinoFrame:SetTitle(L["casino_round_title"]:format(round.prize))
    casinoFrame:SetStatusText(round.stakes and L["casino_stakes_on"] or L["casino_stakes_off"])
    casinoFrame:SetLayout("Flow")
    casinoFrame:SetWidth(440)
    casinoFrame:SetHeight(380)
    casinoFrame:SetCallback("OnClose", function(w) w:Hide(); casinoFrame = nil end)

    local rollBtn = AceGUI:Create("Button")
    rollBtn:SetText("/roll 1-100")
    rollBtn:SetWidth(140)
    rollBtn:SetCallback("OnClick", function()
        RandomRoll(1, 100)
    end)
    casinoFrame:AddChild(rollBtn)

    if round.stakes then
        local betBox = AceGUI:Create("EditBox")
        betBox:SetLabel(L["casino_your_bet"]:format(round.stakeUnit))
        betBox:SetWidth(120)
        casinoFrame:AddChild(betBox)

        local placeBtn = AceGUI:Create("Button")
        placeBtn:SetText(L["casino_place_bet"])
        placeBtn:SetWidth(120)
        placeBtn:SetCallback("OnClick", function()
            local n = tonumber(betBox:GetText())
            if n then MRT.Casino:PlaceBet(n) end
        end)
        casinoFrame:AddChild(placeBtn)
    end

    local rollsList = AceGUI:Create("ScrollFrame")
    rollsList:SetLayout("List")
    rollsList:SetFullWidth(true)
    rollsList:SetHeight(220)
    casinoFrame:AddChild(rollsList)
    self._casinoRolls = rollsList

    self:RefreshCasino(round)
end

function UI:RefreshCasino(round)
    if not self._casinoRolls then return end
    self._casinoRolls:ReleaseChildren()
    local sorted = {}
    for player, roll in pairs(round.rolls) do table.insert(sorted, { p = player, r = roll }) end
    table.sort(sorted, function(a, b) return a.r > b.r end)
    for _, entry in ipairs(sorted) do
        local lbl = AceGUI:Create("Label")
        lbl:SetFullWidth(true)
        local bet = round.bets[entry.p]
        lbl:SetText(string.format("|cffffd200%3d|r  %s%s", entry.r, entry.p,
            bet and (" |cff888888(bet " .. bet .. " " .. (round.stakeUnit or "") .. ")|r") or ""))
        self._casinoRolls:AddChild(lbl)
    end
end

function UI:CloseCasinoRound()
    if casinoFrame then casinoFrame:Release(); casinoFrame = nil end
end

function UI:OpenCasino()
    self:Toggle()
end
