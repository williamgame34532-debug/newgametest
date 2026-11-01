-- Story / rounds (shared): chapters with spawns and transition triggers, the vote before a round
-- (story, PvP by teams, PvP each for himself), spectators, PvP settings, story NPCs and the dispatcher.
-- Everything is set per map in the editor (hla_editor, admins) and kept in data/hla/story/<map>.json.
HLA = HLA or {}
local S = HLA.Story or {}
HLA.Story = S

-- round states (GetGlobal2String('hla_state'))
S.WAIT, S.VOTE, S.STORY, S.PVP, S.END = 'wait', 'vote', 'story', 'pvp', 'end'
-- vote choices
S.CHOICES = {
	{id = 'story', label = 'СЮЖЕТ'},
	{id = 'teams', label = 'ПВП — ПО КОМАНДАМ'},
	{id = 'ffa', label = 'ПВП — КАЖДЫЙ САМ ЗА СЕБЯ'},
}
S.TEAM1, S.TEAM2 = 1, 2

-- models offered for story NPCs: only those installed are shown in the editor (any path can be typed too)
S.NPCModels = {
	{label = 'ГРАНТ', model = 'models/cultist/hl_a/combine_grunt/combine_grunt.mdl', weapon = 'tfa_osips'},
	{label = 'ОРДИНАЛ', model = 'models/cultist/hl_a/combine_ordinal/combine_ordinal.mdl', weapon = 'tfa_ocipr'},
	{label = 'ОРДИНАЛ', model = 'models/cultist/hl_a/combine_officer/combine_officer.mdl', weapon = 'tfa_ocipr'},
	{label = 'ОРДИНАЛ', model = 'models/nemez/combine_soldiers/combine_soldier_coordinator_h.mdl', weapon = 'tfa_ocipr'},
	{label = 'РАЗВЕДЧИК', model = 'models/nemez/combine_soldiers/combine_soldier_recon_h.mdl', weapon = 'weapon_csniper_tfa2'},
	{label = 'СОЛДАТ HL2', model = 'models/combine_soldier.mdl', weapon = 'weapon_ar2'},
	{label = 'ЭЛИТА HL2', model = 'models/combine_super_soldier.mdl', weapon = 'weapon_ar2'},
}

function S.Default()
	return {
		chapters = {{title = 'ГЛАВА 1', name = 'НАЧАЛО', sub = '', spawns = {}, dispatch = ''}},
		pvp = {team1 = 'ОТРЯД АЛЬФА', team2 = 'ОТРЯД ОМЕГА', time = 8, friendly = false,
			spawns = {ffa = {}, t1 = {}, t2 = {}}},
		npcs = {},
		dispatch = {every = 0, pool = {}, custom = {}, edits = {}},
		settings = {minPlayers = 2, voteTime = 20, cardTime = 7, killCallout = true, storyFriendlyFire = false,
			killLines = {'Противник нейтрализован.', 'Цель уничтожена.', 'Ликвидация подтверждена.'},
			killLinesPlayer = {'Цель один затихла.', 'Мёртв.', 'Ликвидация подтверждена.'}},
	}
end

-- fill missing keys of a loaded config from the defaults (older files, hand edits)
function S.Normalize(c)
	local d = S.Default()
	if not istable(c) then return d end
	local function fill(dst, src)
		for k, v in pairs(src) do
			if dst[k] == nil or type(dst[k]) ~= type(v) then dst[k] = v
			elseif istable(v) and not v[1] and next(v) then fill(dst[k], v) end
		end
	end
	fill(c, d)
	if #c.chapters == 0 then c.chapters = d.chapters end
	for _, ch in ipairs(c.chapters) do
		ch.title = tostring(ch.title or '') ch.name = tostring(ch.name or '') ch.sub = tostring(ch.sub or '')
		ch.spawns = istable(ch.spawns) and ch.spawns or {}
		ch.dispatch = tostring(ch.dispatch or '')
	end
	return c
end

-- the text of a dispatcher line: the admin's own edit, the built-in line or an own line
function S.DispatchText(cfg, id)
	local own = cfg and cfg.dispatch
	if own and own.edits and own.edits[id] and own.edits[id] ~= '' then return own.edits[id] end
	local l = HLA.DispatchByID and HLA.DispatchByID[id]
	if l then return l.ru, l.snd end
	for _, c in ipairs(own and own.custom or {}) do
		if c.id == id then return c.ru, c.snd end
	end
end

function S.State() return GetGlobal2String('hla_state', S.WAIT) end
function S.Mode() return GetGlobal2String('hla_mode', '') end
function S.InRound() local s = S.State() return s == S.STORY or s == S.PVP end

-- a point inside a trigger box {a = {x,y,z}, b = {x,y,z}}
function S.Inside(box, pos)
	if not box or not box.a or not box.b then return false end
	local a, b = box.a, box.b
	return pos.x >= math.min(a[1], b[1]) and pos.x <= math.max(a[1], b[1])
		and pos.y >= math.min(a[2], b[2]) and pos.y <= math.max(a[2], b[2])
		and pos.z >= math.min(a[3], b[3]) and pos.z <= math.max(a[3], b[3])
end

team.SetUp(S.TEAM1, 'ОТРЯД АЛЬФА', Color(110, 200, 255))
team.SetUp(S.TEAM2, 'ОТРЯД ОМЕГА', Color(236, 96, 72))
