ITEM.name = "Замок Альянса"
ITEM.description = "Магнитный навесной замок Гражданской Обороны. Наведитесь на дверь и используйте — замок встанет на створку."
ITEM.model = "models/props_c17/padlock001a.mdl"
ITEM.rarity = "special"
ITEM.weight = 0.8
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.bConsumeOnUse = true

function ITEM:OnUse(client)
	if (!NETWORK.factions.IsAlliance(client)) then
		NETWORK.chat.Notice(client, "lockNoAccess")

		return false
	end

	local trace = client:GetEyeTrace()
	local door = trace.Entity

	if (!IsValid(door) or !NETWORK.door.IsDoor(door) or
		trace.HitPos:Distance(client:GetShootPos()) > 96) then
		NETWORK.chat.Notice(client, "lockNoDoor")

		return false
	end

	if (IsValid(door.nwLock)) then
		NETWORK.chat.Notice(client, "lockAlready")

		return false
	end

	local lock = ents.Create("nw_lock")

	if (!IsValid(lock)) then
		return false
	end

	local normal = trace.HitNormal:Angle()
	local position, angles = lock.ComputeLockPosition(door, normal)

	lock:SetPos(trace.HitPos)
	lock:Spawn()
	lock:Activate()
	lock:Attach(door, position, angles)

	client:EmitSound("framework/cmb/lock/lock.mp3", 65)
end

if (CLIENT) then
	local ghost

	local function HasLock()

		local state = NETWORK.inventory.state or {}

		for _, list in ipairs({state.items, state.equipped, state.storage}) do
			for _, item in pairs(list or {}) do
				if (item.id == "cmblock") then
					return true
				end
			end
		end

		return false
	end

	hook.Add("PostDrawTranslucentRenderables", "nwLockPreview", function(_, skybox)
		if (skybox) then
			return
		end

		local client = LocalPlayer()

		if (!IsValid(client) or !client:Alive() or !client:HasCharacter() or
			!NETWORK.factions.IsAlliance(client)) then
			return
		end

		local trace = client:GetEyeTrace()
		local door = trace.Entity

		local bShow = IsValid(door) and NETWORK.door.IsDoor(door) and
			!IsValid(door.nwLock) and
			trace.HitPos:Distance(client:GetShootPos()) <= 96 and HasLock()

		if (!bShow) then
			if (IsValid(ghost)) then
				ghost:SetNoDraw(true)
			end

			return
		end

		if (!IsValid(ghost)) then

			local stored = scripted_ents.GetStored("nw_lock")
			local model = stored and stored.t and stored.t.GetLockModel and
				stored.t.GetLockModel() or "models/props_c17/padlock001a.mdl"

			ghost = ClientsideModel(model)

			if (!IsValid(ghost)) then
				return
			end

			ghost:SetRenderMode(RENDERMODE_TRANSCOLOR)
		end

		local compute = scripted_ents.GetStored("nw_lock")
		compute = compute and compute.t and compute.t.ComputeLockPosition

		if (!compute) then
			return
		end

		local position, angles = compute(door, trace.HitNormal:Angle())

		ghost:SetNoDraw(false)
		ghost:SetPos(position)
		ghost:SetAngles(angles)
		ghost:SetColor(Color(120, 200, 255,
			140 + math.sin(RealTime() * 5) * 50))
		ghost:DrawModel()
		ghost:SetNoDraw(true)
	end)
end
