-- The radio (framework/items/tools/radio.lua): a set that carries the voice over a channel.
--   channels     Выкл; Отряд (the squad, sh_squads.lua); Сторона (Civil Protection, or the Combine);
--                Общая (the whole Alliance). The channels of the Alliance need the Alliance.
--   settings     the item in the inventory → RMB → Настроить, or the key "Рация: настроить" (B):
--                a small window with the channels
--   talking      hold the key "Рация: говорить" (H): the voice goes to everyone on the channel who has
--                a radio, wherever they are, flat (not from a place in the world); around you it is
--                still heard as usual. Clicks of the set when the key goes down and up
--                (sound/network2/radio2). Over the head: the microphone and the radio mark; in the
--                corner: "Радиопередача".
-- On the player: NW2 nwRadioChannel ("" - off), nwRadioTalk, nwHasRadio.

NW.radio = NW.radio or {}

local R = NW.radio

R.channels = {
	{id = "", name = "Выключена", hint = "Рация молчит"},
	{id = "squad", name = "Отряд", hint = "Только ваш отряд", alliance = true},
	{id = "side", name = "Сторона", hint = "ГО — для ГО, комбайны — для комбайнов", alliance = true},
	{id = "all", name = "Общая", hint = "Весь Альянс", alliance = true}
}

R.byID = {}

for _, channel in ipairs(R.channels) do
	R.byID[channel.id] = channel
end

function R.Channel(client)
	return client:GetNW2String("nwRadioChannel", "")
end

function R.Talking(client)
	return client:GetNW2Bool("nwRadioTalk", false)
end

-- does the listener hear the talker on the radio?
function R.Hears(listener, talker)
	if (listener == talker or !R.Talking(talker) or !listener:GetNW2Bool("nwHasRadio", false)) then
		return false
	end

	local channel = R.Channel(talker)

	if (channel == "" or R.Channel(listener) != channel) then
		return false
	end

	if (channel == "squad") then
		local squad = NW.squads.Of(talker)

		return squad != nil and NW.squads.Of(listener) == squad
	elseif (channel == "side") then
		return NW.zones.IsAlliance(listener) and NW.squads.Side(listener) == NW.squads.Side(talker)
	elseif (channel == "all") then
		return NW.zones.IsAlliance(listener)
	end

	return false
end

