NETWORK.immersive = NETWORK.immersive or {}

local enabled = CreateClientConVar("network_immersive", "0", true, false,
	"Камера от глаз персонажа")

local sway = CreateClientConVar("network_immersive_sway", "1", true, false,
	"Наследовать движение головы")

local offsetForward = CreateClientConVar("network_immersive_forward", "3",
	true, false, "Вынос камеры вперёд от кости головы")

local offsetHeight = CreateClientConVar("network_immersive_height", "2",
	true, false, "Высота камеры от кости головы")

local weapons = CreateClientConVar("network_immersive_weapons", "1", true,
	false, "Иммерсивная камера работает и с оружием")

local HEAD_BONES = {
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_Head",
	"Bip01 Head",
	"head"
}

function NETWORK.immersive.IsEnabled()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or !client:Alive()) then
		return false
	end

	if (!client:HasCharacter() or client:InVehicle()) then
		return false
	end

	if (NETWORK.thirdperson and NETWORK.thirdperson.IsEnabled()) then
		return false
	end

	if (!weapons:GetBool()) then
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() != NETWORK.weapon.hands) then
			return false
		end
	end

	return true
end

function NETWORK.immersive.GetHeadBone(client)
	for _, name in ipairs(HEAD_BONES) do
		local bone = client:LookupBone(name)

		if (bone) then
			return bone
		end
	end
end

local blend = 0

function NETWORK.immersive.GetBlend()
	return blend
end

function NETWORK.immersive.IsBodyShown()
	return blend > 0.5
end

NETWORK.view.Register("immersive", 25, function(client, view)
	local bActive = NETWORK.immersive.IsEnabled()

	blend = NETWORK.util.Approach(blend, bActive and 1 or 0, 6)

	if (blend < 0.004) then
		return
	end

	local bone = NETWORK.immersive.GetHeadBone(client)

	if (!bone) then
		return
	end

	local position, angles = client:GetBonePosition(bone)

	if (!position or position == client:GetPos()) then

		return
	end

	local eyes = client:EyeAngles()

	if (!sway:GetBool()) then
		position = LerpVector(0.5, position, client:EyePos())
	end

	local target = position + eyes:Forward() *
		math.Clamp(offsetForward:GetFloat(), 0, 12) +
		vector_up * math.Clamp(offsetHeight:GetFloat(), -6, 10)

	view.origin = LerpVector(NETWORK.util.EaseInOut(blend), client:EyePos(),
		target)
	view.angles = eyes

	view.drawviewer = NETWORK.immersive.IsBodyShown()

	return true
end)

hook.Add("PreDrawViewModel", "nwImmersive", function()
	if (NETWORK.immersive.IsBodyShown()) then
		return true
	end
end)

hook.Add("HUDShouldDraw", "nwImmersive", function(name)
	if (name == "CHudCrosshair" and NETWORK.immersive.IsBodyShown()) then
		return false
	end
end)

local bHidden = false

hook.Add("PrePlayerDraw", "nwImmersiveHead", function(client)
	if (client != LocalPlayer() or !NETWORK.immersive.IsBodyShown()) then
		return
	end

	local bone = NETWORK.immersive.GetHeadBone(client)

	if (!bone) then
		return
	end

	client:ManipulateBoneScale(bone, vector_origin)

	bHidden = true
end)

hook.Add("Think", "nwImmersiveRestore", function()
	if (!bHidden or NETWORK.immersive.IsBodyShown()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local bone = NETWORK.immersive.GetHeadBone(client)

	if (bone) then
		client:ManipulateBoneScale(bone, Vector(1, 1, 1))
	end

	bHidden = false
end)

hook.Add("NetworkShouldDrawLegs", "nwImmersive", function()

	if (NETWORK.immersive.GetBlend() > 0.004) then
		return false
	end
end)

hook.Add("ShouldDrawLocalPlayer", "nwImmersive", function()
	if (NETWORK.immersive.IsBodyShown()) then
		return true
	end
end)
