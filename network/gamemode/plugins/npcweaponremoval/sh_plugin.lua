PLUGIN.name = "NPC Weapon Removal"
PLUGIN.author = "Theis"
PLUGIN.description = "Убирает оружие NPC и выпадение аптечек после их смерти."
PLUGIN.version = "1.1"

-- SF_NPC_DROP_HEALTHKIT и SF_NPC_NO_WEAPON_DROP из Source SDK.
local SF_DROP_HEALTHKIT = 8
local SF_NO_WEAPON_DROP = 8192

NETWORK.config.RegisterCategory("npcs", "NPC", 60)

NETWORK.config.Register("npcWeaponRemoval", {
	name = "Убирать оружие NPC",
	description = "Оружие и аптечки NPC не выпадают после их смерти.",
	category = "npcs",
	type = "bool",
	default = true
})

local function Enabled()
	return NETWORK.config.Get("npcWeaponRemoval") != false
end

if (SERVER) then
	local function StripFlags(npc)
		if (!IsValid(npc) or !npc:IsNPC()) then
			return
		end

		local flags = npc:GetSpawnFlags()
		local stripped = bit.bor(bit.band(flags, bit.bnot(SF_DROP_HEALTHKIT)), SF_NO_WEAPON_DROP)

		if (stripped != flags) then
			npc:SetKeyValue("spawnflags", tostring(stripped))
		end
	end

	-- Флаги ставятся сразу после появления NPC: так движок не создаст аптечку
	-- и не бросит оружие, даже если OnNPCKilled сработает слишком поздно.
	function PLUGIN:OnEntityCreated(entity)
		if (!Enabled()) then
			return
		end

		timer.Simple(0, function()
			StripFlags(entity)
		end)
	end

	function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
		if (!Enabled() or !IsValid(npc)) then
			return
		end

		local weapon = npc:GetActiveWeapon()

		if (IsValid(weapon)) then
			weapon:Remove()
		end

		StripFlags(npc)
	end
end
