NETWORK.weaponSelect = NETWORK.weaponSelect or {}

local select = NETWORK.weaponSelect

select.index = select.index or 1
select.display = select.display or 1
select.alpha = select.alpha or 0
select.fade = select.fade or 0
select.fadeTime = select.fadeTime or 0

function select.GetWeapons()
	local client = LocalPlayer()
	local weapons = {}

	if (!IsValid(client)) then
		return weapons
	end

	for _, weapon in ipairs(client:GetWeapons()) do
		if (IsValid(weapon)) then
			weapons[#weapons + 1] = weapon
		end
	end

	table.sort(weapons, function(a, b)
		return a:GetClass() < b:GetClass()
	end)

	return weapons
end

function select.Show(weapon)
	select.alpha = 1
	select.fadeTime = CurTime() + 4

	if (IsValid(weapon)) then
		NETWORK.sound.Interface("menus/ui/click_wepselect.wav")
	end
end

hook.Add("HUDShouldDraw", "nwWeaponSelect", function(element)
	if (element == "CHudWeaponSelection") then
		return false
	end
end)

hook.Add("PlayerBindPress", "nwWeaponSelect", function(client, bind, pressed)
	if (!pressed or !client:HasCharacter()) then
		return
	end

	if (NETWORK.cmbterm and NETWORK.cmbterm.control) then
		return
	end

	bind = string.lower(bind)

	local bScroll = string.find(bind, "invprev") or string.find(bind, "invnext")
	local bSlot = string.find(bind, "slot")
	local bAttack = string.find(bind, "attack")

	if (!bScroll and !bSlot and !bAttack) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (client:InVehicle() or (IsValid(weapon) and weapon:GetClass() == "weapon_physgun"
		and client:KeyDown(IN_ATTACK))) then
		return
	end

	if (IsValid(weapon) and weapon:GetClass() == "gmod_tool") then
		local tool = client:GetTool()

		if (tool and tool.Scroll != nil) then
			return
		end
	end

	local weapons = select.GetWeapons()

	if (#weapons == 0) then
		return
	end

	if (string.find(bind, "invprev")) then
		select.index = select.index % #weapons + 1

		select.Show(weapons[select.index])

		return true
	end

	if (string.find(bind, "invnext")) then
		select.index = (select.index - 2) % #weapons + 1

		select.Show(weapons[select.index])

		return true
	end

	if (bSlot) then
		select.index = math.Clamp(tonumber(string.match(bind, "slot(%d)")) or 1, 1, #weapons)

		select.Show(weapons[select.index])

		return true
	end

	if (bAttack and select.alpha > 0) then
		local chosen = weapons[select.index]

		if (IsValid(chosen)) then
			client:EmitSound("buttons/button24.wav", 50, 120, 0.4)

			input.SelectWeapon(chosen)

			select.alpha = 0
		end

		return true
	end
end)

hook.Add("HUDPaint", "nwWeaponSelect", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or IsValid(NETWORK.gui.menu)) then
		select.alpha = 0

		return
	end

	local frame = FrameTime()

	select.fade = Lerp(frame * 12, select.fade, select.alpha)

	if (select.fade <= 0.01) then
		return
	end

	local weapons = select.GetWeapons()

	if (#weapons == 0) then
		return
	end

	if (!weapons[select.index]) then
		select.index = #weapons
	end

	select.display = Lerp(frame * 14, select.display, select.index)

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local fraction = select.fade
	local rowHeight = Sc(46)
	local rowWidth = Sc(380)
	local x = ScrW() - rowWidth - Sc(56)
	local centerY = math.Round(ScrH() * 0.5) - (select.display - 1) * rowHeight

	local accent = theme.accent
	local kind = NETWORK.chud and NETWORK.chud.GetKind and
		NETWORK.chud.GetKind(client)

	if (kind) then
		accent = NETWORK.chud.GetPalette(kind).main
	end

	for i = 1, #weapons do
		local weapon = weapons[i]
		local rowY = centerY + (i - 1) * rowHeight
		local distance = math.abs(i - select.display)
		local alpha = math.Clamp(255 - distance * 105, 0, 255) * fraction

		if (alpha <= 2) then
			continue
		end

		local bActive = i == select.index
		local name = util.Upper(language.GetPhrase(weapon:GetPrintName()))

		local lit = math.Clamp(1 - distance, 0, 1)
		local scale = 1 + 0.22 * lit
		local slide = math.Round(distance * Sc(10) - lit * Sc(8))
		local top = rowY - Sc(18)

		local tint = Color(
			Lerp(lit, theme.textDim.r, accent.r),
			Lerp(lit, theme.textDim.g, accent.g),
			Lerp(lit, theme.textDim.b, accent.b)
		)

		if (lit > 0.01) then

			surface.SetDrawColor(8, 11, 15, 235 * fraction * lit)
			surface.DrawRect(x, top, rowWidth, Sc(36))

			surface.SetDrawColor(accent.r, accent.g, accent.b, 250 * fraction * lit)
			surface.DrawRect(x, top, math.max(Sc(3), 2), Sc(36))

			surface.SetDrawColor(accent.r, accent.g, accent.b, 26 * fraction * lit)
			surface.DrawRect(x, top, rowWidth, Sc(36))

			surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * fraction * lit)
			surface.DrawRect(x + rowWidth - Sc(14), top, Sc(14),
				math.max(Sc(2), 1))
			surface.DrawRect(x + rowWidth - Sc(14), top + Sc(36) -
				math.max(Sc(2), 1), Sc(14), math.max(Sc(2), 1))
		end

		draw.SimpleText(i, "nwHudLabelSmall", x - Sc(12), rowY,
			ColorAlpha(bActive and accent or theme.textFaint, alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local textX = x + Sc(16) + slide
		local textY = rowY - lit * Sc(5)
		local matrix = Matrix()

		matrix:Translate(Vector(textX, textY, 0))
		matrix:Scale(Vector(scale, scale, 1))
		matrix:Translate(Vector(-textX, -textY, 0))

		cam.PushModelMatrix(matrix, true)

		util.DrawSimpleTextShadow(name, "nwHudLabel", textX, textY,
			ColorAlpha(tint, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER,
			math.max(Sc(2), 1))

		cam.PopModelMatrix()

		if (!bActive) then
			continue
		end

		local ammo = weapon:Clip1()

		if (!ammo or ammo < 0) then
			continue
		end

		local maximum = math.max(weapon:GetMaxClip1(), 1)
		local reserve = client:GetAmmoCount(weapon:GetPrimaryAmmoType())

		util.DrawSimpleTextShadow(ammo, "nwHudSmall", x + Sc(16) + slide,
			rowY + Sc(11), ColorAlpha(theme.value, alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

		util.DrawSimpleTextShadow("+" .. reserve, "nwHudSmall",
			x + rowWidth - Sc(14), rowY + Sc(11),
			ColorAlpha(theme.textDim, alpha), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

		local ratio = math.Clamp(ammo / maximum, 0, 1)

		util.DrawProgressBar(x + math.max(Sc(3), 2), top + Sc(36) - Sc(3),
			rowWidth - math.max(Sc(3), 2), math.max(Sc(3), 2), ratio,
			ratio > 0.25 and accent or Color(226, 92, 84), fraction)
	end

	if (select.fadeTime < CurTime() and select.alpha > 0) then
		select.alpha = 0
	end
end)
