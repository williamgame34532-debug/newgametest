-- The admin tools of the Q menu (the spawn menu, admins):
--   «Предметы»     a tab with every item of the server (framework/items and /itemedit) by category, the
--                  model as the icon. Click - the item lies in the world where you look (undo - Z);
--                  right click: copy the ID, give to myself, refresh the icon
--   the look       C menu, right click on a player: «Скин» and «Бодигруппы» (every group of the model with
--                  its variants), «Сбросить вид» - saved with the character (sv_appearance.lua, the same as
--                  /setskin, /setbodygroup, /resetlook). Props and other entities keep the sandbox ones.

-- the look of a player: the C menu
properties.Add("nw_look_skin", {
	MenuLabel = "Скин",
	Order = 601,
	MenuIcon = "icon16/picture_edit.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:IsPlayer() and IsValid(client) and client:IsAdmin() and entity:SkinCount() > 1
	end,
	MenuOpen = function(self, option, entity)
		local menu = option:AddSubMenu()

		for skin = 0, entity:SkinCount() - 1 do
			local choice = menu:AddOption("Скин " .. skin, function()
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteUInt(skin, 8)
				self:MsgEnd()
			end)

			if (entity:GetSkin() == skin) then
				choice:SetChecked(true)
			end
		end
	end,
	Action = function() end,
	Receive = function(self, _, client)
		local entity = net.ReadEntity()
		local skin = net.ReadUInt(8)

		if (self:Filter(entity, client)) then
			NW.appearance.SetSkin(entity, skin, client)
		end
	end
})

properties.Add("nw_look_bodygroups", {
	MenuLabel = "Бодигруппы",
	Order = 602,
	MenuIcon = "icon16/link_edit.png",
	Filter = function(self, entity, client)
		if (!IsValid(entity) or !entity:IsPlayer() or !IsValid(client) or !client:IsAdmin()) then
			return false
		end

		for index = 0, entity:GetNumBodyGroups() - 1 do
			if (entity:GetBodygroupCount(index) > 1) then
				return true
			end
		end

		return false
	end,
	MenuOpen = function(self, option, entity)
		local menu = option:AddSubMenu()

		for index = 0, entity:GetNumBodyGroups() - 1 do
			local count = entity:GetBodygroupCount(index)

			if (count > 1) then
				local group = menu:AddSubMenu(entity:GetBodygroupName(index) .. " (" .. count .. ")")

				for value = 0, count - 1 do
					local choice = group:AddOption(value == 0 and "0 — по умолчанию" or tostring(value), function()
						self:MsgStart()
							net.WriteEntity(entity)
							net.WriteUInt(index, 8)
							net.WriteUInt(value, 8)
						self:MsgEnd()
					end)

					if (entity:GetBodygroup(index) == value) then
						choice:SetChecked(true)
					end
				end
			end
		end
	end,
	Action = function() end,
	Receive = function(self, _, client)
		local entity = net.ReadEntity()
		local index = net.ReadUInt(8)
		local value = net.ReadUInt(8)

		if (self:Filter(entity, client)) then
			NW.appearance.SetGroup(entity, index, value, client)
		end
	end
})

properties.Add("nw_look_reset", {
	MenuLabel = "Сбросить вид",
	Order = 603,
	MenuIcon = "icon16/arrow_undo.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:IsPlayer() and IsValid(client) and client:IsAdmin()
	end,
	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,
	Receive = function(self, _, client)
		local entity = net.ReadEntity()

		if (self:Filter(entity, client)) then
			NW.appearance.Reset(entity, client)
		end
	end
})

