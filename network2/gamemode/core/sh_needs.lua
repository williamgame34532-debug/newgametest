-- Needs of a character, networked: hunger and thirst (100 = full, 0 = starving / parched, saved
-- with the character) and stamina (100 = rested; running and jumping spend it). Server side:
-- sv_needs.lua; the inventory shows hunger and thirst, the HUD shows stamina.

NW.needs = NW.needs or {}

local meta = FindMetaTable("Player")

function meta:GetHunger()
	return self:GetNW2Float("nwHunger", 100)
end

function meta:GetThirst()
	return self:GetNW2Float("nwThirst", 100)
end

function meta:GetStamina()
	return self:GetNW2Float("nwStamina", 100)
end

function meta:IsExhausted()
	return self:GetNW2Bool("nwExhausted", false)
end
