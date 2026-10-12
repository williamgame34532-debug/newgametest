using System.Collections.Generic;
using UnityEngine;

// delay — задержка вылета (подкрепление), с; placed — уже на месте без вертолёта (гарнизон, беглецы)
public class SquadPick { public SquadDef def; public int count; public float delay; public bool placed, garrison; public Vector3 pos; }
public class ScpPick { public ScpDef def; public int count; public bool placed; public Vector3 pos; }

public class BattleConfig
{
    public readonly List<SquadPick> foundation = new List<SquadPick>();
    public readonly List<SquadPick> chaos = new List<SquadPick>();
    public readonly List<ScpPick> scps = new List<ScpPick>();
    public int map, time;
    public bool scpAllyChaos;
    public bool playerFps = true;
    public bool friendlyFire;
    public int playerSquad;
    public int seed = 1;
    public List<NetHuman> humans;     // сетевая игра: живые игроки по отрядам (null — одиночная)
    public bool introOn;
    public OperationDef op;          // сценарий «Реальные операции» (или null)
    public bool captureEnds = true;
}

// Менеджер боя: высадка всех сторон, союзы, победа, лента событий
public partial class Battle : MonoBehaviour
{
    public static Battle I;
    public static BattleConfig Cfg;
    public static Color DustColor = new Color(0.45f, 0.4f, 0.32f, 0.45f);
    public static float FriendlyFire => Cfg != null && Cfg.friendlyFire ? 0.5f : 0f;

    public readonly List<SquadRt> squads = new List<SquadRt>();
    public readonly List<Helicopter> helis = new List<Helicopter>();
    public readonly List<ScpContainer> containers = new List<ScpContainer>();
    public readonly List<FeedEntry> feed = new List<FeedEntry>();
    public readonly List<FeedEntry> messages = new List<FeedEntry>();
    public bool over;
    public string debrief;

    void Debrief(bool foundationWon)
    {
        var op = Cfg != null ? Cfg.op : null;
        if (op == null) return;
        debrief = (foundationWon ? "ОПЕРАЦИЯ ВЫПОЛНЕНА. " + op.win : "ОПЕРАЦИЯ ПРОВАЛЕНА. " + op.lose);
    }
    public string winnerText;
    public Color winnerColor;
    public float startTime;
    public readonly int[] teamKills = new int[3];
    public readonly int[] teamLosses = new int[3];
    public bool has173;
    float checkT;

    public class FeedEntry { public string text; public Color color; public float time; public bool player; public float life = 5f; }

    public static bool Hostile(Team a, Team b)
    {
        if (a == b) return false;
        if (Cfg != null && Cfg.scpAllyChaos && ((a == Team.Chaos && b == Team.SCP) || (a == Team.SCP && b == Team.Chaos))) return false;
        return true;
    }

    public static string TeamName(Team t) => t == Team.Foundation ? "Фонд SCP" : t == Team.Chaos ? "Повстанцы Хаоса" : "SCP-объекты";
    public static Color TeamColor(Team t) => t == Team.Foundation ? new Color(0.4f, 0.7f, 1f) : t == Team.Chaos ? new Color(0.45f, 0.9f, 0.35f) : new Color(1f, 0.3f, 0.25f);

    // ---------------- запуск ----------------
    public static void Begin(BattleConfig cfg)
    {
        End();
        Cfg = cfg;
        var go = new GameObject("Battle");
        I = go.AddComponent<Battle>();
        I.StartCoroutine(I.SetupRoutine());
    }

    public static void End()
    {
        if (I != null) Destroy(I.gameObject);
        I = null;
        foreach (var h in Helicopter.Active.ToArray()) if (h != null) Destroy(h.gameObject);
        Helicopter.Active.Clear();
        foreach (var u in Unit.All.ToArray()) if (u != null && !u.isPlayer) Destroy(u.gameObject);
        // убитые и захваченные уже не в списке живых — удаляем все объекты юнитов
        foreach (var u in Compat.FindAll<Unit>()) if (u != null && !u.isPlayer) Destroy(u.gameObject);
        Sfx.StopAll(); Speech.Clear(); Cinematic.Reset(); FacilityLink.Prompt = null; Facility.RootT = null;
        foreach (var c in Ragdoll.Corpses.ToArray()) if (c != null) Destroy(c.gameObject);
        Ragdoll.Corpses.Clear();
        foreach (var o in Compat.FindAll<ScpContainer>()) Destroy(o.gameObject);
        foreach (var o in Compat.FindAll<Wreck>()) Destroy(o.gameObject);
        foreach (var o in Compat.FindAll<Grenade>()) Destroy(o.gameObject);
        foreach (var o in Compat.FindAll<Rocket>()) Destroy(o.gameObject);
        foreach (var g in Compat.FindAll<GunModel>()) if (g.transform.root.GetComponent<PlayerController>() == null) Destroy(g.gameObject);
        foreach (var r in Compat.FindAll<Rigidbody>()) if (r != null && r.gameObject.name == "chunk") Destroy(r.gameObject);
        PlayerController.Remove();
        Scp096.PlayerExposure = 0f;
        Fx.Clear();
        LoreItem.Clear();
        MapGen.Clear();
        Time.timeScale = 1f;
    }

