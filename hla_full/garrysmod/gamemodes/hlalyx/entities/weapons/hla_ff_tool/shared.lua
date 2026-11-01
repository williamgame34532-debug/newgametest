-- Force field adjuster (admins): turn a post of a force field, or the whole field, right in the game.
--   aim at a post:  LMB / RMB — turn this post +90° / -90° around its inner edge (the field stays)
--   aim at a field: LMB / RMB — turn the whole field with both posts around its middle
--   with Shift (walk) held — by 15° instead of 90°
--   Alt + LMB — next skin of the post (on a field: of both posts): auto (blue on / red off), blue,
--               red, the pack's own material
--   R — the posts of the field back to their normal turn (facing along the field)
-- Moving is done with the physgun (take a post: the field follows).
AddCSLuaFile()

SWEP.PrintName = 'Настройщик силового поля'
SWEP.Author = 'hlalyx'
SWEP.Category = 'Half-Life: Alyx'
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Slot = 5
SWEP.ViewModel = 'models/weapons/c_toolgun.mdl'
SWEP.WorldModel = 'models/weapons/w_toolgun.mdl'
SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.Primary = {ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = 'none'}
SWEP.Secondary = {ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = 'none'}

local function target(p)
	local tr = p:GetEyeTraceNoCursor()
	local e = tr.Entity
	if not IsValid(e) or tr.HitPos:DistToSqr(p:EyePos()) > 400 * 400 then return end
	if e:GetClass() == 'hla_forcefield_post' then return e, 'post' end
	if e:GetClass() == 'hla_forcefield' then return e, 'field' end
end

function SWEP:Turn(sign)
	local p = self:GetOwner()
	if not IsValid(p) or not p:IsAdmin() then return end
	local e, kind = target(p)
	if not e then return end
	local deg = sign * (p:KeyDown(IN_SPEED) and 15 or 90)
	if kind == 'post' then e:TurnAroundInner(deg) else e:TurnAll(deg) end
	p:EmitSound('buttons/combine_button1.wav', 50, 110)
end

function SWEP:NextSkin()
	local p = self:GetOwner()
	if not IsValid(p) or not p:IsAdmin() then return end
	local e, kind = target(p)
	if not e then return end
	local posts = kind == 'post' and {e} or {e:GetPostL(), e:GetPostR()}
	local mode
	for _, post in ipairs(posts) do
		if IsValid(post) then
			mode = mode or (post:GetSkinMode() + 1) % 4
			post:SetSkinMode(mode)
		end
	end
	if mode then
		local names = scripted_ents.GetStored('hla_forcefield_post').t.SkinNames
		p:ChatPrint('Скин стойки: ' .. (names[mode] or tostring(mode)))
		p:EmitSound('buttons/combine_button5.wav', 50, 100 + mode * 10)
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.25)
	if SERVER then
		if self:GetOwner():KeyDown(IN_WALK) then self:NextSkin() else self:Turn(1) end
	end
	self:DoShootEffect()
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.25)
	if SERVER then self:Turn(-1) end
	self:DoShootEffect()
end

function SWEP:Reload()
	if CLIENT or (self.NextReset or 0) > CurTime() then return end
	self.NextReset = CurTime() + 0.5
	local p = self:GetOwner()
	if not IsValid(p) or not p:IsAdmin() then return end
	local e, kind = target(p)
	if not e then return end
	local f = kind == 'post' and e:GetField() or e
	if IsValid(f) and f.ResetPosts then f:ResetPosts() p:EmitSound('buttons/combine_button3.wav', 50) end
end

function SWEP:DoShootEffect()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	local p = self:GetOwner()
	if IsValid(p) then p:SetAnimation(PLAYER_ATTACK1) end
end

if CLIENT then
	surface.CreateFont('hla_fftool', {font = 'Roboto Condensed', size = 22, weight = 700, extended = true})
	surface.CreateFont('hla_fftool_s', {font = 'Roboto Condensed', size = 18, weight = 500, extended = true})
	function SWEP:DrawHUD()
		local p = LocalPlayer()
		local e, kind = target(p)
		local c = HLA.Hud and HLA.Hud.AMBER_C or Color(110, 200, 255)
		local x, y = ScrW() / 2, ScrH() * 0.62
		local head = kind == 'post' and 'СТОЙКА СИЛОВОГО ПОЛЯ' or kind == 'field' and 'СИЛОВОЕ ПОЛЕ' or 'НАВЕДИТЕСЬ НА ПОЛЕ ИЛИ СТОЙКУ'
		draw.SimpleTextOutlined(head, 'hla_fftool', x, y, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
		local lines = kind == 'post' and {'ЛКМ / ПКМ — повернуть стойку на 90° (с Shift — на 15°)', 'Alt + ЛКМ — сменить скин стойки', 'E — все настройки поля', 'R — вернуть стойки как при установке', 'Передвинуть — физганом'}
			or kind == 'field' and {'ЛКМ / ПКМ — повернуть всё поле на 90° (с Shift — на 15°)', 'Alt + ЛКМ — сменить скин обеих стоек', 'E — все настройки поля', 'R — вернуть стойки как при установке', 'Передвинуть — физганом за стойку'}
			or {}
		for i, l in ipairs(lines) do
			draw.SimpleTextOutlined(l, 'hla_fftool_s', x, y + 6 + i * 22, Color(220, 235, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160))
		end
		-- outline of what will turn
		if IsValid(e) then
			cam.Start3D()
				local mn, mx = e:OBBMins(), e:OBBMaxs()
				render.DrawWireframeBox(e:GetPos(), e:GetAngles(), mn, mx, c, true)
			cam.End3D()
		end
	end
end
