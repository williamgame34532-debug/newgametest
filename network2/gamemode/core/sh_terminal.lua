-- The civic terminal (entities/entities/nw_terminal.lua; server sv_terminal.lua, windows cl_terminal.lua),
-- after the Helix ix_civic_terminal: a Combine station on a wall the citizen uses by looking at its
-- screen and pressing E on the buttons.
--   ПРОФИЛЬ      the citizen's file: name, CID, faction, bank account, a silhouette of the character
--   ОБЪЯВЛЕНИЯ   the city's announcements (/announce for admins and the Alliance), with a picture link
--   ВЫЗОВ Г.О    a call to Civil Protection: the reason goes to every member of the Alliance with a
--                mark on the terminal; the channel is then closed for a while
--   ЖИЛЬЁ        an apartment given by the city (the doors "Квартира · через терминал", sh_doors.lua):
--                a roulette picks one with free room; the list shows how full each is
--   СЕРВИСЫ      the weather, the bank (tokens in the account and on hand), renting a business
-- One net message both ways: nwTerminal <action> (strings and JSON).

NW.terminal = NW.terminal or {}

local T = NW.terminal

T.class = "nw_terminal"
T.reach = 110
T.callCooldown = 90

T.priorities = {
	normal = {name = "Обычное", color = Color(96, 186, 206)},
	important = {name = "Важное", color = Color(236, 196, 75)},
	critical = {name = "Срочное", color = Color(231, 78, 76)}
}

T.priorityOrder = {"normal", "important", "critical"}

-- upper case for Cyrillic and Latin (string.upper only knows ASCII)
function T.Upper(text)
	local out = {}

	for _, code in utf8.codes(text or "") do
		if (code >= 0x430 and code <= 0x44F) then
			code = code - 0x20
		elseif (code == 0x451) then
			code = 0x401
		elseif (code >= 97 and code <= 122) then
			code = code - 32
		end

		out[#out + 1] = utf8.char(code)
	end

	return table.concat(out)
end

-- close enough to the screen, alive, a character in the world
function T.IsNear(client, terminal)
	return IsValid(client) and IsValid(terminal) and terminal:GetClass() == T.class and client:Alive() and
		client:GetCharacterID() != 0 and !client:GetNW2Bool("nwKnocked", false) and
		client:EyePos():DistToSqr(terminal:GetPos()) <= T.reach * T.reach
end

-- who may post announcements
function T.CanAnnounce(client)
	return client:IsAdmin() or (NW.zones and NW.zones.IsAlliance(client))
end

-- the weather of the hour (the same for everyone, it changes slowly)
local SKIES = {"ЯСНО", "ПЕРЕМЕННАЯ ОБЛАЧНОСТЬ", "ПАСМУРНО", "ТУМАН", "МОРОСЬ", "ДОЖДЬ", "СИЛЬНЫЙ ВЕТЕР"}

function T.Weather(time)
	time = time or os.time()

	local hour = math.floor(time / 3600)
	local day = math.floor(time / 86400)
	local seed = (day * 7919 + math.floor(hour / 3) * 104729) % 2147483647
	local function R(n)
		seed = (seed * 48271) % 2147483647

		return seed % n
	end

	local local_hour = tonumber(os.date("%H", time)) or 12
	local base = 6 + R(9) - math.abs(local_hour - 14) * 0.6

	return {
		sky = SKIES[R(#SKIES) + 1],
		temperature = math.Round(base),
		wind = 1 + R(9),
		humidity = 55 + R(40),
		air = R(10) < 2 and "ПОВЫШЕННЫЙ ФОН" or "В НОРМЕ"
	}
end
