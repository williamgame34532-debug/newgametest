using System.Collections.Generic;
using System.IO;
using UnityEngine;

public enum NetMode { Sandbox, Mission }

// Живой игрок в сетевом бою: в каком отряде и на какой стороне
public class NetHuman { public int peer; public string nick; public Team team; public int squad; }

// Сетевая игра (хост решает всё: ИИ, урон, SCP, победа; клиенты присылают своё положение и попадания).
// Обе стороны строят одну и ту же карту и одни и те же отряды по конфигурации — затем на клиенте всё,
// кроме своего бойца, превращается в «марионеток», которых двигают снимки хоста.
public static class Net
{
    public const int Version = 7;
    public static INetTransport T;
    public static bool Active => T != null;
    public static bool IsHost => T != null && T.IsHost;
    public static bool IsClient => T != null && !T.IsHost;
    public static bool InGame;                 // идёт сетевой бой
    public static bool Applying, Cosmetic, InFire;
    public static int MyPeer;
    public static NetMode Mode = NetMode.Sandbox;
    public static string Status = "";
    public static string Nick
    {
        get { var n = PlayerPrefs.GetString("nick", ""); if (string.IsNullOrEmpty(n)) n = SteamNet.PersonaName ?? ("Боец-" + Random.Range(100, 999)); return n; }
        set { PlayerPrefs.SetString("nick", value); }
    }

    public class Member { public int peer; public string nick; public int side; public bool loaded; }
    public static readonly List<Member> Members = new List<Member>();
    public static BattleConfig PendingCfg;     // клиент: получен старт
    public static bool Go;                     // хост дал команду начинать (все загрузились)

    static NetRunner runner;
    static readonly Dictionary<int, Unit> byId = new Dictionary<int, Unit>();
    static int nextId;
    static readonly Dictionary<int, Soldier> proxyOf = new Dictionary<int, Soldier>();   // хост: пир → его боец-представитель
    static float snapT, stateT, slowT;
    static int relayThrow = -1;
    static bool endSent;

    // ---------------- сообщения ----------------
    enum M : byte
    {
        Hello = 1, Welcome, Lobby, SetSide, Start, Loaded, GoMsg, Leave,
        Snap = 20, Heli, MyState, Shot, Throw, Death, Hit, Damage, Msg, Speech, End, Spawn, Reanimate, Launch, BState, Lore, PickLore, PlayerDied
    }

    static MemoryStream ms = new MemoryStream(2048);
    static BinaryWriter W(M type) { ms.SetLength(0); var w = new BinaryWriter(ms); w.Write((byte)type); return w; }
    static void Send(int peer, bool reliable) { if (T != null) T.Send(peer, ms.GetBuffer(), (int)ms.Length, reliable); }
    static void ToHost(bool reliable) => Send(0, reliable);
    static void ToAll(bool reliable) => Send(-1, reliable);

    // ---------------- запуск ----------------
    public static string HostGame(bool steam, int port = UdpTransport.DefaultPort)
    {
        Shutdown();
        try { T = steam ? (INetTransport)SteamNet.CreateHost() : UdpTransport.Host(port); }
        catch (System.Exception e) { T = null; return "Не удалось создать лобби: " + e.Message; }
        if (T == null) return "Steam недоступен — используйте подключение по IP";
        MyPeer = 0;
        Members.Clear();
        Members.Add(new Member { peer = 0, nick = Nick, side = 0 });
        EnsureRunner();
        Status = "Лобби создано. " + T.Describe;
        return null;
    }

    public static string JoinGame(string address, int port = UdpTransport.DefaultPort)
    {
        Shutdown();
        try { T = UdpTransport.Join(address, port); }
        catch (System.Exception e) { T = null; return "Не удалось подключиться: " + e.Message; }
        StartClient();
        return null;
    }

    // Steam: присоединение к лобби друга (по приглашению)
    public static void JoinSteam(INetTransport t) { Shutdown(); T = t; StartClient(); }

    static void StartClient()
    {
        MyPeer = -1;
        Members.Clear();
        EnsureRunner();
        Status = "Подключение…";
        var w = W(M.Hello); w.Write(Version); w.Write(Nick); ToHost(true);
    }

    public static void EnsureRunner()
    {
        if (runner != null) return;
        var go = new GameObject("Net");
        Object.DontDestroyOnLoad(go);
        runner = go.AddComponent<NetRunner>();
    }

    public static void Shutdown()
    {
        if (T != null) { try { var w = W(M.Leave); if (IsHost) ToAll(true); else ToHost(true); T.Tick(); } catch { } T.Close(); }
        T = null;
        InGame = false; Go = false; PendingCfg = null;
        Members.Clear(); byId.Clear(); proxyOf.Clear();
        SteamNet.LeaveLobby();
    }

