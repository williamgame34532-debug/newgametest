# framework — фракции и предметы

Всё, что здесь лежит, подхватывается само при запуске сервера. Новый файл — новая фракция или
новый предмет, править ядро не нужно. В самих файлах нет комментариев: только данные.

## gamefactions — фракции

Одна фракция — один файл: `gamefactions/<id>.lua`. `id` — имя файла (`citizen.lua` → `citizen`).

```lua
FACTION.name = "Гражданин"
FACTION.description = "Кто это и как живёт."
FACTION.color = Color(200, 206, 212)
FACTION.logo = "citizen_logo"
FACTION.default = true

FACTION.models = {
	male = {"models/network/citizens/male01.mdl", "..."},
	female = {"models/network/citizens/female_01.mdl", "..."}
}
```

| Поле | Что это |
|---|---|
| `name` | название, видно в инвентаре, TAB и выборе персонажа |
| `description` | описание фракции |
| `color` | цвет: иконка над головой, подписи |
| `logo` | иконка: `materials/network2/factions/<logo>.png` (белая, 128 px) |
| `default` | `true` — эту фракцию получают новые персонажи (такая должна быть одна) |
| `models` | модели по полу; эти модели предлагаются при создании персонажа |

Готовые логотипы: `citizen_logo`, `civilprotection_logo`, `combineclaw_logo`,
`combineclaw_full_logo`, `combineclaw_upright_logo`, `engineercore_logo`, `headcrab_logo`.

## items — предметы

```
items/
  base/        базы: что общего у всех предметов одного вида
  food/        еда
  drink/       напитки
  medical/     медицина
  weapons/     оружие
  clothing/    одежда (+ _wardrobe.lua — все варианты одежды моделей граждан)
  bags/        сумки
  packages/    упаковки (рацион)
  junk/        мусор
```

Один предмет — один файл `items/<группа>/<id>.lua`, `id` — имя файла. Новую группу можно
создать просто новой папкой. Предмет берёт всё из своей базы (`ITEM.base`) и меняет то, что
указано в файле:

```lua
ITEM.base = "drink"

ITEM.name = "Вода"
ITEM.description = "Пластиковая бутылка фильтрованной воды."
ITEM.model = "models/props_junk/garbage_plasticbottle003a.mdl"
ITEM.thirst = 40
ITEM.leaves = "bottle_empty"
```

### Базы (`items/base/`)

| База | Для чего | Что задаёт |
|---|---|---|
| `food` | еда | категория, модель, звук еды |
| `drink` | питьё | категория, модель, звук питья |
| `medical` | медицина | категория, аптечка, звук |
| `weapon` | оружие | категория, слот «Вторичное» |
| `clothing` | одежда | категория, коробка как модель в мире |
| `bag` | сумки | слот «Сумка», модель, иконка |
| `package` | упаковки | категория, модель пакета |
| `junk` | мусор | категория, модель |

Своя база — файл в `items/base/` с полями `BASE.<поле> = ...`.

### Поля предмета

| Поле | Что это |
|---|---|
| `name`, `description` | название и описание (подсказка, надпись в мире, панель «Взять») |
| `model` | модель (в ячейке и в мире) |
| `icon` | иконка `materials/network2/items/<icon>.png` (надпись в мире); по умолчанию — id |
| `hunger`, `thirst`, `heal` | сколько восстанавливает (еда, питьё, медицина тратятся) |
| `useSound` | звук при использовании |
| `leaves` | что остаётся после использования (id мусора) |
| `slot` | слот экипировки: `primary`, `secondary`, `melee`, `head`, `face`, `torso`, `hands`, `legs`, `feet`, `bag` |
| `weapon` | SWEP, который выдаётся, пока предмет в слоте оружия |
| `wear` | одежда: `{group = "<бодигруппа>", index = <вариант>}` |
| `bag` | сколько ячеек даёт сумка в слоте «Сумка» |
| `contents` | что внутри упаковки: `{"id", "id", ...}` (распаковка зажатием) |
| `OnUse` | `function(client, cell)` — своё действие при использовании; `return false` — не тратить |

Выдать предмет: `nw_giveitem <id> [кол-во]`, положить в мир: `nw_spawnitem <id>`.
