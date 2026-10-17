-- Voice lines: a phrase typed whole in the chat (IC, /w, /y and the radios; not OOC, LOOC, /pm, /me,
-- /it) is said aloud. The lists (sh_voices_data.lua):
--   citizen_male / citizen_female   everyone outside the Alliance (citizens, the CWU...), by gender
--   cp                              Civil Protection
--   ota                             the Overwatch soldiers
-- The key is the English one ("be careful", "10-4") or the Russian text ("теперь осторожнее"), any
-- case, the punctuation does not matter. The text in the chat becomes the line's text.
--   /voices - the list of one's own lines (a search, a click puts the line into the chat).
-- Range: whisper quiet, speech normal, yell loud; on the radio the listeners hear it in the radio,
-- the ones around - from the speaker.

local V = NW.voices

-- the key of a typed text: lower case, ё as е, only letters, digits and the dash
local function Lower(code)
	if (code >= 0x410 and code <= 0x42F) then
		return code + 0x20
	elseif (code == 0x401 or code == 0x451) then
		return 0x435
	elseif (code >= 65 and code <= 90) then
		return code + 32
	end

	return code
end

function V.Key(text)
	local out = {}

	for _, code in utf8.codes(text or "") do
		code = Lower(code)

		if ((code >= 97 and code <= 122) or (code >= 0x430 and code <= 0x44F) or (code >= 48 and code <= 57) or
			code == 45) then
			out[#out + 1] = utf8.char(code)
		else
			out[#out + 1] = " "
		end
	end

	return string.Trim((string.gsub(table.concat(out), "%s+", " ")))
end

-- key -> line, for each list (the English key and the Russian text both)
V.index = {}

for name, list in pairs(V.lists) do
	local index = {}

	for _, line in ipairs(list) do
		local entry = {key = line[1], text = line[2], sound = line[3]}

		index[line[1]] = index[line[1]] or entry
		index[V.Key(line[2])] = index[V.Key(line[2])] or entry
	end

	V.index[name] = index
end

-- the list of a player: the faction, then the gender of the character
function V.ListOf(client)
	local faction = client:GetFaction()

	if (faction == "cp") then
		return "cp"
	elseif (faction == "combine") then
		return "ota"
	elseif (faction == "") then
		return
	end

	return client:GetNW2String("nwCharGender", "male") == "female" and "citizen_female" or "citizen_male"
end

function V.Match(client, text)
	local list = V.ListOf(client)

	return list and V.index[list][V.Key(text)]
end

V.kinds = {
	[NW.chatKinds.IC] = 75,
	[NW.chatKinds.WHISPER] = 55,
	[NW.chatKinds.YELL] = 90,
	[NW.chatKinds.RADIO] = 60,
	[NW.chatKinds.RADIO_ALL] = 60,
	[NW.chatKinds.SQUAD] = 60,
	[NW.chatKinds.REBEL] = 55
}

if (SERVER) then
	util.AddNetworkString("nwVoiceRadio")

	-- said: from the speaker; on the radio also in the radios of the ones far away
	function V.Play(client, entry, kind, listeners)
		local level = V.kinds[kind] or 75

		client:EmitSound(entry.sound, level, 100, kind == NW.chatKinds.WHISPER and 0.6 or 1)

		if (listeners) then
			local far = {}

			for _, target in ipairs(listeners) do
				if (target != client and target:GetPos():DistToSqr(client:GetPos()) > 600 * 600) then
					far[#far + 1] = target
				end
			end

			if (#far > 0) then
				net.Start("nwVoiceRadio")
					net.WriteString(entry.sound)
				net.Send(far)
			end
		end
	end

	NW.AddChatCommand("voices", {run = function(client)
		client:SendLua("NW.voices.Open()")
	end})

	return
end

net.Receive("nwVoiceRadio", function()
	local path = net.ReadString()

	-- the radio: a bit quieter, the click before it
	surface.PlaySound("npc/metropolice/vo/on" .. math.random(1, 2) .. ".wav")

	timer.Simple(0.12, function()
		LocalPlayer():EmitSound(path, 0, 100, 0.65)
	end)
end)

-- --------------------------------------------------------------- /voices --
local panel

function V.Open()
	if (IsValid(panel)) then
		panel:Remove()
	end

	local list = V.ListOf(LocalPlayer())

	if (!list) then
		return
	end

	local w, h = math.min(ScrW() * 0.5, 760), ScrH() * 0.72

	panel = vgui.Create("DFrame")
	panel:SetSize(w, h)
	panel:Center()
	panel:SetTitle("")
	panel:MakePopup()
	panel.Paint = function(self, pw, ph)
		draw.RoundedBox(6, 0, 0, pw, ph, Color(18, 20, 24, 245))
		draw.SimpleText("Голосовые фразы", "nwWidgetTitle", 16, 10, Color(236, 230, 220))
		draw.SimpleText(({citizen_male = "Гражданин", citizen_female = "Гражданка", cp = "Гражданская Оборона",
			ota = "Надзор"})[list] .. " · напишите фразу целиком в чат (речь, /w, /y, рация)", "nwWidget", 16, 40,
			Color(160, 165, 170))
	end

	local search = vgui.Create("DTextEntry", panel)
	search:SetPos(16, 66)
	search:SetSize(w - 32, 28)
	search:SetPlaceholderText("Поиск по тексту или ключу...")

	local scroll = vgui.Create("DScrollPanel", panel)
	scroll:SetPos(16, 102)
	scroll:SetSize(w - 32, h - 118)

	local function Fill(query)
		scroll:Clear()
		query = V.Key(query or "")

		for _, line in ipairs(V.lists[list]) do
			local key, text, path = line[1], line[2], line[3]

			if (query == "" or string.find(key, query, 1, true) or string.find(V.Key(text), query, 1, true)) then
				local row = scroll:Add("DButton")
				row:Dock(TOP)
				row:DockMargin(0, 0, 0, 3)
				row:SetTall(30)
				row:SetText("")
				row.Paint = function(self, rw, rh)
					draw.RoundedBox(4, 0, 0, rw, rh, self:IsHovered() and Color(52, 58, 66) or Color(30, 33, 38))
					draw.SimpleText(text, "nwWidget", 10, rh / 2, Color(232, 228, 220), TEXT_ALIGN_LEFT,
						TEXT_ALIGN_CENTER)
					draw.SimpleText(key, "nwWidget", rw - 34, rh / 2, Color(130, 136, 142), TEXT_ALIGN_RIGHT,
						TEXT_ALIGN_CENTER)
				end
				-- a click: into the chat; the right click: listen
				row.DoClick = function()
					panel:Remove()
					NW.chat.Open()

					if (IsValid(NW.chat.entry)) then
						NW.chat.entry:SetText(text)
						NW.chat.entry:SetCaretPos(#text)
					end
				end
				row.DoRightClick = function()
					surface.PlaySound(path)
				end

				local play = vgui.Create("DButton", row)
				play:Dock(RIGHT)
				play:SetWide(28)
				play:SetText("▶")
				play:SetTextColor(Color(200, 200, 200))
				play.Paint = nil
				play.DoClick = function()
					surface.PlaySound(path)
				end
			end
		end
	end

	search.OnChange = function(self)
		Fill(self:GetValue())
	end

	Fill("")
end

concommand.Add("nw_voices", V.Open)
