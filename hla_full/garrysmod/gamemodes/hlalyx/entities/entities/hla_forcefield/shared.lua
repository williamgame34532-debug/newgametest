-- Combine force field: an energy wall between two emitter posts. It cannot be walked (or pushed)
-- through while on; E on the field turns it off and on. Spawned from Q → Entities → Half-Life: Alyx
-- (admins): it fits itself into the opening it is placed in.
-- With the HL:A emitters (models/props_combineal/combine_fence01a_128.mdl) the posts are separate
-- entities (hla_forcefield_post): move or turn either of them with the physgun and the field stretches
-- and turns between them. Without them the field draws HL2 fence emitters itself.
ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Силовое поле Альянса'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IsHLAForceField = true

ENT.UseRange = 110
ENT.Thick = 4 -- the field is 8 units thick (its layers and its solid box)

function ENT:SetupDataTables()
	self:NetworkVar('Bool', 0, 'On')
	self:NetworkVar('Float', 0, 'Width')
	self:NetworkVar('Float', 1, 'Height')
	self:NetworkVar('Float', 2, 'Switched')
	self:NetworkVar('Bool', 1, 'Posts')       -- HL:A emitter posts (separate entities)
	self:NetworkVar('Entity', 0, 'PostL')
	self:NetworkVar('Entity', 1, 'PostR')
	-- settings (the adjuster's menu): where the field starts and ends on the posts (0..1, 0 = default),
	-- and which material it shows (0 auto, 1 comshieldwall3, 2 HL:A bake, 3 HL2 shield)
	self:NetworkVar('Float', 3, 'BottomF')
	self:NetworkVar('Float', 4, 'TopF')
	self:NetworkVar('Int', 0, 'Mat')
end

function ENT:FieldFracs()
	local b, t = self:GetBottomF(), self:GetTopF()
	return (b > 0 and b or self.FieldBottom), (t > 0 and t or self.FieldTop)
end

-- the HL:A emitter combine_fence01a_128 as compiled in the «Half-Life: Alyx - Combine Animated Prop's
-- Pack» (models/props_combineal): the left post as it is, the right one the same model turned 180°
-- (like ix_forcefield does with the HL2 fence posts). In that model the origin is in the middle of
-- the height; the inner edge of the post (where the field starts) at the floor is PostInner.
ENT.PostModel = 'models/props_combineal/combine_fence01a_128.mdl'
ENT.PostModels = {ENT.PostModel, ENT.PostModel}
ENT.PostInner = Vector(-0.66, 7.13, -73.8)
ENT.PostWidth = 23.18   -- an emitter post is this wide
ENT.PostHeight = 127.55 -- and this high at its own size
ENT.MinHeight, ENT.MaxHeight = 128, 192 -- height of the posts
ENT.DefaultHeight = 160 -- posts of a new field in a high opening (1.25 x their own size)
ENT.FieldTop = 0.85     -- the field ends a little below the tops of the posts, as in HL:A ...
ENT.FieldBottom = 0.03  -- ... and starts just above the floor

-- the field itself: across local Y (left post at -Y, right post at +Y), facing local X
function ENT:Box()
	local w, h = self:GetWidth(), self:GetHeight()
	return Vector(-self.Thick, -w / 2, 0), Vector(self.Thick, w / 2, h)
end
ENT.FieldBox = ENT.Box

-- first existing file of a list (sound/… or materials/…)
local cache = {}
function ENT.Pick(list, prefix)
	local key = prefix .. table.concat(list, '|')
	if cache[key] ~= nil then return cache[key] or nil end
	for _, f in ipairs(list) do
		if file.Exists(prefix .. f, 'GAME') then cache[key] = f return f end
	end
	cache[key] = false
end

ENT.Sounds = {
	loop = {'hla/forcefield/forcefield_citizen_lp_01.wav', 'ambient/machines/combine_shield_loop3.wav', 'ambient/machines/machine6.wav'},
	hum = {'hla/forcefield/combine_prison_forcefield_deep_lp_01.wav'},
	start = {'hla/forcefield/forcefield_citizen_start_01.wav', 'buttons/combine_button1.wav'},
	stop = {'hla/forcefield/forcefield_citizen_stop_01.wav', 'buttons/combine_button_locked.wav', 'buttons/combine_button2.wav'},
	touch = {
		{'hla/forcefield/quarantine_forcefield_impact_effect_01.wav', 'ambient/energy/zap1.wav'},
		{'hla/forcefield/quarantine_forcefield_impact_effect_02.wav', 'ambient/energy/zap2.wav'},
		{'hla/forcefield/quarantine_forcefield_impact_effect_03.wav', 'ambient/energy/zap3.wav'},
	},
}
function ENT:Sound(kind)
	local list = self.Sounds[kind]
	if kind == 'touch' then list = list[math.random(#list)] end
	return self.Pick(list, 'sound/')
end
