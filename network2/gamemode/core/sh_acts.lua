-- Poses (the G wheel → Анимации) and the voice range (the G wheel → Голос).
-- A pose is a looping sequence of the citizen models (the WN "willard" ones and ours). It is not
-- started on the spot: the wheel opens a placement with a see-through preview of the character
-- in that pose, and the place must suit it (A.CheckSpot):
--   floor    standing poses - firm, flat ground with room to stand;
--   ground   sitting or kneeling on the ground - flat ground, room above;
--   lie      lying - flat ground with room for the body;
--   seat     sitting - something to sit on behind (12..28 units high), the feet on the ground;
--   wall     leaning - a wall right behind;
--   wallsit  sitting against a wall - a wall behind, flat ground.
-- Never higher than the player's own feet (+18), never farther than 110 units, never through a
-- wall. The place must be free: nothing solid and nobody in the space of the pose, and right next
-- to it a free place to stand up at (A.ExitSpot) that the player's whole body can get to - from the
-- pose and from where the player stands now. So getting up never puts anyone behind a wall, through
-- bars or a gap, or inside a prop. The place to stand up at is chosen when the pose starts; the pose
-- plays until the player moves, jumps, crouches or attacks, then the player stands up there.
-- Voice: Шёпот (150 units), Обычный (550), Крик (1100); others hear you in 3D within that range.

NW.acts = NW.acts or {}

local A = NW.acts
local meta = FindMetaTable("Player")

-- id, name, icon, place, variants (sequence name endings, or "=" full names)
A.list = {
	{id = "sit", name = "Сесть", icon = "act_sit", place = "seat", variants = {"sit01", "sit02", "sit03", "sit04",
		"sit05", "sit06", "sit07"}},
	{id = "ground", name = "Сесть на землю", icon = "act_ground", place = "ground", variants = {"sit_ground"}},
	{id = "wall", name = "Сесть у стены", icon = "act_wall", place = "wallsit", variants = {"sitwall"}},
	{id = "lie", name = "Лечь", icon = "act_lie", place = "lie", variants = {"down01", "down02", "down03"}},
	{id = "injured", name = "Раненый", icon = "act_injured", place = "ground", variants = {"injured", "=nw_hla_wounded"}},
	{id = "handsup", name = "Руки вверх", icon = "act_handsup", place = "floor", variants = {"handsup"}},
	{id = "arrest", name = "Арест", icon = "act_arrest", place = "floor", variants = {"arrest", "arrest_sit01"}},
	{id = "lean", name = "Опереться", icon = "act_lean", place = "wall", variants = {"lean01", "lean02",
		"=nw_civ_lean"}},
	{id = "stand", name = "Стоять", icon = "act_stand", place = "floor", variants = {"stand01", "stand02", "stand03",
		"stand04", "stand05"}},
	{id = "check", name = "Осмотреться", icon = "act_check", place = "floor", variants = {"check"}},
	{id = "kneel", name = "На колено", icon = "act_kneel", place = "floor", variants = {"=nw_civ_kneel", "=nw_hla_kneel"}},
	{id = "shiver", name = "Дрожать", icon = "act_shiver", place = "floor", variants = {"=nw_civ_shiver"}},
	-- Civil Protection (HL:A motion capture on networkcp; "only" - hidden from models without them)
	{id = "cp_report", name = "Доклад", icon = "act_check", place = "floor", variants = {"=nw_hla_chat"}, only = true},
	{id = "cp_interrogate", name = "Допрос", icon = "act_arrest", place = "floor", variants = {"=nw_hla_interrogate"},
		only = true},
	{id = "cp_guard", name = "На посту", icon = "act_foldarms", place = "floor", variants = {"=nw_hla_idle_05",
		"=nw_hla_idle_06", "=nw_hla_idle_03"}, only = true}
}

A.byID = {}

for _, act in ipairs(A.list) do
	A.byID[act.id] = act
end

A.voice = {
	{id = 1, name = "Шёпот", icon = "voice_whisper", range = 150},
	{id = 2, name = "Обычный", icon = "voice_normal", range = 550},
	{id = 3, name = "Крик", icon = "voice_yell", range = 1100}
}

A.reach = 110

local PREFIXES = {"willard_male_male_", "willard_female_"}

-- the sequence of a variant on this entity (or nil)
function A.Resolve(entity, variant)
	if (string.sub(variant, 1, 1) == "=") then
		local name = string.sub(variant, 2)

		return entity:LookupSequence(name) > 0 and name or nil
	end

	for _, prefix in ipairs(PREFIXES) do
		if (entity:LookupSequence(prefix .. variant) > 0) then
			return prefix .. variant
		end
	end
end

