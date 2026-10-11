using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

// Подземный комплекс Зоны-19 из комнат SCP - Containment Breach (CC BY-SA 3.0):
// зона лёгкого содержания → КПП → зона тяжёлого содержания → КПП → входная зона.
// Внутри зоны — лабиринт из коридоров, развилок и помещений; камеры SCP-173, SCP-106, SCP-079 — в углах.
// На поверхность ведут лифты/спуски (Ворота A, административный корпус, портал ТЗС, блок ЛЗС).
public static class Facility
{
    public const float Cell = 2048f / 152f;           // 13.47 м — шаг клеток SCP:CB
    const int W = 5, ZH = 4, GAP = 2;                // ширина, высота зоны, разрыв между зонами
    const int Rows = ZH * 3 + GAP * 2;
    public static float BaseY;
    public static Transform RootT;
    public static readonly List<FacilityLink> Links = new List<FacilityLink>();

    class Tpl { public string name, shape; public int zone, common, open, over; public List<Vector4> lightPos = new List<Vector4>(); public List<Color> lightCol = new List<Color>(); }
    static List<Tpl> tpls;

    static void LoadMeta()
    {
        if (tpls != null) return;
        tpls = new List<Tpl>();
        var ta = Resources.Load<TextAsset>("Facility/facility");
        if (ta == null) return;
        foreach (var raw in ta.text.Split('\n'))
        {
            var line = raw.Trim(); if (line.Length == 0) continue;
            var f = line.Split('|');
            if (f.Length < 6) continue;
            var t = new Tpl { name = f[0], shape = f[1], zone = int.Parse(f[2]), common = int.Parse(f[3]), open = int.Parse(f[4]), over = int.Parse(f[5]) };
            if (f.Length > 6 && f[6].Length > 0)
                foreach (var l in f[6].Split(';'))
                {
                    var v = l.Split(',');
                    if (v.Length < 8) continue;
                    float F(int i) => float.Parse(v[i], System.Globalization.CultureInfo.InvariantCulture);
                    t.lightPos.Add(new Vector4(F(0), F(1), F(2), F(3)));
                    t.lightCol.Add(new Color(F(4), F(5), F(6), F(7)));
                }
            tpls.Add(t);
        }
    }

    static Tpl T(string n) { foreach (var t in tpls) if (t.name == n) return t; return null; }

    // направления: 0 — север (+z), 1 — восток (+x), 2 — юг (-z), 3 — запад (-x)
    static readonly int[] DX = { 0, 1, 0, -1 }, DZ = { 1, 0, -1, 0 };

    class CellInfo { public int mask; public Tpl tpl; public int rot; public int zone; public bool used; }

