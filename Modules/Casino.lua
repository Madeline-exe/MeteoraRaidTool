local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Casino = MRT:NewModule("Casino", "AceEvent-3.0", "AceTimer-3.0")
MRT.Casino = Casino

local activeRound = nil

function Casino:OnEnable()
    local Comm = MRT.Comm
    Comm:On(Comm.MSG.CASINO_OPEN,  function(p, s) self:OnRemoteOpen(p, s) end)
    Comm:On(Comm.MSG.CASINO_BET,   function(p, s) self:OnRemoteBet(p, s) end)
    Comm:On(Comm.MSG.CASINO_CLOSE, function(p, s) self:OnRemoteClose(p, s) end)
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")
end

function Casino:HandleSlash(rest)
    rest = (rest or ""):trim():lower()
    local cmd, arg = rest:match("^(%S*)%s*(.*)$")

    if cmd == "" or cmd == "show" then
        if MRT.UI and MRT.UI.OpenCasino then MRT.UI:OpenCasino() end
        return
    end
    if cmd == "open" then
        self:OpenRound(arg)
        return
    end
    if cmd == "close" then
        self:CloseRound()
        return
    end
    if cmd == "bet" then
        local n = tonumber(arg)
        if not n then MRT:Print(L["casino_bad_bet"]); return end
        self:PlaceBet(n)
        return
    end
    if cmd == "roll" then
        RandomRoll(1, 100)
        return
    end
    MRT:Print(L["casino_help"])
end

function Casino:OpenRound(itemSpec)
    if not (MRT:IsRaidLeader() or MRT:IsRaidAssistant()) then
        MRT:Print(L["casino_need_lead"])
        return
    end
    local itemID = itemSpec and tonumber(itemSpec:match("item:(%d+)") or itemSpec)
    local link = itemID and select(2, GetItemInfo(itemID)) or itemSpec or L["casino_generic_prize"]
    local roundID = string.format("cs-%s-%d", UnitName("player"), GetServerTime and GetServerTime() or time())

    activeRound = {
        id        = roundID,
        host      = UnitName("player"),
        prize     = link,
        prizeID   = itemID,
        stakeUnit = MRT.db.profile.casino.stakeUnit,
        stakes    = MRT.db.profile.casino.enableStakes,
        bets      = {},
        rolls     = {},
        opened    = GetServerTime and GetServerTime() or time(),
    }
    MRT.Comm:Send(MRT.Comm.MSG.CASINO_OPEN, {
        roundID   = roundID,
        prize     = link,
        prizeID   = itemID,
        stakeUnit = activeRound.stakeUnit,
        stakes    = activeRound.stakes,
    })
    SendChatMessage(L["casino_announce"]:format(link), "RAID_WARNING")
    if MRT.UI and MRT.UI.OpenCasinoRound then MRT.UI:OpenCasinoRound(activeRound) end
end

function Casino:CloseRound()
    if not activeRound then return end
    local winnerName, winnerRoll = self:DetermineWinner()
    activeRound.winner = winnerName
    activeRound.winnerRoll = winnerRoll
    MRT.Comm:Send(MRT.Comm.MSG.CASINO_CLOSE, {
        roundID = activeRound.id,
        winner  = winnerName,
        roll    = winnerRoll,
    })
    if winnerName then
        SendChatMessage(L["casino_winner"]:format(winnerName, winnerRoll, activeRound.prize), "RAID_WARNING")
        self:SettleStakes(winnerName)
    end
    table.insert(MRT.db.global.casinoHistory, {
        timestamp = GetServerTime and GetServerTime() or time(),
        prize     = activeRound.prize,
        winner    = winnerName,
        roll      = winnerRoll,
        bets      = activeRound.bets,
    })
    local limit = MRT.db.profile.casino.historyLimit
    while #MRT.db.global.casinoHistory > limit do
        table.remove(MRT.db.global.casinoHistory, 1)
    end
    activeRound = nil
    if MRT.UI and MRT.UI.CloseCasinoRound then MRT.UI:CloseCasinoRound() end
end

function Casino:DetermineWinner()
    local best, bestRoll
    for player, roll in pairs(activeRound.rolls) do
        if not bestRoll or roll > bestRoll then
            bestRoll = roll
            best = player
        end
    end
    return best, bestRoll
end

function Casino:PlaceBet(amount)
    if not activeRound then MRT:Print(L["casino_no_round"]); return end
    if not activeRound.stakes then
        MRT:Print(L["casino_no_stakes"])
        return
    end
    local minS = MRT.db.profile.casino.minStake
    local maxS = MRT.db.profile.casino.maxStake
    if amount < minS or amount > maxS then
        MRT:Print(L["casino_bet_range"]:format(minS, maxS))
        return
    end
    MRT.Comm:Send(MRT.Comm.MSG.CASINO_BET, { roundID = activeRound.id, amount = amount })
    MRT:Print(L["casino_bet_placed"]:format(amount, activeRound.stakeUnit))
end

function Casino:OnRemoteOpen(payload, sender)
    if not payload or not payload.roundID then return end
    activeRound = {
        id        = payload.roundID,
        host      = sender,
        prize     = payload.prize,
        prizeID   = payload.prizeID,
        stakeUnit = payload.stakeUnit,
        stakes    = payload.stakes,
        bets      = {},
        rolls     = {},
        opened    = GetServerTime and GetServerTime() or time(),
    }
    if MRT.UI and MRT.UI.OpenCasinoRound then MRT.UI:OpenCasinoRound(activeRound) end
end

function Casino:OnRemoteBet(payload, sender)
    if not activeRound or payload.roundID ~= activeRound.id then return end
    activeRound.bets[Ambiguate(sender, "short")] = payload.amount
    if MRT.UI and MRT.UI.RefreshCasino then MRT.UI:RefreshCasino(activeRound) end
end

function Casino:OnRemoteClose(payload)
    if not activeRound or payload.roundID ~= activeRound.id then return end
    activeRound = nil
    if MRT.UI and MRT.UI.CloseCasinoRound then MRT.UI:CloseCasinoRound() end
end

function Casino:OnSystemMessage(_, msg)
    if not activeRound then return end
    local player, roll, low, high = msg:match("^(%S+) rolls (%d+) %((%d+)-(%d+)%)$")
    if not player then return end
    low, high = tonumber(low), tonumber(high)
    if low ~= 1 or high ~= 100 then return end
    if activeRound.host == UnitName("player") then
        activeRound.rolls[player] = tonumber(roll)
        if MRT.UI and MRT.UI.RefreshCasino then MRT.UI:RefreshCasino(activeRound) end
    end
end

function Casino:SettleStakes(winner)
    if not activeRound.stakes or not winner then return end
    local pot = 0
    for _, amount in pairs(activeRound.bets) do pot = pot + amount end
    if pot == 0 then return end
    MRT:Print(L["casino_pot"]:format(winner, pot, activeRound.stakeUnit))
end

function Casino:GetRound()
    return activeRound
end
