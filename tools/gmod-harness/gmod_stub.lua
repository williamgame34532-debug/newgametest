-- Минимальная эмуляция GMod API для дымовых тестов загрузки (LuaJIT).
-- REALM и GM_ROOT задаются раннером.

SERVER = REALM == "server"
CLIENT = not SERVER

local LOG = {}
_G.__ERRORS = {}

-- универсальная заглушка: любое поле/вызов возвращает заглушку
local Stub
local stubmt = {}
stubmt.__index = function( t, k ) return Stub() end
stubmt.__call  = function( t, ... ) return Stub() end
stubmt.__concat = function( a, b ) return tostring( a ) .. tostring( b ) end
stubmt.__tostring = function() return "stub" end
stubmt.__unm = function() return 0 end
stubmt.__add = function() return 0 end
stubmt.__sub = function() return 0 end
stubmt.__mul = function() return 0 end
stubmt.__div = function() return 0 end
stubmt.__lt = function() return false end
stubmt.__le = function() return false end
Stub = function() return setmetatable( {}, stubmt ) end
_G.Stub = Stub

local function lib( t ) return setmetatable( t or {}, stubmt ) end

-------------------------------------------------------------------- string
function string.Trim( s, c ) return ( s:gsub( "^%s*(.-)%s*$", "%1" ) ) end
function string.StartsWith( s, p ) return s:sub( 1, #p ) == p end
function string.EndsWith( s, p ) return p == "" or s:sub( -#p ) == p end
function string.GetFileFromFilename( p ) return p:match( "([^/]*)$" ) end
function string.Explode( sep, s ) local t = {} for part in ( s .. sep ):gmatch( "(.-)" .. sep:gsub( "%p", "%%%0" ) ) do t[ #t + 1 ] = part end return t end
string.upper = string.upper
-------------------------------------------------------------------- table
function table.Count( t ) local n = 0 for _ in pairs( t ) do n = n + 1 end return n end
function table.GetKeys( t ) local o = {} for k in pairs( t ) do o[ #o + 1 ] = k end return o end
function table.Copy( t ) local o = {} for k, v in pairs( t ) do o[ k ] = type( v ) == "table" and table.Copy( v ) or v end return o end
function table.Merge( a, b ) for k, v in pairs( b ) do a[ k ] = v end return a end
-------------------------------------------------------------------- math
function math.Clamp( v, a, b ) return math.min( math.max( v, a ), b ) end
function math.Round( v, d ) local m = 10 ^ ( d or 0 ) return math.floor( v * m + 0.5 ) / m end
-------------------------------------------------------------------- types
local colmt = {}
function Color( r, g, b, a ) return setmetatable( { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }, colmt ) end
function IsColor( v ) return getmetatable( v ) == colmt end
function istable( v ) return type( v ) == "table" end
function isstring( v ) return type( v ) == "string" end
function isbool( v ) return type( v ) == "boolean" end
function isnumber( v ) return type( v ) == "number" end
function isfunction( v ) return type( v ) == "function" end
function isentity( v ) return type( v ) == "table" and v.__ent == true end
function tobool( v ) return v and v ~= 0 and v ~= "0" and v ~= "false" end
function IsValid( v ) return v ~= nil and v ~= NULL and ( type( v ) ~= "table" or not v.IsValid or v:IsValid() ) end
color_white = Color( 255, 255, 255 )
color_black = Color( 0, 0, 0 )
NULL = setmetatable( {}, { __index = function() return function() end end } )
-------------------------------------------------------------------- utf8 (LuaJIT)
utf8 = {}
utf8.charpattern = "[\0-\x7F\xC2-\xF4][\x80-\xBF]*"
function utf8.char( ... )
	local out = {}
	for _, c in ipairs( { ... } ) do
		if c < 0x80 then out[ #out + 1 ] = string.char( c )
		elseif c < 0x800 then out[ #out + 1 ] = string.char( 0xC0 + math.floor( c / 64 ), 0x80 + c % 64 )
		else out[ #out + 1 ] = string.char( 0xE0 + math.floor( c / 4096 ), 0x80 + math.floor( c / 64 ) % 64, 0x80 + c % 64 ) end
	end
	return table.concat( out )
end
function utf8.codes( s )
	local i = 1
	return function()
		if i > #s then return nil end
		local c = s:byte( i )
		local len = c < 0x80 and 1 or ( c < 0xE0 and 2 or ( c < 0xF0 and 3 or 4 ) )
		local cp
		if len == 1 then cp = c elseif len == 2 then cp = ( c % 32 ) * 64 + s:byte( i + 1 ) % 64
		else cp = ( c % 16 ) * 4096 + ( s:byte( i + 1 ) % 64 ) * 64 + s:byte( i + 2 ) % 64 end
		local p = i
		i = i + len
		return p, cp
	end
end
function utf8.len( s ) local n = 0 for _ in utf8.codes( s ) do n = n + 1 end return n end
function utf8.offset( s, n ) local k = 0 for p in utf8.codes( s ) do k = k + 1 if k == n then return p end end if n == k + 1 then return #s + 1 end end
-------------------------------------------------------------------- hook
hook = { list = {} }
function hook.Add( ev, id, fn ) hook.list[ ev ] = hook.list[ ev ] or {} hook.list[ ev ][ id ] = fn end
function hook.Remove( ev, id ) if hook.list[ ev ] then hook.list[ ev ][ id ] = nil end end
function hook.Run( ev, ... )
	for _, fn in pairs( hook.list[ ev ] or {} ) do
		local a, b, c = fn( ... )
		if a ~= nil then return a, b, c end
	end
	local g = GAMEMODE or GM
	if g and type( g[ ev ] ) == "function" then return g[ ev ]( g, ... ) end
end
hook.Call = function( ev, gm, ... ) return hook.Run( ev, ... ) end
-------------------------------------------------------------------- net
NETSTR = {}
SENT = {}
local cur
net = {}
function net.Start( n ) assert( NETSTR[ n ] or CLIENT, "net.Start без AddNetworkString: " .. n ) cur = { name = n, data = {} } end
for _, t in ipairs{ "String", "UInt", "Int", "Bool", "Entity", "Vector", "Angle", "Float", "Table" } do
	net[ "Write" .. t ] = function( v ) table.insert( cur.data, v ) end
	net[ "Read" .. t ] = function() return table.remove( READBUF, 1 ) end
end
function net.Send( to ) table.insert( SENT, { msg = cur, to = to } ) end
function net.Broadcast() table.insert( SENT, { msg = cur, to = "all" } ) end
function net.SendToServer() table.insert( SENT, { msg = cur, to = "server" } ) end
NETRECV = {}
function net.Receive( n, fn ) NETRECV[ n ] = fn end
-------------------------------------------------------------------- util/sql/file
util = lib()
function util.AddNetworkString( n ) NETSTR[ n ] = true end
function util.TableToJSON( t ) return __json_encode( t ) end
function util.JSONToTable( s ) if s == nil or s == "" then return nil end return __json_decode( s ) end
function util.StringToType( s, t ) return Stub() end
function util.TraceLine() return { Hit = false } end
sql = {}
SQLLOG = {}
function sql.Query( q ) table.insert( SQLLOG, q ) return __sql( q ) end
function sql.SQLStr( s ) return "'" .. tostring( s ):gsub( "'", "''" ) .. "'" end
function sql.LastError() return "" end
file = {}
function file.Find( pat, path )
	local files, dirs = __list( GM_ROOT .. "/" .. pat:gsub( "/%*$", "" ) )
	return files, dirs
end
function file.Read() return nil end
function file.Write() end
function file.CreateDir() end
function file.Delete() end
-------------------------------------------------------------------- include
local CSFILES = {}
function AddCSLuaFile( p ) CSFILES[ p or "?" ] = true end
local stack = {}
function include( p )
	local full
	if p:find( "^nwork/" ) then full = GM_ROOT .. "/" .. p
	else full = ( stack[ #stack ] or GM_ROOT .. "/nwork/gamemode" ) .. "/" .. p end
	local dir = full:match( "^(.*)/[^/]*$" )
	local fn, err = loadfile( full )
	if not fn then error( "include: " .. tostring( err ) ) end
	stack[ #stack + 1 ] = dir
	local ok, res = xpcall( fn, debug.traceback )
	stack[ #stack ] = nil
	if not ok then table.insert( __ERRORS, res ) error( res ) end
	return res
end
-------------------------------------------------------------------- прочее
function DeriveGamemode() end
function CurTime() return os.clock() end
function RealTime() return os.clock() end
function FrameTime() return 0.016 end
function ScrW() return 1920 end
function ScrH() return 1080 end
function MsgC( ... ) local t = {} for _, v in ipairs( { ... } ) do if type( v ) == "string" then t[ #t + 1 ] = v end end io.write( table.concat( t ) ) end
function MsgN( ... ) print( ... ) end
function Material() return Stub() end
VEC = {}
VEC.__index = VEC
function Vector( x, y, z ) return setmetatable( { x = x or 0, y = y or 0, z = z or 0 }, VEC ) end
function VEC:DistToSqr( o ) return ( self.x - o.x ) ^ 2 + ( self.y - o.y ) ^ 2 + ( self.z - o.z ) ^ 2 end
function VEC:Distance( o ) return math.sqrt( self:DistToSqr( o ) ) end
function VEC:Length2DSqr() return self.x ^ 2 + self.y ^ 2 end
VEC.__add = function( a, b ) return Vector( a.x + b.x, a.y + b.y, a.z + b.z ) end
VEC.__sub = function( a, b ) return Vector( a.x - b.x, a.y - b.y, a.z - b.z ) end
VEC.__mul = function( a, b ) if type( b ) == "number" then return Vector( a.x * b, a.y * b, a.z * b ) end return Vector( a * b.x, a * b.y, a * b.z ) end
function Angle( p, y, r ) return { p = p or 0, y = y or 0, r = r or 0 } end
angle_zero = Angle()
function SetClipboardText() end
function RunConsoleCommand( ... ) table.insert( SENT, { cc = { ... } } ) end
function LocalPlayer() return LP end

game = game or {}
game.GetMap = function() return "rp_test" end
game.MaxPlayers = function() return 128 end
timer = { Create = function() end, Simple = function( _, f ) end }
concommand = { Add = function() end }
cookie = { GetString = function( _, d ) return d end, GetNumber = function( _, d ) return d end, Set = function() end, Delete = function() end }
resource = { AddFile = function() end }
language = { GetPhrase = function( s ) return s end }
surface = lib( { CreateFont = function() end, GetTextSize = function( s ) return #tostring( s ) * 8, 16 end } )
draw = lib()
render = lib()
input = lib()
gui = lib()
vgui = lib( { Register = function( n, t ) VGUI = VGUI or {} VGUI[ n ] = t end } )
notification = lib()
list = { Get = function() return {} end }
chat = lib( { AddText = function() end } )
ents = lib()
team = lib()
player_manager = lib()
player = { GetAll = function() return PLAYERS or {} end }
ents.Create = function() return Stub() end
MASK_SHOT, MASK_VISIBLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 0, 0, 0, 2, 1, 3, 4
NOTIFY_ERROR, KEY_ESCAPE, MOUSE_LEFT, RENDERGROUP_OTHER = 1, 70, 107, 0
-------------------------------------------------------------------- игроки
local PLAYER = {}
PLAYER.__index = PLAYER
local metas = { Player = PLAYER, Entity = {} }
function FindMetaTable( n ) metas[ n ] = metas[ n ] or {} return metas[ n ] end
function MakePlayer( nick, pos )
	local p = setmetatable( { __ent = true, nw = {}, nick = nick, pos = pos or Vector(), admin = false }, PLAYER )
	return p
end
function PLAYER:IsValid() return true end
function PLAYER:Nick() return self.nick end
function PLAYER:IsBot() return false end
function PLAYER:IsAdmin() return self.admin end
function PLAYER:Alive() return true end
function PLAYER:SteamID64() return "7656" .. self.nick end
function PLAYER:SteamID() return "STEAM_0:0:" .. self.nick end
function PLAYER:GetNWString( k, d ) local v = self.nw[ k ] if v == nil then return d end return v end
PLAYER.GetNWInt = PLAYER.GetNWString
PLAYER.GetNW2Float = PLAYER.GetNWString
function PLAYER:SetNWString( k, v ) self.nw[ k ] = v end
PLAYER.SetNWInt = PLAYER.SetNWString
PLAYER.SetNW2Float = PLAYER.SetNWString
function PLAYER:GetPos() return self.pos end
local vecmt = {}
function PLAYER:EmitSound() end
function PLAYER:EyeAngles() return Angle() end
function PLAYER:Health() return 100 end
function PLAYER:GetMaxHealth() return 100 end
setmetatable( PLAYER, { __index = function( t, k ) if k:find( "^Nwork" ) then return nil end return function() return Stub() end end } )
function Lerp( f, a, b ) return a + ( b - a ) * f end
function LerpVector( f, a, b ) return a end
function LerpAngle( f, a, b ) return a end
function PLAYER:EyePos() return self.pos end
function PLAYER:GetAimVector() return Vector( 1, 0, 0 ) end
function PLAYER:GetVelocity() return Vector() end
function PLAYER:Ping() return 30 end
function PLAYER:GetNoDraw() return false end
function PLAYER:GetActiveWeapon() return nil end
function PLAYER:LookupBone() return nil end
function PLAYER:GetModel() return "models/player/group01/male_01.mdl" end
function PLAYER:GetSkin() return 0 end
function PLAYER:GetNumBodyGroups() return 0 end
function PLAYER:Crouching() return false end
function PLAYER:GetClass() return "player" end
function PLAYER:IsPlayer() return true end
function PLAYER:IsNPC() return false end
VEC.ToScreen = function( v ) return { x = 100, y = 100, visible = true } end
function os.date( f ) return "12:00" end
function ClientsideModel() return nil end
