--[[-------------------------------------------------------------------------
	N-work — предмет в мире.
---------------------------------------------------------------------------]]

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Предмет"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "ItemID" )
	self:NetworkVar( "Int", 0, "Amount" )
end

if SERVER then

	function ENT:Initialize()
		local def = NWORK.Items[ self:GetItemID() ]

		self:SetModel( def and def.Model or "models/props_junk/cardboard_box001a.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )

		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() end
	end

	-- прямое E тоже подбирает (клиент обычно перехватывает и показывает кнопку)
	function ENT:Use( activator )
		if IsValid( activator ) and activator:IsPlayer() then
			NWORK.PickupItem( activator, self )
		end
	end

end
