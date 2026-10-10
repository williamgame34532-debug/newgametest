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
    public const float Size = 340f;
    public const float Play = 112f;
    static int mapKind;
    static readonly List<Light> lamps = new List<Light>();

    static float R() => (float)rng.NextDouble();
    static float R(float a, float b) => a + (b - a) * (float)rng.NextDouble();

    public static float Height(float x, float z)
    {
        float r = Mathf.Sqrt(x * x + z * z);
        float hills = (Mathf.PerlinNoise(x * 0.012f + 100, z * 0.012f + 50) - 0.5f) * 14f + (Mathf.PerlinNoise(x * 0.05f, z * 0.05f) - 0.5f) * 2.5f;
        float flat = (Mathf.PerlinNoise(x * 0.03f + 7, z * 0.03f + 3) - 0.5f) * 1.2f;
        float k = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(95f, 160f, r));
        return Mathf.Lerp(flat, hills + 2f, k);
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
        BuildCover(map);
        BuildNature(map);
        BuildBounds();
        Lighting(map, time, fog);
        BakeNav();
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
        int res = 136;
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
        for (int i = 0; i < 60 && n < 14; i++)
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
        for (int i = 0; i < 80 && n < 40; i++)
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
        for (int i = 0; i < 60 && n < 60; i++)
        {
            Vector3 p = new Vector3(R(-Play + 8, Play - 8), 0, R(-Play + 8, Play - 8));
            if (Blocked(p, 3)) continue;
            n++;
            float face = R(0, 360);
            Sandbags(p, face, root);
        }
        // вышки
        Vector3[] towers = { new Vector3(-60, 0, -30), new Vector3(60, 0, 30), new Vector3(-55, 0, 40), new Vector3(55, 0, -40) };
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
        for (int i = 0; i < 20 && n < 66; i++)
        {
            Vector3 p = new Vector3(R(-Play + 15, Play - 15), 0, R(-Play + 15, Play - 15));
            if (Blocked(p, 5)) continue;
            n++;
            Truck(OnGround(p.x, p.z), R(0, 360), root);
        }
        // ящики
        for (int i = 0; i < 40; i++)
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
        int trees = map == 1 ? 420 : map == 2 ? 30 : map == 3 ? 260 : 220;
        int rocks = map == 2 ? 90 : 40;
        for (int i = 0; i < trees; i++)
        {
            float a = R(0, Mathf.PI * 2);
            float r = map == 1 && R() < 0.35f ? R(30, 105) : R(98, Size / 2 - 8);
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
            for (int i = 0; i < 260; i++)
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
        float e = 150f;
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
        var sky = new Material(Shader.Find("Skybox/Procedural"));
        Color amb1, amb2, amb3;
        switch (time)
        {
            case 1: // закат
                sunGo.transform.rotation = Quaternion.Euler(9f, 250f, 0);
                sun.color = new Color(1f, 0.6f, 0.35f); sun.intensity = 1.15f;
                sky.SetColor("_SkyTint", new Color(0.9f, 0.5f, 0.4f)); sky.SetFloat("_AtmosphereThickness", 1.7f); sky.SetFloat("_Exposure", 1.1f);
                amb1 = new Color(0.45f, 0.38f, 0.42f); amb2 = new Color(0.32f, 0.26f, 0.24f); amb3 = new Color(0.15f, 0.12f, 0.1f);
                fog = Color.Lerp(fog, new Color(0.8f, 0.5f, 0.35f), 0.6f);
                break;
            case 2: // ночь
                sunGo.transform.rotation = Quaternion.Euler(38f, 120f, 0);
                sun.color = new Color(0.55f, 0.65f, 1f); sun.intensity = 0.16f;
                sky.SetColor("_SkyTint", new Color(0.1f, 0.12f, 0.25f)); sky.SetFloat("_AtmosphereThickness", 0.4f); sky.SetFloat("_Exposure", 0.12f);
                amb1 = new Color(0.07f, 0.08f, 0.13f); amb2 = new Color(0.05f, 0.06f, 0.09f); amb3 = new Color(0.02f, 0.02f, 0.03f);
                fog = new Color(0.03f, 0.04f, 0.07f);
                break;
            default:
                sunGo.transform.rotation = Quaternion.Euler(48f, 35f, 0);
                sun.color = map == 2 ? new Color(1f, 0.93f, 0.8f) : new Color(1f, 0.96f, 0.9f); sun.intensity = 1.25f;
                sky.SetColor("_SkyTint", new Color(0.5f, 0.55f, 0.65f)); sky.SetFloat("_AtmosphereThickness", map == 2 ? 1.3f : 1f); sky.SetFloat("_Exposure", 1.25f);
                amb1 = new Color(0.55f, 0.6f, 0.7f); amb2 = new Color(0.4f, 0.4f, 0.38f); amb3 = new Color(0.2f, 0.18f, 0.15f);
                break;
        }
        sky.SetFloat("_SunSize", 0.04f);
        sky.SetColor("_GroundColor", fog * 0.8f);
        RenderSettings.skybox = sky;
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = amb1;
        RenderSettings.ambientEquatorColor = amb2;
        RenderSettings.ambientGroundColor = amb3;
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogColor = fog;
        RenderSettings.fogDensity = time == 2 ? 0.012f : map == 1 ? 0.009f : map == 3 ? 0.01f : 0.005f;
        RenderSettings.reflectionIntensity = time == 2 ? 0.2f : 0.7f;
        QualitySettings.shadowDistance = 110f;
        QualitySettings.shadowCascades = 2;
        QualitySettings.pixelLightCount = time == 2 ? 10 : 4;
        DynamicGI.UpdateEnvironment();
    }

    // ---------------- навигация ----------------
    static void BakeNav()
    {
        Physics.SyncTransforms();
        var settings = NavMesh.GetSettingsByID(0);
        settings.agentRadius = 0.45f;
        settings.agentHeight = 1.9f;
        settings.agentSlope = 40f;
        settings.agentClimb = 0.45f;
        settings.overrideVoxelSize = true;
        settings.voxelSize = 0.22f;
        settings.overrideTileSize = true;
        settings.tileSize = 128;
        var sources = new List<NavMeshBuildSource>();
        var markups = new List<NavMeshBuildMarkup>();
        var bounds = new Bounds(Vector3.zero, new Vector3(296f, 80f, 296f));
        NavMeshBuilder.CollectSources(bounds, 1 << Layers.World, NavMeshCollectGeometry.PhysicsColliders, 0, markups, sources);
        var data = NavMeshBuilder.BuildNavMeshData(settings, sources, bounds, Vector3.zero, Quaternion.identity);
        if (data != null) navInstance = NavMesh.AddNavMeshData(data);
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