    public const float FarEntry = 2300f;   // вертолёты Хаоса и SCP заходят из-за гор по долинам
    MapGen.FobInfo fob;
    Helicopter playerHeli; SquadRt playerSqRt;
    public bool loading;
    public float loadProgress;
    public TeamCommander cmdF, cmdC;

    System.Collections.IEnumerator SetupRoutine()
    {
        loading = true;
        var cfg = Cfg;
        Random.InitState(cfg.seed);   // одинаковая раскладка у всех участников сетевой игры
        netSetupDone = false;
        startTime = Time.time;
        Ragdoll.MaxCorpses = Game.CorpseLimit;
        Fx.BloodLevel = Game.Blood;

        // зоны высадки
        var lzF = new List<Vector3>();
        var lzC = new List<Vector3>();
        var lzS = new List<Vector3>();
        int nF = cfg.foundation.Count, nC = cfg.chaos.Count, nS = cfg.scps.Count;
        // базы сторон далеко друг от друга — отряды успевают закрепиться, пока командир раздаёт приказы
        for (int i = 0; i < nF; i++) lzF.Add(cfg.foundation[i].placed ? cfg.foundation[i].pos : new Vector3((i - (nF - 1) / 2f) * 30f, 0, -195f - (i % 2) * 10f));
        for (int i = 0; i < nC; i++) lzC.Add(cfg.chaos[i].placed ? cfg.chaos[i].pos : new Vector3((i - (nC - 1) / 2f) * 28f, 0, 195f + (i % 2) * 10f));
        // SCP-объекты — у комплекса в центре: за них и идёт бой
        for (int i = 0; i < nS; i++)
        {
            float a = (90f + (i % 2) * 180f + (i / 2) * 40f * ((i / 2) % 2 == 0 ? 1 : -1)) * Mathf.Deg2Rad;
            float r = 48f + (i / 2) * 6f;
            lzS.Add(cfg.scps[i].placed ? cfg.scps[i].pos : new Vector3(Mathf.Sin(a) * r, 0, Mathf.Cos(a) * r * 0.6f));
        }
        // площадки только там, где садятся вертолёты; гарнизоны и объекты сценариев стоят среди построек
        var all = new List<Vector3>();
        for (int i = 0; i < nF; i++) if (!cfg.foundation[i].placed) all.Add(lzF[i]);
        for (int i = 0; i < nC; i++) if (!cfg.chaos[i].placed) all.Add(lzC[i]);
        for (int i = 0; i < nS; i++) if (!cfg.scps[i].placed) all.Add(lzS[i]);
        MapGen.Build(cfg.map, cfg.time, all, cfg.seed);
        yield return null;
        var nav = MapGen.BakeNavAsync();
        while (nav != null && !nav.isDone) { loadProgress = nav.progress; yield return null; }
        Facility.AfterBake();
        loadProgress = 1f;
        // сетевая игра: все загрузили карту — начинаем одновременно
        if (Net.InGame)
        {
            if (Net.IsHost)
            {
                float until = Time.realtimeSinceStartup + 90f;
                while (!Net.AllLoaded && Time.realtimeSinceStartup < until) yield return null;
                Net.SendGo();
            }
            else
            {
                Net.ReportLoaded();
                while (!Net.Go && Net.InGame) yield return null;
            }
            Random.InitState(cfg.seed + 1);
        }
        loading = false;
        Ambience.Create(cfg.time == 2, cfg.map).transform.SetParent(transform);
        for (int i = 0; i < lzF.Count; i++) lzF[i] = new Vector3(lzF[i].x, cfg.foundation[i].placed ? MapGen.Height(lzF[i].x, lzF[i].z) : GroundHeight(lzF[i]), lzF[i].z);
        for (int i = 0; i < lzC.Count; i++) lzC[i] = new Vector3(lzC[i].x, cfg.chaos[i].placed ? MapGen.Height(lzC[i].x, lzC[i].z) : GroundHeight(lzC[i]), lzC[i].z);
        for (int i = 0; i < lzS.Count; i++) lzS[i] = new Vector3(lzS[i].x, cfg.scps[i].placed ? MapGen.Height(lzS[i].x, lzS[i].z) : GroundHeight(lzS[i]), lzS[i].z);

        bool night = cfg.time == 2;
        // вступление на передовой базе: все вылеты сдвигаются на его длину
        List<IntroLine> introLines = null;
        float introDur = 0f;
        bool hasPlayerSquad = cfg.playerFps && cfg.foundation.Count > 0 && !cfg.foundation[Mathf.Clamp(cfg.playerSquad, 0, cfg.foundation.Count - 1)].placed;
        if (cfg.humans != null) hasPlayerSquad = HumansIn(cfg, Team.Foundation, Mathf.Clamp(cfg.playerSquad, 0, Mathf.Max(0, cfg.foundation.Count - 1))).Count > 0;
        if (hasPlayerSquad && (cfg.humans != null ? cfg.introOn : Game.Intro)) { introLines = Script(cfg); introDur = IntroLength(introLines); }
        playerHeli = null; SquadRt playerSq = null;
        // передовая база в южной долине: борта Фонда стоят на площадках
        fob = null;
        foreach (var f in cfg.foundation) if (!f.placed || cfg.playerFps) { fob = MapGen.BuildFob(MapGen.FobCenter(), cfg.map); break; }
        int padN = cfg.playerFps && cfg.foundation.Count > 0 ? 1 : 0;   // площадка 0 — борт игрока

        // ФОНД
        for (int i = 0; i < nF; i++)
        {
            var pick = cfg.foundation[i];
            var humans = HumansIn(cfg, Team.Foundation, i);
            bool playerHere = humans.Count > 0;
            var lz = lzF[i];
            if (pick.placed && !playerHere) { PlaceSquad(pick, Team.Foundation, lz, Vector3.back, night); continue; }
            var heli = Helicopter.Create(Team.Foundation, pick.def.label, new Color(0.12f, 0.13f, 0.15f), pick.def.look.accent, Mathf.Max(pick.count, 2), false);
            var sq = new SquadRt { def = pick.def, team = Team.Foundation, lz = lz, reinforce = pick.delay > 30f, arriveAt = Time.time + introDur + 4f + i * 4f + pick.delay };
            squads.Add(sq);
            int bots = Mathf.Max(0, pick.count - humans.Count);
            int seat = humans.Count;
            for (int k = 0; k < bots; k++)
            {
                var s = Soldier.Create(pick.def, heli.transform.position, heli.transform.rotation, k + humans.Count, night);
                Net.Assign(s);
                s.squadRt = sq; sq.members.Add(s);
                s.SitIn(heli.seats[(seat + k) % heli.seats.Count]);
                heli.passengers.Add(s);
            }
            if (SpawnHumans(humans, pick.def, heli, sq, night)) { playerHeli = heli; playerSq = sq; }
            Vector3 exit = new Vector3(lz.x * 0.3f, lz.y + 120f, -MapGen.OuterR + 300f);
            float delay = introDur + 4f + i * 4f + pick.delay;
            if (fob != null && (playerHere || padN < fob.pads.Count))
            {
                heli.LaunchFromPad(fob.pads[playerHere ? 0 : padN++], 0f, lz, exit, delay);
                // при вступлении другие группы тоже на базе: брифинг у своего борта и посадка
                if (!playerHere && introLines != null && !Net.IsClient) StartCoroutine(SquadAtFob(heli, sq));
            }
            else
            {
                Vector3 entry = new Vector3(lz.x * 0.3f + Random.Range(-30f, 30f), lz.y + 160f, -FarEntry);
                heli.Launch(entry, lz, exit, delay);
            }
            helis.Add(heli);
        }
        // ХАОС
        for (int i = 0; i < nC; i++)
        {
            var pick = cfg.chaos[i];
            var lz = lzC[i];
            var humansC = HumansIn(cfg, Team.Chaos, i);
            if (pick.placed && humansC.Count == 0) { PlaceSquad(pick, Team.Chaos, lz, Vector3.forward, night); continue; }
            bool rope = pick.def.fastRope;
            var heli = Helicopter.Create(Team.Chaos, pick.def.label, new Color(0.24f, 0.26f, 0.17f), pick.def.look.accent, Mathf.Max(pick.count, 2), rope);
            var sq = new SquadRt { def = pick.def, team = Team.Chaos, lz = lz, reinforce = pick.delay > 30f, arriveAt = Time.time + introDur + 6f + i * 4f + pick.delay };
            squads.Add(sq);
            int botsC = Mathf.Max(0, pick.count - humansC.Count);
            for (int k = 0; k < botsC; k++)
            {
                var s = Soldier.Create(pick.def, heli.transform.position, heli.transform.rotation, k + humansC.Count, night);
                Net.Assign(s);
                s.squadRt = sq; sq.members.Add(s);
                s.SitIn(heli.seats[(k + humansC.Count) % heli.seats.Count]);
                heli.passengers.Add(s);
                s.homeDir = Vector3.forward;
            }
            if (SpawnHumans(humansC, pick.def, heli, sq, night)) playerSqRt = sq;
            Vector3 entry = new Vector3(lz.x * 0.3f + Random.Range(-30f, 30f), lz.y + 260f, FarEntry);
            Vector3 exit = new Vector3(lz.x * 0.3f, lz.y + 160f, FarEntry + 300f);
            heli.Launch(entry, lz, exit, introDur + 6f + i * 4f + pick.delay);
            helis.Add(heli);
        }
        // SCP — в контейнерах на тросе
        for (int i = 0; i < nS; i++)
        {
            var pick = cfg.scps[i];
            var lz = lzS[i];
            if (pick.def.kind == ScpKind.S173) has173 = true;
            if (pick.placed)
            {
                // объект уже на свободе — без контейнера
                for (int k = 0; k < pick.count; k++)
                {
                    float a = k * 2.4f, r = k == 0 ? 0f : 3f + k * 1.3f;
                    Vector3 p = lz + new Vector3(Mathf.Cos(a) * r, 0, Mathf.Sin(a) * r);
                    p.y = MapGen.Height(p.x, p.z);
                    if (UnityEngine.AI.NavMesh.SamplePosition(p, out var nh, 8f, UnityEngine.AI.NavMesh.AllAreas)) p = nh.position;
                    var u = ScpFactory.Spawn(pick.def.kind, p, Quaternion.Euler(0, Random.Range(0f, 360f), 0));
                    Net.Assign(u);
                    if (u != null) Register(u);
                    if (u is ScpUnit su) su.Hold(false);
                    else if (u is Soldier zs) zs.BeginCombat(p);
                }
                continue;
            }
            var heli = Helicopter.Create(Team.SCP, "SCP " + pick.def.id, new Color(0.3f, 0.3f, 0.32f), new Color(0.95f, 0.7f, 0.1f), 2, false);
            var cont = ScpContainer.Create(pick.def.kind, pick.count);
            heli.AttachSling(cont);
            float side = Mathf.Sign(lz.x);
            Vector3 entry = new Vector3(side * FarEntry, lz.y + 260f, lz.z * 0.3f + Random.Range(-40f, 40f));
            Vector3 exit = new Vector3(side * (FarEntry + 300f), lz.y + 160f, lz.z * 0.3f);
            heli.Launch(entry, lz, exit, introDur + i * 3f);
            cont.transform.position = heli.transform.position + Vector3.down * (9f + cont.height);
            cont.transform.rotation = Quaternion.Euler(0, side > 0 ? -90 : 90, 0);
            containers.Add(cont);
            helis.Add(heli);
        }

        // командиры сторон
        Vector3 bF = Vector3.zero, bC = Vector3.zero;
        // база стороны — средняя точка высадки (гарнизоны не в счёт, если есть вертолёты)
        bF = BasePos(cfg.foundation, lzF, new Vector3(0, 0, -195f));
        bC = BasePos(cfg.chaos, lzC, new Vector3(0, 0, 195f));
        cmdF = new TeamCommander(Team.Foundation, bF);
        cmdC = new TeamCommander(Team.Chaos, bC);
        foreach (var sq in squads) (sq.team == Team.Foundation ? cmdF : cmdC).squads.Add(sq);
        startTime = Time.time;
        if (playerSq != null || playerSqRt == null) playerSqRt = playerSq;
        netSetupDone = true;
        GiveLoreItem(cfg, playerSq);
        if (!cfg.playerFps) SpectatorCam.Activate(new Vector3(0, 60, -260), Quaternion.Euler(20, 0, 0));
        if (cfg.op != null) Message(cfg.op.code + " — " + cfg.op.place, new Color(1f, 0.85f, 0.4f));
        if (introLines != null && playerHeli != null && PlayerController.I != null && PlayerController.I.unit.team == Team.Foundation)
        {
            playerHeli.playerPassenger = null;
            StartCoroutine(IntroRoutine(playerHeli, playerSq, PlayerController.I, introLines));
        }
        else
        {
            Message("Вертолёты на подлёте…", new Color(1f, 0.85f, 0.4f));
            Sfx.Play2D("alarm", 0.5f);
        }
    }

