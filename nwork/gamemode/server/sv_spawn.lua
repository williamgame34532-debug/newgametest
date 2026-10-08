--[[-------------------------------------------------------------------------
	N-work — спавн (сервер).

	Пока игрок не выбрал/не создал персонажа, он заморожен и в god-режиме
	(экраны меню всё равно закрывают мир). После загрузки персонажа модель
	и скин переприменяются при каждом респавне.
---------------------------------------------------------------------------]]

function GM:PlayerSpawn( ply )
	self.BaseClass.PlayerSpawn( self, ply )

	local c = ply.NworkChar

	if c then
		ply:SetModel( c.model )
		ply:SetSkin( c.skin or 0 )
		ply:SetupHands()
	else
		ply:GodEnable()
		ply:Freeze( true )
	end
end
