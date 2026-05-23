# Meteora Raid Tool

Гильдейский рейд-инструмент для WoW Classic TBC Burning Crusade Anniversary
(Interface 2.5.x / `bcc`). Софт-резервы, распределение лута с роллами,
авто-трейд, история и статы — всё в одном тёмном Frame-API окне.

![preview](https://raw.githubusercontent.com/Madeline-exe/MeteoraRaidTool/main/.github/preview.png)

## Что умеет

- **Soft-резервы** — клик `+` напротив предмета из заранее наполненной
  дроп-таблицы. Лимит на игрока, синхронизация на всех в группе,
  автозакрытие на пулле, снапшоты в историю.
- **Резервы пугов** — RL жмёт «Спросить у пуга» → игроки без аддона
  получают ЛС с инструкцией → шлют линки → аддон автоматически
  парсит и резервит за них.
- **Импорт дроп-таблиц из AtlasLoot** — кнопка «Импорт из AtlasLoot»
  заполняет дроп всех 9 рейдов TBC (Karazhan, Gruul, Mag, SSC, TK, ZA,
  Hyjal, BT, Sunwell) одним кликом.
- **Распределение лута** — мастер-лут на трупе автоматически кладёт
  эпики в пул, RL разбирает по запросу: «Ролл по SR» / «Свободный ролл» /
  прямая выдача. Роллы из чата подсчитываются в реальном времени.
- **Авто-трейд** — после выдачи, при открытии трейда с победителем,
  предмет автоматически кладётся в trade-слот.
- **Расходники** — сканер `UnitAura` рейда: фласки, эликсиры, еда,
  свитки, заточки/масла, потки, дрАмс. Предупреждение на пулле.
- **История лута и SR** — каждый клиент пишет свою копию (broadcast
  award'ов и snapshot'ов), история переживает смену RL.
- **Статы по игрокам** — топ получивших с фильтрами период/рейд,
  drill-down на полную историю одного игрока.
- **Экспорт в Discord** — кнопка «Копировать» в Статах и Истории
  открывает готовую markdown-таблицу для вставки в код-блок.
- **Кнопка миникарты** (LibDBIcon).
- **Полностью русский UI**, тёмная палитра в стиле ElvUI/DBM,
  drag, resize, сохранение позиции.

## Установка

1. Скачай последний релиз: [releases page](https://github.com/Madeline-exe/MeteoraRaidTool/releases/latest).
2. Файл `MeteoraRaidTool-vX.Y.Z-bcc.zip` распакуй в
   `World of Warcraft\_classic_\Interface\AddOns\` — должна получиться
   папка `Interface\AddOns\MeteoraRaidTool\`.
3. В игре `/reload` или релог.
4. **Опционально**, но рекомендуется: [AtlasLoot Classic](https://www.curseforge.com/wow/addons/atlasloot-classic)
   для one-click импорта дроп-таблиц.

Аддон должен стоять у всех в группе, иначе они не получат данные
(стандартное требование любого SR-инструмента).

## Быстрый старт (RL)

1. `/mrt` → выбрать рейд в дропдауне.
2. «Импорт из AtlasLoot» → дроп всех боссов рейда подгрузится.
3. «Открыть резервы» → игроки могут резервить.
4. «Спросить у пуга» → тем кто без аддона уйдёт ЛС.
5. На пулле резервы автоматически закроются, снимок попадёт в «Историю SR».
6. После боя `LOOT_OPENED` на трупе → эпики в табе «Распределение».
7. На вещи: «Ролл по SR» / «Свободный ролл» / «Передать».
8. Открыть трейд с победителем → предмет сам ляжет в слот.

## Команды

| Команда                | Что делает                                       |
|------------------------|--------------------------------------------------|
| `/mrt`, `/meteora`     | Открыть/закрыть главное окно                     |
| `/mrt sync`            | Заново разослать рейд и лут-таблицу группе       |
| `/mrt dist`            | Открыть таб распределения                        |
| `/mrt cons`            | Открыть таб расходников                          |
| `/mrt askpug`          | Попросить пугов прислать резервы в ЛС            |

## Архитектура

```
MeteoraRaidTool/
├── MeteoraRaidTool.toc       Манифест
├── Core.lua                  Init, slash, DB defaults, минимапа
├── Locale/                   enUS + ruRU
├── Data/
│   ├── Raids.lua             9 TBC рейдов + боссы (ru/en имена)
│   └── Consumables.lua       Spell IDs и name patterns
├── Modules/
│   ├── Comm.lua              AceComm + LibDeflate + LibSerialize
│   ├── RaidLoot.lua          Дроп-таблица + sync + REQUEST/RESPONSE
│   ├── SoftReserve.lua       Резервы, лимиты, snapshot истории
│   ├── Loot.lua              Лут-пул, парсинг чата, ролл-движок, award
│   ├── Consumables.lua       UnitAura scanner (через AceBucket)
│   ├── TestMode.lua          Симуляция дропа/роллов (через /mrt test)
│   ├── AtlasLootImport.lua   Импорт дроп-таблиц из AtlasLootClassic
│   ├── AutoTrade.lua         Авто-выкладка в трейд на TRADE_SHOW
│   └── WhisperReserve.lua    Резервы пугов через ЛС
└── UI/
    ├── Skin.lua              Палитра, BackdropTemplate, UTF-8 helpers
    ├── MainPanel.lua         Главное окно (drag/resize/табы)
    ├── MainFrame.lua         UI module + RegisterMessage hooks
    ├── ReservesPanel.lua     Таб Резервы
    ├── DistributePanel.lua   Таб Распределение
    ├── SimplePanels.lua      Статус / История лута / История SR / Расходники
    ├── StatsPanel.lua        Таб Статы (агрегация + drill-down)
    ├── PlayerHistoryFrame.lua Полная история одного игрока
    └── ExportFrame.lua       Modal popup с TSV для копирования
```

## Лицензия

MIT. Автор: Meteora.
