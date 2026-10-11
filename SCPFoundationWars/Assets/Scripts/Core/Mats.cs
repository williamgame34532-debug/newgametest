using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Материалы и процедурные текстуры. Всё кэшируется, чтобы не плодить тысячи материалов.
public static class Mats
{
    static Shader std, particle, unlit;
    static readonly Dictionary<long, Material> cache = new Dictionary<long, Material>();

    public static Shader Std { get { if (std == null) std = Shader.Find("Standard"); return std; } }

    public static Shader ParticleShader
    {
        get
        {
            if (particle == null) particle = Shader.Find("Particles/Standard Unlit");
            if (particle == null) particle = Shader.Find("Legacy Shaders/Particles/Alpha Blended");
            if (particle == null) particle = Shader.Find("Sprites/Default");
            return particle;
        }
    }

    public static Shader UnlitShader
    {
        get
        {
            if (unlit == null) unlit = Shader.Find("Unlit/Color");
            if (unlit == null) unlit = Shader.Find("Sprites/Default");
            return unlit;
        }
    }

    static long Key(Color c, float s, float m, int kind)
    {
        Color32 c32 = c;
        return ((long)c32.r) | ((long)c32.g << 8) | ((long)c32.b << 16) | ((long)c32.a << 24)
            | ((long)(Mathf.Clamp01(s) * 63) << 32) | ((long)(Mathf.Clamp01(m) * 63) << 38) | ((long)kind << 44);
    }

    // Обычный непрозрачный материал
    public static Material Get(Color c, float smooth = 0.25f, float metal = 0f)
    {
        long k = Key(c, smooth, metal, 0);
        if (cache.TryGetValue(k, out var m) && m != null) return m;
        m = new Material(Std);
        m.color = c;
        m.SetFloat("_Glossiness", smooth);
        m.SetFloat("_Metallic", metal);
        m.enableInstancing = true;
        cache[k] = m;
        return m;
    }

    // Светящийся материал (визоры, огонь, лампы)
    public static Material Glow(Color c, float intensity = 2f)
    {
        long k = Key(c, intensity / 8f, 0, 1);
        if (cache.TryGetValue(k, out var m) && m != null) return m;
        m = new Material(Std);
        m.color = c * 0.6f;
        m.EnableKeyword("_EMISSION");
        m.SetColor("_EmissionColor", c * intensity);
        m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.None;
        m.enableInstancing = true;
        cache[k] = m;
        return m;
    }

    // Прозрачный материал (стекло, визоры)
    public static Material Glass(Color c, float smooth = 0.9f, bool glow = false)
    {
        long k = Key(c, smooth, glow ? 1 : 0, 2);
        if (cache.TryGetValue(k, out var m) && m != null) return m;
        m = new Material(Std);
        MakeTransparent(m);
        m.color = c;
        m.SetFloat("_Glossiness", smooth);
        if (glow)
        {
            m.EnableKeyword("_EMISSION");
            m.SetColor("_EmissionColor", new Color(c.r, c.g, c.b) * 1.2f);
        }
        cache[k] = m;
        return m;
    }

    public static void MakeTransparent(Material m)
    {
        m.SetFloat("_Mode", 3);
        m.SetInt("_SrcBlend", (int)BlendMode.One);
        m.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
        m.SetInt("_ZWrite", 0);
        m.DisableKeyword("_ALPHATEST_ON");
        m.DisableKeyword("_ALPHABLEND_ON");
        m.EnableKeyword("_ALPHAPREMULTIPLY_ON");
        m.renderQueue = 3000;
    }

    public static void MakeFade(Material m)
    {
        m.SetFloat("_Mode", 2);
        m.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
        m.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
        m.SetInt("_ZWrite", 0);
        m.DisableKeyword("_ALPHATEST_ON");
        m.EnableKeyword("_ALPHABLEND_ON");
        m.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        m.renderQueue = 3000;
    }

    // Материал для частиц (мягкое круглое пятно)
    static readonly Dictionary<int, Material> particleMats = new Dictionary<int, Material>();
    public static Material Particle(int texKind = 0, bool additive = false)
    {
        int k = texKind * 2 + (additive ? 1 : 0);
        if (particleMats.TryGetValue(k, out var m) && m != null) return m;
        m = new Material(ParticleShader);
        m.mainTexture = texKind == 1 ? SmokeTex : texKind == 2 ? SparkTex : SoftDot;
        if (m.HasProperty("_Mode"))
        {
            // Particles/Standard Unlit: 0 opaque, 1 cutout, 2 fade, 3 transparent, 4 additive
            m.SetFloat("_Mode", additive ? 4 : 2);
            m.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
            m.SetInt("_DstBlend", additive ? (int)BlendMode.One : (int)BlendMode.OneMinusSrcAlpha);
            m.SetInt("_ZWrite", 0);
            m.EnableKeyword("_ALPHABLEND_ON");
            m.renderQueue = 3000;
        }
        particleMats[k] = m;
        return m;
    }

