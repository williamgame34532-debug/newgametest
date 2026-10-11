using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Природа и рельеф: смешанные слои земли, трава с ветром, деревья (объединены по участкам), камни, внешний мир до гор.
public static partial class MapGen
{
    static Material terrainMat;
    public static readonly List<Renderer> grassChunks = new List<Renderer>();

    // ---------------- текстуры слоёв ----------------
    static float Fbm(float x, float y, int oct, float ox, float oy)
    {
        float s = 0, a = 0.5f, f = 1f, n = 0;
        for (int i = 0; i < oct; i++) { s += a * TileN(x, y, f, ox + i * 17.3f, oy + i * 9.1f); n += a; a *= 0.5f; f *= 2f; }
        return s / n;
    }
    // бесшовный шум на единичном квадрате (частота — целое число)
    static float TileN(float x, float y, float freq, float ox, float oy)
    {
        float fx = x * freq, fy = y * freq;
        float a = Mathf.PerlinNoise(fx + ox, fy + oy), b = Mathf.PerlinNoise(fx - freq + ox, fy + oy);
        float c = Mathf.PerlinNoise(fx + ox, fy - freq + oy), d = Mathf.PerlinNoise(fx - freq + ox, fy - freq + oy);
        return Mathf.Lerp(Mathf.Lerp(a, b, x), Mathf.Lerp(c, d, x), y);
    }

    // kind: 0 трава, 1 лесная подстилка, 2 земля, 3 камень, 4 снег, 5 песок, 6 гравий, 7 сухая потрескавшаяся земля, 8 грязь
    // Слои рельефа: фото-скан, если он есть; иначе процедурная текстура
    static readonly string[] LayerPhoto = { "forest2", "grass", "forest", "rock", "snow", "cracked", "gravel", "dirt", "mud" };
    static Texture2D LayerTex(int kind, int seed)
    {
        if (kind >= 0 && kind < LayerPhoto.Length) { var ph = Mats.Photo(LayerPhoto[kind]); if (ph != null) return ph; }
        return LayerTexProc(kind, seed);
    }