    public static void SetMode(NetMode m) { Mode = m; BroadcastLobby(); }
    public static void SetSide(int side)
    {
        if (IsHost) { Members[0].side = side; BroadcastLobby(); }
        else { var w = W(M.SetSide); w.Write((byte)side); ToHost(true); }
    }

    static void BroadcastLobby()
    {
        if (!IsHost) return;
        var w = W(M.Lobby); w.Write((byte)Mode); w.Write((byte)Members.Count);
        foreach (var m in Members) { w.Write((byte)m.peer); w.Write(m.nick); w.Write((byte)m.side); }
        ToAll(true);
    }

    // Хост: раздать места живым игрокам и начать бой у всех
    public static void HostStart(BattleConfig cfg)
    {
        if (!IsHost) return;
        cfg.humans = new List<NetHuman>();
        foreach (var m in Members)
        {
            Team t = Mode == NetMode.Mission || m.side == 0 ? Team.Foundation : Team.Chaos;
            var list = t == Team.Foundation ? cfg.foundation : cfg.chaos;
            if (list.Count == 0)
            {
                // у стороны нет отрядов — добавляем базовый
                var def = t == Team.Foundation ? DB.Foundation[0] : DB.Chaos[0];
                list.Add(new SquadPick { def = def, count = 4 });
            }
            int sq = t == Team.Foundation ? Mathf.Clamp(cfg.playerSquad, 0, list.Count - 1) : 0;
            for (int i = 0; i < list.Count && list[sq].placed; i++) sq = i;
            cfg.humans.Add(new NetHuman { peer = m.peer, nick = m.nick, team = t, squad = sq });
        }
        // в отряде хватит мест для всех живых игроков
        foreach (var h in cfg.humans)
        {
            var p = (h.team == Team.Foundation ? cfg.foundation : cfg.chaos)[h.squad];
            int n = 0; foreach (var x in cfg.humans) if (x.team == h.team && x.squad == h.squad) n++;
            if (p.count < n + 1) p.count = n + 1;
            p.placed = false; p.delay = 0f;
        }
        cfg.introOn = Game.Intro;
        foreach (var m in Members) m.loaded = m.peer == 0;
        Go = false; endSent = false;
        var w = W(M.Start); WriteCfg(w, cfg); ToAll(true);
        InGame = true;
        ResetIds();
        Game.I.StartBattle(cfg);
    }

    public static void ResetIds() { byId.Clear(); proxyOf.Clear(); nextId = 0; }

    // Сериализация конфигурации боя
    static void WriteCfg(BinaryWriter w, BattleConfig c)
    {
        w.Write(c.op != null ? c.op.id : "");
        w.Write(c.seed); w.Write((byte)c.map); w.Write((byte)c.time); w.Write(c.scpAllyChaos); w.Write(c.friendlyFire);
        w.Write((byte)c.playerSquad); w.Write(c.captureEnds); w.Write(c.introOn);
        void Picks(List<SquadPick> l)
        {
            w.Write((byte)l.Count);
            foreach (var p in l) { w.Write(p.def.id); w.Write((byte)p.count); w.Write(p.delay); w.Write(p.placed); w.Write(p.garrison); w.Write(p.pos.x); w.Write(p.pos.z); }
        }
        Picks(c.foundation); Picks(c.chaos);
        w.Write((byte)c.scps.Count);
        foreach (var s in c.scps) { w.Write(s.def.id); w.Write((byte)s.count); w.Write(s.placed); w.Write(s.pos.x); w.Write(s.pos.z); }
        w.Write((byte)c.humans.Count);
        foreach (var h in c.humans) { w.Write((byte)h.peer); w.Write(h.nick); w.Write((byte)h.team); w.Write((byte)h.squad); }
    }

