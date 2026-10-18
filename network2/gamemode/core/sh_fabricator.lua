-- The fabricator of the Alliance (entities/entities/nw_fabricator.lua): a Combine 3D printer of weapons and
-- equipment - the station of acquisition.
--   the resin       the reservoir of the fabricator (up to nw_fabricator_resin, 200). It is filled with the
--                   packed cargo the factory makes (factory_crate, sh_cwu.lua): whoever brings crates and
--                   presses E loads them all in (+25 resin each, the city pays 12 tokens a crate to the one
--                   who is not of the Alliance)
--   the units       E: the window - on the left the station, the sections (Основное / Вторичное /
--                   Третичное оружие / Разное) and the reservoir; on the right the list: the model, the
--                   name, what it is, what it gives, the price in resin, «Получить»
--   what it gives   weapons and things into the inventory (or at the feet), the ammunition of the weapons
--                   in the hands to the full, the armour repaired (at 50 or less)
--   the catalogue   FB.catalog below; an entry with only = "combine" - for the Overwatch only
-- The resin stays with the fabricator (sv_persist.lua); the model - the C menu → «Настройки».

NW.fabricator = NW.fabricator or {}

local FB = NW.fabricator

FB.sections = {
	{id = "primary", name = "Основное оружие", text = "Пистолеты-пулемёты и винтовки для патрулей и ударных групп."},
	{id = "secondary", name = "Вторичное оружие", text = "Личное оружие юнита: пистолет и электродубинка."},
	{id = "tertiary", name = "Третичное оружие", text = "Взрывные устройства Альянса."},
	{id = "misc", name = "Разное", text = "Снабжение: боеприпасы, броня, медицина, пробивные заряды и замки."}
}

FB.catalog = {
	{id = "smg", section = "primary", kind = "item", item = "smg", cost = 40, name = "Пистолет-пулемёт MP7",
		text = "Компактный пистолет-пулемёт с высоким темпом стрельбы.", effect = "Выдаёт оружие в инвентарь.",
		model = "models/weapons/w_smg1.mdl"},
	{id = "ar2", section = "primary", kind = "item", item = "ar2", cost = 80, only = "combine",
		name = "Импульсная винтовка OSIPR", text = "Штатная винтовка Надзора с подствольной энергосферой.",
		effect = "Выдаёт оружие в инвентарь. Только Надзор.", model = "models/weapons/w_irifle.mdl"},
	{id = "shotgun", section = "primary", kind = "item", item = "shotgun", cost = 60, only = "combine",
		name = "Дробовик SPAS-12", text = "Помповый дробовик для зачистки помещений.",
		effect = "Выдаёт оружие в инвентарь. Только Надзор.", model = "models/weapons/w_shotgun.mdl"},
	{id = "pistol", section = "secondary", kind = "item", item = "pistol", cost = 20, name = "Пистолет USP Match",
		text = "Табельный пистолет юнита.", effect = "Выдаёт оружие в инвентарь.", model = "models/weapons/w_pistol.mdl"},
	{id = "stunstick", section = "secondary", kind = "item", item = "stunstick", cost = 10, name = "Электродубинка",
		text = "Оглушает при ударе. Основной инструмент Гражданской Обороны.", effect = "Выдаёт дубинку в инвентарь.",
		model = "models/weapons/w_stunbaton.mdl"},
	{id = "grenade", section = "tertiary", kind = "item", item = "frag_grenade", cost = 25, name = "Осколочная граната",
		text = "Взрывное устройство Альянса. Взрывается через несколько секунд после броска.",
		effect = "Одна граната в инвентарь.", model = "models/items/grenadeammo.mdl"},
	{id = "ammo", section = "misc", kind = "ammo", cost = 15, name = "Боеприпасы",
		text = "Магазины энергоячеек и патронов для оружия юнита.",
		effect = "Пополняет боезапас всего оружия при вас до полного.", model = "models/items/boxmrounds.mdl"},
	{id = "armor", section = "misc", kind = "armor", cost = 20, name = "Ремонт бронекостюма",
		text = "Полный бронекостюм Гражданской Обороны: существенная защита.",
		effect = "Чинит броню, если она 50 или меньше.", model = "models/items/battery.mdl"},
	{id = "stim", section = "misc", kind = "item", item = "stimdose", cost = 15, name = "Стимдоза",
		text = "Шприц Альянса с лечебным составом: почти мгновенное восстановление.",
		effect = "Одна стимдоза в инвентарь.", model = "models/healthvial.mdl"},
	{id = "breach", section = "misc", kind = "item", item = "breach_charge", cost = 30, name = "Пробивной заряд",
		text = "Силой открывает закрытую или запертую дверь.", effect = "Один заряд в инвентарь.",
		model = "models/weapons/w_slam.mdl"},
	{id = "lock", section = "misc", kind = "item", item = "combine_lock", cost = 25, name = "Замок Альянса",
		text = "Дверь открывается только юнитами Альянса.", effect = "Один замок в инвентарь.",
		model = "models/props_combine/combine_lock01.mdl"}
}

