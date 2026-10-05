NETWORK.sound.enabled = CreateClientConVar("network_sounds", "1", true, false,
	"Звуки интерфейса")

NETWORK.sound.musicVolume = CreateClientConVar("network_music", "0.25", true, false,
	"Громкость музыки")

NETWORK.sound.musicEnabled = CreateClientConVar("network_music_enabled", "1",
	true, false, "Играть музыку")

NETWORK.sound.musicMenu = CreateClientConVar("network_music_menu", "1",
	true, false, "Играть музыку в главном меню")

local lastHover = 0

function NETWORK.sound.Play(id, pitch, volume)
	if (!NETWORK.sound.enabled:GetBool()) then
		return
	end

	local path = NETWORK.sound.paths[id]

	if (!path) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		surface.PlaySound(path)

		return
	end

	local sample = CreateSound(client, path)

	if (!sample) then
		return
	end

	sample:PlayEx(volume or 0.5, pitch or 100)
end

function NETWORK.sound.Click(bAlt)
	NETWORK.sound.Play(bAlt and "clickAlt" or "click", 100, 0.45)
end

function NETWORK.sound.Hover()
	if (lastHover > RealTime()) then
		return
	end

	lastHover = RealTime() + 0.05

	NETWORK.sound.Play("hover" .. math.random(1, 3), 100, 0.3)
end

local lastMenuHover = 0

function NETWORK.sound.Interface(path)
	if (!NETWORK.sound.enabled:GetBool() or !path) then
		return
	end

	surface.PlaySound(path)
end

local function Pick(list)
	if (!list or #list == 0) then
		return
	end

	return list[math.random(#list)]
end

function NETWORK.sound.MenuHover()

	if (lastMenuHover > RealTime()) then
		return
	end

	lastMenuHover = RealTime() + 0.06

	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.hover))
end

function NETWORK.sound.MenuPress()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.press))
end

function NETWORK.sound.MenuLoad()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.load))
end

function NETWORK.sound.CreateHover()
	if (lastMenuHover > RealTime()) then
		return
	end

	lastMenuHover = RealTime() + 0.06

	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.createSelect))
end

function NETWORK.sound.CreatePress()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.createPress))
end

function NETWORK.sound.TabHover()
	if (lastMenuHover > RealTime()) then
		return
	end

	lastMenuHover = RealTime() + 0.06

	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.tabSelect))
end

function NETWORK.sound.TabPress()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.tabPress))
end

function NETWORK.sound.Hint()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.hint))
end

function NETWORK.sound.ChatOpen()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.chatOpen))
end

function NETWORK.sound.ChatSend()
	if (!NETWORK.sound.enabled:GetBool()) then
		return
	end

	surface.PlaySound("buttons/button17.wav")
end

local lastType = 0

function NETWORK.sound.Type(fraction)
	if (!NETWORK.sound.enabled:GetBool()) then
		return
	end

	if (lastType > RealTime()) then
		return
	end

	lastType = RealTime() + 0.05

	fraction = math.Clamp(fraction or 0, 0, 1)

	NETWORK.sound.Interface("framework/buttons/textline_" ..
		math.random(1, 3) .. ".wav")
end

function NETWORK.sound.ZoneType(fraction)
	NETWORK.sound.Type(fraction)
end

function NETWORK.sound.InvMove()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.invMove))
end

function NETWORK.sound.InvSelect()

	if (lastMenuHover > RealTime()) then
		return
	end

	lastMenuHover = RealTime() + 0.05

	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.invSelect))
end

function NETWORK.sound.InvStack()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.invStack))
end

function NETWORK.sound.MenuStart()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.start))
end

function NETWORK.sound.Notify()
	NETWORK.sound.Interface(Pick(NETWORK.sound.menu.hint))
end

function NETWORK.sound.Soft()
	if (!NETWORK.sound.enabled:GetBool()) then
		return
	end

	surface.PlaySound("buttons/blip1.wav")
end

function NETWORK.sound.Chat(id)
	if (id == "ooc" or id == "looc") then
		NETWORK.sound.Play("hover3", 96, 0.35)

		return
	end

	if (id == "pm") then
		NETWORK.sound.Play("clickAlt", 108, 0.6)

		return
	end

	NETWORK.sound.Play("hover1", 100, 0.32)