-- the variants of a pose this model really has
function A.Available(entity, act)
	local out = {}

	for _, variant in ipairs(act.variants) do
		local name = A.Resolve(entity, variant)

		if (name) then
			out[#out + 1] = name
		end
	end

	return out
end

-- ------------------------------------------------------------------ places --
local HEIGHT = {floor = 70, ground = 44, lie = 20, seat = 50, wall = 70, wallsit = 44}
local WIDTH = {floor = 12, ground = 14, lie = 24, seat = 12, wall = 12, wallsit = 14}

local function Floor(pos, filter)
	local trace = util.TraceLine({start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 16),
		mask = MASK_PLAYERSOLID, filter = filter})

	if (trace.Hit and trace.HitNormal.z > 0.7) then
		return trace.HitPos
	end
end

-- the standing hull of the player
local function Hull(client)
	local mins, maxs = client:GetHull()

	return mins, maxs
end

-- can the player stand at pos (the standing hull, nothing solid and nobody else in it)?
local function Free(client, pos)
	local mins, maxs = Hull(client)
	local trace = util.TraceHull({start = pos, endpos = pos, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID,
		filter = client})

	return !trace.StartSolid and !trace.AllSolid
end

local STEP = 18

-- could the whole body walk from a to b in a straight line (steps up to STEP allowed)?
local function Walkable(client, a, b)
	local mins, maxs = Hull(client)
	local lift = Vector(0, 0, STEP)
	local trace = util.TraceHull({start = a + lift, endpos = b + lift, mins = mins, maxs = maxs - lift,
		mask = MASK_PLAYERSOLID, filter = client})

	return !trace.StartSolid and !trace.Hit
end

-- can the body get from the pose at pos to the spot? The pose itself may be in a seat or against a
-- wall, so a thin column starts there; the whole body must then come back from the spot right up
-- to the pose, and nothing may stand in between at the knees or the chest.
local function Leaves(client, pos, spot)
	local column = util.TraceHull({start = pos + Vector(0, 0, 30), endpos = spot + Vector(0, 0, 30),
		mins = Vector(-6, -6, 0), maxs = Vector(6, 6, 30), mask = MASK_PLAYERSOLID, filter = client})

	if (column.StartSolid or column.Hit) then
		return false
	end

	for _, h in ipairs({24, 50}) do
		local line = util.TraceLine({start = pos + Vector(0, 0, h), endpos = spot + Vector(0, 0, h),
			mask = MASK_PLAYERSOLID, filter = client})

		if (line.Hit) then
			return false
		end
	end

	local mins, maxs = Hull(client)
	local back = util.TraceHull({start = spot + Vector(0, 0, 2), endpos = pos + Vector(0, 0, 2), mins = mins,
		maxs = maxs, mask = MASK_PLAYERSOLID, filter = client})
	local gap = (spot - pos):Length2D()

	return !back.StartSolid and (1 - back.Fraction) * gap <= 22
end

-- the nearest place to stand up at from a pose at pos: pos itself, or around it (on the floor, that
-- the body can really get to - not through a wall, bars or a gap), or nil. With from, the place must
-- also be reachable on foot from there (where the player stood when the pose started).
function A.ExitSpot(client, pos, from)
	local lift = Vector(0, 0, 2)
	local function Good(spot)
		return !from or spot:DistToSqr(from) < 4 or Walkable(client, from, spot)
	end

	if (Free(client, pos + lift) and Good(pos + lift)) then
		return pos + lift
	end

	for _, radius in ipairs({16, 24, 32, 40}) do
		for step = 0, 11 do
			local angle = math.rad(step * 30)
			local spot = pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			local down = util.TraceLine({start = spot + Vector(0, 0, 24), endpos = spot - Vector(0, 0, 32),
				mask = MASK_PLAYERSOLID, filter = client})

			if (down.Hit and !down.StartSolid and down.HitNormal.z > 0.7) then
				spot = down.HitPos + lift

				if (math.abs(spot.z - pos.z) <= STEP and Free(client, spot) and Leaves(client, pos, spot) and
					Good(spot)) then
					return spot
				end
			end
		end
	end
end

