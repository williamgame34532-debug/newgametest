-- Voicelines of the Combine units (both sides): a message made of lines from the list — in Russian (or
-- the original English) — becomes those lines and the unit says them aloud. Several lines are joined
-- with commas: «Выдвигаюсь, граната, прикрой меня». The beginning of a line is enough when it is clear
-- which line is meant (two words or more); in the chat Tab completes it (cl_chat.lua).
include('sh_voicelines_data.lua')
local V = {}
HLA.Voice = V

-- lower case (Latin and Cyrillic), ё = е, only letters and digits, single spaces
function V.Norm(s)
	local out = {}
	for _, c in utf8.codes(s or '') do
		if c >= 0x41 and c <= 0x5A then c = c + 32 end
		if c >= 0x410 and c <= 0x42F then c = c + 32 end
		if c == 0x401 or c == 0x451 then c = 0x435 end
		if (c >= 0x61 and c <= 0x7A) or (c >= 0x30 and c <= 0x39) or (c >= 0x430 and c <= 0x44F) then
			out[#out + 1] = utf8.char(c)
		else
			out[#out + 1] = ' '
		end
	end
	return string.Trim((string.gsub(table.concat(out), '%s+', ' ')))
end

V.Index, V.Lines = {}, {}
for i, l in ipairs(HLA.VoiceLineList or {}) do
	local line = {text = l[1], en = l[2], files = l[3], key = V.Norm(l[1])}
	V.Lines[i] = line
	V.Index[line.key] = line
	local en = V.Norm(l[2])
	if en ~= '' and not V.Index[en] then V.Index[en] = line end
end

-- lines whose Russian text starts with what is typed (at most n), the closest first
function V.Suggest(typed, n)
	local k = V.Norm(typed)
	if utf8.len(k) < 2 then return {} end
	local res = {}
	for _, l in ipairs(V.Lines) do
		if string.sub(l.key, 1, #k) == k then res[#res + 1] = l end
	end
	table.sort(res, function(a, b) return #a.key < #b.key end)
	while #res > (n or 5) do table.remove(res) end
	return res, k
end

-- the line for one piece of the message: the whole line, or its beginning when only one line starts so
-- and two words (or 8 letters) are typed
local function find(piece)
	local k = V.Norm(piece)
	if k == '' then return end
	if V.Index[k] then return V.Index[k] end
	local words = select(2, string.gsub(k, ' ', '')) + 1
	if words < 2 and utf8.len(k) < 8 then return end
	local hit
	for _, l in ipairs(V.Lines) do
		if string.sub(l.key, 1, #k) == k then
			if hit and hit ~= l then return end
			hit = l
		end
	end
	return hit
end

-- message -> the text to show, the voicelines in order (nil when none of it is a voiceline)
function V.Parse(text)
	local parts = string.Explode(',', text)
	local out, lines = {}, {}
	local i = 1
	while i <= #parts do
		local got, upto
		-- the longest run of pieces that is one line (a line may have commas of its own)
		for j = #parts, i, -1 do
			local l = find(table.concat(parts, ',', i, j))
			if l then got, upto = l, j break end
		end
		if got then
			out[#out + 1] = got.text
			lines[#lines + 1] = got
			i = upto + 1
		else
			out[#out + 1] = string.Trim(parts[i])
			i = i + 1
		end
	end
	if #lines == 0 then return end
	-- join: after a line ending with . ! ? … or — a space, otherwise a comma
	local s = ''
	for n, piece in ipairs(out) do
		if piece ~= '' then
			if s == '' then s = piece
			elseif string.find(s, '[%.!%?]$') or string.find(s, '…$') or string.find(s, '—$') then s = s .. ' ' .. piece
			else s = s .. ', ' .. piece end
		end
	end
	return s, lines
end