    // Материал декали (кровь, дыры) — с текстурой
    public static Material Decal(Texture2D tex, Color tint)
    {
        var m = new Material(Std);
        MakeFade(m);
        m.mainTexture = tex;
        m.color = tint;
        m.SetFloat("_Glossiness", 0.55f);
        m.enableInstancing = true;
        return m;
    }

    public static Material Textured(Texture2D tex, Color tint, Vector2 tiling, float smooth = 0.1f)
    {
        var m = new Material(Std);
        m.mainTexture = tex;
        m.mainTextureScale = tiling;
        m.color = tint;
        m.SetFloat("_Glossiness", smooth);
        return m;
    }

    // Текстуры из Resources/Models/*.bytes (PNG): цвет — sRGB, карта нормалей — линейная (X продублирован в альфе)
    static readonly Dictionary<string, Texture2D> byteTex = new Dictionary<string, Texture2D>();
    public static Texture2D BytesTex(string name, bool linear)
    {
        if (string.IsNullOrEmpty(name)) return null;
        if (byteTex.TryGetValue(name, out var t)) return t;
        var ta = Resources.Load<TextAsset>("Models/" + name);
        if (ta == null) { byteTex[name] = null; return null; }
        t = new Texture2D(2, 2, TextureFormat.RGBA32, true, linear);
        t.LoadImage(ta.bytes);
        t.wrapMode = TextureWrapMode.Repeat;
        t.anisoLevel = 4;
        t.Apply(true, true);
        byteTex[name] = t;
        return t;
    }

    public static void AddNormal(Material m, Texture2D n, float scale = 1f)
    {
        if (m == null || n == null) return;
        m.SetTexture("_BumpMap", n);
        m.SetFloat("_BumpScale", scale);
        m.EnableKeyword("_NORMALMAP");
    }

    // Фото-текстуры (Poly Haven / ambientCG, CC0) из Resources/Textures
    static readonly Dictionary<string, Texture2D> photos = new Dictionary<string, Texture2D>();
    public static Texture2D Photo(string name)
    {
        if (photos.TryGetValue(name, out var t)) return t;
        t = Resources.Load<Texture2D>("Textures/photo_" + name);
        if (t != null) { t.wrapMode = TextureWrapMode.Repeat; t.anisoLevel = 8; }
        photos[name] = t;
        return t;
    }
    public static Texture2D PhotoOr(string name, Texture2D fallback) { var t = Photo(name); return t != null ? t : fallback; }

    // Материал с мировой проекцией (стены, плиты, бетон) — шаг текстуры в метрах
    static Shader tri; static bool triTried;
    public static Material Tri(Texture2D tex, Color tint, float tileMeters, float smooth = 0.15f, float grime = 0.4f, float metal = 0f)
    {
        if (!triTried) { tri = Shader.Find("SCP/Triplanar"); triTried = true; }
        if (tri == null) { var f = Textured(tex, tint, Vector2.one * 4f, smooth); f.SetFloat("_Metallic", metal); return f; }
        var m = new Material(tri);
        m.mainTexture = tex;
        m.color = tint;
        m.SetFloat("_Scale", tileMeters);
        m.SetFloat("_Glossiness", smooth);
        m.SetFloat("_Metallic", metal);
        m.SetFloat("_Grime", grime);
        return m;
    }

    public static Material UnlitMat(Color c)
    {
        var m = new Material(UnlitShader);
        m.color = c;
        return m;
    }

    // ---------------- процедурные текстуры ----------------
    static Texture2D softDot, smokeTex, sparkTex, bloodTex, holeTex, scorchTex;

    public static Texture2D SoftDot
    {
        get
        {
            if (softDot != null) return softDot;
            softDot = MakeTex(64, (x, y) =>
            {
                float d = Vector2.Distance(new Vector2(x, y), new Vector2(0.5f, 0.5f)) * 2f;
                float a = Mathf.Clamp01(1f - d);
                return new Color(1, 1, 1, a * a * (3 - 2 * a));
            });
            return softDot;
        }
    }

