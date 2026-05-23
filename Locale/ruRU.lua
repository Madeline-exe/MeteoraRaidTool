local L = LibStub("AceLocale-3.0"):NewLocale("MeteoraRaidTool", "ruRU", false)
if not L then return end

L["loaded"]              = "Meteora Raid Tool v%s загружен. /mrt — открыть."
L["version"]             = "Версия %s"
L["status_ready"]        = "Готов."

L["help_show"]           = " — открыть/закрыть окно"
L["help_sync"]           = " — заново разослать рейд и лут-таблицу группе"
L["help_dist"]           = " — открыть таб распределения лута"
L["help_cons"]           = " — открыть таб расходников"

L["none"]                = "не выбран"
L["state_open"]          = "ОТКРЫТЫ"
L["state_closed"]        = "ЗАКРЫТЫ"

L["tab_reserves"]        = "Резервы"
L["tab_distribute"]      = "Распределение"
L["tab_consumables"]     = "Расходники"
L["tab_status"]          = "Статус"
L["tab_history"]         = "История лута"
L["tab_sr_history"]      = "История SR"

L["sr_history_empty"]    = "История резервов пока пуста. Снимок сохраняется когда РЛ закрывает резервы или начинается бой."
L["sr_history_no_reserves"] = "(никто не резервировал)"

-- Distribute / loot pool / rolls
L["pool_added_ml"]       = "В пул добавлено вещей: %d"
L["pool_added_chat"]     = "Из чата: %s получил %s"
L["pool_chat_tag"]       = "из чата"
L["dist_need_lead"]      = "Распределение доступно только рейдлиду и ассистам."
L["dist_pool_title"]     = "Пул лута"
L["dist_pool_empty"]     = "Пул пуст. Вещи попадут сюда автоматически когда РЛ откроет мастер-лут на трупе босса."
L["dist_unmapped"]       = "Без босса"
L["btn_clear_pool"]      = "Очистить пул"
L["popup_clear_pool"]    = "Очистить ВСЕ выпавшие вещи в текущем рейде?"
L["btn_roll_sr"]         = "Ролл по SR"
L["btn_roll_free"]       = "Свободный ролл"
L["btn_roll_stop"]       = "Завершить ролл"
L["btn_roll_clear"]      = "Скрыть результат"
L["roll_announce_sr"]    = "Роллим %s. Резервы: %s. У вас %d сек — /roll"
L["roll_announce_free"]  = "Роллим %s. Свободный ролл, %d сек — /roll"
L["roll_winner"]         = "%s — победил %s с роллом %d"
L["roll_nobody"]         = "Никто не сролил на %s"
L["roll_panel_sr"]       = "Роллы (по резерву)"
L["roll_panel_free"]     = "Роллы"
L["roll_waiting"]        = "Ждём роллы..."

-- Minimap
L["minimap_lmb"]         = "открыть Meteora"
L["minimap_rmb"]         = "настройки"

L["pick_raid"]           = "Рейд"
L["btn_open"]            = "Открыть резервы"
L["btn_close"]           = "Закрыть резервы"
L["btn_clear_all"]       = "Сбросить все"
L["btn_edit"]            = "Редактировать"
L["btn_edit_done"]       = "Готово"
L["btn_add_item"]        = "Добавить"
L["btn_award"]           = "Выдать"
L["edit_mode_on"]        = "РЕЖИМ РЕДАКТИРОВАНИЯ"
L["edit_tip"]            = "Вставь линк предмета (shift+клик из AtlasLoot) или ID в поле и нажми Enter."
L["edit_add_hint"]       = "Линк предмета или ID"
L["loot_bad_item"]       = "Не могу распознать предмет. Shift+клик по линку или вставь ID."

L["popup_clear_all"]     = "Сбросить ВСЕ софт-резервы для текущего рейда?"

L["you_reserved"]        = "Твои резервы"
L["hint_pick_raid"]      = "Рейдлид ещё не выбрал рейд."
L["boss_no_items"]       = "(пока нет предметов)"
L["items_short"]         = "предм."
L["reserves_short"]      = "рез."

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

L["sync_done"]           = "Лут-таблица и рейд разосланы группе."
L["sync_no_raid"]        = "Текущий рейд не выбран."

L["history_empty"]       = "Истории лута пока нет."

-- Consumables
L["cons_missing"]        = "Без химии"
L["cons_no_raid"]        = "Не в группе."
L["cons_refresh"]        = "Обновить скан"
L["cons_player"]         = "Игрок"
L["cons_window_title"]   = "Химия"
L["cons_status"]         = "Скан баффов рейда"
