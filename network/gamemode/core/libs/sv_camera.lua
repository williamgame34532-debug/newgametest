NETWORK.camera = NETWORK.camera or {}

if (SERVER) then
	function NETWORK.camera.Break(camera, attacker)
		if (!IsValid(camera) or camera:GetNWBool("nwBroken", false)) then
			return
		end

		camera:SetNWBool("nwBroken", true)

		camera:Fire("Disable")
		camera:Fire("SetIdle")
		camera:EmitSound("npc/scanner/scanner_electric1.wav", 70, 90)

		local effect = EffectData()

		effect:SetOrigin(camera:WorldSpaceCenter())
		effect:SetMagnitude(2)
		effect:SetScale(1)

		util.Effect("ElectricSpark", effect)

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("lock", string.format("Камера выведена из строя (%s)",
				IsValid(attacker) and NETWORK.log.Name(attacker) or "неизвестно"),
				camera:GetPos())
		end

		if (NETWORK.log and NETWORK.log.Dispatch) then
			local zone = NETWORK.zone and NETWORK.zone.AtEntity and
				NETWORK.zone.AtEntity(camera)

			NETWORK.log.Dispatch("КАМЕРА ПОТЕРЯНА :: " ..
				(zone and (zone.name or zone.id) or "СЕКТОР"),
				Color(232, 92, 92))
		end
	end

	function NETWORK.camera.Repair(camera)
		if (!IsValid(camera)) then
			return
		end

		camera:SetNWBool("nwBroken", false)
		camera:SetHealth(camera:GetMaxHealth() > 0 and camera:GetMaxHealth() or 50)
		camera:Fire("Enable")
		camera:EmitSound("npc/scanner/combat_scan4.wav", 65, 110)
	end

	hook.Add("EntityTakeDamage", "nwCameraBreak", function(target, damage)
		if (!IsValid(target) or target:GetClass() != "npc_combine_camera") then
			return
		end

		if (target:GetNWBool("nwBroken", false)) then

			damage:SetDamage(0)

			return true
		end

		if (target:Health() - damage:GetDamage() > 0) then
			return
		end

		damage:SetDamage(0)

		target:SetHealth(1)

		NETWORK.camera.Break(target, damage:GetAttacker())

		return true
	end)

	hook.Add("NetworkCameraList", "nwCameraBreak", function(camera)
		if (IsValid(camera) and camera:GetNWBool("nwBroken", false)) then
			return false
		end
	end)
end
