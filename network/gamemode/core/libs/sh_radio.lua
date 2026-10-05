NETWORK.radio = NETWORK.radio or {}

local R = NETWORK.radio

R.itemID = "radio"
R.minFreq = 100
R.maxFreq = 199.9
R.hearRange = 320
R.color = Color(96, 210, 96)

function R.Normalise(value)
	local number = tonumber(string.Trim(string.gsub(tostring(value or ""), ",", ".")))

	if (!number) then
		return
	end

	number = math.Round(number, 1)

	if (number < R.minFreq or number > R.maxFreq) then
		return
	end

	return string.format("%.1f", number)
end

function R.GetFreq(client)
	return IsValid(client) and client:GetNWString("nwRadioFreq", "") or ""
end

function R.IsTransmitting(client)
	return IsValid(client) and client:GetNWBool("nwRadioTx", false) and R.GetFreq(client) != ""
end

function R.SameFreq(a, b)
	local freq = R.GetFreq(a)

	return freq != "" and freq == R.GetFreq(b)
end

NETWORK.chat.Register("radio", {
	bBubble = true,
	prefix = {"/r", "/radio"},
	format = "chatRadioItem",
	color = R.color,
	font = "nwChat",
	radius = R.hearRange,
	order = 18,
	bSolidColor = true,
	bRadio = true,

	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (R.SameFreq(speaker, listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <= class.radius * class.radius
	end,
	OnRadioListener = function(class, speaker, listener)
		return R.SameFreq(speaker, listener)
	end,
	OnCanUse = function(class, client)
		if (R.GetFreq(client) == "") then
			return false, "radioNoFreq"
		end

		return true
	end
})

if (SERVER) then
	util.AddNetworkString("nwRadioMenu")
	util.AddNetworkString("nwRadioSet")

	function R.FindItem(client)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"equipped", "items", "storage"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == R.itemID) then
					return item
				end
			end
		end
	end

	function R.Refresh(client)
		if (!IsValid(client)) then
			return
		end

		local item = client:HasCharacter() and R.FindItem(client)
		local freq = item and R.Normalise(item.freq) or ""
		local bTx = item and freq != "" and item.tx == true or false

		if (client:GetNWString("nwRadioFreq", "") != freq) then
			client:SetNWString("nwRadioFreq", freq)
		end

		if (client:GetNWBool("nwRadioTx", false) != bTx) then
			client:SetNWBool("nwRadioTx", bTx)
		end
	end

	function R.OpenMenu(client)
		local item = R.FindItem(client)

		if (!item) then
			return
		end

		net.Start("nwRadioMenu")
			net.WriteString(R.Normalise(item.freq) or "")
			net.WriteBool(item.tx == true)
		net.Send(client)
	end

	net.Receive("nwRadioSet", function(_, client)
		local freqText = net.ReadString()
		local bTx = net.ReadBool()

		if ((client.nwNextRadioSet or 0) > CurTime()) then
			return
		end

		client.nwNextRadioSet = CurTime() + 0.3

		local item = R.FindItem(client)

		if (!item) then
			return
		end

		local freq = R.Normalise(freqText)

		if (freqText != "" and !freq) then
			return NETWORK.notice.Send(client, "radioFreqBad", "warn")
		end

		local bChanged = (item.freq != freq) or ((item.tx == true) != bTx)

		item.freq = freq
		item.tx = (freq != nil) and bTx or nil

		R.Refresh(client)
		NETWORK.inventory.Sync(client)

		if (bChanged) then
			local sounds = NETWORK.chat.radioOnRadio

			client:EmitSound(sounds[math.random(#sounds)], 55, math.random(98, 104))

			if (freq) then
				NETWORK.notice.Send(client, item.tx and "radioTxOn" or "radioFreqSet", "good", freq)
			else
				NETWORK.notice.Send(client, "radioFreqCleared", "info")
			end
		end
	end)

	timer.Create("nwRadioItemScan", 1, 0, function()
		for _, client in ipairs(player.GetAll()) do
			R.Refresh(client)
		end
	end)

	hook.Add("NetworkCharacterLoaded", "nwRadioItem", function(client)
		timer.Simple(0.5, function()
			R.Refresh(client)
		end)
	end)

	hook.Add("NetworkVoiceStarted", "nwRadioItem", function(client)
		if (!R.IsTransmitting(client)) then
			return
		end

		local listeners = {}

		for _, other in ipairs(player.GetAll()) do
			if (other != client and R.SameFreq(client, other) and !other.nwRadioMute) then
				listeners[#listeners + 1] = other
			end
		end

		listeners[#listeners + 1] = client

		for _, listener in ipairs(listeners) do
			net.Start("nwVoiceRadio")
				net.WriteString(NETWORK.voicefx and NETWORK.voicefx.PickRadioSound(listener) or
					NETWORK.chat.radioOnRadio[math.random(#NETWORK.chat.radioOnRadio)])
			net.Send(listener)
		end
	end)

	function R.CanHearVoice(listener, speaker)
		return (!speaker:IsCombine() or speaker:GetInfoNum("network_builtin_radio_tx", 1) == 1) and
			(!listener:IsCombine() or listener:GetInfoNum("network_builtin_radio_rx", 1) == 1) and
			R.IsTransmitting(speaker) and R.SameFreq(speaker, listener) and
			!listener.nwRadioMute
	end

	return
end

net.Receive("nwRadioMenu", function()
	R.OpenMenu(net.ReadString(), net.ReadBool())
end)

function R.OpenMenu(freq, bTx)
	if (IsValid(NETWORK.gui.radioMenu)) then
		NETWORK.gui.radioMenu:Remove()
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = vgui.Create("EditablePanel")

	NETWORK.gui.radioMenu = panel

	panel:SetSize(Sc(360), Sc(230))
	panel:Center()
	panel:MakePopup()
	panel.bTx = bTx
	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			this:Remove()
		end
	end
	panel.Paint = function(this, width, height)
		NETWORK.gui.DrawBlackGlass(this, 0, 0, width, height, 1, Sc(14))

		draw.SimpleText(L("radioMenuTitle"), "nwInvTitle", Sc(20), Sc(28), theme.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("radioMenuFreq"), "nwHudSmall", Sc(20), Sc(62), theme.textDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local material = NETWORK.util.GetMaterial("framework/chat/radio.png", "smooth")

		if (material and !material:IsError()) then
			surface.SetMaterial(material)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(width - Sc(46), Sc(12), Sc(30), Sc(30))
		end
	end

	local entry = panel:Add("DTextEntry")

	entry:SetPos(Sc(20), Sc(76))
	entry:SetSize(Sc(320), Sc(36))
	entry:SetFont("nwField")
	entry:SetValue(freq or "")
	entry:SetPlaceholderText("145.5")
	entry:SetNumeric(false)
	entry:SetPaintBackground(false)
	entry.Paint = function(this, width, height)
		draw.RoundedBox(Sc(8), 0, 0, width, height, Color(0, 0, 0, 160))
		NETWORK.util.DrawRoundedBorder(0, 0, width, height, Sc(8), 1,
			ColorAlpha(this:HasFocus() and R.color or color_white, this:HasFocus() and 200 or 30))
		this:DrawTextEntryText(theme.text, R.color, theme.text)

		if (this:GetValue() == "") then
			draw.SimpleText("100.0 — 199.9", "nwField", Sc(8), height * 0.5,
				ColorAlpha(theme.textFaint, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	entry:RequestFocus()

	local toggle = panel:Add("DButton")

	toggle:SetText("")
	toggle:SetPos(Sc(20), Sc(124))
	toggle:SetSize(Sc(320), Sc(34))
	toggle.DoClick = function()
		panel.bTx = !panel.bTx
		surface.PlaySound("buttons/lightswitch2.wav")
	end
	toggle.Paint = function(this, width, height)
		local color = panel.bTx and R.color or theme.textFaint

		draw.RoundedBox(Sc(8), 0, 0, width, height,
			Color(0, 0, 0, this:IsHovered() and 170 or 130))
		draw.RoundedBox(Sc(6), Sc(8), math.Round(height * 0.5) - Sc(7), Sc(26), Sc(14),
			ColorAlpha(color, 160))
		draw.RoundedBox(Sc(6), panel.bTx and Sc(21) or Sc(9), math.Round(height * 0.5) - Sc(6),
			Sc(12), Sc(12), color_white)
		draw.SimpleText(L(panel.bTx and "radioMenuTxOn" or "radioMenuTxOff"), "nwField",
			Sc(44), height * 0.5, panel.bTx and theme.text or theme.textDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local function Save()
		local value = string.Trim(entry:GetValue())

		if (value != "" and !R.Normalise(value)) then
			NETWORK.gui.Notify(L("radioFreqBad"), theme.warning)

			return
		end

		net.Start("nwRadioSet")
			net.WriteString(value)
			net.WriteBool(panel.bTx == true)
		net.SendToServer()

		panel:Remove()
	end

	entry.OnEnter = Save

	local save = panel:Add("DButton")

	save:SetText("")
	save:SetPos(Sc(20), Sc(172))
	save:SetSize(Sc(320), Sc(38))
	save.DoClick = Save
	save.Paint = function(this, width, height)
		draw.RoundedBox(Sc(8), 0, 0, width, height,
			ColorAlpha(R.color, this:IsHovered() and 90 or 55))
		draw.SimpleText(L("radioMenuSave"), "nwField", width * 0.5, height * 0.5, theme.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end
