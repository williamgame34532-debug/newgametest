-- Picture and music (client), all switchable in TAB > НАСТРОЙКИ:
--   hla_grade 1   colour grade: a little darker and more contrast, less saturation — the bright maps of GMod
--                 stop looking overexposed, closer to the cold City 17 of HL:A
--   hla_hdr 1     a small HDR: only the brightest parts (lamps, sky, screens) glow softly; the eye adapts a little
--                 when going from dark to light and back
--   hla_music 1   Combine music now and then (sound/hla/music/combine_1..5.mp3), never two at once, not in menus;
--                 hla_music_volume 0..1
local cvGrade = CreateClientConVar('hla_grade', '1', true, false, 'Colour grade (0/1)')
local cvHDR = CreateClientConVar('hla_hdr', '1', true, false, 'Small HDR glow (0/1)')
local cvMusic = CreateClientConVar('hla_music', '1', true, false, 'Combine music now and then (0/1)')
local cvMusicVol = CreateClientConVar('hla_music_volume', '0.5', true, false, 'Music volume (0..1)')

local function inMenu()
	local p = LocalPlayer()
	return not IsValid(p) or p:GetNWBool('hla_in_menu') or (HLA.Menu and HLA.Menu.State and HLA.Menu.State.fade > 0)
end

---------------------------------------------------------------------------------------------------
-- eye adaptation: the average light where the player looks, followed slowly
local adapt = 1
local nextProbe = 0
local function probe()
	if RealTime() < nextProbe then return end
	nextProbe = RealTime() + 0.25
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local tr = util.TraceLine({start = EyePos(), endpos = EyePos() + EyeAngles():Forward() * 600, filter = p})
	local c = render.GetLightColor(tr.HitPos + tr.HitNormal * 4)
	local lum = (c.x * 0.3 + c.y * 0.59 + c.z * 0.11)
	-- dark places a bit brighter (up to +12%), very bright ones a bit darker (down to -18%)
	local want = math.Clamp(0.55 / math.max(lum, 0.05), 0.82, 1.12)
	adapt = Lerp(0.08, adapt, want)
end

hook.Add('RenderScreenspaceEffects', 'HLAPicture', function()
	if inMenu() then return end
	-- at a screen (terminal, fabricator) no glow: it would wash out the text of the screen
	local atScreen = (HLA.TerminalFocus and HLA.TerminalFocus.blend > 0) or (CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0)
	if cvHDR:GetBool() and not atScreen then
		probe()
		-- the glow only over the brightest parts
		DrawBloom(0.74, 0.45, 7, 7, 2, 0.8, 1, 1, 1)
	else
		adapt = 1
	end
	if cvGrade:GetBool() or cvHDR:GetBool() then
		local grade = cvGrade:GetBool()
		DrawColorModify({
			['$pp_colour_addr'] = 0, ['$pp_colour_addg'] = 0, ['$pp_colour_addb'] = grade and 0.004 or 0,
			['$pp_colour_brightness'] = grade and -0.035 or 0,
			['$pp_colour_contrast'] = (grade and 1.07 or 1) * adapt,
			['$pp_colour_colour'] = grade and 0.86 or 1,
			['$pp_colour_mulr'] = 0, ['$pp_colour_mulg'] = 0, ['$pp_colour_mulb'] = 0,
		})
	end
end)

---------------------------------------------------------------------------------------------------
-- music: one track at a time, 4..9 minutes of quiet between them, fades in and out
local TRACKS = {'combine_1', 'combine_2', 'combine_3', 'combine_4', 'combine_5'}
local M = {chan = nil, last = nil, nextAt = RealTime() + math.random(60, 150), fade = 0}
HLA.Music = M

local function stop()
	if IsValid(M.chan) then M.chan:Stop() end
	M.chan = nil
end

function M.Play(name)
	if IsValid(M.chan) or M.loading then return end
	local pick = name
	if not pick then
		local list = {}
		for _, t in ipairs(TRACKS) do
			if t ~= M.last and file.Exists('sound/hla/music/' .. t .. '.mp3', 'GAME') then list[#list + 1] = t end
		end
		if #list == 0 then return end
		pick = list[math.random(#list)]
	end
	M.loading = true
	sound.PlayFile('sound/hla/music/' .. pick .. '.mp3', 'noplay noblock', function(ch)
		M.loading = false
		if not IsValid(ch) then return end
		if IsValid(M.chan) or inMenu() or not cvMusic:GetBool() then ch:Stop() return end
		M.chan, M.last, M.fade = ch, pick, 0
		ch:SetVolume(0)
		ch:Play()
	end)
end
concommand.Add('hla_music_next', function() stop() M.Play() end)

hook.Add('Think', 'HLAMusic', function()
	local ch = M.chan
	if IsValid(ch) then
		-- menu, setting off: fade out and stop; at the end: fade out the last 3 s
		local leaving = inMenu() or not cvMusic:GetBool()
		local len, pos = ch:GetLength(), ch:GetTime()
		local target = leaving and 0 or 1
		if len > 0 and len - pos < 3 then target = math.max(0, (len - pos) / 3) end
		M.fade = math.Approach(M.fade, target, FrameTime() / (leaving and 1.2 or 2.5))
		ch:SetVolume(M.fade * math.Clamp(cvMusicVol:GetFloat(), 0, 1))
		if ch:GetState() == GMOD_CHANNEL_STOPPED or (leaving and M.fade <= 0) then
			stop()
			M.nextAt = RealTime() + math.random(240, 540)
		end
		return
	end
	if cvMusic:GetBool() and not inMenu() and RealTime() >= M.nextAt then
		M.nextAt = RealTime() + 30 -- try again later if it does not start
		M.Play()
	end
end)
