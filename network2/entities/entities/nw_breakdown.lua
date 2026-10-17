AddCSLuaFile()

-- A place where the city breaks (sh_cwu.lua): a pipe, a power box or a panel of the Combine. Now and
-- then it breaks by itself (sv_cwu.lua): the pipe hisses with steam, the box sparks, the panel
-- flickers and crackles; the CWU sees it at its terminal and on the HUD. A worker of the CWU with the
-- tool fixes it: E (the time shrinks with Инженерия). Admins: the C menu → «Настройки» (the kind,
-- the name, the model, the tool, whether it is used up, the time, the pay, who may repair) or
-- Alt + E - the next kind (sh_entsettings.lua).

ENT.Type = "anim"
ENT.PrintName = "Точка поломки (ГСР)"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Kinds = {
	{id = "pipe", name = "Утечка в трубе", model = "models/props_pipes/valve002.mdl"},
	{id = "power", name = "Электрощит", model = "models/props_lab/powerbox01a.mdl"},
	{id = "panel", name = "Панель Альянса", model = "models/props_combine/combine_interface002.mdl"},
	{id = "wire", name = "Оборванная проводка", model = "models/props_lab/tpplugholder_single.mdl"},
	{id = "vent", name = "Неисправный котёл", model = "models/props_c17/furnitureboiler001a.mdl"},
	{id = "lamp", name = "Уличный фонарь", model = "models/props_c17/light_cagelight02_on.mdl"}
}

-- the settings of a point (the C menu): what fixes it and how
ENT.Defaults = {tool = "toolkit", consume = false, time = 10, reward = 0, name = "", cwuOnly = true}

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Int", 0, "Kind")
	self:NetworkVar("Float", 0, "BrokenSince")
end

function ENT:KindData()
	local kind = self.Kinds[math.Clamp(self:GetKind(), 1, #self.Kinds)]
	local name = self:GetNW2String("nwBreakName", "")

	return name != "" and {id = kind.id, name = name, model = kind.model} or kind
end

-- the tool that fixes it ("" - the hands)
function ENT:Tool()
	return self:GetNW2String("nwBreakTool", "toolkit")
end

if (SERVER) then
	function ENT:Conf()
		self.nwConf = self.nwConf or table.Copy(self.Defaults)

		return self.nwConf
	end

	function ENT:SetConf(conf)
		local out = self:Conf()

		for key, default in pairs(self.Defaults) do
			if (conf[key] != nil and type(conf[key]) == type(default)) then
				out[key] = conf[key]
			end
		end

		out.time = math.Clamp(out.time, 1, 120)
		out.reward = math.Clamp(math.floor(out.reward), 0, 500)
		out.name = string.sub(string.Trim(out.name), 1, 48)
		self:SetNW2String("nwBreakName", out.name)
		self:SetNW2String("nwBreakTool", out.tool)
	end
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_breakdown")

		entity:SetPos(trace.HitPos + trace.HitNormal * 4)
		entity:SetAngles(trace.HitNormal:Angle())
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetKind(math.max(1, self:GetKind()))
		self:SetConf(self:Conf())
		self:ApplyModel()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:ApplyModel()
		local model = self.nwModel or self:KindData().model

		self:SetModel(util.IsValidModel(model) and model or "models/props_lab/powerbox01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:SetState(bBroken)
		self:SetBroken(bBroken)
		self:SetBrokenSince(CurTime())

		if (self.loop) then
			self.loop:Stop()
			self.loop = nil
		end

		if (bBroken) then
			local kind = self:KindData().id
			local sound = (kind == "pipe" or kind == "vent") and "ambient/gas/steam2.wav" or "ambient/energy/electric_loop.wav"

			self.loop = CreateSound(self, sound)
			self.loop:SetSoundLevel(68)
			self.loop:PlayEx(kind == "pipe" and 0.5 or (kind == "vent" and 0.25 or 0.3), kind == "vent" and 70 or 100)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer()) then
			return
		end

		-- admins: Alt + E - the kind
		if (client:IsAdmin() and client:KeyDown(IN_WALK)) then
			self:SetKind(self:GetKind() % #self.Kinds + 1)
			self.nwModel = nil
			self:ApplyModel()
			NW.Notify(client, "Тип поломки: " .. self:KindData().name)
			NW.persist.Save("nw_breakdown")

			return
		end

		NW.cwu.Repair(client, self)
	end

	function ENT:OnRemove()
		if (self.loop) then
			self.loop:Stop()
		end
	end

	-- sparks of a broken box and panel now and then
	function ENT:Think()
		local kind = self:KindData().id

		if (self:GetBroken() and kind != "pipe" and kind != "vent" and math.random() < 0.35) then
			local effect = EffectData()

			effect:SetOrigin(self:WorldSpaceCenter() + VectorRand() * 6)
			effect:SetNormal(self:GetForward())
			effect:SetMagnitude(2)
			effect:SetScale(1)
			effect:SetRadius(3)
			util.Effect("ElectricSpark", effect, true, true)

			if (math.random() < 0.4) then
				self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 62, math.random(95, 110))
			end
		end

		self:NextThink(CurTime() + math.Rand(0.4, 1.2))

		return true
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_breakdown", {
			Save = function(entity)
				return {kind = entity:GetKind(), model = entity.nwModel, conf = entity:Conf()}
			end,
			Load = function(entity, data)
				entity:SetKind(tonumber(data.kind) or 1)
				entity.nwModel = data.model
				entity:SetConf(istable(data.conf) and data.conf or {})
				entity:ApplyModel()
			end
		})
	end)

	return
end

-- ------------------------------------------------------------------ client --
function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	if (!self:GetBroken() or LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 1500 * 1500) then
		return
	end

	local kind = self:KindData().id

	-- the steam of a pipe, the dust of a vent
	if ((kind == "pipe" or kind == "vent") and (self.nextPuff or 0) < CurTime()) then
		self.nextPuff = CurTime() + (kind == "vent" and 0.25 or 0.06)

		local emitter = ParticleEmitter(self:GetPos())

		if (emitter) then
			local puff = emitter:Add("particle/particle_smokegrenade", self:WorldSpaceCenter())

			if (puff) then
				puff:SetVelocity(self:GetForward() * math.Rand(60, 120) + VectorRand() * 20 + Vector(0, 0, 30))
				puff:SetDieTime(math.Rand(1.2, 2))
				puff:SetStartAlpha(70)
				puff:SetEndAlpha(0)
				puff:SetStartSize(4)
				puff:SetEndSize(math.Rand(28, 44))
				puff:SetRoll(math.Rand(0, 360))
				puff:SetRollDelta(math.Rand(-1, 1))
				puff:SetColor(220, 224, 228)
				puff:SetAirResistance(80)
			end

			emitter:Finish()
		end
	end

	-- the flicker of a box, a panel, the wires, a lamp
	if (kind != "pipe" and kind != "vent") then
		local light = DynamicLight(self:EntIndex())

		if (light and math.random() < 0.6) then
			light.pos = self:WorldSpaceCenter() + self:GetForward() * 10
			light.r, light.g, light.b = 140, 190, 255
			light.brightness = math.Rand(0.5, 2)
			light.decay = 2000
			light.size = 110
			light.dietime = CurTime() + 0.1
		end
	end
end
