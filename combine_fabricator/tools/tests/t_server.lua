-- Scenario: walk up, order a medkit vial (cost 2), feed resin holding E, wait for the print, collect.
local C = CFRework
local S = C.State
local e = NewEntity('sent_combine_fabricator', ENT_FAB, Vector(100, 200, 0), 30)
e:SetupDataTables()
e:Initialize()
local p = NewPlayer(e:LocalToWorld(Vector(48, -8, 0)))
p:SetNWInt('cf_resin', 0)
C.ChangeBalance(p, 20)

local function step(sec)
	local stop = T + sec
	while T < stop do T = T + 0.05 RunTimers() e:Think() end
end
local function aimAt(world) p.aim = (world - p:EyePos()):GetNormalized() end
local function stageName() for k, v in pairs(S) do if v == e:GetStage() then return k end end end
local function show(tag) print(string.format('%-28s t=%5.2f stage=%-8s deploy=%.2f cradle=%.2f tray=%.2f paid=%d/%d resin=%d hp=%d %s',
	tag, T, stageName(), C.Chan(e, 'deploy'), C.Chan(e, 'cradle'), C.Chan(e, 'tray'), e:GetPaid(), e:GetCost(), C.Balance(p), p.hp, e:GetStatusText())) end

show('spawned')
step(3.0) show('after wake-up')

-- aim at the first row (medical tab -> vial)
local pose = C.PoseOf(e)
local origin, right, down = C.ScreenWorld(e, pose)
local scale = C.Geo.SCREEN.w / C.Layout.W
local b = C.Layout.Buttons(S.MENU, 1)[1]
aimAt(origin + right * ((b.x + b.w / 2) * scale) + down * ((b.y + b.h / 2) * scale))
local x, y = C.HitScreen(e, p)
print('screen hit px', x and math.floor(x), y and math.floor(y), 'button', b.id, b.arg)
RunHook('KeyPress', p, IN_USE)
show('after selecting row 1')
step(1.0)

-- hold E on the cells
aimAt(C.CellsCenter(e, C.PoseOf(e)))
print('aimed part', C.HitPart(e, p))
p.keys[IN_USE] = true
step(1.5)
p.keys[IN_USE] = nil
show('after feeding')
step(C.PrintTime * 0.5) show('printing')
step(C.PrintTime * 0.5 + 2) show('after print')

aimAt(C.ItemPoint(e, C.PoseOf(e)))
print('aimed part', C.HitPart(e, p))
T = T + 0.3
RunHook('KeyPress', p, IN_USE)
show('after collecting')
step(2) show('back to menu')

-- walk away: folds up
p.pos = p.pos + Vector(800, 0, 0)
step(7) show('player left')

print('--- sounds')
for _, s in ipairs(SOUNDS) do print(s) end
