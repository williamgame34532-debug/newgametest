using System.Collections.Generic;
using UnityEngine;

// Детальные руки от первого лица: меш из ArmGeo + материалы (ткань рукава с камуфляжем и плетением,
// перчатка с фактурой кожи и швами, тёмные накладки, часы).
public static class FPArms
{
    static readonly Dictionary<string, Mesh> meshes = new Dictionary<string, Mesh>();
    static readonly Dictionary<string, Material[]> mats = new Dictionary<string, Material[]>();
    static Texture2D weaveN, leatherN, padN;

    public static Mesh Mesh(bool left, float l1, float l2)
    {
        string key = (left ? "L" : "R") + l1.ToString("0.000") + l2.ToString("0.000");
        if (meshes.TryGetValue(key, out var m) && m != null) return m;
        var g = ArmGeo.Build(l1, l2, left);
        m = new Mesh { name = "fpArm" + key };
        m.SetVertices(g.v);
        m.SetNormals(g.n);
        m.SetUVs(0, g.uv);
        var bw = new BoneWeight[g.w.Count];
        for (int i = 0; i < bw.Length; i++)
        {
            Vector3 w = g.w[i]; float s = w.x + w.y + w.z; if (s <= 0) { w = new Vector3(0, 0, 1); s = 1; }
            bw[i] = new BoneWeight { boneIndex0 = 0, weight0 = w.x / s, boneIndex1 = 1, weight1 = w.y / s, boneIndex2 = 2, weight2 = w.z / s };
        }
        m.boneWeights = bw;
        m.subMeshCount = ArmGeo.SUBS;
        for (int s = 0; s < ArmGeo.SUBS; s++) m.SetTriangles(g.sub[s], s);
        m.RecalculateTangents();
        m.RecalculateBounds();
        m.bindposes = new[] { Matrix4x4.identity, Matrix4x4.Translate(new Vector3(0, l1, 0)), Matrix4x4.Translate(new Vector3(0, l1 + l2, 0)) };
        meshes[key] = m;
        return m;
    }

    public static Material[] Materials(Look L)
    {
        string key = ColorUtility.ToHtmlStringRGB(L.uniform) + ColorUtility.ToHtmlStringRGB(L.uniform2) + ColorUtility.ToHtmlStringRGB(L.gear);
        if (mats.TryGetValue(key, out var arr) && arr != null) return arr;
        if (weaveN == null) BuildNormals();
        // рукав: камуфляж из цветов формы
        Color baseC = Lift(L.uniform, 0.16f), dark = Lift(L.uniform2, 0.1f) * 0.8f, light = Color.Lerp(baseC, new Color(0.52f, 0.5f, 0.42f), 0.35f);
        int seed = (int)(L.uniform.r * 97 + L.uniform.g * 31);
        var fab = MakeTex(256, (x, y) =>
        {
            float n1 = Tile(x, y, 3f, seed, 11), n2 = Tile(x, y, 5f, seed + 40, 3), n3 = Tile(x, y, 40f, seed, seed);
            Color c = baseC;
            c = Color.Lerp(c, dark, Mathf.SmoothStep(0.56f, 0.6f, n1) * 0.85f);
            c = Color.Lerp(c, light, Mathf.SmoothStep(0.6f, 0.64f, n2) * 0.6f);
            c *= 0.9f + n3 * 0.18f;
            c.a = 1f; return c;
        }, false, false);
        var sleeve = new Material(Mats.Std) { name = "fpSleeve" };
        sleeve.mainTexture = fab; sleeve.color = Color.white;
        sleeve.SetFloat("_Glossiness", 0.12f);
        Mats.AddNormal(sleeve, weaveN, 0.9f);
        sleeve.SetTextureScale("_BumpMap", Vector2.one);
        // перчатка: цвет снаряжения, чуть светлее, с потёртостями
        Color gc = Color.Lerp(Lift(L.gear, 0.12f), new Color(0.33f, 0.28f, 0.21f), 0.3f);
        var gtex = MakeTex(128, (x, y) =>
        {
            float n = Tile(x, y, 6f, 3, 7), f = Tile(x, y, 30f, 9, 1);
            Color c = gc * (0.85f + n * 0.25f + f * 0.08f);
            // швы
            float sx = Mathf.Abs(Mathf.Repeat(x * 2f, 1f) - 0.5f);
            if (sx > 0.485f) c *= 0.7f;
            else if (sx > 0.47f && Mathf.Repeat(y * 40f, 1f) < 0.5f) c = Color.Lerp(c, new Color(0.45f, 0.42f, 0.36f), 0.5f);
            c.a = 1f; return c;
        }, false, false);
        var glove = new Material(Mats.Std) { name = "fpGlove" };
        glove.mainTexture = gtex; glove.color = Color.white;
        glove.SetFloat("_Glossiness", 0.32f);
        Mats.AddNormal(glove, leatherN, 1f);
        var pad = new Material(Mats.Std) { name = "fpPad" };
        pad.color = gc * 0.55f; pad.SetFloat("_Glossiness", 0.2f);
        Mats.AddNormal(pad, padN, 1f);
        var watch = new Material(Mats.Std) { name = "fpWatch" };
        watch.color = new Color(0.05f, 0.05f, 0.055f); watch.SetFloat("_Glossiness", 0.6f);
        arr = new[] { sleeve, glove, pad, watch };
        mats[key] = arr;
        return arr;
    }

