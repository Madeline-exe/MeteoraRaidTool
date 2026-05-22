local L = LibStub("AceLocale-3.0"):NewLocale("MeteoraRaidTool", "ruRU", false)
if not L then return end

L["loaded"]              = "Meteora Raid Tool v%s загружен. /mrt — открыть."
L["version"]             = "Версия %s"
L["status_ready"]        = "Готов."

L["help_show"]           = " — открыть/закрыть окно"
L["help_scan"]           = " — пересканировать лут текущего рейда"
L["help_casino"]         = " — казино роллы"
L["help_cons"]           = " — сканер химии"

L["none"]                = "не выбран"
L["state_open"]          = "ОТКРЫТЫ"
L["state_closed"]        = "ЗАКРЫТЫ"

L["tab_reserves"]        = "Резервы"
L["tab_status"]          = "Статус"
L["tab_history"]         = "История"

L["pick_raid"]           = "Рейд"
L["btn_open"]            = "Открыть резервы"
L["btn_close"]           = "Закрыть резервы"
L["btn_clear_all"]       = "Сбросить все"
L["btn_refresh_loot"]    = "Пересканировать лут"
L["btn_award"]           = "Выдать"

L["popup_clear_all"]     = "Сбросить ВСЕ софт-резервы для текущего рейда?"

L["you_reserved"]        = "Твои резервы"
L["hint_pick_raid"]      = "Рейдлид ещё не выбрал рейд. Подожди или попроси открыть аддон."
L["hint_no_loot_data"]   = "Лут пока не загружен. Нажми «Пересканировать лут» (если не помогает — открой в игре Encounter Journal один раз)."
L["boss_no_items"]       = "Epic+ предметов для этого босса не найдено."

L["player_current_raid"] = "Рейд: |cffffd200%s|r   Резервы: %s"
L["status_current_raid"] = "Рейд: %s   Резервы: %s"
L["status_empty"]        = "Резервов пока нет. Игроки смогут выбирать предметы когда РЛ откроет резервы."

L["sr_max"]              = "Максимум %d резервов на игрока."
L["sr_closed"]           = "Резервы закрыты."
L["sr_need_lead"]        = "Нужны права рейдлида или ассиста."

L["award_title"]         = "Мастер-лут — выдача"
L["award_status"]        = "Выбери победителя на вещь и нажми «Выдать»"
L["award_sr"]            = "Зарезервировали"
L["award_no_sr"]         = "Никто не зарезервировал."
L["award_to"]            = "Кому"
L["award_note"]          = "Заметка (опц.)"
L["award_pick_winner"]   = "Выбери игрока в выпадающем списке."
L["award_done"]          = "Выдано: %s"
L["loot_announce"]       = "Лут: %s → %s (%s)"

L["scan_done"]           = "Лут рейда пересканирован: %s"
L["scan_no_raid"]        = "Текущий рейд не выбран."

L["history_empty"]       = "Истории лута пока нет."

-- Casino
L["casino_intro"]        = "Казино — роллы по приколу."
L["casino_announce"]     = "Раунд казино открыт! Приз: %s. /roll"
L["casino_winner"]       = "%s выиграл казино с роллом %d! Приз: %s"
L["casino_pot"]          = "%s забирает банк: %d %s"
L["casino_round_title"]  = "Казино — %s"
L["casino_stakes_on"]    = "Ставки ВКЛЮЧЕНЫ."
L["casino_stakes_off"]   = "Без ставок."
L["casino_your_bet"]     = "Ставка (%s)"
L["casino_place_bet"]    = "Поставить"
L["casino_bet_placed"]   = "Ставка принята: %d %s"
L["casino_no_round"]     = "Нет активного раунда."
L["casino_no_stakes"]    = "В этом раунде ставки выключены."
L["casino_need_lead"]    = "Нужны права рейдлида или ассиста."
L["casino_bet_range"]    = "Ставка от %d до %d."
L["casino_bad_bet"]      = "Ставка должна быть числом."
L["casino_help"]         = "/mrt casino open <prize> | close | bet <n> | roll"
L["casino_generic_prize"] = "(без приза)"

-- Consumables
L["cons_missing"]        = "Без химии"
L["cons_no_raid"]        = "Не в группе."
L["cons_refresh"]        = "Обновить скан"
L["cons_player"]         = "Игрок"
L["cons_window_title"]   = "Химия"
L["cons_status"]         = "Скан баффов рейда"
