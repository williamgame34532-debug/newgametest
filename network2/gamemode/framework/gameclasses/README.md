# Классы фракций — файлы

Один файл — один класс: `<id>.lua` (имя файла — ID класса). Сервер читает папку при запуске.

```lua
CLASS.faction = "cp"                      -- ID фракции (имя файла в gamefactions)
CLASS.name = "Рекрут ГО"
CLASS.description = "Описание для игроков."
CLASS.color = Color(90, 150, 230)
CLASS.health = 100                        -- здоровье и его максимум
CLASS.armor = 25                          -- броня на каждом спавне
CLASS.walk = 100                          -- скорость шага
CLASS.run = 200                           -- скорость бега
CLASS.models = {"models/network/cp/networkcp.mdl"}   -- игрок выбирает одну
CLASS.skin = 0
CLASS.items = {"stunstick", "radio"}      -- выдаются один раз
CLASS.limit = 0                           -- мест (0 — без лимита)
CLASS.adminOnly = false                   -- назначает только админ (/setclass)
CLASS.default = true                      -- даётся при вступлении во фракцию
```

Поля можно не указывать — тогда по умолчанию (здоровье 100, скорости сервера, модель фракции).
Класс из файла можно поменять в игре (`/classedit`): изменения хранятся в `data/network2/classes.json`
поверх файла; «Удалить» в редакторе сбрасывает их к файлу. Чтобы убрать класс совсем — удалите файл.
