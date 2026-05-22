local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L
local UI = MRT.UI

local AceGUI = LibStub("AceGUI-3.0")

function UI:BuildSoftReserveTab(container)
    local top = AceGUI:Create("SimpleGroup")
    top:SetLayout("Flow")
    top:SetFullWidth(true)
    container:AddChild(top)

    local input = AceGUI:Create("EditBox")
    input:SetLabel(L["sr_input_label"])
    input:SetWidth(380)
    top:AddChild(input)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L["sr_add"])
    addBtn:SetWidth(110)
    addBtn:SetCallback("OnClick", function()
        local text = input:GetText() or ""
        local id = text:match("item:(%d+)") or text:match("(%d+)")
        if id then MRT.SoftReserve:Reserve(tonumber(id)) end
        input:SetText("")
        UI:RefreshSoftReserveList()
    end)
    top:AddChild(addBtn)

    local clearBtn = AceGUI:Create("Button")
    clearBtn:SetText(L["sr_clear_mine"])
    clearBtn:SetWidth(140)
    clearBtn:SetCallback("OnClick", function()
        MRT.SoftReserve:ClearMine()
        UI:RefreshSoftReserveList()
    end)
    top:AddChild(clearBtn)

    local syncBtn = AceGUI:Create("Button")
    syncBtn:SetText(L["sr_sync"])
    syncBtn:SetWidth(120)
    syncBtn:SetCallback("OnClick", function()
        MRT.SoftReserve:BroadcastFullSync()
    end)
    top:AddChild(syncBtn)

    local listScroll = AceGUI:Create("ScrollFrame")
    listScroll:SetLayout("List")
    listScroll:SetFullWidth(true)
    listScroll:SetFullHeight(true)
    container:AddChild(listScroll)

    self.srScroll = listScroll
    self:RefreshSoftReserveList()
end

function UI:RefreshSoftReserveList()
    if not self.srScroll then return end
    self.srScroll:ReleaseChildren()

    local data = MRT.SoftReserve:GetAll()
    local sorted = {}
    for player in pairs(data) do table.insert(sorted, player) end
    table.sort(sorted)

    if #sorted == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText(L["sr_empty"])
        lbl:SetFullWidth(true)
        self.srScroll:AddChild(lbl)
        return
    end

    for _, player in ipairs(sorted) do
        local row = AceGUI:Create("InlineGroup")
        row:SetTitle(player)
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        for _, itemID in ipairs(data[player]) do
            local link = select(2, GetItemInfo(itemID)) or ("item:" .. itemID)
            local lbl = AceGUI:Create("InteractiveLabel")
            lbl:SetText(link)
            lbl:SetWidth(220)
            lbl:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. itemID)
                GameTooltip:Show()
            end)
            lbl:SetCallback("OnLeave", function() GameTooltip:Hide() end)
            row:AddChild(lbl)
        end
        self.srScroll:AddChild(row)
    end
end
