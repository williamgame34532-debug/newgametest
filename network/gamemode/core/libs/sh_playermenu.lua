NETWORK.pmenu = NETWORK.pmenu or {}

local P = NETWORK.pmenu

P.range = 110
P.holdTime = 0.45
P.pulseTime = 3
P.tokenMax = 5000
P.tokenQuick = {5, 10, 25, 50, 100}
P.introTime = 12

P.lendMinutes = 30
P.lendMinutesMax = 180

P.options = {
	tokens = {label = "pmOptTokens", glyph = "coin", icon = "framework/interact/coins.png",
		iconOld = "framework/icons/paid.png"},
	recognise = {label = "pmOptRecognise", glyph = "person",
		icon = "framework/interact/handshake.png", iconOld = "framework/icons/visibility.png"},
	documents = {label = "pmOptDocuments", glyph = "list",
		icon = "framework/interact/id_card.png", iconOld = "framework/icons/assignment.png"},
	lendkey = {label = "pmOptLendkey", glyph = "split",
		icon = "framework/interact/house_keys.png", iconOld = "framework/icons/key.png"},
	search = {label = "pmOptSearch", glyph = "backpack",
		icon = "framework/interact/search.png", iconOld = "framework/icons/backpack.png"},
	lead = {label = "pmOptLead", glyph = "chevron", icon = "framework/interact/lead.png",
		iconOld = "framework/icons/directions_run.png"},
	release = {label = "pmOptRelease", glyph = "back", icon = "framework/interact/release.png",
		iconOld = "framework/icons/lock.png"},
	untie = {label = "pmOptUntie", glyph = "split", icon = "framework/interact/untie.png",
		iconOld = "framework/icons/key.png"},
	pulse = {label = "pmOptPulse", glyph = "pulse", icon = "framework/interact/pulse.png",
		iconOld = "framework/icons/favorite.png"},
	treat = {label = "pmOptTreat", glyph = "plus", icon = "framework/interact/treat.png",
		iconOld = "framework/icons/healing.png"},
	bodybag = {label = "pmOptBodybag", glyph = "stack", icon = "framework/interact/bodybag.png",
		iconOld = "framework/icons/masks.png", bClient = true}
}

function P.Resolve(entity)
	if (!IsValid(entity)) then
		return
	end

	if (entity:IsPlayer()) then
		return entity, "player"
	end

	if (entity:GetNWBool("nwCorpse", false)) then
		return entity, "corpse"
	end

	if (entity:IsRagdoll()) then
		local owner = entity:GetNWEntity("nwRagdollOwner", NULL)

		if (IsValid(owner) and owner:IsPlayer() and
			owner:GetNWEntity("nwRagdollEntity", NULL) == entity) then
			return owner, "player"
		end
	end
end

function P.GetTarget(client)
	if (!IsValid(client)) then
		return
	end

	local trace = client:GetEyeTrace()

	if (!trace.Hit or client:GetShootPos():Distance(trace.HitPos) > P.range) then
		return
	end

	local target, kind = P.Resolve(trace.Entity)

	if (!target or target == client) then
		return
	end

	if (kind == "player" and (!target:Alive() or !target:HasCharacter())) then
		return
	end

	return target, kind, trace.Entity
end

function P.IsHelpless(target)
	if (!IsValid(target) or !target:IsPlayer()) then
		return false
	end

	return NETWORK.restraint.IsTied(target) or target:IsDowned() or
		target:IsUnconscious()
end

function P.IsDocument(item)
	return istable(item) and (item.id == "document" or item.id == "idcard")
end
