local function eq( a, b, msg ) if a ~= b then error( ( "FAIL %s: %s ~= %s" ):format( msg, tostring( a ), tostring( b ) ), 2 ) end print( "ok  " .. msg ) end

------------------------------------------------ эмуляция панелей
local ALL = {}
METHODS = {}
for _, n in ipairs( { "AddDeathNotice", "AddLine", "Alive", "AlphaTo", "Angle", "Build", "BuildHotbar", "BuildNav", "Center", "Clip1", "Close", "CompleteCommand", "ContextMenuOpen", "CursorPos", "DistToSqr", "Distance", "Dock", "DockMargin", "DragThink", "DrawDeathNotice", "DrawTextEntryText", "EyeAngles", "EyePos", "Forward", "GetActiveWeapon", "GetAimVector", "GetAlpha", "GetAmount", "GetBodygroup", "GetBonePosition", "GetCharDesc", "GetCharName", "GetClass", "GetEntity", "GetFaction", "GetFactionTable", "GetItemID", "GetMaxHealth", "GetModel", "GetNoDraw", "GetNumBodyGroups", "GetPos", "GetPrintName", "GetSize", "GetSkin", "GetSlot", "GetSlotPos", "GetTall", "GetVBar", "GetValue", "GetWeapons", "GetWide", "HUDAmmoPickedUp", "HUDDrawPickupHistory", "HUDDrawScoreBoard", "HUDDrawTargetID", "HUDItemPickedUp", "HUDShouldDraw", "HUDWeaponPickedUp", "HandleKey", "HasCharacter", "HasFocus", "Health", "Height", "HideCommands", "Hovered", "Init", "IsAdmin", "IsDown", "IsError", "IsHovered", "IsNPC", "IsPlayer", "IsSpeaking", "LocalToScreen", "LookupBone", "MakePopup", "MouseCapture", "MoveSel", "NavButton", "Nick", "OBBCenter", "OnMousePressed", "OnMouseReleased", "OnMouseWheeled", "Open", "Paint", "PaintOver", "Ping", "PlayerEndVoice", "PlayerStartVoice", "PrintHelp", "RebuildAppearance", "RebuildSkins", "Recompute", "Relayout", "Remove", "RequestFocus", "Rewrap", "RunAnimation", "ScoreboardHide", "ScoreboardShow", "SelectModel", "Send", "SetAlpha", "SetAngles", "SetBodygroup", "SetCamPos", "SetCaretPos", "SetCursor", "SetDSP", "SetDrawLanguageID", "SetFOV", "SetFloat", "SetFont", "SetIconAlphaMul", "SetKeyboardInputEnabled", "SetLookAt", "SetModel", "SetMouseInputEnabled", "SetMultiline", "SetOptions", "SetPage", "SetPaintBackground", "SetParent", "SetPlaceholderText", "SetPos", "SetSize", "SetSkin", "SetTabbingDisabled", "SetTall", "SetText", "SetTextColor", "SetTooltip", "SetUpdateOnType", "SetVisible", "SetWide", "SizeToContents", "SkinCount", "SpawnMenuOpen", "TextWidth", "Think", "ToScreen", "TryCreate", "Update", "UpdateCommands", "UpdatePreview", "Width" } ) do METHODS[ n ] = true end
local Base = {}
function Base:SetSize( w, h ) self._w, self._h = w, h end
function Base:SetWide( w ) self._w = w end
function Base:SetTall( h ) self._h = h end
function Base:GetWide() return self._w or 100 end
function Base:GetTall() return self._h or 40 end
function Base:GetSize() return self:GetWide(), self:GetTall() end
function Base:SetPos( x, y ) self._x, self._y = x, y end
function Base:GetPos() return self._x or 0, self._y or 0 end
function Base:CursorPos() return 10, 10 end
function Base:LocalToScreen( x, y ) return x, y end
function Base:GetAlpha() return 255 end
function Base:IsValid() return not self._removed end
function Base:Remove() if self._removed then return end self._removed = true if self.OnRemove then self:OnRemove() end end
function Base:IsHovered() return true end
function Base:IsDown() return false end
function Base:HasFocus() return false end
function Base:GetValue() return self._text or "" end
function Base:SetText( t ) self._text = t end
function Base:GetVBar() return vgui.Create( "DPanel" ) end
function Base:GetEntity() return nil end
function Base:AlphaTo( a, t, d, cb ) if cb then cb() end end
function Base:IsVisible() return true end

local function chain( name )
	local t = VGUI and VGUI[ name ]
	return t
end

local REGBASE = {}
local oldReg = vgui.Register
vgui.Register = function( n, t, b ) oldReg( n, t, b ) REGBASE[ n ] = b t.BaseClass = VGUI[ b ] end
-- уже зарегистрированные (загружены до этого файла) — восстановить базы
REGBASE.NworkMainMenu = "NworkScreen" REGBASE.NworkCharCreate = "NworkScreen" REGBASE.NworkCharSelect = "NworkScreen"
for n, b in pairs( REGBASE ) do if VGUI[ n ] then VGUI[ n ].BaseClass = VGUI[ b ] end end