    public static Texture2D SmokeTex
    {
        get
        {
            if (smokeTex != null) return smokeTex;
            smokeTex = MakeTex(128, (x, y) =>
            {
                float d = Vector2.Distance(new Vector2(x, y), new Vector2(0.5f, 0.5f)) * 2f;
                float n = Mathf.PerlinNoise(x * 6f + 3.1f, y * 6f + 7.7f) * 0.6f + Mathf.PerlinNoise(x * 13f, y * 13f) * 0.4f;
                float a = Mathf.Clamp01(1f - d) * Mathf.Clamp01(n * 1.5f - 0.15f);
                return new Color(1, 1, 1, a);
            });
            return smokeTex;
        }
    }

    public static Texture2D SparkTex
    {
        get
        {
            if (sparkTex != null) return sparkTex;
            sparkTex = MakeTex(32, (x, y) =>
            {
                float dx = Mathf.Abs(x - 0.5f) * 2f, dy = Mathf.Abs(y - 0.5f) * 2f;
                float a = Mathf.Clamp01(1f - dx * 3f) * Mathf.Clamp01(1f - dy);
                return new Color(1, 1, 1, a);
            });
            return sparkTex;
        }
    }

    public static Texture2D BloodTex
    {
        get
        {
            if (bloodTex != null) return bloodTex;
            var rnd = new System.Random(7);
            var blobs = new List<Vector3>();
            blobs.Add(new Vector3(0.5f, 0.5f, 0.28f));
            for (int i = 0; i < 14; i++)
            {
                float ang = (float)rnd.NextDouble() * Mathf.PI * 2f;
                float r = 0.15f + (float)rnd.NextDouble() * 0.3f;
                blobs.Add(new Vector3(0.5f + Mathf.Cos(ang) * r, 0.5f + Mathf.Sin(ang) * r, 0.02f + (float)rnd.NextDouble() * 0.07f));
            }
            bloodTex = MakeTex(128, (x, y) =>
            {
                float v = 0;
                foreach (var b in blobs)
                {
                    float d = Vector2.Distance(new Vector2(x, y), new Vector2(b.x, b.y));
                    v = Mathf.Max(v, Mathf.Clamp01((b.z - d) / 0.025f + 0.5f));
                }
                float n = Mathf.PerlinNoise(x * 9f, y * 9f);
                float dark = 0.75f + n * 0.25f;
                return new Color(dark, dark, dark, v);
            });
            return bloodTex;
        }
    }

    // Брызги крови: ядро, капли, вытянутые потёки по направлению удара (несколько вариантов)
    static readonly Texture2D[] splatTex = new Texture2D[4];
    public static Texture2D SplatterTex(int variant)
    {
        variant = Mathf.Abs(variant) % splatTex.Length;
        if (splatTex[variant] != null) return splatTex[variant];
        var rnd = new System.Random(31 + variant * 17);
        float R() => (float)rnd.NextDouble();
        var blobs = new List<Vector4>();   // x, y, радиус, вытянутость
        blobs.Add(new Vector4(0.42f, 0.5f, 0.16f + R() * 0.06f, 1f));
        for (int i = 0; i < 6; i++) blobs.Add(new Vector4(0.36f + R() * 0.16f, 0.4f + R() * 0.2f, 0.05f + R() * 0.07f, 1f));
        for (int i = 0; i < 28; i++)
        {
            float a = (R() - 0.5f) * 1.5f, r = 0.18f + R() * 0.3f;
            blobs.Add(new Vector4(0.42f + Mathf.Cos(a) * r, 0.5f + Mathf.Sin(a) * r, 0.006f + R() * 0.02f, 1f + R() * 3f));
        }
        splatTex[variant] = MakeTex(256, (x, y) =>
        {
            float v = 0;
            foreach (var b in blobs)
            {
                float dx = (x - b.x) / b.w, dy = y - b.y;           // потёки вытянуты вдоль X (направление удара)
                float d = Mathf.Sqrt(dx * dx + dy * dy);
                v = Mathf.Max(v, Mathf.Clamp01((b.z - d) / 0.012f + 0.5f));
            }
            float edge = Mathf.PerlinNoise(x * 23f + variant, y * 23f) * 0.35f;
            v = Mathf.Clamp01(v * 1.1f - edge * (1f - v) * 2f);
            float n = 0.7f + Mathf.PerlinNoise(x * 7f, y * 7f + variant) * 0.3f;
            // по краю — темнее (подсохшее), в центре — сочнее
            return new Color(n, n * 0.95f, n * 0.95f, v);
        });
        return splatTex[variant];
    }

