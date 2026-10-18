-- The cleanup of the city: every nw_cleanup_interval seconds (1800 - half an hour) the things lying in the
-- world (nw_item) and the bodies (the dead players and NPCs; not the body of one who is only unconscious)
-- are taken away. A minute before and ten seconds before - a warning in the chat for everyone, then how
-- much was taken. /cleanup - admins, now (with the same ten seconds). nw_cleanup_interval 0 - never.

NW.cleanup = NW.cleanup or {}

local CL = NW.cleanup

if (SERVER) then
	util.AddNetworkString("nwCleanup")

	local every = CreateConVar("nw_cleanup_interval", "1800", FCVAR_ARCHIVE,
		"Как часто убирать предметы и трупы (секунды, 0 — никогда)")

	local function Tell(text)
		net.Start("nwCleanup")
			net.WriteString(text)
		net.Broadcast()
	end

	-- a body still in use: someone unconscious lies in it
	local function InUse(ragdoll)
		for _, client in ipairs(player.GetAll()) do
			if (client:Alive() and client:GetNW2Entity("nwBody") == ragdoll) then
				return true
			end
		end

		return false
	end

	function CL.Run()
		local items, bodies = 0, 0

		for _, item in ipairs(ents.FindByClass("nw_item")) do
			if (IsValid(item) and !item:IsPlayerHolding()) then
				item:Remove()
				items = items + 1
			end
		end

		for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do
			if (IsValid(ragdoll) and (ragdoll:GetNW2Bool("nwCorpse", false) or ragdoll.nwStore) and !InUse(ragdoll)) then
				ragdoll:Remove()
				bodies = bodies + 1
			end
		end

		Tell("Очистка выполнена: предметов " .. items .. ", тел " .. bodies .. ".")
		MsgN(string.format("[CLEANUP] предметов %d, тел %d", items, bodies))
	end

	-- the warnings, then the cleanup
	local function Schedule(delay)
		timer.Remove("nwCleanupWarn")
		timer.Remove("nwCleanupWarn10")
		timer.Remove("nwCleanupRun")

		if (delay > 60) then
			timer.Create("nwCleanupWarn", delay - 60, 1, function()
				Tell("Через минуту будут убраны предметы на земле и трупы.")
			end)
		end

		timer.Create("nwCleanupWarn10", math.max(delay - 10, 0), 1, function()
			Tell("Через 10 секунд — очистка предметов и трупов.")
		end)

		timer.Create("nwCleanupRun", delay, 1, function()
			CL.Run()

			if (every:GetFloat() > 0) then
				Schedule(every:GetFloat())
			end
		end)
	end

	hook.Add("InitPostEntity", "nwCleanup", function()
		if (every:GetFloat() > 0) then
			Schedule(every:GetFloat())
		end
	end)

	cvars.AddChangeCallback("nw_cleanup_interval", function(_, _, value)
		value = tonumber(value) or 0

		if (value > 0) then
			Schedule(value)
		else
			timer.Remove("nwCleanupWarn")
			timer.Remove("nwCleanupWarn10")
			timer.Remove("nwCleanupRun")
		end
	end, "nwCleanup")

	NW.AddChatCommand("cleanup", {admin = true, run = function()
		Schedule(10)
	end})

	return
end

local ORANGE = Color(240, 170, 70)

net.Receive("nwCleanup", function()
	NW.chat.AddStyled("nwChat", ORANGE, "[ОЧИСТКА] " .. net.ReadString())
	surface.PlaySound("buttons/blip1.wav")
end)
