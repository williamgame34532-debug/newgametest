--[[-------------------------------------------------------------------------
	Знакомства (клиент): приём списка, F3, действие «Представиться».
---------------------------------------------------------------------------]]

local CC = NWORK.Chat.Colors

net.Receive( "nwork_recog", function()
	if not net.ReadBool() then
		local n = net.ReadUInt( 16 )
		for _ = 1, n do NWORK.Recognized[ net.ReadUInt( 32 ) ] = true end
		return
	end

	local self_ = net.ReadBool()
	local id    = net.ReadUInt( 32 )
	local name  = net.ReadString()

	if self_ then
		NWORK.ChatPush( "Nwork.ChatItalic", CC.Emote, "** Вы представляетесь окружающим как " .. name .. "." )
	else
		NWORK.Recognized[ id ] = true
		NWORK.ChatPush( "Nwork.ChatItalic", CC.Emote, "** " .. name .. " представляется." )
	end
end )

concommand.Add( "nwork_introduce", function()
	net.Start( "nwork_introduce" )
	net.SendToServer()
end )

hook.Add( "PlayerBindPress", "Nwork.Introduce", function( _, bind, pressed )
	if not pressed or bind ~= "gm_showspare1" then return end
	if NWORK.UI.Active() then return true end
	RunConsoleCommand( "nwork_introduce" )
	return true
end )

NWORK.Interact.AddOption( "introduce", {
	Name   = "Представиться",
	Glyph  = "people",
	Order  = 10,
	Filter = function( ent ) return ent:IsPlayer() and LocalPlayer():HasCharacter() end,
	Run    = function() RunConsoleCommand( "nwork_introduce" ) end,
} )
