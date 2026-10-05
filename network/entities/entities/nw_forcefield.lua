AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Силовое поле"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.MODE_OFF = 1
ENT.MODE_SHUTDOWN = 2
ENT.MODE_CARD = 3
ENT.MODE_ALLIANCE = 4
ENT.MODE_CWU = 5

ENT.MaxIntegrity = 400

function ENT.PickModel(preferred, fallbacks)
	local list = {preferred, unpack(fallbacks)}

	for _, model in ipairs(list) do
		if (file.Exists(model, "GAME")) then
			util.PrecacheModel(model)

			return model
		end
	end

	return list[#list]
end

ENT.Height = 150
ENT.Reach = 480

ENT.Base = 44

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Mode")
	self:NetworkVar("Entity", 0, "Pillar")
end

function ENT:GetModeName()
	local mode = self:GetMode()

	if (mode == self.MODE_CARD) then
		return "fieldCard"
	elseif (mode == self.MODE_ALLIANCE) then
		return "fieldAlliance"
	elseif (mode == self.MODE_CWU) then
		return "fieldCWU"
	elseif (mode == self.MODE_SHUTDOWN) then
		return "fieldShutdown"
	end

	return "fieldOff"
end

function ENT:IsWorking()
	local mode = self:GetMode()

	return mode == self.MODE_CARD or mode == self.MODE_ALLIANCE or
		mode == self.MODE_CWU
end

function ENT:GetModeSkin()
	local mode = self:GetMode()

	if (mode == self.MODE_CWU) then
		return 1
	elseif (mode == self.MODE_CARD) then
		return 0
	elseif (mode == self.MODE_SHUTDOWN) then
		return 3
	end

	return 2
end

function ENT:ApplySkin()
	local skin = self:GetModeSkin()

	self:SetSkin(skin)

	local pillar = self:GetPillar()

	if (IsValid(pillar)) then
		pillar:SetSkin(skin)
	end
end

function ENT:GetSpan()
	local pillar = self:GetPillar()

	if (IsValid(pillar)) then
		return self:WorldToLocal(pillar:GetPos())
	end

	return Vector(0, self.Reach, 0)
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p = 0
		angles.r = 0

		angles:RotateAroundAxis(angles:Up(), 270)

		local entity = ents.Create("nw_forcefield")

		entity:SetPos(trace.HitPos + Vector(0, 0, 40))
		entity:SetAngles(angles:SnapTo("y", 90))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = self.PickModel("models/network_force/combine_fence01b.mdl", {
			"models/props_combine/combine_fence01b.mdl",
			"models/props_wasteland/interior_fence002c.mdl"
		})

		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:DrawShadow(false)
		self:SetMode(self.MODE_CARD)

		self.integrity = self.MaxIntegrity

		timer.Simple(0.15, function()
			if (IsValid(self)) then
				self:ApplySkin()
				self:UpdateLoop()
			end
		end)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:BuildPillar()
	end

	function ENT:BuildPillar()
		local trace = util.TraceLine({
			start = self:GetPos() + self:GetRight() * -16,
			endpos = self:GetPos() + self:GetRight() * -self.Reach,
			filter = self
		})

		local pillar = ents.Create("prop_physics")

		if (!IsValid(pillar)) then
			return
		end

		local model = self.PickModel("models/network_force/combine_fence01a.mdl", {
			"models/props_combine/combine_fence01a.mdl",
			self:GetModel()
		})

		pillar:SetModel(model)
		pillar:SetPos(trace.HitPos)
		pillar:SetAngles(self:GetAngles())
		pillar:Spawn()
		pillar:Activate()

		pillar.PhysgunDisabled = true

		local physics = pillar:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:DeleteOnRemove(pillar)
		self:SetPillar(pillar)
	end

	function ENT:UpdateLoop()
		if (self:IsWorking()) then
			if (!self.loopSound) then
				self.loopSound = CreateSound(self, "framework/cmb/forcefield/loop.wav")
				self.loopSound:PlayEx(0.5, 100)
			end
		elseif (self.loopSound) then
			self.loopSound:Stop()
			self.loopSound = nil
		end
	end

	function ENT:SetModeEx(mode, client)
		local previous = self:GetMode()

		self:SetMode(mode)
		self:ApplySkin()
		self:UpdateLoop()

		if (previous != mode) then
			hook.Run("NetworkForcefieldMode", client, self, mode)
		end

		if (self:IsWorking() and (previous == self.MODE_OFF or
			previous == self.MODE_SHUTDOWN)) then
			self:EmitSound("framework/cmb/forcefield/start.mp3", 80)
		else
			self:EmitSound("framework/cmb/forcefield/changemode" ..
				(math.random(2) == 2 and "2.wav" or ".mp3"), 70)
		end

		if (IsValid(client)) then
			NETWORK.chat.Notice(client, self:GetModeName())
		end
	end

	function ENT:Shutdown()
		self.integrity = 0

		self:SetMode(self.MODE_SHUTDOWN)
		self:ApplySkin()
		self:UpdateLoop()
		self:EmitSound("framework/cmb/forcefield/shutdown.mp3", 85)

		if (NETWORK.dispatch and NETWORK.dispatch.SendRadio) then
			local zone = NETWORK.zone.At(self:GetPos())
			local zoneName = zone and zone.name or L("owUnknownZone")

			NETWORK.dispatch.SendRadio(
				L("dispatchFieldDown", zoneName), Color(240, 96, 86))
		end
	end

	function ENT:Repair()
		self.integrity = self.MaxIntegrity

		self:SetMode(self.MODE_OFF)
		self:ApplySkin()
		self:UpdateLoop()
		self:EmitSound("framework/cmb/forcefield/repair_complete.mp3", 75)
	end

	function ENT:HasToolkit(client)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage", "clothes", "equipped"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and (item.id == "toolkit" or
					item.id == "mechanic_toolkit")) then
					return true
				end
			end
		end

		return false
	end

	function ENT:SetDisabled(bDisabled)
		if (bDisabled) then
			self:SetModeEx(self.MODE_SHUTDOWN)

			return
		end

		self:SetModeEx(self.MODE_CARD)

		self.integrity = self.MaxIntegrity
	end

	function ENT:Use(client)
		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1

		if (!NETWORK.factions.IsAlliance(client) and
			!(client:IsAdmin() and client:KeyDown(IN_SPEED))) then
			self:EmitSound("buttons/combine_button_locked.wav")

			return
		end

		if (self:GetMode() == self.MODE_SHUTDOWN) then
			self:EmitSound("framework/cmb/forcefield/sparkle" ..
				math.random(2, 4) .. ".mp3", 60, 110)

			if (!IsValid(client)) then
				return
			end

			if (!self:HasToolkit(client)) then
				NETWORK.chat.Notice(client, "fieldNeedToolkit")

				return
			end

			hook.Run("NetworkForcefieldRepair", client, self)

			return
		end

		local mode = self:GetMode() + 1

		if (mode == self.MODE_SHUTDOWN) then
			mode = self.MODE_CARD
		end

		if (mode > self.MODE_CWU) then
			mode = self.MODE_OFF
		end

		self:SetModeEx(mode, client)
	end

	function ENT:OnTakeDamage(damage)
		if (!self:IsWorking()) then
			return 0
		end

		self.integrity = (self.integrity or self.MaxIntegrity) -
			damage:GetDamage()

		self:EmitSound("framework/cmb/forcefield/attack" ..
			(math.random(3) == 1 and "" or math.random(2, 3)) .. ".mp3",
			70, math.random(95, 105))

		if (self.integrity <= 0) then
			self:Shutdown()
		end

		return 0
	end

	function ENT:OnRemove()
		if (self.loopSound) then
			self.loopSound:Stop()
		end
	end

	local CWU_FACTIONS = {cwu = true, worker = true, disinfector = true}

	function ENT:CanPass(client)

		if (NETWORK.factions.IsAlliance(client)) then
			return true
		end

		local mode = self:GetMode()

		if (mode == self.MODE_ALLIANCE) then
			return false
		end

		if (mode == self.MODE_CWU) then
			local id = client:GetCharacterFaction()
			local faction = id and NETWORK.factions.Get(id)

			return CWU_FACTIONS[id] == true or
				(faction and faction.bCWU) == true
		end

		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({state.items, state.equipped, state.storage}) do
			for _, item in pairs(list) do
				if (item.id == "idcard") then
					return true
				end
			end
		end

		return false
	end

	function ENT:Think()
		if (!self:IsWorking()) then

			if (self:GetMode() == self.MODE_SHUTDOWN and
				(self.nextSparkle or 0) < CurTime()) then
				self.nextSparkle = CurTime() + math.Rand(2, 5)

				self:EmitSound("framework/cmb/forcefield/sparkle" ..
					math.random(4) .. ".mp3", 62, math.random(92, 108))
			end

			self:NextThink(CurTime() + 0.4)

			return true
		end

		local span = self:GetSpan()
		local length = span:Length()
		local origin = self:GetPos()
		local along = self:GetRight() * -1
		local normal = self:GetForward()

		self.tracks = self.tracks or {}

		for _, client in ipairs(ents.FindInSphere(origin + along * (length * 0.5),
			length * 0.5 + 96)) do
			if (!client:IsPlayer() or !client:Alive() or
				client:GetMoveType() == MOVETYPE_NOCLIP) then
				continue
			end

			if (self:CanPass(client)) then
				self.tracks[client] = nil

				continue
			end

			local center = client:GetPos() + Vector(0, 0, 32)
			local offset = center - origin
			local distance = offset:Dot(along)
			local side = offset:Dot(normal)
			local track = self.tracks[client]

			self.tracks[client] = {position = center, time = CurTime()}

			if (distance < -16 or distance > length + 16 or
				offset.z < -self.Base - 8 or offset.z > self.Height + 40) then
				continue
			end

			if (track and CurTime() - track.time <= 0.35) then
				local previous = (track.position - origin):Dot(normal)

				if (previous * side < 0) then
					local total = previous - side

					local fraction = math.Clamp(
						total != 0 and (previous / total) or 0, 0, 1)
					local hit = track.position +
						(center - track.position) * fraction
					local hitOffset = hit - origin
					local hitAlong = hitOffset:Dot(along)

					if (hitAlong >= -8 and hitAlong <= length + 8 and
						hitOffset.z >= -self.Base - 8 and
						hitOffset.z <= self.Height + 8) then
						local back = (previous >= 0 and 26 or -26)

						client:SetPos(hit + normal * back - Vector(0, 0, 32))
						client:SetLocalVelocity(client:GetVelocity() -
							normal * client:GetVelocity():Dot(normal))

						client:EmitSound("ambient/energy/zap" ..
							math.random(1, 3) .. ".wav", 64,
							math.random(92, 100), 0.55)

						self.tracks[client] = {
							position = client:GetPos() + Vector(0, 0, 32),
							time = CurTime()
						}

						side = back
					end
				end
			end

			if (math.abs(side) <= 28) then
				local velocity = client:GetVelocity()

				client:SetVelocity(normal * (side >= 0 and 220 or -220) -
					velocity * 0.5)

				self.contact = self.contact or {}

				if (!self.contact[client]) then
					self.contact[client] = true

					client:EmitSound("ambient/energy/zap" .. math.random(1, 3) ..
						".wav", 62, math.random(95, 105), 0.45)
				end
			elseif (self.contact and self.contact[client]) then

				self.contact[client] = nil

				client:StopSound("ambient/machines/combine_shield_touch_loop1.wav")
			end
		end

		for client, track in pairs(self.tracks) do
			if (!IsValid(client) or CurTime() - track.time > 2) then
				self.tracks[client] = nil

				if (self.contact) then
					self.contact[client] = nil
				end
			end
		end

		self:NextThink(CurTime() + 0.05)

		return true
	end
