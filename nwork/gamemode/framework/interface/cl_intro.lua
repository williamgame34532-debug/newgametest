--[[-------------------------------------------------------------------------
	N-work — интро после создания персонажа.

	Короткая белая вспышка, затем курсивный титр и подзаголовок в разрядку
	(тексты — в sh_config.lua), плавное затухание. Не блокирует управление.
---------------------------------------------------------------------------]]

local T = NWORK.Theme
local C = NWORK.Config

local startTime

local Chars = NWORK.Util.Chars

local function DrawSpaced( font, text, cx, y, col, spacing )
	surface.SetFont( font )
	local chars = Chars( text )

	local total = 0
	for i, ch in ipairs( chars ) do
		total = total + select( 1, surface.GetTextSize( ch ) )
			+ ( i < #chars and spacing or 0 )
	end

	local x = cx - total / 2
	surface.SetTextColor( col )
	for _, ch in ipairs( chars ) do
		surface.SetTextPos( x, y )
		surface.DrawText( ch )
		x = x + select( 1, surface.GetTextSize( ch ) ) + spacing
	end
end

hook.Add( "HUDPaint", "Nwork.Intro", function()
	if not startTime then return end

	local I = T.Intro
	local t = CurTime() - startTime

	local total = I.Flash + I.FadeIn + I.Hold + I.FadeOut
	if t > total then startTime = nil return end

	local w, h = ScrW(), ScrH()
	local k = h / 1080

	-- вспышка
	if t < I.Flash then
		local f = 1 - ( t / I.Flash )
		surface.SetDrawColor( 255, 255, 255, 210 * f * f )
		surface.DrawRect( 0, 0, w, h )
	end

	-- титры
	local tt = t - I.Flash * 0.5 -- текст начинает проявляться ещё на вспышке
	local a = 0

	if tt > 0 then
		if tt < I.FadeIn then
			a = tt / I.FadeIn
		elseif tt < I.FadeIn + I.Hold + I.Flash * 0.5 then
			a = 1
		else
			a = math.max( 0, 1 - ( tt - I.FadeIn - I.Hold - I.Flash * 0.5 ) / I.FadeOut )
		end
	end

	if a <= 0 then return end
	a = a * a * ( 3 - 2 * a )

	local cy = math.floor( h * 0.42 )

	draw.SimpleText( C.IntroTitle, "Nwork.Intro", w / 2, cy,
		Color( 255, 255, 255, 255 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )

	DrawSpaced( "Nwork.IntroSub", C.IntroSub, w / 2,
		cy + math.floor( 18 * k ),
		Color( 210, 216, 222, 230 * a ), math.floor( 6 * k ) )
end )

net.Receive( "nwork_intro", function()
	startTime = CurTime()
	surface.PlaySound( "ambient/energy/whiteflash.wav" )
end )
