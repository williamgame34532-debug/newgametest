net.Receive("nwIconSync", function()
	NETWORK.icon.stored = NETWORK.util.ReadTable()

	hook.Run("NetworkIconsUpdated")
end)

net.Receive("nwIconEditor", function()
	if (NETWORK.gui.OpenIconEditor) then
		NETWORK.gui.OpenIconEditor()
	end
end)

function NETWORK.icon.Send(id, data)
	net.Start("nwIconSave")
		net.WriteString(id)
		NETWORK.util.WriteTable(data)
	net.SendToServer()
end

NETWORK.icon.panels = NETWORK.icon.panels or {}

function NETWORK.icon.GetDefault(model)
	local entity = ClientsideModel(model, RENDERGROUP_OPAQUE)

	if (!IsValid(entity)) then
		return {pos = {28, 0, 0}, ang = {0, 180, 0}, fov = 40}
	end

	entity:SetNoDraw(true)

	local mins, maxs = entity:GetRenderBounds()
	local center = (mins + maxs) * 0.5
	local size = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z)
	local distance = math.max(size * 1.6, 12)

	entity:Remove()

	return {
		pos = {center.x + distance * 0.7, center.y + distance * 0.7,
			center.z + distance * 0.45},
		ang = {0, 0, 0},
		fov = 40,
		center = {center.x, center.y, center.z}
	}
end