else

	NETWORK.forcefield = NETWORK.forcefield or {}
	NETWORK.forcefield.material = "framework/forcefield/comshieldwall3"
	NETWORK.forcefield.tinted = "framework/forcefield/comshieldwall_"

	local FALLBACK = Material(NETWORK.forcefield.material)

	if (FALLBACK:IsError()) then
		FALLBACK = Material("effects/combineshield/comshieldwall3")
	end

	local SHEETS = {}

	local TINTS = {
		red = Color(255, 96, 86),
		orange = Color(255, 176, 74),
		blue = Color(150, 210, 255)
	}

	local custom = CreateClientConVar("network_forcefield_custom", "0", true,
		false, "Использовать материалы силовых полей из контент-аддона")

	local function IsUsable(material)
		if (!material or material:IsError()) then
			return false
		end

		local bFound = false

		for _, key in ipairs({"$basetexture", "$normalmap", "$refracttexture"}) do
			local texture = material:GetTexture(key)

			if (texture) then
				if (texture:IsError()) then
					return false
				end

				bFound = true
			end
		end

		return bFound
	end

	local function Sheet(name)
		if (SHEETS[name] == nil) then
			local material = Material(NETWORK.forcefield.tinted ..
				string.gsub(name, "^comshieldwall_", ""))

			SHEETS[name] = IsUsable(material) and material or false
		end

		return SHEETS[name]
	end

	concommand.Add("network_reloadforcefield", function()
		SHEETS = {}

		MsgN("[Network] Материалы силового поля перепроверены.")
	end)

	function ENT:GetSheet()
		local mode = self:GetMode()
		local tint = "blue"

		if (mode == self.MODE_ALLIANCE) then
			tint = "red"
		elseif (mode == self.MODE_CWU) then
			tint = "orange"
		end

		local sheet = custom:GetBool() and Sheet("comshieldwall_" .. tint)

		if (sheet) then
			return sheet, color_white
		end

		return FALLBACK, TINTS[tint]
	end

	function ENT:Draw()
		self:DrawModel()

		local mode = self:GetMode()

		if (mode == self.MODE_OFF or mode == self.MODE_SHUTDOWN) then
			return
		end

		local span = self:GetSpan()

		self:SetRenderBounds(Vector(-16, -16, -self.Base - 16),
			span + Vector(16, 16, self.Height + 16))

		local matrix = Matrix()

		matrix:Translate(self:GetPos())
		matrix:Rotate(self:GetAngles())

		local sheet, tint = self:GetSheet()

		render.SetMaterial(sheet)

		render.SetColorModulation(tint.r / 255, tint.g / 255, tint.b / 255)

		cam.PushModelMatrix(matrix)
			self:DrawSheet(span)
		cam.PopModelMatrix()

		matrix:Translate(span)
		matrix:Rotate(Angle(0, 180, 0))

		cam.PushModelMatrix(matrix)
			self:DrawSheet(span)
		cam.PopModelMatrix()

		render.SetColorModulation(1, 1, 1)
	end

	function ENT:DrawSheet(span)
		local bottom = Vector(0, 0, -self.Base)
		local top = Vector(0, 0, self.Height)

		mesh.Begin(MATERIAL_QUADS, 1)
			mesh.Position(bottom)
			mesh.TexCoord(0, 0, 0)
			mesh.AdvanceVertex()

			mesh.Position(top)
			mesh.TexCoord(0, 0, 3)
			mesh.AdvanceVertex()

			mesh.Position(span + top)
			mesh.TexCoord(0, 3, 3)
			mesh.AdvanceVertex()

			mesh.Position(span + bottom)
			mesh.TexCoord(0, 3, 0)
			mesh.AdvanceVertex()
		mesh.End()
	end
end