end

NETWORK.music = NETWORK.music or {}
NETWORK.music.current = NETWORK.music.current or nil
NETWORK.music.context = NETWORK.music.context or nil
NETWORK.music.channels = NETWORK.music.channels or {}

local function Track(station)
	NETWORK.music.channels[station] = true
end

local function StopAll(except)
	for station in pairs(NETWORK.music.channels) do
		if (station != except and IsValid(station)) then
			station:Stop()
		end

		if (station != except) then
			NETWORK.music.channels[station] = nil
		end
	end
end

function NETWORK.music.Stop(bImmediate)
	local station = NETWORK.music.current

	NETWORK.music.current = nil

	if (!IsValid(station)) then
		return
	end

	if (bImmediate) then
		station:Stop()

		NETWORK.music.channels[station] = nil

		return
	end

	if (IsValid(NETWORK.music.fading)) then
		NETWORK.music.fading:Stop()

		NETWORK.music.channels[NETWORK.music.fading] = nil
	end

	NETWORK.music.fading = station
end

function NETWORK.music.Play(context)
	if (NETWORK.music.loading) then
		return
	end

	local list = NETWORK.sound.music[context]

	if (!list or #list == 0) then
		return
	end

	NETWORK.music.context = context
	NETWORK.music.loading = context

	NETWORK.music.Stop()

	local path = list[math.random(#list)]

	sound.PlayFile("sound/" .. path, "noblock", function(station, errorID, name)
		NETWORK.music.loading = nil

		if (!IsValid(station)) then
			NETWORK.util.PrintWarning("Музыка не найдена: " .. path)

			return
		end

		Track(station)

		if (NETWORK.music.context != context) then
			station:Stop()

			NETWORK.music.channels[station] = nil

			return
		end

		StopAll(station)

		if (IsValid(NETWORK.music.fading)) then
			NETWORK.music.fading = nil
		end

		station:SetVolume(math.Clamp(NETWORK.sound.musicVolume:GetFloat(), 0, 1))
		station:Play()

		NETWORK.music.current = station
	end)
end

hook.Add("Think", "nwMusic", function()

	local volume = NETWORK.sound.musicEnabled:GetBool() and
		math.Clamp(NETWORK.sound.musicVolume:GetFloat(), 0, 1) or 0
	local station = NETWORK.music.current

	if (IsValid(station)) then
		station:SetVolume(volume)

		if (station:GetState() == GMOD_CHANNEL_STOPPED) then
			NETWORK.music.channels[station] = nil
			NETWORK.music.current = nil
			NETWORK.music.context = nil
		end
	end

	local fading = NETWORK.music.fading

	if (IsValid(fading)) then
		local current = fading:GetVolume() - FrameTime() * 0.7

		if (current <= 0.01) then
			fading:Stop()

			NETWORK.music.channels[fading] = nil
			NETWORK.music.fading = nil
		else
			fading:SetVolume(current)
		end
	elseif (fading) then
		NETWORK.music.fading = nil
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	if (volume <= 0.001) then
		StopAll()

		NETWORK.music.current = nil
		NETWORK.music.context = nil

		return
	end

	if (NETWORK.music.loading) then
		return
	end

	local context = (IsValid(NETWORK.gui.menu) or !client:HasCharacter()) and "menu" or "game"

	if (context == "menu" and !NETWORK.sound.musicMenu:GetBool()) then
		StopAll()

		NETWORK.music.current = nil
		NETWORK.music.context = nil

		return
	end

	if (NETWORK.music.context == context and IsValid(NETWORK.music.current)) then
		return
	end

	if ((NETWORK.music.nextTry or 0) > RealTime()) then
		return
	end

	NETWORK.music.nextTry = RealTime() + 1.5

	NETWORK.music.Play(context)
end)

concommand.Add("network_music_next", function()
	NETWORK.music.context = nil
	NETWORK.music.nextTry = 0

	NETWORK.music.Stop(true)
end)

concommand.Add("network_music_stop", function()
	StopAll()

	NETWORK.music.current = nil
	NETWORK.music.context = nil
	NETWORK.music.loading = nil

	NETWORK.util.Print("Музыка остановлена.")
end)
