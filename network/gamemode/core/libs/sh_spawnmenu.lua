NETWORK.spawnmenu = NETWORK.spawnmenu or {}

NETWORK.spawnmenu.icons = {
	weapon = "icon16/gun.png",
	weapons = "icon16/gun.png",
	medical = "icon16/heart.png",
	food = "icon16/pill.png",
	rations = "icon16/box.png",
	clothing = "icon16/user_suit.png",
	armour = "icon16/shield.png",
	junk = "icon16/brick.png",
	container = "icon16/package.png",
	documents = "icon16/note.png",
	misc = "icon16/error.png"
}

function NETWORK.spawnmenu.GetIcon(category)
	return hook.Run("NetworkItemMenuIcon", category) or
		NETWORK.spawnmenu.icons[category] or "icon16/folder.png"
end

function NETWORK.spawnmenu.GetCategoryName(category)
	local key = "itemCat" .. string.upper(string.sub(category, 1, 1)) ..
		string.sub(category, 2)
	local translated = L(key)

	return translated != key and translated or category
end

if (SERVER) then
	util.AddNetworkString("nwItemSpawn")
	util.AddNetworkString("nwItemGive")

	local function CanSpawn(client)
		return IsValid(client) and client:IsAdmin() and client:HasCharacter()
	end

	net.Receive("nwItemSpawn", function(_, client)
		local id = net.ReadString()

		if (!CanSpawn(client) or !NETWORK.item.Get(id)) then
			return
		end

		if ((client.nwNextSpawnItem or 0) > CurTime()) then
			return
		end

		client.nwNextSpawnItem = CurTime() + 0.15

		local entity = NETWORK.item.Spawn(id,
			client:GetShootPos() + client:GetAimVector() * 84 + Vector(0, 0, 16))

		if (IsValid(entity)) then
			undo.Create("Item")
			undo.AddEntity(entity)
			undo.SetPlayer(client)
			undo.Finish(NETWORK.item.Get(id).name)
		end

		NETWORK.util.Print(string.format("%s заспавнил предмет: %s",
			client:GetCharacterName(), id))
	end)

	net.Receive("nwItemGive", function(_, client)
		local id = net.ReadString()

		if (!CanSpawn(client) or !NETWORK.item.Get(id)) then
			return
		end

		if ((client.nwNextSpawnItem or 0) > CurTime()) then
			return
		end

		client.nwNextSpawnItem = CurTime() + 0.15

		local function Notice(key)
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(key)
			net.Send(client)
		end

		if (NETWORK.inventory.Give(client, id, 1)) then
			Notice("itemGiven")
		else
			Notice("invNoRoom")
		end
	end)

	return
end

local function BuildTab()
	local panel = vgui.Create("SpawnmenuContentPanel")
	local tree = panel.ContentNavBar.Tree
	local categories = {}
	local custom = {}

	for _, item in ipairs(NETWORK.item.GetAll()) do
		local category = item.category or "misc"

		categories[category] = categories[category] or {}
		categories[category][#categories[category] + 1] = item

		if (item.bCustom) then
			custom[#custom + 1] = item
		end
	end

	local function AddCategoryNode(name, icon, items)
		local node = tree:AddNode(name, icon)

		node.DoClick = function(self)
			if (IsValid(self.PropPanel)) then
				self.PropPanel:Remove()

				self.PropPanel = nil
			end

			self.PropPanel = vgui.Create("ContentContainer", panel)

			self.PropPanel:SetVisible(false)
			self.PropPanel:SetTriggerSpawnlistChange(false)

			for _, item in SortedPairsByMemberValue(items, "name") do
				spawnmenu.CreateContentIcon("nwitem", self.PropPanel, {
					nicename = L(item.name),
					spawnname = item.id
				})
			end

			panel:SwitchPanel(self.PropPanel)
		end

		return node
	end

	local create = tree:AddNode(L("itemCreateNode"), "icon16/add.png")

	create.DoClick = function()
		if (NETWORK.itemedit and NETWORK.itemedit.OpenCreator) then
			NETWORK.itemedit.OpenCreator()
		end
	end

	if (#custom > 0) then
		AddCategoryNode(L("itemCreateCustomNode"), "icon16/star.png", custom)
	end

	for category, items in SortedPairs(categories) do
		AddCategoryNode(NETWORK.spawnmenu.GetCategoryName(category),
			NETWORK.spawnmenu.GetIcon(category), items)
	end

	local first = tree:Root():GetChildNode(1)

	if (IsValid(first)) then
		first:InternalDoClick()
	end

	return panel
end

spawnmenu.AddContentType("nwitem", function(container, data)
	local id = data.spawnname
	local base = NETWORK.item.Get(id)

	if (!base) then
		return
	end

	local icon = vgui.Create("SpawnIcon", container)

	icon:SetWide(64)
	icon:SetTall(64)
	icon:SetModel(base.model or "models/props_junk/wood_crate001a.mdl")
	icon:SetTooltip(data.nicename .. "\n" .. id ..
		(base.bCustom and ("\n" .. L("itemCreateCustomTag")) or ""))
	icon:InvalidateLayout(true)

	icon.DoClick = function()
		if (!LocalPlayer():IsAdmin()) then
			return
		end

		surface.PlaySound("ui/buttonclickrelease.wav")

		net.Start("nwItemSpawn")
			net.WriteString(id)
		net.SendToServer()
	end

	icon.OpenMenu = function()
		local menu = DermaMenu()

		menu:AddOption(L("spawnCopyID"), function()
			SetClipboardText(id)
		end):SetIcon("icon16/page_copy.png")

		menu:AddOption(L("spawnGiveSelf"), function()
			net.Start("nwItemGive")
				net.WriteString(id)
			net.SendToServer()
		end):SetIcon("icon16/user_add.png")

		menu:AddOption(L("spawnRefresh"), function()
			if (IsValid(icon)) then
				icon:RebuildSpawnIcon()
			end
		end):SetIcon("icon16/arrow_refresh.png")

		if (NETWORK.itemedit and NETWORK.itemedit.AddMenuOptions) then
			NETWORK.itemedit.AddMenuOptions(menu, id)
		end

		menu:Open()
	end

	if (IsValid(container)) then
		container:Add(icon)
	end

	return icon
end)

hook.Add("InitPostEntity", "nwItemSpawnMenu", function()
	timer.Simple(1, function()
		if (!LocalPlayer():IsAdmin()) then
			return
		end

		spawnmenu.AddCreationTab(L("spawnTab"), BuildTab, "icon16/box.png", 201)

		RunConsoleCommand("spawnmenu_reload")
	end)
end)