if (SERVER) then
	util.AddNetworkString("nwRadioSet")
	util.AddNetworkString("nwRadioTalk")
	util.AddNetworkString("nwRadioOpen")
	util.AddNetworkString("nwRadioClick")

	-- any radio: the framework one or one made in /itemedit (item.radio)
	local function HasRadio(client)
		local inventory = NW.inventory.Get(client)

		for _, cell in pairs(inventory.grid) do
			local item = NW.items.Get(cell.id)

			if (item and item.radio) then
				return true
			end
		end

		for _, cell in pairs(inventory.equip) do
			local item = NW.items.Get(cell.id)

			if (item and item.radio) then
				return true
			end
		end

		return false
	end

	local function Update(client)
		local has = HasRadio(client)

		client:SetNW2Bool("nwHasRadio", has)

		if (!has) then
			client:SetNW2String("nwRadioChannel", "")
			client:SetNW2Bool("nwRadioTalk", false)
		end
	end

	hook.Add("NWInventoryChanged", "nwRadio", Update)
	hook.Add("NWCharacterLoaded", "nwRadio", function(client)
		timer.Simple(0.5, function()
			if (IsValid(client)) then
				client:SetNW2String("nwRadioChannel", "")
				Update(client)
			end
		end)
	end)

	function R.Open(client)
		net.Start("nwRadioOpen")
		net.Send(client)
	end

	-- the click of the set for everyone on the channel (and the one talking)
	local function Click(talker, bOn)
		local targets = {talker}

		for _, other in ipairs(player.GetAll()) do
			if (other != talker and other:GetNW2Bool("nwHasRadio", false) and R.Channel(other) == R.Channel(talker)) then
				targets[#targets + 1] = other
			end
		end

		net.Start("nwRadioClick")
			net.WriteBool(bOn)
		net.Send(targets)
	end

	net.Receive("nwRadioSet", function(_, client)
		local id = net.ReadString()
		local channel = R.byID[id]

		if (!channel or !client:GetNW2Bool("nwHasRadio", false)) then
			return
		end

		if (channel.alliance and !NW.zones.IsAlliance(client)) then
			return NW.Notify(client, "Этот канал зашифрован: только для Альянса")
		end

		client:SetNW2String("nwRadioChannel", id)

		if (id == "") then
			client:SetNW2Bool("nwRadioTalk", false)
		end
	end)

	net.Receive("nwRadioTalk", function(_, client)
		local bOn = net.ReadBool()

		if (bOn and (R.Channel(client) == "" or !client:GetNW2Bool("nwHasRadio", false) or
			(NW.Incapable and NW.Incapable(client)))) then
			bOn = false
		end

		if (R.Talking(client) == bOn) then
			return
		end

		client:SetNW2Bool("nwRadioTalk", bOn)
		Click(client, bOn)
	end)

	hook.Add("PlayerDeath", "nwRadio", function(client)
		client:SetNW2Bool("nwRadioTalk", false)
	end)

	return
end

-- ------------------------------------------------------------------ client --
local U = NW.ui

net.Receive("nwRadioClick", function()
	local bOn = net.ReadBool()

	surface.PlaySound(bOn and ("network2/radio2/on" .. math.random(1, 2) .. ".wav") or
		("network2/radio2/off" .. math.random(1, 3) .. ".wav"))
end)

-- the key held: the voice goes on the radio (and the microphone opens)
local talking = false

local function Talk(bOn)
	if (talking == bOn) then
		return
	end

	talking = bOn

	net.Start("nwRadioTalk")
		net.WriteBool(bOn)
	net.SendToServer()

	RunConsoleCommand(bOn and "+voicerecord" or "-voicerecord")
end

hook.Add("NWKey", "nwRadio", function(id)
	local client = LocalPlayer()

	if (id == "radio") then
		R.OpenMenu()
	elseif (id == "radio_talk") then
		if (!client:GetNW2Bool("nwHasRadio", false)) then
			return NW.notify.Add("У вас нет рации")
		elseif (R.Channel(client) == "") then
			return NW.notify.Add("Рация выключена — настройте канал")
		end

		Talk(true)
	end
end)

hook.Add("NWKeyUp", "nwRadio", function(id)
	if (id == "radio_talk") then
		Talk(false)
	end
end)

-- dying, falling, losing the radio: the key is let go
hook.Add("Think", "nwRadioTalk", function()
	local client = LocalPlayer()

	if (talking and ((NW.Incapable and NW.Incapable(client)) or !client:GetNW2Bool("nwHasRadio", false))) then
		Talk(false)
	end
end)

-- the window: the channels as plates
surface.CreateFont("nwRadioTitle", {font = "Montserrat SemiBold", size = math.max(14, math.Round(ScrH() * 0.024)),
	weight = 600, extended = true, antialias = true})
surface.CreateFont("nwRadioText", {font = "Montserrat Medium", size = math.max(11, math.Round(ScrH() * 0.016)),
	weight = 500, extended = true, antialias = true})

local ACCENT = Color(96, 200, 255)

function R.OpenMenu()
	local client = LocalPlayer()

	if (IsValid(R.frame)) then
		R.frame:Remove()

		return
	end

	if (!client:GetNW2Bool("nwHasRadio", false)) then
		return NW.notify.Add("У вас нет рации")
	end

	local sw, sh = ScrW(), ScrH()
	local w, rowH = math.Round(sh * 0.4), math.Round(sh * 0.062)
	local pad = math.Round(sh * 0.022)
	local h = math.Round(pad * 2 + sh * 0.06 + #R.channels * (rowH + 8) + sh * 0.03)
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(w, h)
	frame:SetPos(sw - w - sh * 0.04, (sh - h) / 2)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.born = RealTime()
	frame.Paint = function(self, pw, ph)
		local a = math.Clamp((RealTime() - self.born) / 0.18, 0, 1)

		draw.RoundedBox(10, 0, 0, pw, ph, Color(12, 15, 18, 236 * a))
		draw.RoundedBox(2, 0, 0, pw, 3, ColorAlpha(ACCENT, 255 * a))
		U.DrawIcon("radio", pad, pad, sh * 0.032, ColorAlpha(ACCENT, 255 * a))
		draw.SimpleText("Рация", "nwRadioTitle", pad + sh * 0.042, pad + sh * 0.016, ColorAlpha(U.color.text, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local talkKey = input.GetKeyName(NW.keys.Get("radio_talk") or 0) or "?"

		draw.SimpleText("Говорить: зажать " .. string.upper(talkKey), "nwRadioText", pw - pad, pad + sh * 0.016,
			ColorAlpha(U.color.dim, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	R.frame = frame

	local alliance = NW.zones.IsAlliance(client)

	for index, channel in ipairs(R.channels) do
		local button = frame:Add("DButton")
		local locked = channel.alliance and !alliance

		button:SetPos(pad, pad + sh * 0.06 + (index - 1) * (rowH + 8))
		button:SetSize(w - pad * 2, rowH)
		button:SetText("")
		button:SetEnabled(!locked)
		button.Paint = function(self, bw, bh)
			local current = R.Channel(client) == channel.id
			local hover = self:IsHovered() and !locked

			draw.RoundedBox(8, 0, 0, bw, bh, current and ColorAlpha(ACCENT, 46) or Color(255, 255, 255, hover and 16 or 7))

			if (current) then
				draw.RoundedBox(2, 0, 0, 3, bh, ACCENT)
			end

			draw.SimpleText(channel.name, "nwRadioTitle", bh * 0.3, bh * 0.36, locked and Color(110, 112, 116) or
				U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(locked and "Зашифровано: только Альянс" or channel.hint, "nwRadioText", bh * 0.3, bh * 0.72,
				U.color.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			net.Start("nwRadioSet")
				net.WriteString(channel.id)
			net.SendToServer()
			surface.PlaySound("network2/radio2/on" .. math.random(1, 2) .. ".wav")
		end
		button.OnCursorEntered = function()
			if (!locked) then
				surface.PlaySound("network2/ui/hover.wav")
			end
		end
	end

	-- a click outside or Esc closes it
	frame.Think = function(self)
		if (input.IsMouseDown(MOUSE_LEFT) and !self:IsChildHovered() and !self:IsHovered()) then
			self:Remove()
		end
	end
end

net.Receive("nwRadioOpen", function()
	if (!IsValid(R.frame)) then
		R.OpenMenu()
	end
end)

hook.Add("NWEscape", "nwRadio", function()
	if (IsValid(R.frame)) then
		R.frame:Remove()

		return true
	end
end)

-- "Радиопередача" over the microphone of your own voice
surface.CreateFont("nwRadioOn", {font = "JetBrains Mono ExtraBold", size = math.max(11, math.Round(ScrH() * 0.016)),
	weight = 800, extended = true, antialias = true})

hook.Add("HUDPaint", "nwRadioSelf", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !R.Talking(client)) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local size = sh * 0.03
	local blink = 0.6 + 0.4 * math.abs(math.sin(RealTime() * 4))
	local x, y = sw - sh * 0.04, sh * 0.82
	local channel = R.byID[R.Channel(client)]

	U.DrawIcon("broadcast", x - size, y - size / 2, size, ColorAlpha(ACCENT, 255 * blink))
	draw.SimpleTextOutlined("РАДИОПЕРЕДАЧА · " .. string.upper(channel and channel.name or ""), "nwRadioOn",
		x - size - sh * 0.01, y, ACCENT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 170))
end)