    // Лужа: гладкая, с неровным краем и тёмной каймой
    static Texture2D poolTex;
    public static Texture2D PoolTex
    {
        get
        {
            if (poolTex != null) return poolTex;
            poolTex = MakeTex(256, (x, y) =>
            {
                float dx = x - 0.5f, dy = y - 0.5f;
                float ang = Mathf.Atan2(dy, dx);
                float rr = 0.36f + Mathf.PerlinNoise(Mathf.Cos(ang) * 2f + 3f, Mathf.Sin(ang) * 2f + 7f) * 0.12f;
                float d = Mathf.Sqrt(dx * dx + dy * dy);
                float a = Mathf.Clamp01((rr - d) / 0.02f);
                float rim = Mathf.Clamp01(1f - (rr - d) / 0.06f);
                float c = Mathf.Lerp(1f, 0.55f, rim);
                return new Color(c, c, c, a);
            });
            return poolTex;
        }
    }

    public static Texture2D HoleTex
    {
        get
        {
            if (holeTex != null) return holeTex;
            holeTex = MakeTex(32, (x, y) =>
            {
                float d = Vector2.Distance(new Vector2(x, y), new Vector2(0.5f, 0.5f)) * 2f;
                float core = Mathf.Clamp01((0.3f - d) * 10f);
                float ring = Mathf.Clamp01(1f - d) * 0.5f;
                float c = core > 0 ? 0.02f : 0.25f;
                return new Color(c, c, c, Mathf.Max(core, ring));
            });
            return holeTex;
        }
    }

    public static Texture2D ScorchTex
    {
        get
        {
            if (scorchTex != null) return scorchTex;
            scorchTex = MakeTex(128, (x, y) =>
            {
                float d = Vector2.Distance(new Vector2(x, y), new Vector2(0.5f, 0.5f)) * 2f;
                float n = Mathf.PerlinNoise(x * 7f + 2, y * 7f + 5);
                float a = Mathf.Clamp01((1f - d) * 1.6f) * (0.6f + n * 0.4f);
                return new Color(0.05f, 0.04f, 0.035f, a);
            });
            return scorchTex;
        }
    }

    public delegate Color PixelFn(float x, float y);

    public static Texture2D MakeTex(int size, PixelFn fn, bool clamp = true)
    {
        var t = new Texture2D(size, size, TextureFormat.RGBA32, true);
        var px = new Color[size * size];
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
                px[y * size + x] = fn((x + 0.5f) / size, (y + 0.5f) / size);
        t.SetPixels(px);
        t.wrapMode = clamp ? TextureWrapMode.Clamp : TextureWrapMode.Repeat;
        t.filterMode = FilterMode.Bilinear;
        t.Apply(true);
        return t;
    }

    // Текстура земли (трава/песок/снег) с крупными и мелкими пятнами
    public static Texture2D GroundTex(Color a, Color b, Color c, int seed)
    {
        float ox = seed * 13.1f, oy = seed * 7.7f;
        return MakeTex(256, (x, y) =>
        {
            float n1 = Tile(x, y, 4f, ox, oy);
            float n2 = Tile(x, y, 16f, ox + 50, oy + 20);
            float n3 = Tile(x, y, 48f, ox + 9, oy + 90);
            Color col = Color.Lerp(a, b, Mathf.SmoothStep(0.3f, 0.7f, n1));
            col = Color.Lerp(col, c, Mathf.Clamp01((n2 - 0.6f) * 2.5f));
            col *= 0.85f + n3 * 0.3f;
            col.a = 1;
            return col;
        }, false);
    }

    public static Texture2D ConcreteTex(Color baseCol, int seed)
    {
        return MakeTex(128, (x, y) =>
        {
            float n = Tile(x, y, 8f, seed, seed * 2) * 0.6f + Tile(x, y, 32f, seed + 3, seed) * 0.4f;
            float seam = (Mathf.Abs((x * 2f) % 1f - 0.5f) > 0.49f || Mathf.Abs((y * 2f) % 1f - 0.5f) > 0.49f) ? 0.8f : 1f;
            Color c = baseCol * (0.82f + n * 0.3f) * seam;
            c.a = 1;
            return c;
        }, false);
    }

    // Бесшовный шум
    static float Tile(float x, float y, float freq, float ox, float oy)
    {
        float a = Mathf.PerlinNoise(x * freq + ox, y * freq + oy);
        float b = Mathf.PerlinNoise((x - 1) * freq + ox, y * freq + oy);
        float c = Mathf.PerlinNoise(x * freq + ox, (y - 1) * freq + oy);
        float d = Mathf.PerlinNoise((x - 1) * freq + ox, (y - 1) * freq + oy);
        float u = x, v = y;
        return Mathf.Lerp(Mathf.Lerp(a, b, u), Mathf.Lerp(c, d, u), v);
    }
}
