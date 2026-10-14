-- Bodies: where a hit lands, falling unconscious, the dead body and what can be done to them.
--
-- Damage by the place of the hit (GM:ScalePlayerDamage):
--   head      without a helmet - death; a helmet (item.protect) turns it into a heavy hit
--   chest,    hurts a lot without clothes (x1.6), clothes x1.35, a vest (item.protect) takes its share
--   stomach
--   arms      x0.55
--   legs      x0.6, but every hit counts: after 6-7 hits in the legs the character falls unconscious
-- A fall that does not kill (real fall damage) knocks the character out as well.
--
-- Unconscious: the character lies as a ragdoll (the player hidden and frozen inside it). Hits on
-- the body hurt the player; killing it kills the player. With 30+ health they come to by
-- themselves after nw_knockout_time (40 s); with less only someone else can help them up - or they
-- give up (hold Space, cl_body.lua). Others: E on the body → Проверить пульс; there is a pulse →
-- Помочь встать, Подлечить (a medical item of the helper).
--
-- Death: the body stays (nw_corpse_time, 10 minutes), and part of what the character carried
-- (nw_death_loss, 35% of the things in the grid and a quarter of the tokens) stays in it.
-- Others: Проверить пульс first, then Обыскать (the storage window).
--
-- Searching a living character: the wheel → Обыскать, only from behind (their back to you).

NW.body = NW.body or {}

local B = NW.body
local SO = NW.social
local ST = NW.storage
local INV = NW.inventory
local I = NW.items

local knockTime = CreateConVar("nw_knockout_time", "40", FCVAR_ARCHIVE, "Сколько секунд без сознания")
local selfHealth = CreateConVar("nw_knockout_selfhp", "30", FCVAR_ARCHIVE,
	"С каким здоровьем можно встать самому после потери сознания")
local corpseTime = CreateConVar("nw_corpse_time", "600", FCVAR_ARCHIVE, "Сколько секунд лежит тело")
local deathLoss = CreateConVar("nw_death_loss", "0.35", FCVAR_ARCHIVE, "Доля вещей, которые остаются в теле при смерти")

local RANGE = 120

local function Notify(client, text)
	NW.Notify(client, text)
end

local function Protect(client, slot)
	local cell = INV.Get(client).equip[slot]
	local item = cell and I.Get(cell.id)

	return item and tonumber(item.protect) or 0, cell != nil
end

-- --------------------------------------------------------------- damage --
function GM:ScalePlayerDamage(client, hitgroup, damage)
	if (hitgroup == HITGROUP_HEAD) then
		local helmet = Protect(client, "head")

		if (helmet <= 0) then
			damage:SetDamage(math.max(damage:GetDamage() * 10, client:Health() + client:Armor() + 50))
		else
			damage:ScaleDamage(2.4 * (1 - helmet))
		end
	elseif (hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH) then
		local vest, clothed = Protect(client, "torso")

		damage:ScaleDamage((clothed and 1.35 or 1.6) * (1 - math.Clamp(vest, 0, 0.9)))
	elseif (hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM) then
		damage:ScaleDamage(0.55)
	elseif (hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG) then
		damage:ScaleDamage(0.6)

		client.nwLegHits = (client.nwLegHits or 0) + 1
		client.nwLegLimit = client.nwLegLimit or math.random(6, 7)

		if (client.nwLegHits >= client.nwLegLimit) then
			timer.Simple(0, function()
				if (IsValid(client) and client:Alive()) then
					B.Knock(client)
				end
			end)
		end
	end
end

-- falling: the real fall damage; a fall that does not kill knocks the character out
function GM:GetFallDamage(client, speed)
	local damage = math.max(0, (speed - 526.5) * (100 / 396))

	if (damage >= 6 and damage < client:Health()) then
		timer.Simple(0, function()
			if (IsValid(client) and client:Alive()) then
				B.Knock(client)
			end
		end)
	end

	return damage
end

-- ------------------------------------------------------------ the ragdoll --
-- a ragdoll in the pose the player has right now
local function MakeRagdoll(client)
	local ragdoll = ents.Create("prop_ragdoll")

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll:SetModel(client:GetModel())
	ragdoll:SetPos(client:GetPos())
	ragdoll:SetAngles(Angle(0, client:EyeAngles().y, 0))
	ragdoll:SetSkin(client:GetSkin())

	for _, group in ipairs(client:GetBodyGroups() or {}) do
		ragdoll:SetBodygroup(group.id, client:GetBodygroup(group.id))
	end

	ragdoll:Spawn()
	ragdoll:Activate()
	ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ragdoll:SetModelScale(client:GetModelScale(), 0)

	local velocity = client:GetVelocity()

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physics = ragdoll:GetPhysicsObjectNum(i)
		local bone = ragdoll:TranslatePhysBoneToBone(i)
		local pos, ang = client:GetBonePosition(bone)

		if (IsValid(physics) and pos) then
			physics:SetPos(pos)
			physics:SetAngles(ang)
			physics:SetVelocity(velocity)
		end
	end

	ragdoll:SetNW2String("nwName", client:Nick())
	ragdoll:SetNW2Int("nwCharID", client:GetCharacterID())
	ragdoll.nwChecked = {}

	return ragdoll
