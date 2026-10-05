-- Purchasable apartments: a citizen pays at the civic terminal, an administrator assigns the door,
-- ownership survives reconnects/restarts. In exchange the owner pays a tax on every budget payday
-- and the address is registered in the CID database (Civil Protection can mark it on the map).
NETWORK.apartments = NETWORK.apartments or {}

local A = NETWORK.apartments

A.price = 1500       -- purchase price in tokens (taken from the bank account first, then cash)
A.tax = 15           -- tax per budget payday (NETWORK.budget.interval, 15 minutes by default)
A.seizeAfter = 0     -- seize after this many unpaid paydays in a row; 0 = never seize automatically
A.capacity = 3       -- residents per apartment for the terminal's free housing

NETWORK.door.housingCapacity = A.capacity

function A.IsPurchased(data)
	return istable(data) and istable(data.purchase) and data.purchase.char != nil
end

function A.IsBuyer(data, steamID)
	return A.IsPurchased(data) and data.purchase.steamID == steamID
end