    static Vector3 BasePos(List<SquadPick> picks, List<Vector3> lz, Vector3 fallback)
    {
        Vector3 sum = Vector3.zero; int n = 0;
        for (int i = 0; i < picks.Count; i++) if (!picks[i].placed) { sum += lz[i]; n++; }
        if (n == 0) for (int i = 0; i < picks.Count; i++) { sum += lz[i]; n++; }
        return n > 0 ? sum / n : fallback;
    }

    // Отряд уже на месте (гарнизон Зоны, беглецы): без вертолёта, сразу в бою
    void PlaceSquad(SquadPick pick, Team team, Vector3 lz, Vector3 face, bool night)
    {
        var sq = new SquadRt { def = pick.def, team = team, lz = lz, garrison = pick.garrison, orderPos = lz, orderSet = true, hold = pick.garrison, orderText = pick.garrison ? "Удерживать сектор" : "Высадка" };
        squads.Add(sq);
        int cols = Mathf.CeilToInt(Mathf.Sqrt(pick.count));
        for (int k = 0; k < pick.count; k++)
        {
            Vector3 p = lz + new Vector3((k % cols - (cols - 1) / 2f) * 2.2f + Random.Range(-0.4f, 0.4f), 0, (k / cols) * 2.2f + Random.Range(-0.4f, 0.4f));
            p.y = MapGen.Height(p.x, p.z);
            if (UnityEngine.AI.NavMesh.SamplePosition(p, out var nh, 6f, UnityEngine.AI.NavMesh.AllAreas)) p = nh.position;
            var s = Soldier.Create(pick.def, p, Quaternion.LookRotation(face), k, night);
            Net.Assign(s);
            s.squadRt = sq; sq.members.Add(s);
            s.homeDir = face;
            s.BeginCombat(p);
        }
    }