    static BattleConfig ReadCfg(BinaryReader r)
    {
        string opId = r.ReadString();
        var c = new BattleConfig();
        c.seed = r.ReadInt32(); c.map = r.ReadByte(); c.time = r.ReadByte(); c.scpAllyChaos = r.ReadBoolean(); c.friendlyFire = r.ReadBoolean();
        c.playerSquad = r.ReadByte(); c.captureEnds = r.ReadBoolean(); c.introOn = r.ReadBoolean();
        if (opId != "") { Operations.Init(); foreach (var o in Operations.All) if (o.id == opId) c.op = o; }
        SquadDef Find(string id, bool f)
        {
            if (c.op != null) foreach (var p in (f ? c.op.foundation : c.op.chaos)) if (p.def.id == id) return p.def;
            foreach (var d in f ? DB.Foundation : DB.Chaos) if (d.id == id) return d;
            return f ? DB.Foundation[0] : DB.Chaos[0];
        }
        void Picks(List<SquadPick> l, bool f)
        {
            int n = r.ReadByte();
            for (int i = 0; i < n; i++)
            {
                var p = new SquadPick { def = Find(r.ReadString(), f), count = r.ReadByte(), delay = r.ReadSingle(), placed = r.ReadBoolean(), garrison = r.ReadBoolean() };
                p.pos = new Vector3(r.ReadSingle(), 0, r.ReadSingle());
                l.Add(p);
            }
        }
        Picks(c.foundation, true); Picks(c.chaos, false);
        int ns = r.ReadByte();
        for (int i = 0; i < ns; i++)
        {
            string id = r.ReadString();
            ScpDef def = null; foreach (var d in DB.Scps) if (d.id == id) def = d;
            var s = new ScpPick { def = def, count = r.ReadByte(), placed = r.ReadBoolean() };
            s.pos = new Vector3(r.ReadSingle(), 0, r.ReadSingle());
            if (def != null) c.scps.Add(s);
        }
        int nh = r.ReadByte();
        c.humans = new List<NetHuman>();
        for (int i = 0; i < nh; i++) c.humans.Add(new NetHuman { peer = r.ReadByte(), nick = r.ReadString(), team = (Team)r.ReadByte(), squad = r.ReadByte() });
        c.playerFps = true;
        return c;
    }

    // ---------------- юниты ----------------
    // Одинаковый порядок создания на всех машинах даёт одинаковые номера
    public static void Assign(Unit u)
    {
        if (!InGame || u == null || u.netId >= 0) return;
        u.netId = nextId++;
        byId[u.netId] = u;
        if (IsClient && !(u is PlayerUnit)) u.netPuppet = true;
        if (u is Soldier s && s.remoteHuman) { s.netPuppet = true; if (IsHost) proxyOf[s.netPeer] = s; }
    }

    // Хост взял под контроль бойца: его номер переходит к новому телу игрока
    public static void Rebind(Unit u, int id)
    {
        if (!InGame || u == null || id < 0) return;
        u.netId = id; byId[id] = u; u.netPuppet = false;
    }

    public static Unit Get(int id) => id >= 0 && byId.TryGetValue(id, out var u) ? u : null;
    static int Id(Unit u) => u != null ? u.netId : -1;

    // Хост: объект появился посреди боя (выпущен из контейнера) — сообщаем клиентам
    public static void HostSpawned(Unit u)
    {
        if (!IsHost || !InGame || u == null) return;
        if (u.netId >= 0) return;
        Assign(u);
        if (u is ScpUnit su) { var w = W(M.Spawn); w.Write(u.netId); w.Write((byte)su.kind); V(w, u.transform.position); w.Write(u.transform.eulerAngles.y); ToAll(true); }
    }

    public static void HostReanimated(Unit u)
    {
        if (!IsHost || !InGame || u == null || u.netId < 0) return;
        var w = W(M.Reanimate); w.Write(u.netId); ToAll(true);
    }

    // ---------------- урон ----------------
    // Вызывается из Unit.TakeDamage. true — урон здесь не применять.
    public static bool InterceptDamage(Unit u, DamageInfo d)
    {
        if (!InGame || Applying) return false;
        if (IsHost)
        {
            if (Cosmetic) return true;
            if (u is Soldier s && s.remoteHuman)
            {
                // по живому игроку-клиенту: урон считает его машина
                var w = W(M.Damage); w.Write(d.amount); w.Write((byte)d.type); V(w, d.dir); V(w, d.point); w.Write(d.force); w.Write(Id(d.attacker)); w.Write(d.weapon ?? "");
                Send(s.netPeer, true);
                return true;
            }
            return false;
        }
        // клиент
        if (Cosmetic) return true;
        var local = PlayerController.I != null ? PlayerController.I.unit : null;
        if (u == local) return !(d.attacker == null && (d.type == DamageType.Fall || d.type == DamageType.Crush));
        if (local != null && d.attacker == local && u.netId >= 0)
        {
            int hb = -1;
            if (d.hitbox != null) { var all = u.GetComponentsInChildren<Hitbox>(); hb = System.Array.IndexOf(all, d.hitbox); }
            var w = W(M.Hit); w.Write(u.netId); w.Write(d.amount); w.Write((byte)d.type); V(w, d.dir); V(w, d.point); w.Write(d.force); w.Write((short)hb); w.Write(d.weapon ?? "");
            ToHost(true);
        }
        return true;
    }

    // Хост: юнит погиб — клиенты повторяют гибель у себя
    public static void OnDeath(Unit u, DamageInfo d)
    {
        if (!IsHost || !InGame || u.netId < 0) return;
        int hb = -1;
        if (d.hitbox != null) { var all = u.GetComponentsInChildren<Hitbox>(); hb = System.Array.IndexOf(all, d.hitbox); }
        var w = W(M.Death); w.Write(u.netId); w.Write(Id(d.attacker)); w.Write((byte)d.type); V(w, d.dir); V(w, d.point); w.Write(d.force); w.Write((short)hb); w.Write(d.weapon ?? "");
        ToAll(true);
    }