    static Texture2D LayerTexProc(int kind, int seed)
    {
        float ox = seed * 3.7f, oy = seed * 1.9f;
        return Mats.MakeTex(256, (x, y) =>
        {
            float n = Fbm(x, y, 5, ox, oy);
            float hi = TileN(x, y, 64f, ox + 40, oy + 11);
            float mid = TileN(x, y, 16f, ox + 5, oy + 70);
            Color c;
            switch (kind)
            {
                case 0: // трава: зелёная с тёмными промежутками и сухими пятнами
                {
                    float blades = TileN(x, y, 96f, ox, oy) * 0.6f + hi * 0.4f;
                    c = Color.Lerp(new Color(0.16f, 0.24f, 0.08f), new Color(0.33f, 0.43f, 0.16f), blades);
                    c = Color.Lerp(c, new Color(0.45f, 0.44f, 0.22f), Mathf.Clamp01((mid - 0.62f) * 3f));
                    c *= 0.85f + n * 0.3f;
                    break;
                }
                case 1: // лесная подстилка: хвоя, листья, мох
                {
                    float needles = Mathf.Abs(Mathf.Sin((x * 37f + TileN(x, y, 8f, ox, oy) * 4f) * 6.28f)) * hi;
                    c = Color.Lerp(new Color(0.2f, 0.15f, 0.09f), new Color(0.36f, 0.27f, 0.15f), n);
                    c = Color.Lerp(c, new Color(0.17f, 0.25f, 0.1f), Mathf.Clamp01((mid - 0.55f) * 2.5f));
                    c *= 0.8f + needles * 0.4f;
                    break;
                }
                case 2: // земля с мелкими камешками
                {
                    c = Color.Lerp(new Color(0.27f, 0.21f, 0.15f), new Color(0.42f, 0.34f, 0.25f), n);
                    if (hi > 0.68f) c = Color.Lerp(c, new Color(0.55f, 0.52f, 0.48f), (hi - 0.68f) * 5f);
                    c *= 0.88f + mid * 0.24f;
                    break;
                }
                case 3: // камень: трещины, лишайник
                {
                    float ridge = 1f - Mathf.Abs(TileN(x, y, 12f, ox + 3, oy + 8) * 2f - 1f);
                    c = Color.Lerp(new Color(0.33f, 0.33f, 0.32f), new Color(0.55f, 0.54f, 0.52f), n);
                    c *= 1f - Mathf.Pow(ridge, 8f) * 0.55f;
                    c = Color.Lerp(c, new Color(0.42f, 0.45f, 0.3f), Mathf.Clamp01((mid - 0.66f) * 3f) * 0.6f);
                    break;
                }
                case 4: // снег: мягкие наносы
                    c = Color.Lerp(new Color(0.8f, 0.84f, 0.9f), new Color(0.96f, 0.97f, 1f), n);
                    c *= 0.95f + hi * 0.08f;
                    break;
                case 5: // песок: рябь
                {
                    float rip = Mathf.Sin((y * 22f + TileN(x, y, 4f, ox, oy) * 3f) * 6.28f) * 0.5f + 0.5f;
                    c = Color.Lerp(new Color(0.7f, 0.58f, 0.4f), new Color(0.86f, 0.74f, 0.54f), n);
                    c *= 0.92f + rip * 0.08f + hi * 0.06f;
                    break;
                }
                case 6: // гравий
                {
                    float pebble = Mathf.Clamp01((hi - 0.45f) * 4f);
                    c = Color.Lerp(new Color(0.35f, 0.34f, 0.32f), new Color(0.62f, 0.6f, 0.56f), pebble * 0.8f + n * 0.2f);
                    break;
                }
                case 7: // сухая потрескавшаяся земля
                {
                    float cell = Mathf.Abs(TileN(x, y, 10f, ox, oy) - 0.5f);
                    c = Color.Lerp(new Color(0.55f, 0.42f, 0.28f), new Color(0.7f, 0.56f, 0.38f), n);
                    if (cell < 0.02f) c *= 0.6f;
                    break;
                }
                default: // грязь, лёд
                    c = Color.Lerp(new Color(0.18f, 0.15f, 0.11f), new Color(0.3f, 0.25f, 0.18f), n) * (0.9f + hi * 0.2f);
                    break;
            }
            c.a = 1;
            return c;
        }, false);
    }

    static Material TerrainMaterial(int map, int seed, int last = -1)
    {
        var sh = Shader.Find("SCP/Terrain");
        if (sh == null) return null;
        var m = new Material(sh);
        int[] kinds = map == 1 ? new[] { 0, 1, 3, 8 } : map == 2 ? new[] { 5, 7, 3, 6 } : map == 3 ? new[] { 4, 2, 3, 4 } : new[] { 0, 2, 3, 6 };
        string[] slots = { "_L0", "_L1", "_L2", "_L3" };
        for (int i = 0; i < 4; i++)
        {
            var t = LayerTex(i == 3 && last >= 0 ? last : kinds[i], seed + i * 7);
            t.anisoLevel = 4;
            m.SetTexture(slots[i], t);
        }
        m.SetFloat("_Scale", Mats.Photo("grass") != null ? 0.3f : 0.17f);   // фото-скан ~3 м на тайл
        m.SetVector("_Gloss", map == 3 ? new Vector4(0.45f, 0.1f, 0.15f, 0.5f) : new Vector4(0.04f, 0.08f, 0.15f, 0.12f));
        return m;
    }