    public static void Build(Transform parent, Vector3 origin, int seed)
    {
        LoadMeta();
        Links.Clear();
        if (tpls == null || tpls.Count == 0) return;
        var rng = new System.Random(seed * 31 + 19);
        BaseY = origin.y;
        var root = new GameObject("Facility").transform;
        root.SetParent(parent, false);
        root.position = origin;
        RootT = root;
        var cells = new CellInfo[W, Rows];
        for (int x = 0; x < W; x++) for (int z = 0; z < Rows; z++) cells[x, z] = new CellInfo { zone = 0 };
        int[] zoneStart = { 0, ZH + GAP, (ZH + GAP) * 2 };
        void Link(int x0, int z0, int d)
        {
            cells[x0, z0].mask |= 1 << d; cells[x0, z0].used = true;
            int x1 = x0 + DX[d], z1 = z0 + DZ[d];
            cells[x1, z1].mask |= 1 << ((d + 2) % 4); cells[x1, z1].used = true;
        }
        // угловые камеры: (зона, комната, угол x, угол z, поворот)
        var corners = new List<(int zone, string room, int x, int z, int rot)>
        {
            (1, "start", W - 1, zoneStart[0], 1),            // SCP-173: выступ на восток и юг (за пределы сетки)
            (2, "room106", W - 1, zoneStart[1] + ZH - 1, 0),  // SCP-106: выступ на север (в разрыв) и восток
            (3, "room079", W - 1, zoneStart[2] + ZH - 1, 0),  // SCP-079: выступ на север и восток
        };
        int[] linkCol = new int[2];
        for (int zi = 0; zi < 3; zi++)
        {
            int z0 = zoneStart[zi];
            for (int x = 0; x < W; x++) for (int z = z0; z < z0 + ZH; z++) cells[x, z].zone = zi + 1;
            var cc = corners[zi];
            bool cornerOk = T(cc.room) != null;
            // остовное дерево (случайный обход) без угловой клетки
            var visited = new bool[W, ZH];
            if (cornerOk) visited[cc.x, cc.z - z0] = true;
            var stack = new List<(int, int)>();
            int sx = 0, sz = 0;
            visited[sx, sz] = true; stack.Add((sx, sz));
            while (stack.Count > 0)
            {
                var (cx, cz) = stack[stack.Count - 1];
                var opts = new List<int>();
                for (int d = 0; d < 4; d++)
                {
                    int nx = cx + DX[d], nz = cz + DZ[d];
                    if (nx < 0 || nz < 0 || nx >= W || nz >= ZH || visited[nx, nz]) continue;
                    opts.Add(d);
                }
                if (opts.Count == 0) { stack.RemoveAt(stack.Count - 1); continue; }
                int dd = opts[rng.Next(opts.Count)];
                Link(cx, cz + z0, dd);
                visited[cx + DX[dd], cz + DZ[dd]] = true;
                stack.Add((cx + DX[dd], cz + DZ[dd]));
            }
            // несколько колец, чтобы был не только тупиковый лабиринт
            for (int k = 0; k < 3; k++)
            {
                int x = rng.Next(W), z = rng.Next(ZH), d = rng.Next(4);
                int nx = x + DX[d], nz = z + DZ[d];
                if (nx < 0 || nz < 0 || nx >= W || nz >= ZH) continue;
                if (cornerOk && ((x == cc.x && z + z0 == cc.z) || (nx == cc.x && nz + z0 == cc.z))) continue;
                Link(x, z + z0, d);
            }
            // угловая камера: единственный вход — внутрь зоны
            if (cornerOk)
            {
                int inward = (2 + cc.rot) % 4;   // проём комнаты формы 1 смотрит на юг, поворот переносит его
                Link(cc.x, cc.z, inward);
                cells[cc.x, cc.z].tpl = T(cc.room); cells[cc.x, cc.z].rot = cc.rot;
            }
            // переход к следующей зоне через КПП и коридор
            if (zi < 2)
            {
                int col = rng.Next(W - 1);   // не столбец с угловой камерой
                linkCol[zi] = col;
                int top = z0 + ZH - 1;
                Link(col, top, 0);
                Link(col, top + 1, 0);
                Link(col, top + 2, 0);
                cells[col, top + 1].zone = 0; cells[col, top + 1].tpl = T(zi == 0 ? "checkpoint1" : "checkpoint2"); cells[col, top + 1].rot = 0;
                cells[col, top + 2].zone = zi + 2; cells[col, top + 2].tpl = T(zi == 0 ? "tunnel" : "room2z3"); cells[col, top + 2].rot = 0;
            }
        }

        // особые тупиковые помещения по зонам
        var deadSpecial = new Dictionary<int, Queue<string>>
        {
            { 1, new Queue<string>(new[] { "room1archive", "endroom" }) },
            { 2, new Queue<string>(new[] { "room035", "008", "endroom2" }) },
            { 3, new Queue<string>(new[] { "gateaentrance", "room1lifts" }) },
        };
        // выбор шаблона и поворота по маске проёмов
        for (int x = 0; x < W; x++)
            for (int z = 0; z < Rows; z++)
            {
                var c = cells[x, z];
                if (!c.used || c.tpl != null) continue;
                int m = c.mask, n = 0; for (int d = 0; d < 4; d++) if ((m & (1 << d)) != 0) n++;
                string shape; int rot = 0;
                if (n == 1) { shape = "1"; int d = 0; while ((m & (1 << d)) == 0) d++; rot = (d - 2 + 4) % 4; }
                else if (n == 2)
                {
                    if (m == 5 || m == 10) { shape = "2"; rot = m == 5 ? (rng.Next(2) * 2) : 1 + rng.Next(2) * 2; }
                    else { shape = "2C"; for (int r = 0; r < 4; r++) if ((((1 << ((1 + r) % 4)) | (1 << ((2 + r) % 4)))) == m) rot = r; }
                }
                else if (n == 3) { shape = "3"; int miss = 0; while ((m & (1 << miss)) != 0) miss++; rot = miss; }
                else { shape = "4"; rot = rng.Next(4); }
                Tpl pick = null;
                if (shape == "1" && deadSpecial.TryGetValue(c.zone, out var q) && q.Count > 0) pick = T(q.Dequeue());
                if (pick == null)
                {
                    var cand = new List<Tpl>(); int sum = 0;
                    foreach (var t in tpls)
                        if (t.zone == c.zone && t.shape == shape && t.common > 0 && t.over == 0) { cand.Add(t); sum += t.common; }
                    if (cand.Count == 0) foreach (var t in tpls) if (t.shape == shape && t.common > 0 && t.over == 0) { cand.Add(t); sum += t.common; }
                    int r2 = rng.Next(Mathf.Max(1, sum));
                    foreach (var t in cand) { r2 -= t.common; if (r2 < 0) { pick = t; break; } }
                    if (pick == null && cand.Count > 0) pick = cand[0];
                }
                c.tpl = pick; c.rot = rot;
            }

        // постройка
        var mats = new Dictionary<string, Material>();
        Material MatFor(ModelX mx, int i)
        {
            string tex = mx.matTex[i];
            Color col = mx.matColor[i];
            string key = tex + (col.a < 0.99f ? "_glass" : "");
            if (mats.TryGetValue(key, out var mm)) return mm;
            mm = mx.Mat(i, Color.white);
            mats[key] = mm;
            return mm;
        }
        for (int x = 0; x < W; x++)
            for (int z = 0; z < Rows; z++)
            {
                var c = cells[x, z];
                if (!c.used || c.tpl == null) continue;
                Vector3 pos = CellPos(x, z);
                var go = new GameObject("room_" + c.tpl.name);
                go.transform.SetParent(root, false);
                go.transform.position = pos;
                go.transform.rotation = Quaternion.Euler(0, 90f * c.rot, 0);
                var mx = ModelX.Load("room_" + c.tpl.name, "Facility/");
                if (mx == null) continue;
                foreach (var p in mx.parts)
                {
                    var pg = new GameObject(p.name);
                    pg.transform.SetParent(go.transform, false);
                    pg.layer = Layers.World;
                    bool coll = p.name.StartsWith("coll");
                    bool glass = !coll && mx.matColor[p.mat].a < 0.99f;
                    if (!coll)
                    {
                        pg.AddComponent<MeshFilter>().sharedMesh = p.mesh;
                        var mr = pg.AddComponent<MeshRenderer>();
                        mr.sharedMaterial = MatFor(mx, p.mat);
                        mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                    }
                    if (!glass) { var mc = pg.AddComponent<MeshCollider>(); mc.sharedMesh = p.mesh; pg.AddComponent<Surface>().color = new Color(0.5f, 0.5f, 0.5f); }
                }
                // свет комнаты
                for (int i = 0; i < c.tpl.lightPos.Count && i < 3; i++)
                {
                    var lp = c.tpl.lightPos[i]; var lc = c.tpl.lightCol[i];
                    var lg = new GameObject("lamp");
                    lg.transform.SetParent(go.transform, false);
                    lg.transform.localPosition = new Vector3(lp.x, lp.y, lp.z);
                    var l = lg.AddComponent<Light>();
                    l.type = LightType.Point; l.range = Mathf.Clamp(lp.w * 1.3f, 5f, 15f);
                    l.color = new Color(Mathf.Max(0.6f, lc.r), Mathf.Max(0.6f, lc.g), Mathf.Max(0.55f, lc.b));
                    l.intensity = Mathf.Clamp(lc.a * 1.6f, 0.5f, 1.6f);
                    l.shadows = LightShadows.None;
                    l.renderMode = i == 0 ? LightRenderMode.ForcePixel : LightRenderMode.Auto;
                }
                go.AddComponent<FacilityRoom>().Init(pos);
            }
        // двери на стыках клеток
        for (int x = 0; x < W; x++)
            for (int z = 0; z < Rows; z++)
            {
                var c = cells[x, z];
                if (!c.used) continue;
                for (int d = 0; d < 2; d++)   // север и восток — каждая дверь один раз
                {
                    if ((c.mask & (1 << d)) == 0) continue;
                    Vector3 p = CellPos(x, z) + new Vector3(DX[d], 0, DZ[d]) * (Cell * 0.5f);
                    FacilityDoor.Create(root, p, d == 0 ? 0f : 90f, rng.Next(100) < 70);
                }
            }
        // лифты на поверхность
        Vector3 Surf(float sx, float sz) => new Vector3(sx, Battle.GroundHeight(new Vector3(sx, 0, sz)) + 0.05f, sz);
        CellInfo Find(string n, out int fx, out int fz)
        {
            for (int x = 0; x < W; x++) for (int z = 0; z < Rows; z++) if (cells[x, z].tpl != null && cells[x, z].tpl.name == n) { fx = x; fz = z; return cells[x, z]; }
            fx = fz = -1; return null;
        }
        void AddLink(string room, Vector3 surface, string label)
        {
            var c = Find(room, out int fx, out int fz);
            if (c == null) return;
            Vector3 inside = CellPos(fx, fz) + new Vector3(0, 0.1f, 0);
            Links.Add(FacilityLink.Create(root, surface, inside, label));
        }
        AddLink("gateaentrance", Surf(0f, -38f), "ВОРОТА A · ВХОДНАЯ ЗОНА");
        AddLink("room1lifts", Surf(108f, -10f), "ЛИФТ · ВХОДНАЯ ЗОНА");
        AddLink("endroom2", Surf(-62f, 82f), "СПУСК · ЗОНА ТЯЖЁЛОГО СОДЕРЖАНИЯ");
        AddLink("endroom", Surf(-112f, -34f), "ЛИФТ · ЗОНА ЛЁГКОГО СОДЕРЖАНИЯ");
        root.gameObject.AddComponent<FacilityAmbience>();
    }