vgui.Create = function( name, parent )
	local layers = {}
	local n = name
	while n and VGUI[ n ] do layers[ #layers + 1 ] = VGUI[ n ] n = REGBASE[ n ] end
	local o = setmetatable( { _name = name, _kids = {} }, { __index = function( t, k )
		for _, L in ipairs( layers ) do if L[ k ] ~= nil then return L[ k ] end end
		if Base[ k ] then return Base[ k ] end
		if METHODS[ k ] then return function() end end
		return nil
	end } )
	o.btnUp, o.btnDown, o.btnGrip = {}, {}, {}
	if parent then table.insert( parent._kids, o ) end
	ALL[ #ALL + 1 ] = o
	if o.Init then o:Init() end
	return o
end

local function PaintAll( p, depth )
	depth = depth or 0
	if p._removed then return end
	local w, h = p:GetSize()
	if rawget( p, "Paint" ) or p.Paint then p:Paint( w, h ) end
	if p.PaintOver then p:PaintOver( w, h ) end
	if p.Think then p:Think() end
	for _, k in ipairs( p._kids ) do PaintAll( k, depth + 1 ) end
end

------------------------------------------------ данные
LP.nw.nwork_charid = 5
LP.nw.nwork_faction = "citizen"
LP.nw.nwork_desc = "Высокий, в синей куртке."
LP.admin = true
local other = MakePlayer( "other", Vector( 50, 0, 0 ) )
other.nw.nwork_name = "Другой"
other.nw.nwork_charid = 7
other.nw.nwork_faction = "cp"
PLAYERS = { LP, other }
function LP:GetWeapons() return {} end
function LP:GetEyeTrace() return {} end
function LP:IsSpeaking() return true end
function other:IsSpeaking() return true end

NWORK.LocalInv = { { id = "cid", n = 1 }, { id = "water", n = 3 }, { id = "scrap", n = 20 } }

------------------------------------------------ чат
local function recv( name, ... ) READBUF = { ... } NETRECV[ name ]() end
recv( "nwork_chat", "ic", other, "Привет." )
recv( "nwork_chat", "me", other, "кивает" )
recv( "nwork_chat", "r", other, "Приём" )
recv( "nwork_chat", "ooc", other, "ooc" )
recv( "nwork_chat", "roll", other, "57/100" )
eq( NWORK.CharName( other ), "Неизвестный", "незнакомец" )
NWORK.Recognized[ 7 ] = true
eq( NWORK.CharName( other ), "Другой", "знакомый" )
recv( "nwork_notify", "Проверка", 1 )
eq( #NWORK.Notices, 1, "уведомление" )
recv( "nwork_objective", "Точка", "Подзадача" )
eq( NWORK.HUD.Objective.Title, "Точка", "задание получено" )
chat.AddText( Color( 255, 0, 0 ), "Системное" )
print( "ok  чат принял сообщения" )

------------------------------------------------ HUD
for id, fn in pairs( hook.list.HUDPaint ) do fn() print( "ok  HUDPaint " .. id ) end
for id, fn in pairs( hook.list.NworkHUDPaint or {} ) do print( "    (NworkHUDPaint " .. id .. ")" ) end

------------------------------------------------ экраны
NWORK.Chars = { { id = 1, name = "Тест", descr = "...", model = "m", skin = 0, faction = "citizen" } }
for _, open in ipairs( { "OpenMainMenu", "OpenCharCreate", "OpenCharSelect" } ) do
	local p = NWORK[ open ]()
	PaintAll( p )
	print( "ok  экран " .. open )
	p:Close()
end

for id in pairs( NWORK.UI.Pages ) do
	local tab = NWORK.OpenTab( id )
	if not tab then error( "OpenTab nil" ) end
	PaintAll( tab )
	print( "ok  вкладка " .. id )
	tab:Close()
end
-- выбранный предмет
local tab = NWORK.OpenTab( "inv" )
tab.SelIdx = 2
tab:SetPage( "inv" )
PaintAll( tab )
print( "ok  вкладка inv с выбранным предметом" )
tab:Close()

local r = NWORK.UI.Radial( { { Name = "А", Run = function() end }, { Name = "Б" } } )
PaintAll( r )
print( "ok  радиальное меню" )

NWORK.UI.TextPrompt( "Тест", "x", true, function() end )
print( "ok  TextPrompt" )

for _, p in ipairs( ALL ) do if p._name == "NworkChat" then PaintAll( p ) p:Open() PaintAll( p ) p.Entry._text = "/" p:UpdateCommands() print( "ok  чат-бокс открыт, команд: " .. #p.Matches ) end end
for _, p in ipairs( ALL ) do if p._name == "NworkCmdList" then PaintAll( p ) print( "ok  список команд" ) end end

print( "\nВСЕ КЛИЕНТСКИЕ ТЕСТЫ ПРОЙДЕНЫ" )
