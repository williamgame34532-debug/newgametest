AddCSLuaFile()

-- An announcer of the city: an invisible point the Overwatch speaks from (sh_overwatch.lua). Every
-- 5..15 minutes (nw_announcer_min / nw_announcer_max) one of the everyday announcements (ambient =
-- true) sounds from it, loud, and the words go to the chat of those who hear it (within 2500 units).
-- Players do not see it and do not bump into it; admins with the physics gun or the tool gun in hand
-- (or in noclip) see a small mark and move it with the physics gun - it stays where it is put
-- (sv_persist.lua). nw_announcer_test - the announcer looked at speaks now.

ENT.Type = "anim"
ENT.PrintName = "Оповещатель Надзора"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

if (SERVER) then
	local minimum = CreateConVar("nw_announcer_min", "300", FCVAR_ARCHIVE, "Оповещатель: наименьшая пауза (секунды)")
	local maximum = CreateConVar("nw_announcer_max", "900", FCVAR_ARCHIVE, "Оповещатель: наибольшая пауза (секунды)")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_announcer")

		entity:SetPos(trace.HitPos + trace.HitNormal * 16)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/PopCan01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(false)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:EnableGravity(false)
		end

		self:Schedule()
	end

	function ENT:Schedule()
		local low = math.max(10, minimum:GetFloat())

		self.nextTalk = CurTime() + math.Rand(low, math.max(low, maximum:GetFloat()))
	end

	function ENT:Speak()
		local list = {}

		for _, entry in ipairs(NW.overwatch.list) do
			if (entry.ambient and entry.id != self.lastID) then
				list[#list + 1] = entry
			end
		end

		local entry = list[math.random(#list)]

		if (!entry) then
			return
		end

		self.lastID = entry.id
		self:EmitSound(entry.sound, 120, 100, 1, CHAN_VOICE)

		local hearers = {}

		for _, client in ipairs(player.GetAll()) do
			if (client:GetPos():DistToSqr(self:GetPos()) < 2500 * 2500) then
				hearers[#hearers + 1] = client
			end
		end

		if (#hearers > 0) then
			NW.Dispatch(entry.text, hearers)
		end
	end

	function ENT:Think()
		if (CurTime() >= (self.nextTalk or 0)) then
			self:Speak()
			self:Schedule()
		end

		self:NextThink(CurTime() + 1)

		return true
	end

	-- let go of the physics gun: it hangs where it was let go
	hook.Add("PhysgunDrop", "nwAnnouncer", function(_, entity)
		if (IsValid(entity) and entity:GetClass() == "nw_announcer") then
			local physics = entity:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
			end
		end
	end)

	concommand.Add("nw_announcer_test", function(client)
		if (!IsValid(client) or !client:IsAdmin()) then
			return
		end

		local entity = client:GetEyeTrace().Entity

		if (IsValid(entity) and entity:GetClass() == "nw_announcer") then
			entity:Speak()
		else
			NW.Notify(client, "Посмотрите на оповещатель")
		end
	end)

	timer.Simple(0, function()
		NW.persist.Register("nw_announcer")
	end)

	return
end

-- ------------------------------------------------------------------ client --
local MARK = Material("sprites/light_glow02_add")
local TOOLS = {weapon_physgun = true, gmod_tool = true}

local function Seen()
	local client = LocalPlayer()

	if (!client:IsAdmin()) then
		return false
	end

	local weapon = client:GetActiveWeapon()

	return client:GetNW2Bool("nwObserver", false) or (IsValid(weapon) and TOOLS[weapon:GetClass()] == true)
end

function ENT:Draw()
end

function ENT:DrawTranslucent()
	if (!Seen()) then
		return
	end

	local pulse = 0.7 + 0.3 * math.sin(RealTime() * 3)

	render.SetMaterial(MARK)
	render.DrawSprite(self:GetPos(), 28 * pulse, 28 * pulse, Color(236, 98, 74, 220))

	local angle = Angle(0, EyeAngles().y - 90, 90)

	cam.Start3D2D(self:GetPos() + Vector(0, 0, 14), angle, 0.08)
		draw.SimpleTextOutlined("ОПОВЕЩАТЕЛЬ", "DermaLarge", 0, 0, Color(236, 98, 74), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_BOTTOM, 2, color_black)
	cam.End3D2D()
end
