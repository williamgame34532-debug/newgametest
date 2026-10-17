-- Noclip: admins only (the sandbox lets everyone). While flying the admin is an observer: hidden from
-- everyone and not solid (nw_noclip_hide 0 - stay seen), and sees every player, item, container,
-- NPC and zone through the walls (cl_noclip.lua). Shared: the client predicts the same answer.

local hide = CreateConVar("nw_noclip_hide", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Скрывать админа в ноуклипе")

-- hidden: an observer nobody sees (the model, the weapon, what hangs on the model, the shadow, the
-- steps), nobody hurts and no NPC notices
function NW.Hidden(client)
	return IsValid(client) and client:GetNW2Bool("nwObserver", false) and hide:GetBool()
end

local function Observe(client, bOn)
	local hidden = bOn and hide:GetBool()

	client:SetNW2Bool("nwObserver", bOn)
	client:SetNoDraw(hidden)
	client:DrawShadow(!hidden)
	client:SetNotSolid(bOn)
	client:SetNoTarget(bOn)

	if (bOn and client:FlashlightIsOn()) then
		client:Flashlight(false)
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon)) then
		weapon:SetNoDraw(hidden)
	end

	-- clothes, gear and other models attached to the player
	for _, child in ipairs(client:GetChildren()) do
		if (IsValid(child) and !child:IsWeapon()) then
			if (hidden) then
				child.nwObserverDraw = child.nwObserverDraw == nil and !child:GetNoDraw() or child.nwObserverDraw
				child:SetNoDraw(true)
			elseif (child.nwObserverDraw != nil) then
				child:SetNoDraw(!child.nwObserverDraw)
				child.nwObserverDraw = nil
			end
		end
	end
end

-- no steps heard
hook.Add("PlayerFootstep", "nwObserver", function(client)
	if (NW.Hidden(client)) then
		return true
	end
end)

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
	-- no damage in noclip
	hook.Add("EntityTakeDamage", "nwObserver", function(target)
		if (target:IsPlayer() and target:GetNW2Bool("nwObserver", false)) then
			return true
		end
	end)

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

if (CLIENT) then
	-- the model is not drawn at all for the others (whatever else draws players: legs, effects)
	hook.Add("PrePlayerDraw", "nwObserver", function(client)
		if (client != LocalPlayer() and NW.Hidden(client)) then
			return true
		end
	end)
end