-- is the place right for this pose? returns the corrected position or nil and why
function A.CheckSpot(client, act, pos, yaw)
	local origin = client:GetPos()

	if (pos.z > origin.z + 18) then
		return nil, "Нельзя выше себя"
	end

	if (pos.z < origin.z - 72 or (pos - origin):Length2D() > A.reach) then
		return nil, "Слишком далеко"
	end

	local floor = Floor(pos, client)

	if (!floor) then
		return nil, "Нужна ровная земля"
	end

	pos = floor

	-- seen from the eyes (not through walls)
	local sight = util.TraceLine({start = client:EyePos(), endpos = pos + Vector(0, 0, 16),
		mask = MASK_SOLID_BRUSHONLY, filter = client})

	if (sight.Hit and sight.HitPos:DistToSqr(pos + Vector(0, 0, 16)) > 16 * 16) then
		return nil, "Место не видно"
	end

	-- room for the body: nothing solid and nobody else in the space of the pose
	local place = act.place or "floor"
	local w = WIDTH[place]
	local room = util.TraceHull({start = pos + Vector(0, 0, 2), endpos = pos + Vector(0, 0, 2),
		mins = Vector(-w, -w, 0), maxs = Vector(w, w, HEIGHT[place]), mask = MASK_PLAYERSOLID, filter = client})

	if (room.StartSolid) then
		return nil, "Здесь тесно"
	end

	-- standing poses: the whole body fits right there (getting up does not move the player)
	if (place == "floor" and !Free(client, pos + Vector(0, 0, 2))) then
		return nil, "Здесь тесно"
	end

	-- somewhere free to stand up at afterwards, on this side of any wall
	if (!A.ExitSpot(client, pos, client:GetPos())) then
		return nil, "Отсюда будет не встать"
	end

	local back = -Angle(0, yaw, 0):Forward()

	if (place == "seat") then
		-- something to sit on right behind
		local probe = pos + back * 14
		local seat = util.TraceLine({start = probe + Vector(0, 0, 32), endpos = probe + Vector(0, 0, 6),
			mask = MASK_PLAYERSOLID, filter = client})
		local height = seat.HitPos.z - pos.z

		if (!seat.Hit or seat.StartSolid or height < 12 or height > 28 or seat.HitNormal.z < 0.6) then
			return nil, "Сесть можно только на что-то: стул, скамью, ящик"
		end
	elseif (place == "wall" or place == "wallsit") then
		-- a wall right behind
		local h = place == "wall" and 40 or 24
		local wall = util.TraceLine({start = pos + Vector(0, 0, h), endpos = pos + Vector(0, 0, h) + back * 24,
			mask = MASK_PLAYERSOLID, filter = client})

		if (!wall.Hit or math.abs(wall.HitNormal.z) > 0.35) then
			return nil, "Нужна стена за спиной"
		end
	end

	return pos
end

-- where the pose goes for what the player aims at (client preview; the server checks again)
function A.FindSpot(client, act, trace, turn)
	local place = act.place or "floor"
	local toPlayer = client:GetPos() - trace.HitPos

	toPlayer.z = 0
	toPlayer:Normalize()

	local pos, yaw

	if ((place == "wall" or place == "wallsit") and math.abs(trace.HitNormal.z) < 0.35) then
		-- aiming at a wall: in front of it, the back to it
		pos = trace.HitPos + trace.HitNormal * (place == "wall" and 14 or 16)
		yaw = trace.HitNormal:Angle().y
	elseif (place == "seat" and trace.HitNormal.z > 0.6) then
		-- aiming at a seat: in front of it, facing the player
		pos = trace.HitPos + toPlayer * 14
		yaw = toPlayer:Angle().y
	else
		pos = trace.HitPos
		yaw = toPlayer:Angle().y
	end

	yaw = yaw + (turn or 0)

	-- down to the floor
	local down = util.TraceLine({start = pos + Vector(0, 0, 8), endpos = pos - Vector(0, 0, 64),
		mask = MASK_PLAYERSOLID, filter = client})

	pos = down.HitPos

	local checked, why = A.CheckSpot(client, act, pos, yaw)

	return checked or pos, yaw, checked != nil, why
end

-- ----------------------------------------------------------------- players --
function meta:GetAct()
	local name = self:GetNW2String("nwAct", "")

	return name != "" and name or nil
end

function meta:GetVoiceMode()
	return math.Clamp(self:GetNW2Int("nwVoiceMode", 2), 1, 3)
end

-- the animation engine (sh_animhooks.lua) plays this sequence instead of the normal ones
function meta:GetForcedSequence()
	local name = self:GetAct()

	if (!name) then
		self.nwActCache = nil

		return
	end

	if (!self.nwActCache or self.nwActCache.name != name or self.nwActCache.model != self:GetModel()) then
		local sequence = self:LookupSequence(name)

		self.nwActCache = {name = name, model = self:GetModel(), sequence = sequence > 0 and sequence or nil}
		self.nwSeqBlendStart = CurTime()
		self:SetCycle(0)
	end

	return self.nwActCache.sequence
end