end

function SO.IsBody(entity)
	return IsValid(entity) and entity:GetClass() == "prop_ragdoll" and
		(entity:GetNW2Bool("nwCorpse", false) or IsValid(entity:GetNW2Entity("nwPlayer")))
end

-- ------------------------------------------------------------ unconscious --
function B.IsKnocked(client)
	return client:GetNW2Bool("nwKnocked", false)
end

function B.Knock(client)
	if (!client:Alive() or B.IsKnocked(client) or client:InVehicle() or client:GetCharacterID() == 0) then
		return
	end

	local ragdoll = MakeRagdoll(client)

	if (!ragdoll) then
		return
	end

	if (NW.acts and NW.acts.Stop) then
		NW.acts.Stop(client)
	end

	NW.progress.Cancel(client)
	ST.Close(client)

	ragdoll:SetNW2Entity("nwPlayer", client)
	client:SetNW2Entity("nwBody", ragdoll)
	client:SetNW2Bool("nwKnocked", true)
	client:SetNW2Float("nwWakeAt", CurTime() + knockTime:GetFloat())
	client:SetNW2Int("nwWakeHP", selfHealth:GetInt())

	if (client:HasWeapon("nw_hands")) then
		client:SelectWeapon("nw_hands")
	end

	client:SetNW2Bool("nwRaised", false)
	client:DrawShadow(false)
	client:SetNoDraw(true)
	client:SetNotSolid(true)
	client:Freeze(true)
	client:SetMoveType(MOVETYPE_NONE)
	client:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 70)
end

-- back on the feet next to the body
local function Restore(client)
	client:SetNW2Bool("nwKnocked", false)
	client:SetNW2Entity("nwBody", NULL)
	client:DrawShadow(true)
	client:SetNoDraw(false)
	client:SetNotSolid(false)
	client:Freeze(false)
	client:SetMoveType(MOVETYPE_WALK)
	client.nwLegHits = 0
	client.nwLegLimit = nil
end

function B.Wake(client)
	if (!B.IsKnocked(client)) then
		return
	end

	local ragdoll = client:GetNW2Entity("nwBody")
	local pos = client:GetPos()
	local yaw = client:EyeAngles().y

	if (IsValid(ragdoll)) then
		local center = ragdoll:WorldSpaceCenter()
		local down = util.TraceLine({start = center + Vector(0, 0, 8), endpos = center - Vector(0, 0, 64),
			mask = MASK_PLAYERSOLID, filter = {ragdoll, client}})

		pos = down.HitPos
		yaw = ragdoll:GetAngles().y
		ragdoll:Remove()
	end

	Restore(client)

	local spot = NW.acts.ExitSpot and NW.acts.ExitSpot(client, pos) or pos

	client:SetPos(spot or pos)
	client:SetEyeAngles(Angle(0, yaw, 0))
	client:SetVelocity(-client:GetVelocity())
end

-- the hidden player stays with the body (the sound of the voice, what is near)
timer.Create("nwKnockFollow", 0.2, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (B.IsKnocked(client)) then
			local ragdoll = client:GetNW2Entity("nwBody")

			if (!IsValid(ragdoll)) then
				B.Wake(client)
			elseif (client:Alive()) then
				client:SetPos(ragdoll:WorldSpaceCenter())
			end
		end
	end
end)

-- hits on the body of an unconscious one hurt them
hook.Add("EntityTakeDamage", "nwBody", function(target, damage)
	if (target:GetClass() != "prop_ragdoll") then
		return
	end

	local client = target:GetNW2Entity("nwPlayer")

	if (IsValid(client) and client:Alive() and B.IsKnocked(client)) then
		local amount = damage:GetDamage()

		if (damage:IsDamageType(DMG_CRUSH) and amount < 20) then
			return
		end

		client:TakeDamage(amount, damage:GetAttacker(), damage:GetInflictor())
	end
end)

-- coming to by themselves / giving up
util.AddNetworkString("nwKnock")

