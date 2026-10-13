using System.Collections.Generic;
using UnityEngine;

// Передовая база Фонда (FOB): отсюда отряды вылетают в район операции.
// Стоит в южной долине, в 1.3 км от района операции: вертолёты взлетают отсюда по-настоящему.
public static partial class MapGen
{
    public class FobInfo
    {
        public Transform root;
        public readonly List<Vector3> pads = new List<Vector3>();
        public Vector3 brief;        // место у стола с картой: офицер стоит здесь, отряд — полукругом
        public float briefYaw;       // куда смотрит офицер
    }

    public static FobInfo BuildFob(Vector3 c, int map)
    {
        var info = new FobInfo();
        var root = new GameObject("FOB").transform;
        root.SetParent(Root != null ? Root.transform : null);
        root.position = c;
        info.root = root;
        if (rng == null) rng = new System.Random(5);
        flatGround = true; flatY = c.y;

        Color dirt = map == 2 ? new Color(0.7f, 0.6f, 0.43f) : map == 3 ? new Color(0.85f, 0.87f, 0.9f) : new Color(0.38f, 0.35f, 0.27f);
        Color hesco = map == 2 || map == 0 ? new Color(0.66f, 0.58f, 0.42f) : map == 3 ? new Color(0.7f, 0.68f, 0.62f) : new Color(0.5f, 0.46f, 0.34f);

        // грунт (гравий) и бетонная стоянка вертолётов
        var gph = Mats.Photo(map == 3 ? "snow" : map == 2 ? "cracked" : "gravel");
        var gm = gph != null ? Mats.Tri(gph, Color.white, 3f, map == 3 ? 0.3f : 0.05f, 0.3f) : Mats.Textured(Mats.GroundTex(dirt, dirt * 0.88f, dirt * 1.08f, 77), Color.white, Vector2.one * 40f, map == 3 ? 0.3f : 0.05f);
        var ground = Solid(c + new Vector3(0, -15f, 0), new Vector3(300f, 30f, 300f), gm, Quaternion.identity, dirt, false, root);
        ground.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        var aph = Mats.Photo("concrete_floor");
        var apron = aph != null ? Mats.Tri(aph, new Color(0.9f, 0.9f, 0.9f), 3f, 0.15f, 0.3f) : Mats.Textured(Mats.ConcreteTex(new Color(0.46f, 0.46f, 0.44f), 9), Color.white, new Vector2(8f, 5f), 0.15f);
        Solid(c + new Vector3(0, 0.02f, 20f), new Vector3(150f, 0.06f, 36f), apron, Quaternion.identity, new Color(0.45f, 0.45f, 0.44f), false, root);

        // площадки с разметкой
        // первая площадка — у стола брифинга (борт группы игрока)
        float[] padX = { -28f, 0f, -56f, 28f, 56f };
        for (int i = 0; i < padX.Length; i++)
        {
            Vector3 p = c + new Vector3(padX[i], 0, 20f);
            info.pads.Add(p);
            var mark = Mats.Get(new Color(0.92f, 0.85f, 0.25f), 0.3f);
            var h = new GameObject("pad"); h.transform.SetParent(root); h.transform.position = p + Vector3.up * 0.06f;
            MeshKit.Box(h.transform, new Vector3(-1.2f, 0, 0), new Vector3(0.5f, 0.02f, 4f), mark);
            MeshKit.Box(h.transform, new Vector3(1.2f, 0, 0), new Vector3(0.5f, 0.02f, 4f), mark);
            MeshKit.Box(h.transform, Vector3.zero, new Vector3(2.4f, 0.02f, 0.5f), mark);
            for (int k = 0; k < 24; k++)
            {
                float a = k / 24f * Mathf.PI * 2f;
                MeshKit.Box(h.transform, new Vector3(Mathf.Cos(a) * 7f, 0, Mathf.Sin(a) * 7f), new Vector3(1.1f, 0.02f, 0.3f), Mats.Get(new Color(0.9f, 0.9f, 0.88f)), new Vector3(0, -a * Mathf.Rad2Deg, 0));
            }
            MeshKit.CombineParts(h.transform);
            for (int k = 0; k < 4; k++)
            {
                float a = k * Mathf.PI * 0.5f + 0.785f;
                var l = new GameObject("padLight"); l.transform.SetParent(root); l.transform.position = p + new Vector3(Mathf.Cos(a) * 8f, 0.15f, Mathf.Sin(a) * 8f);
                MeshKit.Ball(l.transform, Vector3.zero, Vector3.one * 0.18f, Mats.Glow(new Color(0.2f, 1f, 0.3f), Night ? 6f : 2f));
            }
        }

        // периметр из габионов HESCO с въездом
        var hm = Mats.Get(hesco, 0.05f);
        var mesh = Mats.Get(new Color(0.35f, 0.35f, 0.33f), 0.4f, 0.6f);
        float hx = 75f, hz = 60f;
        for (float x = -hx; x <= hx; x += 1.5f)
            foreach (float z in new[] { -hz, hz })
            {
                if (z < 0 && Mathf.Abs(x) < 6f) continue; // въезд
                Hesco(c + new Vector3(x, 0, z), 0, hm, mesh, hesco, root);
            }
        for (float z = -hz + 1.5f; z < hz; z += 1.5f)
            foreach (float x in new[] { -hx, hx })
                Hesco(c + new Vector3(x, 0, z), 90, hm, mesh, hesco, root);
        Barrier(c + new Vector3(-3f, 0, -hz - 3f), 0, root);
        Barrier(c + new Vector3(3.5f, 0, -hz - 5f), 0, root);

        // палатки модульного лагеря
        Color tent = map == 2 ? new Color(0.72f, 0.64f, 0.48f) : map == 3 ? new Color(0.78f, 0.8f, 0.8f) : new Color(0.33f, 0.36f, 0.26f);
        for (int i = 0; i < 4; i++) BigTent(c + new Vector3(-50f + i * 16f, 0, -32f), 0, tent, root);
        // жилые и штабные контейнеры
        Color[] cc = { new Color(0.42f, 0.44f, 0.36f), new Color(0.6f, 0.55f, 0.45f), new Color(0.3f, 0.36f, 0.42f) };
        for (int i = 0; i < 6; i++) Container(c + new Vector3(30f + (i % 3) * 3.2f, (i / 3) * 2.6f, -36f), 90, cc[i % 3], root);
        for (int i = 0; i < 3; i++) Container(c + new Vector3(52f, 0, -40f + i * 7f), 0, cc[(i + 1) % 3], root);
        // техника, ящики, топливо, генератор
        Truck(c + new Vector3(-66f, 0, -8f), 15, root);
        Truck(c + new Vector3(-64f, 0, -20f), 25, root);
        for (int i = 0; i < 12; i++) Crate(c + new Vector3(R(-40f, -20f), 0, R(-50f, -45f)), root);
        Generator(c + new Vector3(44f, 0, -14f), root);
        FuelBladder(c + new Vector3(64f, 0, -6f), root);
        // вышки, мачта связи, освещение, флаг
        Tower(c + new Vector3(-hx + 4f, 0, hz - 4f), root);
        Tower(c + new Vector3(hx - 4f, 0, -hz + 4f), root);
        Mast(c + new Vector3(40f, 0, -24f), root);
        for (int i = 0; i < 4; i++) LightPole(c + new Vector3(-45f + i * 30f, 0, 42f), root);
        Flag(c + new Vector3(-8f, 0, -12f), root);
        for (int i = 0; i < 4; i++) Sandbags(c + new Vector3(-20f + i * 13f, 0, -hz + 6f), 180, root);

        // место брифинга: стол с картой у площадок
        info.brief = c + new Vector3(-28f, 0, 2f);
        info.briefYaw = 180f;
        var table = new GameObject("briefTable"); table.transform.SetParent(root); table.transform.position = info.brief + new Vector3(0, 0, 1.4f);
        var tm = Mats.Get(new Color(0.3f, 0.28f, 0.22f), 0.2f);
        MeshKit.Box(table.transform, new Vector3(0, 0.8f, 0), new Vector3(2.2f, 0.06f, 1.1f), tm);
        foreach (var lp in new[] { new Vector3(-1f, 0.4f, -0.45f), new Vector3(1f, 0.4f, -0.45f), new Vector3(-1f, 0.4f, 0.45f), new Vector3(1f, 0.4f, 0.45f) })
            MeshKit.Box(table.transform, lp, new Vector3(0.06f, 0.8f, 0.06f), tm);
        MeshKit.Box(table.transform, new Vector3(0, 0.835f, 0), new Vector3(1.9f, 0.01f, 0.9f), Mats.Textured(MapTex(), Color.white, Vector2.one, 0.1f));
        MeshKit.CombineParts(table.transform);
        var tb = table.AddComponent<BoxCollider>(); tb.center = new Vector3(0, 0.45f, 0); tb.size = new Vector3(2.2f, 0.9f, 1.1f);
        if (Night) Lamp(info.brief + new Vector3(0, 2.6f, 1.4f), new Color(1f, 0.85f, 0.6f), 9f, 1.6f, root);

        flatGround = false;
        MeshKit.SetLayer(root.gameObject, Layers.World);
        return info;
    }

