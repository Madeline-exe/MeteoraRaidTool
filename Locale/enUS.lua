local L = LibStub("AceLocale-3.0"):NewLocale("MeteoraRaidTool", "enUS", true, true)
if not L then return end

L["loaded"]              = "Meteora Raid Tool v%s loaded. Type /mrt to open."
L["version"]             = "Version %s"
L["status_ready"]        = "Ready."

L["help_show"]           = " — toggle main window"
L["help_scan"]           = " — rescan loot table for current raid"
L["help_casino"]         = " — fun casino rolls"
L["help_cons"]           = " — consumable scan"

L["none"]                = "none"
L["state_open"]          = "OPEN"
L["state_closed"]        = "CLOSED"

L["tab_reserves"]        = "Reserves"
L["tab_status"]          = "Status"
L["tab_history"]         = "History"

L["pick_raid"]           = "Raid"
L["btn_open"]            = "Open reserves"
L["btn_close"]           = "Close reserves"
L["btn_clear_all"]       = "Clear all"
L["btn_refresh_loot"]    = "Rescan loot table"
L["btn_award"]           = "Award"

L["popup_clear_all"]     = "Clear ALL soft reserves for the current raid?"

L["you_reserved"]        = "Your reserves"
L["hint_pick_raid"]      = "Raid leader hasn't picked a raid yet. Wait or ask them to open the addon."
L["hint_no_loot_data"]   = "No loot data yet. Click 'Rescan loot table' (open the Encounter Journal first if it doesn't fill up)."
L["boss_no_items"]       = "No epic+ items recorded for this boss."

L["player_current_raid"] = "Raid: |cffffd200%s|r   Reserves: %s"
L["status_current_raid"] = "Raid: %s   Reserves: %s"
L["status_empty"]        = "No reserves yet. Players can pick items once the raid leader opens reserves."

L["sr_max"]              = "Max %d reserves per player."
L["sr_closed"]           = "Reserves are closed."
L["sr_need_lead"]        = "You need to be raid leader or assistant."

L["award_title"]         = "Master loot — award"
L["award_status"]        = "Choose winner per item, then Award"
L["award_sr"]            = "Soft-reserved by"
L["award_no_sr"]         = "No soft reserves on this item."
L["award_to"]            = "Award to"
L["award_note"]          = "Note (optional)"
L["award_pick_winner"]   = "Pick a player from the dropdown first."
L["award_done"]          = "Awarded to %s"
L["loot_announce"]       = "Loot: %s -> %s (%s)"

L["scan_done"]           = "Loot table rescanned for raid: %s"
L["scan_no_raid"]        = "No current raid selected."

L["history_empty"]       = "No loot history yet."

-- Casino (kept for slash command compatibility)
L["casino_intro"]        = "Casino — for fun rolls."
L["casino_announce"]     = "Casino round open! Prize: %s. /roll"
L["casino_winner"]       = "%s wins the casino with %d! Prize: %s"
L["casino_pot"]          = "%s claims the pot: %d %s"
L["casino_round_title"]  = "Casino — %s"
L["casino_stakes_on"]    = "Stakes ENABLED."
L["casino_stakes_off"]   = "No stakes."
L["casino_your_bet"]     = "Bet (%s)"
L["casino_place_bet"]    = "Place bet"
L["casino_bet_placed"]   = "Bet placed: %d %s"
L["casino_no_round"]     = "No active casino round."
L["casino_no_stakes"]    = "Stakes are off in this round."
L["casino_need_lead"]    = "You must be raid leader or assistant."
L["casino_bet_range"]    = "Bet must be between %d and %d."
L["casino_bad_bet"]      = "Bet must be a number."
L["casino_help"]         = "/mrt casino open <prize> | close | bet <n> | roll"
L["casino_generic_prize"] = "(unspecified prize)"

-- Consumables (kept for slash command compatibility)
L["cons_missing"]        = "Missing consumables"
L["cons_no_raid"]        = "Not in a group."
L["cons_refresh"]        = "Refresh scan"
L["cons_player"]         = "Player"
L["cons_window_title"]   = "Consumables"
L["cons_status"]         = "Buff scan of raid"