    // после построения навмеша — переподключить связи лифтов
    public static void AfterBake()
    {
        foreach (var l in Links)
        {
            if (l == null) continue;
            var ol = l.GetComponent<OffMeshLink>();
            if (ol != null) { ol.enabled = false; ol.enabled = true; ol.UpdatePositions(); }
        }
    }

    public static Vector3 CellPos(int x, int z) => RootT.position + new Vector3((x - (W - 1) * 0.5f) * Cell, 0, (z - (Rows - 1) * 0.5f) * Cell);

    public static bool Underground(Vector3 p) => RootT != null && p.y < BaseY + 14f;
}

// Комната: рисуется, только когда камера под землёй и недалеко
public class FacilityRoom : MonoBehaviour
{
    Renderer[] rs; Light[] ls; Vector3 c; bool shown = true; float t;
    public void Init(Vector3 center) { c = center; rs = GetComponentsInChildren<Renderer>(); ls = GetComponentsInChildren<Light>(); t = Random.value * 0.3f; }
    void Update()
    {
        if (Time.time < t) return;
        t = Time.time + 0.3f;
        var cam = Game.Cam;
        bool want = cam != null && Facility.Underground(cam.transform.position) && (cam.transform.position - c).sqrMagnitude < 70f * 70f;
        if (want == shown) return;
        shown = want;
        foreach (var r in rs) if (r != null) r.enabled = want;
        foreach (var l in ls) if (l != null) l.enabled = want;
    }
}

