using System.Collections.Generic;
using UnityEngine;

public class SquadPick { public SquadDef def; public int count; }
public class ScpPick { public ScpDef def; public int count; }

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
}

// Менеджер боя: высадка всех сторон, союзы, победа, лента событий
public class Battle : MonoBehaviour
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
    public string winnerText;
    public Color winnerColor;
    public float startTime;
    public readonly int[] teamKills = new int[3];
    public readonly int[] teamLosses = new int[3];
    public bool has173;
    float checkT;

    public class FeedEntry { public string text; public Color color; public float time; public bool player; }

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
        I.Setup();
    }

    public static void End()
    {
        if (I != null) Destroy(I.gameObject);
        I = null;
        foreach (var h in Helicopter.Active.ToArray()) if (h != null) Destroy(h.gameObject);
        Helicopter.Active.Clear();
        foreach (var u in Unit.All.ToArray()) if (u != null && !u.isPlayer) Destroy(u.gameObject);
        foreach (var c in Ragdoll.Corpses.ToArray()) if (c != null) Destroy(c.gameObject);
        Ragdoll.Corpses.Clear();
        foreach (var o in Object.FindObjectsOfType<ScpContainer>()) Destroy(o.gameObject);
        foreach (var o in Object.FindObjectsOfType<Wreck>()) Destroy(o.gameObject);
        foreach (var o in Object.FindObjectsOfType<Grenade>()) Destroy(o.gameObject);
        foreach (var o in Object.FindObjectsOfType<Rocket>()) Destroy(o.gameObject);
        foreach (var g in Object.FindObjectsOfType<GunModel>()) if (g.transform.root.GetComponent<PlayerController>() == null) Destroy(g.gameObject);
        foreach (var r in Object.FindObjectsOfType<Rigidbody>()) if (r != null && r.gameObject.name == "chunk") Destroy(r.gameObject);
        PlayerController.Remove();
        Fx.Clear();
        MapGen.Clear();
        Time.timeScale = 1f;
    }

    void Setup()
    {
        var cfg = Cfg;
        startTime = Time.time;
        Ragdoll.MaxCorpses = Game.CorpseLimit;
        Fx.BloodLevel = Game.Blood;

        // зоны высадки
        var lzF = new List<Vector3>();
        var lzC = new List<Vector3>();
        var lzS = new List<Vector3>();
        int nF = cfg.foundation.Count, nC = cfg.chaos.Count, nS = cfg.scps.Count;
        for (int i = 0; i < nF; i++) lzF.Add(new Vector3((i - (nF - 1) / 2f) * 24f, 0, -64f - (i % 2) * 8f));
        for (int i = 0; i < nC; i++) lzC.Add(new Vector3((i - (nC - 1) / 2f) * 22f, 0, 64f + (i % 2) * 8f));
        for (int i = 0; i < nS; i++)
        {
            float side = i % 2 == 0 ? 1 : -1;
            int row = i / 2;
            lzS.Add(new Vector3(side * (74f + (row % 2) * 6f), 0, (row - (Mathf.Ceil(nS / 2f) - 1) / 2f) * 30f));
        }
        var all = new List<Vector3>(); all.AddRange(lzF); all.AddRange(lzC); all.AddRange(lzS);
        MapGen.Build(cfg.map, cfg.time, all, cfg.seed);
        for (int i = 0; i < lzF.Count; i++) lzF[i] = new Vector3(lzF[i].x, GroundHeight(lzF[i]), lzF[i].z);
        for (int i = 0; i < lzC.Count; i++) lzC[i] = new Vector3(lzC[i].x, GroundHeight(lzC[i]), lzC[i].z);
        for (int i = 0; i < lzS.Count; i++) lzS[i] = new Vector3(lzS[i].x, GroundHeight(lzS[i]), lzS[i].z);

        bool night = cfg.time == 2;

        // ФОНД
        for (int i = 0; i < nF; i++)
        {
            var pick = cfg.foundation[i];
            bool playerHere = cfg.playerFps && i == cfg.playerSquad;
            var lz = lzF[i];
            var heli = Helicopter.Create(Team.Foundation, pick.def.label, new Color(0.12f, 0.13f, 0.15f), pick.def.look.accent, Mathf.Max(pick.count, 2), false);
            var sq = new SquadRt { def = pick.def, team = Team.Foundation };
            squads.Add(sq);
            int bots = playerHere ? pick.count - 1 : pick.count;
            int seat = playerHere ? 1 : 0;
            for (int k = 0; k < bots; k++)
            {
                var s = Soldier.Create(pick.def, heli.transform.position, heli.transform.rotation, k + (playerHere ? 1 : 0), night);
                s.squadRt = sq; sq.members.Add(s);
                s.SitIn(heli.seats[(seat + k) % heli.seats.Count]);
                heli.passengers.Add(s);
            }
            if (playerHere)
            {
                var pc = PlayerController.Create(pick.def);
                pc.RideIn(heli, heli.seats[0]);
                heli.playerPassenger = pc;
            }
            Vector3 entry = new Vector3(lz.x * 0.6f + Random.Range(-30f, 30f), lz.y + 70f, -430f);
            Vector3 exit = new Vector3(lz.x * 2f, lz.y + 90f, -440f);
            heli.Launch(entry, lz, exit, i * 2.5f);
            helis.Add(heli);
        }
        // ХАОС
        for (int i = 0; i < nC; i++)
        {
            var pick = cfg.chaos[i];
            var lz = lzC[i];
            bool rope = pick.def.fastRope;
            var heli = Helicopter.Create(Team.Chaos, pick.def.label, new Color(0.24f, 0.26f, 0.17f), pick.def.look.accent, Mathf.Max(pick.count, 2), rope);
            var sq = new SquadRt { def = pick.def, team = Team.Chaos };
            squads.Add(sq);
            for (int k = 0; k < pick.count; k++)
            {
                var s = Soldier.Create(pick.def, heli.transform.position, heli.transform.rotation, k, night);
                s.squadRt = sq; sq.members.Add(s);
                s.SitIn(heli.seats[k % heli.seats.Count]);
                heli.passengers.Add(s);
                s.homeDir = Vector3.forward;
            }
            Vector3 entry = new Vector3(lz.x * 0.6f + Random.Range(-30f, 30f), lz.y + 70f, 430f);
            Vector3 exit = new Vector3(lz.x * 2f, lz.y + 90f, 440f);
            heli.Launch(entry, lz, exit, 3f + i * 2.5f);
            helis.Add(heli);
        }
        // SCP — в контейнерах на тросе
        for (int i = 0; i < nS; i++)
        {
            var pick = cfg.scps[i];
            var lz = lzS[i];
            if (pick.def.kind == ScpKind.S173) has173 = true;
            var heli = Helicopter.Create(Team.SCP, "SCP " + pick.def.id, new Color(0.3f, 0.3f, 0.32f), new Color(0.95f, 0.7f, 0.1f), 2, false);
            var cont = ScpContainer.Create(pick.def.kind, pick.count);
            heli.AttachSling(cont);
            float side = Mathf.Sign(lz.x);
            Vector3 entry = new Vector3(side * 440f, lz.y + 75f, lz.z + Random.Range(-40f, 40f));
            Vector3 exit = new Vector3(side * 450f, lz.y + 90f, lz.z * 2f);
            heli.Launch(entry, lz, exit, 6f + i * 3f);
            cont.transform.position = heli.transform.position + Vector3.down * (9f + cont.height);
            cont.transform.rotation = Quaternion.Euler(0, side > 0 ? -90 : 90, 0);
            containers.Add(cont);
            helis.Add(heli);
        }

        if (!cfg.playerFps) SpectatorCam.Activate(new Vector3(0, 40, -110), Quaternion.Euler(18, 0, 0));
        Message("Вертолёты на подлёте…", new Color(1f, 0.85f, 0.4f));
        Sfx.Play2D("alarm", 0.5f);
    }

    // ---------------- события ----------------
    public static void Message(string text, Color c)
    {
        if (I == null) return;
        I.messages.Add(new FeedEntry { text = text, color = c, time = Time.unscaledTime });
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

    public static void Register(Unit u) { }

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
        messages.RemoveAll(f => Time.unscaledTime - f.time > 5f);

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
            Sfx.Play2D("alarm", 0.6f, 0.8f);
        }
    }
}
