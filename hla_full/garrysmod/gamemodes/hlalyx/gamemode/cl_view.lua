-- First person from the eyes of the character model. The camera sits at the model's «eyes»
-- attachment and follows the body (crouch, lean, the sway of the animations); the view model
-- (weapon, hands) moves with it. The legs are seen when looking down (below).
-- hla_body_view 0 = the usual camera.
local cv = CreateClientConVar('hla_body_view', '1', true, false, 'First person body view (0/1)')


local function active(p)
	return cv:GetBool() and IsValid(p) and p:Alive() and not p:InVehicle() and p:GetViewEntity() == p
		and p:GetObserverMode() == OBS_MODE_NONE and not p:GetNWBool('hla_in_menu')
end

-- Legs (as the Helix «Legs» plugin by Valkyrie & blackops7799, public domain): a copy of the player's
-- model plays the player's own sequence (advanced by FrameAdvance at the speed of the walk), takes
-- the pose parameters, has the head, arms and the upper spine folded away, and is drawn 22 units
-- behind the player, cut at the eye height, so only the legs and the hips are seen when looking down.
local REMOVE = {'ValveBiped.Bip01_Head1', 'ValveBiped.Bip01_Spine4', 'ValveBiped.Bip01_Spine2',
	'ValveBiped.Bip01_L_Clavicle', 'ValveBiped.Bip01_L_UpperArm', 'ValveBiped.Bip01_L_Upperarm', 'ValveBiped.Bip01_L_Forearm', 'ValveBiped.Bip01_L_Hand',
	'ValveBiped.Bip01_R_Clavicle', 'ValveBiped.Bip01_R_UpperArm', 'ValveBiped.Bip01_R_Upperarm', 'ValveBiped.Bip01_R_Forearm', 'ValveBiped.Bip01_R_Hand'}
local Legs = {}

local function fixBones(e)
	for i = 0, e:GetBoneCount() - 1 do
		e:ManipulateBoneScale(i, Vector(1, 1, 1))
		e:ManipulateBonePosition(i, vector_origin)
	end
	local list = {}
	for _, n in ipairs(REMOVE) do list[n] = true end
	for i = 0, e:GetBoneCount() - 1 do
		local n = e:GetBoneName(i) or ''
		if list[n] or string.find(n, 'Finger', 1, true) then
			e:ManipulateBoneScale(i, vector_origin)
			e:ManipulateBonePosition(i, Vector(0, -100, 0))
			e:ManipulateBoneAngles(i, angle_zero)
		end
	end
end

local function setup(p)
	local mdl = p:GetModel()
	if not IsValid(Legs.ent) then
		Legs.ent = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
		if not IsValid(Legs.ent) then return end
	elseif Legs.ent:GetModel() ~= mdl then
		Legs.ent:SetModel(mdl)
	end
	local e = Legs.ent
	e:SetNoDraw(true)
	for _, g in ipairs(p:GetBodyGroups() or {}) do e:SetBodygroup(g.id, p:GetBodygroup(g.id)) end
	for k in ipairs(p:GetMaterials() or {}) do e:SetSubMaterial(k - 1, p:GetSubMaterial(k - 1)) end
	e:SetSkin(p:GetSkin())
	e:SetMaterial(p:GetMaterial())
	e.GetPlayerColor = function() return IsValid(p) and p:GetPlayerColor() or Vector(1, 1, 1) end
	e.anim, e.lastTick = nil, CurTime()
	Legs.model, Legs.skin = mdl, p:GetSkin()
	fixBones(e)
end

local function update(p, maxSpeed)
	local e = Legs.ent
	local vel = p:GetVelocity():Length2D()
	local rate = 1
	if vel > 0.5 then rate = maxSpeed < 0.001 and 0.01 or math.Clamp(vel / maxSpeed, 0.01, 10) end
	e:SetPlaybackRate(rate)
	local seq = p:GetSequence()
	if e.anim ~= seq then e.anim = seq e:ResetSequence(seq) end
	e:FrameAdvance(CurTime() - (e.lastTick or CurTime()))
	e.lastTick = CurTime()
	-- pose parameters: on the client a player's read back as 0..1, the copy takes the model's range
	for i = 0, p:GetNumPoseParameters() - 1 do
		local name = p:GetPoseParameterName(i)
		local mn, mx = p:GetPoseParameterRange(i)
		if name and mn then e:SetPoseParameter(name, math.Remap(p:GetPoseParameter(name), 0, 1, mn, mx)) end
	end
