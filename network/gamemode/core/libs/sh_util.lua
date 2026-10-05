NETWORK.util = NETWORK.util or {}

function NETWORK.util.Length(text)
	if (!isstring(text)) then
		return 0
	end

	return utf8.len(text) or string.len(text)
end

function NETWORK.util.Sub(text, first, last)
	if (!isstring(text) or text == "") then
		return ""
	end

	local length = NETWORK.util.Length(text)

	first = math.floor(first or 1)
	last = math.floor(last or length)

	if (first < 0) then first = length + first + 1 end
	if (last < 0) then last = length + last + 1 end

	first = math.max(first, 1)
	last = math.min(last, length)

	if (first > last) then
		return ""
	end

	if (first == 1 and last == length) then
		return text
	end

	local result = {}
	local index = 0

	for _, code in utf8.codes(text) do
		index = index + 1

		if (index > last) then
			break
		end

		if (index >= first) then
			result[#result + 1] = utf8.char(code)
		end
	end

	return table.concat(result)
end

function NETWORK.util.FindLookedAt(client, range, filter)
	if (!IsValid(client)) then
		return
	end

	local start = client:GetShootPos()
	local forward = client:GetAimVector()

	local trace = util.TraceLine({
		start = start,
		endpos = start + forward * range,
		filter = client
	})

	if (IsValid(trace.Entity) and filter(trace.Entity)) then
		return trace.Entity, trace.HitPos
	end

	local hull = util.TraceHull({
		start = start,
		endpos = start + forward * range,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		filter = client
	})

	if (IsValid(hull.Entity) and filter(hull.Entity)) then
		return hull.Entity, hull.HitPos
	end

	local best, bestDot

	for _, entity in ipairs(ents.FindInSphere(start, range)) do
		if (entity == client or !filter(entity)) then
			continue
		end

		local direction = entity:WorldSpaceCenter() - start
		local distance = direction:Length()

		direction:Normalize()

		local dot = direction:Dot(forward)

		if (dot < 0.97) then
			continue
		end

		if (!bestDot or dot > bestDot) then
			best = entity
			bestDot = dot
		end
	end

	if (IsValid(best)) then
		return best, best:WorldSpaceCenter()
	end
end

function NETWORK.util.Truncate(text, maximum, suffix)
	if (!isstring(text) or text == "") then
		return ""
	end

	if (NETWORK.util.Length(text) <= maximum) then
		return text
	end

	return NETWORK.util.Sub(text, 1, maximum) .. (suffix or "...")
end

local upperMap = {
	["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё",
	["ж"] = "Ж", ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М",
	["н"] = "Н", ["о"] = "О", ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т", ["у"] = "У",
	["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц", ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ",
	["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я"
}

local lowerMap = {}

for lower, upper in pairs(upperMap) do
	lowerMap[upper] = lower
end

local upperCache = {}

function NETWORK.util.Upper(text)
	if (!isstring(text)) then
		return ""
	end

	local cached = upperCache[text]

	if (cached) then
		return cached
	end

	local result = ""

	for _, code in utf8.codes(text) do
		local char = utf8.char(code)

		result = result .. (upperMap[char] or string.upper(char))
	end

	upperCache[text] = result

	return result
end

function NETWORK.util.Lower(text)
	if (!isstring(text)) then
		return ""
	end

	local result = ""

	for _, code in utf8.codes(text) do
		local char = utf8.char(code)

		result = result .. (lowerMap[char] or string.lower(char))
	end

	return result
end

local throttles = {}

function NETWORK.util.Throttle(key, interval)
	local now = CurTime()

	if ((throttles[key] or 0) > now) then
		return false
	end

	throttles[key] = now + (interval or 0.25)

	return true
end

function NETWORK.util.Sanitise(text, maxLength, bMultiline)
	if (!isstring(text)) then
		return ""
	end

	text = string.gsub(text, "%z", "")
	text = string.gsub(text, "\r", "")

	if (bMultiline) then
		text = string.gsub(text, "\n\n\n+", "\n\n")
	else
		text = string.gsub(text, "[\n\t]", " ")
	end

	text = string.gsub(text, "  +", " ")
	text = string.Trim(text)

	if (maxLength and NETWORK.util.Length(text) > maxLength) then
		text = NETWORK.util.Sub(text, 1, maxLength)
	end

	return text
end

local nameRanges = {
	{0x0041, 0x005A},
	{0x0061, 0x007A},
	{0x0401, 0x0401},
	{0x0410, 0x044F},
	{0x0451, 0x0451}
}

local nameExtra = {
	[0x0020] = true,
	[0x002D] = true,
	[0x0027] = true
}

function NETWORK.util.IsName(text)
	if (!isstring(text) or text == "") then
		return false
	end

	for _, code in utf8.codes(text) do
		if (nameExtra[code]) then
			continue
		end

		local bValid = false

		for i = 1, #nameRanges do
			if (code >= nameRanges[i][1] and code <= nameRanges[i][2]) then
				bValid = true

				break
			end
		end

		if (!bValid) then
			return false
		end
	end

	return true
end

local TAG_NUMBER = "#n:"
local TAG_STRING = "#s:"

local function IsSequence(tbl)
	local count = #tbl

	if (count == 0) then
		return next(tbl) == nil
	end

	local seen = 0

	for key in pairs(tbl) do
		if (!isnumber(key) or key < 1 or key > count or key % 1 != 0) then
			return false
		end

		seen = seen + 1
	end

	return seen == count
end

function NETWORK.util.TagKeys(tbl, depth)
	if (!istable(tbl)) then
		return tbl
	end

	depth = depth or 0

	if (depth > 24) then
		return tbl
	end

	local copy = {}

	if (IsSequence(tbl)) then
		for index, value in ipairs(tbl) do
			copy[index] = istable(value) and NETWORK.util.TagKeys(value, depth + 1) or value
		end

		return copy
	end

	for key, value in pairs(tbl) do
		local tagged = key

		if (isnumber(key)) then
			tagged = TAG_NUMBER .. key
		elseif (isstring(key) and key:match("^%-?%d+%.?%d*$")) then
			tagged = TAG_STRING .. key
		end

		copy[tagged] = istable(value) and NETWORK.util.TagKeys(value, depth + 1) or value
	end

	return copy
end

function NETWORK.util.UntagKeys(tbl, depth)
	if (!istable(tbl)) then
		return tbl
	end

	depth = depth or 0

	if (depth > 24) then
		return tbl
	end

	local copy = {}

	for key, value in pairs(tbl) do
		local plain = key

		if (isstring(key)) then
			if (key:sub(1, 3) == TAG_NUMBER) then
				plain = tonumber(key:sub(4)) or key
			elseif (key:sub(1, 3) == TAG_STRING) then
				plain = key:sub(4)
			end
		end

		copy[plain] = istable(value) and NETWORK.util.UntagKeys(value, depth + 1) or value
	end

	return copy
end

function NETWORK.util.WriteTable(tbl)
	local data = util.Compress(util.TableToJSON(NETWORK.util.TagKeys(tbl or {})) or "{}")

	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
end

function NETWORK.util.ReadTable()
	local length = net.ReadUInt(32)

	if (!length or length <= 0) then
		return {}
	end

	local data = util.Decompress(net.ReadData(length))

	if (!data) then
		return {}
	end

	return NETWORK.util.UntagKeys(util.JSONToTable(data, false, true) or {})
end

function NETWORK.util.RestoreNumericKeys(tbl, depth)
	if (!istable(tbl)) then
		return tbl
	end

	depth = depth or 0

	if (depth > 16) then
		return tbl
	end

	local fixed = {}

	for key, value in pairs(tbl) do
		if (istable(value)) then
			value = NETWORK.util.RestoreNumericKeys(value, depth + 1)
		end

		local number = isstring(key) and #key <= 9 and key:match("^%-?[1-9]%d*$") and
			tonumber(key) or nil

		if (number and tbl[number] == nil) then
			fixed[number] = value
		else
			fixed[key] = value
		end
	end

	return fixed
end

function NETWORK.util.SafeCall(name, callback, ...)
	local results = {pcall(callback, ...)}

	if (!results[1]) then
		NETWORK.util.PrintWarning("Ошибка в " .. tostring(name) .. ": " .. tostring(results[2]))

		return
	end

	return unpack(results, 2)
end

if (CLIENT) then
	concommand.Add("network_text_test", function(_, _, arguments)
		local text = #arguments > 0 and table.concat(arguments, " ") or
			"Привет, это проверка текста"

		NETWORK.util.Print("Исходник:     [" .. text .. "]")
		NETWORK.util.Print("Длина:        " .. NETWORK.util.Length(text))
		NETWORK.util.Print("Sub(1,5):     [" .. NETWORK.util.Sub(text, 1, 5) .. "]")
		NETWORK.util.Print("Sub(2):       [" .. NETWORK.util.Sub(text, 2) .. "]")
		NETWORK.util.Print("Sub(-1):      [" .. NETWORK.util.Sub(text, -1) .. "]")
		NETWORK.util.Print("Upper:        [" .. NETWORK.util.Upper(text) .. "]")
		NETWORK.util.Print("Truncate(10): [" .. NETWORK.util.Truncate(text, 10) .. "]")

		if (NETWORK.chat and NETWORK.chat.Format) then
			NETWORK.util.Print("Format:       [" .. NETWORK.chat.Format(text) .. "]")
		end
	end)
end