    // Клиент: свой боец погиб
    public static void LocalDied(DamageInfo d)
    {
        if (!IsClient || !InGame) return;
        var w = W(M.PlayerDied); w.Write(Id(d.attacker)); w.Write((byte)d.type); V(w, d.dir); w.Write(d.force); ToHost(true);
    }

    static void ApplyKill(Unit u, Unit attacker, DamageType type, Vector3 dir, Vector3 point, float force, int hb, string weapon)
    {
        if (u == null || !u.alive) return;
        Hitbox hitbox = null;
        if (hb >= 0) { var all = u.GetComponentsInChildren<Hitbox>(); if (hb < all.Length) hitbox = all[hb]; }
        Applying = true;
        try { u.TakeDamage(new DamageInfo { amount = 1e6f, attacker = attacker, type = type, dir = dir, point = point, force = force, hitbox = hitbox, weapon = weapon }); }
        finally { Applying = false; }
    }

    // ---------------- выстрелы и броски ----------------
    public static void OnFire(Unit owner, WeaponDef def, Vector3 origin, Vector3 dir, float spread, Vector3 muzzle)
    {
        if (!InGame || Cosmetic || owner == null || owner.netId < 0) return;
        bool mine = IsClient && PlayerController.I != null && owner == PlayerController.I.unit;
        if (IsClient && !mine) return;
        var w = W(M.Shot); w.Write(owner.netId); w.Write(def.id); V(w, origin); V(w, dir); w.Write(spread); V(w, muzzle);
        if (IsHost) ToAll(def.kind == WeaponKind.Launcher); else ToHost(def.kind == WeaponKind.Launcher);
    }

    public static void OnThrow(Unit owner, Vector3 pos, Vector3 vel, bool impact, float damage)
    {
        if (!InGame || Cosmetic || InFire || owner == null || owner.netId < 0) return;
        if (relayThrow >= 0) { foreach (var p in T.Peers) if (p != relayThrow) { var w2 = W(M.Throw); w2.Write(owner.netId); V(w2, pos); V(w2, vel); w2.Write(impact); w2.Write(damage); Send(p, true); } return; }
        bool mine = IsClient && PlayerController.I != null && owner == PlayerController.I.unit;
        if (IsClient && !mine) return;
        var w = W(M.Throw); w.Write(owner.netId); V(w, pos); V(w, vel); w.Write(impact); w.Write(damage);
        if (IsHost) ToAll(true); else ToHost(true);
    }

    // ---------------- интерфейс ----------------
    public static void OnMessage(string text, Color c, float life)
    {
        if (!IsHost || !InGame || (Battle.I != null && Battle.I.intro)) return;
        var w = W(M.Msg); w.Write(text); Col(w, c); w.Write(life); ToAll(true);
    }

    public static void OnSpeech(Transform who, string name, string text, float dur, Color c, string voice)
    {
        if (!IsHost || !InGame || who == null || (Battle.I != null && Battle.I.intro)) return;
        var u = who.GetComponent<Unit>();
        if (u == null || u.netId < 0) return;
        var w = W(M.Speech); w.Write(u.netId); w.Write(name ?? ""); w.Write(text); w.Write(dur); Col(w, c); w.Write(voice ?? ""); ToAll(true);
    }

    public static void OnLaunch(Helicopter h)
    {
        if (!IsHost || !InGame || Battle.I == null) return;
        int i = Battle.I.helis.IndexOf(h);
        if (i < 0) return;
        var w = W(M.Launch); w.Write((byte)i); ToAll(true);
    }

    public static void RequestPickup(int loreIndex)
    {
        if (!IsClient) return;
        var w = W(M.PickLore); w.Write((byte)loreIndex); ToHost(true);
    }

    // Клиент загрузил карту и ждёт команды хоста; хост ждёт всех
    public static void ReportLoaded()
    {
        if (IsClient) { var w = W(M.Loaded); ToHost(true); }
    }

    public static bool AllLoaded
    {
        get { foreach (var m in Members) if (!m.loaded) return false; return true; }
    }

    public static void SendGo() { Go = true; var w = W(M.GoMsg); ToAll(true); }

    public static string NickOf(int peer) { foreach (var m in Members) if (m.peer == peer) return m.nick; return "Игрок"; }