    // ---------------- события ----------------
    public static void Message(string text, Color c, float life = 5f)
    {
        if (I == null) return;
        Net.OnMessage(text, c, life);
        I.messages.Add(new FeedEntry { text = text, color = c, time = Time.unscaledTime, life = life });
        if (I.messages.Count > 6) I.messages.RemoveAt(0);
    }

    public static void ReportKill(Unit attacker, Unit victim, DamageInfo d)
    {
        if (I == null || victim == null) return;
        I.teamLosses[(int)victim.team]++;
        if (attacker != null && attacker != victim) I.teamKills[(int)attacker.team]++;
        string an = attacker == null ? "" : attacker.isPlayer ? "ВЫ" : attacker.displayName;
        string vn = victim.isPlayer ? "ВЫ" : victim.displayName;
        string w = string.IsNullOrEmpty(d.weapon) ? "" : d.weapon;
        string text = attacker == null || attacker == victim ? vn + " погиб" + (w != "" ? " (" + w + ")" : "") : an + "  [" + w + "]  " + vn;
        if (d.hitbox != null && d.hitbox.head && d.type == DamageType.Bullet) text += "  ✚ ГОЛОВА";
        var c = attacker != null ? TeamColor(attacker.team) : Color.gray;
        I.feed.Add(new FeedEntry { text = text, color = c, time = Time.unscaledTime, player = (attacker != null && attacker.isPlayer) || victim.isPlayer });
        if (I.feed.Count > 7) I.feed.RemoveAt(0);
    }

