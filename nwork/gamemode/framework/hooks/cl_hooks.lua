--[[-------------------------------------------------------------------------
	N-work — клиентские переопределения геймода.

	Стандартный HUD выключен полностью: всё, что видит игрок, рисует
	интерфейс N-work. Остаётся только CHudGMod — без него не вызываются
	HUDPaint-хуки. Спавн- и контекст-меню песочницы — только админам.
---------------------------------------------------------------------------]]

local SHOW = { CHudGMod = true }

function GM:HUDShouldDraw( name )
	return SHOW[ name ] == true
end

-- то, что base/sandbox рисуют сами
function GM:HUDDrawTargetID() return false end
function GM:HUDDrawPickupHistory() end
function GM:HUDAmmoPickedUp() end
function GM:HUDItemPickedUp() end
function GM:HUDWeaponPickedUp() end
function GM:DrawDeathNotice() end
function GM:AddDeathNotice() end

-- панели голосового чата — свои, в cl_hud.lua
function GM:PlayerStartVoice() end
function GM:PlayerEndVoice() end

-- скорборд заменён меню персонажа (Tab)
function GM:ScoreboardShow() end
function GM:ScoreboardHide() end
function GM:HUDDrawScoreBoard() end

function GM:SpawnMenuOpen()
	return LocalPlayer():IsAdmin()
end

function GM:ContextMenuOpen()
	return LocalPlayer():IsAdmin()
end

hook.Add( "InitPostEntity", "Nwork.CleanDefaultHUD", function()
	if IsValid( g_VoicePanelList ) then g_VoicePanelList:Remove() end
	RunConsoleCommand( "cl_showhints", "0" )
end )
