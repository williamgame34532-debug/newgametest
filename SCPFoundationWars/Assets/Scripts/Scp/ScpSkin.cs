using System.Collections.Generic;
using UnityEngine;

// Свои детальные текстуры для SCP-объектов (бетон с потёками краски, кожа балахона, гниющая плоть, мышцы, чешуя, уголь).
// Накладываются поверх цвета каждой детали: силуэт остаётся, поверхность становится материальной.
public static class ScpSkin
{
    public enum Kind { Concrete, Leather, Rot, Flesh, Scales, Char, Pale }
    static readonly Dictionary<Kind, Texture2D> tex = new Dictionary<Kind, Texture2D>();
    static readonly Dictionary<long, Material> cache = new Dictionary<long, Material>();

    static float N(float x, float y, float f, float o) => Mathf.PerlinNoise(x * f + o, y * f + o * 0.7f);
    static float Fbm(float x, float y, float f, float o) { float s = 0, a = 0.5f, n = 0; for (int i = 0; i < 4; i++) { s += a * N(x, y, f, o + i * 13f); n += a; a *= 0.5f; f *= 2f; } return s / n; }

    static Texture2D Tex(Kind k)
    {
        if (tex.TryGetValue(k, out var t) && t != null) return t;
        t = Mats.MakeTex(256, (x, y) =>
        {
            float n = Fbm(x, y, 6f, (int)k * 17f), hi = N(x, y, 48f, 3f);
            float v;
            switch (k)
            {
                case Kind.Concrete:
                {
                    float pits = hi > 0.72f ? 0.75f : 1f;
                    float crack = Mathf.Abs(Fbm(x, y, 3f, 41f) - 0.5f) < 0.012f ? 0.6f : 1f;
                    float streak = 1f - Mathf.Clamp01((N(x * 0.2f, y * 6f, 4f, 9f) - 0.62f) * 2f) * 0.25f;   // вертикальные потёки
                    v = (0.72f + n * 0.4f) * pits * crack * streak;
                    break;
                }
                case Kind.Leather:
                {
                    float grain = 0.9f + hi * 0.15f;
                    float crease = 1f - Mathf.Pow(Mathf.Abs(Mathf.Sin((y * 9f + Fbm(x, y, 2f, 5f) * 3f) * 6.28f)), 18f) * 0.35f;
                    v = (0.75f + n * 0.35f) * grain * crease;
                    break;
                }
                case Kind.Rot:
                {
                    float blot = Mathf.Clamp01((Fbm(x, y, 4f, 7f) - 0.45f) * 3f);
                    v = (0.6f + n * 0.5f) * (1f - blot * 0.45f) * (0.9f + hi * 0.2f);
                    break;
                }
                case Kind.Flesh:
                {
                    float fiber = 0.85f + Mathf.Abs(Mathf.Sin((x * 30f + Fbm(x, y, 3f, 2f) * 5f) * 3.14f)) * 0.2f;
                    float vein = Mathf.Abs(Fbm(x, y, 5f, 19f) - 0.5f) < 0.015f ? 0.55f : 1f;
                    v = (0.7f + n * 0.45f) * fiber * vein;
                    break;
                }
                case Kind.Scales:
                {
                    float sx = x * 16f, sy = y * 16f + (Mathf.Floor(x * 16f) % 2) * 0.5f;
                    float cx = sx - Mathf.Floor(sx) - 0.5f, cy = sy - Mathf.Floor(sy) - 0.5f;
                    float d = Mathf.Sqrt(cx * cx + cy * cy);
                    v = (0.65f + n * 0.4f) * (d > 0.42f ? 0.55f : 1f - d * 0.5f);
                    break;
                }
                case Kind.Char:
                {
                    float cr = Mathf.Abs(Fbm(x, y, 4f, 31f) - 0.5f) < 0.02f ? 1.8f : 1f;
                    v = (0.5f + n * 0.6f) * cr;
                    break;
                }
                default:
                    v = 0.85f + n * 0.25f + (hi - 0.5f) * 0.05f;
                    break;
            }
            return new Color(v, v * (k == Kind.Flesh || k == Kind.Rot ? 0.94f : 1f), v * (k == Kind.Flesh ? 0.9f : 1f), 1f);
        }, false);
        t.anisoLevel = 2;
        tex[k] = t;
        return t;
    }

    public static void Apply(GameObject root, Kind k, float smooth = -1f)
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
        {
            if (r is ParticleSystemRenderer || r is LineRenderer) continue;
            var ms = r.sharedMaterials;
            bool changed = false;
            for (int i = 0; i < ms.Length; i++)
            {
                var m = ms[i];
                if (m == null || m.mainTexture != null || m.IsKeywordEnabled("_EMISSION") || m.renderQueue > 2500) continue;
                long key = m.GetInstanceID() * 16L + (int)k;
                if (!cache.TryGetValue(key, out var nm) || nm == null)
                {
                    nm = new Material(m);
                    nm.mainTexture = Tex(k);
                    nm.mainTextureScale = Vector2.one * (k == Kind.Scales ? 3f : 2f);
                    Color c = m.color * 1.25f; c.a = 1f;
                    nm.color = c;
                    if (smooth >= 0f) nm.SetFloat("_Glossiness", smooth);
                    cache[key] = nm;
                }
                ms[i] = nm; changed = true;
            }
            if (changed) r.sharedMaterials = ms;
        }
    }
}
