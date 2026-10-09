--[[-------------------------------------------------------------------------
	N-work — персонаж: общие функции и методы игрока.

	Данные активного персонажа передаются клиентам через NW-переменные:
		nwork_charid   id в базе (0 — нет персонажа или бот)
		nwork_name     имя персонажа
		nwork_faction  id фракции
		nwork_desc     описание (видно другим)

	На сервере полная запись лежит в ply.NworkChar (см. sv_character.lua).
---------------------------------------------------------------------------]]

NWORK.Character = NWORK.Character or {}

local PLAYER = FindMetaTable( "Player" )

function PLAYER:HasCharacter()
	return self:GetNWString( "nwork_name", "" ) ~= ""
end

function PLAYER:GetCharID()
	return self:GetNWInt( "nwork_charid", 0 )
end

function PLAYER:GetCharName()
	local n = self:GetNWString( "nwork_name", "" )
	return n ~= "" and n or self:Nick()
end

function PLAYER:GetCharDesc()
	return self:GetNWString( "nwork_desc", "" )
end

function PLAYER:GetFaction()
	return self:GetNWString( "nwork_faction", NWORK.Config.CreateFaction )
end

function PLAYER:GetFactionTable()
	return NWORK.Factions[ self:GetFaction() ]
end

----------------------------------------------------------------- знакомства

-- На клиенте: id персонажей, которых знает локальный игрок
NWORK.Recognized = NWORK.Recognized or {}

-- Знает ли локальный игрок этого персонажа (на сервере всегда да)
function NWORK.Character.Knows( ply )
	if SERVER then return true end
	if not IsValid( ply ) then return false end
	if ply == LocalPlayer() or ply:IsBot() then return true end

	local id = ply:GetCharID()
	if id == 0 then return true end

	if hook.Run( "NworkCanRecognize", ply ) == true then return true end

	return NWORK.Recognized[ id ] == true
end

-- Имя, которое видит локальный игрок: настоящее или «Неизвестный»
function NWORK.CharName( ply )
	if not IsValid( ply ) then return "Консоль" end
	if not ply:HasCharacter() then return ply:Nick() end
	if NWORK.Character.Knows( ply ) then return ply:GetCharName() end
	return "Неизвестный"
end
