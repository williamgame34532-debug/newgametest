NETWORK.documents = NETWORK.documents or {}

local D = NETWORK.documents

D.textMax = 600
D.titleMax = 60

D.types = {
	{id = "work", name = "docTypeWork", issuers = {alliance = true, cwu = true}, hours = 72},
	{id = "trade", name = "docTypeTrade", issuers = {alliance = true, cwu = true}, hours = 72},
	{id = "housing", name = "docTypeHousing", issuers = {alliance = true, cwu = true}, hours = 0},
	{id = "pass", name = "docTypePass", issuers = {alliance = true}, hours = 24},
	{id = "medical", name = "docTypeMedical", issuers = {alliance = true, cwu = true, medic = true}, hours = 48},
	{id = "warrant", name = "docTypeWarrant", issuers = {alliance = true}, hours = 12},
	{id = "summons", name = "docTypeSummons", issuers = {alliance = true}, hours = 24},
	{id = "note", name = "docTypeNote", issuers = {alliance = true, cwu = true}, hours = 0}
}

function D.GetType(id)
	for _, data in ipairs(D.types) do
		if (data.id == id) then
			return data
		end
	end
end

function D.GetTypesFor(kind)
	local list = {}

	for _, data in ipairs(D.types) do
		if (data.issuers[kind]) then
			list[#list + 1] = data
		end
	end

	return list
end

function D.BuildView(item)
	if (!istable(item)) then
		return
	end

	local data = item.data or {}

	if (item.id == "idcard") then
		local number = data.number

		if (isnumber(number)) then
			number = string.format("%05d", number % 100000)
		end

		return {
			kind = "idcard",
			title = "idCardTitle",
			holder = data.owner or "?",
			cid = tostring(number or "00000"),
			serial = data.serial or "",
			issuer = data.issuer or "",
			issued = data.issued or ""
		}
	end

	if (item.id == "document") then
		local docType = D.GetType(data.type)

		return {
			kind = "document",
			title = docType and docType.name or "docTypeNote",
			holder = data.holder or "?",
			cid = data.cid or "",
			serial = data.serial or "",
			issuer = data.issuer or "",
			issued = data.issued or "",
			expires = data.expires or "",
			text = data.text or ""
		}
	end
end