    static Color Lift(Color c, float min)
    {
        float m = Mathf.Max(c.r, Mathf.Max(c.g, c.b));
        if (m >= min) return c;
        return m < 0.001f ? new Color(min, min, min) : c * (min / m);
    }

    static void BuildNormals()
    {
        // плетение ткани (саржа): диагональные рубчики + нити
        weaveN = NormalFromHeight(256, (x, y) =>
        {
            float a = Mathf.Sin((x * 64f + y * 64f) * Mathf.PI * 2f) * 0.5f + 0.5f;
            float b = Mathf.Sin(x * 128f * Mathf.PI * 2f) * Mathf.Sin(y * 128f * Mathf.PI * 2f);
            return a * 0.6f + b * 0.15f + Tile(x, y, 12f, 2, 5) * 0.8f;
        }, 2.2f);
        // кожа перчатки: мелкая зернистость + складки
        leatherN = NormalFromHeight(256, (x, y) => Tile(x, y, 48f, 1, 2) * 0.5f + Tile(x, y, 96f, 7, 3) * 0.35f + Mathf.Abs(Tile(x, y, 6f, 4, 4) - 0.5f) * 0.6f, 3f);
        // накладки: рифление
        padN = NormalFromHeight(128, (x, y) => (Mathf.Sin(y * 24f * Mathf.PI * 2f) > 0.6f ? 1f : 0f) * 0.6f + Tile(x, y, 30f, 5, 9) * 0.3f, 2f);
    }

    static Texture2D NormalFromHeight(int size, Mats.PixelFn hf, float strength)
    {
        var h = new float[size * size];
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++) h[y * size + x] = hf((x + 0.5f) / size, (y + 0.5f) / size).r;
        var px = new Color[size * size];
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float dx = h[y * size + (x + 1) % size] - h[y * size + (x + size - 1) % size];
                float dy = h[((y + 1) % size) * size + x] - h[((y + size - 1) % size) * size + x];
                Vector3 n = new Vector3(-dx * strength, -dy * strength, 1f).normalized;
                float r = n.x * 0.5f + 0.5f, g = n.y * 0.5f + 0.5f;
                px[y * size + x] = new Color(r, g, n.z * 0.5f + 0.5f, r);
            }
        var t = new Texture2D(size, size, TextureFormat.RGBA32, true, true);
        t.SetPixels(px); t.wrapMode = TextureWrapMode.Repeat; t.anisoLevel = 4; t.Apply(true);
        return t;
    }

    static Texture2D NormalFromHeight(int size, System.Func<float, float, float> hf, float strength) => NormalFromHeight(size, (x, y) => { float v = hf(x, y); return new Color(v, v, v); }, strength);

    static Texture2D MakeTex(int size, Mats.PixelFn fn, bool clamp, bool linear)
    {
        var t = new Texture2D(size, size, TextureFormat.RGBA32, true, linear);
        var px = new Color[size * size];
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++) px[y * size + x] = fn((x + 0.5f) / size, (y + 0.5f) / size);
        t.SetPixels(px); t.wrapMode = clamp ? TextureWrapMode.Clamp : TextureWrapMode.Repeat; t.anisoLevel = 4; t.Apply(true);
        return t;
    }

    static float Tile(float x, float y, float freq, float ox, float oy)
    {
        float a = Mathf.PerlinNoise(x * freq + ox, y * freq + oy);
        float b = Mathf.PerlinNoise((x - 1) * freq + ox, y * freq + oy);
        float c = Mathf.PerlinNoise(x * freq + ox, (y - 1) * freq + oy);
        float d = Mathf.PerlinNoise((x - 1) * freq + ox, (y - 1) * freq + oy);
        return Mathf.Lerp(Mathf.Lerp(a, b, x), Mathf.Lerp(c, d, x), y);
    }
}