// Раздвижная гермодверь: открывается, когда рядом кто-то есть
public class FacilityDoor : MonoBehaviour
{
    Transform a, b; float k, checkT; bool open;
    public static void Create(Transform parent, Vector3 p, float yaw, bool heavy)
    {
        var go = new GameObject("door");
        go.transform.SetParent(parent, false);
        go.transform.position = p; go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        var d = go.AddComponent<FacilityDoor>();
        var mat = Mats.Get(heavy ? new Color(0.32f, 0.33f, 0.35f) : new Color(0.55f, 0.56f, 0.58f), 0.45f, 0.6f);
        var stripe = Mats.Get(new Color(0.85f, 0.65f, 0.1f), 0.3f);
        for (int s = -1; s <= 1; s += 2)
        {
            var leaf = new GameObject(s < 0 ? "L" : "R").transform;
            leaf.SetParent(go.transform, false);
            leaf.localPosition = new Vector3(s * 0.55f, 0, 0);
            leaf.gameObject.layer = Layers.Vehicle;
            MeshKit.Box(leaf, new Vector3(0, 1.3f, 0), new Vector3(1.1f, 2.6f, 0.14f), mat);
            if (heavy) MeshKit.Box(leaf, new Vector3(0, 1.3f, 0), new Vector3(1.1f, 0.12f, 0.16f), stripe);
            var bc = leaf.gameObject.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 1.3f, 0); bc.size = new Vector3(1.1f, 2.6f, 0.14f);
            if (s < 0) d.a = leaf; else d.b = leaf;
        }
    }
    void Update()
    {
        if (Time.time > checkT)
        {
            checkT = Time.time + 0.2f;
            bool want = false;
            Vector3 p = transform.position;
            foreach (var u in Unit.All)
                if (u != null && u.alive && (u.transform.position - p).sqrMagnitude < 12f) { want = true; break; }
            var cam = Game.Cam;
            if (!want && cam != null && (cam.transform.position - p).sqrMagnitude < 9f) want = true;
            if (want != open)
            {
                open = want;
                if (cam != null && (cam.transform.position - p).sqrMagnitude < 900f) Sfx.Play(open ? "door_open" : "door_close", p + Vector3.up, 0.6f, Random.Range(0.95f, 1.05f), 25f);
            }
        }
        k = Mathf.MoveTowards(k, open ? 1f : 0f, Time.deltaTime / 0.9f);
        float s = Mathf.SmoothStep(0, 1, k) * 1.08f;
        a.localPosition = new Vector3(-0.55f - s, 0, 0);
        b.localPosition = new Vector3(0.55f + s, 0, 0);
    }
}

