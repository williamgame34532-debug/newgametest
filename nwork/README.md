# N-work 1.0 — RP-фреймворк для Garry's Mod

Фреймворк сервера **Network - HL:A RP**. Работает поверх `sandbox`,
визуальный стиль — Monarch / Project Synapse: шрифт Roboto, белый текст с
мягкой тенью, тёмные полупрозрачные плашки, тонкие контуры, логотип-надпись.

## Установка

Папку `nwork` целиком — в `garrysmod/gamemodes/nwork/`.
Запуск: `+gamemode nwork` или выбор в меню (категория RP).

## Устройство

```
nwork/
├── nwork.txt, icon24.png, logo.png
├── content/materials/nwork/     иконки и логотип (раздаются через resource.AddFile)
├── entities/
│   ├── entities/nwork_item.lua  предмет в мире
│   └── weapons/nwork_hands.lua  руки (оружие по умолчанию)
└── gamemode/
    ├── shared.lua               загрузчик (NWORK.Include / IncludeDir)
    ├── framework/
    │   ├── boot.lua             порядок загрузки
    │   ├── libraries/           ядро
    │   ├── hooks/               переопределения GM
    │   └── interface/           клиентский интерфейс
    ├── schema/                  контент сервера: фракции, предметы, чат, команды
    └── modules/                 отключаемые модули
```

Реалм файла — по префиксу: `sv_` сервер, `cl_` клиент, `sh_` обе стороны.
Внутри папки сначала грузятся `sh_`, потом `sv_`, потом `cl_`.

**Ядро** (`framework/libraries`):

| Файл | Что делает |
|---|---|
| `sh_config` | Все настройки по умолчанию (`NWORK.Config`) |
| `sh_faction` | `NWORK.Faction.Register`, модели, состав онлайн |
| `sh_item` | `NWORK.Item.Register`, категории, действия предметов |
| `sh_character` | Методы игрока: `GetCharName`, `GetFaction`, `HasCharacter`…; знакомства |
| `sv_character` | Создание, выбор, удаление, сохранение, смена персонажа; `data` для модулей |
| `sh/sv_inventory` | Инвентарь: `Give`, `Take`, `Has`, стопки, выброс, подбор, действия |
| `sh_command` | Команды чата `/имя` с правами и автодополнением |
| `sh_chat` | Чат-классы: префиксы, дистанции, форматы строк, реплики над головой |
| `sh_notify` | Уведомления `NWORK.Notify` (и стандартные уведомления песочницы) |
| `sh_module` | Загрузка модулей |
| `cl_option` | Клиентские настройки с автоматической вкладкой «Настройки» |
| `sv_database` | Обёртка SQLite и миграции колонок |

**Схема** (`schema/`) — всё, что относится к конкретному серверу: название,
задание по умолчанию, правила, стартовые предметы, фракции
(`factions/`), предметы (`items/`), рация `/r`, команды
`/setfaction`, `/giveitem`, `/chardesc`.

**Модули** (`modules/`) — отключаются в схеме:
`NWORK.Config.DisabledModules.needs = true`.

| Модуль | Что делает |
|---|---|
| `recognition` | Знакомства: F3 или «Представиться», до этого — «Неизвестный» |
| `needs` | Сытость, жажда, бодрость: полосы, значки, статус «Вы устали.» |
| `objectives` | Строка «? Задание / 《 подзадача» слева сверху, `/objective` |
| `acts` | Колесо жестов на F2 |
| `combine` | Оверлей Альянса: компас, расписание, позывные союзников |
| `campath` | Путь камеры на фоне главного меню (задаётся в игре) |
| `bots` | Ботам — случайное имя, фракция и модель |

## Интерфейс

* **HUD** — стандартный HUD выключен полностью. Слева сверху — статусы, задание
  и уведомления; точка прицела; неймплейт (рамка с иконкой фракции или «?»,
  крупное имя, фракция), компактный — у NPC; реплики над головами; микрофон над
  говорящими; справа снизу — список говорящих и логотип; экран смерти с отсчётом.
* **Подсказка взаимодействия** снизу по центру: `E  Взять «Аптечка»`.
  E на предмете или игроке — список действий у прицела (колесо мыши, ЛКМ).
