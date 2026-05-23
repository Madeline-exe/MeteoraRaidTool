local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

-- ============================================================
-- UI module registration. Build / Toggle / Refresh / OpenTab /
-- OnTestToggled are provided by UI/MainPanel.lua (loaded last).
-- This file only owns the AceEvent-3.0 mixin and the message
-- subscriptions that drive UI refresh.
-- ============================================================

local UI = MRT:NewModule("UI", "AceEvent-3.0")
MRT.UI = UI

function UI:OnEnable()
    self:RegisterMessage("MRT_SR_STATE_CHANGED",  "RefreshLater")
    self:RegisterMessage("MRT_RAIDLOOT_CHANGED",  "RefreshLater")
    self:RegisterMessage("MRT_POOL_CHANGED",      "RefreshLater")
    self:RegisterMessage("MRT_ROLL_UPDATE",       "RefreshLater")
    self:RegisterMessage("MRT_TEST_TOGGLED",      "OnTestToggled")
end
