local R = {}
HLA.Radial = R

R.Poses = {
	{id = 'none', label = 'ОБЫЧНО', bones = {}},
	{id = 'cross', label = 'СКРЕСТИТЬ РУКИ', bones = {
		['ValveBiped.Bip01_R_UpperArm'] = Angle(20.26, 16.46, -7.14),
		['ValveBiped.Bip01_R_Forearm'] = Angle(-43.78, -107.18, 15.92),
		['ValveBiped.Bip01_L_UpperArm'] = Angle(-25.14, 0.07, 15.6),
		['ValveBiped.Bip01_L_Forearm'] = Angle(52.43, -106.38, -12.86),
	}},
	{id = 'back', label = 'РУКИ ЗА СПИНОЙ', bones = {
		['ValveBiped.Bip01_R_UpperArm'] = Angle(-28, 18, -21),
		['ValveBiped.Bip01_R_Forearm'] = Angle(0, -30, 0),
		['ValveBiped.Bip01_R_Hand'] = Angle(90, 0, 0),
		['ValveBiped.Bip01_L_UpperArm'] = Angle(28, 18, 21),
		['ValveBiped.Bip01_L_Forearm'] = Angle(0, -30, 0),
		['ValveBiped.Bip01_L_Hand'] = Angle(-90, 0, 0),
	}},
	{id = 'up', label = 'РУКИ ВВЕРХ', bones = {
		['ValveBiped.Bip01_L_Forearm'] = Angle(25, -65, 25),
		['ValveBiped.Bip01_R_Forearm'] = Angle(-25, -65, -25),
		['ValveBiped.Bip01_L_UpperArm'] = Angle(-70, -180, 70),
		['ValveBiped.Bip01_R_UpperArm'] = Angle(70, -180, -70),
	}},
	{id = 'radio', label = 'РУКА У РАЦИИ', bones = {
		['ValveBiped.Bip01_R_UpperArm'] = Angle(30, -70, 10),
		['ValveBiped.Bip01_R_Forearm'] = Angle(0, -110, 0),
		['ValveBiped.Bip01_R_Hand'] = Angle(0, 0, -40),
	}},
}
R.PoseByID = {}
for i, p in ipairs(R.Poses) do R.PoseByID[p.id] = p p.index = i end

R.Phrases = {
	{label = 'ПОДТВЕРЖДЕНИЕ', lines = {'Принял.', 'Так точно.', 'Отрицательно.', 'Это отрицательно.', 'Удерживаю позицию.', 'Позиция зафиксирована.'}},
	{label = 'ДВИЖЕНИЕ', lines = {'Выдвигаюсь.', 'Выдвигаюсь сейчас.', 'Сближаюсь.', 'Прикрой меня.', 'Укрытие.', 'Ухожу от огня.', 'Эхо-один меняет позицию.'}},
	{label = 'БОЙ', lines = {'Вступаю в бой.', 'Открываю огонь.', 'Атакую цель.', 'Подавляю.', 'Огонь на подавление.', 'Перезаряжаюсь.', 'Граната.', 'Граната пошла.'}},
	{label = 'КОНТАКТ', lines = {'Некротики.', 'Некротики на подходе.', 'Паразиты.', 'Муравьиный лев.', 'Визконтакт! Визконтакт!', 'Противник активен.', 'Возможный заражённый.'}},
	{label = 'ДОКЛАДЫ', lines = {'Чисто.', 'Цель уничтожена.', 'Противник нейтрализован.', 'Ликвидация подтверждена.', 'Контакт молчит.', 'Всё ещё ищу...', 'Медик.', 'Получаю урон.'}},
}
R.PhraseOK = {}
for _, c in ipairs(R.Phrases) do for _, l in ipairs(c.lines) do R.PhraseOK[l] = true end end

if SERVER then
	util.AddNetworkString('hla_radial')
	local CH = HLA.Chat

	local custom = {}
	local function loadCustom()
		local t = util.JSONToTable(file.Read('hla/poses.json', 'DATA') or '') or {}
		custom = istable(t) and t or {}
	end
	loadCustom()

	local function boneAngle(pose, bone)
		local c = custom[pose.id] and custom[pose.id][bone]
		if istable(c) then return Angle(tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0) end
		return pose.bones[bone]
	end

	local function clear(p)
		for i = 0, p:GetBoneCount() - 1 do
			if p:GetManipulateBoneAngles(i) ~= angle_zero then p:ManipulateBoneAngles(i, angle_zero) end
		end
	end

	function R.SetPose(p, id)
		local pose = R.PoseByID[id] or R.PoseByID.none
		clear(p)
		p.HLAPose = pose.id ~= 'none' and pose.id or nil
		p:SetNW2String('hla_pose', p.HLAPose or '')
		if not p.HLAPose then return end
		for bone in pairs(pose.bones) do
			local b = p:LookupBone(bone)
			if b then p:ManipulateBoneAngles(b, boneAngle(pose, bone)) end
		end
		for bone in pairs(custom[pose.id] or {}) do
			local b = not pose.bones[bone] and p:LookupBone(bone)
			if b then p:ManipulateBoneAngles(b, boneAngle(pose, bone)) end
		end
	end

	net.Receive('hla_radial', function(_, p)
		if not IsValid(p) or not p:Alive() or p.HLAInMenu then return end
		if (p.HLARadialNext or 0) > CurTime() then return end
		p.HLARadialNext = CurTime() + 0.5
		local what, arg = net.ReadString(), net.ReadString()
		if what == 'pose' then
			if arg ~= 'none' and HLA.IsArmed and HLA.IsArmed(p) then
				p:ChatPrint('[HLA] Сначала уберите оружие (руки)')
				return
			end
			R.SetPose(p, arg)
		elseif what == 'say' and R.PhraseOK[arg] and CH and CH.Say then
			CH.Say(p, 'say', arg)
		end
	end)

	hook.Add('PlayerSwitchWeapon', 'HLARadialPose', function(p, _, new)
		if p.HLAPose and IsValid(new) and HLA.IsArmed and timer.Simple then
			timer.Simple(0, function() if IsValid(p) and p.HLAPose and HLA.IsArmed(p) then R.SetPose(p, 'none') end end)
		end
	end)
	hook.Add('PlayerSpawn', 'HLARadialPose', function(p) if p.HLAPose then R.SetPose(p, 'none') end end)
	hook.Add('PlayerDeath', 'HLARadialPose', function(p) if p.HLAPose then R.SetPose(p, 'none') end end)

	concommand.Add('hla_pose_set', function(p, _, a)
		if IsValid(p) and not (HLA.CanEdit and HLA.CanEdit(p)) then return end
		local pose, bone = a[1], a[2]
		if not R.PoseByID[pose or ''] or not bone then
			if IsValid(p) then p:ChatPrint('hla_pose_set <cross|back|up|radio> <ValveBiped.Bip01_...> <p> <y> <r>') end
			return
		end
		custom[pose] = custom[pose] or {}
		custom[pose][bone] = {tonumber(a[3]) or 0, tonumber(a[4]) or 0, tonumber(a[5]) or 0}
		file.CreateDir('hla')
		file.Write('hla/poses.json', util.TableToJSON(custom, true))
		for _, o in ipairs(player.GetAll()) do if o.HLAPose == pose then R.SetPose(o, pose) end end
		if IsValid(p) then p:ChatPrint('[HLA] Поза «' .. pose .. '»: ' .. bone .. ' = ' .. table.concat(custom[pose][bone], ' ')) end
	end)
end
