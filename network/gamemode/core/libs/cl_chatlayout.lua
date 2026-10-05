NETWORK.chat = NETWORK.chat or {}

local LAYOUT = {}
LAYOUT.__index = LAYOUT

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local entities = {
	["&lt;"] = "<",
	["&gt;"] = ">",
	["&amp;"] = "&",
	["&quot;"] = "\""
}

local function Decode(text)
	return (string.gsub(text, "&%a+;", function(entity)
		return entities[entity] or entity
	end))
end

local function Tokenize(text, defaultFont)
	local chars = {}
	local fonts = {defaultFont}
	local colors = {Color(255, 255, 255)}
	local index = 1
	local length = #text

	while (index <= length) do
		local char = string.sub(text, index, index)

		if (char == "<") then
			local close = string.find(text, ">", index, true)

			if (!close) then
				break
			end

			local tag = string.sub(text, index + 1, close - 1)
			local name, value = string.match(tag, "^(/?%a+)=?(.*)$")

			if (name == "font") then
				fonts[#fonts + 1] = value != "" and value or defaultFont
			elseif (name == "/font") then
				if (#fonts > 1) then
					fonts[#fonts] = nil
				end
			elseif (name == "color" or name == "colour") then
				local r, g, b = string.match(value, "(%d+),%s*(%d+),%s*(%d+)")

				colors[#colors + 1] = r and Color(tonumber(r), tonumber(g), tonumber(b)) or
					colors[#colors]
			elseif (name == "/color" or name == "/colour") then
				if (#colors > 1) then
					colors[#colors] = nil
				end
			end

			index = close + 1
		elseif (char == "&") then
			local entity = string.match(text, "^&%a+;", index)

			if (entity) then
				chars[#chars + 1] = {text = Decode(entity), font = fonts[#fonts],
					color = colors[#colors]}
				index = index + #entity
			else
				chars[#chars + 1] = {text = "&", font = fonts[#fonts], color = colors[#colors]}
				index = index + 1
			end
		else
			local glyph = string.match(text, "^" .. UTF8_CHAR, index)

			if (!glyph or glyph == "") then
				glyph = char
			end

			chars[#chars + 1] = {text = glyph, font = fonts[#fonts], color = colors[#colors]}
			index = index + #glyph
		end
	end

	return chars
end

local widthCache = {}
local heightCache = {}

local function Measure(font, text)
	local cache = widthCache[font]

	if (!cache) then
		cache = {}
		widthCache[font] = cache
	end

	local width = cache[text]

	if (!width) then
		surface.SetFont(font)
		width = (surface.GetTextSize(text))
		cache[text] = width
	end

	return width
end

local function FontHeight(font)
	local height = heightCache[font]

	if (!height) then
		surface.SetFont(font)

		local _, tall = surface.GetTextSize("Ай")

		height = tall
		heightCache[font] = height
	end

	return height
end

hook.Add("OnScreenSizeChanged", "nwChatLayoutCache", function()
	widthCache = {}
	heightCache = {}
end)

local function Build(chars, maxWidth)
	local lines = {}
	local line = {runs = {}, width = 0, height = 0}
	local run = nil

	local function CloseRun()
		if (run and run.text != "") then
			run.width = Measure(run.font, run.text)
			line.runs[#line.runs + 1] = run
			line.width = line.width + run.width
			line.height = math.max(line.height, FontHeight(run.font))
		end

		run = nil
	end

	local function NewLine()
		CloseRun()

		if (line.height == 0) then
			line.height = FontHeight(chars[1] and chars[1].font or "nwChat")
		end

		lines[#lines + 1] = line
		line = {runs = {}, width = 0, height = 0}
	end

	local function Append(char, index)
		if (run and (run.font != char.font or run.color != char.color)) then
			CloseRun()
		end

		if (!run) then
			run = {font = char.font, color = char.color, text = "", start = index, stop = index,
				x = line.width}
		end

		run.text = run.text .. char.text
		run.stop = index
	end

	local words = {}
	local word = {from = 1, to = 0, width = 0}

	for index, char in ipairs(chars) do
		if (char.text == "\n") then
			if (word.to >= word.from) then
				words[#words + 1] = word
			end

			words[#words + 1] = {from = index, to = index, width = 0, bBreak = true}
			word = {from = index + 1, to = index, width = 0}
		else
			word.to = index
			word.width = word.width + Measure(char.font, char.text)

			if (char.text == " ") then
				words[#words + 1] = word
				word = {from = index + 1, to = index, width = 0}
			end
		end
	end

	if (word.to >= word.from) then
		words[#words + 1] = word
	end

	for _, entry in ipairs(words) do
		if (entry.bBreak) then
			Append({text = "", font = chars[entry.from].font, color = chars[entry.from].color},
				entry.from)
			NewLine()

			continue
		end

		local lineWidth = line.width + (run and Measure(run.font, run.text) or 0)

		if (lineWidth > 0 and lineWidth + entry.width > maxWidth) then
			NewLine()
		end

		if (entry.width > maxWidth) then

			for index = entry.from, entry.to do
				local char = chars[index]
				local current = line.width + (run and Measure(run.font, run.text) or 0)

				if (current > 0 and current + Measure(char.font, char.text) > maxWidth) then
					NewLine()
				end

				Append(char, index)
			end
		else
			for index = entry.from, entry.to do
				Append(chars[index], index)
			end
		end
	end

	NewLine()

	local y = 0
	local width = 0

	for _, entry in ipairs(lines) do
		entry.y = y
		y = y + entry.height
		width = math.max(width, entry.width)
	end

	return lines, y, width
end

function NETWORK.chat.Layout(text, maxWidth, font)
	local object = setmetatable({}, LAYOUT)

	object.font = font or "nwChat"
	object.chars = Tokenize(text or "", object.font)
	object.maxWidth = math.max(maxWidth or 100, 20)
	object.lines, object.height, object.width = Build(object.chars, object.maxWidth)

	local plain = {}

	for index, char in ipairs(object.chars) do
		plain[index] = char.text
	end

	object.plain = table.concat(plain)
	object.count = #object.chars

	return object
end

function LAYOUT:GetHeight()
	return self.height
end

function LAYOUT:GetWidth()
	return self.width
end

function LAYOUT:Draw(x, y, alpha, bShadow)
	alpha = alpha or 255

	for _, line in ipairs(self.lines) do
		for _, run in ipairs(line.runs) do
			local runY = y + line.y + (line.height - FontHeight(run.font))

			surface.SetFont(run.font)

			if (bShadow) then
				surface.SetTextColor(0, 0, 0, alpha * 0.85)
				surface.SetTextPos(x + run.x + 1, runY + 1)
				surface.DrawText(run.text)
			end

			surface.SetTextColor(run.color.r, run.color.g, run.color.b, alpha)
			surface.SetTextPos(x + run.x, runY)
			surface.DrawText(run.text)
		end
	end
end

local function PrefixWidth(run, count)
	if (count <= 0) then
		return 0
	end

	local chars = {}

	for glyph in string.gmatch(run.text, UTF8_CHAR) do
		chars[#chars + 1] = glyph

		if (#chars >= count) then
			break
		end
	end

	return Measure(run.font, table.concat(chars))
end

function LAYOUT:CharAt(x, y)
	if (#self.lines == 0) then
		return 1
	end

	local line = self.lines[#self.lines]

	for _, entry in ipairs(self.lines) do
		if (y < entry.y + entry.height) then
			line = entry

			break
		end
	end

	if (#line.runs == 0) then
		return self.count + 1
	end

	if (x <= 0) then
		return line.runs[1].start
	end

	for _, run in ipairs(line.runs) do
		if (x < run.x + run.width) then
			local count = run.stop - run.start + 1
			local local_x = x - run.x

			for i = 1, count do
				local left = PrefixWidth(run, i - 1)
				local right = PrefixWidth(run, i)

				if (local_x < (left + right) * 0.5) then
					return run.start + i - 1
				end
			end

			return run.stop + 1
		end
	end

	return line.runs[#line.runs].stop + 1
end

local selectionColor = Color(0, 0, 0, 0)

function LAYOUT:DrawSelection(x, y, from, to, color, radius)
	if (!from or !to or from == to) then
		return
	end

	if (from > to) then
		from, to = to, from
	end

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	selectionColor.r, selectionColor.g, selectionColor.b, selectionColor.a =
		color.r, color.g, color.b, color.a or 255

	for _, line in ipairs(self.lines) do
		local lineLeft, lineRight

		for _, run in ipairs(line.runs) do
			local first = math.max(from, run.start)
			local last = math.min(to, run.stop + 1)

			if (first < last) then
				local left = run.x + PrefixWidth(run, first - run.start)
				local right = run.x + PrefixWidth(run, last - run.start)

				if (radius and radius > 0) then
					lineLeft = lineLeft and math.min(lineLeft, left) or left
					lineRight = lineRight and math.max(lineRight, right) or right
				else
					surface.DrawRect(x + left, y + line.y, math.max(right - left, 1), line.height)
				end
			end
		end

		if (lineLeft) then
			local width = math.max(lineRight - lineLeft, 1)
			local corner = math.min(radius, math.floor(math.min(width, line.height) * 0.5))

			draw.RoundedBox(corner, math.Round(x + lineLeft - 1), math.Round(y + line.y),
				math.Round(width + 2), line.height, selectionColor)
		end
	end
end

function LAYOUT:GetText(from, to)
	from = math.max(from or 1, 1)
	to = math.min(to or (self.count + 1), self.count + 1)

	if (from >= to) then
		return ""
	end

	local parts = {}

	for index = from, to - 1 do
		parts[#parts + 1] = self.chars[index].text
	end

	return table.concat(parts)
end
