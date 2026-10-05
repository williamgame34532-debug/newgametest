local ghost
local pending

local function ClearGhost()
	if (IsValid(ghost)) then
		ghost:Remove()
	end

	ghost = nil
	pending = nil
end

function NETWORK.shop.IsPlacing()
	return pending != nil
end

local function GetSpot()
	local client = LocalPlayer()
	local trace = util.TraceLine({
		start = client:EyePos(),
		endpos = client:EyePos() + client:GetAimVector() * NETWORK.shop.range,
		filter = client
	})

	return trace.HitPos, trace.HitNormal
end

function NETWORK.shop.BeginPlacing(index, item)
	local base = NETWORK.item.Get(item.id)

	if (!base) then
		return
	end

	ClearGhost()

	pending = {index = index, id = item.id}

	ghost = ClientsideModel(base.model or
		"models/props_junk/cardboard_box004a.mdl", RENDERGROUP_TRANSLUCENT)

	if (!IsValid(ghost)) then
		pending = nil

		return
	end

	ghost:SetNoDraw(false)
	ghost:SetColor(Color(90, 240, 130, 170))
	ghost:SetRenderMode(RENDERMODE_TRANSALPHA)

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end

	NETWORK.chat.Notify(L("shopPlaceHint"))
end

hook.Add("Think", "nwShopGhost", function()
	if (!pending or !IsValid(ghost)) then
		return
	end

	local position, normal = GetSpot()

	ghost:SetPos(position + normal * 2)
	ghost:SetAngles(Angle(0, LocalPlayer():EyeAngles().y + 180, 0))
end)

hook.Add("PlayerBindPress", "nwShopPlace", function(client, bind, bPressed)
	if (!pending or !bPressed) then
		return
	end

	bind = string.lower(bind)

	if (string.find(bind, "attack2")) then
		ClearGhost()

		return true
	end

	if (!string.find(bind, "attack")) then
		return
	end

	local position, normal = GetSpot()
	local angles = Angle(0, LocalPlayer():EyeAngles().y + 180, 0)
	local index = pending.index

	ClearGhost()

	Derma_StringRequest(L("shopPriceTitle"), L("shopPriceHint"), "10",
		function(text)
			local price = math.Clamp(math.Round(tonumber(text) or 0), 0,
				NETWORK.shop.maxPrice)

			net.Start("nwShopPlace")
				net.WriteUInt(index, 8)
				net.WriteVector(position + normal * 2)
				net.WriteAngle(angles)
				net.WriteUInt(price, 16)
			net.SendToServer()
		end)

	return true
end)

hook.Add("OnPlayerChat", "nwShopPlace", function()
	ClearGhost()
end)
