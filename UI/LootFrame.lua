local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local awardFrame

local function raidRosterList()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then list[name] = name end
        end
    else
        list[UnitName("player")] = UnitName("player")
        for i = 1, (GetNumGroupMembers() or 0) - 1 do
            local name = UnitName("party" .. i)
            if name then list[name] = name end
        end
    end
    return list
end

function UI:OpenAwardWindow(items)
    if awardFrame then awardFrame:Release() end

    awardFrame = AceGUI:Create("Frame")
    awardFrame:SetTitle(L["award_title"])
    awardFrame:SetStatusText(L["award_status"])
    awardFrame:SetLayout("Flow")
    awardFrame:SetWidth(560)
    awardFrame:SetHeight(420)
    awardFrame:SetCallback("OnClose", function(w) w:Hide(); awardFrame = nil end)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    awardFrame:AddChild(scroll)

    for _, item in ipairs(items) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(item.link or ("item:" .. item.itemID))
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        scroll:AddChild(group)

        local reservers = MRT.SoftReserve:GetReservesForItem(item.itemID)
        local srLabel = AceGUI:Create("Label")
        srLabel:SetFullWidth(true)
        if #reservers > 0 then
            srLabel:SetText("|cffff8800" .. L["award_sr"] .. ":|r " .. table.concat(reservers, ", "))
        else
            srLabel:SetText("|cff888888" .. L["award_no_sr"] .. "|r")
        end
        group:AddChild(srLabel)

        local dd = AceGUI:Create("Dropdown")
        dd:SetLabel(L["award_to"])
        local roster = raidRosterList()
        dd:SetList(roster)
        if reservers[1] then dd:SetValue(reservers[1]) end
        dd:SetWidth(220)
        group:AddChild(dd)

        local noteBox = AceGUI:Create("EditBox")
        noteBox:SetLabel(L["award_note"])
        noteBox:SetWidth(180)
        group:AddChild(noteBox)

        local awardBtn = AceGUI:Create("Button")
        awardBtn:SetText(L["btn_award"])
        awardBtn:SetWidth(110)
        awardBtn:SetCallback("OnClick", function()
            local winner = dd:GetValue()
            if not winner or winner == "" then
                MRT:Print(L["award_pick_winner"])
                return
            end
            MRT.Loot:Award(item, winner, noteBox:GetText())
            srLabel:SetText("|cff00ff00" .. L["award_done"]:format(winner) .. "|r")
            awardBtn:SetDisabled(true)
            dd:SetDisabled(true)
            UI:Refresh()
        end)
        group:AddChild(awardBtn)
    end
end
