NETWORK.option = NETWORK.option or {}
NETWORK.option.stored = NETWORK.option.stored or {}
NETWORK.option.order = NETWORK.option.order or {}
NETWORK.option.categories = NETWORK.option.categories or {}
NETWORK.option.categoryOrder = NETWORK.option.categoryOrder or {}

function NETWORK.option.RegisterCategory(id, name, order)
	if (!NETWORK.option.categories[id]) then
		NETWORK.option.categoryOrder[#NETWORK.option.categoryOrder + 1] = id
	end

	NETWORK.option.categories[id] = {
		id = id,
		name = name,
		order = order or (#NETWORK.option.categoryOrder * 10)
	}
end

function NETWORK.option.Register(id, data)
	data.id = id
	data.type = data.type or "bool"
	data.category = data.category or "general"
	data.convar = data.convar or id
	data.order = data.order or (#NETWORK.option.order + 1) * 10

	if (!NETWORK.option.stored[id]) then
		NETWORK.option.order[#NETWORK.option.order + 1] = id
	end

	NETWORK.option.stored[id] = data

	return data
end

function NETWORK.option.Get(id)
	local data = NETWORK.option.stored[id]

	if (!data) then
		return
	end

	local convar = GetConVar(data.convar)

	if (!convar) then
		return data.default
	end

	if (data.type == "bool") then
		return convar:GetBool()
	elseif (data.type == "number") then
		return convar:GetFloat()
	end

	return convar:GetString()
end

function NETWORK.option.Set(id, value)
	local data = NETWORK.option.stored[id]

	if (!data) then
		return
	end

	if (isbool(value)) then
		value = value and "1" or "0"
	end

	RunConsoleCommand(data.convar, tostring(value))
end

function NETWORK.option.GetCategories()
	local list = {}

	for _, id in ipairs(NETWORK.option.categoryOrder) do
		list[#list + 1] = NETWORK.option.categories[id]
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

function NETWORK.option.GetEntries(category)
	local list = {}

	for _, id in ipairs(NETWORK.option.order) do
		local data = NETWORK.option.stored[id]

		if (data and (!category or data.category == category)) then
			list[#list + 1] = data
		end
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

NETWORK.option.RegisterCategory("performance", "optCatPerformance", 5)
NETWORK.option.RegisterCategory("interface", "optCatInterface", 10)
NETWORK.option.RegisterCategory("view", "optCatView", 20)
NETWORK.option.RegisterCategory("legs", "optCatLegs", 30)
NETWORK.option.RegisterCategory("thirdperson", "optCatThird", 35)
NETWORK.option.RegisterCategory("hud", "optCatHud", 40)

NETWORK.option.Register("fullEffects", {
	name = "settingFullEffects",
	description = "settingFullEffectsDesc",
	category = "performance",
	type = "bool",
	convar = "network_full_effects",
	default = true
})

NETWORK.option.Register("combineGlyphSize", {
	name = "settingGlyphSize",
	description = "settingGlyphSizeDesc",
	category = "hud",
	type = "number",
	convar = "network_glyph_size",
	min = 12,
	max = 40,
	decimals = 0
})

NETWORK.option.Register("language", {
	name = "settingLanguage",
	description = "settingLanguageDesc",
	category = "interface",
	type = "choice",
	convar = "network_language",
	options = {
		{value = "ru", label = "langRussian"},
		{value = "en", label = "langEnglish"},
		{value = "auto", label = "langAuto"}
	}
})

NETWORK.option.Register("postprocess", {
	name = "settingPost",
	description = "settingPostDesc",
	category = "interface",
	convar = "network_postprocess"
})

NETWORK.option.Register("curfewHud", {
	name = "settingCurfewHud",
	description = "settingCurfewHudDesc",
	category = "interface",
	type = "bool",
	convar = "network_curfew_hud",
	default = true
})

NETWORK.option.Register("zoneGreeting", {
	name = "settingZoneGreeting",
	description = "settingZoneGreetingDesc",
	category = "interface",
	type = "choice",
	convar = "network_zone_greeting",
	options = {
		{value = "off", label = "settingsOff"},
		{value = "chat", label = "zoneGreetingChat"},
		{value = "notify", label = "zoneGreetingNotify"}
	}
})

NETWORK.option.Register("voiceIndicator", {
	name = "settingVoiceIndicator",
	description = "settingVoiceIndicatorDesc",
	category = "hud",
	type = "choice",
	convar = "network_voice_indicator",
	options = {
		{value = "panel", label = "voiceIndicatorPanel"},
		{value = "icon", label = "voiceIndicatorIcon"}
	}
})

NETWORK.option.Register("progressStyle", {
	name = "settingProgressStyle",
	description = "settingProgressStyleDesc",
	category = "interface",
	type = "choice",
	convar = "network_progress_style",
	options = {
		{value = "bar", label = "progressStyleBar"},
		{value = "glass", label = "progressStyleGlass"}
	}
})

NETWORK.option.Register("progressPos", {
	name = "settingProgressPos",
	description = "settingProgressPosDesc",
	category = "interface",
	type = "choice",
	convar = "network_progress_pos",
	options = {
		{value = "top", label = "progressPosTop"},
		{value = "bottom", label = "progressPosBottom"}
	}
})

NETWORK.option.Register("needsEmotes", {
	name = "settingNeedsEmotes",
	description = "settingNeedsEmotesDesc",
	category = "interface",
	type = "bool",
	convar = "network_needs_emotes",
	default = true
})

NETWORK.option.Register("muteRadioVoice", {
	name = "settingMuteRadio",
	description = "settingMuteRadioDesc",
	category = "interface",
	type = "bool",
	convar = "network_mute_radio",
	default = false
})

NETWORK.option.Register("chatIcons", {
	name = "settingChatIcons",
	description = "settingChatIconsDesc",
	category = "interface",
	type = "bool",
	convar = "network_chat_icons_v2",
	default = true
})

NETWORK.option.Register("nameplates", {
	name = "settingNameplates",
	description = "settingNameplatesDesc",
	category = "interface",
	convar = "network_nameplates"
})

NETWORK.option.Register("viewbob", {
	name = "settingBob",
	description = "settingBobDesc",
	category = "view",
	type = "number",
	convar = "network_viewbob",
	min = 0,
	max = 2,
	decimals = 2
})

NETWORK.option.Register("viewroll", {
	name = "settingRoll",
	description = "settingRollDesc",
	category = "view",
	type = "number",
	convar = "network_viewroll",
	min = 0,
	max = 2,
	decimals = 2
})

NETWORK.option.Register("gunFeel", {
	name = "settingGunFeel",
	description = "settingGunFeelDesc",
	category = "view",
	type = "number",
	convar = "network_gunfeel",
	min = 0,
	max = 2,
	decimals = 2
})

NETWORK.option.Register("legs", {
	name = "settingLegs",
	description = "settingLegsDesc",
	category = "legs",

	convar = "network_legs_v2"
})

NETWORK.option.Register("legsArms", {
	name = "settingLegsArms",
	description = "settingLegsArmsDesc",
	category = "legs",
	convar = "network_legs_arms"
})

NETWORK.option.Register("legsBody", {
	name = "settingLegsBody",
	description = "settingLegsBodyDesc",
	category = "legs",
	convar = "network_legs_body"
})

NETWORK.option.Register("legsHide", {
	name = "settingLegsHide",
	description = "settingLegsHideDesc",
	category = "legs",
	convar = "network_legs_hidearms"
})

NETWORK.option.Register("hud", {
	name = "settingHud",
	description = "settingHudDesc",
	category = "hud",
	convar = "network_hud"
})

NETWORK.option.Register("hudSway", {
	name = "settingVisorSway",
	description = "settingVisorSwayDesc",
	category = "hud",
	convar = "network_visor_sway"
})

NETWORK.option.Register("thirdperson", {
	name = "settingThird",
	description = "settingThirdDesc",
	category = "thirdperson",
	convar = "network_thirdperson"
})

NETWORK.option.Register("thirdDistance", {
	name = "settingThirdDistance",
	description = "settingThirdDistanceDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_thirdperson_distance",
	min = 20,
	max = 80,
	decimals = 0
})

NETWORK.option.Register("thirdSide", {
	name = "settingThirdSide",
	description = "settingThirdSideDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_thirdperson_side",
	min = -80,
	max = 80,
	decimals = 0
})

NETWORK.option.Register("thirdHeight", {
	name = "settingThirdHeight",
	description = "settingThirdHeightDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_thirdperson_height",
	min = -40,
	max = 60,
	decimals = 0
})

NETWORK.option.Register("thirdSmooth", {
	name = "settingThirdSmooth",
	description = "settingThirdSmoothDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_thirdperson_smooth",
	min = 2,
	max = 30,
	decimals = 0
})

NETWORK.option.Register("cityFeel", {
	name = "settingCityFeel",
	description = "settingCityFeelDesc",
	category = "view",
	type = "bool",
	convar = "network_cityfeel",
	default = true
})

NETWORK.option.Register("cityDust", {
	name = "settingCityDust",
	description = "settingCityDustDesc",
	category = "view",
	type = "bool",
	convar = "network_cityfeel_dust",
	default = true
})

NETWORK.option.Register("immersive", {
	name = "settingImmersive",
	description = "settingImmersiveDesc",
	category = "thirdperson",
	type = "bool",
	convar = "network_immersive",
	default = false
})

NETWORK.option.Register("immersiveHeight", {
	name = "settingImmersiveHeight",
	description = "settingImmersiveHeightDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_immersive_height",
	min = -6,
	max = 10,
	decimals = 1
})

NETWORK.option.Register("immersiveForward", {
	name = "settingImmersiveForward",
	description = "settingImmersiveForwardDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_immersive_forward",
	min = 0,
	max = 12,
	decimals = 1
})

NETWORK.option.Register("immersiveSway", {
	name = "settingImmersiveSway",
	description = "settingImmersiveSwayDesc",
	category = "thirdperson",
	type = "bool",
	convar = "network_immersive_sway",
	default = true
})

NETWORK.option.Register("thirdHideHud", {
	name = "optThirdHideHud",
	description = "optThirdHideHudDesc",
	category = "thirdperson",
	type = "bool",
	convar = "network_thirdperson_hidehud",
	default = true
})

NETWORK.option.Register("thirdDynamic", {
	name = "settingThirdDynamic",
	description = "settingThirdDynamicDesc",
	category = "thirdperson",
	type = "number",
	convar = "network_thirdperson_dynamic",
	min = 0,
	max = 1,
	decimals = 2
})

NETWORK.option.Register("network_immersive_weapons", {
	name = "optImmersiveWeapons",
	description = "optImmersiveWeaponsDesc",
	category = "view",
	convar = "network_immersive_weapons"
})

NETWORK.option.Register("network_perf_low", {
	name = "optPerfLow",
	description = "optPerfLowDesc",
	category = "performance",
	convar = "network_perf_low"
})

for _, data in ipairs({
	{id = "network_menu_blur", name = "optPerfMenuBlur"},
	{id = "network_legs_v2", name = "optPerfLegs"},
	{id = "network_hud_curve", name = "optPerfHudCurve"},
	{id = "network_visor_sway", name = "optPerfSway"},
	{id = "network_cull", name = "optPerfCull"}
}) do
	if (ConVarExists(data.id)) then
		NETWORK.option.Register(data.id, {
			name = data.name,
			description = data.name .. "Desc",
			category = "performance",
			convar = data.id
		})
	end
end

NETWORK.option.Register("network_chat_font", {
	name = "optChatFont",
	description = "optChatFontDesc",
	category = "interface",
	type = "choice",
	convar = "network_chat_font",
	options = {
		{value = "chat", label = "fontChatRound"},
		{value = "body", label = "fontChatBody"},
		{value = "notice", label = "fontChatNotice"},
		{value = "mono", label = "fontChatMono"}
	}
})

NETWORK.option.Register("network_chat_size", {
	name = "optChatSize",
	description = "optChatSizeDesc",
	category = "interface",
	type = "number",
	convar = "network_chat_size",
	min = 12,
	max = 30,
	decimals = 0
})

NETWORK.option.Register("network_notify_side", {
	name = "optNoticeSide",
	description = "optNoticeSideDesc",
	category = "interface",
	type = "choice",
	convar = "network_notify_side",
	options = {
		{value = "right", label = "optNoticeRight"},
		{value = "left", label = "optNoticeLeft"}
	}
})

NETWORK.option.Register("network_fx_vignette", {
	name = "optVignette",
	description = "optVignetteDesc",
	category = "interface",
	type = "number",
	convar = "network_fx_vignette",
	min = 0,
	max = 1,
	decimals = 2,
	default = 0.55
})

NETWORK.option.Register("network_fx_vignette_size", {
	name = "optVignetteSize",
	description = "optVignetteSizeDesc",
	category = "interface",
	type = "number",
	convar = "network_fx_vignette_size",
	min = 0.4,
	max = 1,
	decimals = 2,
	default = 0.62
})

NETWORK.option.Register("network_fx_vignette_color", {
	name = "optVignetteColor",
	description = "optVignetteColorDesc",
	category = "interface",
	type = "choice",
	convar = "network_fx_vignette_color",
	default = "black",
	options = {
		{value = "black", label = "optVignetteBlack"},
		{value = "blue", label = "optVignetteBlue"},
		{value = "warm", label = "optVignetteWarm"}
	}
})

NETWORK.option.Register("network_fx_fog", {
	name = "optFog",
	description = "optFogDesc",
	category = "interface",
	convar = "network_fx_fog"
})

NETWORK.option.Register("network_music_enabled", {
	name = "optMusicEnabled",
	description = "optMusicEnabledDesc",
	category = "interface",
	convar = "network_music_enabled"
})

NETWORK.option.Register("network_music_menu", {
	name = "optMusicMenu",
	description = "optMusicMenuDesc",
	category = "interface",
	convar = "network_music_menu"
})

NETWORK.option.Register("network_music", {
	name = "optMusic",
	description = "optMusicDesc",
	category = "interface",
	type = "number",
	min = 0,
	max = 1,
	decimals = 2,
	default = 0.25
})

NETWORK.option.Register("network_uiscale", {
	name = "optUIScale",
	description = "optUIScaleDesc",
	category = "interface",
	type = "number",
	min = 0.75,
	max = 1.35,
	decimals = 2,
	default = 1
})

NETWORK.option.Register("network_dispatchfeed", {
	name = "optDispatchFeed",
	description = "optDispatchFeedDesc",
	category = "hud",
	type = "bool",
	default = 1
})

NETWORK.option.Register("network_cmb_markers", {
	name = "optCmbMarkers",
	description = "optCmbMarkersDesc",
	category = "hud",
	type = "bool",
	default = 1
})

NETWORK.option.Register("network_blur", {
	name = "optBlur",
	description = "optBlurDesc",
	category = "interface",
	type = "number",
	min = 0,
	max = 2,
	decimals = 0,
	default = 1
})

NETWORK.option.Register("network_sounds", {
	name = "optSounds",
	description = "optSoundsDesc",
	category = "interface",
	type = "bool",
	default = 1
})

NETWORK.option.Register("visor", {
	name = "optVisor",
	description = "optVisorDesc",
	category = "hud",
	type = "number",
	convar = "network_visor",
	min = 0,
	max = 1,
	decimals = 2
})

NETWORK.option.Register("welcome", {
	name = "optWelcome",
	description = "optWelcomeDesc",
	category = "interface",
	type = "bool",
	convar = "network_welcome",
	default = 1
})

NETWORK.option.Register("visorCurve", {
	name = "optVisorCurve",
	description = "optVisorCurveDesc",
	category = "hud",
	type = "bool",
	convar = "network_visor_curve",
	default = 1
})

NETWORK.option.Register("visorSway", {
	name = "optVisorSway",
	description = "optVisorSwayDesc",
	category = "hud",
	type = "bool",
	convar = "network_visor_sway",
	default = 1
})

NETWORK.option.Register("pickupMode", {
	name = "optPickupMode",
	description = "optPickupModeDesc",
	category = "interface",
	type = "choice",
	convar = "network_pickup_mode",
	options = {
		{value = "menu", label = "optPickupMenu"},
		{value = "hold", label = "optPickupHold"}
	}
})

NETWORK.option.Register("network_radial_key", {
	name = "optRadialKey",
	description = "optRadialKeyDesc",
	category = "interface",
	type = "number",
	min = 0,
	max = 159,
	decimals = 0,
	default = KEY_G
})

NETWORK.option.Register("network_thirdperson_key", {
	name = "optThirdKey",
	description = "optThirdKeyDesc",
	category = "thirdperson",
	type = "number",
	min = 0,
	max = 159,
	decimals = 0,
	default = 0
})

NETWORK.option.Register("network_rarity", {
	name = "optRarity",
	description = "optRarityDesc",
	category = "interface",
	type = "choice",
	options = {
		{value = "full", label = "optRarityFull"},
		{value = "minimal", label = "optRarityMinimal"},
		{value = "off", label = "optRarityOff"}
	},
	default = "full"
})

NETWORK.option.Register("network_shield_key", {
	name = "optShieldKey",
	description = "optShieldKeyDesc",
	category = "interface",
	type = "number",
	min = 0,
	max = 159,
	decimals = 0,
	default = KEY_I
})

NETWORK.option.Register("network_shieldflash_key", {
	name = "optShieldFlashKey",
	description = "optShieldFlashKeyDesc",
	category = "interface",
	type = "number",
	min = 0,
	max = 159,
	decimals = 0,
	default = 0
})

NETWORK.option.Register("network_mute_cwur", {
	name = "optMuteCWUR",
	description = "optMuteCWURDesc",
	category = "interface",
	type = "bool",
	default = false
})