net.Receive("nwKnock", function(_, client)
	local action = net.ReadString()

	if (!B.IsKnocked(client) or !client:Alive()) then
		return
	end

	if (action == "wake") then
		if (CurTime() >= client:GetNW2Float("nwWakeAt", 0) and client:Health() >= selfHealth:GetInt()) then
			B.Wake(client)
		end
	elseif (action == "giveup") then
		client:Kill()
	end
end)

-- ------------------------------------------------------------------ death --
local function Lose(client, ragdoll)
	local inventory = INV.Get(client)
	local store = {grid = {}, tokens = 0}
	local index = 0

	for cell = 1, I.maxSize do
		local thing = inventory.grid[cell]

		if (thing and math.random() < deathLoss:GetFloat()) then
			index = index + 1
			store.grid[index] = thing
			inventory.grid[cell] = nil
		end
	end

	local tokens = SO.GetTokens(client)
	local lost = math.floor(tokens * 0.25)

	if (lost > 0) then
		SO.SetTokens(client, tokens - lost)
		store.tokens = lost
	end

	store.size = math.max(12, math.ceil(index / 6) * 6)
	ragdoll.nwStore = store
	INV.Changed(client)
end

function B.MakeCorpse(client, ragdoll)
	if (!IsValid(ragdoll)) then
		ragdoll = MakeRagdoll(client)
	end

	if (!IsValid(ragdoll)) then
		return
	end

	-- one body per player
	if (IsValid(client.nwCorpse) and client.nwCorpse != ragdoll) then
		client.nwCorpse:Remove()
	end

	ragdoll:SetNW2Entity("nwPlayer", NULL)
	ragdoll:SetNW2Bool("nwCorpse", true)
	ragdoll.nwChecked = ragdoll.nwChecked or {}
	client.nwCorpse = ragdoll
	client:SetNW2Entity("nwBody", ragdoll)

	if (client:GetCharacterID() != 0) then
		Lose(client, ragdoll)
	end

	timer.Simple(corpseTime:GetFloat(), function()
		if (IsValid(ragdoll)) then
			ragdoll:Remove()
		end
	end)
end

-- the base gamemode makes a client ragdoll; here the body is a real one that stays
function GM:DoPlayerDeath(client, attacker, damage)
	-- unconscious: that body becomes the dead one
	local body = B.IsKnocked(client) and client:GetNW2Entity("nwBody") or nil

	if (B.IsKnocked(client)) then
		Restore(client)
		client:SetNoDraw(true)
	end

	B.MakeCorpse(client, body)
	client:AddDeaths(1)

	if (IsValid(attacker) and attacker:IsPlayer()) then
		attacker:AddFrags(attacker == client and -1 or 1)
	end
end

hook.Add("PlayerSpawn", "nwBody", function(client)
	if (B.IsKnocked(client)) then
		local ragdoll = client:GetNW2Entity("nwBody")

		if (IsValid(ragdoll) and ragdoll:GetNW2Entity("nwPlayer") == client) then
			ragdoll:Remove()
		end
	end

	Restore(client)
	client:SetNW2Entity("nwBody", NULL)
end)

-- back to the menu (a silent death) or gone: no body left behind
local function Clear(client)
	local ragdoll = client:GetNW2Entity("nwBody")

	if (IsValid(ragdoll) and ragdoll:GetNW2Entity("nwPlayer") == client) then
		ragdoll:Remove()
	end

	if (B.IsKnocked(client)) then
		Restore(client)
	end
end

hook.Add("PlayerSilentDeath", "nwBody", Clear)
hook.Add("PlayerDisconnected", "nwBody", Clear)

-- ----------------------------------------------------------- the actions --
util.AddNetworkString("nwPulse")

local function Near(client, body)
	return IsValid(client) and IsValid(body) and client:Alive() and
		client:GetPos():DistToSqr(body:GetPos()) < RANGE * RANGE
end

-- the name of the one lying there, if known (else the fallback)
local function BodyName(client, body, fallback)
	local id = body:GetNW2Int("nwCharID", 0)
	local known = client.nwCharacter and client.nwCharacter.data and client.nwCharacter.data.known

	return (istable(known) and known[tostring(id)]) and body:GetNW2String("nwName", "") or fallback
end

function SO.actions.pulse(client, body)
	if (!SO.IsBody(body)) then
		return
	end

	NW.SayMe(client, "присаживается и проверяет пульс у " .. BodyName(client, body, "лежащего"))

	NW.progress.Start(client, "Проверяю пульс", 2.5, function()
		local victim = body:GetNW2Entity("nwPlayer")
		local alive = IsValid(victim) and victim:Alive() and B.IsKnocked(victim)

		body.nwChecked = body.nwChecked or {}
		body.nwChecked[client] = true

		net.Start("nwPulse")
			net.WriteEntity(body)
			net.WriteBool(alive)
		net.Send(client)

		if (alive) then
			Notify(client, victim:Health() < selfHealth:GetInt() and "Пульс есть, но слабый" or "Пульс есть")
		else
			Notify(client, "Пульса нет")
		end
	end, function()
		return Near(client, body)
	end)
