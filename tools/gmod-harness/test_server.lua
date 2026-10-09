local function eq( a, b, msg ) if a ~= b then error( ( "FAIL %s: %s ~= %s" ):format( msg, tostring( a ), tostring( b ) ), 2 ) end print( "ok  " .. msg ) end
local CH = NWORK.Chat

-- разбор префиксов
local function P( t ) local id, body = CH.Parse( t ) return tostring( id ) .. "|" .. body end
eq( P( "привет" ), "nil|привет", "обычная речь" )
eq( P( "/me кивает" ), "me|кивает", "/me" )
eq( P( "/meow" ), "nil|/meow", "/meow не /me" )
eq( P( "//hello" ), "ooc|hello", "//" )
eq( P( ".//hi" ), "looc|hi", ".//" )
eq( P( "/r Приём" ), "r|Приём", "/r" )
eq( P( "/roll" ), "roll|", "/roll пусто" )
eq( P( "/roll 20" ), "roll|20", "/roll 20" )
eq( P( "/W тихо" ), "w|тихо", "регистр /W" )
eq( P( "/whisper тихо" ), "w|тихо", "/whisper" )
eq( P( "/yell А!" ), "y|А!", "/yell" )

-- игроки
local a = MakePlayer( "alice", Vector( 0, 0, 0 ) )
local b = MakePlayer( "bob", Vector( 200, 0, 0 ) )
local c = MakePlayer( "carl", Vector( 1000, 0, 0 ) )
PLAYERS = { a, b, c }

-- создание персонажа через сеть
local function recv( name, ply, ... ) READBUF = { ... } NETRECV[ name ]( 0, ply ) end
for _, p in ipairs( PLAYERS ) do
	recv( "nwork_ready", p )
	recv( "nwork_create", p, "Персонаж " .. p.nick, "Описание длиной больше десяти.", "models/player/group01/male_01.mdl", 0 )
end
eq( a:GetCharName(), "Персонаж alice", "персонаж создан" )
eq( a:GetCharID(), 1, "id персонажа" )
eq( a:GetFaction(), "citizen", "фракция" )
eq( NWORK.Inventory.Count( a.NworkInv, "cid" ), 1, "стартовые предметы" )

-- ошибка: плохое имя
SENT = {}
local d = MakePlayer( "dan" ) PLAYERS[ 4 ] = d
recv( "nwork_create", d, "<x>", "Описание длиной больше десяти.", "models/player/group01/male_01.mdl", 0 )
eq( d:HasCharacter(), false, "плохое имя отклонено" )
eq( SENT[ #SENT ].msg.name, "nwork_notify", "уведомление об ошибке" )
table.remove( PLAYERS, 4 )

-- чат и дистанции
local function say( p, text )
	SENT = {}
	local r = hook.list.PlayerSay[ "Nwork.Chat" ]( p, text )
	eq( r, "", "PlayerSay подавлен: " .. text )
	return SENT[ #SENT ]
end
local function nrecv( s ) return type( s.to ) == "table" and #s.to or s.to end

local s = say( a, "Привет" )
eq( s.msg.name, "nwork_chat", "ic отправлен" ) eq( s.msg.data[ 1 ], "ic", "класс ic" ) eq( nrecv( s ), 2, "ic слышат 2 (alice, bob)" )
s = say( a, "/w секрет" ) eq( nrecv( s ), 1, "шёпот слышит только сам" )
s = say( a, "/y ЭЙ" ) eq( nrecv( s ), 2, "крик 640: carl на 1000 не слышит" )
s = say( a, "// ooc" ) eq( nrecv( s ), 3, "ooc всем" )
s = say( a, "/roll" ) eq( s.msg.data[ 1 ], "roll", "roll" ) assert( s.msg.data[ 3 ]:match( "^%d+/100$" ), "roll формат" ) print( "ok  roll " .. s.msg.data[ 3 ] )
s = say( a, "/r приём" ) eq( s.msg.name, "nwork_notify", "рация без рации запрещена" )
NWORK.Inventory.Give( a, "radio", 1 )
s = say( a, "/r приём" ) eq( s.msg.data[ 1 ], "r", "рация с предметом" ) eq( nrecv( s ), 2, "рацию слышат: сам + bob рядом" )
s = say( a, "/abc" ) eq( s.msg.name, "nwork_notify", "неизвестная команда" ) eq( s.msg.data[ 1 ], "Неизвестная команда: /abc", "текст" )
s = say( a, "/giveitem alice scrap" ) eq( s.msg.data[ 1 ], "Эта команда только для администрации.", "админ-команда закрыта" )
a.admin = true
s = say( a, "/giveitem bob scrap 25" ) eq( s.msg.data[ 1 ], "Выдано.", "giveitem" )
eq( NWORK.Inventory.Count( b.NworkInv, "scrap" ), 25, "25 металлолома" )
local cells = 0 for _, e in ipairs( b.NworkInv ) do if e.id == "scrap" then cells = cells + 1 end end
eq( cells, 2, "стопка 20 -> две ячейки" )
s = say( a, "/setfaction bob cp" ) eq( b:GetFaction(), "cp", "setfaction" ) eq( b.NworkChar.model, "models/player/police.mdl", "модель фракции" )
s = say( b, "/r на позиции" ) eq( s.msg.data[ 1 ], "r", "ГО с рацией по фракции" )
s = say( a, "/objective Сбор | Подойти к терминалу" ) eq( s.msg.data[ 1 ], "Задание обновлено.", "objective" )
s = say( a, "/chardesc коротко" ) eq( s.msg.data[ 1 ], "Описание: от 10 до 512 символов.", "chardesc валидация" )
s = say( a, "/event Тревога" ) eq( s.msg.data[ 1 ], "event", "event админом" )

-- предметы
SENT = {}
local before = NWORK.Inventory.Count( a.NworkInv, "water" )
local idx for i, e in ipairs( a.NworkInv ) do if e.id == "water" then idx = i end end
a.nextAct = 0
recv( "nwork_item_action", a, idx, "use" )
eq( NWORK.Inventory.Count( a.NworkInv, "water" ), before - 1, "вода выпита" )
eq( NWORK.Needs.Get( a, "thirst" ), 100, "жажда (кламп 100)" )
a.NworkActCD = 0
for i, e in ipairs( a.NworkInv ) do if e.id == "cid" then idx = i end end
SENT = {}
recv( "nwork_item_action", a, idx, "show" )
eq( NWORK.Inventory.Count( a.NworkInv, "cid" ), 1, "ID не расходуется" )
eq( SENT[ 1 ].msg.data[ 1 ], "it", "показ документа в /it" )

-- сохранение и нужды
a.nw[ "nwork_need_hunger" ] = 42
NWORK.Character.Save( a )
local row = sql.Query( "SELECT data FROM nwork_characters WHERE id = 1" )[ 1 ]
assert( row.data:find( '"hunger": 42' ), "нужды в data: " .. row.data ) print( "ok  нужды сохранены " .. row.data )

-- выгрузка персонажа
recv( "nwork_unload", a )
eq( a:HasCharacter(), false, "персонаж выгружен" )
recv( "nwork_select", a, 1 )
eq( a:GetCharName(), "Персонаж alice", "персонаж загружен снова" )
eq( NWORK.Needs.Get( a, "hunger" ), 42, "нужды восстановлены" )

-- справка команд
local help = NWORK.Command.Help( a )
print( "ok  команд в справке: " .. #help )
print( "\nВСЕ СЕРВЕРНЫЕ ТЕСТЫ ПРОЙДЕНЫ" )