    // Веса слоёв в точке: трава, земля, камень, четвёртый слой
    static Color GroundWeights(float x, float z, float slope)
    {
        float rock = Mathf.SmoothStep(0f, 1f, (slope - 0.16f) / 0.22f);
        rock = Mathf.Max(rock, Mathf.Clamp01((Mathf.PerlinNoise(x * 0.05f + 300, z * 0.05f) - 0.78f) * 4f));
        float dirt = Mathf.Clamp01((Mathf.PerlinNoise(x * 0.025f + 40, z * 0.025f + 9) - 0.56f) * 3.5f);
        float l3 = 0f;
        // натоптанная земля у площадок и укрытий
        foreach (var k in keepOut)
        {
            float d = Vector2.Distance(new Vector2(x, z), new Vector2(k.x, k.z));
            if (d < 22f) dirt = Mathf.Max(dirt, Mathf.SmoothStep(1f, 0f, (d - 9f) / 13f));
        }
        float fac = Mathf.Max(Mathf.Abs(x) - 26f, Mathf.Abs(z) - 20f);
        switch (mapKind)
        {
            case 0: l3 = Mathf.Max(Mathf.SmoothStep(1f, 0f, fac / 10f), SiteFlat(x, z) * 0.85f); break;  // гравий/бетон на территории комплекса
            case 1: l3 = Mathf.Clamp01((Mathf.PerlinNoise(x * 0.04f, z * 0.04f + 77) - 0.65f) * 4f); break; // грязь в низинах
            case 2: l3 = Mathf.Clamp01((Mathf.PerlinNoise(x * 0.06f + 5, z * 0.06f) - 0.6f) * 3f) + Mathf.SmoothStep(1f, 0f, fac / 10f); break;
            case 3: l3 = 0f; dirt *= 0.4f; break;
        }
        l3 = Mathf.Clamp01(l3);
        float grass = Mathf.Clamp01(1f - rock - dirt * 0.9f - l3);
        return new Color(grass, dirt * (1f - rock), rock, l3 * (1f - rock));
    }

    static float SlopeAt(float x, float z)
    {
        float e = 1.5f;
        Vector3 n = Vector3.Cross(new Vector3(0, Height(x, z + e) - Height(x, z - e), 2 * e), new Vector3(2 * e, Height(x + e, z) - Height(x - e, z), 0)).normalized;
        return 1f - Mathf.Abs(n.y);
    }

    // Раскрашивает готовый меш рельефа весами слоёв
    static void PaintGround(Mesh m)
    {
        var v = m.vertices; var n = m.normals;
        var cols = new Color[v.Length];
        for (int i = 0; i < v.Length; i++) cols[i] = GroundWeights(v[i].x, v[i].z, 1f - n[i].y);
        m.colors = cols;
    }

    // ---------------- трава ----------------
    static Texture2D grassTex;
    static Texture2D GrassTex()
    {
        if (grassTex != null) return grassTex;
        var bases = new float[14]; var tops = new float[14]; var bend = new float[14]; var wid = new float[14]; var shade = new float[14];
        var r = new System.Random(3);
        for (int i = 0; i < bases.Length; i++)
        {
            bases[i] = 0.06f + 0.88f * (float)r.NextDouble();
            tops[i] = 0.55f + 0.43f * (float)r.NextDouble();
            bend[i] = ((float)r.NextDouble() - 0.5f) * 0.25f;
            wid[i] = 0.025f + 0.02f * (float)r.NextDouble();
            shade[i] = 0.75f + 0.35f * (float)r.NextDouble();
        }
        grassTex = Mats.MakeTex(128, (x, y) =>
        {
            for (int i = 0; i < bases.Length; i++)
            {
                if (y > tops[i]) continue;
                float k = y / tops[i];
                float cx = bases[i] + bend[i] * k * k;
                float w = wid[i] * (1f - k * 0.92f);
                if (Mathf.Abs(x - cx) < w)
                {
                    Color c = Color.Lerp(new Color(0.12f, 0.17f, 0.06f), new Color(0.42f, 0.52f, 0.22f), k) * shade[i];
                    c.a = 1f;
                    return c;
                }
            }
            return new Color(0.3f, 0.38f, 0.15f, 0f);
        });
        grassTex.wrapMode = TextureWrapMode.Clamp;
        return grassTex;
    }