    static void Hesco(Vector3 p, float yaw, Material fill, Material wire, Color col, Transform root)
    {
        var go = new GameObject("hesco"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z); go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        MeshKit.Box(go.transform, new Vector3(0, 0.7f, 0), new Vector3(1.45f, 1.4f, 1.45f), fill);
        MeshKit.Box(go.transform, new Vector3(0, 1.41f, 0), new Vector3(1.5f, 0.03f, 1.5f), wire);
        for (int k = -1; k <= 1; k += 2)
        {
            MeshKit.Box(go.transform, new Vector3(0.73f * k, 0.7f, 0.73f), new Vector3(0.04f, 1.42f, 0.04f), wire);
            MeshKit.Box(go.transform, new Vector3(0.73f * k, 0.7f, -0.73f), new Vector3(0.04f, 1.42f, 0.04f), wire);
        }
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 0.7f, 0); bc.size = new Vector3(1.5f, 1.4f, 1.5f);
        go.AddComponent<Surface>().color = col;
    }

    static void BigTent(Vector3 p, float yaw, Color c, Transform root)
    {
        if (PropKit.Has("tent_cmd")) { PropKit.Place("tent_cmd", OnGround(p.x, p.z) + Vector3.down * 0.05f, yaw + 90f, root, 0.85f, 2, false, "tent"); return; }
        var go = new GameObject("tent"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z); go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        var m = Mats.Get(c, 0.05f);
        // полуцилиндрический каркасный шатёр
        for (int i = 0; i < 10; i++)
        {
            float a0 = i / 10f * Mathf.PI, a1 = (i + 1) / 10f * Mathf.PI, am = (a0 + a1) * 0.5f;
            Vector3 lp = new Vector3(Mathf.Cos(am) * 3.2f, Mathf.Sin(am) * 3.2f, 0);
            MeshKit.Box(go.transform, lp, new Vector3(2.05f, 0.06f, 10f), m, new Vector3(0, 0, am * Mathf.Rad2Deg - 90f));
        }
        MeshKit.Box(go.transform, new Vector3(0, 1.4f, 5f), new Vector3(6.2f, 2.8f, 0.05f), Mats.Get(c * 0.85f, 0.05f));
        MeshKit.Box(go.transform, new Vector3(0, 1.0f, 5.03f), new Vector3(1.4f, 2.0f, 0.04f), Mats.Get(new Color(0.08f, 0.08f, 0.08f)));
        MeshKit.Box(go.transform, new Vector3(0, 1.4f, -5f), new Vector3(6.2f, 2.8f, 0.05f), Mats.Get(c * 0.85f, 0.05f));
        MeshKit.Box(go.transform, new Vector3(3.6f, 0.6f, -2f), new Vector3(0.8f, 1.2f, 1.6f), Mats.Get(new Color(0.75f, 0.75f, 0.72f), 0.3f)); // кондиционер
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 1.6f, 0); bc.size = new Vector3(6.2f, 3.2f, 10f);
        go.AddComponent<Surface>().color = c;
    }

    static void Container(Vector3 p, float yaw, Color c, Transform root)
    {
        var go = new GameObject("container"); go.transform.SetParent(root);
        go.transform.position = new Vector3(p.x, p.y, p.z);
        go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        var m = Mats.Get(c, 0.3f, 0.3f);
        var dark = Mats.Get(c * 0.7f, 0.3f, 0.3f);
        MeshKit.Box(go.transform, new Vector3(0, 1.3f, 0), new Vector3(2.44f, 2.59f, 6.06f), m);
        for (int i = 0; i < 20; i++)
            foreach (float x in new[] { -1.23f, 1.23f })
                MeshKit.Box(go.transform, new Vector3(x, 1.3f, -2.85f + i * 0.3f), new Vector3(0.04f, 2.4f, 0.12f), dark);
        MeshKit.Box(go.transform, new Vector3(0, 1.3f, 3.04f), new Vector3(2.3f, 2.45f, 0.04f), dark);
        MeshKit.Box(go.transform, new Vector3(-0.3f, 1.3f, 3.07f), new Vector3(0.05f, 2.3f, 0.05f), Mats.Get(new Color(0.2f, 0.2f, 0.2f)));
        MeshKit.Box(go.transform, new Vector3(0.3f, 1.3f, 3.07f), new Vector3(0.05f, 2.3f, 0.05f), Mats.Get(new Color(0.2f, 0.2f, 0.2f)));
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 1.3f, 0); bc.size = new Vector3(2.44f, 2.59f, 6.06f);
        var s = go.AddComponent<Surface>(); s.color = c; s.metal = true;
    }

    static void Generator(Vector3 p, Transform root)
    {
        if (PropKit.Has("generator"))
        {
            var g = OnGround(p.x, p.z);
            var gg = PropKit.Place("generator", g, R(0, 360), root, 1.2f, 1, true, "generator");
            for (int k = 0; k < 4; k++) PropKit.Place("jerrycan", OnGround(p.x + 0.9f + k * 0.22f, p.z + R(-0.3f, 0.3f)), R(-20, 20), root, 1f, 1, true);
            PropKit.Place(R() < 0.5f ? "barrel_01" : "barrel_02", OnGround(p.x - 1.0f, p.z + 0.4f), R(0, 360), root, 1f, 1, true);
            if (gg != null) Sfx.Loop("wind", gg.transform, 0.1f, 15f, 0.42f);   // тарахтит
            return;
        }
        var go = new GameObject("generator"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z);
        var m = Mats.Get(new Color(0.3f, 0.34f, 0.26f), 0.3f, 0.2f);
        MeshKit.Box(go.transform, new Vector3(0, 0.9f, 0), new Vector3(1.6f, 1.6f, 3.2f), m);
        MeshKit.Box(go.transform, new Vector3(0, 0.08f, 0), new Vector3(1.8f, 0.16f, 3.6f), Mats.Get(new Color(0.15f, 0.15f, 0.15f)));
        MeshKit.Cyl(go.transform, new Vector3(0.5f, 2.1f, -1.1f), 0.14f, 0.9f, Mats.Get(new Color(0.12f, 0.12f, 0.12f), 0.3f, 0.6f));
        for (int i = 0; i < 6; i++) MeshKit.Box(go.transform, new Vector3(0.81f, 1.1f, -1f + i * 0.35f), new Vector3(0.02f, 0.8f, 0.18f), Mats.Get(new Color(0.1f, 0.1f, 0.1f)));
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 0.9f, 0); bc.size = new Vector3(1.6f, 1.8f, 3.4f);
        go.AddComponent<Surface>().metal = true;
        Sfx.Loop("wind", go.transform, 0.12f, 18f, 0.35f);   // гул генератора
    }

    static void FuelBladder(Vector3 p, Transform root)
    {
        var go = new GameObject("fuel"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z);
        MeshKit.Ball(go.transform, new Vector3(0, 0.55f, 0), new Vector3(6f, 1.1f, 9f), Mats.Get(new Color(0.12f, 0.12f, 0.1f), 0.5f));
        for (int i = 0; i < 4; i++) MeshKit.Box(go.transform, new Vector3((i % 2 == 0 ? -1 : 1) * 4f, 0.6f, (i < 2 ? -1 : 1) * 5.5f), new Vector3(1.4f, 1.2f, 1.4f), Mats.Get(new Color(0.6f, 0.55f, 0.4f), 0.05f));
        MeshKit.CombineParts(go.transform);
    }

    static void Mast(Vector3 p, Transform root)
    {
        var go = new GameObject("mast"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z);
        var m = Mats.Get(new Color(0.55f, 0.55f, 0.55f), 0.4f, 0.6f);
        for (int i = 0; i < 6; i++) MeshKit.Cyl(go.transform, new Vector3(0, 2.5f + i * 5f, 0), 0.22f - i * 0.025f, 5f, m);
        MeshKit.Box(go.transform, new Vector3(0, 28f, 0), new Vector3(1.6f, 0.08f, 0.08f), m);
        MeshKit.Ball(go.transform, new Vector3(0, 30.2f, 0), Vector3.one * 0.25f, Mats.Glow(new Color(1f, 0.1f, 0.05f), 6f));
        MeshKit.CombineParts(go.transform);
        // растяжки
        for (int i = 0; i < 3; i++)
        {
            float a = i / 3f * Mathf.PI * 2f;
            var lg = new GameObject("guy"); lg.transform.SetParent(go.transform, false);
            var lr = lg.AddComponent<LineRenderer>();
            lr.sharedMaterial = Mats.Get(new Color(0.15f, 0.15f, 0.15f));
            lr.widthMultiplier = 0.02f; lr.positionCount = 2;
            lr.SetPosition(0, go.transform.position + Vector3.up * 24f);
            lr.SetPosition(1, go.transform.position + new Vector3(Mathf.Cos(a) * 12f, 0, Mathf.Sin(a) * 12f));
        }
        var cc = go.AddComponent<CapsuleCollider>(); cc.center = new Vector3(0, 15f, 0); cc.height = 30f; cc.radius = 0.2f;
    }

    static void Flag(Vector3 p, Transform root)
    {
        var go = new GameObject("flag"); go.transform.SetParent(root); go.transform.position = OnGround(p.x, p.z);
        MeshKit.Cyl(go.transform, new Vector3(0, 4f, 0), 0.08f, 8f, Mats.Get(new Color(0.7f, 0.7f, 0.7f), 0.5f, 0.7f));
        var logo = Resources.Load<Texture2D>("Branding/Logo");
        var fm = logo != null ? Mats.Textured(logo, Color.white, Vector2.one, 0.05f) : Mats.Get(new Color(0.9f, 0.9f, 0.9f));
        var cloth = MeshKit.Part(go.transform, MeshKit.Quad, fm, new Vector3(0.95f, 7.2f, 0), new Vector3(1.8f, 1.2f, 1f), new Vector3(0, 90, 0));
        var back = MeshKit.Part(go.transform, MeshKit.Quad, fm, new Vector3(0.95f, 7.2f, 0), new Vector3(1.8f, 1.2f, 1f), new Vector3(0, -90, 0));
        cloth.AddComponent<FlagWave>(); back.AddComponent<FlagWave>();
    }

    // Простая тактическая карта для стола брифинга
    static Texture2D MapTex()
    {
        return Mats.MakeTex(256, (u, v) =>
        {
            float n = Mathf.PerlinNoise(u * 6f, v * 6f);
            Color c = Color.Lerp(new Color(0.78f, 0.76f, 0.62f), new Color(0.55f, 0.65f, 0.45f), n);
            float iso = Mathf.Repeat(n * 10f, 1f);
            if (iso < 0.06f) c *= 0.8f;
            if (Mathf.Abs(u - 0.5f) < 0.004f || Mathf.Abs(v - 0.5f) < 0.004f) c = new Color(0.3f, 0.3f, 0.3f);
            float d = Vector2.Distance(new Vector2(u, v), new Vector2(0.55f, 0.6f));
            if (Mathf.Abs(d - 0.08f) < 0.006f) c = new Color(0.8f, 0.1f, 0.1f);
            if (Mathf.Abs(u - v * 0.6f - 0.15f) < 0.004f && v < 0.6f) c = new Color(0.1f, 0.2f, 0.7f);
            return c;
        }, false);
    }
}

// Флаг колышется на ветру
public class FlagWave : MonoBehaviour
{
    Quaternion rest;
    float seed;
    void Start() { rest = transform.localRotation; seed = Random.value * 10f; }
    void Update()
    {
        float t = Time.time + seed;
        transform.localRotation = rest * Quaternion.Euler(Mathf.Sin(t * 1.3f) * 4f, Mathf.Sin(t * 2.1f) * 9f, Mathf.Sin(t * 1.7f) * 3f);
    }
}
