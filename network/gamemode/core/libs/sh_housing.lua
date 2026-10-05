NETWORK.housing = NETWORK.housing or {}

local H = NETWORK.housing

H.perType = 10

H.furniture = {
	{id = "chair", name = "Стул", model = "models/props_c17/FurnitureChair001a.mdl"},
	{id = "table", name = "Стол", model = "models/props_c17/FurnitureTable002a.mdl"},
	{id = "fridge", name = "Холодильник", model = "models/props_c17/FurnitureFridge001a.mdl"},
	{id = "bed", name = "Кровать", model = "models/props_c17/FurnitureBed001a.mdl"},
	{id = "cabinet", name = "Шкаф", model = "models/props_c17/FurnitureDrawer001a.mdl"},
	{id = "lamp", name = "Лампа", model = "models/props_c17/lamp001a.mdl"},
	{id = "shelf", name = "Полка", model = "models/props_c17/FurnitureShelf001a.mdl"},
	{id = "couch", name = "Диван", model = "models/props_c17/FurnitureCouch001a.mdl"}
}

function H.GetFurniture(id)
	for _, entry in ipairs(H.furniture) do
		if (entry.id == id) then
			return entry
		end
	end
end

function H.GetHome(client)
	local steamID = client:SteamID64()

	for _, entity in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(entity)) then
			local data = NETWORK.door.GetData(entity)

			if (data and data.type == "residential" and NETWORK.door.IsOwner(data, steamID)) then
				return entity, NETWORK.zone.AtEntity(entity)
			end
		end
	end
end

H.homeRange = 300

function H.IsAtHome(client)
	local door, zone = H.GetHome(client)

	if (!IsValid(door)) then
		return false
	end

	local distance = client:GetPos():Distance(door:GetPos())

	if (zone) then
		local here = NETWORK.zone.At(client:GetPos())

		if (here != nil and here.id == zone.id) then
			return true
		end

		return distance <= H.homeRange
	end

	return distance <= H.homeRange
end

