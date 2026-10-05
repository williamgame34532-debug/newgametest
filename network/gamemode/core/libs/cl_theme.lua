NETWORK.theme = NETWORK.theme or {}

NETWORK.theme.background = Color(6, 7, 8)
NETWORK.theme.plate = Color(13, 14, 16)
NETWORK.theme.plateBright = Color(21, 23, 25)
NETWORK.theme.plateDeep = Color(9, 10, 11)
NETWORK.theme.accent = Color(178, 184, 190)
NETWORK.theme.accentDeep = Color(88, 93, 99)
NETWORK.theme.accentSoft = Color(226, 230, 234)
NETWORK.theme.text = Color(232, 232, 230)
NETWORK.theme.textDim = Color(158, 160, 162)
NETWORK.theme.textFaint = Color(104, 106, 110)
NETWORK.theme.line = Color(74, 78, 83)
NETWORK.theme.value = Color(206, 210, 214)

NETWORK.theme.hover = Color(228, 176, 104)

NETWORK.theme.combine = Color(86, 150, 226)
NETWORK.theme.combineDeep = Color(40, 78, 128)
NETWORK.theme.combineSoft = Color(150, 196, 246)

NETWORK.theme.danger = Color(232, 84, 76)
NETWORK.theme.warning = Color(240, 186, 74)
NETWORK.theme.positive = Color(96, 224, 140)

-- PDA palette (navy plates, hairlines, uppercase captions): shared by the PDA, tooltips, the
-- inventory, the main menu and the character screens.
NETWORK.theme.pda = {
	bg = Color(10, 22, 36),
	bg2 = Color(15, 31, 49),
	deep = Color(7, 15, 25),
	line = Color(44, 70, 96),
	lineSoft = Color(27, 45, 64),
	text = Color(228, 238, 246),
	muted = Color(122, 146, 168),
	faint = Color(84, 106, 128),
	accent = Color(104, 170, 228),
	good = Color(110, 200, 150),
	warn = Color(232, 176, 86),
	bad = Color(230, 92, 84)
}

NETWORK.theme.inv = {
	background = Color(6, 13, 22),
	panel = Color(10, 22, 36),
	panelBright = Color(15, 31, 49),
	cell = Color(11, 23, 37),
	cellTop = Color(7, 15, 25),
	cellBright = Color(20, 38, 58),
	line = Color(44, 70, 96),
	lineSoft = Color(27, 45, 64),
	accent = NETWORK.theme.combine,
	accentDeep = NETWORK.theme.combineDeep,
	accentSoft = NETWORK.theme.combineSoft,
	text = Color(228, 238, 246),
	textDim = Color(150, 172, 192),
	textFaint = Color(96, 118, 140),
	select = NETWORK.theme.combine,
	positive = Color(96, 224, 140),
	warning = Color(240, 186, 74),
	danger = Color(232, 84, 76)
}

NETWORK.theme.inv.plate = NETWORK.theme.inv.panel
NETWORK.theme.inv.plateBright = NETWORK.theme.inv.panelBright
NETWORK.theme.inv.plateDeep = NETWORK.theme.inv.background
NETWORK.theme.inv.value = NETWORK.theme.inv.accent

NETWORK.theme.create = {
	background = Color(13, 14, 15),
	backdrop = Color(24, 26, 28),
	panel = Color(22, 24, 26),
	cell = Color(19, 20, 22),
	cellBright = Color(32, 35, 38),
	line = Color(74, 78, 83),
	lineSoft = Color(44, 47, 50),
	text = Color(232, 232, 230),
	textDim = Color(158, 160, 162),
	textFaint = Color(104, 106, 110),
	title = Color(214, 218, 222),
	select = Color(226, 230, 234),
	button = Color(18, 19, 21),
	error = Color(232, 84, 76),
	ok = Color(96, 224, 140)
}
