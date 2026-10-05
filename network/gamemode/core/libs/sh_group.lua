NETWORK.group = NETWORK.group or {}
NETWORK.group.list = NETWORK.group.list or {}

NETWORK.group.nameMax = 28
NETWORK.group.roleMax = 20
NETWORK.group.defaultSize = 6
NETWORK.group.maxSize = 24
NETWORK.group.inviteTime = 60

NETWORK.group.icons = {
	"icon16/group.png",
	"icon16/user_red.png",
	"icon16/shield.png",
	"icon16/heart.png",
	"icon16/wrench.png",
	"icon16/lightning.png",
	"icon16/star.png",
	"icon16/eye.png",
	"icon16/lock.png",
	"icon16/box.png",
	"icon16/car.png",
	"icon16/cross.png"
}

NETWORK.group.class = "rebel"

function NETWORK.group.CanCreate(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	return client:GetNWString("nwClass", "") == NETWORK.group.class
end

function NETWORK.group.CanAccess(client)
	client = client or (CLIENT and LocalPlayer())

	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.group.CanCreate(client)) then
		return true
	end

	if (CLIENT) then
		return NETWORK.group.own != nil
	end

	return NETWORK.group.GetOf(client) != nil
end

function NETWORK.group.IsIcon(path)
	for _, icon in ipairs(NETWORK.group.icons) do
		if (icon == path) then
			return true
		end
	end

	return false
end

function NETWORK.group.Get(id)
	return NETWORK.group.list[id]
end

function NETWORK.group.GetByCharacter(key)
	if (!key or key == "") then
		return
	end

	for id, group in pairs(NETWORK.group.list) do
		if (group.members and group.members[key]) then
			return group, id
		end
	end
end

function NETWORK.group.GetOf(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	return NETWORK.group.GetByCharacter(tostring(client:GetCharacterID()))
end

function NETWORK.group.IsLeader(client)
	local group = NETWORK.group.GetOf(client)

	if (!group) then
		return false
	end

	return group.leader == tostring(client:GetCharacterID())
end

function NETWORK.group.Count(group)
	local count = 0

	for _ in pairs(group and group.members or {}) do
		count = count + 1
	end

	return count
end

NETWORK.group.chatMax = 40
NETWORK.group.chatLength = 220

NETWORK.group.palette = {
	{id = "blue", color = Color(74, 178, 245)},
	{id = "cyan", color = Color(96, 214, 214)},
	{id = "green", color = Color(110, 206, 130)},
	{id = "amber", color = Color(228, 178, 78)},
	{id = "red", color = Color(226, 96, 92)},
	{id = "violet", color = Color(166, 130, 230)},
	{id = "grey", color = Color(168, 178, 192)}
}

NETWORK.group.layouts = {"list", "chat"}
NETWORK.group.messageStyles = {"plain", "compact", "plate"}

function NETWORK.group.GetColor(group)
	for _, entry in ipairs(NETWORK.group.palette) do
		if (entry.id == (group and group.color)) then
			return entry.color
		end
	end

	return NETWORK.group.palette[1].color
end

function NETWORK.group.GetStyle(group)
	group = group or {}

	return {
		color = group.color or "blue",
		bGradient = group.bGradient == true,
		layout = group.layout or "list",
		messages = group.messages or "plain"
	}
end
