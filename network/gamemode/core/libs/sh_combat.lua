NETWORK.combat = NETWORK.combat or {}

NETWORK.combat.duration = 8

local PLAYER = FindMetaTable("Player")

function PLAYER:GetCombatEnd()
	return self:GetNWFloat("nwCombat", 0)
end

function PLAYER:IsCombat()
	return self:GetCombatEnd() > CurTime()
end

function PLAYER:GetCombatLeft()
	return math.max(self:GetCombatEnd() - CurTime(), 0)
end

if (SERVER) then
	function NETWORK.combat.Mark(client)
		if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
			return
		end

		local bWas = client:IsCombat()

		client:SetNWFloat("nwCombat", CurTime() + NETWORK.combat.duration)

		if (!bWas) then
			hook.Run("NetworkCombatStarted", client)
		end
	end

	function NETWORK.combat.Clear(client)
		client:SetNWFloat("nwCombat", 0)
	end

	hook.Add("PlayerHurt", "nwCombat", function(client, attacker)
		NETWORK.combat.Mark(client)

		if (IsValid(attacker) and attacker:IsPlayer() and attacker != client) then
			NETWORK.combat.Mark(attacker)
		end
	end)

	hook.Add("EntityTakeDamage", "nwCombat", function(target, info)
		local attacker = info:GetAttacker()

		if (IsValid(attacker) and attacker:IsPlayer() and target != attacker) then
			NETWORK.combat.Mark(attacker)
		end
	end)

	hook.Add("PlayerSpawn", "nwCombat", function(client)
		NETWORK.combat.Clear(client)
	end)

	hook.Add("NetworkCharacterLoaded", "nwCombat", function(client)
		NETWORK.combat.Clear(client)
	end)
end

if (CLIENT) then

	hook.Add("NetworkDrawHUD", "nwCombat", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:HasCharacter()) then
			NETWORK.combat.show = 0
			NETWORK.combat.overTime = nil

			return
		end

		local bCombat = client:IsCombat()

		if (NETWORK.combat.bWas and !bCombat) then
			NETWORK.combat.overTime = CurTime()
		end

		NETWORK.combat.bWas = bCombat

		local over = NETWORK.combat.overTime and
			math.Clamp(1 - (CurTime() - NETWORK.combat.overTime) / 1.5, 0, 1) or 0

		if (over <= 0) then
			NETWORK.combat.overTime = nil
		end

		NETWORK.combat.show = math.Approach(NETWORK.combat.show or 0,
			bCombat and 1 or 0, FrameTime() * 4)

		local show = math.max(NETWORK.util.EaseInOut(NETWORK.combat.show), over)

		if (show < 0.01) then
			return
		end

		local Sc = NETWORK.util.Scale
		local util = NETWORK.util
		local theme = NETWORK.theme
		local left = client:GetCombatLeft()
		local progress = math.Clamp(left / NETWORK.combat.duration, 0, 1)

		local speed = 3 + (1 - progress) * 5
		local pulse = bCombat and
			(0.72 + math.abs(math.sin(RealTime() * speed)) * 0.28) or 1

		local width = Sc(90)
		local height = math.max(Sc(3), 2)
		local x = math.Round((ScrW() - width) * 0.5)
		local y = math.Round(ScrH() * 0.5) + Sc(34)

		local fraction = bCombat and progress or 1
		local color = bCombat and theme.danger or theme.positive

		surface.SetDrawColor(0, 0, 0, 170 * show)
		surface.DrawRect(x, y, width, height)

		local fill = math.max(math.Round(width * fraction), 2)

		surface.SetDrawColor(color.r, color.g, color.b, 250 * show * pulse)
		surface.DrawRect(x + math.Round((width - fill) * 0.5), y, fill, height)

		util.DrawGlow(x - Sc(20), y - Sc(10), width + Sc(40), Sc(26),
			ColorAlpha(color, 60 * show * pulse))
	end)
end
