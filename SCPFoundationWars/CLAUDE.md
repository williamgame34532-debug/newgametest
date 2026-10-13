# SCP: Война за Фонд — заметки для Claude

Тактический шутер от первого лица на Unity (встроенный конвейер рендера, Built-in RP): отряды МОГ против Повстанцев Хаоса и
вырвавшихся SCP-объектов. Почти всё строится кодом во время игры — сцена `Assets/Scenes/Main.unity` пустая,
её создаёт `Editor/ScpSetup.cs` при первом открытии проекта.

## Как работать с проектом

- Unity 2021.3 LTS – 6.x, платформа сборки — **Windows, Mac, Linux (Standalone)** (иначе выключается Steamworks).
- Весь интерфейс — IMGUI (`OnGUI`), без префабов и UI-канваса.
- Модели, звуки, текстуры лежат в `Assets/Resources/**` и грузятся `Resources.Load` по имени — не переименовывать файлы.
- Тексты игры и комментарии в коде — по-русски; стиль кода: короткие методы, `static` фабрики `Create(...)`, без LINQ в горячих местах.
- Шейдеры — `Assets/Shaders/*.shader` (CG/HLSL, Built-in RP). Новый шейдер, которого нет в сцене, нужно добавить в список
  `IncludeShaders()` в `Editor/ScpSetup.cs`, иначе он пропадёт из сборки.

## MCP: Claude управляет редактором Unity

В проект добавлен пакет **MCP for Unity** (`Packages/manifest.json` → `com.coplaydev.unity-mcp`, MIT) и конфиг `.mcp.json`.

1. Нужны `git` и Python-менеджер [`uv`](https://docs.astral.sh/uv/) (`winget install astral-sh.uv` на Windows).
2. Откройте проект в Unity → `Window → MCP for Unity` → **Start Server** (или «Configure All Detected Clients»).
3. В папке проекта запустите `claude` — сервер `unityMCP` из `.mcp.json` подключится автоматически
   (адрес по умолчанию `http://localhost:8080/mcp`).
4. Теперь можно просить: «запусти Play и сделай скриншот», «найди ошибки в консоли», «покажи иерархию сцены».

Если HTTP не работает, замените запись в `.mcp.json` на stdio:
`{"command": "uvx", "args": ["--from", "mcpforunityserver", "mcp-for-unity", "--transport", "stdio"]}`.

## Карта кода (`Assets/Scripts`)

| Папка | Что внутри |
|---|---|
| `Core/` | `Game` (меню, настройки, камера), `Data` (оружие, отряды, SCP), `Mats` (материалы, фото-текстуры), `MeshKit` (примитивы и склейка мешей), `ModelX`/`ModelLib` (формат моделей SCPX), `PostFX` (постобработка, визор, bodycam), `WorldFX` (SSAO, атмосфера, глубина резкости, размытие движения, объёмный свет ламп), `Sfx`, `Operations` (сценарии) |
| `World/` | `Battle` (запуск боя, высадка, отряды), `MapGen`/`Nature`/`Site19`/`Fob` (генерация карт), `Facility` (подземный комплекс из комнат SCP:CB), `PropKit` (сканированные предметы из `Resources/Props`), `Weather` (дождь), `Helicopter`, `Intro`, `Cinematic`, `Commander` (ИИ командиров сторон) |
| `Human/` | `Soldier` (ИИ бойца: цели, укрытия, слух, страх, переговоры), `HumanAnimator`/`HumanRig`/`Mocap` (процедурная анимация), `Ragdoll`, `Dismember` |
| `Player/` | `PlayerController` (движение, оружие, жесты на G, приказы отряду), `FPView` (руки и оружие от первого лица), `FPArms*` (меш рук) |
| `Scp/` | все SCP-объекты (`Scps.cs`), четвероногие (`Quadruped`: 939, 682) |
| `Combat/` | `Unit` (здоровье, урон, взрывы), `Weapons` (оружие, ракеты, гранаты), `Hearing` (шум → реакция ИИ), `LoreItem` (средства содержания) |
| `Net/` | сетевая игра: хост считает бой, клиенты получают снимки (UDP или Steam P2P) |
| `UI/` | `GameUI` (меню, HUD, круговое меню), `LoadingScreen`, `NetGUI`, `Speech` (реплики над головой) |

## Важные соглашения

- Сетевая игра: всё, что создаёт юнитов, должно идти в одинаковом порядке у хоста и клиента (`Net.Assign`); случайность — через
  `Random` после `Random.InitState(cfg.seed)`.
- Вид по умолчанию — «маска шлема» (`PostFX.ViewMode`: 0 — маска, 1 — bodycam, 2 — обычный).
- Слои: `Layers.World` — статичная геометрия (её запекает навмеш), `Layers.ViewModel` — оружие от первого лица (своя камера).
- Проверка сборки без редактора невозможна полностью: шейдеры компилирует только Unity — после правок шейдеров смотрите консоль.

## Лицензии ресурсов

См. `CREDITS.txt` в каждой папке `Assets/Resources/*`: Poly Haven (CC0), SCP: Containment Breach (CC BY-SA 3.0),
shadow-six (CC0), Kenney (CC0) и др. Материалы SCP — по лицензии CC BY-SA 3.0 (scpwiki.com).