    static void BuildGrass(int map)
    {
        grassChunks.Clear();
        if (map == 3) return;
        var sh = Shader.Find("SCP/Grass");
        if (sh == null) return;
        var mat = new Material(sh);
        mat.SetTexture("_MainTex", GrassTex());
        mat.SetFloat("_Cutoff", 0.45f);
        mat.SetFloat("_Fade", 80f);
        mat.SetFloat("_Wind", map == 2 ? 0.7f : 1f);
        var root = new GameObject("Grass").transform;
        root.SetParent(Root.transform);
        float chunk = 32f, half = Play + 30f;
        float dens = map == 1 ? 0.85f : map == 2 ? 0.12f : 0.6f;
        Color tintA = map == 2 ? new Color(0.95f, 0.8f, 0.5f) : map == 1 ? new Color(0.8f, 0.95f, 0.75f) : new Color(1f, 1f, 0.9f);
        Color tintB = map == 2 ? new Color(0.8f, 0.65f, 0.4f) : new Color(1.15f, 1.05f, 0.7f);
        for (float cx = -half; cx < half; cx += chunk)
            for (float cz = -half; cz < half; cz += chunk)
            {
                var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var cols = new List<Color>(); var tris = new List<int>();
                Vector3 c0 = new Vector3(cx + chunk / 2, 0, cz + chunk / 2);
                int tries = Mathf.RoundToInt(chunk * chunk * dens);
                for (int i = 0; i < tries; i++)
                {
                    float x = cx + R() * chunk, z = cz + R() * chunk;
                    if (x * x + z * z > half * half) continue;
                    var gw = GroundWeights(x, z, SlopeAt(x, z));
                    if (R() > gw.r * gw.r) continue;
                    if (Blocked(new Vector3(x, 0, z), -10f)) continue;
                    float y = Height(x, z) - 0.03f;
                    float h = R(0.35f, map == 1 ? 0.85f : 0.65f), w = R(0.5f, 0.9f);
                    float a = R(0, Mathf.PI);
                    Color tint = Color.Lerp(tintA, tintB, R()) * R(0.85f, 1.1f);
                    for (int q = 0; q < 2; q++)
                    {
                        float aa = a + q * Mathf.PI * 0.5f;
                        Vector3 d = new Vector3(Mathf.Cos(aa), 0, Mathf.Sin(aa)) * w * 0.5f;
                        Vector3 b = new Vector3(x, y, z) - c0;
                        int vi = verts.Count;
                        verts.Add(b - d); verts.Add(b + d); verts.Add(b + d + Vector3.up * h); verts.Add(b - d + Vector3.up * h);
                        uvs.Add(new Vector2(0, 0)); uvs.Add(new Vector2(1, 0)); uvs.Add(new Vector2(1, 1)); uvs.Add(new Vector2(0, 1));
                        for (int k = 0; k < 4; k++) cols.Add(tint);
                        tris.Add(vi); tris.Add(vi + 2); tris.Add(vi + 1); tris.Add(vi); tris.Add(vi + 3); tris.Add(vi + 2);
                    }
                }
                if (verts.Count == 0) continue;
                var m = new Mesh { name = "grass", indexFormat = verts.Count > 65000 ? IndexFormat.UInt32 : IndexFormat.UInt16 };
                m.SetVertices(verts); m.SetUVs(0, uvs); m.SetColors(cols); m.SetTriangles(tris, 0);
                m.RecalculateBounds();
                var go = new GameObject("grassChunk");
                go.transform.SetParent(root);
                go.transform.position = c0;
                go.AddComponent<MeshFilter>().sharedMesh = m;
                var mr = go.AddComponent<MeshRenderer>();
                mr.sharedMaterial = mat;
                mr.shadowCastingMode = ShadowCastingMode.Off;
                mr.receiveShadows = true;
                grassChunks.Add(mr);
            }
        root.gameObject.AddComponent<GrassCuller>();
    }

    // ---------------- деревья (по участкам) ----------------
    static readonly Dictionary<Vector2Int, Transform> treeChunks = new Dictionary<Vector2Int, Transform>();
    static Transform TreeChunk(Vector3 p, Transform root)
    {
        var key = new Vector2Int(Mathf.FloorToInt(p.x / 48f), Mathf.FloorToInt(p.z / 48f));
        if (!treeChunks.TryGetValue(key, out var t))
        {
            t = new GameObject("trees").transform;
            t.SetParent(root);
            treeChunks[key] = t;
        }
        return t;
    }

