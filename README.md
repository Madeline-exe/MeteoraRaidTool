# Meteora Raid Tool

Гильдейский рейд-инструмент для WoW Classic TBC Burning Crusade Anniversary (Interface 2.5.x).

## Возможности

- **Loot Council** — мастер-лут сессии с голосованием Need/Offspec/Transmog/Pass + комментарий, выдача через UI, автоанонс победителя.
- **Soft Reserve** — игроки резервируют вещи через `/mrt sr <item>` или окно UI, данные синхронизируются между обладателями аддона через AddOn channel. Лимит резервов на игрока + автоблок при пулле.
- **Consumables tracking** — скан `UnitAura` рейд-членов: фласки, эликсиры (battle/guardian), еда, свитки, заточки/масла, бэтл-поты, дрАмс. Предупреждение о тех, кто без химии на пулле.
- **Casino** — `/roll 1-100` раунды по приколу с опциональными ставками на DKP/EPGP/голд. История последних раундов.
- **История лута** — полный архив всех выдач в SavedVariables.
- **UI** — классический wow-вид, минимализм через Ace3 (AceGUI), вкладочный главный фрейм.

## Workflow: VPS → GitHub → Windows клиент

Аддон собирается автоматически через GitHub Actions (BigWigs packager подтягивает Ace3 и упаковывает ZIP), а на клиенте устанавливается одной командой PowerShell.

### Однократная настройка

**На VPS (этой машине):**

```bash
cd ~/MeteoraRaidTool
git init -b main
git add .
git commit -m "init"
git remote add origin git@github.com:<твой-юзер>/MeteoraRaidTool.git
git push -u origin main
```

(Если приватный репо — добавь deploy key или используй HTTPS-токен.)

GitHub Actions сработает автоматически на каждый push в `main`/`master` или на tag `v*` и создаст артефакт билда (на каждый push) или Release (на tag).

**На Windows-клиенте (один раз):**

1. Скачай файлы `tools/Install-MeteoraRaidTool.ps1` и `tools/update.bat` из репо.
2. Открой `Install-MeteoraRaidTool.ps1` и поменяй дефолтное значение `$Repo` на свой `owner/MeteoraRaidTool`, либо выставь переменную окружения:
   ```powershell
   setx METEORA_REPO "your-github-user/MeteoraRaidTool"
   ```
3. (Если репо приватный или хочешь тянуть CI-артефакты без тегов) сделай GitHub PAT с правами `actions:read` + `contents:read`:
   ```powershell
   setx GITHUB_TOKEN "ghp_xxxxx"
   ```

### Обычный рабочий цикл

**На VPS — внёс правки → запушил:**

```bash
git add -A
git commit -m "feat: новое поведение SR"
git tag v0.1.1            # опционально — создаёт полноценный Release
git push --follow-tags
```

**На Windows — двойной клик `update.bat`** (или `tools\update.bat -Source artifact` для последнего CI-билда без тега).

Скрипт сам:
- найдёт твою `World of Warcraft\_classic_\Interface\AddOns\` папку (кэширует в `%USERPROFILE%\.meteora-raid-tool.json`),
- скачает последний Release-ZIP с GitHub,
- удалит старую установку и распакует новую.

В игре после обновления — `/reload`.

### Команды скрипта

| Команда                                                    | Что делает                                  |
|------------------------------------------------------------|---------------------------------------------|
| `tools\update.bat`                                         | Установить последний **Release** (тег `v*`) |
| `tools\update.bat -Source artifact`                        | Установить последний **CI-билд** (без тега) |
| `.\Install-MeteoraRaidTool.ps1 -WoWPath "D:\WoW"`          | Указать путь к WoW вручную                  |
| `.\Install-MeteoraRaidTool.ps1 -Repo user/repo`            | Переопределить репо                         |

### Локальная сборка для отладки

Если хочешь собрать ZIP прямо на VPS без push в GitHub:

```bash
# Один раз — поставить packager
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh -o release.sh
chmod +x release.sh

# Каждый раз — собрать в .release/
./release.sh -g classic -w 0
```

В `.release/` появится `MeteoraRaidTool-x.y.z.zip` с уже встроенными Ace3 либами.

## Команды

| Команда                          | Действие                                              |
|----------------------------------|-------------------------------------------------------|
| `/mrt` или `/meteora`            | Открыть главное окно                                  |
| `/mrt sr <item-link>` или `<id>` | Зарезервировать предмет                               |
| `/mrt sr list`                   | Список текущих резервов                               |
| `/mrt sr clear`                  | Очистить мои резервы                                  |
| `/mrt sr lock` / `unlock`        | Заблокировать резервы (rl/assist only)                |
| `/mrt casino open <prize>`       | Открыть раунд казино                                  |
| `/mrt casino close`              | Закрыть раунд, определить победителя                  |
| `/mrt casino bet <n>`            | Сделать ставку (если ставки включены)                 |
| `/mrt consumables` / `cons`      | Окно сканера химии                                    |
| `/mrt config`                    | Настройки                                             |

## Архитектура

```
MeteoraRaidTool/
├── MeteoraRaidTool.toc       Манифест
├── Core.lua                  Ace3 init, slash commands, DB defaults
├── Locale/                   enUS + ruRU
├── Data/Consumables.lua      Spell IDs всех TBC расходников
├── Modules/
│   ├── Comm.lua              Сериализация и обмен через AddOn channel
│   ├── SoftReserve.lua       Резервы + sync
│   ├── Loot.lua              Loot council mechanics
│   ├── Consumables.lua       UnitAura scanner
│   └── Casino.lua            Roll-раунды + ставки
├── UI/                       AceGUI вкладки
├── tools/
│   ├── Install-MeteoraRaidTool.ps1   PowerShell-инсталлятор для Windows
│   └── update.bat                    Одно-кликовый враппер для update
├── .pkgmeta                  BigWigs packager — externals для Ace3
└── .github/workflows/
    └── release.yml           Авто-сборка ZIP при push/tag
```

### Comm-протокол

Все сообщения проходят через префикс `MRT1` (AceComm + LibDeflate + LibSerialize):

```
{ t = <type>, v = <addon version>, p = <payload> }
```

Типы: `ver`, `vRpl`, `srSet`, `srDel`, `srSync`, `ltOpen`, `ltVote`, `ltClose`, `ltAward`, `csOpen`, `csBet`, `csClose`, `cnRep`.

## Что НЕ работает прямо сейчас

- Импорт из softres.it — пока не реализовано (можно добавить позже отдельным модулем).
- Полная панель `AceConfig` — каркас есть, опции добавить под нужды гильдии.
- Spell ID базы расходников — добавлены основные TBC консумы, но список нужно сверить с актуальной TBC Anniversary версией (некоторые ID могут отличаться, особенно у Shattrath flask / new BC items).

## Лицензия

MIT (или какая нужна гильдии). Автор: Meteora.