    // ---------------- цикл ----------------
    public static void Update()
    {
        if (T == null) return;
        T.Tick();
        while (T != null && T.Receive(out int peer, out byte[] data))
        {
            try { Handle(peer, data); }
            catch (System.Exception e) { Debug.LogWarning("Net: " + e); }
        }
        if (T == null) return;
        foreach (var p in T.Dropped) PeerLeft(p);
        T.Dropped.Clear();
        if (!InGame || Battle.I == null || Battle.I.loading) return;
        float now = Time.unscaledTime;
        if (IsHost)
        {
            if (now > snapT) { snapT = now + 1f / 15f; SendSnapshots(); }
            if (now > slowT) { slowT = now + 0.5f; SendBattleState(); SendLore(); }
            var b = Battle.I;
            if (b.over && !endSent) { endSent = true; var w = W(M.End); w.Write(b.winnerText ?? ""); Col(w, b.winnerColor); w.Write(b.debrief ?? ""); ToAll(true); }
        }
        else if (now > stateT) { stateT = now + 1f / 20f; SendMyState(); }
    }

    static void PeerLeft(int peer)
    {
        if (IsHost)
        {
            string n = NickOf(peer);
            Members.RemoveAll(m => m.peer == peer);
            BroadcastLobby();
            if (proxyOf.TryGetValue(peer, out var s) && s != null && s.alive) { Applying = true; try { s.Kill(DamageType.Fall); } finally { Applying = false; } }
            proxyOf.Remove(peer);
            if (Battle.I != null) Battle.Message(n + " отключился", new Color(1f, 0.6f, 0.4f));
            Status = n + " отключился";
        }
        else
        {
            Status = "Связь с хостом потеряна";
            if (Battle.I != null) Battle.Message("Связь с хостом потеряна", new Color(1f, 0.4f, 0.3f), 8f);
            T.Close(); T = null; InGame = false;
        }
    }

