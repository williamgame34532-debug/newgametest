AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Личный сейф"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Range = 110
ENT.Slots = 24

local MODELS = {
	"models/props_c17/Lockers001a.mdl",
	"models/props_c17/FurnitureDrawer001a.mdl",
	"models/props_wasteland/controlroom_storagecloset001a.mdl",
	"models/props_junk/wood_crate002a.mdl"
}

ENT.Models = MODELS

local defaultModel

function ENT:GetDefaultModel()
	if (defaultModel) then
		return defaultModel
	end

	for _, path in ipairs(MODELS) do
		if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
			defaultModel = path

			return path
		end
	end

	defaultModel = MODELS[#MODELS]

	if (SERVER) then
		NETWORK.util.PrintWarning(
			"Ни одна модель не найдена, используется запасная: " .. defaultModel)
	end

	return defaultModel
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "StashModel")

	self:NetworkVar("String", 1, "LockItem")
	self:NetworkVar("String", 2, "LockCode")
end

function ENT:GetContainerSlots()
	return self.Slots
end

function ENT:GetContainerRefill()
	return 0
end

function ENT:GetContainerID()
	return ""
end

function ENT:SetContainerRefill()
end

function ENT:SetContainerName()
end

function ENT:SetContainerDescription()
end

function ENT:GetDisplayDescription()
	if (self:GetNWString("nwGroupName", "") != "") then
		return L("stashGroupDesc")
	end

	return L("stashSub")
end

function ENT:GetDisplayName()
	if (CLIENT and NETWORK.group and NETWORK.group.own and
		self:GetNWString("nwGroupName", "") != "") then
		return self:GetNWString("nwGroupName")
	end

	return L("stashLabel")
end

if (SERVER) then
	NETWORK.stash = NETWORK.stash or {}
	NETWORK.stash.stored = NETWORK.stash.stored or {}

	local dataPath = "network/stash.txt"

	function NETWORK.stash.Save()

		file.CreateDir("network")
		file.Write(dataPath, util.TableToJSON(NETWORK.stash.stored, true))
	end

	function NETWORK.stash.Load()
		local raw = file.Read(dataPath, "DATA")

		NETWORK.stash.stored = raw and util.JSONToTable(raw) or {}
	end

	hook.Add("Initialize", "nwStash", function()
		NETWORK.stash.Load()
	end)

	function NETWORK.stash.Key(client, entity)
		local override = hook.Run("NetworkStashKey", client, entity)

		if (isstring(override) and override != "") then
			return override
		end

		local character = client:GetCharacter()

		return character and tostring(character:GetID())
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_stash")

		if (!IsValid(entity)) then
			return
		end

		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(angles:SnapTo("y", 45))
		entity:Spawn()
		entity:Activate()

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		return entity
	end

	function ENT:Initialize()
		local model = self:GetStashModel()

		if (model == "" or !(util.IsValidModel(model) or
			file.Exists(model, "GAME"))) then
			model = self:GetDefaultModel()

			self:SetStashModel(model)
		end

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.viewers = {}
		self.nextUse = 0
	end

	function ENT:Apply()
		local model = self:GetStashModel()

		if (model != "" and (util.IsValidModel(model) or
			file.Exists(model, "GAME"))) then
			util.PrecacheModel(model)
			self:SetModel(model)
			self:PhysicsInit(SOLID_VPHYSICS)

			local physics = self:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
				physics:Sleep()
			end
		end
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime() or !IsValid(client) or
			!client:HasCharacter()) then
			return
		end

		self.nextUse = CurTime() + 0.6

		if (client:GetPos():Distance(self:GetPos()) > self.Range) then
			return
		end

		local key = NETWORK.stash.Key(client, self)

		if (!key) then
			return
		end

		if (NETWORK.stashcode and !NETWORK.stashcode.Check(client, self)) then
			return
		end

		if (!NETWORK.container.CheckLock(client, self)) then
			return
		end

		if (next(self.viewers or {}) != nil) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return NETWORK.chat.Notice(client, "stashBusy")
		end

		self.items = NETWORK.stash.stored[key] or {}
		self.owner = key

		NETWORK.container.Open(client, self)
	end

	function ENT:OnStashClosed(client)
		if (!self.owner) then
			return
		end

		NETWORK.stash.stored[self.owner] = self.items or {}

		NETWORK.stash.Save()

		self.owner = nil
	end

	hook.Add("NetworkContainerClosed", "nwStash", function(client, entity)
		if (IsValid(entity) and entity:GetClass() == "nw_stash") then
			entity:OnStashClosed(client)
		end
	end)

	hook.Add("PlayerDisconnected", "nwStash", function(client)
		local entity = client.nwContainer

		if (IsValid(entity) and entity:GetClass() == "nw_stash") then
			entity:OnStashClosed(client)
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()

		local subtitle = L("stashSub")

		if (NETWORK.container.IsLocked(self)) then
			subtitle = subtitle .. " · " .. L("containerLockedTag")
		end

		NETWORK.label.Draw(self, L("stashLabel"), subtitle)
	end
end
