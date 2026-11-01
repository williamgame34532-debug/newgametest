-- The dropship: every few minutes (editor, tab ДЕСАНТНИК) a Combine dropship — with its container, if set —
-- flies along the points the admin put down (where he stood: on the ground or in the air, noclip).
-- The server only says «fly now» with the path; every client flies its own model along it (no physics, no
-- network traffic while it flies, nothing to collide with).
local S = HLA.Story
local D = {}
HLA.Dropship = D
util.AddNetworkString('hla_dropship')

local function cfg() return S.Config and S.Config.dropship end

function D.Fly()
	local c = cfg()
	if not c or not istable(c.points) or #c.points < 2 then return false end
	net.Start('hla_dropship')
	net.WriteFloat(CurTime())
	net.WriteBool(c.container ~= false)
	net.WriteUInt(math.Clamp(math.floor(tonumber(c.speed) or 700), 100, 3000), 12)
	net.WriteUInt(math.min(#c.points, 64), 7)
	for i = 1, math.min(#c.points, 64) do
		local p = c.points[i]
		net.WriteVector(Vector(tonumber(p[1]) or 0, tonumber(p[2]) or 0, tonumber(p[3]) or 0))
	end
	net.Broadcast()
	return true
end

local nextAt = 0
timer.Create('HLADropship', 5, 0, function()
	local c = cfg()
	local every = c and tonumber(c.every) or 0
	if every <= 0 or not istable(c.points) or #c.points < 2 then nextAt = 0 return end
	if nextAt == 0 then nextAt = CurTime() + every * 60 return end
	if CurTime() >= nextAt then
		nextAt = CurTime() + every * 60
		D.Fly()
	end
end)

concommand.Add('hla_dropship', function(p)
	if IsValid(p) and not HLA.CanEdit(p) then return end
	if not D.Fly() and IsValid(p) then p:ChatPrint('[HLA] Десантник: нужно хотя бы 2 точки (редактор, вкладка ДЕСАНТНИК)') end
end)
