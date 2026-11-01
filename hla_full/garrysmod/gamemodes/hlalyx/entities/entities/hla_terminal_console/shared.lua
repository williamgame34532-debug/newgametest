-- The working Combine terminal: the HL:A console vr_combine_interface_01. It stays folded
-- (closed_idle); the interface is on its screen at the top of the panel (see hla_terminal).
ENT.Type = 'anim'
ENT.Base = 'hla_terminal'
ENT.PrintName = 'Терминал Альянса (консоль)'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Models = {'models/hla/terminal/vr_combine_interface_01.mdl', 'models/props_combine/combine_interface001.mdl'}
ENT.WallMount = false
ENT.Powered = true
ENT.Anim = {closeIdle = 'closed_idle'}
ENT.Static = true -- no open / close animation, only the screen lights up
-- the screen of vr_combine_interface_01 in closed_idle (corners: top-left, top-right, bottom-left;
-- entity coordinates; the attachments screen_tl / tr / bl after a recompile give the same)
ENT.ScreenLocal = {Vector(8.37, 11.91, 47.60), Vector(-10.28, 11.92, 47.61), Vector(8.37, 17.42, 42.56)}
ENT.UseRange = 110
