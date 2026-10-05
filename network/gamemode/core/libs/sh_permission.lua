NETWORK.permission = NETWORK.permission or {}
NETWORK.permission.stored = NETWORK.permission.stored or {}
NETWORK.permission.list = NETWORK.permission.list or {}

function NETWORK.permission.Register(id, name)
	if (!NETWORK.permission.stored[id]) then
		NETWORK.permission.list[#NETWORK.permission.list + 1] = id
	end

	NETWORK.permission.stored[id] = {id = id, name = name}
end

NETWORK.permission.Register("spawnmenu", "permSpawnMenu")
NETWORK.permission.Register("context", "permContext")
NETWORK.permission.Register("props", "permProps")
NETWORK.permission.Register("tools", "permTools")
NETWORK.permission.Register("physgun", "permPhysgun")
NETWORK.permission.Register("noclip", "permNoclip")

NETWORK.permission.Register("advert", "permAdvert")

local PLAYER = FindMetaTable("Player")

function PLAYER:HasPermission(id)
	if (self:IsAdmin()) then
		return true
	end

	return self:GetNWBool("nwPerm_" .. id, false)
end