    static Material barkM, barkBirch;
    static readonly Material[] leafM = new Material[4];
    static void TreeMats(bool snow)
    {
        barkM = Mats.Get(new Color(0.24f, 0.17f, 0.11f), 0.05f);
        barkBirch = Mats.Get(new Color(0.82f, 0.8f, 0.74f), 0.1f);
        for (int i = 0; i < 4; i++)
        {
            Color c = snow ? Color.Lerp(new Color(0.12f, 0.2f, 0.14f), new Color(0.2f, 0.27f, 0.2f), i / 3f)
                           : Color.Lerp(new Color(0.07f, 0.15f, 0.06f), new Color(0.2f, 0.3f, 0.1f), i / 3f);
            leafM[i] = Mats.Get(c, 0.04f);
        }
    }

    // Ель: конический ствол, ярусы рваных «юбок» с наклоном вниз, лёгкий наклон всего дерева
    static void Conifer(Vector3 p, Transform root, bool snow, float scale = 1f, bool collider = true)
    {
        var ch = TreeChunk(p, root);
        float h = R(9f, 17f) * scale;
        Quaternion lean = Quaternion.Euler(R(-3, 3), R(0, 360), R(-3, 3));
        MeshKit.Part(ch, MeshKit.Frustum(0.25f, 7), barkM, p + lean * new Vector3(0, h * 0.42f, 0), new Vector3(0.42f * scale, h * 0.84f, 0.42f * scale), lean.eulerAngles);
        int tiers = Mathf.RoundToInt(R(6, 9));
        for (int i = 0; i < tiers; i++)
        {
            float k = i / (float)(tiers - 1);
            float w = Mathf.Lerp(4.6f, 0.7f, Mathf.Pow(k, 0.85f)) * (h / 13f) * R(0.85f, 1.1f);
            float y = h * Mathf.Lerp(0.2f, 0.93f, k);
            var m = leafM[(int)(R() * 3.99f)];
            MeshKit.Part(ch, MeshKit.Frustum(0.08f, 9), m, p + lean * new Vector3(R(-0.15f, 0.15f), y, R(-0.15f, 0.15f)), new Vector3(w, h * 0.2f, w), (lean * Quaternion.Euler(R(-6, 6), R(0, 360), R(-6, 6))).eulerAngles);
            if (snow && i % 2 == 0) MeshKit.Part(ch, MeshKit.Frustum(0.1f, 9), Mats.Get(new Color(0.92f, 0.94f, 0.97f), 0.4f), p + lean * new Vector3(0, y + 0.25f, 0), new Vector3(w * 0.8f, h * 0.12f, w * 0.8f), lean.eulerAngles);
        }
        if (collider) TreeCollider(p, h, 0.32f * scale);
    }

    // Лиственное дерево: ствол с развилкой и неровная крона из «облаков» листвы
    static void Broadleaf(Vector3 p, Transform root, bool birch)
    {
        var ch = TreeChunk(p, root);
        float h = R(7f, 12f);
        var bark = birch ? barkBirch : barkM;
        float tilt = R(-5, 5);
        MeshKit.Part(ch, MeshKit.Frustum(0.55f, 7), bark, p + new Vector3(0, h * 0.3f, 0), new Vector3(0.45f, h * 0.6f, 0.45f), new Vector3(tilt, 0, R(-4, 4)));
        for (int b = 0; b < 3; b++)
        {
            float a = b * 120f + R(-20, 20);
            Vector3 dir = Quaternion.Euler(0, a, 0) * new Vector3(0, 1, 0.6f);
            MeshKit.Part(ch, MeshKit.Frustum(0.4f, 6), bark, p + new Vector3(0, h * 0.58f, 0) + dir.normalized * 1.1f, new Vector3(0.22f, 1.3f, 0.22f), Quaternion.FromToRotation(Vector3.up, dir).eulerAngles);
        }
        int blobs = Mathf.RoundToInt(R(6, 10));
        for (int i = 0; i < blobs; i++)
        {
            Vector3 o = new Vector3(R(-2.4f, 2.4f), h * R(0.62f, 0.98f), R(-2.4f, 2.4f));
            float s = R(2.2f, 3.6f);
            MeshKit.Part(ch, MeshKit.Sphere, leafM[1 + (int)(R() * 2.99f)], p + o, new Vector3(s, s * R(0.7f, 0.9f), s), new Vector3(0, R(0, 360), 0));
        }
        TreeCollider(p, h, 0.3f);
    }