    static void Handle(int peer, byte[] data)
    {
        var r = new BinaryReader(new MemoryStream(data));
        var type = (M)r.ReadByte();
        switch (type)
        {
            // ---- лобби ----
            case M.Hello:
                if (!IsHost) break;
                {
                    int ver = r.ReadInt32(); string nick = r.ReadString();
                    if (ver != Version) { Status = nick + ": другая версия игры"; break; }
                    if (Members.Exists(m => m.peer == peer)) break;
                    Members.Add(new Member { peer = peer, nick = nick, side = 0 });
                    var w = W(M.Welcome); w.Write((byte)peer); Send(peer, true);
                    BroadcastLobby();
                    Status = nick + " подключился";
                }
                break;
            case M.Welcome: MyPeer = r.ReadByte(); Status = "Подключено. Ждём хоста…"; break;
            case M.Lobby:
            {
                Mode = (NetMode)r.ReadByte();
                int n = r.ReadByte();
                Members.Clear();
                for (int i = 0; i < n; i++) Members.Add(new Member { peer = r.ReadByte(), nick = r.ReadString(), side = r.ReadByte() });
                break;
            }
            case M.SetSide:
                if (IsHost) { int s = r.ReadByte(); foreach (var m in Members) if (m.peer == peer) m.side = s; BroadcastLobby(); }
                break;
            case M.Start:
                if (IsClient)
                {
                    var cfg = ReadCfg(r);
                    InGame = true; Go = false; ResetIds();
                    Game.I.StartBattle(cfg);
                }
                break;
            case M.Loaded: foreach (var m in Members) if (m.peer == peer) m.loaded = true; break;
            case M.GoMsg: Go = true; break;
            case M.Leave: PeerLeft(peer); break;

            // ---- бой ----
            case M.Snap: if (IsClient) ReadSnapshot(r); break;
            case M.Heli: if (IsClient) ReadHelis(r); break;
            case M.MyState: if (IsHost) ReadClientState(peer, r); break;
            case M.Shot:
            {
                var owner = Get(r.ReadInt32()); var def = DB.W(r.ReadString());
                Vector3 o = RV(r), dir = RV(r); float sp = r.ReadSingle(); Vector3 mz = RV(r);
                if (owner == null || def == null) break;
                if (IsHost) { ms.SetLength(0); ms.Write(data, 0, data.Length); foreach (var p in T.Peers) if (p != peer) Send(p, def.kind == WeaponKind.Launcher); }
                Cosmetic = true;
                try { Ballistics.Fire(def, owner, o, dir, sp, mz); }
                finally { Cosmetic = false; }
                if (owner is Soldier so && so.anim != null) so.anim.Kick(def.recoil * 0.8f, def.recoil);
                break;
            }
            case M.Throw:
            {
                var owner = Get(r.ReadInt32()); Vector3 p0 = RV(r), v = RV(r); bool imp = r.ReadBoolean(); float dmg = r.ReadSingle();
                if (IsHost)
                {
                    // бросок клиента: настоящая граната у хоста (урон считает хост), остальным — копия
                    relayThrow = peer;
                    try { Grenade.Spawn(p0, v, owner, imp, dmg); }
                    finally { relayThrow = -1; }
                }
                else { Cosmetic = true; try { Grenade.Spawn(p0, v, owner, imp, dmg); } finally { Cosmetic = false; } }
                break;
            }
            case M.Death:
            {
                var u = Get(r.ReadInt32()); var at = Get(r.ReadInt32());
                var t = (DamageType)r.ReadByte(); Vector3 dir = RV(r), pt = RV(r); float f = r.ReadSingle(); int hb = r.ReadInt16(); string wpn = r.ReadString();
                if (u != null && u != (PlayerController.I != null ? PlayerController.I.unit : null)) ApplyKill(u, at, t, dir, pt, f, hb, wpn);
                break;
            }
            case M.Hit:
                if (IsHost)
                {
                    var u = Get(r.ReadInt32()); float amt = r.ReadSingle(); var t = (DamageType)r.ReadByte(); Vector3 dir = RV(r), pt = RV(r); float f = r.ReadSingle(); int hb = r.ReadInt16(); string wpn = r.ReadString();
                    if (u == null || !u.alive) break;
                    proxyOf.TryGetValue(peer, out var att);
                    Hitbox hitbox = null;
                    if (hb >= 0) { var all = u.GetComponentsInChildren<Hitbox>(); if (hb < all.Length) hitbox = all[hb]; }
                    amt = Mathf.Min(amt, 400f);   // защита от нечестных значений
                    Applying = true;
                    try { u.TakeDamage(new DamageInfo { amount = amt, attacker = att, type = t, dir = dir, point = pt, force = f, hitbox = hitbox, weapon = wpn }); }
                    finally { Applying = false; }
                }
                break;
            case M.Damage:
                if (IsClient && PlayerController.I != null)
                {
                    float amt = r.ReadSingle(); var t = (DamageType)r.ReadByte(); Vector3 dir = RV(r), pt = RV(r); float f = r.ReadSingle(); var at = Get(r.ReadInt32()); string wpn = r.ReadString();
                    Applying = true;
                    try { PlayerController.I.unit.TakeDamage(new DamageInfo { amount = amt, type = t, dir = dir, point = pt, force = f, attacker = at, weapon = wpn }); }
                    finally { Applying = false; }
                }
                break;
            case M.PlayerDied:
                if (IsHost && proxyOf.TryGetValue(peer, out var px) && px != null && px.alive)
                {
                    var at = Get(r.ReadInt32()); var t = (DamageType)r.ReadByte(); Vector3 dir = RV(r); float f = r.ReadSingle();
                    ApplyKill(px, at, t, dir, px.AimPoint, f, -1, null);
                    Battle.Message(NickOf(peer) + " погиб", new Color(1f, 0.55f, 0.4f));
                }
                break;
            case M.Msg: if (IsClient) { string tx = r.ReadString(); var c = RC(r); float l = r.ReadSingle(); Battle.Message(tx, c, l); } break;
            case M.Speech:
                if (IsClient)
                {
                    var u = Get(r.ReadInt32()); string nm = r.ReadString(), tx = r.ReadString(); float du = r.ReadSingle(); var c = RC(r); string vo = r.ReadString();
                    if (u != null) Speech.Say(u.transform, nm, tx, du, c, vo == "" ? null : vo);
                }
                break;
            case M.End:
                if (IsClient && Battle.I != null)
                {
                    var b = Battle.I; b.winnerText = r.ReadString(); b.winnerColor = RC(r); string db = r.ReadString(); b.debrief = db == "" ? null : db; b.over = true;
                    Sfx.Play2D("alarm", 0.6f, 0.8f);
                }
                break;
            case M.Spawn:
                if (IsClient)
                {
                    int id = r.ReadInt32(); var k = (ScpKind)r.ReadByte(); Vector3 p = RV(r); float yaw = r.ReadSingle();
                    var u = ScpFactory.Spawn(k, p, Quaternion.Euler(0, yaw, 0));
                    if (u != null) { u.netId = id; byId[id] = u; u.netPuppet = true; if (id >= nextId) nextId = id + 1; }
                }
                break;
            case M.Reanimate:
                if (IsClient && Get(r.ReadInt32()) is Soldier zs) zs.Reanimate();
                break;
            case M.Launch:
                if (IsClient && Battle.I != null) Battle.I.NetLaunch(r.ReadByte());
                break;
            case M.BState: if (IsClient) ReadBattleState(r); break;
            case M.Lore: if (IsClient) ReadLore(r); break;
            case M.PickLore:
                if (IsHost)
                {
                    int i = r.ReadByte();
                    if (i < LoreItem.All.Count && proxyOf.TryGetValue(peer, out var carrier) && carrier != null && carrier.alive) LoreItem.All[i].NetAttach(carrier);
                }
                break;
        }
    }

