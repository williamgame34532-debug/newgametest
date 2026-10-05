NETWORK.medcomp = NETWORK.medcomp or {}

local MC = NETWORK.medcomp

MC.medicClasses = {medic = true, doctor = true, nurse = true}

MC.recordLimit = 200
MC.noteMax = 400
MC.letterMax = 800

function MC.CanUse(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.factions.CanCheckDocuments and
		NETWORK.factions.CanCheckDocuments(client)) then
		return true
	end

	return MC.medicClasses[client:GetNWString("nwClass", "")] == true
end

NETWORK.mail = NETWORK.mail or {}

local MAIL = NETWORK.mail

MAIL.limit = 30

if (SERVER) then
	util.AddNetworkString("nwMedRecords")
	util.AddNetworkString("nwMedRecordSave")
	util.AddNetworkString("nwMedDocument")
	util.AddNetworkString("nwMailSend")
	util.AddNetworkString("nwMailList")
	util.AddNetworkString("nwMailOpen")
	util.AddNetworkString("nwMedOpen")
end