    public static void Register(Unit u) { if (I != null && I.netSetupDone) Net.HostSpawned(u); }
    public bool netSetupDone;

    // Живые игроки в отряде (одиночная игра — только сам игрок в своём отряде)
    static List<NetHuman> HumansIn(BattleConfig cfg, Team t, int i)
    {
        var l = new List<NetHuman>();
        if (cfg.humans != null) { foreach (var h in cfg.humans) if (h.team == t && h.squad == i) l.Add(h); }
        else if (t == Team.Foundation && cfg.playerFps && i == cfg.playerSquad) l.Add(new NetHuman { peer = 0, team = t, squad = i });
        return l;
    }

    // Посадка живых игроков в борт: свой — управляемый игрок, чужие — их тела-представители. true — среди них свой.
    bool SpawnHumans(List<NetHuman> humans, SquadDef def, Helicopter heli, SquadRt sq, bool night)
    {
        bool mine = false;
        for (int j = 0; j < humans.Count; j++)
        {
            var h = humans[j];
            var seat = heli.seats[j % heli.seats.Count];
            bool local = Cfg.humans == null || h.peer == Net.MyPeer;
            if (local)
            {
                var pc = PlayerController.Create(def);
                Net.Assign(pc.unit);
                pc.RideIn(heli, seat);
                heli.playerPassenger = pc;
                mine = true;
            }
            else
            {
                var s = Soldier.Create(def, heli.transform.position, heli.transform.rotation, j, night);
                s.remoteHuman = true; s.netPeer = h.peer; s.nick = h.nick; s.displayName = h.nick;
                Net.Assign(s);
                s.squadRt = sq; sq.members.Add(s);
                s.SitIn(seat);
            }
        }
        return mine;
    }

