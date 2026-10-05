NETWORK.currency = NETWORK.currency or {}

NETWORK.currency.name = "currencyTokens"
NETWORK.currency.short = "currencyShort"

local PLAYER = FindMetaTable("Player")

function PLAYER:GetTokens()
	return self:GetNWInt("nwTokens", 0)
end

function NETWORK.currency.Format(amount)
	return tostring(math.Round(amount or 0)) .. " " .. L(NETWORK.currency.short)
end