if (SERVER) then
	util.AddNetworkString("nwAct")
	util.AddNetworkString("nwVoice")

	local function Notice(client, text)
		net.Start("nwChatNotice")
			net.WriteString(text)
		net.Send(client)
	end

	-- out of the pose: on the place chosen when it started (if it is still free), else on the
	-- nearest free place the body can get to; never in a wall, a seat or behind a wall
	function A.Stop(client)
		if (!client:GetAct()) then
			return
		end

		client:SetNW2String("nwAct", "")

		if (client:Alive() and !client:InVehicle()) then
			local pos = client:GetPos()
			local spot = client.nwActExit

			if (!spot or !Free(client, spot)) then
				spot = A.ExitSpot(client, client.nwActSpot or pos, client.nwActFrom) or
					A.ExitSpot(client, client.nwActSpot or pos) or client.nwActFrom
			end

			if (spot and spot:DistToSqr(pos) > 4) then
				client:SetPos(spot)
				client:SetVelocity(-client:GetVelocity())
			end
		end

		client.nwActExit, client.nwActSpot, client.nwActFrom = nil, nil, nil
	end

	function A.Start(client, id, index, pos, yaw)
		local act = A.byID[id or ""]

		if (!act or !client:Alive() or client:GetCharacterID() == 0 or client:InVehicle() or !client:OnGround() or
			client:GetMoveType() != MOVETYPE_WALK) then
			return
		end

		local list = A.Available(client, act)

		if (#list == 0) then
			return Notice(client, "Эта модель не умеет: " .. act.name)
		end

		local spot, why = A.CheckSpot(client, act, pos, yaw)

		if (!spot) then
			return Notice(client, why or "Сюда нельзя")
		end

		local from = client:GetPos()
		local exit = A.ExitSpot(client, spot, from)

		if (!exit) then
			return Notice(client, "Отсюда будет не встать")
		end

		-- empty hands, weapon down, into place
		if (client:HasWeapon("nw_hands")) then
			client:SelectWeapon("nw_hands")
		end

		client:SetNW2Bool("nwRaised", false)
		client:SetPos(spot)
		client:SetEyeAngles(Angle(0, yaw, 0))
		client:SetVelocity(-client:GetVelocity())
		client:SetNW2Float("nwActYaw", yaw)
		client:SetNW2String("nwAct", "")
		client:SetNW2String("nwAct", list[math.Clamp(index, 1, #list)])
		client.nwActStarted = CurTime()
		client.nwActSpot, client.nwActExit, client.nwActFrom = spot, exit, from
	end

	net.Receive("nwAct", function(_, client)
		local id = net.ReadString()

		if ((client.nwActNext or 0) > CurTime()) then
			return
		end

		client.nwActNext = CurTime() + 0.4

		if (id == "") then
			A.Stop(client)

			return
		end

		local index = net.ReadUInt(4)
		local pos = net.ReadVector()
		local yaw = math.NormalizeAngle(net.ReadFloat())

		A.Start(client, id, index, pos, yaw)
	end)

	net.Receive("nwVoice", function(_, client)
		client:SetNW2Int("nwVoiceMode", math.Clamp(net.ReadUInt(2), 1, 3))
	end)

	-- any movement drops the pose
	local STOP = {[IN_FORWARD] = true, [IN_BACK] = true, [IN_MOVELEFT] = true, [IN_MOVERIGHT] = true,
		[IN_JUMP] = true, [IN_DUCK] = true, [IN_ATTACK] = true, [IN_ATTACK2] = true}

	hook.Add("KeyPress", "nwActs", function(client, key)
		if (client:GetAct() and STOP[key] and CurTime() - (client.nwActStarted or 0) > 0.3) then
			A.Stop(client)
		end
	end)

	hook.Add("Think", "nwActs", function()
		for _, client in ipairs(player.GetAll()) do
			if (client:GetAct() and (!client:Alive() or client:InVehicle() or
				(CurTime() - (client.nwActStarted or 0) > 0.5 and (!client:OnGround() or
				client:GetVelocity():Length2DSqr() > 400)))) then
				A.Stop(client)
			end
		end
	end)

	hook.Add("PlayerSpawn", "nwActs", function(client)
		client:SetNW2String("nwAct", "")
	end)

	hook.Add("PlayerSwitchWeapon", "nwActs", function(client, old, new)
		if (client:GetAct() and IsValid(new) and new:GetClass() != "nw_hands") then
			A.Stop(client)
		end
	end)

	-- the voice: heard in 3D within the speaker's range
	hook.Add("PlayerCanHearPlayersVoice", "nwVoice", function(listener, talker)
		if (talker:GetNW2Bool("nwInMenu", false) or listener:GetNW2Bool("nwInMenu", false)) then
			return false
		end

		-- the dead and the unconscious say nothing
		if (!talker:Alive() or talker:GetNW2Bool("nwKnocked", false)) then
			return false
		end

		-- over the radio: everyone on the channel, flat (sh_radio.lua)
		if (NW.radio and NW.radio.Hears(listener, talker)) then
			return true, false
		end

		local mode = A.voice[talker:GetVoiceMode()] or A.voice[2]

		return listener:GetPos():DistToSqr(talker:GetPos()) <= mode.range * mode.range, true
	end)
end
