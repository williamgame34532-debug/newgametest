--[[
	Полное отключение стандартного HUD.
]]

local whitelist = HLARP.Config.HUDWhitelist

-- Все движковые HUD-элементы, кроме белого списка.
function GM:HUDShouldDraw(name)
	return whitelist[name] == true
end

-- Отрисовка base-гейммода: имена над игроками, история подбора, килфид.
function GM:HUDPaint() end
function GM:HUDDrawTargetID() return false end
function GM:HUDDrawPickupHistory() end
function GM:DrawDeathNotice(x, y) end
function GM:AddDeathNotice() end

function GM:HUDAmmoPickedUp() end
function GM:HUDItemPickedUp() end
function GM:HUDWeaponPickedUp() end

-- Стандартный скорборд (TAB).
function GM:ScoreboardShow() return false end
function GM:ScoreboardHide() end
function GM:HUDDrawScoreBoard() end

-- Панели голосового чата в углу экрана.
function GM:PlayerStartVoice(ply) end
function GM:PlayerEndVoice(ply) end

-- Стандартное окно чата.
function GM:StartChat(isTeam)
	return not whitelist.CHudChat
end

-- Удаляем панели, которые base-гейммод мог создать до загрузки.
hook.Add("InitPostEntity", "HLARP.RemoveDefaultHUD", function()
	if IsValid(g_VoicePanelList) then g_VoicePanelList:Remove() end
	if IsValid(g_Scoreboard) then g_Scoreboard:Remove() end
end)
