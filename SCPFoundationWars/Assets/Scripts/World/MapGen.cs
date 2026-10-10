using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.Rendering;

// Процедурная карта: рельеф, комплекс Зоны, укрытия, лес, освещение, навигационная сетка.
public static class MapGen
{
    public static readonly string[] MapNames = { "Зона-19: поверхность", "Лесной КПП", "Пустынная Зона-██", "Зимний комплекс" };
    public static readonly string[] TimeNames = { "День", "Закат", "Ночь" };

    public static GameObject Root;
    public static bool Night;
    static NavMeshDataInstance navInstance;
    static System.Random rng;
    static readonly List<Vector3> keepOut = new List<Vector3>();
    static Material groundMat, concreteMat, darkConcrete;
    static Color dirtColor;
    public const float Size = 640f;
    public const float Play = 235f;
    static int mapKind;
    static readonly List<Light> lamps = new List<Light>();
    static Vector3 sunDir = Vector3.up;
    static Color sunCol = Color.white, fogColor = Color.gray;

    static float R() => (float)rng.NextDouble();
    static float R(float a, float b) => a + (b - a) * (float)rng.NextDouble();

    public static float Height(float x, float z)
    {
        float r = Mathf.Sqrt(x * x + z * z);
        float hills = (Mathf.PerlinNoise(x * 0.012f + 100, z * 0.012f + 50) - 0.5f) * 14f + (Mathf.PerlinNoise(x * 0.05f, z * 0.05f) - 0.5f) * 2.5f;
        float flat = (Mathf.PerlinNoise(x * 0.03f + 7, z * 0.03f + 3) - 0.5f) * 1.2f;
        float k = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(215f, 300f, r));
        float mid = (Mathf.PerlinNoise(x * 0.008f + 31, z * 0.008f + 77) - 0.5f) * 5f;   // пологие холмы внутри зоны боя
        return Mathf.Lerp(flat + mid, hills * 1.6f + 3f, k);
    }

    public static void Build(int map, int time, List<Vector3> lzs, int seed)
    {
        Clear();
        mapKind = map;
        rng = new System.Random(seed);
        Night = time == 2;
        keepOut.Clear();
        keepOut.AddRange(lzs);
        Root = new GameObject("Map");

        Color g1, g2, g3, fog;
        switch (map)
        {
            case 1: g1 = new Color(0.22f, 0.3f, 0.13f); g2 = new Color(0.17f, 0.24f, 0.1f); g3 = new Color(0.3f, 0.25f, 0.16f); fog = new Color(0.55f, 0.62f, 0.6f); dirtColor = new Color(0.35f, 0.3f, 0.22f); break;
            case 2: g1 = new Color(0.78f, 0.66f, 0.45f); g2 = new Color(0.7f, 0.57f, 0.38f); g3 = new Color(0.62f, 0.5f, 0.35f); fog = new Color(0.85f, 0.78f, 0.65f); dirtColor = new Color(0.75f, 0.64f, 0.46f); break;
            case 3: g1 = new Color(0.9f, 0.92f, 0.95f); g2 = new Color(0.82f, 0.85f, 0.9f); g3 = new Color(0.6f, 0.62f, 0.65f); fog = new Color(0.78f, 0.82f, 0.88f); dirtColor = new Color(0.9f, 0.92f, 0.95f); break;
            default: g1 = new Color(0.3f, 0.38f, 0.18f); g2 = new Color(0.25f, 0.32f, 0.14f); g3 = new Color(0.38f, 0.33f, 0.24f); fog = new Color(0.62f, 0.68f, 0.72f); dirtColor = new Color(0.42f, 0.38f, 0.3f); break;
        }
        Battle.DustColor = new Color(dirtColor.r, dirtColor.g, dirtColor.b, 0.45f);
        groundMat = Mats.Textured(Mats.GroundTex(g1, g2, g3, seed), Color.white, Vector2.one, map == 3 ? 0.35f : 0.08f);
        concreteMat = Mats.Textured(Mats.ConcreteTex(new Color(0.58f, 0.57f, 0.54f), 3), Color.white, Vector2.one, 0.15f);
        darkConcrete = Mats.Textured(Mats.ConcreteTex(new Color(0.4f, 0.4f, 0.39f), 5), Color.white, Vector2.one, 0.15f);

        BuildGround();
        foreach (var lz in lzs) Helipad(lz);
        BuildFacility();
        BuildOutposts();
        BuildRoads();
        BuildCover(map);
        BuildNature(map);
        BuildBounds();
        Lighting(map, time, fog);
        Mountains(map, fog);
        Physics.SyncTransforms();
    }

    public static void Clear()
    {
        if (Root != null) { Root.SetActive(false); Object.Destroy(Root); }
        Root = null;
        lamps.Clear();
        if (navInstance.valid) NavMesh.RemoveNavMeshData(navInstance);
        NavMesh.RemoveAllNavMeshData();
    }

    // ---------------- рельеф ----------------
    static void BuildGround()
    {
        int res = 210;
        float step = Size / res;
        var verts = new Vector3[(res + 1) * (res + 1)];
        var uvs = new Vector2[verts.Length];
        var tris = new int[res * res * 6];
        for (int z = 0; z <= res; z++)
            for (int x = 0; x <= res; x++)
            {
                float wx = -Size / 2 + x * step, wz = -Size / 2 + z * step;
                float h = Height(wx, wz);
                // площадки под вертолёты — ровные
                foreach (var k in keepOut)
                {
                    float d = Vector2.Distance(new Vector2(wx, wz), new Vector2(k.x, k.z));
                    if (d < 14f) h = Mathf.Lerp(Height(k.x, k.z), h, Mathf.SmoothStep(0, 1, (d - 9f) / 5f));
                }
                verts[z * (res + 1) + x] = new Vector3(wx, h, wz);
                uvs[z * (res + 1) + x] = new Vector2(wx / 9f, wz / 9f);
            }
        int t = 0;
        for (int z = 0; z < res; z++)
            for (int x = 0; x < res; x++)
            {
                int i = z * (res + 1) + x;
                tris[t++] = i; tris[t++] = i + res + 1; tris[t++] = i + 1;
                tris[t++] = i + 1; tris[t++] = i + res + 1; tris[t++] = i + res + 2;
            }
        var m = new Mesh { name = "ground", indexFormat = IndexFormat.UInt32 };
        m.vertices = verts; m.uv = uvs; m.triangles = tris;
        m.RecalculateNormals();
        m.RecalculateBounds();
        var go = new GameObject("Ground");
        go.transform.SetParent(Root.transform);
        go.AddComponent<MeshFilter>().sharedMesh = m;
        var mr = go.AddComponent<MeshRenderer>();
        mr.sharedMaterial = groundMat;
        mr.shadowCastingMode = ShadowCastingMode.Off;
        go.AddComponent<MeshCollider>().sharedMesh = m;
        var s = go.AddComponent<Surface>(); s.color = dirtColor;
    }

    public static float GroundAt(float x, float z) => Height(x, z);

    // ---------------- примитивы с коллайдерами ----------------
    static GameObject Solid(Vector3 pos, Vector3 size, Material mat, Quaternion rot, Color surf, bool metal = false, Transform parent = null)
    {
        var go = new GameObject("solid");
        go.transform.SetParent(parent != null ? parent : Root.transform, false);
        go.transform.position = pos;
        go.transform.rotation = rot;
        go.transform.localScale = size;
        go.AddComponent<MeshFilter>().sharedMesh = MeshKit.Cube;
        go.AddComponent<MeshRenderer>().sharedMaterial = mat;
        go.AddComponent<BoxCollider>();
        var s = go.AddComponent<Surface>(); s.color = surf; s.metal = metal;
        return go;
    }

    static Vector3 OnGround(float x, float z, float yOff = 0) => new Vector3(x, Height(x, z) + yOff, z);

    static bool Blocked(Vector3 p, float r)
    {
        foreach (var k in keepOut) if (Vector2.Distance(new Vector2(p.x, p.z), new Vector2(k.x, k.z)) < r + 13f) return true;
        if (Mathf.Abs(p.x) < 19f && Mathf.Abs(p.z) < 14f) return true; // здание в центре
        return false;
    }

    static void Helipad(Vector3 c)
    {
        float y = Height(c.x, c.z);
        var pad = Solid(new Vector3(c.x, y - 0.1f, c.z), new Vector3(12f, 0.4f, 12f), darkConcrete, Quaternion.identity, new Color(0.4f, 0.4f, 0.4f));
        var mark = Mats.Get(new Color(0.9f, 0.85f, 0.2f), 0.3f);
        var h = new GameObject("H"); h.transform.SetParent(Root.transform); h.transform.position = new Vector3(c.x, y + 0.11f, c.z);
        MeshKit.Box(h.transform, new Vector3(-1.2f, 0, 0), new Vector3(0.5f, 0.02f, 4f), mark);
        MeshKit.Box(h.transform, new Vector3(1.2f, 0, 0), new Vector3(0.5f, 0.02f, 4f), mark);
        MeshKit.Box(h.transform, Vector3.zero, new Vector3(2.4f, 0.02f, 0.5f), mark);
        for (int i = 0; i < 4; i++)
            MeshKit.Box(h.transform, Quaternion.Euler(0, i * 90, 0) * new Vector3(0, 0, 5.6f), new Vector3(10f, 0.02f, 0.25f), Mats.Get(Color.white * 0.85f), new Vector3(0, i * 90, 0));
        MeshKit.CombineParts(h.transform);
        // посадочные огни
        for (int i = 0; i < 4; i++)
        {
            Vector3 lp = new Vector3(c.x + (i % 2 == 0 ? -5.6f : 5.6f), y + 0.15f, c.z + (i < 2 ? -5.6f : 5.6f));
            var l = new GameObject("padLight"); l.transform.SetParent(Root.transform); l.transform.position = lp;
            MeshKit.Ball(l.transform, Vector3.zero, Vector3.one * 0.2f, Mats.Glow(new Color(1f, 0.6f, 0.1f), 5f));
        }
    }

    // ---------------- центральный комплекс ----------------
    static void BuildFacility()
    {
        var root = new GameObject("Facility").transform;
        root.SetParent(Root.transform);
        float y = Height(0, 0);
        Color cs = new Color(0.55f, 0.54f, 0.5f);
        float W = 30f, D = 20f, Hh = 5.5f, th = 0.6f;
        // пол
        Solid(new Vector3(0, y - 0.05f, 0), new Vector3(W + 2, 0.3f, D + 2), darkConcrete, Quaternion.identity, cs, false, root);
        // наружные стены с проходами
        WallX(root, -W / 2, W / 2, -D / 2, y, Hh, th, new[] { -8f, 0f, 8f }, 2.4f, cs);
        WallX(root, -W / 2, W / 2, D / 2, y, Hh, th, new[] { -8f, 0f, 8f }, 2.4f, cs);
        WallZ(root, -D / 2, D / 2, -W / 2, y, Hh, th, new[] { 0f }, 2.6f, cs);
        WallZ(root, -D / 2, D / 2, W / 2, y, Hh, th, new[] { 0f }, 2.6f, cs);
        // внутренние стены
        WallX(root, -W / 2, -4f, 0, y, Hh, 0.4f, new[] { -10f }, 2f, cs);
        WallX(root, 4f, W / 2, 0, y, Hh, 0.4f, new[] { 10f }, 2f, cs);
        WallZ(root, -D / 2, D / 2, -4f, y, Hh, 0.4f, new[] { -5f, 5f }, 2f, cs);
        WallZ(root, -D / 2, D / 2, 4f, y, Hh, 0.4f, new[] { -5f, 5f }, 2f, cs);
        // крыша с проёмом в центре (свет)
        Solid(new Vector3(-W / 4 - 2, y + Hh + 0.25f, 0), new Vector3(W / 2 - 4, 0.5f, D + 1), concreteMat, Quaternion.identity, cs, false, root);
        Solid(new Vector3(W / 4 + 2, y + Hh + 0.25f, 0), new Vector3(W / 2 - 4, 0.5f, D + 1), concreteMat, Quaternion.identity, cs, false, root);
        Solid(new Vector3(0, y + Hh + 0.25f, -D / 4 - 2), new Vector3(8, 0.5f, D / 2 - 4), concreteMat, Quaternion.identity, cs, false, root);
        Solid(new Vector3(0, y + Hh + 0.25f, D / 4 + 2), new Vector3(8, 0.5f, D / 2 - 4), concreteMat, Quaternion.identity, cs, false, root);
        // логотип Фонда на крыше-парапете
        var font = Helicopter.UIFont();
        if (font != null)
        {
            foreach (int side in new[] { -1, 1 })
            {
                var tg = new GameObject("sign");
                tg.transform.SetParent(root);
                tg.transform.position = new Vector3(0, y + Hh - 1.2f, side * (D / 2 + th / 2 + 0.02f));
                tg.transform.rotation = Quaternion.Euler(0, side > 0 ? 180 : 0, 0);
                tg.transform.localScale = Vector3.one * 0.25f;
                var tm = tg.AddComponent<TextMesh>();
                tm.font = font; tm.fontSize = 60; tm.anchor = TextAnchor.MiddleCenter;
                tm.text = "ФОНД SCP — ЗОНА-19\nОБЕСПЕЧИТЬ. УДЕРЖАТЬ. СОХРАНИТЬ.";
                tm.color = new Color(0.1f, 0.1f, 0.1f);
                tm.alignment = TextAlignment.Center;
                tg.GetComponent<MeshRenderer>().sharedMaterial = Helicopter.TextMat(font);
                // знак Фонда (круг со стрелками)
                var logo = new GameObject("logo");
                logo.transform.SetParent(root);
                logo.transform.position = new Vector3(side * 0 + 9f, y + Hh - 1.8f, side * (D / 2 + th / 2 + 0.03f));
                logo.transform.rotation = Quaternion.Euler(90, 0, 0);
                MeshKit.Cyl(logo.transform, Vector3.zero, 2.2f, 0.02f, new Color(0.9f, 0.9f, 0.9f));
                MeshKit.Cyl(logo.transform, new Vector3(0, side * 0.01f, 0), 1.5f, 0.02f, new Color(0.12f, 0.12f, 0.12f));
                MeshKit.Cyl(logo.transform, new Vector3(0, side * 0.02f, 0), 0.9f, 0.02f, new Color(0.9f, 0.9f, 0.9f));
                for (int a = 0; a < 3; a++)
                    MeshKit.Box(logo.transform, Quaternion.Euler(0, a * 120, 0) * new Vector3(0, side * 0.025f, 0.9f), new Vector3(0.3f, 0.02f, 0.9f), Mats.Get(new Color(0.9f, 0.9f, 0.9f)), new Vector3(0, a * 120, 0));
            }
        }
        // ящики и стеллажи внутри
        for (int i = 0; i < 10; i++)
        {
            float x = R(-W / 2 + 2, W / 2 - 2), z = R(-D / 2 + 2, D / 2 - 2);
            if (Mathf.Abs(x) < 6 || Mathf.Abs(z) < 2.5f) continue;
            Crate(new Vector3(x, y, z), root);
        }
        // свет внутри
        if (Night)
            for (int i = -1; i <= 1; i += 2)
                for (int j = -1; j <= 1; j += 2)
                    Lamp(new Vector3(i * 9f, y + Hh - 0.4f, j * 5f), new Color(1f, 0.9f, 0.7f), 14f, 2f, root);
    }

    static void WallX(Transform p, float x0, float x1, float z, float y, float h, float th, float[] doors, float dw, Color cs)
    {
        var xs = new List<float> { x0 };
        foreach (var d in doors) { xs.Add(d - dw / 2); xs.Add(d + dw / 2); }
        xs.Add(x1);
        for (int i = 0; i + 1 < xs.Count; i += 2)
        {
            float a = xs[i], b = xs[i + 1];
            if (b - a < 0.05f) continue;
            Solid(new Vector3((a + b) / 2, y + h / 2, z), new Vector3(b - a, h, th), concreteMat, Quaternion.identity, cs, false, p);
        }
        foreach (var d in doors) Solid(new Vector3(d, y + h - 0.6f, z), new Vector3(dw, 1.2f, th), concreteMat, Quaternion.identity, cs, false, p);
    }

    static void WallZ(Transform p, float z0, float z1, float x, float y, float h, float th, float[] doors, float dw, Color cs)
    {
        var zs = new List<float> { z0 };
        foreach (var d in doors) { zs.Add(d - dw / 2); zs.Add(d + dw / 2); }
        zs.Add(z1);
        for (int i = 0; i + 1 < zs.Count; i += 2)
        {
            float a = zs[i], b = zs[i + 1];
            if (b - a < 0.05f) continue;
            Solid(new Vector3(x, y + h / 2, (a + b) / 2), new Vector3(th, h, b - a), concreteMat, Quaternion.identity, cs, false, p);
        }
        foreach (var d in doors) Solid(new Vector3(x, y + h - 0.6f, d), new Vector3(th, 1.2f, dw), concreteMat, Quaternion.identity, cs, false, p);
    }

    static void Crate(Vector3 pos, Transform parent)
    {
        float s = R(0.9f, 1.4f);
        var wood = Mats.Get(new Color(0.45f, 0.33f, 0.2f), 0.1f);
        var go = Solid(pos + Vector3.up * s / 2, Vector3.one * s, wood, Quaternion.Euler(0, R(0, 90), 0), new Color(0.45f, 0.33f, 0.2f), false, parent);
        if (R() < 0.4f) Solid(pos + Vector3.up * (s + s * 0.4f), Vector3.one * s * 0.8f, wood, Quaternion.Euler(0, R(0, 90), 0), new Color(0.45f, 0.33f, 0.2f), false, parent);
    }

    // ---------------- укрытия ----------------
    static void BuildCover(int map)
    {
        var root = new GameObject("Cover").transform;
        root.SetParent(Root.transform);
        Color[] contCols = { new Color(0.6f, 0.15f, 0.1f), new Color(0.15f, 0.3f, 0.55f), new Color(0.2f, 0.4f, 0.2f), new Color(0.75f, 0.45f, 0.1f), new Color(0.4f, 0.4f, 0.42f) };
        int n = 0;
        // контейнеры
        for (int i = 0; i < 220 && n < 44; i++)
        {
            Vector3 p = new Vector3(R(-Play + 10, Play - 10), 0, R(-Play + 10, Play - 10));
            if (Blocked(p, 5)) continue;
            n++;
            p = OnGround(p.x, p.z);
            var rot = Quaternion.Euler(0, R() < 0.5f ? 0 : 90 + R(-10, 10), 0);
            Color c = contCols[rng.Next(contCols.Length)];
            var cont = Solid(p + Vector3.up * 1.3f, new Vector3(2.5f, 2.6f, 6.1f), Mats.Get(c, 0.3f, 0.3f), rot, c, true, root);
            for (int r = 0; r < 8; r++)
            {
                MeshKit.Box(cont.transform, new Vector3(0.505f, 0, -0.45f + r * 0.13f), new Vector3(0.02f, 0.95f, 0.02f), Mats.Get(c * 0.75f));
                MeshKit.Box(cont.transform, new Vector3(-0.505f, 0, -0.45f + r * 0.13f), new Vector3(0.02f, 0.95f, 0.02f), Mats.Get(c * 0.75f));
            }
            if (R() < 0.3f) Solid(p + Vector3.up * 3.9f + rot * new Vector3(0, 0, R(-1, 1)), new Vector3(2.5f, 2.6f, 6.1f), Mats.Get(contCols[rng.Next(contCols.Length)], 0.3f, 0.3f), rot * Quaternion.Euler(0, R(-8, 8), 0), c, true, root);
        }
        // бетонные блоки
        for (int i = 0; i < 320 && n < 150; i++)
        {
            Vector3 p = new Vector3(R(-Play + 5, Play - 5), 0, R(-Play + 5, Play - 5));
            if (Blocked(p, 3)) continue;
            n++;
            float yaw = R(0, 180);
            int cnt = rng.Next(2, 5);
            for (int k = 0; k < cnt; k++)
            {
                Vector3 q = p + Quaternion.Euler(0, yaw, 0) * new Vector3(k * 3.1f, 0, 0);
                q = OnGround(q.x, q.z);
                Barrier(q, yaw + R(-5, 5), root);
            }
        }
        // мешки с песком полукругом
        for (int i = 0; i < 320 && n < 270; i++)
        {
            Vector3 p = new Vector3(R(-Play + 8, Play - 8), 0, R(-Play + 8, Play - 8));
            if (Blocked(p, 3)) continue;
            n++;
            float face = R(0, 360);
            Sandbags(p, face, root);
        }
        // вышки
        Vector3[] towers = { new Vector3(-60, 0, -30), new Vector3(60, 0, 30), new Vector3(-55, 0, 40), new Vector3(55, 0, -40),
            new Vector3(-150, 0, -120), new Vector3(150, 0, -120), new Vector3(-150, 0, 120), new Vector3(150, 0, 120), new Vector3(0, 0, -150), new Vector3(0, 0, 150) };
        foreach (var tp in towers) if (!Blocked(tp, 4)) Tower(OnGround(tp.x, tp.z), root);
        // фонари
        for (int i = 0; i < 14; i++)
        {
            float a = i / 14f * Mathf.PI * 2f;
            Vector3 p = new Vector3(Mathf.Cos(a) * 42f, 0, Mathf.Sin(a) * 34f);
            if (Blocked(p, 1)) continue;
            LightPole(OnGround(p.x, p.z), root);
        }
        // грузовики
        for (int i = 0; i < 90 && n < 300; i++)
        {
            Vector3 p = new Vector3(R(-Play + 15, Play - 15), 0, R(-Play + 15, Play - 15));
            if (Blocked(p, 5)) continue;
            n++;
            Truck(OnGround(p.x, p.z), R(0, 360), root);
        }
        // ящики
        for (int i = 0; i < 160; i++)
        {
            Vector3 p = new Vector3(R(-Play, Play), 0, R(-Play, Play));
            if (Blocked(p, 2)) continue;
            Crate(OnGround(p.x, p.z), root);
        }
        foreach (Transform ch in root) if (ch.name == "solid") MeshKit.CombineParts(ch);
    }

    static void Barrier(Vector3 p, float yaw, Transform root)
    {
        var rot = Quaternion.Euler(0, yaw, 0);
        Color c = new Color(0.62f, 0.6f, 0.56f);
        var go = new GameObject("barrier"); go.transform.SetParent(root); go.transform.position = p; go.transform.rotation = rot;
        MeshKit.Box(go.transform, new Vector3(0, 0.2f, 0), new Vector3(3f, 0.4f, 0.75f), concreteMat);
        MeshKit.Part(go.transform, MeshKit.Frustum(0.45f, 4), concreteMat, new Vector3(0, 0.75f, 0), new Vector3(3f * 1.414f, 0.7f, 0.65f * 1.414f), new Vector3(0, 45, 0));
        MeshKit.Box(go.transform, new Vector3(0, 0.8f, 0.0f), new Vector3(3f, 0.06f, 0.42f), Mats.Get(new Color(0.9f, 0.75f, 0.1f)));
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 0.55f, 0); bc.size = new Vector3(3f, 1.1f, 0.6f);
        var s = go.AddComponent<Surface>(); s.color = c;
    }

    static void Sandbags(Vector3 p, float face, Transform root)
    {
        var go = new GameObject("sandbags"); go.transform.SetParent(root);
        p = OnGround(p.x, p.z);
        go.transform.position = p;
        go.transform.rotation = Quaternion.Euler(0, face, 0);
        Color sc = mapKind == 2 ? new Color(0.72f, 0.62f, 0.45f) : mapKind == 3 ? new Color(0.75f, 0.75f, 0.72f) : new Color(0.55f, 0.5f, 0.36f);
        var m = Mats.Get(sc, 0.05f);
        int segs = 7;
        for (int row = 0; row < 3; row++)
            for (int i = 0; i < segs; i++)
            {
                float a = (i - (segs - 1) / 2f) * 0.22f + (row % 2) * 0.11f;
                Vector3 lp = new Vector3(Mathf.Sin(a) * 3f, 0.16f + row * 0.28f, Mathf.Cos(a) * 3f - 3f);
                MeshKit.Ball(go.transform, lp, new Vector3(0.8f, 0.32f, 0.45f), m, new Vector3(0, a * Mathf.Rad2Deg, 0));
            }
        MeshKit.CombineParts(go.transform);
        for (int i = 0; i < 3; i++)
        {
            float a = (i - 1) * 0.5f;
            var cgo = new GameObject("col"); cgo.transform.SetParent(go.transform, false);
            cgo.transform.localPosition = new Vector3(Mathf.Sin(a) * 3f, 0.45f, Mathf.Cos(a) * 3f - 3f);
            cgo.transform.localRotation = Quaternion.Euler(0, a * Mathf.Rad2Deg, 0);
            var bc = cgo.AddComponent<BoxCollider>(); bc.size = new Vector3(1.6f, 0.9f, 0.5f);
            var s = cgo.AddComponent<Surface>(); s.color = sc;
        }
    }

    static void Tower(Vector3 p, Transform root)
    {
        var go = new GameObject("tower"); go.transform.SetParent(root); go.transform.position = p;
        var metal = Mats.Get(new Color(0.3f, 0.3f, 0.3f), 0.4f, 0.5f);
        for (int i = 0; i < 4; i++)
        {
            Vector3 lp = new Vector3(i % 2 == 0 ? -1.4f : 1.4f, 3.5f, i < 2 ? -1.4f : 1.4f);
            var leg = new GameObject("leg"); leg.transform.SetParent(go.transform, false); leg.transform.localPosition = lp;
            MeshKit.Box(leg.transform, Vector3.zero, new Vector3(0.25f, 7f, 0.25f), metal);
            var bc = leg.AddComponent<BoxCollider>(); bc.size = new Vector3(0.25f, 7f, 0.25f);
            leg.AddComponent<Surface>().metal = true;
        }
        MeshKit.Box(go.transform, new Vector3(0, 7.1f, 0), new Vector3(3.6f, 0.25f, 3.6f), metal);
        MeshKit.Box(go.transform, new Vector3(0, 7.7f, 1.7f), new Vector3(3.6f, 1f, 0.1f), metal);
        MeshKit.Box(go.transform, new Vector3(0, 7.7f, -1.7f), new Vector3(3.6f, 1f, 0.1f), metal);
        MeshKit.Box(go.transform, new Vector3(1.7f, 7.7f, 0), new Vector3(0.1f, 1f, 3.6f), metal);
        MeshKit.Box(go.transform, new Vector3(-1.7f, 7.7f, 0), new Vector3(0.1f, 1f, 3.6f), metal);
        MeshKit.Part(go.transform, MeshKit.Frustum(0.05f, 4), Mats.Get(new Color(0.25f, 0.25f, 0.22f)), new Vector3(0, 9.6f, 0), new Vector3(5.2f, 1.2f, 5.2f), new Vector3(0, 45, 0));
        for (int i = 0; i < 4; i++)
            MeshKit.Box(go.transform, new Vector3(i % 2 == 0 ? -1.6f : 1.6f, 8.5f, i < 2 ? -1.6f : 1.6f), new Vector3(0.1f, 2f, 0.1f), metal);
        MeshKit.CombineParts(go.transform);
        var top = new GameObject("deck"); top.transform.SetParent(go.transform, false); top.transform.localPosition = new Vector3(0, 7.5f, 0);
        var tbc = top.AddComponent<BoxCollider>(); tbc.size = new Vector3(3.6f, 1.2f, 3.6f);
        top.AddComponent<Surface>().metal = true;
        // прожектор
        var lg = new GameObject("search"); lg.transform.SetParent(go.transform, false);
        lg.transform.localPosition = new Vector3(0, 8.4f, 1.6f);
        lg.transform.localRotation = Quaternion.Euler(35, R(-40, 40), 0);
        MeshKit.Cyl(lg.transform, Vector3.zero, 0.5f, 0.5f, Mats.Get(new Color(0.2f, 0.2f, 0.2f)), new Vector3(90, 0, 0));
        if (Night)
        {
            MeshKit.Cyl(lg.transform, new Vector3(0, 0, 0.26f), 0.45f, 0.02f, Mats.Glow(new Color(1f, 0.95f, 0.8f), 5f), new Vector3(90, 0, 0));
            var l = lg.AddComponent<Light>(); l.type = LightType.Spot; l.spotAngle = 35; l.range = 70; l.intensity = 4f; l.color = new Color(1f, 0.95f, 0.85f);
            l.shadows = LightShadows.Hard;
            lamps.Add(l);
            lg.AddComponent<Searchlight>();
        }
    }

    static void LightPole(Vector3 p, Transform root)
    {
        var go = new GameObject("pole"); go.transform.SetParent(root); go.transform.position = p;
        var metal = Mats.Get(new Color(0.25f, 0.25f, 0.26f), 0.4f, 0.6f);
        MeshKit.Cyl(go.transform, new Vector3(0, 4f, 0), 0.18f, 8f, metal);
        MeshKit.Box(go.transform, new Vector3(0, 7.9f, 0.6f), new Vector3(0.15f, 0.15f, 1.4f), metal);
        MeshKit.Box(go.transform, new Vector3(0, 7.8f, 1.2f), new Vector3(0.5f, 0.15f, 0.7f), metal);
        MeshKit.Box(go.transform, new Vector3(0, 7.71f, 1.2f), new Vector3(0.4f, 0.02f, 0.6f), Night ? Mats.Glow(new Color(1f, 0.85f, 0.6f), 4f) : Mats.Get(new Color(0.8f, 0.8f, 0.75f), 0.8f));
        MeshKit.CombineParts(go.transform);
        var c = go.AddComponent<CapsuleCollider>(); c.center = new Vector3(0, 4, 0); c.height = 8; c.radius = 0.12f;
        go.AddComponent<Surface>().metal = true;
        if (Night) Lamp(p + new Vector3(0, 7.6f, 0) + go.transform.rotation * new Vector3(0, 0, 1.2f), new Color(1f, 0.82f, 0.55f), 22f, 2.4f, go.transform, true);
    }

    static void Lamp(Vector3 pos, Color c, float range, float intensity, Transform parent, bool spot = false)
    {
        var lg = new GameObject("lamp"); lg.transform.SetParent(parent); lg.transform.position = pos;
        var l = lg.AddComponent<Light>();
        l.type = spot ? LightType.Spot : LightType.Point;
        if (spot) { lg.transform.rotation = Quaternion.Euler(90, 0, 0); l.spotAngle = 110; }
        l.color = c; l.range = range; l.intensity = intensity; l.shadows = LightShadows.None;
        lamps.Add(l);
    }

    static void Truck(Vector3 p, float yaw, Transform root)
    {
        var go = new GameObject("truck"); go.transform.SetParent(root); go.transform.position = p; go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        Color body = mapKind == 2 ? new Color(0.6f, 0.52f, 0.36f) : new Color(0.25f, 0.28f, 0.2f);
        var bm = Mats.Get(body, 0.3f, 0.2f);
        var dark = Mats.Get(new Color(0.06f, 0.06f, 0.06f), 0.4f);
        MeshKit.Box(go.transform, new Vector3(0, 1.0f, 1.9f), new Vector3(2.3f, 1.6f, 1.8f), bm);
        MeshKit.Box(go.transform, new Vector3(0, 1.45f, 2.81f), new Vector3(2f, 0.6f, 0.02f), Mats.Glass(new Color(0.1f, 0.15f, 0.2f, 0.7f)));
        MeshKit.Box(go.transform, new Vector3(0, 0.75f, -1.1f), new Vector3(2.4f, 0.3f, 4.2f), bm);
        MeshKit.Box(go.transform, new Vector3(0, 1.8f, -1.1f), new Vector3(2.4f, 1.8f, 4.2f), Mats.Get(body * 0.8f, 0.1f));
        foreach (float z in new[] { 1.9f, -0.3f, -2.2f })
            foreach (float x in new[] { -1.1f, 1.1f })
                MeshKit.Cyl(go.transform, new Vector3(x, 0.5f, z), 1f, 0.35f, dark, new Vector3(0, 0, 90));
        MeshKit.CombineParts(go.transform);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 1.4f, 0.1f); bc.size = new Vector3(2.4f, 2.6f, 6.4f);
        var s = go.AddComponent<Surface>(); s.color = body; s.metal = true;
    }

    // ---------------- природа ----------------
    static void BuildNature(int map)
    {
        var root = new GameObject("Nature").transform;
        root.SetParent(Root.transform);
        int trees = map == 1 ? 1500 : map == 2 ? 90 : map == 3 ? 900 : 800;
        int rocks = map == 2 ? 300 : 140;
        for (int i = 0; i < trees; i++)
        {
            float a = R(0, Mathf.PI * 2);
            float r = R() < (map == 1 ? 0.45f : 0.25f) ? R(40, Play) : R(Play - 20, Size / 2 - 8);
            Vector3 p = new Vector3(Mathf.Cos(a) * r, 0, Mathf.Sin(a) * r);
            if (Blocked(p, 3)) continue;
            p = OnGround(p.x, p.z, -0.1f);
            if (map == 2) Cactus(p, root);
            else Tree(p, root, map == 3);
        }
        for (int i = 0; i < rocks; i++)
        {
            Vector3 p = new Vector3(R(-Size / 2 + 10, Size / 2 - 10), 0, R(-Size / 2 + 10, Size / 2 - 10));
            if (Blocked(p, 3)) continue;
            Rock(OnGround(p.x, p.z), root);
        }
        // кусты/трава
        if (map != 2)
        {
            var bushM = Mats.Get(map == 3 ? new Color(0.7f, 0.75f, 0.78f) : new Color(0.18f, 0.28f, 0.1f), 0.05f);
            var bushes = new GameObject("bushes"); bushes.transform.SetParent(root);
            int made = 0;
            for (int i = 0; i < 900; i++)
            {
                Vector3 p = new Vector3(R(-Size / 2 + 5, Size / 2 - 5), 0, R(-Size / 2 + 5, Size / 2 - 5));
                if (Blocked(p, 1)) continue;
                p = OnGround(p.x, p.z);
                MeshKit.Ball(bushes.transform, p + Vector3.up * 0.25f, new Vector3(R(0.8f, 1.6f), R(0.5f, 0.9f), R(0.8f, 1.6f)), bushM);
                made++;
                if (made % 120 == 0) { MeshKit.CombineParts(bushes.transform); bushes = new GameObject("bushes"); bushes.transform.SetParent(root); }
            }
            MeshKit.CombineParts(bushes.transform);
        }
    }

    static void Tree(Vector3 p, Transform root, bool snow)
    {
        var go = new GameObject("tree"); go.transform.SetParent(root); go.transform.position = p;
        float h = R(7f, 13f);
        var bark = Mats.Get(new Color(0.28f, 0.2f, 0.13f), 0.05f);
        MeshKit.Cyl(go.transform, new Vector3(0, h * 0.25f, 0), 0.35f, h * 0.5f, bark);
        Color leaf = snow ? new Color(0.22f, 0.3f, 0.22f) : new Color(R(0.1f, 0.16f), R(0.22f, 0.3f), R(0.08f, 0.12f));
        var lm = Mats.Get(leaf, 0.05f);
        int layers = 4;
        for (int i = 0; i < layers; i++)
        {
            float k = i / (float)layers;
            float w = Mathf.Lerp(4.2f, 1.2f, k) * (h / 10f);
            MeshKit.Part(go.transform, MeshKit.Frustum(0.05f, 8), lm, new Vector3(0, h * (0.3f + k * 0.62f), 0), new Vector3(w, h * 0.32f, w), new Vector3(0, R(0, 90), 0));
            if (snow) MeshKit.Part(go.transform, MeshKit.Frustum(0.05f, 8), Mats.Get(new Color(0.92f, 0.94f, 0.97f), 0.3f), new Vector3(0, h * (0.32f + k * 0.62f) + 0.15f, 0), new Vector3(w * 0.75f, h * 0.25f, w * 0.75f));
        }
        MeshKit.CombineParts(go.transform);
        var c = go.AddComponent<CapsuleCollider>(); c.center = new Vector3(0, h * 0.4f, 0); c.height = h * 0.8f; c.radius = 0.35f;
        var s = go.AddComponent<Surface>(); s.color = new Color(0.35f, 0.26f, 0.17f);
    }

    static void Cactus(Vector3 p, Transform root)
    {
        var go = new GameObject("cactus"); go.transform.SetParent(root); go.transform.position = p;
        var m = Mats.Get(new Color(0.25f, 0.4f, 0.2f), 0.2f);
        float h = R(2.5f, 4.5f);
        MeshKit.Caps(go.transform, new Vector3(0, h / 2, 0), 0.45f, h, new Color(0.25f, 0.4f, 0.2f));
        MeshKit.Caps(go.transform, new Vector3(0.5f, h * 0.55f, 0), 0.3f, 1.2f, new Color(0.25f, 0.4f, 0.2f));
        MeshKit.Caps(go.transform, new Vector3(-0.45f, h * 0.45f, 0), 0.28f, 1f, new Color(0.25f, 0.4f, 0.2f));
        MeshKit.CombineParts(go.transform);
        var c = go.AddComponent<CapsuleCollider>(); c.center = new Vector3(0, h / 2, 0); c.height = h; c.radius = 0.3f;
        go.AddComponent<Surface>().color = new Color(0.3f, 0.45f, 0.25f);
    }

    static void Rock(Vector3 p, Transform root)
    {
        var go = new GameObject("rock"); go.transform.SetParent(root); go.transform.position = p;
        Color c = mapKind == 2 ? new Color(0.62f, 0.5f, 0.38f) : mapKind == 3 ? new Color(0.55f, 0.56f, 0.6f) : new Color(0.42f, 0.41f, 0.4f);
        float s = R(1f, 3.2f);
        go.transform.rotation = Quaternion.Euler(R(-10, 10), R(0, 360), R(-10, 10));
        MeshKit.Ball(go.transform, Vector3.zero, new Vector3(s * 1.4f, s * 0.9f, s), Mats.Get(c, 0.1f));
        MeshKit.Ball(go.transform, new Vector3(s * 0.4f, s * 0.2f, 0.2f), new Vector3(s * 0.8f, s * 0.7f, s * 0.8f), Mats.Get(c * 0.9f, 0.1f));
        MeshKit.CombineParts(go.transform);
        var col = go.AddComponent<SphereCollider>(); col.radius = s * 0.45f;
        go.AddComponent<Surface>().color = c;
    }

    static void BuildBounds()
    {
        var root = new GameObject("Bounds").transform;
        root.SetParent(Root.transform);
        float e = Size / 2f - 12f;
        for (int i = 0; i < 4; i++)
        {
            var w = new GameObject("wall"); w.transform.SetParent(root);
            w.transform.position = Quaternion.Euler(0, i * 90, 0) * new Vector3(0, 20, e);
            w.transform.rotation = Quaternion.Euler(0, i * 90, 0);
            var bc = w.AddComponent<BoxCollider>(); bc.size = new Vector3(e * 2, 60, 2);
            w.layer = 2; // Ignore Raycast — не мешает пулям и видимости
        }
    }

    // ---------------- освещение ----------------
    static void Lighting(int map, int time, Color fog)
    {
        var sunGo = new GameObject("Sun");
        sunGo.transform.SetParent(Root.transform);
        var sun = sunGo.AddComponent<Light>();
        sun.type = LightType.Directional;
        sun.shadows = LightShadows.Soft;
        sun.shadowStrength = 0.85f;
        sun.shadowBias = 0.04f;
        sun.shadowNormalBias = 0.3f;
        RenderSettings.sun = sun;
        var skyShader = Shader.Find("SCP/Sky");
        var sky = new Material(skyShader != null ? skyShader : Shader.Find("Skybox/Procedural"));
        Color amb1, amb2, amb3;
        float cover = map == 2 ? 0.22f : map == 1 ? 0.55f : map == 3 ? 0.62f : 0.42f;
        switch (time)
        {
            case 1: // закат
                sunGo.transform.rotation = Quaternion.Euler(9f, 250f, 0);
                sun.color = new Color(1f, 0.6f, 0.35f); sun.intensity = 1.15f;
                amb1 = new Color(0.45f, 0.38f, 0.42f); amb2 = new Color(0.32f, 0.26f, 0.24f); amb3 = new Color(0.15f, 0.12f, 0.1f);
                fog = Color.Lerp(fog, new Color(0.8f, 0.5f, 0.35f), 0.6f);
                Sky(sky, new Color(0.16f, 0.2f, 0.42f), new Color(0.98f, 0.55f, 0.32f), fog, new Color(1f, 0.55f, 0.25f), new Color(1f, 0.68f, 0.48f), new Color(0.36f, 0.24f, 0.32f), cover + 0.1f, 0f);
                break;
            case 2: // ночь
                sunGo.transform.rotation = Quaternion.Euler(38f, 120f, 0);
                sun.color = new Color(0.55f, 0.65f, 1f); sun.intensity = 0.16f;
                amb1 = new Color(0.07f, 0.08f, 0.13f); amb2 = new Color(0.05f, 0.06f, 0.09f); amb3 = new Color(0.02f, 0.02f, 0.03f);
                fog = new Color(0.03f, 0.04f, 0.07f);
                Sky(sky, new Color(0.008f, 0.012f, 0.035f), new Color(0.04f, 0.055f, 0.1f), fog, new Color(0, 0, 0), new Color(0.09f, 0.1f, 0.14f), new Color(0.025f, 0.03f, 0.05f), cover * 0.7f, 1f);
                sky.SetVector("_SunDir", new Vector4(0, -1, 0, 0));
                sky.SetVector("_MoonDir", -sunGo.transform.forward);
                break;
            default:
                sunGo.transform.rotation = Quaternion.Euler(48f, 35f, 0);
                sun.color = map == 2 ? new Color(1f, 0.93f, 0.8f) : new Color(1f, 0.96f, 0.9f); sun.intensity = 1.25f;
                amb1 = new Color(0.55f, 0.6f, 0.7f); amb2 = new Color(0.4f, 0.4f, 0.38f); amb3 = new Color(0.2f, 0.18f, 0.15f);
                Sky(sky, map == 2 ? new Color(0.25f, 0.45f, 0.78f) : new Color(0.2f, 0.4f, 0.78f), map == 2 ? new Color(0.85f, 0.82f, 0.75f) : new Color(0.66f, 0.79f, 0.93f), fog, new Color(1f, 0.95f, 0.85f), new Color(1f, 1f, 1f), new Color(0.55f, 0.6f, 0.68f), cover, 0f);
                break;
        }
        if (time != 2) sky.SetVector("_SunDir", -sunGo.transform.forward);
        sunDir = -sunGo.transform.forward;
        sunCol = sun.color * sun.intensity;
        if (skyShader == null)
        {
            sky.SetFloat("_SunSize", 0.04f);
            sky.SetColor("_GroundColor", fog * 0.8f);
        }
        RenderSettings.skybox = sky;
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = amb1;
        RenderSettings.ambientEquatorColor = amb2;
        RenderSettings.ambientGroundColor = amb3;
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogColor = fog;
        RenderSettings.fogDensity = time == 2 ? 0.009f : map == 1 ? 0.0055f : map == 3 ? 0.006f : 0.0035f;
        fogColor = fog;
        RenderSettings.reflectionIntensity = time == 2 ? 0.2f : 0.7f;
        QualitySettings.shadowDistance = 140f;
        QualitySettings.shadowCascades = 2;
        QualitySettings.pixelLightCount = time == 2 ? 10 : 4;
        DynamicGI.UpdateEnvironment();
    }

    static void Sky(Material m, Color zenith, Color horizon, Color haze, Color sun, Color cloudLit, Color cloudShadow, float cover, float stars)
    {
        m.SetColor("_Zenith", zenith);
        m.SetColor("_Horizon", horizon);
        m.SetColor("_Ground", haze * 0.7f);
        m.SetColor("_Haze", Color.Lerp(horizon, haze, 0.6f));
        m.SetColor("_SunColor", sun);
        m.SetColor("_CloudColor", cloudLit);
        m.SetColor("_CloudShadow", cloudShadow);
        m.SetFloat("_CloudCover", cover);
        m.SetFloat("_Stars", stars);
        m.SetFloat("_SunSize", 1f);
    }

    // ---------------- горы на горизонте ----------------
    static void Mountains(int map, Color fog)
    {
        var sh = Shader.Find("SCP/Distant");
        if (sh == null) return;
        var root = new GameObject("Mountains").transform;
        root.SetParent(Root.transform);
        Color rock = map == 2 ? new Color(0.62f, 0.48f, 0.34f) : map == 3 ? new Color(0.45f, 0.48f, 0.53f) : map == 1 ? new Color(0.2f, 0.28f, 0.18f) : new Color(0.32f, 0.36f, 0.3f);
        Color snow = new Color(0.93f, 0.95f, 0.98f);
        bool snowy = map != 2;
        float[] radii = { 760f, 920f, 1100f };
        float[] haze = { 0.32f, 0.52f, 0.7f };
        for (int ring = 0; ring < 3; ring++)
        {
            int seg = 96;
            float r = radii[ring];
            var v = new List<Vector3>(); var c = new List<Color>(); var t = new List<int>();
            var peaks = new float[seg + 1];
            for (int i = 0; i <= seg; i++)
            {
                float a = i / (float)seg * Mathf.PI * 2f;
                float n = Mathf.PerlinNoise(Mathf.Cos(a) * 2.2f + ring * 7f + 10f, Mathf.Sin(a) * 2.2f + ring * 3f + 10f);
                float n2 = Mathf.PerlinNoise(Mathf.Cos(a) * 9f + ring * 5f, Mathf.Sin(a) * 9f + 40f);
                peaks[i] = (40f + n * (map == 2 ? 110f : 190f) + n2 * 45f) * (1f + ring * 0.35f);
            }
            peaks[seg] = peaks[0];
            for (int i = 0; i < seg; i++)
            {
                float a0 = i / (float)seg * Mathf.PI * 2f, a1 = (i + 1) / (float)seg * Mathf.PI * 2f, am = (a0 + a1) * 0.5f;
                Vector3 d0 = new Vector3(Mathf.Cos(a0), 0, Mathf.Sin(a0)), d1 = new Vector3(Mathf.Cos(a1), 0, Mathf.Sin(a1)), dm = new Vector3(Mathf.Cos(am), 0, Mathf.Sin(am));
                float jag = (Mathf.PerlinNoise(i * 0.7f + ring * 13f, 3f) - 0.3f) * 60f * (1f + ring * 0.3f);
                Vector3 b0 = d0 * (r + 60f) + Vector3.down * 40f, b1 = d1 * (r + 60f) + Vector3.down * 40f;
                Vector3 p0 = d0 * r + Vector3.up * peaks[i], p1 = d1 * r + Vector3.up * peaks[i + 1];
                Vector3 pm = dm * (r - 25f) + Vector3.up * (Mathf.Max(peaks[i], peaks[i + 1]) + jag);
                Vector3 bm = dm * (r + 60f) + Vector3.down * 40f;
                void Tri(Vector3 x, Vector3 y, Vector3 z)
                {
                    // лицом к центру карты
                    Vector3 nrm = Vector3.Cross(y - x, z - x);
                    int k = v.Count;
                    if (Vector3.Dot(nrm, -(x + y + z)) < 0) { var tmp = y; y = z; z = tmp; }
                    foreach (var q in new[] { x, y, z })
                    {
                        v.Add(q);
                        float hk = Mathf.InverseLerp(0f, 260f * (1f + ring * 0.35f), q.y);
                        Color col = Color.Lerp(rock * 0.75f, rock * 1.1f, hk);
                        if (snowy && q.y > 150f * (1f + ring * 0.3f)) col = snow;
                        c.Add(col);
                    }
                    t.Add(k); t.Add(k + 1); t.Add(k + 2);
                }
                Tri(b0, p0, pm); Tri(b0, pm, bm); Tri(bm, pm, p1); Tri(bm, p1, b1);
            }
            var mesh = new Mesh { name = "mountains" + ring };
            mesh.SetVertices(v); mesh.SetColors(c); mesh.SetTriangles(t, 0);
            mesh.RecalculateNormals(); mesh.RecalculateBounds();
            var go = new GameObject("ring" + ring);
            go.transform.SetParent(root);
            go.transform.position = new Vector3(0, -10f, 0);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            var mat = new Material(sh);
            mat.SetColor("_Haze", fog);
            mat.SetFloat("_HazeAmt", Night ? 0.6f + ring * 0.12f : haze[ring]);
            mat.SetVector("_SunDir", sunDir);
            mat.SetColor("_SunColor", sunCol);
            mat.SetColor("_Ambient", RenderSettings.ambientSkyColor * 0.9f);
            mr.sharedMaterial = mat;
            mr.shadowCastingMode = ShadowCastingMode.Off;
            mr.receiveShadows = false;
        }
    }

    // ---------------- передовые базы сторон и руины ----------------
    static void BuildOutposts()
    {
        var root = new GameObject("Outposts").transform;
        root.SetParent(Root.transform);
        // база Фонда (юг) и лагерь Хаоса (север)
        Outpost(new Vector3(0, 0, -150), 0f, new Color(0.25f, 0.27f, 0.3f), root);
        Outpost(new Vector3(0, 0, 150), 180f, new Color(0.28f, 0.3f, 0.2f), root);
        Ruins(new Vector3(-120, 0, 30), root);
        Ruins(new Vector3(125, 0, -35), root);
        Ruins(new Vector3(-60, 0, 95), root);
        Ruins(new Vector3(70, 0, -100), root);
    }

    static void Outpost(Vector3 c, float yaw, Color tent, Transform root)
    {
        var q = Quaternion.Euler(0, yaw, 0);
        // полукольцо мешков с песком, обращённое к центру
        for (int i = -2; i <= 2; i++)
        {
            Vector3 p = c + q * new Vector3(i * 9f, 0, 14f);
            if (!Blocked(p, 2)) Sandbags(p, yaw, root);
        }
        // палатки
        for (int i = -1; i <= 1; i += 2)
        {
            Vector3 p = c + q * new Vector3(i * 12f, 0, -4f);
            if (Blocked(p, 4)) continue;
            p = OnGround(p.x, p.z);
            var go = new GameObject("tent"); go.transform.SetParent(root); go.transform.position = p; go.transform.rotation = q;
            MeshKit.Part(go.transform, MeshKit.Frustum(0.02f, 4), Mats.Get(tent, 0.05f), new Vector3(0, 1.4f, 0), new Vector3(6.5f, 2.8f, 8f), new Vector3(0, 45, 0));
            MeshKit.Box(go.transform, new Vector3(0, 0.05f, 0), new Vector3(4.6f, 0.1f, 5.6f), Mats.Get(tent * 0.7f));
            MeshKit.CombineParts(go.transform);
            var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 1.1f, 0); bc.size = new Vector3(4.2f, 2.2f, 5.2f);
            go.AddComponent<Surface>().color = tent;
        }
        for (int i = 0; i < 10; i++)
        {
            Vector3 p = c + q * new Vector3(R(-15, 15), 0, R(-8, 8));
            if (!Blocked(p, 1.5f)) Crate(OnGround(p.x, p.z), root);
        }
        Vector3 tp = c + q * new Vector3(18f, 0, 6f);
        if (!Blocked(tp, 4)) Tower(OnGround(tp.x, tp.z), root);
    }

    static void Ruins(Vector3 c, Transform root)
    {
        if (Blocked(c, 10)) return;
        float y = Height(c.x, c.z);
        float yaw = R(0, 90);
        var q = Quaternion.Euler(0, yaw, 0);
        Color cs = new Color(0.5f, 0.49f, 0.46f);
        // остатки стен разной высоты
        for (int i = 0; i < 4; i++)
        {
            float len = R(4f, 10f), h = R(1.2f, 4.5f);
            Vector3 off = q * new Vector3((i % 2 == 0 ? -1 : 1) * 6f, 0, (i < 2 ? -1 : 1) * 5f);
            Quaternion r = q * Quaternion.Euler(0, i % 2 == 0 ? 0 : 90, 0);
            Solid(c + off + Vector3.up * (y + h / 2 - 0.2f), new Vector3(len, h, 0.5f), concreteMat, r, cs);
        }
        for (int i = 0; i < 12; i++)
        {
            Vector3 p = c + new Vector3(R(-8, 8), 0, R(-8, 8));
            float sz = R(0.4f, 1.3f);
            Solid(OnGround(p.x, p.z, sz * 0.3f), new Vector3(sz, sz * 0.6f, sz * 0.8f), concreteMat, Quaternion.Euler(R(-20, 20), R(0, 360), R(-20, 20)), cs);
        }
    }

    // ---------------- дороги ----------------
    static void BuildRoads()
    {
        Color road = mapKind == 2 ? new Color(0.55f, 0.46f, 0.33f) : mapKind == 3 ? new Color(0.55f, 0.57f, 0.6f) : new Color(0.24f, 0.23f, 0.21f);
        var m = Mats.Get(road, 0.15f);
        Road(new[] { new Vector3(0, 0, -300), new Vector3(8, 0, -150), new Vector3(0, 0, -20) }, 7f, m);
        Road(new[] { new Vector3(0, 0, 20), new Vector3(-8, 0, 150), new Vector3(0, 0, 300) }, 7f, m);
        Road(new[] { new Vector3(-300, 0, 10), new Vector3(-120, 0, 25), new Vector3(-24, 0, 0) }, 6f, m);
        Road(new[] { new Vector3(24, 0, 0), new Vector3(125, 0, -30), new Vector3(300, 0, -20) }, 6f, m);
    }

    static void Road(Vector3[] pts, float w, Material m)
    {
        var v = new List<Vector3>(); var t = new List<int>(); var uv = new List<Vector2>();
        int steps = 80;
        for (int i = 0; i <= steps; i++)
        {
            float k = i / (float)steps;
            // квадратичная кривая Безье
            Vector3 p = (1 - k) * (1 - k) * pts[0] + 2 * (1 - k) * k * pts[1] + k * k * pts[2];
            Vector3 d = (2 * (1 - k) * (pts[1] - pts[0]) + 2 * k * (pts[2] - pts[1])).normalized;
            Vector3 side = Vector3.Cross(Vector3.up, d) * w * 0.5f;
            Vector3 a = p - side, b = p + side;
            a.y = Height(a.x, a.z) + 0.06f; b.y = Height(b.x, b.z) + 0.06f;
            v.Add(a); v.Add(b);
            uv.Add(new Vector2(0, k * 30)); uv.Add(new Vector2(1, k * 30));
            if (i > 0)
            {
                int j = v.Count - 4;
                t.Add(j); t.Add(j + 2); t.Add(j + 1);
                t.Add(j + 1); t.Add(j + 2); t.Add(j + 3);
            }
        }
        var mesh = new Mesh();
        mesh.SetVertices(v); mesh.SetTriangles(t, 0); mesh.SetUVs(0, uv);
        mesh.RecalculateNormals(); mesh.RecalculateBounds();
        var go = new GameObject("road"); go.transform.SetParent(Root.transform);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var mr = go.AddComponent<MeshRenderer>(); mr.sharedMaterial = m; mr.shadowCastingMode = ShadowCastingMode.Off;
    }

    // ---------------- навигация ----------------
    // Строится в фоне (карта большая), Battle ждёт завершения и показывает экран загрузки
    public static AsyncOperation BakeNavAsync()
    {
        Physics.SyncTransforms();
        var settings = NavMesh.GetSettingsByID(0);
        settings.agentRadius = 0.45f;
        settings.agentHeight = 1.9f;
        settings.agentSlope = 40f;
        settings.agentClimb = 0.45f;
        settings.overrideVoxelSize = true;
        settings.voxelSize = 0.28f;
        settings.overrideTileSize = true;
        settings.tileSize = 192;
        var sources = new List<NavMeshBuildSource>();
        var markups = new List<NavMeshBuildMarkup>();
        var bounds = new Bounds(Vector3.zero, new Vector3(Size - 30f, 120f, Size - 30f));
        NavMeshBuilder.CollectSources(bounds, 1 << Layers.World, NavMeshCollectGeometry.PhysicsColliders, 0, markups, sources);
        var data = new NavMeshData(settings.agentTypeID);
        navInstance = NavMesh.AddNavMeshData(data);
        return NavMeshBuilder.UpdateNavMeshDataAsync(data, settings, sources, bounds);
    }
}

// Вращающийся прожектор на вышке
public class Searchlight : MonoBehaviour
{
    float t0;
    Quaternion baseRot;
    void Start() { t0 = Random.Range(0f, 10f); baseRot = transform.localRotation; }
    void Update() { transform.localRotation = baseRot * Quaternion.Euler(0, Mathf.Sin((Time.time + t0) * 0.3f) * 60f, 0); }
}
