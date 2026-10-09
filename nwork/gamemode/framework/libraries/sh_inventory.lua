--[[-------------------------------------------------------------------------
	N-work — инвентарь (общее и клиент).

	Инвентарь персонажа — список ячеек { id = "item", n = количество }.
	Одинаковые предметы складываются до Stack. Серверная часть —
	sv_inventory.lua; клиент получает копию в NWORK.LocalInv.
---------------------------------------------------------------------------]]

NWORK.Inventory = NWORK.Inventory or {}
local INV = NWORK.Inventory

function INV.Count( inv, id )
	local n = 0
	for _, e in ipairs( inv or {} ) do
		if e.id == id then n = n + e.n end
	end
	return n
end

if SERVER then return end

NWORK.LocalInv = NWORK.LocalInv or {}

net.Receive( "nwork_inv", function()
	local n = net.ReadUInt( 8 )
	local t = {}

	for i = 1, n do
		t[ i ] = { id = net.ReadString(), n = net.ReadUInt( 16 ) }
	end

	NWORK.LocalInv = t
	hook.Run( "NworkInventoryUpdated", t )
end )

-- Выполнить действие предмета в ячейке idx ("drop" или ключ из Actions)
function INV.Action( idx, action )
	net.Start( "nwork_item_action" )
		net.WriteUInt( idx, 8 )
		net.WriteString( action )
	net.SendToServer()
end