    static void TreeCollider(Vector3 p, float h, float r)
    {
        var go = new GameObject("treeCol");
        go.transform.SetParent(Root.transform);
        go.transform.position = p;
        var c = go.AddComponent<CapsuleCollider>(); c.center = new Vector3(0, h * 0.4f, 0); c.height = h * 0.8f; c.radius = r;
        go.AddComponent<Surface>().color = new Color(0.35f, 0.26f, 0.17f);
    }

    // ---------------- камни: деформированные сферы с рублеными гранями ----------------
    static Mesh[] rockMeshes;
    static Mesh RockMesh(int seed)
    {
        var src = MeshKit.Sphere;
        var v = src.vertices; var t = src.triangles;
        var nv = new List<Vector3>(); var nt = new List<int>();
        float o = seed * 5.3f;
        System.Func<Vector3, Vector3> D = p =>
        {
            Vector3 d = p.normalized;
            float n = Mathf.PerlinNoise(d.x * 1.7f + o, d.z * 1.7f + d.y * 0.9f) * 0.55f + Mathf.PerlinNoise(d.x * 4.1f + o, d.y * 4.1f + d.z) * 0.25f;
            Vector3 q = p * (0.75f + n);
            q.y = q.y > 0 ? q.y * 0.75f : q.y * 0.5f;   // плоское основание
            return q;
        };
        for (int i = 0; i < t.Length; i += 3)
        {
            int b = nv.Count;
            nv.Add(D(v[t[i]])); nv.Add(D(v[t[i + 1]])); nv.Add(D(v[t[i + 2]]));
            nt.Add(b); nt.Add(b + 1); nt.Add(b + 2);
        }
        var m = new Mesh { name = "rock" };
        m.SetVertices(nv); m.SetTriangles(nt, 0);
        m.RecalculateNormals(); m.RecalculateBounds();
        return m;
    }

    static void RockNew(Vector3 p, Transform root, Material mat)
    {
        if (rockMeshes == null) { rockMeshes = new Mesh[6]; for (int i = 0; i < 6; i++) rockMeshes[i] = RockMesh(i + 1); }
        var ch = TreeChunk(p, root);
        float s = R(0.8f, 3.4f);
        var mesh = rockMeshes[(int)(R() * 5.99f)];
        MeshKit.Part(ch, mesh, mat, p + Vector3.down * s * 0.15f, new Vector3(s * R(1f, 1.6f), s * R(0.7f, 1.1f), s * R(1f, 1.5f)), new Vector3(R(-8, 8), R(0, 360), R(-8, 8)));
        if (s > 1.2f)
        {
            var go = new GameObject("rockCol"); go.transform.SetParent(Root.transform); go.transform.position = p;
            var c = go.AddComponent<SphereCollider>(); c.radius = s * 0.5f;
            go.AddComponent<Surface>().color = mat.color;
        }
    }

    // Упавшие брёвна и пни — для леса
    static void Log(Vector3 p, Transform root)
    {
        var ch = TreeChunk(p, root);
        float l = R(3f, 7f);
        MeshKit.Part(ch, MeshKit.Frustum(0.85f, 7), barkM, p + Vector3.up * 0.25f, new Vector3(0.5f, l, 0.5f), new Vector3(90, R(0, 360), 0));
    }

    static void Stump(Vector3 p, Transform root)
    {
        var ch = TreeChunk(p, root);
        MeshKit.Part(ch, MeshKit.Frustum(0.75f, 7), barkM, p + Vector3.up * 0.3f, new Vector3(0.7f, 0.6f, 0.7f), new Vector3(0, R(0, 360), 0));
    }

    static void CombineTreeChunks()
    {
        foreach (var t in treeChunks.Values) MeshKit.CombineParts(t);
        treeChunks.Clear();
    }

