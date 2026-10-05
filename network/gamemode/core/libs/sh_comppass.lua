NETWORK.comppass = NETWORK.comppass or {}

local CP = NETWORK.comppass

CP.classes = {
	nw_admin_computer = true,
	nw_council_computer = true,
	nw_medcomputer = true,
	nw_cwu_computer = true
}

CP.unlockTime = 300
CP.maxLength = 24

function CP.GetHash(entity)
	return IsValid(entity) and entity.GetPassHash and entity:GetPassHash() or ""
end

function CP.HasPassword(entity)
	return CP.GetHash(entity) != ""
end

function CP.CanSet(client, entity)
	if (!IsValid(client) or !IsValid(entity) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	local class = entity:GetClass()

	if (class == "nw_admin_computer" or class == "nw_council_computer") then
		return NETWORK.classes.IsAdministrative(client)
	end

	if (class == "nw_cwu_computer") then
		return NETWORK.admincomp and NETWORK.admincomp.IsCWUHead and
			NETWORK.admincomp.IsCWUHead(client, entity)
	end

	if (class == "nw_medcomputer") then
		return NETWORK.meddb and NETWORK.meddb.CanUse and NETWORK.meddb.CanUse(client)
	end

	return false
end

properties.Add("nwCompPassword", {
	MenuLabel = "Компьютер: пароль",
	Order = 4,
	MenuIcon = "icon16/lock.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and CP.classes[entity:GetClass()] == true and CP.CanSet(client, entity)
	end,
	Action = function(self, entity)
		Derma_StringRequest("Пароль компьютера",
			"Новый пароль (пустая строка — снять пароль):", "", function(text)
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteString(string.sub(text, 1, CP.maxLength))
				self:MsgEnd()
			end)
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local text = string.Trim(net.ReadString())

		if (!self:Filter(entity, client) or !entity.SetPassHash) then
			return
		end

		local hash = text == "" and "" or util.SHA256(text)

		entity:SetPassHash(hash)

		if (CP.Store) then
			CP.Store(entity, hash)
		end

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		NETWORK.notice.Send(client, text == "" and "compPassCleared" or "compPassSet",
			"good")
	end
})

if (SERVER) then
	util.AddNetworkString("nwCompPassAsk")
	util.AddNetworkString("nwCompPassReply")

	CP.path = "network/comppass.txt"
	CP.stored = CP.stored or nil

	local function Key(entity)
		local position = entity:GetPos()

		return string.format("%s@%d_%d_%d", entity:GetClass(), math.Round(position.x),
			math.Round(position.y), math.Round(position.z))
	end

	function CP.Load()
		local raw = file.Read(CP.path, "DATA")

		CP.stored = raw and util.JSONToTable(raw) or {}
	end

	function CP.Save()
		file.CreateDir("network")
		file.Write(CP.path, util.TableToJSON(CP.stored or {}, true))
	end

	function CP.Store(entity, hash)
		if (!CP.stored) then
			CP.Load()
		end

		CP.stored[Key(entity)] = hash != "" and hash or nil
		CP.Save()
	end

	function CP.Restore(entity)
		if (!IsValid(entity) or !entity.SetPassHash) then
			return
		end

		if (!CP.stored) then
			CP.Load()
		end

		local hash = CP.stored[Key(entity)]

		if (hash and hash != "" and entity:GetPassHash() == "") then
			entity:SetPassHash(hash)
		end
	end

	hook.Add("OnEntityCreated", "nwCompPassRestore", function(entity)
		if (!IsValid(entity) or !CP.classes[entity:GetClass()]) then
			return
		end

		timer.Simple(0.6, function()
			if (IsValid(entity)) then
				CP.Restore(entity)
			end
		end)
	end)

	hook.Add("InitPostEntity", "nwCompPassRestore", function()
		timer.Simple(3, function()
			for class in pairs(CP.classes) do
				for _, entity in ipairs(ents.FindByClass(class)) do
					CP.Restore(entity)
				end
			end
		end)
	end)

	function CP.Request(client, entity, callback)
		if (!IsValid(client) or !IsValid(entity)) then
			return
		end

		local hash = CP.GetHash(entity)

		if (hash == "") then
			return callback()
		end

		client.nwCompUnlock = client.nwCompUnlock or {}

		if ((client.nwCompUnlock[entity] or 0) > CurTime()) then
			return callback()
		end

		client.nwCompPending = {entity = entity, callback = callback, time = CurTime()}

		net.Start("nwCompPassAsk")
			net.WriteEntity(entity)
		net.Send(client)
	end

	net.Receive("nwCompPassReply", function(_, client)
		local entity = net.ReadEntity()
		local text = string.sub(net.ReadString(), 1, CP.maxLength)
		local pending = client.nwCompPending

		client.nwCompPending = nil

		if (!pending or pending.entity != entity or !IsValid(entity) or
			CurTime() - pending.time > 60) then
			return
		end

		if ((client.nwCompPassNext or 0) > CurTime()) then
			return
		end

		client.nwCompPassNext = CurTime() + 1

		if (client:GetPos():Distance(entity:GetPos()) > 160) then
			return
		end

		if (util.SHA256(text) != CP.GetHash(entity)) then
			entity:EmitSound(NETWORK.sound.computer.deny, 60, 80)

			return NETWORK.notice.Send(client, "compPassWrong", "bad")
		end

		client.nwCompUnlock = client.nwCompUnlock or {}
		client.nwCompUnlock[entity] = CurTime() + CP.unlockTime

		entity:EmitSound(NETWORK.sound.computer.enter, 60, 100)

		pending.callback()
	end)

	return
end

net.Receive("nwCompPassAsk", function()
	local entity = net.ReadEntity()

	if (IsValid(NETWORK.gui.compPass)) then
		NETWORK.gui.compPass:Remove()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local panel = vgui.Create("EditablePanel")

	NETWORK.gui.compPass = panel
	panel:SetSize(Sc(380), Sc(170))
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel.alpha = 0
	panel.shake = 0

	panel.Think = function(this)
		this.alpha = util.Approach(this.alpha, 1, 10)
		this:SetAlpha(math.Round(this.alpha * 255))

		if (!IsValid(entity) or LocalPlayer():GetPos():DistToSqr(entity:GetPos()) > 200 * 200) then
			this:Remove()
		end
	end

	panel.Paint = function(this, width, height)
		local radius = math.max(Sc(10), 6)

		util.DrawBlurRounded(this, 0, 0, width, height, radius, 4)
		draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 238))
		util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			Color(255, 255, 255, 26))

		NETWORK.gui.DrawGlyph("shield", Sc(20), Sc(18), Sc(16), theme.combine)
		draw.SimpleText(util.Upper(L("compPassTitle")), "nwInvKey", Sc(44), Sc(26),
			ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("compPassHint"), "nwInvBody", Sc(20), Sc(52), theme.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("compPassKeys"), "nwHudSmall", Sc(20), height - Sc(18),
			theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local entry = panel:Add("DTextEntry")

	entry:SetPos(Sc(20), Sc(74))
	entry:SetSize(Sc(340), Sc(36))
	entry:SetFont("nwInvBody")
	entry:SetPaintBackground(false)
	entry:SetTextColor(Color(0, 0, 0, 0))
	entry:SetCursorColor(theme.text)
	entry:SetDrawLanguageID(false)
	entry:SetAllowNonAsciiCharacters(true)
	entry:RequestFocus()
	entry.Paint = function(this, width, height)
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, 230))
		util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			this:HasFocus() and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))

		local dots = string.rep("•", utf8.len(this:GetValue()) or #this:GetValue())

		draw.SimpleText(dots, "nwInvTitle", Sc(12), height * 0.5, theme.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		if (dots == "" and !this:HasFocus()) then
			draw.SimpleText(L("compPassPlaceholder"), "nwInvBody", Sc(12), height * 0.5,
				theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	entry.OnEnter = function(this)
		local text = string.sub(this:GetValue(), 1, CP.maxLength)

		if (text == "") then
			return
		end

		net.Start("nwCompPassReply")
			net.WriteEntity(entity)
			net.WriteString(text)
		net.SendToServer()

		surface.PlaySound(NETWORK.sound.ComputerKeys())
		panel:Remove()
	end

	local ok = panel:Add("nwInvButton")

	ok:SetSize(Sc(150), Sc(28))
	ok:SetPos(Sc(380) - Sc(170), Sc(120))
	ok:Setup(L("compPassEnter"), "chevron", true)
	ok.DoClick = function()
		entry:OnEnter()
	end

	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			this:Remove()
		end
	end
end)