    // Клиент: хост поднял борт (пропустил брифинг) — у нас тоже
    public void NetLaunch(int i)
    {
        if (i < 0 || i >= helis.Count || helis[i] == null) return;
        var h = helis[i];
        if (h == playerHeli && intro) { skipIntro = true; return; }   // брифинг сам доведёт до посадки
        h.LaunchNow();
        var pc = PlayerController.I;
        if (h == playerHeli && pc != null && !pc.riding && !pc.dead)
        {
            int seat = LocalHumanIndex(out _);
            pc.RideIn(h, h.seats[seat % h.seats.Count]);
            h.playerPassenger = pc;
        }
    }

    // ---------------- запросы ----------------
    public static float GroundHeight(Vector3 p)
    {
        if (Physics.Raycast(new Vector3(p.x, 300f, p.z), Vector3.down, out var hit, 600f, 1 << Layers.World, QueryTriggerInteraction.Ignore))
            return hit.point.y;
        return MapGen.Height(p.x, p.z);
    }

    public static Unit NearestEnemyUnit(Unit me, bool reachable = false)
    {
        Unit best = null; float bd = float.MaxValue;
        Vector3 p = me.transform.position;
        foreach (var u in Unit.All)
        {
            if (u == null || !u.alive || !me.IsEnemy(u) || !u.Targetable) continue;
            float d = (u.transform.position - p).sqrMagnitude;
            if (reachable && u.transform.position.y - GroundHeight(u.transform.position) > 3f) d *= 4f;
            if (d < bd) { bd = d; best = u; }
        }
        return best;
    }

    static readonly List<Unit> buf = new List<Unit>();
    public static List<Unit> SortedEnemies(Unit me, int n)
    {
        buf.Clear();
        Vector3 p = me.transform.position;
        foreach (var u in Unit.All)
            if (u != null && u.alive && me.IsEnemy(u) && u.Targetable) buf.Add(u);
        buf.Sort((a, b) => (a.transform.position - p).sqrMagnitude.CompareTo((b.transform.position - p).sqrMagnitude));
        if (buf.Count > n) buf.RemoveRange(n, buf.Count - n);
        return buf;
    }

    public static Helicopter EnemyHeli(Unit me, float range)
    {
        foreach (var h in Helicopter.Active)
        {
            if (h == null || h.Done || !Hostile(me.team, h.team)) continue;
            float d = Vector3.Distance(h.transform.position, me.transform.position);
            if (d > range || d < 15f) continue;
            if (!Combat.Visible(me.EyePos, h.transform.position + Vector3.up)) continue;
            return h;
        }
        return null;
    }