    // ---------------- внешний мир: настоящие горы с долинами до горизонта ----------------
    // Четыре долины по сторонам света — по ним летают вертолёты; на юге в долине стоит база.
    public const float OuterR = 2700f;
    public static float ValleyOpen(float x, float z)
    {
        float d = Mathf.Min(Mathf.Abs(x), Mathf.Abs(z));
        float r = Mathf.Sqrt(x * x + z * z);
        float w = 90f + r * 0.06f;                          // долина расширяется наружу
        return 1f - Mathf.SmoothStep(0f, 1f, (d - w * 0.5f) / w);
    }

    // Передовая база стоит в южной долине на выровненной площадке
    public static readonly Vector2 FobXZ = new Vector2(0f, -1300f);
    public static Vector3 FobCenter() => new Vector3(FobXZ.x, OuterRaw(FobXZ.x, FobXZ.y), FobXZ.y);

    public static float OuterHeight(float x, float z)
    {
        float h = OuterRaw(x, z);
        float fd = Vector2.Distance(new Vector2(x, z), FobXZ);
        if (fd < 280f) h = Mathf.Lerp(OuterRaw(FobXZ.x, FobXZ.y) - 0.4f, h, Mathf.SmoothStep(0f, 1f, (fd - 165f) / 115f));
        return h;
    }

    static float OuterRaw(float x, float z)
    {
        float e = Mathf.Max(Mathf.Abs(x), Mathf.Abs(z));
        float r = Mathf.Sqrt(x * x + z * z);
        float baseH = Height(Mathf.Clamp(x, -Size / 2, Size / 2), Mathf.Clamp(z, -Size / 2, Size / 2));
        float near = Mathf.SmoothStep(0f, 1f, (e - Size / 2 - 4f) / 260f);
        // холмы предгорий
        float hills = (Mathf.PerlinNoise(x * 0.004f + 11, z * 0.004f + 3) - 0.35f) * 70f + (Mathf.PerlinNoise(x * 0.012f, z * 0.012f + 50) - 0.5f) * 18f;
        hills = Mathf.Max(0f, hills + 20f);
        // хребты: «гребневой» шум, высота растёт к краю мира
        float ridge = 0f, amp = 1f, f = 0.0016f, tot = 0f;
        for (int o = 0; o < 5; o++)
        {
            float n = 1f - Mathf.Abs(Mathf.PerlinNoise(x * f + 31.7f + o * 13f, z * f + 7.3f - o * 5f) * 2f - 1f);
            ridge += n * n * amp; tot += amp;
            amp *= 0.5f; f *= 2.05f;
        }
        ridge /= tot;
        float mtnK = Mathf.SmoothStep(0f, 1f, (r - 520f) / 900f);
        float peaks = ridge * Mathf.Lerp(80f, mapKind == 2 ? 330f : 520f, Mathf.Clamp01((r - 500f) / 1800f)) * mtnK;
        float valley = ValleyOpen(x, z);
        float floor = Mathf.Clamp01((r - 400f) / 2000f) * 35f;   // дно долины плавно поднимается
        float h = hills * (1f - valley * 0.85f) + peaks * (1f - valley) + floor * valley;
        // край мира загибаем вверх — горизонт закрыт стеной гор
        h += Mathf.SmoothStep(0f, 1f, (r - OuterR + 700f) / 700f) * 420f * (1f - valley * 0.6f);
        return baseH + near * h;
    }

