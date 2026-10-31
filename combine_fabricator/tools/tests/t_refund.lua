local C = CFRework
local S = C.State
local e = NewEntity('sent_combine_fabricator', ENT_FAB, Vector(0, 0, 0), 0)
e:SetupDataTables() e:Initialize()
local p = NewPlayer(Vector(48, -8, 0)) C.ChangeBalance(p, 50)
local q = NewPlayer(Vector(50, 10, 0)) q.SteamID64 = function() return '76561190000000002' end
local function step(sec) local stop = T + sec while T < stop do T = T + 0.05 RunTimers() e:Think() end end
local function aimAt(pl, w) pl.aim = (w - pl:EyePos()):GetNormalized() end
local function button(stage, tab, id, arg)
	for _, b in ipairs(C.Layout.Buttons(stage, tab)) do if b.id == id and (arg == nil or b.arg == arg) then return b end end
end
local function aimButton(pl, b)
	local o, r, d = C.ScreenWorld(e, C.PoseOf(e)) local s = C.Geo.SCREEN.w / C.Layout.W
	aimAt(pl, o + r * ((b.x + b.w / 2) * s) + d * ((b.y + b.h / 2) * s))
end
step(3)
-- switch to weapons tab, order the shotgun (35)
aimButton(p, button(S.MENU, 1, 'tab', 2)) RunHook('KeyPress', p, IN_USE) T = T + 0.3
print('tab now', e:GetTab())
aimButton(p, button(S.MENU, 2, 'select', 6)) RunHook('KeyPress', p, IN_USE) T = T + 0.3
print('stage', e:GetStage(), 'cost', e:GetCost())
-- second player tries the screen
aimButton(q, button(S.DEPOSIT, 1, 'cancel')) RunHook('KeyPress', q, IN_USE) T = T + 0.3
print('other player ->', e:GetStatusText())
-- feed 5, then cancel
step(0.8) aimAt(p, C.CellsCenter(e, C.PoseOf(e))) p.keys[IN_USE] = true step(1.15) p.keys[IN_USE] = nil
print('paid', e:GetPaid(), 'balance', C.Balance(p))
aimButton(p, button(S.DEPOSIT, 1, 'cancel')) RunHook('KeyPress', p, IN_USE) T = T + 0.3
print('after cancel: stage', e:GetStage(), 'balance', C.Balance(p))
-- order again, feed 3, walk away
step(1)
aimButton(p, button(S.MENU, 2, 'select', 6)) RunHook('KeyPress', p, IN_USE) T = T + 0.3
step(0.8) aimAt(p, C.CellsCenter(e, C.PoseOf(e))) p.keys[IN_USE] = true step(0.6) p.keys[IN_USE] = nil
print('paid', e:GetPaid(), 'balance', C.Balance(p))
p.pos = Vector(900, 0, 0) step(1)
print('after leaving: stage', e:GetStage(), 'balance', C.Balance(p))
-- not enough resin
p.pos = Vector(48, -8, 0) q.pos = Vector(900, 0, 0) step(1)
aimButton(p, button(S.MENU, 2, 'select', 7)) C.ChangeBalance(p, -C.Balance(p) + 3) RunHook('KeyPress', p, IN_USE)
print('poor ->', e:GetStatusText(), 'stage', e:GetStage())