end

-- every frame (the units' UpdateAnimation hook ends the chain, so the legs follow from Think, with
-- the ground speed of the player's current sequence as the plugin gets it from UpdateAnimation)
hook.Add('Think', 'HLALegs', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	if not IsValid(Legs.ent) or Legs.model ~= p:GetModel() or Legs.skin ~= p:GetSkin() then setup(p) end
	if IsValid(Legs.ent) then update(p, p:GetSequenceGroundSpeed(p:GetSequence()) or 0) end
end)

hook.Add('PlayerSwitchWeapon', 'HLALegs', function(p)
	if p == LocalPlayer() and IsValid(Legs.ent) then timer.Simple(0, function() if IsValid(Legs.ent) then fixBones(Legs.ent) end end) end
end)

local function shouldDraw(p)
	return active(p) and IsValid(Legs.ent) and not p:ShouldDrawLocalPlayer() and not p:GetNoDraw()
		and not IsValid(p:GetObserverTarget())
		and not (HLA.TerminalFocus and HLA.TerminalFocus.blend > 0)
		and not (HLA.Tab and HLA.Tab.fade and HLA.Tab.fade > 0)
end

local CLIP = Vector(0, 0, -1)
hook.Add('PostDrawTranslucentRenderables', 'HLALegs', function(depth, sky)
	if depth or sky then return end
	local p = LocalPlayer()
	if not IsValid(p) or not shouldDraw(p) then return end
	local e = Legs.ent
	local yaw = p:EyeAngles().y
	local pos = p:GetPos()
	local r = math.rad(yaw)
	pos.x = pos.x + math.cos(r) * -22
	pos.y = pos.y + math.sin(r) * -22
	if p:GetGroundEntity() == NULL then
		pos.z = pos.z + 8
		if p:KeyDown(IN_DUCK) then pos.z = pos.z - 28 end
	end
	local col = p:GetColor()
	cam.Start3D(EyePos(), EyeAngles())
		local was = render.EnableClipping(true)
		render.PushCustomClipPlane(CLIP, CLIP:Dot(EyePos()))
			render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
			render.SetBlend(col.a / 255)
			e:SetRenderOrigin(pos)
			e:SetRenderAngles(Angle(0, yaw, 0))
			e:SetupBones()
			e:DrawModel()
			e:SetRenderOrigin()
			e:SetRenderAngles()
			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
		render.PopCustomClipPlane()
		render.EnableClipping(was)
	cam.End3D()
end)

-- offset of the eyes of the model from the player's eye point, smoothed
local offset, smooth = Vector(0, 0, 0), nil
local function eyeOffset(p, origin, angles)
	local att = p:LookupAttachment('eyes')
	local a = att and att > 0 and p:GetAttachment(att)
	if not a then return Vector(0, 0, 0) end
	local off = a.Pos + angles:Forward() * 3 - origin
	if off:LengthSqr() > 40 * 40 then return Vector(0, 0, 0) end
	-- the eye height itself is the model's (sv_game sets the view offset from it); here only the sway
	-- of the animations is followed, so shots still go where the crosshair is
	off.z = math.Clamp(off.z, -5, 5)
	local flat = Vector(off.x, off.y, 0)
	if flat:LengthSqr() > 10 * 10 then flat = flat:GetNormalized() * 10 off.x, off.y = flat.x, flat.y end
	smooth = smooth and LerpVector(math.min(1, FrameTime() * 22), smooth, off) or off
	return smooth
end

function GM:CalcView(p, origin, angles, fov, znear, zfar)
	local view = self.BaseClass.CalcView(self, p, origin, angles, fov, znear, zfar) or {origin = origin, angles = angles, fov = fov}
	if not active(p) or p:ShouldDrawLocalPlayer() then smooth = nil offset = Vector(0, 0, 0) HLA.ViewOffset = nil return view end
	offset = eyeOffset(p, origin, angles)
	view.origin = (view.origin or origin) + offset
	HLA.ViewOffset = offset
	view.znear = 2
	return view
end

-- the weapon / hands follow the camera
function GM:CalcViewModelView(wep, vm, oldPos, oldAng, pos, ang)
	local p, a = self.BaseClass.CalcViewModelView(self, wep, vm, oldPos, oldAng, pos, ang)
	p, a = p or pos, a or ang
	if active(LocalPlayer()) then p = p + offset end
	return p, a
end
