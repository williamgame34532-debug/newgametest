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
-- how long a thing is printed (seconds)
FB.printTime = 2.8

if (SERVER) then
	util.AddNetworkString("nwFabricator")
	util.AddNetworkString("nwFabricatorAcquire")
	util.AddNetworkString("nwFabricatorClose")

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

		-- the resin tray: out, the crates in, back
		fabricator:EmitSound("network2/fabricator/resin_tray_open.wav", 66)

		timer.Simple(1.2, function()
			if (IsValid(fabricator)) then
				fabricator:EmitSound("network2/fabricator/resin_tray_advance.wav", 66)
			end
		end)

		timer.Simple(1.9, function()
			if (IsValid(fabricator)) then
				fabricator:EmitSound("network2/fabricator/resin_tray_retract.wav", 66)
			end
		end)

		TakeAll(client, "factory_crate")

		for _ = 1, crates - loaded do
			INV.Add(client, "factory_crate")
		end

		INV.Changed(client)
		fabricator:SetResin(fabricator:GetResin() + loaded * FB.perCrate)

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
		fabricator:EmitSound("network2/fabricator/eyestalk_extend.wav", 60, 100, 0.6)
		fabricator:EmitSound("network2/fabricator/interface_open.wav", 60, 100, 0.5)

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

		if (fabricator:GetPrinted() + FB.printTime > CurTime()) then
			return NW.Notify(client, "Фабрикатор занят: идёт печать")
		end

		-- the supplies (ammunition, armour) right away; the things are printed first
		if (entry.kind != "item") then
			local problem = GIVE[entry.kind](client, entry)

			if (isstring(problem)) then
				return NW.Notify(client, problem)
			end

			fabricator:SetResin(fabricator:GetResin() - entry.cost)
			fabricator:EmitSound("network2/fabricator/resin_tray_advance.wav", 65)
			NW.persist.Save("nw_fabricator")

			return NW.Notify(client, "Получено: " .. entry.name .. " · −" .. entry.cost .. " смолы")
		end

		fabricator:SetResin(fabricator:GetResin() - entry.cost)
		fabricator:Print(entry.section == "primary" or entry.section == "secondary")
		NW.persist.Save("nw_fabricator")
		MsgN(string.format("[FABRICATOR] %s (%s): %s", client:Nick(), client:SteamName(), entry.id))

		timer.Simple(FB.printTime, function()
			if (!IsValid(client)) then
				return
			end

			if (IsValid(fabricator) and client:GetPos():DistToSqr(fabricator:GetPos()) > 300 * 300) then
				-- walked away: it lies at the fabricator
				local item = ents.Create("nw_item")

				if (IsValid(item)) then
					item:SetItem(entry.item, {})
					item:SetPos(fabricator:LocalToWorld(Vector(fabricator:OBBMaxs().x + 10, 0, 20)))
					item:Spawn()

					return
				end
			end

			GIVE.item(client, entry)
			NW.Notify(client, "Получено: " .. entry.name .. " · −" .. entry.cost .. " смолы")
		end)
	end)

	net.Receive("nwFabricatorClose", function(_, client)
		local fabricator = net.ReadEntity()

		if (IsValid(fabricator) and fabricator:GetClass() == "nw_fabricator" and
			client:GetPos():DistToSqr(fabricator:GetPos()) < 300 * 300) then
			fabricator:EmitSound("network2/fabricator/eyestalk_retract.wav", 60, 100, 0.6)
		end
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
-- The window: the glass of the Alliance terminal. On the left the reservoir (a tall gauge in segments)
-- and the sections; on the right the cards (the model turning, the name, what it is, the price in resin,
-- «Печать»); at the bottom the line of the printing while it goes.
surface.CreateFont("nwFabHead", {font = "Oswald Medium", size = math.max(16, math.Round(ScrH() * 0.03)), weight = 500,
	extended = true, antialias = true})
surface.CreateFont("nwFabText", {font = "Exo 2", size = math.max(11, math.Round(ScrH() * 0.0155)), weight = 500,
	extended = true, antialias = true})
surface.CreateFont("nwFabName", {font = "Exo 2", size = math.max(13, math.Round(ScrH() * 0.019)), weight = 700,
	extended = true, antialias = true})
surface.CreateFont("nwFabMono", {font = "JetBrains Mono ExtraBold", size = math.max(10, math.Round(ScrH() * 0.014)),
	weight = 800, extended = true, antialias = true})

local GLASS = Color(8, 18, 24, 236)
local CARD = Color(14, 30, 38, 230)
local CARD_HOVER = Color(22, 48, 60, 240)
local CYAN = Color(96, 200, 240)
local DIM = Color(110, 160, 180)
local TEXT = Color(214, 238, 246)
local RED = Color(220, 96, 80)

local function Click()
	surface.PlaySound("network2/cmbterminal/combine_tech_click_0" .. math.random(1, 5) .. ".wav")
end

local function Up(text)
	return NW.terminal and NW.terminal.Upper and NW.terminal.Upper(text) or text
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
	local w, h = math.Round(math.min(sw * 0.8, sh * 1.5)), math.Round(sh * 0.78)
	local back = vgui.Create("EditablePanel")
	local frame = back:Add("EditablePanel")
	local pad = math.Round(sh * 0.022)
	local leftW = math.Round(w * 0.22)
	local top = math.Round(sh * 0.07)

	back:SetSize(sw, sh)
	back:MakePopup()
	back.Paint = function(self, pw, ph)
		NW.ui.Blur(0, 0, pw, ph, 3, 255, self, 10)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, pw, ph)
	end
	back.OnRemove = function()
		net.Start("nwFabricatorClose")
			net.WriteEntity(fabricator)
		net.SendToServer()
	end

	frame:SetSize(w, h)
	frame:Center()
	frame.section = FB.section or "primary"
	frame.born = RealTime()
	FB.frame = back

	frame.Paint = function(self, pw, ph)
		local a = math.Clamp((RealTime() - self.born) / 0.25, 0, 1)

		draw.RoundedBox(6, 0, 0, pw, ph, ColorAlpha(GLASS, GLASS.a * a))
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 90 * a)
		surface.DrawOutlinedRect(0, 0, pw, ph, 1)

		-- the head: a lit strip with the name, the node on the right
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 22 * a)
		surface.DrawRect(1, 1, pw - 2, top - 2)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 160 * a)
		surface.DrawRect(0, top - 1, pw, 1)
		draw.SimpleText("ФАБРИКАТОР", "nwFabHead", pad, top / 2, ColorAlpha(TEXT, 255 * a), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("ПЕЧАТЬ СНАРЯЖЕНИЯ  ::  УЗЕЛ " .. string.format("%02d", fabricator:EntIndex() % 97), "nwFabMono",
			pad + sh * 0.17, top / 2, ColorAlpha(DIM, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- the reservoir: a tall gauge in segments
		local resin, max = IsValid(fabricator) and fabricator:GetResin() or 0, FB.max:GetInt()
		local gx, gy, gw, gh = pad, top + pad, math.Round(leftW * 0.28), math.Round(h * 0.42)
		local segments = 12
		local filled = resin / max * segments

		for index = 0, segments - 1 do
			local sy = gy + gh - (index + 1) * (gh / segments)
			local lit = math.Clamp(filled - index, 0, 1)

			surface.SetDrawColor(30, 54, 64, 255 * a)
			surface.DrawRect(gx, sy + 2, gw, gh / segments - 4)

			if (lit > 0) then
				surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, (80 + 175 * lit) * a)
				surface.DrawRect(gx, sy + 2, gw, gh / segments - 4)
			end
		end

		local tx = gx + gw + pad * 0.6

		draw.SimpleText("СМОЛА", "nwFabMono", tx, gy, ColorAlpha(DIM, 255 * a))
		draw.SimpleText(resin, "nwFabHead", tx, gy + sh * 0.02, ColorAlpha(TEXT, 255 * a))
		draw.SimpleText("из " .. max, "nwFabText", tx, gy + sh * 0.06, ColorAlpha(DIM, 255 * a))

		local note = NW.inventory.WrapText("Пополняется грузом завода: " .. FB.perCrate .. " за ящик.", "nwFabText",
			leftW - gw - pad * 1.6)

		for index, line in ipairs(note) do
			draw.SimpleText(line, "nwFabText", tx, gy + gh - #note * sh * 0.02 + (index - 1) * sh * 0.02,
				ColorAlpha(DIM, 200 * a))
		end

		-- the printing now
		local since = IsValid(fabricator) and CurTime() - fabricator:GetPrinted() or 99

		if (since < FB.printTime) then
			local bx, by, bw = leftW + pad * 2, h - pad - sh * 0.012, w - leftW - pad * 3

			surface.SetDrawColor(30, 54, 64, 255 * a)
			surface.DrawRect(bx, by, bw, 4)
			surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 255 * a)
			surface.DrawRect(bx, by, bw * since / FB.printTime, 4)
			draw.SimpleText("ПЕЧАТЬ  " .. math.floor(since / FB.printTime * 100) .. "%", "nwFabMono", bx + bw, by - 4,
				ColorAlpha(CYAN, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	local close = frame:Add("DButton")

	close:SetText("")
	close:SetSize(top, top)
	close:SetPos(w - top, 0)
	close.Paint = function(self, pw, ph)
		draw.SimpleText("✕", "nwFabName", pw / 2, ph / 2, self:IsHovered() and RED or DIM, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
	close.DoClick = function()
		Click()
		back:Remove()
	end

	-- the cards
	local gridX = leftW + pad * 2
	local scroll = frame:Add("DScrollPanel")

	scroll:SetPos(gridX, top + pad)
	scroll:SetSize(w - gridX - pad, h - top - pad * 2 - sh * 0.03)

	local function Fill()
		scroll:Clear()

		local me = LocalPlayer()
		local columns = 3
		local gap = math.Round(sh * 0.012)
		local cw = math.floor((scroll:GetWide() - 12 - gap * (columns - 1)) / columns)
		local ch = math.Round(cw * 0.92)
		local index = 0
		local canvas = scroll:Add("EditablePanel")

		canvas:Dock(TOP)

		for _, entry in ipairs(FB.catalog) do
			if (entry.section == frame.section) then
				local col, row = index % columns, math.floor(index / columns)
				local locked = entry.only and me:GetFaction() != entry.only
				local card = canvas:Add("DButton")

				index = index + 1
				card:SetText("")
				card:SetPos(col * (cw + gap), row * (ch + gap))
				card:SetSize(cw, ch)
				card.Paint = function(self, pw, ph)
					local enough = IsValid(fabricator) and fabricator:GetResin() >= entry.cost and !locked

					draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and enough and CARD_HOVER or CARD)
					surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, self:IsHovered() and 160 or 50)
					surface.DrawOutlinedRect(0, 0, pw, ph, 1)

					local ty = ph * 0.56

					draw.SimpleText(entry.name, "nwFabName", pw * 0.06, ty, locked and DIM or TEXT)

					for line, part in ipairs(NW.inventory.WrapText(entry.effect, "nwFabText", pw * 0.88)) do
						if (line <= 2) then
							draw.SimpleText(part, "nwFabText", pw * 0.06, ty + sh * 0.028 + (line - 1) * sh * 0.019, DIM)
						end
					end

					-- the price and the action
					local bh = ph * 0.15

					surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, enough and (self:IsHovered() and 60 or 25) or 10)
					surface.DrawRect(0, ph - bh, pw, bh)
					draw.SimpleText("◆ " .. entry.cost, "nwFabMono", pw * 0.06, ph - bh / 2,
						enough and CYAN or RED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(locked and "ТОЛЬКО ОТА" or (entry.kind == "item" and "ПЕЧАТЬ" or "ВЫДАТЬ"), "nwFabMono",
						pw * 0.94, ph - bh / 2, enough and TEXT or DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
				card.DoClick = function()
					Click()

					net.Start("nwFabricatorAcquire")
						net.WriteEntity(fabricator)
						net.WriteString(entry.id)
					net.SendToServer()
				end

				local view = card:Add("DModelPanel")

				view:SetPos(cw * 0.06, ch * 0.04)
				view:SetSize(cw * 0.88, ch * 0.48)
				view:SetModel(entry.model)
				view:SetMouseInputEnabled(false)
				view.LayoutEntity = function(self, model)
					model:SetAngles(Angle(0, RealTime() * 25 % 360, 0))
				end

				local model = view:GetEntity()

				if (IsValid(model)) then
					local mins, maxs = model:GetRenderBounds()
					local size = math.max(maxs:Distance(mins), 4)

					view:SetFOV(32)
					view:SetCamPos(Vector(size * 1.5, size * 0.4, size * 0.45))
					view:SetLookAt((mins + maxs) / 2)
				end
			end
		end

		canvas:SetTall(math.ceil(index / columns) * (ch + gap))
	end

	-- the sections
	local sy = top + pad + math.Round(h * 0.42) + pad * 1.5

	for number, section in ipairs(FB.sections) do
		local button = frame:Add("DButton")

		button:SetText("")
		button:SetPos(pad, sy + (number - 1) * sh * 0.052)
		button:SetSize(leftW, sh * 0.046)
		button.Paint = function(self, pw, ph)
			local active = frame.section == section.id

			surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, active and 40 or (self:IsHovered() and 20 or 0))
			surface.DrawRect(0, 0, pw, ph)

			if (active) then
				surface.SetDrawColor(CYAN)
				surface.DrawRect(0, 0, 3, ph)
			end

			draw.SimpleText(Up(section.name), "nwFabMono", ph * 0.4, ph / 2, active and TEXT or DIM, TEXT_ALIGN_LEFT,
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
end)
