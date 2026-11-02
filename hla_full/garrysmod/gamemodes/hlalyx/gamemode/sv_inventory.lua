local I = HLA.Items

util.AddNetworkString('hla_inv')
util.AddNetworkString('hla_inv_do')
file.CreateDir('hla/inv')

local function key(p)
	return p.HLACharID and ('char_' .. p.HLACharID) or nil
end

function I.Load(p)
	local k = key(p)
	local t = k and util.JSONToTable(file.Read('hla/inv/' .. k .. '.json', 'DATA') or '') or {}
	local inv = {}
	for i = 1, I.Slots do
		local id = t[tostring(i)] or t[i]
		if isstring(id) and I.Defs[id] then inv[i] = id end
	end
	p.HLAInv = inv
	I.Send(p)
end

function I.Save(p)
	if not p.HLAInv or not key(p) then return end
	local t = {}
	for i = 1, I.Slots do if p.HLAInv[i] then t[tostring(i)] = p.HLAInv[i] end end
	file.Write('hla/inv/' .. key(p) .. '.json', util.TableToJSON(t))
end

function I.Send(p)
	net.Start('hla_inv')
	for i = 1, I.Slots do net.WriteString(p.HLAInv and p.HLAInv[i] or '') end
	net.Send(p)
end

function I.Inv(p)
	if not p.HLAInv then I.Load(p) end
	return p.HLAInv
end

function I.FreeSlot(p)
	local inv = I.Inv(p)
	for i = 1, I.Slots do if not inv[i] then return i end end
end

function I.Count(p, id)
	local n = 0
	for i = 1, I.Slots do if I.Inv(p)[i] == id then n = n + 1 end end
	return n
end

function I.Add(p, id)
	local s = I.FreeSlot(p)
	if not s or not I.Defs[id] then return false end
	I.Inv(p)[s] = id
	I.Save(p) I.Send(p)
	return s
end

function I.Take(p, slot)
	local inv = I.Inv(p)
	local id = inv[slot]
	if not id then return end
	inv[slot] = nil
	I.Save(p) I.Send(p)
	return id
end

function I.SpawnWorld(id, pos, ang)
	local e = ents.Create('hla_item')
	if not IsValid(e) then return end
	e:SetItemID(id)
	e:SetPos(pos)
	e:SetAngles(ang or Angle(0, math.random(0, 359), 0))
	e:Spawn()
	return e
end

local USE = {}
function USE.heal(p, d)
	if p:Health() >= p:GetMaxHealth() then return false, 'Здоровье уже полное' end
	p:SetHealth(math.min(p:GetMaxHealth(), p:Health() + d.amount))
	p:EmitSound(d.sound or 'items/smallmedkit1.wav', 60)
	return true
end
function USE.armor(p, d)
	if p:Armor() >= 100 then return false, 'Броня уже полная' end
	p:SetArmor(math.min(100, p:Armor() + d.amount))
	p:EmitSound('items/battery_pickup.wav', 60)
	return true
end

function USE.ammo(p, d)
	local ammo, amount = d.ammo, d.amount
	if not ammo then
		local w = p:GetActiveWeapon()
		if not IsValid(w) or w:GetPrimaryAmmoType() < 0 then
			for _, o in ipairs(p:GetWeapons()) do if o:GetPrimaryAmmoType() >= 0 then w = o break end end
		end
		if not IsValid(w) or w:GetPrimaryAmmoType() < 0 then return false, 'Нет оружия для этих магазинов' end
		ammo = game.GetAmmoName(w:GetPrimaryAmmoType())
		amount = math.max(w:GetMaxClip1(), 10) * (d.clips or 2)
	end
	if p:GiveAmmo(amount, ammo, true) <= 0 then return false, 'Не удалось взять патроны' end
	p:EmitSound('items/ammo_pickup.wav', 60)
	return true
end

net.Receive('hla_inv_do', function(_, p)
	if not IsValid(p) or not p:Alive() or p.HLAInMenu then return end
	if (p.HLAInvNext or 0) > CurTime() then return end
	p.HLAInvNext = CurTime() + 0.12
	local what = net.ReadString()
	local inv = I.Inv(p)
	if what == 'move' then
		local a, b = net.ReadUInt(5), net.ReadUInt(5)
		if a < 1 or b < 1 or a > I.Slots or b > I.Slots or a == b then return end
		inv[a], inv[b] = inv[b], inv[a]
		I.Save(p) I.Send(p)
		p:EmitSound(I.MoveSound(), 45, 100)
	elseif what == 'use' then
		local s = net.ReadUInt(5)
		local d = inv[s] and I.Defs[inv[s]]
		if not d or not USE[d.use] then return end
		local ok, why = USE[d.use](p, d)
		if ok then I.Take(p, s) elseif why then p:ChatPrint(why) end
	elseif what == 'drop' then
		local s = net.ReadUInt(5)
		local id = I.Take(p, s)
		if not id then return end
		local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * 40, filter = p})
		I.SpawnWorld(id, tr.HitPos + tr.HitNormal * 6)
		p:EmitSound(I.MoveSound(), 50, 90)
	elseif what == 'place' then
		local s, ent = net.ReadUInt(5), net.ReadEntity()
		local id = inv[s]
		if not id or not IsValid(ent) or not ent.AcceptItem then return end
		if p:EyePos():DistToSqr(ent:GetPos()) > 130 * 130 then return end
		if ent:AcceptItem(p, id) then I.Take(p, s) end
	end
end)

hook.Add('PlayerDisconnected', 'HLAInventory', function(p) I.Save(p) end)
hook.Add('ShutDown', 'HLAInventory', function() for _, p in ipairs(player.GetAll()) do I.Save(p) end end)

hook.Add('KeyPress', 'HLAPickup', function(p, k)
	if k ~= IN_USE or not p:Alive() or p.HLAInMenu then return end
	local tr = p:GetEyeTrace()
	local e = tr.Entity
	if IsValid(e) and e.IsHLAItem and tr.HitPos:DistToSqr(p:EyePos()) < I.PickupRange * I.PickupRange then
		p:SetNW2Entity('hla_pick', e)
		p:SetNW2Float('hla_pick_t', CurTime())
	end
end)

hook.Add('PlayerTick', 'HLAPickup', function(p)
	local e = p:GetNW2Entity('hla_pick')
	if not IsValid(e) then return end
	local tr = p:GetEyeTrace()
	if not p:KeyDown(IN_USE) or tr.Entity ~= e or tr.HitPos:DistToSqr(p:EyePos()) > I.PickupRange * I.PickupRange then
		p:SetNW2Entity('hla_pick', NULL)
		return
	end
	if CurTime() - p:GetNW2Float('hla_pick_t') >= I.PickupTime then
		p:SetNW2Entity('hla_pick', NULL)
		if e.Picked then return end
		if I.Add(p, e:GetItemID()) then
			e.Picked = true
			p:EmitSound(I.MoveSound(), 60)
			e:Remove()
		else
			p:ChatPrint('Инвентарь заполнен')
		end
	end
end)

concommand.Add('hla_give_item', function(p, _, a)
	if not IsValid(p) or not p:IsAdmin() then return end
	local id = a[1] or 'health_vial'
	if not I.Defs[id] then p:ChatPrint('Нет такого предмета: ' .. id) return end
	if not I.Add(p, id) then p:ChatPrint('Инвентарь заполнен') end
end)
