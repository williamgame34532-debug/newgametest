-- Combine terminals. The working one is the HL:A console vr_combine_interface_01 (hla_terminal_console):
-- it stays folded (closed_idle), the interface is drawn on its own screen at the top of the panel;
-- E — the camera goes to the screen (like at the fabricator), the mouse drives a cursor; the command
-- index, the squads (create, join, leave, disband) and the session log.
-- The HL:A monitors (combine_monitor_large / medium / small) are without power: a red screen
-- «:: ВНИМАНИЕ, ВНИМАНИЕ - ТЕРМИНАЛ ОБЕСТОЧЕН ::», no use.
ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Монитор Альянса (большой, обесточен)'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

ENT.Models = {'models/hla/terminal/combine_monitor_large.mdl', 'models/props_combine/combine_interface001.mdl'}
ENT.WallMount = true      -- a monitor hangs on the wall it is placed on
ENT.Powered = false       -- only the console works; the monitors show the red «no power» screen
ENT.Anim = {open = 'open', openIdle = 'open_idle', close = 'close', closeIdle = 'close_idle'}
ENT.W, ENT.H = 1024, 576  -- screen canvas (px)
ENT.ScreenWidth = 46      -- world units, for a model without a screen of its own
ENT.UseRange = 120
ENT.OpenRange = 170       -- opens when someone comes this close

function ENT:SetupDataTables()
	self:NetworkVar('Bool', 0, 'Open')
	self:NetworkVar('Float', 0, 'OpenedAt')
end

function ENT:PickModel()
	for _, m in ipairs(self.Models) do if file.Exists(m, 'GAME') then return m end end
	return self.Models[#self.Models]
end

-- the screen in the world: top-left corner, right, down, normal (toward the user), scale (units/px),
-- centre, canvas width (px; the height is always ENT.H, the width follows the shape of the screen).
-- From the corners of the model's screen (attachments screen_tl / tr / bl, or ENT.ScreenLocal —
-- the same corners in the entity's own coordinates).
function ENT:ScreenCorners()
	local tl, tr, bl = self:LookupAttachment('screen_tl'), self:LookupAttachment('screen_tr'), self:LookupAttachment('screen_bl')
	if tl and tl > 0 and tr > 0 and bl > 0 then
		local a, b, c = self:GetAttachment(tl), self:GetAttachment(tr), self:GetAttachment(bl)
		if a and b and c then return a.Pos, b.Pos, c.Pos end
	end
	local L = self.ScreenLocal
	if L then return self:LocalToWorld(L[1]), self:LocalToWorld(L[2]), self:LocalToWorld(L[3]) end
end

function ENT:Screen()
	local A, B, C = self:ScreenCorners()
	if A then
		local right, down = B - A, C - A
		local w, h = right:Length(), down:Length()
		if w > 1 and h > 1 then
			right:Normalize() down:Normalize()
			local normal = down:Cross(right)
			local cw = math.Clamp(math.floor(self.H * w / h), self.W, 1600)
			local scale = math.min(w / cw, h / self.H)
			local origin = A + right * ((w - cw * scale) / 2) + down * ((h - self.H * scale) / 2) + normal * 0.12
			local center = A + right * (w / 2) + down * (h / 2)
			return origin, right, down, normal, scale, center, cw
		end
	end
	local mn, mx = self:OBBMins(), self:OBBMaxs()
	local scale = self.ScreenWidth / self.W
	local sw, sh = self.ScreenWidth, self.H * scale
	local normal, right, down = self:GetForward(), -self:GetRight(), -self:GetUp()
	local center = self:LocalToWorld(Vector(mx.x - 2, (mn.y + mx.y) / 2, mx.z + sh / 2 + 3))
	return center - right * (sw / 2) - down * (sh / 2), right, down, normal, scale, center, self.W
end