    // Предмет содержания по лору — у бойца группы игрока (или первой группы Фонда)
    // Игрок ждёт вылета (на базе после брифинга или уже в вертолёте) — можно вылететь сразу
    public bool PlayerCanLaunch => playerHeli != null && playerHeli.IsWaiting && PlayerController.I != null && !PlayerController.I.dead
        && (intro || playerHeli.playerPassenger == PlayerController.I) && Time.time < playerHeli.LaunchTime - 2f;
    public void LaunchPlayerNow()
    {
        if (!PlayerCanLaunch) return;
        if (intro) { skipIntro = true; return; }       // вступление само посадит в вертолёт и запустит его
        playerHeli.LaunchNow();
        if (playerSqRt != null) playerSqRt.arriveAt = Time.time;
        Message("Пилот: Понял, запускаемся, вылет немедленно.", new Color(0.75f, 0.9f, 0.75f), 4f);
        Sfx.Play2D("radio", 0.4f);
    }

    void GiveLoreItem(BattleConfig cfg, SquadRt playerSq)
    {
        // по средству на каждый вид SCP в бою; носители — бойцы группы игрока (не командир и не медик), затем других групп
        var kinds = new List<ScpKind>();
        foreach (var sp in cfg.scps) if (!kinds.Contains(sp.def.kind) && LoreItem.For(sp.def.kind) != null) kinds.Add(sp.def.kind);
        if (kinds.Count == 0) return;
        var pool = new List<Soldier>();
        var order = new List<SquadRt>();
        if (playerSq != null) order.Add(playerSq);
        foreach (var x in squads) if (x.team == Team.Foundation && x != playerSq) order.Add(x);
        foreach (var sq in order) foreach (var m in sq.members) if (m != null && m.alive && m.index >= 2) pool.Add(m);
        foreach (var sq in order) foreach (var m in sq.members) if (m != null && m.alive && m.index < 2 && !pool.Contains(m)) pool.Add(m);
        for (int i = 0; i < kinds.Count && i < pool.Count; i++)
        {
            var def = LoreItem.For(kinds[i]);
            LoreItem.Spawn(def, pool[i]);
            if (pool[i].squadRt == playerSq) Message(pool[i].CallSign + " несёт: «" + def.name + "». Оружием объект не остановить — только этим.", new Color(0.7f, 0.9f, 1f), 7f);
        }
    }

    // ---------------- захват SCP ----------------
    readonly List<Unit> capBuf = new List<Unit>();
    public ScpUnit captureTarget;   // ослабленный SCP, вокруг которого идёт бой (для интерфейса)

    void CaptureTick(float dt)
    {
        captureTarget = null;
        foreach (var u in Unit.All.ToArray())
        {
            if (!(u is ScpUnit su) || su.captured) continue;
            // Повстанцы уносят SCP-173 своими методами (держат его взглядом и грузят), остальных — только обезвреженных
            bool chaosGrab = !su.subdued && su.kind == ScpKind.S173 && su.alive;
            if (!su.subdued && !chaosGrab) continue;
            captureTarget = su;
            Combat.OverlapUnits(su.transform.position, 10f, capBuf);
            int f = 0, c = 0;
            foreach (var x in capBuf)
            {
                if (x.isScp || x.inVehicle) continue;
                if (x.team == Team.Foundation) f++; else if (x.team == Team.Chaos) c++;
            }
            float rate = dt / 14f;
            // Фонду нужен предмет содержания, если он предусмотрен для этого объекта
            var li = LoreItem.Find(su.kind);
            bool needItem = (li != null && !su.itemApplied) || chaosGrab;
            if (chaosGrab) f = 0;
            // группа игрока ещё не на земле — союзники объект не берут, ждут её
            if (Cfg != null && Cfg.playerFps && playerSqRt != null && PlayerController.I != null && (PlayerController.I.riding || intro || PlayerController.I.unit.inVehicle)) f = 0;
            if (needItem && c == 0) { if (f > 0) su.subduedUntil = Mathf.Max(su.subduedUntil, Time.time + 6f); continue; }
            if (su.itemApplied) rate *= 1.6f;
            if (f > 0 && c == 0) { su.capture[0] += rate * (1f + 0.15f * (f - 1)); su.capture[1] = Mathf.Max(0, su.capture[1] - rate); }
            else if (c > 0 && f == 0) { su.capture[1] += rate * (1f + 0.15f * (c - 1)); su.capture[0] = Mathf.Max(0, su.capture[0] - rate); }
            else if (f == 0 && c == 0) { su.capture[0] = Mathf.Max(0, su.capture[0] - rate * 0.3f); su.capture[1] = Mathf.Max(0, su.capture[1] - rate * 0.3f); }
            // пока идёт захват, объект не вырывается
            if (f + c > 0) su.subduedUntil = Mathf.Max(su.subduedUntil, Time.time + 6f);
            for (int t = 0; t < 2; t++)
            {
                if (su.capture[t] < 1f) continue;
                Team by = t == 0 ? Team.Foundation : Team.Chaos;
                su.Capture(by);
                if (Cfg != null && !Cfg.captureEnds)
                {
                    Message(su.displayName + " захвачен: " + TeamName(by), TeamColor(by));
                    Sfx.Play2D("radio", 0.5f);
                    continue;
                }
                over = true;
                Debrief(by == Team.Foundation);
                winnerText = (by == Team.Foundation ? "ФОНД ЗАХВАТИЛ " : "ПОВСТАНЦЫ ХАОСА ЗАХВАТИЛИ ") + su.displayName;
                winnerColor = TeamColor(by);
                teamKills[(int)by] += 0;
                Message(winnerText + " — ПОБЕДА", winnerColor);
                Sfx.Play2D("alarm", 0.7f, 1.2f);
                return;
            }
        }
    }

