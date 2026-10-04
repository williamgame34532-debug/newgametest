using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public class UIPalette
    {
        public Color panel, panelEdge, text, sub, accent, accent2, btn, btnHover, btnText, title, titleShadow;
    }

    // Стили арены: бумага, арена, поле, город, киберпанк
    public class Theme : MonoBehaviour
    {
        public static readonly string[] Names = { "Лист бумаги", "Тёмная арена", "Поле", "Город", "Киберпанк", "Туманный лес", "Сияние", "Дуэль", "Чистый лист", "Долина", "Закат", "Кровавая луна", "Пепелище" };
        public const int Count = 13;

        public int id;
        public Color bg;
        public bool glow, outline, silhouette;
        public Color groundCol = new Color(0.3f, 0.3f, 0.3f);
        bool depthOn;
        public Color outlineCol = new Color(0.05f, 0.05f, 0.06f), ink = Color.white;
        public Color defaultRed, defaultBlue;

        class Layer { public Transform t; public float f; public Vector3 basePos; }
        readonly List<Layer> layers = new List<Layer>();
        readonly List<Transform> clouds = new List<Transform>();
        readonly List<SpriteRenderer> flicker = new List<SpriteRenderer>();
        float W;
        float time;

        public static UIPalette Palette(int id)
        {
            var p = new UIPalette();
            switch (id)
            {
                case 0: // бумага
                    p.panel = new Color(1f, 0.99f, 0.95f, 0.92f); p.panelEdge = new Color(0.1f, 0.1f, 0.1f, 1f);
                    p.text = new Color(0.08f, 0.08f, 0.1f); p.sub = new Color(0.35f, 0.35f, 0.38f);
                    p.accent = new Color(0.8f, 0.08f, 0.08f); p.accent2 = new Color(0.1f, 0.25f, 0.8f);
                    p.btn = new Color(1f, 1f, 1f, 0.95f); p.btnHover = new Color(1f, 0.9f, 0.85f, 1f); p.btnText = new Color(0.08f, 0.08f, 0.1f);
                    p.title = new Color(0.08f, 0.08f, 0.1f); p.titleShadow = new Color(0.8f, 0.08f, 0.08f, 0.9f);
                    break;
                case 1: // арена
                    p.panel = new Color(0.08f, 0.08f, 0.09f, 0.9f); p.panelEdge = new Color(0.9f, 0.4f, 0.35f, 1f);
                    p.text = new Color(0.95f, 0.95f, 0.95f); p.sub = new Color(0.65f, 0.65f, 0.68f);
                    p.accent = new Color(0.92f, 0.38f, 0.33f); p.accent2 = new Color(0.4f, 0.55f, 0.9f);
                    p.btn = new Color(0.14f, 0.14f, 0.15f, 0.95f); p.btnHover = new Color(0.32f, 0.14f, 0.13f, 1f); p.btnText = new Color(0.97f, 0.97f, 0.97f);
                    p.title = new Color(0.97f, 0.97f, 0.97f); p.titleShadow = new Color(0.92f, 0.38f, 0.33f, 0.9f);
                    break;
                case 2: // поле
                    p.panel = new Color(1f, 1f, 0.97f, 0.88f); p.panelEdge = new Color(0.2f, 0.45f, 0.15f, 1f);
                    p.text = new Color(0.1f, 0.18f, 0.08f); p.sub = new Color(0.3f, 0.4f, 0.28f);
                    p.accent = new Color(0.85f, 0.35f, 0.1f); p.accent2 = new Color(0.2f, 0.5f, 0.15f);
                    p.btn = new Color(1f, 1f, 1f, 0.92f); p.btnHover = new Color(0.9f, 1f, 0.85f, 1f); p.btnText = new Color(0.1f, 0.18f, 0.08f);
                    p.title = new Color(1f, 1f, 1f); p.titleShadow = new Color(0.1f, 0.25f, 0.05f, 0.9f);
                    break;
                case 3: // город
                    p.panel = new Color(0.22f, 0.22f, 0.23f, 0.88f); p.panelEdge = new Color(0.86f, 0.36f, 0.36f, 1f);
                    p.text = new Color(0.97f, 0.97f, 0.97f); p.sub = new Color(0.75f, 0.75f, 0.77f);
                    p.accent = new Color(0.86f, 0.36f, 0.36f); p.accent2 = new Color(0.35f, 0.65f, 0.95f);
                    p.btn = new Color(0.82f, 0.38f, 0.38f, 0.95f); p.btnHover = new Color(0.95f, 0.5f, 0.5f, 1f); p.btnText = new Color(1f, 1f, 1f);
                    p.title = new Color(0.85f, 0.92f, 1f); p.titleShadow = new Color(0.2f, 0.45f, 0.95f, 0.9f);
                    break;
                case 5: // туманный лес
                    p.panel = new Color(0.95f, 0.95f, 0.95f, 0.9f); p.panelEdge = new Color(0.08f, 0.08f, 0.08f, 1f);
                    p.text = new Color(0.06f, 0.06f, 0.07f); p.sub = new Color(0.35f, 0.35f, 0.37f);
                    p.accent = new Color(0.85f, 0.05f, 0.05f); p.accent2 = new Color(0.2f, 0.5f, 0.95f);
                    p.btn = new Color(0.1f, 0.1f, 0.1f, 0.92f); p.btnHover = new Color(0.35f, 0.05f, 0.05f, 1f); p.btnText = new Color(0.97f, 0.97f, 0.97f);
                    p.title = new Color(0.05f, 0.05f, 0.05f); p.titleShadow = new Color(0.85f, 0.05f, 0.05f, 0.9f);
                    break;
                case 9: // долина
                    p.panel = new Color(1f, 1f, 1f, 0.88f); p.panelEdge = new Color(0.2f, 0.3f, 0.5f, 1f);
                    p.text = new Color(0.1f, 0.12f, 0.2f); p.sub = new Color(0.35f, 0.4f, 0.5f);
                    p.accent = new Color(0.15f, 0.2f, 0.45f); p.accent2 = new Color(0.3f, 0.6f, 0.3f);
                    p.btn = new Color(1f, 1f, 1f, 0.92f); p.btnHover = new Color(0.88f, 0.92f, 1f, 1f); p.btnText = new Color(0.1f, 0.12f, 0.2f);
                    p.title = new Color(0.12f, 0.14f, 0.3f); p.titleShadow = new Color(1f, 1f, 1f, 0.9f);
                    break;
                case 10: // закат
                    p.panel = new Color(0.12f, 0.05f, 0.05f, 0.85f); p.panelEdge = new Color(1f, 0.55f, 0.3f, 1f);
                    p.text = new Color(1f, 0.93f, 0.85f); p.sub = new Color(0.9f, 0.65f, 0.55f);
                    p.accent = new Color(0.95f, 0.4f, 0.2f); p.accent2 = new Color(0.25f, 0.35f, 0.8f);
                    p.btn = new Color(0.2f, 0.08f, 0.07f, 0.95f); p.btnHover = new Color(0.45f, 0.15f, 0.1f, 1f); p.btnText = new Color(1f, 0.93f, 0.85f);
                    p.title = new Color(0.1f, 0.12f, 0.35f); p.titleShadow = new Color(1f, 0.55f, 0.3f, 0.95f);
                    break;
                case 8: // чистый лист
                    p.panel = new Color(1f, 1f, 1f, 0.94f); p.panelEdge = new Color(0.08f, 0.08f, 0.09f, 1f);
                    p.text = new Color(0.07f, 0.07f, 0.08f); p.sub = new Color(0.4f, 0.4f, 0.42f);
                    p.accent = new Color(0.15f, 0.15f, 0.17f); p.accent2 = new Color(0.85f, 0.2f, 0.15f);
                    p.btn = new Color(1f, 1f, 1f, 0.97f); p.btnHover = new Color(0.92f, 0.92f, 0.93f, 1f); p.btnText = new Color(0.07f, 0.07f, 0.08f);
                    p.title = new Color(0.07f, 0.07f, 0.08f); p.titleShadow = new Color(0.75f, 0.75f, 0.77f, 0.9f);
                    break;
                case 7: // дуэль
                    p.panel = new Color(0.1f, 0.1f, 0.11f, 0.9f); p.panelEdge = new Color(0.86f, 0.4f, 0.37f, 1f);
                    p.text = new Color(0.95f, 0.95f, 0.95f); p.sub = new Color(0.62f, 0.62f, 0.65f);
                    p.accent = new Color(0.86f, 0.4f, 0.37f); p.accent2 = new Color(0.42f, 0.56f, 0.86f);
                    p.btn = new Color(0.16f, 0.16f, 0.17f, 0.95f); p.btnHover = new Color(0.3f, 0.17f, 0.16f, 1f); p.btnText = new Color(0.95f, 0.95f, 0.95f);
                    p.title = new Color(0.95f, 0.95f, 0.95f); p.titleShadow = new Color(0.42f, 0.56f, 0.86f, 0.9f);
                    break;
                case 6: // сияние
                    p.panel = new Color(0.12f, 0.1f, 0.2f, 0.88f); p.panelEdge = new Color(0.85f, 0.75f, 1f, 1f);
                    p.text = new Color(0.97f, 0.95f, 1f); p.sub = new Color(0.75f, 0.7f, 0.88f);
                    p.accent = new Color(1f, 0.75f, 0.35f); p.accent2 = new Color(0.45f, 0.5f, 1f);
                    p.btn = new Color(0.2f, 0.17f, 0.32f, 0.95f); p.btnHover = new Color(0.38f, 0.3f, 0.55f, 1f); p.btnText = new Color(0.97f, 0.95f, 1f);
                    p.title = new Color(1f, 0.95f, 0.85f); p.titleShadow = new Color(0.6f, 0.4f, 1f, 0.9f);
                    break;
                case 11: // кровавая луна
                    p.panel = new Color(0.07f, 0.01f, 0.02f, 0.9f); p.panelEdge = new Color(0.85f, 0.08f, 0.08f, 1f);
                    p.text = new Color(0.96f, 0.9f, 0.88f); p.sub = new Color(0.7f, 0.5f, 0.5f);
                    p.accent = new Color(0.9f, 0.1f, 0.1f); p.accent2 = new Color(0.5f, 0.55f, 0.75f);
                    p.btn = new Color(0.12f, 0.02f, 0.03f, 0.95f); p.btnHover = new Color(0.4f, 0.03f, 0.05f, 1f); p.btnText = new Color(0.96f, 0.9f, 0.88f);
                    p.title = new Color(0.04f, 0.0f, 0.01f); p.titleShadow = new Color(0.9f, 0.08f, 0.08f, 0.95f);
                    break;
                case 12: // пепелище
                    p.panel = new Color(0.1f, 0.08f, 0.07f, 0.9f); p.panelEdge = new Color(1f, 0.45f, 0.1f, 1f);
                    p.text = new Color(0.95f, 0.9f, 0.84f); p.sub = new Color(0.68f, 0.6f, 0.52f);
                    p.accent = new Color(1f, 0.45f, 0.1f); p.accent2 = new Color(0.55f, 0.6f, 0.7f);
                    p.btn = new Color(0.16f, 0.12f, 0.1f, 0.95f); p.btnHover = new Color(0.4f, 0.18f, 0.06f, 1f); p.btnText = new Color(0.95f, 0.9f, 0.84f);
                    p.title = new Color(0.08f, 0.06f, 0.05f); p.titleShadow = new Color(1f, 0.45f, 0.1f, 0.95f);
                    break;
                default: // киберпанк
                    p.panel = new Color(0.04f, 0.01f, 0.08f, 0.88f); p.panelEdge = new Color(0.1f, 0.95f, 1f, 1f);
                    p.text = new Color(0.9f, 0.97f, 1f); p.sub = new Color(0.65f, 0.6f, 0.85f);
                    p.accent = new Color(1f, 0.2f, 0.75f); p.accent2 = new Color(0.1f, 0.95f, 1f);
                    p.btn = new Color(0.1f, 0.02f, 0.16f, 0.95f); p.btnHover = new Color(0.3f, 0.04f, 0.32f, 1f); p.btnText = new Color(0.9f, 0.97f, 1f);
                    p.title = new Color(1f, 0.3f, 0.85f); p.titleShadow = new Color(0.1f, 0.95f, 1f, 0.9f);
                    break;
            }
            return p;
        }

        Transform NewLayer(string name, float factor)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            layers.Add(new Layer { t = go.transform, f = factor, basePos = Vector3.zero });
            return go.transform;
        }

        public void Build(int themeId, float w)
        {
            id = themeId; W = w;
            foreach (Transform c in transform) Destroy(c.gameObject);
            layers.Clear(); clouds.Clear(); flicker.Clear();
            glow = false; outline = false; silhouette = false; ink = Color.white; outlineCol = new Color(0.05f, 0.05f, 0.06f);
            defaultRed = new Color(0.82f, 0.08f, 0.08f);
            defaultBlue = new Color(0.1f, 0.25f, 0.85f);
            var rnd = new System.Random(12345 + themeId);
            float ext = 70f;

            switch (id)
            {
                case 0: BuildPaper(ext); break;
                case 1: BuildArena(ext, rnd); break;
                case 2: BuildField(ext, rnd); break;
                case 3: BuildCity(ext, rnd); break;
                case 5: BuildForest(ext, rnd); break;
                case 6: BuildGlow(ext, rnd); break;
                case 7: BuildDuel(ext); break;
                case 8: BuildClean(ext); break;
                case 9: BuildValley(ext, rnd); break;
                case 10: BuildSunset(ext, rnd); break;
                case 11: BuildBloodMoon(ext, rnd); break;
                case 12: BuildAshes(ext, rnd); break;
                default: BuildCyber(ext, rnd); break;
            }
        }

        void Ground(float ext, Color fill, Color line, float lineW)
        {
            groundCol = fill;
            var g = NewLayer("ground", 0f);
            Draw.Rect(g, new Rect(-ext, -30f, ext * 2, 30f), fill, -10);
            var l = Draw.Line(g, "groundLine", lineW, line, -3, true, 0);
            Draw.Set(l, new Vector2(-ext, -lineW * 0.5f + 0.02f), new Vector2(ext, -lineW * 0.5f + 0.02f));
        }

        void Walls(Color c, float width)
        {
            var g = NewLayer("walls", 0f);
            for (int s = -1; s <= 1; s += 2)
            {
                float x = s * (W + 0.2f + width * 0.5f);
                Draw.Rect(g, new Rect(x - width * 0.5f, -1f, width, 40f), c, -9);
            }
        }

        void BuildPaper(float ext)
        {
            outline = true; ink = new Color(0.08f, 0.08f, 0.1f);
            bg = new Color(0.95f, 0.94f, 0.9f);
            var grid = NewLayer("grid", 0f);
            var gc = new Color(0.9f, 0.55f, 0.55f, 0.45f);
            for (float x = -ext; x <= ext; x += 2.5f)
            {
                var l = Draw.Line(grid, "v", 0.035f, gc, -50, true, 0);
                Draw.Set(l, new Vector2(x, -2), new Vector2(x, 40));
            }
            for (float y = 0; y <= 40; y += 2.5f)
            {
                var l = Draw.Line(grid, "h", 0.035f, gc, -50, true, 0);
                Draw.Set(l, new Vector2(-ext, y), new Vector2(ext, y));
            }
            // поля тетради
            var m = Draw.Line(grid, "margin", 0.06f, new Color(0.85f, 0.2f, 0.2f, 0.6f), -49, true, 0);
            Draw.Set(m, new Vector2(-W - 1.2f, -2), new Vector2(-W - 1.2f, 40));
            // каракули на фоне
            var doodle = NewLayer("doodles", 0.2f);
            var sun = Draw.Line(doodle, "sun", 0.06f, new Color(0.3f, 0.3f, 0.35f, 0.5f), -45, true, 0);
            var pts = new List<Vector2>();
            for (int i = 0; i <= 30; i++) { float a = i / 30f * Mathf.PI * 2; pts.Add(new Vector2(9f + Mathf.Cos(a) * 1.2f, 11f + Mathf.Sin(a) * 1.2f)); }
            Draw.Set(sun, pts);
            for (int i = 0; i < 10; i++)
            {
                float a = i / 10f * Mathf.PI * 2;
                var r = Draw.Line(doodle, "ray", 0.05f, new Color(0.3f, 0.3f, 0.35f, 0.5f), -45, true, 0);
                Draw.Set(r, new Vector2(9f + Mathf.Cos(a) * 1.6f, 11f + Mathf.Sin(a) * 1.6f), new Vector2(9f + Mathf.Cos(a) * 2.3f, 11f + Mathf.Sin(a) * 2.3f));
            }
            Ground(ext, new Color(0.88f, 0.87f, 0.83f), new Color(0.08f, 0.08f, 0.08f), 0.16f);
            // штриховка карандашом
            var hatch = NewLayer("hatch", 0f);
            for (float x = -ext; x < ext; x += 0.6f)
            {
                var l = Draw.Line(hatch, "hatch", 0.025f, new Color(0.2f, 0.2f, 0.2f, 0.25f), -8, true, 0);
                Draw.Set(l, new Vector2(x, -0.25f), new Vector2(x - 0.8f, -1.6f));
            }
            Walls(new Color(0.15f, 0.15f, 0.15f, 0.12f), 0.6f);
        }

        void BuildArena(float ext, System.Random rnd)
        {
            bg = new Color(0.16f, 0.16f, 0.17f);
            var far = NewLayer("pillars", 0.5f);
            for (int i = -8; i <= 8; i++)
            {
                float x = i * 6f;
                Draw.Rect(far, new Rect(x - 0.7f, 0, 1.4f, 14f), new Color(0.2f, 0.2f, 0.21f), -40);
                Draw.Rect(far, new Rect(x - 1f, 13.5f, 2f, 0.6f), new Color(0.22f, 0.22f, 0.23f), -40);
            }
            // толпа-силуэты
            var crowd = NewLayer("crowd", 0.3f);
            for (int i = 0; i < 160; i++)
            {
                float x = -ext * 0.7f + i * 0.6f + (float)rnd.NextDouble() * 0.3f;
                float h = 0.9f + (float)rnd.NextDouble() * 0.6f;
                var head = Draw.Spr(crowd, "fan", Draw.Circle, new Color(0.12f, 0.12f, 0.13f), -38);
                head.transform.localPosition = new Vector3(x, 2.2f + h, 0);
                head.transform.localScale = Vector3.one * 0.45f;
                Draw.Rect(crowd, new Rect(x - 0.2f, 0, 0.4f, 2.2f + h - 0.2f), new Color(0.12f, 0.12f, 0.13f), -38);
            }
            // прожекторы
            var lights = NewLayer("lights", 0.1f);
            for (int i = -2; i <= 2; i++)
            {
                float x = i * 7f;
                Draw.Cone(lights, new Vector2(x, 18f), new Vector2(x - 5f, 0), new Vector2(x + 5f, 0), new Color(1, 1, 0.9f, 0.13f), new Color(1, 1, 0.9f, 0f), -30);
            }
            Ground(ext, new Color(0.11f, 0.11f, 0.12f), new Color(0.85f, 0.85f, 0.85f), 0.07f);
            Walls(new Color(0.1f, 0.1f, 0.11f, 1f), 0.8f);
        }

        void BuildField(float ext, System.Random rnd)
        {
            outline = true; outlineCol = new Color(0.1f, 0.12f, 0.08f);
            bg = new Color(0.55f, 0.78f, 0.97f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.3f, 0.55f, 0.92f), new Color(0.85f, 0.93f, 1f), -60);
            var sun = Draw.Spr(sky, "sunGlow", Draw.Soft, new Color(1f, 0.95f, 0.6f, 0.8f), -59);
            sun.transform.localPosition = new Vector3(8, 12, 0); sun.transform.localScale = Vector3.one * 7f;
            var sun2 = Draw.Spr(sky, "sun", Draw.Circle, new Color(1f, 0.97f, 0.75f), -58);
            sun2.transform.localPosition = new Vector3(8, 12, 0); sun2.transform.localScale = Vector3.one * 2.2f;
            var cl = NewLayer("clouds", 0.8f);
            for (int i = 0; i < 8; i++)
            {
                var c = new GameObject("cloud").transform;
                c.SetParent(cl, false);
                c.localPosition = new Vector3(-40 + i * 11 + (float)rnd.NextDouble() * 5, 9 + (float)rnd.NextDouble() * 6, 0);
                for (int k = 0; k < 5; k++)
                {
                    var p = Draw.Spr(c, "puff", Draw.Circle, new Color(1, 1, 1, 0.92f), -55);
                    p.transform.localPosition = new Vector3(k * 0.9f - 1.8f, Mathf.Sin(k * 1.3f) * 0.4f + (k == 2 ? 0.5f : 0), 0);
                    p.transform.localScale = Vector3.one * (1.4f + (float)rnd.NextDouble() * 0.9f);
                }
                clouds.Add(c);
            }
            Hills(NewLayer("hillsFar", 0.6f), new Color(0.45f, 0.68f, 0.4f), 5f, 3.5f, -52, rnd);
            Hills(NewLayer("hillsNear", 0.35f), new Color(0.35f, 0.6f, 0.3f), 3f, 2.5f, -50, rnd);
            // деревья
            var trees = NewLayer("trees", 0.35f);
            for (int i = 0; i < 14; i++)
            {
                float x = -45 + i * 7 + (float)rnd.NextDouble() * 3;
                Draw.Rect(trees, new Rect(x - 0.15f, 0, 0.3f, 2f), new Color(0.35f, 0.22f, 0.12f), -49);
                var crown = Draw.Spr(trees, "crown", Draw.Circle, new Color(0.22f, 0.48f, 0.2f), -48);
                crown.transform.localPosition = new Vector3(x, 2.4f, 0); crown.transform.localScale = Vector3.one * 1.8f;
            }
            Ground(ext, new Color(0.38f, 0.62f, 0.25f), new Color(0.22f, 0.42f, 0.14f), 0.14f);
            var grass = NewLayer("grass", 0f);
            for (float x = -ext; x < ext; x += 0.5f)
            {
                var g = Draw.Line(grass, "blade", 0.04f, new Color(0.25f, 0.5f, 0.17f), -2, true, 0);
                float h = 0.15f + (float)rnd.NextDouble() * 0.25f;
                Draw.Set(g, new Vector2(x, 0), new Vector2(x + (float)rnd.NextDouble() * 0.2f - 0.1f, h));
            }
            Walls(new Color(0.4f, 0.28f, 0.15f, 1f), 0.4f);
        }

        void Hills(Transform layer, Color c, float baseH, float amp, int order, System.Random rnd)
        {
            var pts = new List<Vector2>();
            float ph = (float)rnd.NextDouble() * 10;
            for (float x = -90; x <= 90; x += 2f)
                pts.Add(new Vector2(x, baseH + Mathf.Sin(x * 0.15f + ph) * amp * 0.5f + Mathf.Sin(x * 0.07f + ph * 2) * amp * 0.5f));
            // разбиваем на столбики-трапеции (выпуклые)
            for (int i = 0; i < pts.Count - 1; i++)
            {
                var poly = new[] { new Vector2(pts[i].x, -2), pts[i], pts[i + 1], new Vector2(pts[i + 1].x, -2) };
                Draw.Poly(layer, poly, c, order);
            }
        }

        void BuildCity(float ext, System.Random rnd)
        {
            outline = true; outlineCol = new Color(0.12f, 0.12f, 0.13f);
            bg = new Color(0.62f, 0.62f, 0.62f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.5f, 0.5f, 0.52f), new Color(0.78f, 0.77f, 0.76f), -60);
            Skyline(NewLayer("far", 0.7f), new Color(0.82f, 0.81f, 0.8f), 6f, 16f, -55, rnd, false);
            Skyline(NewLayer("near", 0.45f), new Color(0.7f, 0.7f, 0.71f), 3f, 10f, -52, rnd, false);
            Ground(ext, new Color(0.27f, 0.27f, 0.28f), new Color(0.2f, 0.2f, 0.2f), 0.1f);
            Walls(new Color(0.3f, 0.3f, 0.32f, 1f), 0.6f);
        }

        void Skyline(Transform layer, Color c, float minH, float maxH, int order, System.Random rnd, bool windows)
        {
            float x = -90;
            while (x < 90)
            {
                float w = 2f + (float)rnd.NextDouble() * 3.5f;
                float h = minH + (float)rnd.NextDouble() * (maxH - minH);
                Draw.Rect(layer, new Rect(x, -1, w, h + 1), c, order);
                if (rnd.NextDouble() < 0.25) Draw.Rect(layer, new Rect(x + w * 0.45f, h, 0.12f, 2f), c, order);
                if (windows)
                {
                    for (float wy = 1f; wy < h - 0.6f; wy += 0.9f)
                        for (float wx = x + 0.4f; wx < x + w - 0.4f; wx += 0.7f)
                        {
                            if (rnd.NextDouble() < 0.45) continue;
                            Color wc = rnd.NextDouble() < 0.5 ? new Color(1f, 0.2f, 0.8f, 0.85f) : new Color(0.1f, 0.9f, 1f, 0.85f);
                            if (rnd.NextDouble() < 0.3) wc = new Color(1f, 0.85f, 0.4f, 0.8f);
                            var sr = Draw.Rect(layer, new Rect(wx, wy, 0.3f, 0.4f), wc, order + 1);
                            if (rnd.NextDouble() < 0.08) flicker.Add(sr);
                        }
                }
                x += w + (float)rnd.NextDouble() * 0.6f;
            }
        }

        // Туманный лес: серые силуэты деревьев, чёрные бойцы со светящимися глазами
        void BuildForest(float ext, System.Random rnd)
        {
            silhouette = true; ink = new Color(0.08f, 0.08f, 0.08f);
            bg = new Color(0.86f, 0.86f, 0.86f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.72f, 0.72f, 0.73f), new Color(0.92f, 0.92f, 0.92f), -60);
            Trees(NewLayer("treesFar", 0.7f), new Color(0.78f, 0.78f, 0.79f), 9f, 2.2f, -56, rnd);
            var fog = NewLayer("fog", 0.6f);
            for (int i = 0; i < 12; i++)
            {
                var f = Draw.Spr(fog, "fog", Draw.Soft, new Color(1f, 1f, 1f, 0.5f), -54);
                f.transform.localPosition = new Vector3(-45 + i * 8 + (float)rnd.NextDouble() * 4, 1.5f + (float)rnd.NextDouble() * 2f, 0);
                f.transform.localScale = new Vector3(14f, 3.5f, 1);
                clouds.Add(f.transform);
            }
            Trees(NewLayer("treesNear", 0.4f), new Color(0.66f, 0.66f, 0.67f), 12f, 3.2f, -52, rnd);
            Ground(ext, new Color(0.55f, 0.55f, 0.56f), new Color(0.3f, 0.3f, 0.31f), 0.1f);
            var twigs = NewLayer("twigs", 0f);
            for (int i = 0; i < 18; i++)
            {
                float x = -ext * 0.5f + i * 5.3f + (float)rnd.NextDouble() * 2f;
                Branch(twigs, new Vector2(x, 0), 90f + (float)(rnd.NextDouble() * 30 - 15), 0.7f + (float)rnd.NextDouble() * 0.6f, 0.06f, new Color(0.08f, 0.08f, 0.08f), -3, rnd, 3);
            }
            Walls(new Color(0.4f, 0.4f, 0.41f, 1f), 0.5f);
        }

        void Trees(Transform layer, Color c, float h, float w, int order, System.Random rnd)
        {
            for (float x = -90; x < 90; x += 6f + (float)rnd.NextDouble() * 5f)
            {
                float th = h * (0.7f + (float)rnd.NextDouble() * 0.6f);
                var trunk = Draw.Line(layer, "trunk", 1f, c, order, true, 2);
                Draw.Set(trunk, new List<Vector2> { new Vector2(x, -1), new Vector2(x + (float)(rnd.NextDouble() - 0.5), th * 0.5f), new Vector2(x + (float)(rnd.NextDouble() - 0.5) * 2f, th) });
                Draw.Taper(trunk, w * 0.35f, w * 0.08f);
                for (int b = 0; b < 4; b++)
                    Branch(layer, new Vector2(x, th * (0.45f + b * 0.14f)), 90f + (b % 2 == 0 ? 40f : -40f) + (float)(rnd.NextDouble() * 20 - 10), th * 0.3f, w * 0.12f, c, order, rnd, 2);
            }
        }

        void Branch(Transform layer, Vector2 at, float ang, float len, float width, Color c, int order, System.Random rnd, int depth)
        {
            if (depth <= 0 || len < 0.1f) return;
            Vector2 end = at + new Vector2(Mathf.Cos(ang * Mathf.Deg2Rad), Mathf.Sin(ang * Mathf.Deg2Rad)) * len;
            var l = Draw.Line(layer, "branch", 1f, c, order, true, 0);
            Draw.Set(l, at, end);
            Draw.Taper(l, width, width * 0.4f);
            Branch(layer, end, ang + 25f + (float)rnd.NextDouble() * 15f, len * 0.6f, width * 0.6f, c, order, rnd, depth - 1);
            Branch(layer, end, ang - 25f - (float)rnd.NextDouble() * 15f, len * 0.55f, width * 0.6f, c, order, rnd, depth - 1);
        }

        // Сияние: мягкий фиолетовый градиент, вспышка света за бойцами, сцена-диск
        void BuildGlow(float ext, System.Random rnd)
        {
            bg = new Color(0.3f, 0.28f, 0.42f);
            ink = new Color(1f, 0.95f, 0.85f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.2f, 0.18f, 0.32f), new Color(0.55f, 0.53f, 0.68f), -60);
            var lightL = NewLayer("light", 0.85f);
            var halo = Draw.Spr(lightL, "halo", Draw.Soft, new Color(1f, 0.97f, 0.9f, 0.75f), -58);
            halo.transform.localPosition = new Vector3(0, 4.5f, 0); halo.transform.localScale = Vector3.one * 16f;
            var core = Draw.Spr(lightL, "core", Draw.Soft, new Color(1f, 1f, 1f, 0.9f), -57);
            core.transform.localPosition = new Vector3(0, 4.5f, 0); core.transform.localScale = Vector3.one * 4f;
            var flareH = Draw.Spr(lightL, "flareH", Draw.Soft, new Color(1f, 0.9f, 0.75f, 0.7f), -56);
            flareH.transform.localPosition = new Vector3(0, 4.5f, 0); flareH.transform.localScale = new Vector3(40f, 0.35f, 1f);
            var flareV = Draw.Spr(lightL, "flareV", Draw.Soft, new Color(1f, 0.9f, 0.75f, 0.5f), -56);
            flareV.transform.localPosition = new Vector3(0, 4.5f, 0); flareV.transform.localScale = new Vector3(0.3f, 10f, 1f);
            Ground(ext, new Color(0.24f, 0.22f, 0.32f), new Color(0.75f, 0.7f, 0.9f), 0.05f);
            var stage = NewLayer("stage", 0f);
            var disk = Draw.Spr(stage, "disk", Draw.Soft, new Color(0.85f, 0.8f, 1f, 0.35f), -9);
            disk.transform.localPosition = new Vector3(0, -0.4f, 0); disk.transform.localScale = new Vector3(36f, 2.2f, 1f);
            Walls(new Color(0.2f, 0.18f, 0.28f, 1f), 0.5f);
        }

        // Дуэль: чистый тёмный фон и тонкая линия пола — как в классических стикмен-анимациях
        void BuildDuel(float ext)
        {
            bg = new Color(0.17f, 0.17f, 0.18f);
            defaultRed = new Color(0.86f, 0.39f, 0.36f);
            defaultBlue = new Color(0.42f, 0.56f, 0.86f);
            var g = NewLayer("glowFloor", 0.2f);
            var s = Draw.Spr(g, "spot", Draw.Soft, new Color(1f, 1f, 1f, 0.05f), -50);
            s.transform.localPosition = new Vector3(0, 3, 0); s.transform.localScale = new Vector3(30f, 14f, 1f);
            Ground(ext, new Color(0.15f, 0.15f, 0.16f), new Color(0.05f, 0.05f, 0.05f), 0.08f);
            Walls(new Color(0.13f, 0.13f, 0.14f, 1f), 0.4f);
        }

        // Чистый лист: белый фон и мягкий пол — классический вид рисованного стикмена
        void BuildClean(float ext)
        {
            bg = new Color(0.985f, 0.985f, 0.98f);
            ink = new Color(0.08f, 0.08f, 0.09f);
            defaultRed = new Color(0.93f, 0.93f, 0.93f);
            defaultBlue = new Color(0.93f, 0.93f, 0.93f);
            Ground(ext, new Color(0.96f, 0.96f, 0.955f), new Color(0.82f, 0.82f, 0.83f), 0.03f);
            Walls(new Color(0.9f, 0.9f, 0.9f, 0.6f), 0.3f);
        }

        // скалы: колонки-трапеции с рваным верхом и светлой кромкой
        void Cliffs(Transform layer, Color body, Color top, float baseH, float var, int order, System.Random rnd, float from, float to)
        {
            var tops = new List<Vector2>();
            for (float x = from; x <= to; x += 1.5f)
            {
                float h = baseH + (float)rnd.NextDouble() * var + Mathf.Sin(x * 0.11f) * var * 0.6f;
                tops.Add(new Vector2(x, h));
            }
            for (int i = 0; i < tops.Count - 1; i++)
                Draw.Poly(layer, new[] { new Vector2(tops[i].x, -2), tops[i], tops[i + 1], new Vector2(tops[i + 1].x, -2) }, body, order);
            var edge = Draw.Line(layer, "edge", 0.25f, top, order + 1, true, 1);
            Draw.Set(edge, tops);
            // вертикальные трещины-штрихи
            for (int i = 0; i < tops.Count; i += 2)
            {
                var l = Draw.Line(layer, "crack", 0.08f, Draw.Mul(body, 0.88f), order + 1, true, 0);
                Draw.Set(l, new Vector2(tops[i].x + 0.3f, tops[i].y - 0.4f), new Vector2(tops[i].x + 0.1f, tops[i].y * 0.3f));
            }
        }

        // Долина: голубое небо, облака, сиреневые скалы, зелёные холмы и трава — живописный фон
        void BuildValley(float ext, System.Random rnd)
        {
            bg = new Color(0.62f, 0.8f, 0.97f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.45f, 0.68f, 0.95f), new Color(0.88f, 0.94f, 1f), -60);
            var cl = NewLayer("clouds", 0.85f);
            for (int i = 0; i < 9; i++)
            {
                var c = Draw.Spr(cl, "cloud", Draw.Soft, new Color(1f, 1f, 1f, 0.85f), -58);
                c.transform.localPosition = new Vector3(-40 + i * 10 + (float)rnd.NextDouble() * 5, 10 + (float)rnd.NextDouble() * 5, 0);
                c.transform.localScale = new Vector3(7f + (float)rnd.NextDouble() * 4f, 1.1f, 1f);
                clouds.Add(c.transform);
            }
            Cliffs(NewLayer("cliffsFar", 0.7f), new Color(0.66f, 0.63f, 0.75f), new Color(0.8f, 0.78f, 0.86f), 7f, 3f, -55, rnd, -90, 90);
            Cliffs(NewLayer("cliffsNear", 0.5f), new Color(0.58f, 0.54f, 0.66f), new Color(0.55f, 0.75f, 0.45f), 4.5f, 3.5f, -53, rnd, -90, 90);
            Hills(NewLayer("hills", 0.3f), new Color(0.45f, 0.7f, 0.38f), 1.5f, 1.2f, -50, rnd);
            var wall = NewLayer("wall", 0.15f);
            for (float x = -60; x < 60; x += 2.2f)
                Draw.Rect(wall, new Rect(x, 0f, 2.1f, 1.0f + (float)rnd.NextDouble() * 0.15f), new Color(0.62f, 0.58f, 0.5f), -48);
            var wl = Draw.Line(wall, "wallTop", 0.12f, new Color(0.45f, 0.62f, 0.35f), -47, true, 0);
            Draw.Set(wl, new Vector2(-60, 1.1f), new Vector2(60, 1.1f));
            Ground(ext, new Color(0.42f, 0.67f, 0.34f), new Color(0.33f, 0.55f, 0.27f), 0.1f);
            var grass = NewLayer("grass", 0f);
            for (float x = -ext; x < ext; x += 0.45f)
            {
                var g = Draw.Line(grass, "blade", 0.05f, new Color(0.35f, 0.6f, 0.28f), -2, true, 0);
                Draw.Set(g, new Vector2(x, 0), new Vector2(x + (float)rnd.NextDouble() * 0.25f - 0.12f, 0.15f + (float)rnd.NextDouble() * 0.3f));
            }
            Walls(new Color(0.6f, 0.55f, 0.65f, 1f), 0.5f);
        }

        // Закат: оранжево-красное небо, руины города, столбы дыма — как в «One vs Many»
        void BuildSunset(float ext, System.Random rnd)
        {
            bg = new Color(0.9f, 0.42f, 0.25f);
            ink = new Color(1f, 0.9f, 0.75f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.75f, 0.25f, 0.18f), new Color(0.98f, 0.55f, 0.3f), -60);
            var sun = Draw.Spr(sky, "sunGlow", Draw.Soft, new Color(1f, 0.85f, 0.5f, 0.7f), -59);
            sun.transform.localPosition = new Vector3(-2, 3, 0); sun.transform.localScale = new Vector3(26f, 9f, 1f);
            Skyline(NewLayer("ruinsFar", 0.7f), new Color(0.8f, 0.38f, 0.25f), 3f, 9f, -55, rnd, false);
            Skyline(NewLayer("ruinsNear", 0.45f), new Color(0.65f, 0.27f, 0.2f), 1.5f, 5f, -52, rnd, false);
            var smoke = NewLayer("smoke", 0.5f);
            for (int i = 0; i < 10; i++)
            {
                float x = -40 + i * 8 + (float)rnd.NextDouble() * 4;
                var sm = Draw.Line(smoke, "smoke", 1f, new Color(0.35f, 0.08f, 0.06f, 0.45f), -51, true, 2);
                Draw.Set(sm, new List<Vector2> { new Vector2(x, 2), new Vector2(x + 0.5f, 7), new Vector2(x - 0.3f, 13) });
                Draw.Taper(sm, 0.6f, 0.15f);
            }
            Ground(ext, new Color(0.62f, 0.26f, 0.19f), new Color(0.45f, 0.15f, 0.12f), 0.08f);
            var debris = NewLayer("debris", 0f);
            for (int i = 0; i < 26; i++)
            {
                var d = Draw.Spr(debris, "rubble", Draw.Soft, new Color(0.4f, 0.12f, 0.1f, 0.6f), -9);
                d.transform.localPosition = new Vector3(-ext * 0.6f + i * 3.7f + (float)rnd.NextDouble() * 2f, -0.4f - (float)rnd.NextDouble(), 0);
                d.transform.localScale = new Vector3(1.6f + (float)rnd.NextDouble() * 2f, 0.35f, 1f);
            }
            Walls(new Color(0.45f, 0.16f, 0.12f, 1f), 0.5f);
        }

        // Кровавая луна: багровое небо, огромная луна, чёрные мёртвые деревья, виселицы и туман
        void BuildBloodMoon(float ext, System.Random rnd)
        {
            bg = new Color(0.4f, 0.04f, 0.05f);
            ink = new Color(1f, 0.85f, 0.8f);
            defaultRed = new Color(0.05f, 0.04f, 0.05f);
            defaultBlue = new Color(0.25f, 0.28f, 0.38f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.62f, 0.08f, 0.07f), new Color(0.12f, 0.01f, 0.03f), -60);
            var moonL = NewLayer("moon", 0.9f);
            var halo = Draw.Spr(moonL, "halo", Draw.Soft, new Color(1f, 0.3f, 0.2f, 0.55f), -59);
            halo.transform.localPosition = new Vector3(4f, 9f, 0); halo.transform.localScale = Vector3.one * 20f;
            var moon = Draw.Spr(moonL, "moon", Draw.Circle, new Color(0.95f, 0.32f, 0.22f), -58);
            moon.transform.localPosition = new Vector3(4f, 9f, 0); moon.transform.localScale = Vector3.one * 7.5f;
            for (int i = 0; i < 5; i++)
            {
                var cr = Draw.Spr(moonL, "crater", Draw.Circle, new Color(0.8f, 0.2f, 0.15f, 0.6f), -57);
                cr.transform.localPosition = new Vector3(4f + (float)rnd.NextDouble() * 4f - 2f, 9f + (float)rnd.NextDouble() * 4f - 2f, 0);
                cr.transform.localScale = Vector3.one * (0.6f + (float)rnd.NextDouble() * 1.1f);
            }
            var cl = NewLayer("clouds", 0.85f);
            for (int i = 0; i < 7; i++)
            {
                var c = Draw.Spr(cl, "cloud", Draw.Soft, new Color(0.08f, 0.0f, 0.02f, 0.7f), -56);
                c.transform.localPosition = new Vector3(-40 + i * 12 + (float)rnd.NextDouble() * 5, 8 + (float)rnd.NextDouble() * 6, 0);
                c.transform.localScale = new Vector3(9f + (float)rnd.NextDouble() * 5f, 1.2f, 1f);
                clouds.Add(c.transform);
            }
            Hills(NewLayer("hillsFar", 0.6f), new Color(0.2f, 0.02f, 0.04f), 3f, 2f, -54, rnd);
            var trees = NewLayer("trees", 0.35f);
            Color tc = new Color(0.03f, 0.0f, 0.01f);
            for (int i = 0; i < 14; i++)
            {
                float x = -55 + i * 8f + (float)rnd.NextDouble() * 4f;
                float h = 4f + (float)rnd.NextDouble() * 4f;
                var tr = Draw.Line(trees, "trunk", 1f, tc, -50, true, 1);
                Draw.Set(tr, new List<Vector2> { new Vector2(x, -1), new Vector2(x + 0.3f, h * 0.5f), new Vector2(x - 0.2f, h) });
                Draw.Taper(tr, 0.6f, 0.08f);
                for (int b = 0; b < 5; b++)
                {
                    float y0 = h * (0.4f + b * 0.12f), dir = b % 2 == 0 ? 1 : -1;
                    var br = Draw.Line(trees, "branch", 1f, tc, -50, true, 0);
                    Draw.Set(br, new List<Vector2> { new Vector2(x, y0), new Vector2(x + dir * 1.2f, y0 + 0.9f), new Vector2(x + dir * 2.2f, y0 + 0.7f + (float)rnd.NextDouble() * 0.8f) });
                    Draw.Taper(br, 0.2f, 0.01f);
                }
                if (i % 4 == 1)
                {
                    // висящая цепь с клеткой
                    float bx = x + 1.6f, by = h * 0.62f;
                    var ch = Draw.Line(trees, "chain", 0.05f, tc, -50, true, 0);
                    Draw.Set(ch, new Vector2(bx, by + 0.5f), new Vector2(bx, by - 0.9f));
                    Draw.Rect(trees, new Rect(bx - 0.35f, by - 1.8f, 0.7f, 0.9f), tc, -50);
                }
            }
            var mist = NewLayer("mist", 0.2f);
            for (int i = 0; i < 10; i++)
            {
                var m = Draw.Spr(mist, "mist", Draw.Soft, new Color(0.5f, 0.05f, 0.06f, 0.4f), -49);
                m.transform.localPosition = new Vector3(-50 + i * 11f, 0.8f, 0); m.transform.localScale = new Vector3(16f, 2.6f, 1f);
                clouds.Add(m.transform);
            }
            Ground(ext, new Color(0.04f, 0.0f, 0.01f), new Color(0.3f, 0.02f, 0.03f), 0.08f);
            var graves = NewLayer("graves", 0f);
            for (int i = 0; i < 16; i++)
            {
                float x = -ext * 0.5f + i * 4.6f + (float)rnd.NextDouble() * 2f;
                if (Mathf.Abs(x) > W) continue;
                var cr = Draw.Line(graves, "cross", 0.12f, new Color(0.1f, 0.01f, 0.02f), -8, true, 0);
                Draw.Set(cr, new Vector2(x, 0), new Vector2(x + 0.05f, 0.9f));
                var cb = Draw.Line(graves, "crossBar", 0.1f, new Color(0.1f, 0.01f, 0.02f), -8, true, 0);
                Draw.Set(cb, new Vector2(x - 0.3f, 0.62f), new Vector2(x + 0.35f, 0.66f));
            }
            Walls(new Color(0.15f, 0.01f, 0.03f, 1f), 0.5f);
        }

        // Пепелище: горящий город, дым до неба, пепел и искры
        void BuildAshes(float ext, System.Random rnd)
        {
            bg = new Color(0.3f, 0.25f, 0.23f);
            ink = new Color(1f, 0.85f, 0.6f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.62f, 0.32f, 0.16f), new Color(0.16f, 0.14f, 0.15f), -60);
            var glowL = NewLayer("fireGlow", 0.8f);
            for (int i = 0; i < 6; i++)
            {
                var g = Draw.Spr(glowL, "fireGlow", Draw.Soft, new Color(1f, 0.45f, 0.1f, 0.5f), -58);
                g.transform.localPosition = new Vector3(-40 + i * 16f + (float)rnd.NextDouble() * 6f, 1.5f, 0); g.transform.localScale = new Vector3(14f, 6f, 1f);
                flicker.Add(g);
            }
            var smoke = NewLayer("smoke", 0.7f);
            for (int i = 0; i < 12; i++)
            {
                float x = -50 + i * 9 + (float)rnd.NextDouble() * 4;
                var sm = Draw.Line(smoke, "smoke", 1f, new Color(0.1f, 0.08f, 0.08f, 0.6f), -57, true, 3);
                Draw.Set(sm, new List<Vector2> { new Vector2(x, 2), new Vector2(x + 1f, 8), new Vector2(x - 1f, 14), new Vector2(x + 2f, 22) });
                Draw.Taper(sm, 1.2f, 4f);
            }
            Skyline(NewLayer("ruinsFar", 0.6f), new Color(0.2f, 0.15f, 0.14f), 2.5f, 8f, -55, rnd, false);
            Skyline(NewLayer("ruinsNear", 0.4f), new Color(0.09f, 0.07f, 0.07f), 1.2f, 4.5f, -52, rnd, false);
            Ground(ext, new Color(0.12f, 0.1f, 0.1f), new Color(0.35f, 0.18f, 0.08f), 0.08f);
            var coals = NewLayer("coals", 0f);
            for (int i = 0; i < 40; i++)
            {
                var c = Draw.Spr(coals, "coal", Draw.Soft, new Color(1f, 0.35f, 0.05f, 0.55f), -8);
                c.transform.localPosition = new Vector3(-ext * 0.5f + i * 1.8f + (float)rnd.NextDouble(), -0.15f - (float)rnd.NextDouble() * 0.4f, 0);
                c.transform.localScale = new Vector3(0.7f + (float)rnd.NextDouble(), 0.25f, 1f);
                if (i % 3 == 0) flicker.Add(c);
            }
            Walls(new Color(0.15f, 0.12f, 0.11f, 1f), 0.5f);
        }

        void BuildCyber(float ext, System.Random rnd)
        {
            glow = true;
            bg = new Color(0.04f, 0.01f, 0.08f);
            defaultRed = new Color(1f, 0.15f, 0.55f);
            defaultBlue = new Color(0.1f, 0.85f, 1f);
            var sky = NewLayer("sky", 0.95f);
            Draw.Gradient(sky, new Rect(-80, -10, 160, 60), new Color(0.03f, 0.01f, 0.08f), new Color(0.35f, 0.05f, 0.35f), -60);
            // ретро-солнце
            var sunG = Draw.Spr(sky, "sunGlow", Draw.Soft, new Color(1f, 0.3f, 0.6f, 0.6f), -59);
            sunG.transform.localPosition = new Vector3(0, 9, 0); sunG.transform.localScale = Vector3.one * 14f;
            var sun = Draw.Spr(sky, "sun", Draw.Circle, new Color(1f, 0.55f, 0.3f), -58);
            sun.transform.localPosition = new Vector3(0, 9, 0); sun.transform.localScale = Vector3.one * 7f;
            for (int i = 0; i < 6; i++) Draw.Rect(sky, new Rect(-4, 6f + i * 0.55f, 8, 0.12f + i * 0.03f), new Color(0.2f, 0.03f, 0.25f), -57);
            Skyline(NewLayer("far", 0.7f), new Color(0.09f, 0.03f, 0.16f), 6f, 18f, -55, rnd, true);
            Skyline(NewLayer("near", 0.45f), new Color(0.05f, 0.02f, 0.1f), 3f, 11f, -52, rnd, true);
            // неоновые вывески
            var signs = NewLayer("signs", 0.45f);
            for (int i = 0; i < 9; i++)
            {
                float x = -40 + i * 10 + (float)rnd.NextDouble() * 4;
                float y = 4 + (float)rnd.NextDouble() * 4;
                Color c = i % 2 == 0 ? new Color(1f, 0.2f, 0.8f) : new Color(0.1f, 0.95f, 1f);
                var s = Draw.Line(signs, "sign", 0.08f, c, -50, true, 2);
                s.loop = true;
                Draw.Set(s, new List<Vector2> { new Vector2(x, y), new Vector2(x + 2.2f, y), new Vector2(x + 2.2f, y + 0.9f), new Vector2(x, y + 0.9f) });
                var g = Draw.Spr(signs, "glow", Draw.Soft, Draw.A(c, 0.35f), -51);
                g.transform.localPosition = new Vector3(x + 1.1f, y + 0.45f, 0); g.transform.localScale = new Vector3(4.5f, 2.5f, 1);
                flicker.Add(g);
            }
            Ground(ext, new Color(0.05f, 0.02f, 0.09f), new Color(0.1f, 0.95f, 1f), 0.08f);
            var gl = NewLayer("groundGlow", 0f);
            var gg = Draw.Line(gl, "glowLine", 0.5f, new Color(0.1f, 0.95f, 1f, 0.18f), -4, true, 0);
            Draw.Set(gg, new Vector2(-ext, 0), new Vector2(ext, 0));
            // перспективная сетка пола
            for (float x = -ext; x <= ext; x += 2f)
            {
                var l = Draw.Line(gl, "grid", 0.03f, new Color(1f, 0.2f, 0.8f, 0.35f), -7, true, 0);
                Draw.Set(l, new Vector2(x, -0.05f), new Vector2(x * 1.6f, -6f));
            }
            for (int i = 1; i < 6; i++)
            {
                float y = -Mathf.Pow(i, 1.4f) * 0.5f;
                var l = Draw.Line(gl, "gridH", 0.03f, new Color(1f, 0.2f, 0.8f, 0.35f), -7, true, 0);
                Draw.Set(l, new Vector2(-ext, y), new Vector2(ext, y));
            }
            Walls(new Color(0.1f, 0.95f, 1f, 0.25f), 0.25f);
        }

        // 3D-переход: слои фона уходят в глубину (с компенсацией масштаба), чтобы появился настоящий параллакс
        public void SetDepth(bool on, Vector2 focus, float dist)
        {
            depthOn = on;
            foreach (var l in layers)
            {
                if (!on || l.f <= 0.001f) { l.t.localScale = Vector3.one; var p0 = l.t.position; p0.z = 0; l.t.position = p0; continue; }
                float z = l.f * 55f;
                float k = (dist + z) / dist;
                Vector3 p = l.t.position;
                Vector3 c = new Vector3(focus.x, focus.y, 0);
                Vector3 np = c + (new Vector3(p.x, p.y, 0) - c) * k;
                np.z = z;
                l.t.position = np;
                l.t.localScale = Vector3.one * k;
            }
        }

        public void Follow(Vector3 cam)
        {
            if (depthOn) return;
            foreach (var l in layers)
                l.t.position = new Vector3(cam.x * l.f, cam.y * l.f, 0) + l.basePos;
        }

        public void Tick(float dt, Particles fx, Vector3 cam, float halfW, float halfH)
        {
            time += dt;
            foreach (var c in clouds)
            {
                var p = c.localPosition;
                p.x += dt * 0.4f;
                if (p.x > 50) p.x = -50;
                c.localPosition = p;
            }
            foreach (var f in flicker)
            {
                var col = f.color;
                col.a = (Mathf.PerlinNoise(f.GetInstanceID() * 0.37f, time * 3f) > 0.25f) ? Mathf.Min(0.85f, col.a + dt * 4) : 0.05f;
                f.color = col;
            }
            if ((id == 11 || id == 12) && fx != null && dt > 0)
            {
                // 11: падающий багровый пепел; 12: искры поднимаются от углей, сверху сыплется серый пепел
                if (Random.value < dt * (id == 12 ? 22f : 10f))
                {
                    var pos = new Vector2(cam.x + Random.Range(-halfW, halfW) * 1.1f, id == 12 ? 0.1f : cam.y + halfH + 0.5f);
                    if (id == 12) fx.Emit(pos, new Vector2(Random.Range(-0.6f, 0.6f), Random.Range(1.5f, 3.5f)), new Color(1f, Random.Range(0.4f, 0.7f), 0.1f, 1f), Random.Range(0.04f, 0.08f), Random.Range(1.5f, 3f), 0.3f, false, 0.4f, true, 1, 1, true);
                    else fx.Emit(pos, new Vector2(Random.Range(-0.8f, 0.2f), -Random.Range(0.5f, 1.2f)), new Color(0.45f, 0.03f, 0.05f, 0.8f), Random.Range(0.05f, 0.1f), 6f, 0f, false, 0.1f, true);
                }
                if (id == 12 && Random.value < dt * 8f)
                    fx.Emit(new Vector2(cam.x + Random.Range(-halfW, halfW) * 1.1f, cam.y + halfH + 0.5f), new Vector2(Random.Range(-0.5f, 0.5f), -Random.Range(0.4f, 0.9f)), new Color(0.6f, 0.58f, 0.56f, 0.7f), Random.Range(0.04f, 0.09f), 7f, 0f, false, 0.1f, true);
            }
            else if (Game.I != null && Game.I.S.grim && fx != null && dt > 0 && id != 4 && Random.value < dt * 5f)
            {
                // мрачная атмосфера: в воздухе медленно оседает пепел
                var pos = new Vector2(cam.x + Random.Range(-halfW, halfW) * 1.1f, cam.y + halfH + 0.5f);
                fx.Emit(pos, new Vector2(Random.Range(-0.6f, 0.3f), -Random.Range(0.4f, 0.9f)), new Color(0.15f, 0.12f, 0.12f, 0.55f), Random.Range(0.035f, 0.07f), 8f, 0f, false, 0.1f, true);
            }
            if (id == 4 && fx != null && dt > 0)
            {
                // неоновый дождь
                int n = Mathf.Max(1, (int)(dt * 120));
                for (int i = 0; i < n; i++)
                {
                    var pos = new Vector2(cam.x + Random.Range(-halfW, halfW) * 1.2f, cam.y + halfH + 1f);
                    fx.Emit(pos, new Vector2(-1.5f, -22f), new Color(0.6f, 0.8f, 1f, 0.35f), 0.03f, 1.2f, 0f, false, 0f, false, 1f, 12f);
                }
            }
        }
    }
}