* **Чат** — строки как в Monarch: `Имя` серым, `говорит` жирным, реплика белым;
  рация голубым; `/me` курсивом; `(OOC)`/`(LOOC)` красной меткой. Открытый —
  плоская тёмная панель, перетаскивание, растяжение, список команд при «/».
* **Меню персонажа (Tab)** — модель, имя и фракция, слоты, эффекты и полосы
  состояния, хотбар оружия; справа колонка вкладок: Инвентарь, Фракция, Помощь,
  Игроки; снизу Админ, Правила, Настройки; логотип по центру снизу.
* **Главное меню, создание и выбор персонажа, интро** — как раньше, вместо
  текстового заголовка — логотип-надпись.

## Клавиши

| Клавиша | Действие |
|---|---|
| Tab | Меню персонажа |
| E | Взаимодействие |
| F1 | Помощь |
| F2 | Колесо жестов |
| F3 | Представиться |

## Чат

| Ввод | Что это |
|---|---|
| текст | Речь, ~320 юнитов |
| `/w` `/y` | Шёпот ~120, крик ~640 |
| `/me` `/it` | Действие, описание сцены |
| `/roll [макс]` | Кубик |
| `/r` | Рация (фракции с `Radio = true` или предмет «Рация») |
| `//` `.//` | OOC для всех, LOOC рядом |
| `/event` | Событие (админ) |

## Как расширять

```lua
-- фракция: schema/factions/sh_ota.lua
NWORK.Faction.Register( "ota", { Name = "Патруль Альянса", Combine = true, Radio = true,
	Models = { male = { "models/player/combine_soldier.mdl" } } } )

-- предмет: schema/items/sh_xxx.lua
NWORK.Item.Register( "ration", { Name = "Паёк", Model = "...", Category = "Еда",
	Actions = { open = { Name = "Открыть", Run = function( ply ) NWORK.Inventory.Give( ply, "bread", 2 ) return true end } } } )

-- команда
NWORK.Command.Add( "dice", { Args = "", Desc = "…", Run = function( ply, args, raw ) return "Ответ игроку" end } )

-- чат-класс
NWORK.Chat.Register( "dispatch", { Prefix = { "/dispatch" }, Admin = true, Desc = "…",
	CanSay = function( ply ) return ply:IsAdmin() end,
	Format = function( speaker, text ) return Color( 205, 72, 62 ), "Диспетчер: " .. text end } )

-- вкладка меню персонажа (клиент)
NWORK.UI.AddPage( "map", { Title = "КАРТА", Glyph = "key", Order = 50, Build = function( page, menu ) end } )

-- строка статуса слева сверху (клиент)
hook.Add( "NworkHUDStatus", "id", function( lines ) lines[ #lines + 1 ] = { text = "…" } end )
```

Хуки фреймворка: `NworkCharacterLoaded`, `NworkCharacterSave`,
`NworkCharacterUnloaded`, `NworkCharacterDeleted`, `NworkFactionChanged`,
`NworkPlayerReady`, `NworkPlayerSpawn`, `NworkLoadout`, `NworkInventoryChanged`,
`NworkCanUseItem`, `NworkChatSent`, `NworkValidateName`; на клиенте —
`NworkChatReceived`, `NworkInventoryUpdated`, `NworkHUDStatus`, `NworkHUDPaint`,
`NworkTabStats`, `NworkTabEffects`, `NworkOptionChanged`, `NworkCanRecognize`.

## Совместимость с 0.x

База персонажей та же (`nwork_characters`), новые колонки добавляются сами.
Персонажи, инвентари и знакомства сохраняются. Старые имена функций
(`NWORK.RegisterItem`, `NWORK.LoadCharacter`, `NWORK.PickupItem`,
`NWORK.FactionHasModel`) оставлены.

## Песочница

Пропы, энтити, NPC, машины и ноуклип — только админам
(`NWORK.Config.PlayerSandbox = true` открывает всем). Спавн- и контекст-меню —
только админам. Игроки получают руки, админы — ещё физган и тулган.
Голосовой чат слышно в радиусе `NWORK.Config.VoiceRange` (600).
