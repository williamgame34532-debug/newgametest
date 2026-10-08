HLARP.Config = HLARP.Config or {}
local cfg = HLARP.Config

cfg.ServerName = "Network - HL:A RP"

cfg.Colors = {
	Primary    = Color(255, 77, 59),   -- акцент логотипа
	Combine    = Color(70, 190, 230),
	Background = Color(18, 20, 24),
	Text       = Color(236, 238, 240),
}

-- Стандартные HUD-элементы, которые НЕ скрываются.
-- Все остальные (здоровье, броня, патроны, прицел, выбор оружия, чат,
-- урон, фонарик, подсказки и т.д.) выключены.
-- CHudGMod обязателен: без него не вызываются HUDPaint-хуки.
-- Чтобы вернуть стандартный чат или выбор оружия до появления своих —
-- добавьте сюда "CHudChat" / "CHudWeaponSelection".
cfg.HUDWhitelist = {
	CHudGMod = true,
}