FB.byID = {}

for _, entry in ipairs(FB.catalog) do
	FB.byID[entry.id] = entry
end

FB.max = CreateConVar("nw_fabricator_resin", "200", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Сколько смолы вмещает фабрикатор")
FB.perCrate = 25

if (SERVER) then
	util.AddNetworkString("nwFabricator")
	util.AddNetworkString("nwFabricatorAcquire")

	local INV = NW.inventory
	local I = NW.items
	local D = NW.doors

	local function Count(client, id)
		local inventory = INV.Get(client)
		local count = 0

		for index = 1, I.maxSize do
			if (inventory.grid[index] and inventory.grid[index].id == id) then
				count = count + 1
			end
		end

		return count
	end

	local function TakeAll(client, id)
		local inventory = INV.Get(client)

		for index = 1, I.maxSize do
			if (inventory.grid[index] and inventory.grid[index].id == id) then
				inventory.grid[index] = nil
			end
		end
	end

	-- the crates into the reservoir: as many as fit
	function FB.Load(client, fabricator)
		local crates = Count(client, "factory_crate")

		if (crates == 0) then
			return false
		end

		local room = math.floor((FB.max:GetInt() - fabricator:GetResin()) / FB.perCrate)
		local loaded = math.min(crates, room)

		if (loaded <= 0) then
			NW.Notify(client, "Резервуар полон")

			return true
		end

		TakeAll(client, "factory_crate")

		for _ = 1, crates - loaded do
			INV.Add(client, "factory_crate")
		end

		INV.Changed(client)
		fabricator:SetResin(fabricator:GetResin() + loaded * FB.perCrate)
		fabricator:EmitSound("ambient/machines/combine_terminal_idle4.wav", 65)

		-- the workers are paid by the city
		if (!NW.zones.IsAlliance(client)) then
			NW.social.SetTokens(client, NW.social.GetTokens(client) + loaded * 12)
			NW.Notify(client, "Груз сдан в фабрикатор: " .. loaded .. " шт. · +" .. loaded * 12 .. " ток.")
		else
			NW.Notify(client, "Резервуар пополнен: +" .. loaded * FB.perCrate .. " смолы")
		end

		NW.persist.Save("nw_fabricator")

		return true
	end

	function FB.Open(client, fabricator)
		net.Start("nwFabricator")
			net.WriteEntity(fabricator)
		net.Send(client)
	end

	local function Give(client, id)
		if (!INV.Add(client, id)) then
			INV.SpawnWorldItem(client, {id = id, data = {}})
		end

		INV.Changed(client)
	end

	local GIVE = {}

	function GIVE.item(client, entry)
		Give(client, entry.item)
	end

	function GIVE.ammo(client)
		local any = false

		for _, weapon in ipairs(client:GetWeapons()) do
			local ammo = weapon:GetPrimaryAmmoType()

			if (ammo >= 0) then
				local full = math.max(weapon:GetMaxClip1(), 1) * 4

				if (client:GetAmmoCount(ammo) < full) then
					client:SetAmmo(full, ammo)
					any = true
				end
			end

			local second = weapon:GetSecondaryAmmoType()

			if (second >= 0 and client:GetAmmoCount(second) < 2) then
				client:SetAmmo(2, second)
				any = true
			end
		end

		return any or "Боезапас уже полный"
	end

	function GIVE.armor(client)
		if (client:Armor() > 50) then
			return "Броня ещё цела (больше 50)"
		end

		client:SetArmor(100)
		client:EmitSound("items/battery_pickup.wav", 60)
	end

	net.Receive("nwFabricatorAcquire", function(_, client)
		local fabricator = net.ReadEntity()
		local entry = FB.byID[net.ReadString()]

		if (!entry or !IsValid(fabricator) or fabricator:GetClass() != "nw_fabricator" or
			client:GetPos():DistToSqr(fabricator:GetPos()) > 160 * 160 or !NW.zones.IsAlliance(client) or
			(client.nwFabNext or 0) > CurTime()) then
			return
		end

		client.nwFabNext = CurTime() + 1.5

		if (entry.only and client:GetFaction() != entry.only) then
			return NW.Notify(client, "Недоступно для вашего подразделения")
		elseif (fabricator:GetResin() < entry.cost) then
			return NW.Notify(client, "Не хватает смолы: нужно " .. entry.cost .. ". Пополните резервуар грузом завода")
		end

		local problem = GIVE[entry.kind](client, entry)

		if (isstring(problem)) then
			return NW.Notify(client, problem)
		end

		fabricator:SetResin(fabricator:GetResin() - entry.cost)
		fabricator:Print()
		NW.persist.Save("nw_fabricator")
		NW.Notify(client, "Получено: " .. entry.name .. " · −" .. entry.cost .. " смолы")
		MsgN(string.format("[FABRICATOR] %s (%s): %s", client:Nick(), client:SteamName(), entry.id))
	end)

	-- ------------------------------------------------------ the things it makes --
	function FB.PlaceLock(client)
		local trace = client:GetEyeTrace()
		local door = trace.Entity

		if (!D.IsDoor(door) or trace.HitPos:DistToSqr(client:GetShootPos()) > 100 * 100) then
			NW.Notify(client, "Посмотрите на дверь рядом")

			return false
		end

		local stored = scripted_ents.GetStored("nw_combinelock")
		local lock = stored and stored.t.SpawnFunction(stored.t, client, trace)

		if (!IsValid(lock)) then
			return false
		end

		client:EmitSound("doors/door_metal_thin_close2.wav", 60)
		NW.Notify(client, "Замок установлен")

		return true
	end

	function FB.Breach(client)
		local trace = client:GetEyeTrace()
		local door = trace.Entity

		if (!D.IsDoor(door) or trace.HitPos:DistToSqr(client:GetShootPos()) > 100 * 100) then
			NW.Notify(client, "Посмотрите на дверь рядом")

			return false
		end

		local charge = ents.Create("prop_physics")

		charge:SetModel("models/weapons/w_slam.mdl")
		charge:SetPos(trace.HitPos + trace.HitNormal * 1.5)
		charge:SetAngles(trace.HitNormal:Angle() + Angle(90, 0, 0))
		charge:Spawn()
		charge:SetMoveType(MOVETYPE_NONE)
		charge:SetCollisionGroup(COLLISION_GROUP_WORLD)
		charge:SetParent(door)

		NW.SayMe(client, "ставит пробивной заряд на дверь")

		for beep = 0, 4 do
			timer.Simple(beep * 0.6, function()
				if (IsValid(charge)) then
					charge:EmitSound("buttons/blip1.wav", 70, 100 + beep * 12)
				end
			end)
		end

		timer.Simple(3, function()
			if (!IsValid(charge)) then
				return
			end

			local pos = charge:GetPos()

			charge:Remove()

			local effect = EffectData()

			effect:SetOrigin(pos)
			util.Effect("Explosion", effect, true, true)
			util.BlastDamage(IsValid(client) and client or game.GetWorld(), IsValid(client) and client or game.GetWorld(),
				pos, 110, 35)

			if (!IsValid(door)) then
				return
			end

			local lock = door.nwCombineLock

			if (IsValid(lock) and lock.SetState) then
				lock:SetState(false)
			end

			local name = IsValid(client) and ("nwBreacher" .. client:EntIndex()) or ""

			if (IsValid(client)) then
				client:SetName(name)
			end

			for _, member in ipairs(D.Group(door)) do
				member.nwLocked = false
				member:Fire("Unlock")

				if (member:GetClass() == "prop_door_rotating" and name != "") then
					member:Fire("OpenAwayFrom", name)
				else
					member:Fire("Open")
				end
			end

			util.ScreenShake(pos, 8, 10, 0.6, 600)
		end)

		return true
	end

	return
end

-- ------------------------------------------------------------------ client --
surface.CreateFont("nwFabTitle", {font = "Exo 2", size = math.max(20, math.Round(ScrH() * 0.034)), weight = 600,
	extended = true, antialias = true})
surface.CreateFont("nwFabText", {font = "Exo 2", size = math.max(12, math.Round(ScrH() * 0.017)), weight = 500,
	extended = true, antialias = true})
surface.CreateFont("nwFabRow", {font = "Exo 2", size = math.max(16, math.Round(ScrH() * 0.027)), weight = 600,
	extended = true, antialias = true})
surface.CreateFont("nwFabButton", {font = "Exo 2", size = math.max(12, math.Round(ScrH() * 0.018)), weight = 500,
	extended = true, antialias = true})

local TEXT = Color(226, 230, 232)
local DIM = Color(170, 176, 180)
local CELL = Color(42, 44, 46, 235)
local CELL_HOVER = Color(56, 60, 62, 240)
local CORNERS = {primary = Color(196, 52, 40), secondary = Color(196, 52, 40), tertiary = Color(196, 52, 40),
	misc = Color(196, 140, 52)}

local function Click()
	surface.PlaySound("network2/cmbterminal/combine_tech_click_0" .. math.random(1, 5) .. ".wav")
end

net.Receive("nwFabricator", function()
	local fabricator = net.ReadEntity()

	if (!IsValid(fabricator)) then
		return
	end

	if (IsValid(FB.frame)) then
		FB.frame:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")
	local pad = math.Round(sw * 0.02)
	local leftW = math.Round(sw * 0.33)

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame.born = RealTime()
	frame.section = FB.section or "misc"
	FB.frame = frame

	frame.Paint = function(self, w, h)
		local a = math.Clamp((RealTime() - self.born) / 0.25, 0, 1)

		NW.ui.Blur(0, 0, w, h, 4, 255 * a, self, 12)
		surface.SetDrawColor(10, 12, 14, 215 * a)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText("Станция снабжения", "nwFabTitle", pad, sh * 0.035, ColorAlpha(TEXT, 255 * a))
		draw.SimpleText("Комбайновский 3D-принтер для изготовления оружия и снаряжения.", "nwFabText", pad, sh * 0.075,
			ColorAlpha(DIM, 255 * a))

		local section

		for _, entry in ipairs(FB.sections) do
			if (entry.id == self.section) then
				section = entry
			end
		end

		draw.SimpleText(section.name, "nwFabTitle", pad * 2 + leftW, sh * 0.035, ColorAlpha(TEXT, 255 * a))
		draw.SimpleText(section.text, "nwFabText", pad * 2 + leftW, sh * 0.075, ColorAlpha(DIM, 255 * a))

		-- the reservoir
		local ry = sh * 0.095 + #FB.sections * sh * 0.062 + sh * 0.02
		local resin, max = IsValid(fabricator) and fabricator:GetResin() or 0, FB.max:GetInt()

		draw.SimpleText("Резервуар смолы", "nwFabTitle", pad, ry, ColorAlpha(TEXT, 255 * a))
		draw.SimpleText("Пополняется упакованным грузом завода (" .. FB.perCrate .. " смолы за ящик).", "nwFabText", pad,
			ry + sh * 0.04, ColorAlpha(DIM, 255 * a))
		surface.SetDrawColor(60, 62, 64, 255 * a)
		surface.DrawRect(pad, ry + sh * 0.07, leftW, 4)
		surface.SetDrawColor(230, 232, 234, 255 * a)
		surface.DrawRect(pad, ry + sh * 0.07, leftW * math.Clamp(resin / max, 0, 1), 4)
		draw.SimpleText(math.Round(resin / max * 100) .. "% - " .. resin .. "/" .. max, "nwFabText", pad + leftW,
			ry + sh * 0.085, ColorAlpha(DIM, 255 * a), TEXT_ALIGN_RIGHT)
	end

	local close = vgui.Create("DButton", frame)

	close:SetText("")
	close:SetSize(sw * 0.06, sh * 0.035)
	close:SetPos(sw - pad - sw * 0.06, sh * 0.01)
	close.Paint = function(self, w, h)
		draw.SimpleText("ЗАКРЫТЬ  ✕", "nwFabButton", w, h / 2, self:IsHovered() and color_white or DIM, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end
	close.DoClick = function()
		Click()
		frame:Remove()
	end

	local list = vgui.Create("DScrollPanel", frame)
	local listX = pad * 2 + leftW

	list:SetPos(listX, sh * 0.1)
	list:SetSize(sw - listX - pad, sh * 0.85)

	local function Fill()
		list:Clear()

		local me = LocalPlayer()

		for _, entry in ipairs(FB.catalog) do
			if (entry.section == frame.section) then
				local rowH = math.Round(sh * 0.09)
				local row = list:Add("DPanel")
				local locked = entry.only and me:GetFaction() != entry.only

				row:Dock(TOP)
				row:DockMargin(0, 0, 0, 3)
				row:SetTall(rowH)
				row.Paint = function(self, w, h)
					draw.RoundedBox(0, 0, 0, w, h, CELL)

					-- the price corner
					local corner = CORNERS[entry.section]

					draw.NoTexture()
					surface.SetDrawColor(corner.r, corner.g, corner.b, 220)
					surface.DrawPoly({{x = h * 0.82, y = h - 2}, {x = h * 0.82 + h * 0.18, y = h - h * 0.18 - 2},
						{x = h * 0.82 + h * 0.18, y = h - 2}})

					draw.SimpleText(entry.name, "nwFabRow", h * 1.1, h * 0.24, locked and DIM or TEXT, TEXT_ALIGN_LEFT,
						TEXT_ALIGN_CENTER)
					draw.SimpleText(entry.text, "nwFabText", h * 1.1, h * 0.54, DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(entry.effect, "nwFabButton", h * 1.1, h * 0.79, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end

				local icon = row:Add("DModelPanel")

				icon:SetPos(4, 4)
				icon:SetSize(rowH - 8, rowH - 8)
				icon:SetModel(entry.model)
				icon:SetMouseInputEnabled(false)
				icon.LayoutEntity = function(self, model)
					model:SetAngles(Angle(0, 30, 0))
				end

				local model = icon:GetEntity()

				if (IsValid(model)) then
					local mins, maxs = model:GetRenderBounds()
					local size = math.max(maxs:Distance(mins), 4)

					icon:SetFOV(30)
					icon:SetCamPos(Vector(size * 1.6, size * 0.6, size * 0.5))
					icon:SetLookAt((mins + maxs) / 2)
				end

				local acquire = row:Add("DButton")
				local bw = math.Round(sw * 0.08)

				acquire:SetText("")
				acquire:Dock(RIGHT)
				acquire:SetWide(bw)
				acquire.Paint = function(self, w, h)
					local enough = IsValid(fabricator) and fabricator:GetResin() >= entry.cost and !locked

					if (self:IsHovered() and enough) then
						surface.SetDrawColor(CELL_HOVER)
						surface.DrawRect(0, 0, w, h)
					end

					draw.SimpleText(locked and "Недоступно" or "Получить", "nwFabButton", w / 2, h * 0.42,
						enough and TEXT or DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(entry.cost .. " смолы", "nwFabText", w / 2, h * 0.66, enough and DIM or
						Color(196, 80, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				acquire.DoClick = function()
					Click()

					net.Start("nwFabricatorAcquire")
						net.WriteEntity(fabricator)
						net.WriteString(entry.id)
					net.SendToServer()
				end
			end
		end
	end

	for index, section in ipairs(FB.sections) do
		local button = vgui.Create("DButton", frame)

		button:SetText("")
		button:SetPos(pad, sh * 0.1 + (index - 1) * sh * 0.062)
		button:SetSize(leftW, sh * 0.058)
		button.Paint = function(self, w, h)
			local active = frame.section == section.id

			surface.SetDrawColor(active and CELL_HOVER or (self:IsHovered() and Color(50, 52, 54, 240) or CELL))
			surface.DrawRect(0, 0, w, h)
			draw.SimpleText(section.name, "nwFabButton", w / 2, h / 2, active and color_white or TEXT, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			Click()
			frame.section = section.id
			FB.section = section.id
			Fill()
		end
	end

	Fill()
	surface.PlaySound("buttons/combine_button7.wav")
end)