    // Текущая цель стороны (для маркера на экране)
    public bool Objective(Team t, out Vector3 pos, out string name)
    {
        var c = t == Team.Foundation ? cmdF : cmdC;
        pos = Vector3.zero; name = "";
        if (c == null || c.phase == OrderPhase.Landing) return false;
        pos = c.objective; name = c.objectiveName;
        return true;
    }

    public SquadRt SquadOf(SquadDef d)
    {
        foreach (var s in squads) if (s.def == d) return s;
        return null;
    }

    public int AliveCount(Team t)
    {
        int n = 0;
        foreach (var u in Unit.All) if (u != null && u.alive && u.team == t) n++;
        return n;
    }

    // ---------------- ход боя ----------------
    void Update()
    {
        // ленты событий живут 7 секунд
        feed.RemoveAll(f => Time.unscaledTime - f.time > 8f);
        messages.RemoveAll(f => Time.unscaledTime - f.time > f.life);

        if (loading) return;
        IntroInput();
        LaunchInput();
        if (Net.IsClient && Net.InGame) return;   // у клиента бой ведёт хост
        if (!over)
        {
            cmdF?.Tick(Time.deltaTime);
            cmdC?.Tick(Time.deltaTime);
            CaptureTick(Time.deltaTime);
        }
        if (over || Time.time < checkT) return;
        checkT = Time.time + 1f;
        if (Time.time - startTime < 15f) return;
        // все ли высадились
        foreach (var h in helis) if (h != null && !h.Done && !h.Unloaded) return;
        foreach (var c in containers) if (c != null && c.attached) return;
        foreach (var c in containers) if (c != null && c.spawned.Count == 0 && c.count > 0) return;

        int f = AliveCount(Team.Foundation), ch = AliveCount(Team.Chaos), s = AliveCount(Team.SCP);
        bool ally = Cfg.scpAllyChaos;
        int sides = (f > 0 ? 1 : 0) + (ally ? ((ch + s) > 0 ? 1 : 0) : (ch > 0 ? 1 : 0) + (s > 0 ? 1 : 0));
        if (sides <= 1)
        {
            over = true;
            if (f > 0) { winnerText = "ПОБЕДА ФОНДА"; winnerColor = TeamColor(Team.Foundation); }
            else if (ally && (ch + s) > 0) { winnerText = "ПОБЕДА ХАОСА И SCP"; winnerColor = TeamColor(Team.Chaos); }
            else if (ch > 0) { winnerText = "ПОБЕДА ПОВСТАНЦЕВ ХАОСА"; winnerColor = TeamColor(Team.Chaos); }
            else if (s > 0) { winnerText = "SCP-ОБЪЕКТЫ ВЫРВАЛИСЬ НА СВОБОДУ"; winnerColor = TeamColor(Team.SCP); }
            else { winnerText = "НИКТО НЕ ВЫЖИЛ"; winnerColor = Color.gray; }
            Debrief(f > 0);
            Sfx.Play2D("alarm", 0.6f, 0.8f);
        }
    }
}