    // ---------------- снимки ----------------
    // Запись юнита: номер, позиция, курс, наклон взгляда, флаги, здоровье, оружие, состояние объекта
    static void SendSnapshots()
    {
        var list = new List<Unit>();
        foreach (var kv in byId) if (kv.Value != null && (kv.Value.alive || Time.time - kv.Value.deathTime < 0.5f)) list.Add(kv.Value);
        foreach (int peer in T.Peers)
        {
            proxyOf.TryGetValue(peer, out var own);
            int i = 0;
            while (i < list.Count)
            {
                var w = W(M.Snap);
                long countPos = ms.Position; w.Write((byte)0);
                int n = 0;
                for (; i < list.Count && n < 45; i++)
                {
                    var u = list[i];
                    if (u == own) continue;
                    WriteUnit(w, u); n++;
                }
                long end = ms.Position; ms.Position = countPos; w.Write((byte)n); ms.Position = end;
                if (n > 0) Send(peer, false);
            }
        }
        // вертолёты
        var b = Battle.I;
        var hw = W(M.Heli); hw.Write((byte)b.helis.Count);
        foreach (var h in b.helis)
        {
            bool ok = h != null;
            hw.Write(ok);
            if (!ok) continue;
            V(hw, h.transform.position); var q = h.transform.rotation; hw.Write(q.x); hw.Write(q.y); hw.Write(q.z); hw.Write(q.w);
            V(hw, h.velocity); hw.Write(h.NetPhase);
        }
        ToAll(false);
    }

    static void WriteUnit(BinaryWriter w, Unit u)
    {
        w.Write((ushort)u.netId);
        V(w, u.transform.position);
        Vector3 look = u.LookDir;
        w.Write((byte)(Mathf.Repeat(u.transform.eulerAngles.y, 360f) / 360f * 255f));
        float pitch = Mathf.Asin(Mathf.Clamp(look.y, -1f, 1f)) * Mathf.Rad2Deg;
        float lyaw = Mathf.Atan2(look.x, look.z) * Mathf.Rad2Deg;
        w.Write((sbyte)Mathf.Clamp(pitch, -90f, 90f));
        w.Write((byte)(Mathf.Repeat(lyaw, 360f) / 360f * 255f));
        byte f = 0, wpn = 0, extra = 0;
        if (u is Soldier s)
        {
            if (s.anim != null && s.anim.crouch) f |= 1;
            if (s.anim != null && s.anim.seated) f |= 2;
            if (s.anim != null && s.anim.sprint) f |= 32;
            wpn = (byte)(s.current == s.secondary && s.secondary != null ? 1 : s.current == s.special && s.special != null ? 2 : 0);
            if (s.zombie) f |= 64;
        }
        else if (u is PlayerUnit pu && pu.pc != null)
        {
            if (pu.pc.crouching || pu.pc.prone) f |= 1;
            if (pu.pc.riding) f |= 2;
            if (pu.pc.sprintW > 0.5f) f |= 32;
            wpn = (byte)pu.pc.CurIndex;
        }
        else if (u is ScpUnit su)
        {
            if (su.subdued) f |= 4;
            if (su.captured) f |= 8;
            if (su.itemApplied) f |= 16;
            extra = su.NetState();
            wpn = (byte)Mathf.RoundToInt(Mathf.Clamp01(su.capture[0]) * 255f);
        }
        if (u.inVehicle) f |= 128;
        w.Write(f);
        w.Write((byte)Mathf.RoundToInt(Mathf.Clamp01(u.hp / Mathf.Max(1f, u.maxHp)) * 255f));
        w.Write(wpn); w.Write(extra);
    }

    static void ReadSnapshot(BinaryReader r)
    {
        int n = r.ReadByte();
        for (int i = 0; i < n; i++)
        {
            int id = r.ReadUInt16();
            Vector3 p = RV(r);
            float yaw = r.ReadByte() / 255f * 360f;
            float pitch = r.ReadSByte();
            float lyaw = r.ReadByte() / 255f * 360f;
            byte f = r.ReadByte(), hp = r.ReadByte(), wpn = r.ReadByte(), extra = r.ReadByte();
            var u = Get(id);
            if (u == null || u == (PlayerController.I != null ? PlayerController.I.unit : null)) continue;
            u.NetReceive(p, yaw, pitch, lyaw, f, hp / 255f * u.maxHp, wpn, extra);
        }
    }

    static void ReadHelis(BinaryReader r)
    {
        var b = Battle.I; if (b == null) return;
        int n = r.ReadByte();
        for (int i = 0; i < n; i++)
        {
            if (!r.ReadBoolean()) continue;
            Vector3 p = RV(r); var q = new Quaternion(r.ReadSingle(), r.ReadSingle(), r.ReadSingle(), r.ReadSingle());
            Vector3 v = RV(r); byte ph = r.ReadByte();
            if (i < b.helis.Count && b.helis[i] != null) b.helis[i].NetDrive(p, q, v, ph);
        }
    }