// Лифт/спуск между поверхностью и комплексом: игрок — по клавише E (с ближайшими бойцами отряда), ИИ — по связи навмеша
public class FacilityLink : MonoBehaviour
{
    public Vector3 top, bottom; public string label;
    public static string Prompt;
    float useT;

    public static FacilityLink Create(Transform parent, Vector3 top, Vector3 bottom, string label)
    {
        var go = new GameObject("link " + label);
        go.transform.SetParent(parent, true);
        var l = go.AddComponent<FacilityLink>();
        l.top = top; l.bottom = bottom; l.label = label;
        // будка лифта на поверхности
        var t = new GameObject("lift").transform; t.SetParent(go.transform, true); t.position = top;
        var wall = Mats.Get(new Color(0.42f, 0.43f, 0.45f), 0.3f);
        MeshKit.Box(t, new Vector3(0, 1.6f, 1.6f), new Vector3(3.2f, 3.2f, 0.25f), wall);
        MeshKit.Box(t, new Vector3(-1.6f, 1.6f, 0.4f), new Vector3(0.25f, 3.2f, 2.6f), wall);
        MeshKit.Box(t, new Vector3(1.6f, 1.6f, 0.4f), new Vector3(0.25f, 3.2f, 2.6f), wall);
        MeshKit.Box(t, new Vector3(0, 3.3f, 0.4f), new Vector3(3.5f, 0.25f, 2.8f), wall);
        MeshKit.Box(t, new Vector3(0, 2.9f, -0.95f), new Vector3(2.6f, 0.3f, 0.05f), Mats.Glow(new Color(1f, 0.75f, 0.2f), 1.5f));
        foreach (var r in t.GetComponentsInChildren<Renderer>()) { var c = r.gameObject.AddComponent<BoxCollider>(); }
        MeshKit.SetLayer(t.gameObject, Layers.World);
        var ol = go.AddComponent<OffMeshLink>();
        var sa = new GameObject("a").transform; sa.SetParent(go.transform, true); sa.position = top + Vector3.back * 0.5f;
        var sb = new GameObject("b").transform; sb.SetParent(go.transform, true); sb.position = bottom;
        ol.startTransform = sa; ol.endTransform = sb; ol.biDirectional = true; ol.costOverride = 30f;
        return l;
    }

