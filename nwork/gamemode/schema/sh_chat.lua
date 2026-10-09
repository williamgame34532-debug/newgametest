--[[-------------------------------------------------------------------------
	N-work — чат схемы: рация.

	/r — рация. Пишут только фракции с Radio = true или игроки с
	предметом «Рация». Слышат все, у кого тоже есть рация; стоящие рядом
	слышат говорящего обычной речью.
---------------------------------------------------------------------------]]

local CH = NWORK.Chat
local C  = CH.Colors

local function HasRadio( ply )
	local f = ply:GetFactionTable()
	if f and f.Radio then return true end
	if SERVER then return NWORK.Inventory.Has( ply, "radio" ) end
	return NWORK.Inventory.Count( NWORK.LocalInv, "radio" ) > 0
end

NWORK.HasRadio = HasRadio

CH.Register( "r", {
	Prefix = { "/r", "/radio" },
	Font   = "Nwork.ChatRadio",
	Desc   = "Передать сообщение по рации.",
	Overhead = true,
	CanSay = function( ply ) return HasRadio( ply ) end,
	CanHear = function( speaker, listener )
		return listener == speaker or HasRadio( listener )
			or listener:GetPos():DistToSqr( speaker:GetPos() ) <= 320 * 320
	end,
	Format = function( _, text, name )
		return C.Radio, name .. " передаёт по рации \"<:: " .. text .. " ::>\""
	end,
	OverheadText = function( _, text ) return "<:: " .. text .. " ::>" end,
} )