if (SERVER) then
	util.AddNetworkString("nwHousingMenu")
	util.AddNetworkString("nwHousingMenuRequest")
	util.AddNetworkString("nwHousingPick")
	util.AddNetworkString("nwHousingRemove")

	function H.RequestMenu(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (!H.IsAtHome(client)) then
			return NETWORK.notice.Send(client, "housingNotHome", "warn")
		end

		net.Start("nwHousingMenu")
		net.Send(client)
	end

	net.Receive("nwHousingMenuRequest", function(_, client)
		if ((client.nwNextHousingMenu or 0) > CurTime()) then
			return
		end

		client.nwNextHousingMenu = CurTime() + 0.5

		H.RequestMenu(client)
	end)

	NETWORK.command.Register("furniture", {
		description = "cmdFurniture",
		usage = "/furniture",
		aliases = {"mebel", "home"},
		OnRun = function(command, client)
			H.RequestMenu(client)
		end
	})

	function H.ClearFurniture(charID)
		if (!charID) then
			return 0
		end

		local removed = 0

		for _, entity in ipairs(ents.FindByClass("nw_furniture")) do
			if (entity:GetOwnerChar() == tostring(charID)) then
				entity:Remove()

				removed = removed + 1
			end
		end

		return removed
	end

	function H.Count(client, id)
		local count = 0
		local char = tostring(client:GetCharacterID())

		for _, entity in ipairs(ents.FindByClass("nw_furniture")) do
			if (entity:GetOwnerChar() == char and entity:GetKind() == id) then
				count = count + 1
			end
		end

		return count
	end

	NETWORK.placer.Register("furniture", {
		CanPlace = function(client, placing, position)
			if (!H.IsAtHome(client)) then
				return false, "housingNotHome"
			end

			local zone = NETWORK.zone.At(position)
			local _, homeZone = H.GetHome(client)

			if (homeZone and (!zone or zone.id != homeZone.id)) then
				return false, "housingNotHome"
			end

			if (H.Count(client, placing.payload) >= H.perType) then
				return false, "housingLimit"
			end

			return true
		end,
		OnPlace = function(client, placing, position, angles)
			local entity = ents.Create("nw_furniture")

			entity:SetPos(position)
			entity:SetAngles(angles)
			entity:SetFurnModel(placing.model)
			entity:SetKind(placing.payload)
			entity:SetOwnerChar(tostring(client:GetCharacterID()))
			entity:Spawn()

			NETWORK.notice.Send(client, "housingPlaced", "good")
		end
	})

	net.Receive("nwHousingPick", function(_, client)
		local id = net.ReadString()
		local entry = H.GetFurniture(id)

		if (!entry or !H.IsAtHome(client)) then
			return NETWORK.notice.Send(client, "housingNotHome", "warn")
		end

		if (H.Count(client, id) >= H.perType) then
			return NETWORK.notice.Send(client, "housingLimit", "warn")
		end

		NETWORK.placer.Begin(client, "furniture", entry.model, id)
	end)

	net.Receive("nwHousingRemove", function(_, client)
		local entity = net.ReadEntity()

		if (IsValid(entity) and entity:GetClass() == "nw_furniture" and
			(entity:GetOwnerChar() == tostring(client:GetCharacterID()) or client:IsAdmin()) and
			client:GetPos():Distance(entity:GetPos()) < 200) then
			entity:Remove()
		end
	end)

	return
end

local holdStart

hook.Add("PlayerBindPress", "nwHousingMenu", function(client, bind, bPressed)
	if (bind != "+menu") then
		return
	end

	local bShift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

	local bCanProps = NETWORK.sandbox and NETWORK.sandbox.Check and
		NETWORK.sandbox.Check(client, "props")

	if (!bShift and bCanProps) then
		holdStart = nil

		return
	end

	if (!H.IsAtHome(client)) then
		holdStart = nil

		return
	end

	if (bPressed) then
		holdStart = RealTime()
	else
		holdStart = nil
	end

	return true
end)

hook.Add("Think", "nwHousingMenu", function()
	if (!holdStart or RealTime() - holdStart < 0.4) then
		return
	end

	holdStart = nil

	local client = LocalPlayer()

	local bCanProps = NETWORK.sandbox and NETWORK.sandbox.Check and
		NETWORK.sandbox.Check(client, "props")

	if (bCanProps and !input.IsKeyDown(KEY_LSHIFT) and !input.IsKeyDown(KEY_RSHIFT)) then
		return
	end

	net.Start("nwHousingMenuRequest")
	net.SendToServer()
end)

net.Receive("nwHousingMenu", function()
	H.OpenMenu()
end)

function H.OpenMenu()
	if (IsValid(NETWORK.gui.housingMenu)) then
		NETWORK.gui.housingMenu:Remove()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = vgui.Create("EditablePanel")
	local columns = 4
	local tile = Sc(120)
	local gap = Sc(10)
	local rows = math.ceil(#H.furniture / columns)

	NETWORK.gui.housingMenu = panel
	panel:SetSize(columns * (tile + gap) + Sc(30), rows * (tile + gap) + Sc(80))
	panel:Center()
	panel:MakePopup()
	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE or key == KEY_Q) then
			this:Remove()
		end
	end
	panel.Paint = function(this, width, height)
		NETWORK.gui.DrawBlackGlass(this, 0, 0, width, height, 1, Sc(14))
		draw.SimpleText("МЕБЕЛЬ ДЛЯ КВАРТИРЫ", "nwInvTitle", Sc(20), Sc(26), theme.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("До " .. H.perType .. " штук каждого вида", "nwHudSmall", width - Sc(20),
			Sc(26), theme.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	for index, entry in ipairs(H.furniture) do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local button = panel:Add("DButton")

		button:SetText("")
		button:SetSize(tile, tile)
		button:SetPos(Sc(15) + column * (tile + gap), Sc(50) + row * (tile + gap))
		button.DoClick = function()
			net.Start("nwHousingPick")
				net.WriteString(entry.id)
			net.SendToServer()

			panel:Remove()
		end
		button.Paint = function(this, width, height)
			draw.RoundedBox(Sc(10), 0, 0, width, height, Color(0, 0, 0, 150))

			if (this:IsHovered()) then
				draw.RoundedBox(Sc(10), 0, 0, width, height, ColorAlpha(theme.hover, 26))
			end

			NETWORK.util.DrawRoundedBorder(0, 0, width, height, Sc(10), 1,
				ColorAlpha(this:IsHovered() and theme.hover or Color(255, 255, 255),
				this:IsHovered() and 200 or 30))
			draw.SimpleText(entry.name, "nwField", width * 0.5, height - Sc(16), theme.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local icon = button:Add("DModelPanel")

		icon:SetPos(Sc(10), Sc(6))
		icon:SetSize(tile - Sc(20), tile - Sc(36))
		icon:SetModel(entry.model)
		icon:SetMouseInputEnabled(false)
		icon.LayoutEntity = function(this, ent)
			ent:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
		end

		local ent = icon:GetEntity()

		if (IsValid(ent)) then
			local mins, maxs = ent:GetRenderBounds()
			local center = (mins + maxs) * 0.5
			local size = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z)

			icon:SetLookAt(center)
			icon:SetCamPos(center + Vector(size, size, size * 0.6))
			icon:SetFOV(40)
		end
	end
end

properties.Add("nw_furniture_remove", {
	MenuLabel = "Убрать мебель",
	Order = 100,
	MenuIcon = "icon16/delete.png",
	Filter = function(_, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_furniture" and
			(entity:GetOwnerChar() == tostring(client:GetCharacterID()) or client:IsAdmin())
	end,
	Action = function(_, entity)
		net.Start("nwHousingRemove")
			net.WriteEntity(entity)
		net.SendToServer()
	end
})