    // ---------------- клиент → хост: своё состояние ----------------
    static void SendMyState()
    {
        var pc = PlayerController.I;
        if (pc == null || pc.dead || pc.unit.netId < 0) return;
        var w = W(M.MyState);
        V(w, pc.transform.position);
        Vector3 look = pc.AimForward;
        w.Write(pc.transform.eulerAngles.y);
        w.Write(Mathf.Asin(Mathf.Clamp(look.y, -1f, 1f)) * Mathf.Rad2Deg);
        byte f = 0;
        if (pc.crouching || pc.prone) f |= 1;
        if (pc.riding) f |= 2;
        if (pc.sprintW > 0.5f) f |= 32;
        if (pc.unit.inVehicle) f |= 128;
        w.Write(f);
        w.Write(pc.unit.hp);
        w.Write((byte)pc.CurIndex);
        ToHost(false);
    }

    static void ReadClientState(int peer, BinaryReader r)
    {
        if (!proxyOf.TryGetValue(peer, out var s) || s == null || !s.alive) return;
        Vector3 p = RV(r); float yaw = r.ReadSingle(), pitch = r.ReadSingle(); byte f = r.ReadByte(); float hp = r.ReadSingle(); byte wpn = r.ReadByte();
        s.NetReceive(p, yaw, pitch, yaw, f, hp, wpn, 0);
    }

    // ---------------- состояние боя (захват, приказы), предметы ----------------
    static void SendBattleState()
    {
        var b = Battle.I;
        var w = W(M.BState);
        w.Write(b.captureTarget != null ? b.captureTarget.netId : -1);
        if (b.captureTarget != null) { w.Write(b.captureTarget.capture[0]); w.Write(b.captureTarget.capture[1]); }
        w.Write((byte)b.squads.Count);
        foreach (var sq in b.squads) w.Write(sq.orderText ?? "");
        ToAll(false);
    }

    static void ReadBattleState(BinaryReader r)
    {
        var b = Battle.I; if (b == null) return;
        int id = r.ReadInt32();
        b.captureTarget = Get(id) as ScpUnit;
        if (id >= 0) { float c0 = r.ReadSingle(), c1 = r.ReadSingle(); if (b.captureTarget != null) { b.captureTarget.capture[0] = c0; b.captureTarget.capture[1] = c1; } }
        int n = r.ReadByte();
        for (int i = 0; i < n; i++) { string o = r.ReadString(); if (i < b.squads.Count) b.squads[i].orderText = o; }
    }

    static void SendLore()
    {
        var w = W(M.Lore); w.Write((byte)LoreItem.All.Count);
        foreach (var li in LoreItem.All)
        {
            w.Write(li != null && li.used);
            w.Write(li != null && li.carrier != null ? li.carrier.netId : -1);
            V(w, li != null ? li.transform.position : Vector3.zero);
            w.Write(li != null ? li.applyK : 0f);
        }
        ToAll(false);
    }

    static void ReadLore(BinaryReader r)
    {
        int n = r.ReadByte();
        for (int i = 0; i < n; i++)
        {
            bool used = r.ReadBoolean(); int cid = r.ReadInt32(); Vector3 p = RV(r); float k = r.ReadSingle();
            if (i >= LoreItem.All.Count || LoreItem.All[i] == null) continue;
            var c = Get(cid);
            // свой боец на клиенте — это местный игрок
            if (c == null && cid >= 0 && PlayerController.I != null && PlayerController.I.unit.netId == cid) c = PlayerController.I.unit;
            LoreItem.All[i].NetApply(used, c, p, k);
        }
    }

    // ---------------- запись ----------------
    static void V(BinaryWriter w, Vector3 v) { w.Write(v.x); w.Write(v.y); w.Write(v.z); }
    static Vector3 RV(BinaryReader r) => new Vector3(r.ReadSingle(), r.ReadSingle(), r.ReadSingle());
    static void Col(BinaryWriter w, Color c) { w.Write((byte)(Mathf.Clamp01(c.r) * 255)); w.Write((byte)(Mathf.Clamp01(c.g) * 255)); w.Write((byte)(Mathf.Clamp01(c.b) * 255)); }
    static Color RC(BinaryReader r) => new Color(r.ReadByte() / 255f, r.ReadByte() / 255f, r.ReadByte() / 255f);
}

public class NetRunner : MonoBehaviour
{
    void Update() { SteamNet.RunCallbacks(); Net.Update(); }
    void OnApplicationQuit() { Net.Shutdown(); SteamNet.Shutdown(); }
}
