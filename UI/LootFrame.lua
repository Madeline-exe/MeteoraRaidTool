local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

local councilFrame, voteFrame

function UI:BuildLootTab(container)
    local info = AceGUI:Create("Label")
    info:SetFullWidth(true)
    info:SetText(L["loot_tab_info"])
    container:AddChild(info)

    local openBtn = AceGUI:Create("Button")
    openBtn:SetText(L["loot_open_test"])
    openBtn:SetWidth(180)
    openBtn:SetCallback("OnClick", function()
        local session = MRT.Loot:GetSession() or MRT.pendingSession
        if session and councilFrame == nil then
            UI:OpenLootCouncil(session)
        else
            MRT:Print(L["loot_no_session"])
        end
    end)
    container:AddChild(openBtn)
end

function UI:OpenLootCouncil(session)
    if councilFrame then councilFrame:Release() end
    councilFrame = AceGUI:Create("Frame")
    councilFrame:SetTitle(L["loot_council_title"])
    councilFrame:SetStatusText(string.format("Session %s", session.id))
    councilFrame:SetLayout("Flow")
    councilFrame:SetWidth(620)
    councilFrame:SetHeight(420)
    councilFrame:SetCallback("OnClose", function(widget) widget:Hide(); councilFrame = nil end)

    for idx, item in ipairs(session.items) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(item.link or ("item:" .. item.itemID))
        group:SetFullWidth(true)
        group:SetLayout("Flow")

        local srLabel = AceGUI:Create("Label")
        local reservers = MRT.SoftReserve:GetReservesForItem(item.itemID)
        srLabel:SetFullWidth(true)
        srLabel:SetText(L["loot_sr_for_item"] .. ": " .. (next(reservers) and table.concat(reservers, ", ") or L["sr_none"]))
        group:AddChild(srLabel)

        local votesScroll = AceGUI:Create("ScrollFrame")
        votesScroll:SetLayout("List")
        votesScroll:SetFullWidth(true)
        votesScroll:SetHeight(120)
        group:AddChild(votesScroll)

        item._votesScroll = votesScroll
        item._index = idx

        local awardEdit = AceGUI:Create("EditBox")
        awardEdit:SetLabel(L["loot_award_to"])
        awardEdit:SetWidth(180)
        group:AddChild(awardEdit)

        local reasonDD = AceGUI:Create("Dropdown")
        reasonDD:SetLabel(L["loot_reason"])
        reasonDD:SetList({
            need = "Need",
            os   = "Offspec",
            tmog = "Transmog",
            sr   = "Soft Reserve",
        })
        reasonDD:SetValue("need")
        reasonDD:SetWidth(140)
        group:AddChild(reasonDD)

        local awardBtn = AceGUI:Create("Button")
        awardBtn:SetText(L["loot_award"])
        awardBtn:SetWidth(110)
        awardBtn:SetCallback("OnClick", function()
            local winner = awardEdit:GetText()
            if winner and winner ~= "" then
                MRT.Loot:Award(idx, winner, reasonDD:GetValue())
                if councilFrame then councilFrame:SetStatusText(L["loot_awarded_status"]:format(winner)) end
            end
        end)
        group:AddChild(awardBtn)

        councilFrame:AddChild(group)
    end

    self:RefreshLootCouncil(session)
end

function UI:RefreshLootCouncil(session)
    if not councilFrame then return end
    for idx, item in ipairs(session.items) do
        local scroll = item._votesScroll
        if scroll then
            scroll:ReleaseChildren()
            local votes = session.votes[idx] or {}
            for player, vote in pairs(votes) do
                local lbl = AceGUI:Create("Label")
                lbl:SetFullWidth(true)
                lbl:SetText(string.format("%s — |cffffff00%s|r%s%s",
                    player,
                    vote.response or "",
                    vote.sr and " |cffff8800[SR]|r" or "",
                    vote.comment and (" — " .. vote.comment) or ""))
                scroll:AddChild(lbl)
            end
        end
    end
end

function UI:OpenLootVote(session)
    if voteFrame then voteFrame:Release() end
    voteFrame = AceGUI:Create("Frame")
    voteFrame:SetTitle(L["loot_vote_title"])
    voteFrame:SetStatusText(L["loot_vote_status"])
    voteFrame:SetLayout("Flow")
    voteFrame:SetWidth(520)
    voteFrame:SetHeight(420)
    voteFrame:SetCallback("OnClose", function(widget) widget:Hide(); voteFrame = nil end)

    for idx, item in ipairs(session.items) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(item.link or ("item:" .. item.itemID))
        group:SetFullWidth(true)
        group:SetLayout("Flow")

        local commentBox = AceGUI:Create("EditBox")
        commentBox:SetLabel(L["loot_comment"])
        commentBox:SetWidth(280)
        group:AddChild(commentBox)

        local responses = {
            { key = "need",  text = "Need"     },
            { key = "os",    text = "Offspec"  },
            { key = "tmog",  text = "Transmog" },
            { key = "pass",  text = "Pass"     },
        }
        for _, r in ipairs(responses) do
            local btn = AceGUI:Create("Button")
            btn:SetText(r.text)
            btn:SetWidth(90)
            btn:SetCallback("OnClick", function()
                MRT.Loot:Vote(idx, r.key, commentBox:GetText())
                MRT:Print(L["loot_vote_sent"]:format(r.text))
            end)
            group:AddChild(btn)
        end

        voteFrame:AddChild(group)
    end
end

function UI:CloseLootVote()
    if voteFrame then voteFrame:Release(); voteFrame = nil end
end