    static void BuildOuter(int map)
    {
        int seg = 288, rings = 84;
        float r0 = 300f, r1 = OuterR;
        var v = new List<Vector3>(); var t = new List<int>();
        for (int j = 0; j <= rings; j++)
        {
            float k = j / (float)rings;
            float r = Mathf.Lerp(r0, r1, k * k * 0.55f + k * 0.45f);
            for (int i = 0; i < seg; i++)
            {
                float a = i / (float)seg * Mathf.PI * 2f;
                float x = Mathf.Cos(a) * r, z = Mathf.Sin(a) * r;
                float y = OuterHeight(x, z);
                // внутри квадрата основного рельефа — чуть ниже (не мерцает)
                if (Mathf.Abs(x) < Size / 2 - 1f && Mathf.Abs(z) < Size / 2 - 1f) y -= 0.6f;
                v.Add(new Vector3(x, y, z));
            }
        }
        for (int j = 0; j < rings; j++)
            for (int i = 0; i < seg; i++)
            {
                int a = j * seg + i, b = j * seg + (i + 1) % seg, c = (j + 1) * seg + i, d = (j + 1) * seg + (i + 1) % seg;
                t.Add(a); t.Add(b); t.Add(c); t.Add(b); t.Add(d); t.Add(c);
            }
        var m = new Mesh { name = "outer", indexFormat = IndexFormat.UInt32 };
        m.SetVertices(v); m.SetTriangles(t, 0);
        m.RecalculateNormals(); m.RecalculateBounds();
        // склоны — камень, вершины — снег (кроме пустыни)
        {
            var nv = m.normals; var cols = new Color[v.Count];
            for (int i = 0; i < v.Count; i++)
            {
                Color w = GroundWeights(v[i].x, v[i].z, 1f - nv[i].y);
                if (map != 2)
                {
                    float snowLine = map == 3 ? 40f : 230f;
                    float sn = Mathf.Clamp01((v[i].y - snowLine + (Mathf.PerlinNoise(v[i].x * 0.01f, v[i].z * 0.01f) - 0.5f) * 80f) / 60f) * Mathf.Clamp01(nv[i].y * 1.6f - 0.3f);
                    w.a = 0f;
                    if (sn > 0f) w = Color.Lerp(w, new Color(0, 0, 1f - sn, sn), sn);
                }
                cols[i] = w;
            }
            m.colors = cols;
        }
        var go = new GameObject("OuterGround");
        go.transform.SetParent(Root.transform);
        go.AddComponent<MeshFilter>().sharedMesh = m;
        var mr = go.AddComponent<MeshRenderer>();
        var om = map != 2 ? TerrainMaterial(map, 91, 4) : null;
        mr.sharedMaterial = om != null ? om : terrainMat != null ? terrainMat : groundMat;
        mr.shadowCastingMode = ShadowCastingMode.Off;
        var col = go.AddComponent<MeshCollider>();
        col.sharedMesh = m;

        // дальний лес/кактусы на склонах вокруг
        if (map == 2) return;
        var root = new GameObject("FarForest").transform;
        root.SetParent(Root.transform);
        int n = map == 1 ? 4200 : map == 3 ? 2600 : 2600;
        for (int i = 0; i < n; i++)
        {
            float a = R(0, Mathf.PI * 2), r = R(335f, 1700f);
            float x = Mathf.Cos(a) * r, z = Mathf.Sin(a) * r;
            if (Mathf.Abs(x) < Size / 2 && Mathf.Abs(z) < Size / 2) continue;
            // лес гуще в низинах, просеки по перевалам
            // просека по дну долины — там ходят вертолёты
            if (Vector2.Distance(new Vector2(x, z), FobXZ) < 260f) continue;
            if (ValleyOpen(x, z) > 0.55f && Mathf.Min(Mathf.Abs(x), Mathf.Abs(z)) < 45f + r * 0.02f) continue;
            if (Mathf.PerlinNoise(x * 0.01f, z * 0.01f) < 0.38f) continue;
            float fy = OuterHeight(x, z);
            if (fy > (map == 3 ? 60f : 200f)) continue;            // выше границы леса — голые скалы
            Conifer(new Vector3(x, fy - 0.3f, z), root, map == 3, R(0.9f, 1.4f), false);
        }
    }
}

// Трава рисуется только рядом с камерой (дальше она всё равно растворяется)
public class GrassCuller : MonoBehaviour
{
    float t;
    void Update()
    {
        if (Time.unscaledTime < t) return;
        t = Time.unscaledTime + 0.25f;
        var cam = Game.Cam;
        if (cam == null) return;
        Vector3 c = cam.transform.position;
        foreach (var r in MapGen.grassChunks)
        {
            if (r == null) continue;
            Vector3 p = r.transform.position;
            float d = new Vector2(p.x - c.x, p.z - c.z).magnitude;
            r.enabled = d < 115f;
        }
    }
}
