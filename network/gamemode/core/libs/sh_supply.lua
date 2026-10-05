NETWORK.supply = NETWORK.supply or {}

local S = NETWORK.supply

S.fundMax = 100
S.fundRegen = 1
S.fundInterval = 60
S.autoAfter = 300
S.autoDelay = 60
S.workerPay = 25
S.maxActive = 6
S.crateHealth = 120
S.deliverRange = 160
S.carryDistance = 150

S.catalog = {
	{id = "ammo_pistol", name = "supplyAmmoPistol", cost = 10,
		items = {{"ammo_pistol", 4}}},
	{id = "ammo_smg", name = "supplyAmmoSMG", cost = 14,
		items = {{"ammo_smg", 4}}},
	{id = "ammo_ar2", name = "supplyAmmoAR2", cost = 20,
		items = {{"ammo_ar2", 3}}},
	{id = "ammo_buckshot", name = "supplyAmmoShotgun", cost = 14,
		items = {{"ammo_buckshot", 3}}},
	{id = "medical", name = "supplyMedical", cost = 22,
		items = {{"bandage", 4}, {"tourniquet", 2}, {"syringe", 2}}},
	{id = "trauma", name = "supplyTrauma", cost = 35,
		items = {{"medkit", 1}, {"chestseal", 2}, {"splint", 2}, {"bloodbag", 1}}},
	{id = "restraints", name = "supplyRestraints", cost = 8,
		items = {{"zipties", 4}, {"bodybag", 2}}},
	{id = "rations", name = "supplyRations", cost = 12,
		items = {{"ration_standard", 4}, {"water_breen", 4}}},
	{id = "filters", name = "supplyFilters", cost = 10,
		items = {{"gasmask_filter", 4}}},
	{id = "forms", name = "supplyForms", cost = 6,
		items = {{"blank_form", 5}}}
}

S.statuses = {
	pending = "supplyStatusPending",
	assigned = "supplyStatusAssigned",
	transit = "supplyStatusTransit",
	delivered = "supplyStatusDelivered",
	opened = "supplyStatusOpened",
	lost = "supplyStatusLost",
	cancelled = "supplyStatusCancelled"
}

function S.GetEntry(id)
	for _, entry in ipairs(S.catalog) do
		if (entry.id == id) then
			return entry
		end
	end
end

S.orderClass = "cmd"

function S.CanOrder(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	local class = client:GetNWString("nwClass", "")

	if (NETWORK.classes.IsAdministrativeID(class)) then
		return true
	end

	return client:GetCharacterFaction() == "cp" and class == S.orderClass
end
