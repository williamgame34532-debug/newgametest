NETWORK.restraint = NETWORK.restraint or {}

NETWORK.restraint.range = 110
NETWORK.restraint.tieTime = 3
NETWORK.restraint.leadRange = 96

function NETWORK.restraint.IsTied(client)
	return IsValid(client) and client:GetNWBool("nwTied", false)
end

function NETWORK.restraint.GetLeader(client)
	return IsValid(client) and client:GetNWEntity("nwLeader", NULL) or NULL
end

function NETWORK.restraint.IsLed(client)
	return IsValid(NETWORK.restraint.GetLeader(client))
end

function NETWORK.restraint.CanAct(client)
	return !NETWORK.restraint.IsTied(client)
end

local function Usable(path)
	return (file.Size(path, "GAME") or 0) > 0
end

NETWORK.restraint.Usable = Usable

function NETWORK.restraint.Model(path, fallback)
	return Usable(path) and path or fallback
end

function NETWORK.restraint.Sound(path, fallback)
	return Usable("sound/" .. path) and path or fallback
end

NETWORK.restraint.cuffItemModel = NETWORK.restraint.Model(
	"models/chara/simplehandcuffs/handcuffs.mdl", "models/maxofs2d/hover_rings.mdl")

NETWORK.restraint.cuffPose = {
	["ValveBiped.Bip01_L_UpperArm"] = Angle(20, 8.8, 0),
	["ValveBiped.Bip01_L_Forearm"] = Angle(15, 0, 0),
	["ValveBiped.Bip01_L_Hand"] = Angle(0, 0, 75),
	["ValveBiped.Bip01_R_UpperArm"] = Angle(-20, 16.6, 0),
	["ValveBiped.Bip01_R_Forearm"] = Angle(-15, 0, 0),
	["ValveBiped.Bip01_R_Hand"] = Angle(0, 0, -75)
}
