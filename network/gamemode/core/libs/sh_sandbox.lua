NETWORK.sandbox = NETWORK.sandbox or {}

function NETWORK.sandbox.Check(client, permission)
	return IsValid(client) and client:HasPermission(permission)
end

function GM:SpawnMenuOpen()
	return NETWORK.sandbox.Check(LocalPlayer(), "spawnmenu")
end

function GM:ContextMenuOpen()
	return NETWORK.sandbox.Check(LocalPlayer(), "context")
end

function GM:PlayerSpawnProp(client)
	return NETWORK.sandbox.Check(client, "props")
end

function GM:PlayerSpawnSENT(client)
	return NETWORK.sandbox.Check(client, "props")
end

function GM:PlayerSpawnSWEP(client)
	return client:IsAdmin()
end

function GM:PlayerGiveSWEP(client)
	return client:IsAdmin()
end

function GM:PlayerSpawnNPC(client)
	return client:IsAdmin()
end

function GM:PlayerSpawnEffect(client)
	return NETWORK.sandbox.Check(client, "props")
end

function GM:PlayerSpawnRagdoll(client)
	return NETWORK.sandbox.Check(client, "props")
end

function GM:PlayerSpawnVehicle(client)
	return client:IsAdmin()
end

function GM:CanTool(client)
	return NETWORK.sandbox.Check(client, "tools")
end

function GM:PhysgunPickup(client)
	return NETWORK.sandbox.Check(client, "physgun")
end

function GM:CanProperty(client)
	return client:IsAdmin()
end

function GM:PlayerNoClip(client)
	return NETWORK.sandbox.Check(client, "noclip")
end

function GM:CanDrive()
	return false
end

local carryable = {
	nw_factory_box = true,
	nw_factory_part = true,
	nw_shopitem = true,
	nw_bodybag = true,
	nw_supply_crate = true,

	nw_furniture = true,

	nw_fridge = true,
	nw_vending = true
}

local business = {
	nw_fridge = true,
	nw_vending = true,
	nw_shopitem = true
}

local function CanCarryBusiness(client, entity)
	if (client:IsAdmin()) then
		return true
	end

	local owner = entity.nwOwner or entity:GetNWEntity("nwOwner", NULL)

	if (IsValid(owner) and owner == client) then
		return true
	end

	local door = entity.nwDoor or entity:GetNWEntity("nwDoor", NULL)

	if (IsValid(door) and NETWORK.door.GetData) then
		local data = NETWORK.door.GetData(door)

		if (data and data.owner and client:HasCharacter() and
			tostring(client:GetCharacterID()) == tostring(data.owner)) then
			return true
		end
	end

	return false
end

local CARRY_MASS = 85

local function CanCarryProp(entity)
	if (entity:GetClass() != "prop_physics" and
		entity:GetClass() != "prop_physics_multiplayer") then
		return false
	end

	local physics = entity:GetPhysicsObject()

	if (!IsValid(physics) or !physics:IsMoveable()) then
		return false
	end

	return physics:GetMass() <= CARRY_MASS
end

local function CanCarry(client, entity)
	local class = entity:GetClass()

	if (class == "nw_item") then
		local base = NETWORK.item.Get(entity.nwItemID or
			(entity.GetItemID and entity:GetItemID()) or "")

		return base != nil and base.bNoInventory == true
	end

	if (!carryable[class]) then
		return CanCarryProp(entity)
	end

	if (class == "nw_furniture" and entity:GetLocked()) then
		return false
	end

	if (business[class]) then
		return CanCarryBusiness(client, entity)
	end

	return true
end

function GM:AllowPlayerPickup(client, entity)
	return CanCarry(client, entity)
end

hook.Add("AllowPlayerPickup", "nwFactoryCarry", function(client, entity)
	if (CanCarry(client, entity)) then
		return true
	end
end)

hook.Add("GravGunPickupAllowed", "nwFactoryCarry", function(client, entity)
	if (CanCarry(client, entity)) then
		return true
	end
end)
