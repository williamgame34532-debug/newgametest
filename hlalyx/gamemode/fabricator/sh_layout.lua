-- Display layout (pixel space of the 3D2D canvas, 2:1 like the Half-Life: Alyx screen).
-- Shared: the server validates clicks against the same rectangles the client draws.
CFRework = CFRework or {}
local C = CFRework
local S = C.State
local Lay = {}
C.Layout = Lay

Lay.W, Lay.H = 1024, 512
Lay.ROW = {x = 40, y = 78, w = 600, h = 56, gap = 12, max = 4}
Lay.TAB = {x = 40, y = 352, w = 194, h = 38, gap = 9}
Lay.SUMMARY = {x = 684, y = 62, w = 306}
Lay.PANEL = {x = 24, y = 84, w = 624, h = 252}
Lay.CANCEL = {x = 498, y = 360, w = 150, h = 48}
Lay.BOTTOM = 440

function Lay.Buttons(stage, tab)
	local b = {}
	if stage == S.MENU then
		local R = Lay.ROW
		for row, index in ipairs(C.CategoryItems(tab or 1)) do
			if row > R.max then break end
			b[#b + 1] = {id = 'select', arg = index, x = R.x, y = R.y + (row - 1) * (R.h + R.gap), w = R.w, h = R.h}
		end
		local T = Lay.TAB
		for i = 1, #C.Categories do
			b[#b + 1] = {id = 'tab', arg = i, x = T.x + (i - 1) * (T.w + T.gap), y = T.y, w = T.w, h = T.h}
		end
	elseif stage == S.DEPOSIT then
		b[1] = {id = 'cancel', x = Lay.CANCEL.x, y = Lay.CANCEL.y, w = Lay.CANCEL.w, h = Lay.CANCEL.h}
	end
	return b
end

function Lay.ButtonAt(stage, tab, x, y)
	for _, b in ipairs(Lay.Buttons(stage, tab)) do
		if x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then return b end
	end
end

-- UTF-8 upper case for Russian (string.upper only knows ASCII)
function C.Upper(s)
	s = string.upper(s)
	s = s:gsub('\208([\176-\191])', function(c) return '\208' .. string.char(c:byte() - 32) end)
	s = s:gsub('\209([\128-\143])', function(c) return '\208' .. string.char(c:byte() + 32) end)
	s = s:gsub('\209\145', '\208\129')
	return s
end
