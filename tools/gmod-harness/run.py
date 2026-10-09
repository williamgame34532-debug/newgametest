import sys, os, json
from lupa.luajit21 import LuaRuntime
root, realm = sys.argv[1], sys.argv[2]
test = sys.argv[3] if len(sys.argv) > 3 else None
L = LuaRuntime(unpack_returned_tuples=True)
g = L.globals()
def lst(path):
    path = path.replace('//','/')
    if not os.path.isdir(path): return L.table(), L.table()
    fs=[f for f in sorted(os.listdir(path)) if os.path.isfile(os.path.join(path,f))]
    ds=[d for d in sorted(os.listdir(path)) if os.path.isdir(os.path.join(path,d))]
    return L.table(*fs), L.table(*ds)
def to_py(t):
    if L.eval('function(x) return type(x)=="table" end')(t):
        keys=list(t.keys())
        if keys and all(isinstance(k,int) for k in keys): return [to_py(t[k]) for k in sorted(keys)]
        return {str(k): to_py(t[k]) for k in keys}
    return t
def to_lua(v):
    if isinstance(v,dict):
        t=L.table()
        for k,x in v.items(): t[k]=to_lua(x)
        return t
    if isinstance(v,list):
        t=L.table()
        for i,x in enumerate(v): t[i+1]=to_lua(x)
        return t
    return v
g.__list = lst
g.__json_encode = lambda t: json.dumps(to_py(t), ensure_ascii=False)
g.__json_decode = lambda s: to_lua(json.loads(s))
g.REALM = realm; g.GM_ROOT = root
import sqlite3
db = sqlite3.connect(':memory:')
def q(sqltext):
    try:
        cur = db.execute(sqltext)
        db.commit()
    except Exception as e:
        print("SQLERR", e, "|", sqltext); return False
    rows = cur.fetchall()
    if not rows: return None
    cols=[d[0] for d in cur.description]
    return to_lua([{c:(None if v is None else str(v)) for c,v in zip(cols,r)} for r in rows])
g.__sql = q
here=os.path.dirname(os.path.abspath(__file__))
L.execute(open(os.path.join(here,'gmod_stub.lua'),encoding='utf-8').read())
L.execute('GM = setmetatable( { FolderName = "nwork", BaseClass = Stub() }, {} ) GAMEMODE = GM')
if realm == "client":
    L.execute('LP = MakePlayer( "local" ) LP.nw.nwork_name = "Тест" PLAYERS = { LP }')
try:
    L.execute('include( "nwork/gamemode/' + ('init.lua' if realm=='server' else 'cl_init.lua') + '" )')
    print("\n== загрузка", realm, "OK")
except Exception as e:
    print("\n== ОШИБКА", realm, e); sys.exit(1)
if test:
    L.execute(open(test,encoding='utf-8').read())
