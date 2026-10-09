--[[-------------------------------------------------------------------------
	N-work — конфигурация по умолчанию.

	Схема (schema/sh_schema.lua) переопределяет любые значения простым
	присваиванием: NWORK.Config.MaxCharacters = 3
---------------------------------------------------------------------------]]

NWORK.Config = NWORK.Config or {}
local C = NWORK.Config

-- Персонажи
C.MaxCharacters = 1           -- сколько персонажей можно завести
C.CreateFaction = "citizen"   -- фракция новых персонажей
C.MinName       = 3           -- длина имени, символов
C.MaxName       = 32
C.MinDesc       = 10          -- длина описания
C.MaxDesc       = 512
C.AutoSave      = 120         -- автосохранение, секунд
C.RespawnTime   = 5           -- задержка возрождения после смерти

-- Интро после создания персонажа
C.IntroTitle = "ГОРОД ДВАДЦАТЬ ЧЕТЫРЕ"
C.IntroSub   = "ЗА ЧЕТЫРЕ ГОДА ДО ВОССТАНИЯ"

-- Инвентарь
C.InvSlots    = 20
C.PickupRange = 130
C.StartItems  = {}            -- { { id = "cola", n = 1 }, ... }

-- Чат: дистанции слышимости, юниты (nil = слышно всем)
C.ChatRange = {
	talk    = 320,
	whisper = 120,
	yell    = 640,
	me      = 400,
	looc    = 320,
}
C.ChatMaxLength = 500

-- Голосовой чат: дистанция слышимости (3D-звук), юниты
C.VoiceRange = 600

-- Знакомства
C.IntroduceRange = 250

-- Оружие
C.HandsWeapon   = "nwork_hands"
C.AdminLoadout  = { "weapon_physgun", "gmod_tool" }

-- Песочница: могут ли обычные игроки спавнить пропы, энтити, NPC и т.д.
C.PlayerSandbox = false

-- Модули, которые не нужно загружать: { needs = true }
C.DisabledModules = {}