    void Update()
    {
        var pc = PlayerController.I;
        if (pc == null || pc.dead || pc.riding) return;
        Vector3 p = pc.transform.position;
        bool atTop = (p - top).sqrMagnitude < 9f, atBottom = (p - bottom).sqrMagnitude < 9f;
        if (!atTop && !atBottom) { if (Prompt != null && Prompt.Contains(label)) Prompt = null; return; }
        Prompt = "[E] " + (atTop ? "Спуститься: " : "Подняться на поверхность: ") + label;
        if (Input.GetKeyDown(KeyCode.E) && Time.time > useT)
        {
            useT = Time.time + 2f;
            Vector3 to = atTop ? bottom : top + Vector3.back * 2.5f;
            Sfx.Play2D("door_open", 0.6f, 0.8f);
            // ближайшие бойцы отряда идут следом
            foreach (var u in Unit.All)
                if (u is Soldier s && s.alive && !s.netPuppet && s.squad == pc.squad && (s.transform.position - p).sqrMagnitude < 144f)
                {
                    var off = Random.insideUnitCircle * 2.2f;
                    s.NetWarp(to + new Vector3(off.x, 0, off.y));
                }
            pc.Teleport(to);
            Prompt = null;
        }
    }
}

// Под землёй: тусклый рассеянный свет, без солнца и тумана поверхности
public class FacilityAmbience : MonoBehaviour
{
    bool under; Color a1, a2, a3, fogC; bool fogOn; float sunI = -1f;
    void LateUpdate()
    {
        var cam = Game.Cam;
        bool want = cam != null && Facility.Underground(cam.transform.position);
        if (want == under) return;
        under = want;
        var sun = RenderSettings.sun;
        if (under)
        {
            a1 = RenderSettings.ambientSkyColor; a2 = RenderSettings.ambientEquatorColor; a3 = RenderSettings.ambientGroundColor; fogC = RenderSettings.fogColor; fogOn = RenderSettings.fog;
            RenderSettings.ambientSkyColor = new Color(0.1f, 0.105f, 0.11f); RenderSettings.ambientEquatorColor = new Color(0.08f, 0.08f, 0.085f); RenderSettings.ambientGroundColor = new Color(0.05f, 0.05f, 0.05f);
            RenderSettings.fog = false;
            if (sun != null) { sunI = sun.intensity; sun.intensity = 0f; }
        }
        else
        {
            RenderSettings.ambientSkyColor = a1; RenderSettings.ambientEquatorColor = a2; RenderSettings.ambientGroundColor = a3; RenderSettings.fogColor = fogC; RenderSettings.fog = fogOn;
            if (sun != null && sunI >= 0) sun.intensity = sunI;
        }
    }
    void OnDestroy() { if (under) { under = true; RenderSettings.ambientSkyColor = a1; RenderSettings.ambientEquatorColor = a2; RenderSettings.ambientGroundColor = a3; RenderSettings.fog = fogOn; var sun = RenderSettings.sun; if (sun != null && sunI >= 0) sun.intensity = sunI; } }
}
