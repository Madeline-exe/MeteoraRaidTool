local ADDON_NAME, ns = ...
local MRT = ns.MRT
local L = ns.L

local Comm = MRT:NewModule("Comm", "AceComm-3.0", "AceSerializer-3.0", "AceEvent-3.0")
MRT.Comm = Comm

local PREFIX = MRT.commPrefix
local LibDeflate = LibStub("LibDeflate", true)

local MSG = {
    VERSION       = "ver",
    VERSION_REPLY = "vRpl",
    RESERVE_SET   = "srSet",
    RESERVE_DEL   = "srDel",
    RESERVE_SYNC  = "srSync",
    LOOT_OPEN     = "ltOpen",
    LOOT_VOTE     = "ltVote",
    LOOT_CLOSE    = "ltClose",
    LOOT_AWARD    = "ltAward",
    POOL_SYNC     = "plSync",
    ROLL_START    = "rlStart",
    ROLL_END      = "rlEnd",
    RAIDLOOT_REQUEST = "rlGet",
    RESERVE_REQUEST  = "srGet",
    CONS_REPORT   = "cnRep",
}
Comm.MSG = MSG

local handlers = {}

function Comm:OnEnable()
    self:RegisterComm(PREFIX, "OnCommReceived")
end

function Comm:On(messageType, handler)
    handlers[messageType] = handlers[messageType] or {}
    table.insert(handlers[messageType], handler)
end

function Comm:Send(messageType, payload, distribution, target)
    distribution = distribution or self:DefaultDistribution()
    local envelope = { t = messageType, v = MRT.version, p = payload }
    local serialized = self:Serialize(envelope)
    local data = serialized
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(serialized)
        data = LibDeflate:EncodeForWoWAddonChannel(compressed)
    end
    self:SendCommMessage(PREFIX, data, distribution, target, "NORMAL")
end

function Comm:DefaultDistribution()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    if IsInGuild() then return "GUILD" end
    return nil
end

function Comm:OnCommReceived(_, message, distribution, sender)
    local decoded = message
    if LibDeflate then
        local d = LibDeflate:DecodeForWoWAddonChannel(message)
        if d then
            local decompressed = LibDeflate:DecompressDeflate(d)
            if decompressed then decoded = decompressed end
        end
    end
    local ok, envelope = self:Deserialize(decoded)
    if not ok or type(envelope) ~= "table" or not envelope.t then return end

    local list = handlers[envelope.t]
    if not list then return end
    for _, handler in ipairs(list) do
        pcall(handler, envelope.p, sender, envelope.v, distribution)
    end
end

function Comm:AnnounceVersion()
    self:Send(MSG.VERSION, { version = MRT.version })
end

Comm:On(MSG.VERSION, function(payload, sender)
    if not payload or not sender then return end
    MRT.peers = MRT.peers or {}
    MRT.peers[Ambiguate(sender, "short")] = {
        version = payload.version,
        seen = GetServerTime and GetServerTime() or time(),
    }
end)
