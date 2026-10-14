-- Noclip: admins only (the sandbox lets everyone). While flying the admin is an observer: hidden from
-- everyone and not solid (nw_noclip_hide 0 - stay seen), and sees every player, item, container,
-- NPC and zone through the walls (cl_noclip.lua). Shared: the client predicts the same answer.

local hide = CreateConVar("nw_noclip_hide", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Скрывать админа в ноуклипе")

local function Observe(client, bOn)
	client:SetNW2Bool("nwObserver", bOn)
	client:SetNoDraw(bOn and hide:GetBool())
	client:DrawShadow(!bOn)
	client:SetNotSolid(bOn)

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon)) then
		weapon:SetNoDraw(bOn and hide:GetBool())
	end
end

function GM:PlayerNoClip(client, bDesired)
	if (!bDesired) then
		if (SERVER and client:GetNW2Bool("nwObserver", false)) then
			Observe(client, false)
		end

		return true
	end

	if (!client:IsAdmin() or !client:Alive() or client:GetNW2Bool("nwKnocked", false)) then
		return false
	end

	if (SERVER) then
		Observe(client, true)
	end

	return true
end

if (SERVER) then
	hook.Add("PlayerSpawn", "nwObserver", function(client)
		if (client:GetNW2Bool("nwObserver", false)) then
			Observe(client, false)
		end
	end)

	hook.Add("PlayerSwitchWeapon", "nwObserver", function(client, _, new)
		if (client:GetNW2Bool("nwObserver", false) and IsValid(new)) then
			timer.Simple(0, function()
				if (IsValid(new) and IsValid(client) and client:GetNW2Bool("nwObserver", false)) then
					new:SetNoDraw(hide:GetBool())
				end
			end)
		end
	end)
end
