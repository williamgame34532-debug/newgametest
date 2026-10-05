NETWORK.loyalty = NETWORK.loyalty or {}

NETWORK.loyalty.min = -100
NETWORK.loyalty.max = 100
NETWORK.loyalty.default = 0

NETWORK.loyalty.bands = {
	{minimum = 60, label = "loyaltyExemplary", color = Color(96, 212, 120)},
	{minimum = 20, label = "loyaltyGood", color = Color(126, 200, 240)},
	{minimum = -19, label = "loyaltyNeutral", color = Color(200, 208, 216)},
	{minimum = -59, label = "loyaltyPoor", color = Color(238, 152, 70)},
	{minimum = -100, label = "loyaltyHostile", color = Color(238, 88, 78)}
}

local PLAYER = FindMetaTable("Player")

function PLAYER:GetLoyalty()
	local value = SERVER and (self.nwLoyalty or NETWORK.loyalty.default) or
		self:GetNWInt("nwLoyalty", NETWORK.loyalty.default)

	return math.Clamp(math.Round(value), NETWORK.loyalty.min,
		NETWORK.loyalty.max)
end

function NETWORK.loyalty.GetBand(value)
	for _, band in ipairs(NETWORK.loyalty.bands) do
		if (value >= band.minimum) then
			return band
		end
	end

	return NETWORK.loyalty.bands[#NETWORK.loyalty.bands]
end

if (SERVER) then

	NETWORK.loyalty.stored = NETWORK.loyalty.stored or {}

	local loyaltyPath = "network/loyalty.txt"

	function NETWORK.loyalty.Load()
		local raw = file.Read(loyaltyPath, "DATA")

		NETWORK.loyalty.stored = raw and util.JSONToTable(raw) or {}
	end

	function NETWORK.loyalty.Save()
		file.CreateDir("network")
		file.Write(loyaltyPath, util.TableToJSON(NETWORK.loyalty.stored, true))
	end

	hook.Add("Initialize", "nwLoyaltyStore", NETWORK.loyalty.Load)
	hook.Add("ShutDown", "nwLoyaltyStore", NETWORK.loyalty.Save)

	function NETWORK.loyalty.Set(client, value, bNoStore)
		client.nwLoyalty = math.Clamp(math.Round(value), NETWORK.loyalty.min,
			NETWORK.loyalty.max)

		client:SetNWInt("nwLoyalty", client.nwLoyalty)

		local character = client.GetCharacter and client:GetCharacter()

		if (character and !bNoStore) then
			NETWORK.loyalty.stored[tostring(character:GetID())] = client.nwLoyalty

			timer.Create("nwLoyaltySave", 3, 1, NETWORK.loyalty.Save)
		end
	end

	hook.Add("NetworkCharacterLoaded", "nwLoyaltyStore", function(client, character)

		timer.Simple(0.6, function()
			if (!IsValid(client) or client:GetCharacter() != character) then
				return
			end

			local stored = NETWORK.loyalty.stored[tostring(character:GetID())]

			if (stored != nil) then
				NETWORK.loyalty.Set(client, tonumber(stored) or NETWORK.loyalty.default, true)
			end
		end)
	end)

	local function AdminNotice(client, key, ...)
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L(key, ...))
		net.Send(client)
	end

	NETWORK.command.Register("setloyalty", {
		adminOnly = true,
		description = "cmdSetloyalty",
		usage = "/setloyalty <игрок> <-100..100>",
		aliases = {"givelo", "setol"},
		OnRun = function(command, client, arguments)
			local target = NETWORK.permission.Find(arguments[1])

			if (!IsValid(target) or !target:HasCharacter()) then
				return AdminNotice(client, "permNoTarget")
			end

			local value = tonumber(arguments[2])

			if (!value) then
				return AdminNotice(client, "cmdSetloyalty")
			end

			local before = target:GetLoyalty()

			NETWORK.loyalty.Set(target, value)
			hook.Run("NetworkLoyaltyChanged", target, target:GetLoyalty(), before,
				client:GetCharacterName())

			AdminNotice(client, "loyaltySetTo", target:GetCharacterName(), target:GetLoyalty())
		end
	})

	NETWORK.command.Register("addloyalty", {
		adminOnly = true,
		description = "cmdAddloyalty",
		usage = "/addloyalty <игрок> <число>",
		aliases = {"addol"},
		OnRun = function(command, client, arguments)
			local target = NETWORK.permission.Find(arguments[1])

			if (!IsValid(target) or !target:HasCharacter()) then
				return AdminNotice(client, "permNoTarget")
			end

			local amount = math.Round(tonumber(arguments[2]) or 0)

			if (amount == 0) then
				return AdminNotice(client, "cmdAddloyalty")
			end

			NETWORK.loyalty.Add(target, amount, client:GetCharacterName())

			AdminNotice(client, "loyaltySetTo", target:GetCharacterName(), target:GetLoyalty())
		end
	})

	function NETWORK.loyalty.Add(client, amount, reason)
		local before = client:GetLoyalty()

		NETWORK.loyalty.Set(client, before + amount)

		local after = client:GetLoyalty()

		if (after == before) then
			return
		end

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L(after > before and "loyaltyUp" or "loyaltyDown"))
		net.Send(client)

		hook.Run("NetworkLoyaltyChanged", client, after, before, reason)
	end

	NETWORK.command.Register("loyalty", {
		description = "cmdLoyalty",
		usage = "/loyalty <игрок> <число>",
		OnRun = function(command, client, arguments)
			local function Notice(key, ...)
				net.Start("nwChatMessage")
					net.WriteString("notice")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString(L(key, ...))
				net.Send(client)
			end

			if (!NETWORK.factions.IsAlliance(client) and !client:IsAdmin()) then
				return Notice("owNoAccess")
			end

			local target = NETWORK.permission.Find(arguments[1])

			if (!IsValid(target) or !target:HasCharacter()) then
				return Notice("permNoTarget")
			end

			local amount = math.Clamp(math.Round(tonumber(arguments[2]) or 0), -50, 50)

			if (amount == 0) then
				return Notice("cmdLoyalty")
			end

			NETWORK.loyalty.Add(target, amount, client:GetCharacterName())

			Notice("adminDone")
		end
	})
end