end

function SO.actions.helpup(client, body)
	local victim = body:GetNW2Entity("nwPlayer")

	if (!IsValid(victim) or !B.IsKnocked(victim) or !(body.nwChecked or {})[client]) then
		return
	end

	NW.SayMe(client, "помогает подняться " .. BodyName(client, body, "лежащему"))

	NW.progress.Start(client, "Помогаю подняться", 4, function()
		if (IsValid(victim) and B.IsKnocked(victim) and victim:Alive()) then
			victim:SetHealth(math.max(victim:Health(), 10))
			B.Wake(victim)
		end
	end, function()
		return Near(client, body)
	end)
end

function SO.actions.heal(client, body)
	local victim = body:GetNW2Entity("nwPlayer")

	if (!IsValid(victim) or !B.IsKnocked(victim) or !(body.nwChecked or {})[client]) then
		return
	end

	-- the first medical thing in the helper's grid
	local inventory = INV.Get(client)
	local index, item

	for cell = 1, I.maxSize do
		local thing = inventory.grid[cell]
		local data = thing and I.Get(thing.id)

		if (data and data.heal) then
			index, item = cell, data

			break
		end
	end

	if (!index) then
		return Notify(client, "Нечем лечить: нужны бинт, аптечка или таблетки")
	end

	if (victim:Health() >= victim:GetMaxHealth()) then
		return Notify(client, "Ранений нет")
	end

	NW.SayMe(client, "перевязывает раны " .. BodyName(client, body, "лежащего"))

	NW.progress.Start(client, "Лечу", 3, function()
		local thing = inventory.grid[index]

		if (!thing or thing.id != item.id or !IsValid(victim) or !B.IsKnocked(victim)) then
			return
		end

		inventory.grid[index] = item.leaves and I.Get(item.leaves) and {id = item.leaves, data = {}} or nil
		victim:SetHealth(math.min(victim:GetMaxHealth(), victim:Health() + item.heal))
		INV.Changed(client)
		Notify(client, "Вы использовали: " .. item.name)
	end, function()
		return Near(client, body)
	end)
end

-- the dead: what stayed in the body
local function CorpseSource(body)
	local store = body.nwStore or {grid = {}, tokens = 0, size = 12}

	body.nwStore = store

	return {
		key = "corpse" .. body:EntIndex(),
		title = "Тело",
		icon = "skull",
		entity = body,
		cols = 6,
		rows = math.ceil(store.size / 6),
		Get = function(index)
			return store.grid[index]
		end,
		Set = function(index, cell)
			store.grid[index] = cell
		end,
		GetTokens = function()
			return store.tokens or 0
		end,
		SetTokens = function(amount)
			store.tokens = amount
		end,
		Valid = function(client)
			return Near(client, body)
		end,
		Changed = function()
		end
	}
end

function SO.actions.searchbody(client, body)
	if (!body:GetNW2Bool("nwCorpse", false)) then
		return
	end

	if (!(body.nwChecked or {})[client]) then
		return Notify(client, "Сначала проверьте пульс")
	end

	NW.SayMe(client, "обыскивает тело")

	NW.progress.Start(client, "Обыскиваю тело", 2.5, function()
		ST.Open(client, CorpseSource(body))
	end, function()
		return Near(client, body)
	end)
end

-- a living one, from behind
function B.Behind(client, target)
	local forward = target:EyeAngles():Forward()
	local toMe = client:GetPos() - target:GetPos()

	forward.z = 0
	toMe.z = 0

	return forward:GetNormalized():Dot(toMe:GetNormalized()) < -0.35
end

function SO.actions.search(client, target)
	if (!target:IsPlayer() or !target:Alive()) then
		return
	end

	if (!B.Behind(client, target)) then
		return Notify(client, "Обыскать можно только со спины")
	end

	NW.SayMe(client, "быстро обыскивает одежду и карманы " ..
		(NW.char.Knows(client, target) and target:Nick() or "человека"))
	Notify(target, "Вас обыскивают")

	NW.progress.Start(client, "Обыскиваю", 3, function()
		ST.Open(client, ST.PlayerSource(target, client))
	end, function()
		return IsValid(target) and target:Alive() and client:GetPos():DistToSqr(target:GetPos()) < 130 * 130 and
			B.Behind(client, target)
	end)
end