if (SERVER) then
	util.AddNetworkString("nwSpawnItem")

	local INV = NW.inventory
	local I = NW.items

	net.Receive("nwSpawnItem", function(_, client)
		local id = net.ReadString()
		local bGive = net.ReadBool()
		local item = I.Get(id)

		if (!IsValid(client) or !client:IsAdmin() or !item) then
			return
		end

		if (bGive) then
			if (client:GetCharacterID() == 0 or !INV.Add(client, id)) then
				return NW.Notify(client, "Нет места в инвентаре")
			end

			INV.Changed(client)
			NW.Notify(client, "Выдано: " .. item.name)
			MsgN(string.format("[ITEMS] %s выдал себе %s", client:Nick(), id))

			return
		end

		local trace = util.TraceLine({start = client:GetShootPos(), endpos = client:GetShootPos() + client:GetAimVector() * 84,
			filter = client})
		local entity = ents.Create("nw_item")

		if (!IsValid(entity)) then
			return
		end

		entity:SetItem(id, {})
		entity:SetPos(trace.HitPos + trace.HitNormal * 10 + Vector(0, 0, 6))
		entity:SetAngles(Angle(0, client:EyeAngles().y + 90, 0))
		entity:Spawn()

		undo.Create(item.name)
			undo.AddEntity(entity)
			undo.SetPlayer(client)
		undo.Finish()

		MsgN(string.format("[ITEMS] %s создал %s", client:Nick(), id))
	end)

	return
end

-- ------------------------------------------------------------------ client --
local I = NW.items

local ICONS = {
	food = "icon16/cake.png",
	drink = "icon16/cup.png",
	medical = "icon16/heart.png",
	weapon = "icon16/gun.png",
	clothing = "icon16/user_suit.png",
	misc = "icon16/box.png"
}

local function Request(id, bGive)
	net.Start("nwSpawnItem")
		net.WriteString(id)
		net.WriteBool(bGive)
	net.SendToServer()
end

spawnmenu.AddContentType("nw_item", function(panel, data)
	local item = I.Get(data.spawnname)

	if (!item) then
		return
	end

	local icon = vgui.Create("SpawnIcon", panel)

	icon:SetSize(64, 64)
	icon:SetModel(item.model or "models/props_junk/cardboard_box004a.mdl")
	icon:SetTooltip(item.name .. "\n" .. data.spawnname .. (item.description and ("\n\n" .. item.description) or ""))
	icon.DoClick = function()
		surface.PlaySound("ui/buttonclickrelease.wav")
		Request(data.spawnname, false)
	end
	icon.OpenMenu = function(self)
		local menu = DermaMenu()

		menu:AddOption("Копировать ID", function()
			SetClipboardText(data.spawnname)
		end):SetIcon("icon16/page_copy.png")
		menu:AddOption("Выдать себе", function()
			Request(data.spawnname, true)
		end):SetIcon("icon16/user_add.png")
		menu:AddOption("Обновить иконку", function()
			if (IsValid(self)) then
				self:RebuildSpawnIcon()
			end
		end):SetIcon("icon16/arrow_refresh.png")
		menu:Open()
	end

	if (IsValid(panel)) then
		panel:Add(icon)
	end

	return icon
end)

spawnmenu.AddCreationTab("Предметы", function()
	local panel = vgui.Create("SpawnmenuContentPanel")
	local tree = panel.ContentNavBar.Tree
	local order = {"food", "drink", "medical", "weapon", "clothing", "misc"}

	for _, category in ipairs(order) do
		local info = I.categories[category]
		local node = tree:AddNode(info and info.name or category, ICONS[category] or "icon16/folder.png")

		node.DoClick = function(self)
			if (IsValid(self.PropPanel)) then
				self.PropPanel:Remove()
			end

			-- built on every click: the items changed by /itemedit are there at once
			self.PropPanel = vgui.Create("ContentContainer", panel)
			self.PropPanel:SetVisible(false)
			self.PropPanel:SetTriggerSpawnlistChange(false)

			local items = {}

			for id, item in pairs(I.list) do
				if ((I.categories[item.category] and item.category or "misc") == category) then
					items[#items + 1] = {id = id, name = item.name or id}
				end
			end

			table.SortByMember(items, "name", true)

			for _, entry in ipairs(items) do
				spawnmenu.CreateContentIcon("nw_item", self.PropPanel, {nicename = entry.name, spawnname = entry.id})
			end

			panel:SwitchPanel(self.PropPanel)
		end
	end

	local first = tree:Root():GetChildNode(0)

	if (IsValid(first)) then
		first:InternalDoClick()
	end

	return panel
end, "icon16/box.png", 201)
