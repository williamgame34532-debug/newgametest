using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Зона-19 — крупнейший объект Фонда. Наземная часть — огороженный комплекс:
// в центре КПП «Ворота A» (постройки из SCP - Containment Breach, CC BY-SA 3.0) — выход из подземных секторов,
// вокруг — административный корпус (входная зона), наземный блок лёгкого содержания, портал тяжёлой зоны,
// электростанция, казармы охраны, гараж и склады; по периметру — бетонная стена, вышки, КПП на дорогах.
public static partial class MapGen
{
    public const float SiteX = 165f, SiteZ = 128f;   // половина размеров периметра
    public const float SiteY = 0.4f;                  // отметка площадки комплекса
    static readonly List<Rect> siteRects = new List<Rect>();
    static Material wallWhite, wallGrey, roofMat, glassDark, hazard, metalDark, asphalt;

    static bool InSite(float x, float z) => mapKind == 0 && Mathf.Abs(x) < SiteX + 4f && Mathf.Abs(z) < SiteZ + 4f;

    // Насколько точка выровнена под комплекс (1 — внутри периметра)
    static float SiteFlat(float x, float z)
    {
        if (mapKind != 0) return 0f;
        float e = Mathf.Max(Mathf.Abs(x) - SiteX, Mathf.Abs(z) - SiteZ);
        return 1f - Mathf.SmoothStep(0f, 1f, (e - 6f) / 30f);
    }

    static bool SiteBlocked(Vector3 p, float r)
    {
        foreach (var rc in siteRects)
            if (p.x > rc.xMin - r && p.x < rc.xMax + r && p.z > rc.yMin - r && p.z < rc.yMax + r) return true;
        return false;
    }

    static void Reserve(float cx, float cz, float w, float d) { siteRects.Add(new Rect(cx - w / 2, cz - d / 2, w, d)); }

    static void SiteMaterials()
    {
        wallWhite = Mats.Tri(TexOr("cb_whitewall", Mats.ConcreteTex(new Color(0.75f, 0.74f, 0.7f), 11)), new Color(0.92f, 0.91f, 0.88f), 2.5f, 0.12f, 0.5f);
        wallGrey = Mats.Tri(Mats.ConcreteTex(new Color(0.52f, 0.52f, 0.5f), 13), Color.white, 3f, 0.12f, 0.55f);
        roofMat = Mats.Tri(TexOr("cb_concretefloor", Mats.ConcreteTex(new Color(0.38f, 0.38f, 0.37f), 17)), new Color(0.7f, 0.7f, 0.68f), 4f, 0.1f, 0.5f);
        metalDark = Mats.Tri(TexOr("cb_metalpanels2", Mats.ConcreteTex(new Color(0.3f, 0.32f, 0.33f), 19)), new Color(0.75f, 0.78f, 0.8f), 2f, 0.35f, 0.3f, 0.4f);
        asphalt = Mats.Tri(Mats.ConcreteTex(new Color(0.2f, 0.2f, 0.19f), 23), Color.white, 6f, 0.08f, 0.6f);
        glassDark = Mats.Get(new Color(0.08f, 0.1f, 0.12f), 0.92f, 0.1f);
        hazard = Mats.Textured(Mats.MakeTex(64, (x, y) => Mathf.Repeat((x + y) * 4f, 1f) < 0.5f ? new Color(0.9f, 0.72f, 0.1f) : new Color(0.08f, 0.08f, 0.08f)), Color.white, Vector2.one, 0.3f);
        foreach (var m in new[] { wallWhite, wallGrey, roofMat, metalDark, asphalt }) m.SetFloat("_Base", SiteY);
    }

    static Texture2D TexOr(string res, Texture2D fallback)
    {
        var t = Resources.Load<Texture2D>("Models/" + res);
        return t != null ? t : fallback;
    }

    // ---------------- сборка ----------------
    static void BuildSite19()
    {
        siteRects.Clear();
        SiteMaterials();
        var root = new GameObject("Site19").transform;
        root.SetParent(Root.transform);
        float y = SiteY;

        GateA(root, y);
        // корпуса
        Building(root, "АДМИНИСТРАТИВНЫЙ КОРПУС · ВХОДНАЯ ЗОНА", new Vector3(108, y, 4), 50, 22, 3, 0f, wallWhite, true);
        Building(root, "БЛОК ЛЁГКОГО СОДЕРЖАНИЯ · СЕКТОР 1", new Vector3(-112, y, -14), 42, 32, 2, 0f, wallGrey, false);
        HeavyPortal(root, new Vector3(-62, y, 92), 0f);
        PowerPlant(root, new Vector3(104, y, 88));
        Building(root, "КАЗАРМЫ ОХРАНЫ", new Vector3(102, y, -78), 42, 12, 2, 0f, wallWhite, true);
        Building(root, "МЕДИЦИНСКИЙ БЛОК", new Vector3(102, y, -104), 30, 12, 1, 0f, wallWhite, true);
        Hangar(root, new Vector3(-104, y, -86), 34, 24);
        Building(root, "ЛАБОРАТОРНЫЙ КОРПУС · СЕКТОР 3", new Vector3(-122, y, 62), 28, 30, 2, 90f, wallWhite, true);
        WaterTower(root, new Vector3(-58, y, -104));
        RadioMast(root, new Vector3(64, y, 112));
        Parking(root, new Vector3(84, y, -38), 26, 14);
        Perimeter(root, y);
        SiteRoads(y);
        // освещение двора
        foreach (var p in new[] { new Vector3(-60, 0, -40), new Vector3(60, 0, -60), new Vector3(-60, 0, 40), new Vector3(60, 0, 50), new Vector3(0, 0, -70), new Vector3(0, 0, 70), new Vector3(-140, 0, -50), new Vector3(140, 0, 40) })
            if (!SiteBlocked(p, 1f)) LightPole(OnGround(p.x, p.z), root);
    }

    // ---------------- Ворота A (из SCP:CB) ----------------
    static void GateA(Transform root, float y)
    {
        var mx = ModelX.Load("cb_gatea");
        var go = new GameObject("GateA"); go.transform.SetParent(root); go.transform.position = new Vector3(0, y, 0);
        if (mx != null)
        {
            foreach (var p in mx.parts)
            {
                var part = mx.Spawn(p.name, go.transform, Color.white, Vector3.zero);
                if (part == null) continue;
                bool glass = mx.matColor[p.mat].a < 0.99f;
                if (!glass)
                {
                    part.AddComponent<MeshCollider>().sharedMesh = p.mesh;
                    part.AddComponent<Surface>().color = new Color(0.55f, 0.55f, 0.53f);
                }
                part.GetComponent<MeshRenderer>().shadowCastingMode = glass ? ShadowCastingMode.Off : ShadowCastingMode.TwoSided;
            }
            Reserve(0, 0, 90, 62);
        }
        else
        {
            // запасной вариант: простая коробка КПП
            Solid(new Vector3(0, y + 3f, 0), new Vector3(30, 6, 20), wallGrey, Quaternion.identity, new Color(0.5f, 0.5f, 0.5f), false, go.transform);
            Reserve(0, 0, 32, 22);
        }
        if (Night)
            foreach (var p in new[] { new Vector3(-20, 6, 0), new Vector3(20, 6, 0), new Vector3(0, 6, 18), new Vector3(0, 6, -18) })
                Lamp(go.transform.position + p, new Color(1f, 0.92f, 0.75f), 22f, 1.6f, go.transform);
    }

    // ---------------- типовой корпус ----------------
    // Первый этаж — проходной (двери по фасадам, коридор, комнаты), выше — этажи с ленточным остеклением, кровля с парапетом
    static void Building(Transform root, string sign, Vector3 c, float w, float d, int floors, float yaw, Material wall, bool windows)
    {
        var q = Quaternion.Euler(0, yaw, 0);
        var go = new GameObject("building"); go.transform.SetParent(root); go.transform.SetPositionAndRotation(c, q);
        var t = go.transform;
        Color cs = new Color(0.62f, 0.61f, 0.58f);
        float fh = 3.6f, th = 0.4f, H = floors * fh;
        void S(Vector3 lp, Vector3 size, Material m) => Solid(c + q * lp, size, m, q, cs, false, t);
        // пол и перекрытие первого этажа
        S(new Vector3(0, 0.1f, 0), new Vector3(w, 0.3f, d), roofMat);
        S(new Vector3(0, fh + 0.15f, 0), new Vector3(w, 0.3f, d), roofMat);
        // фасады первого этажа с дверями
        float[] doorsX = { -w * 0.3f, 0f, w * 0.3f };
        LWall(t, c, q, -w / 2, w / 2, d / 2, fh, th, doorsX, 2.2f, wall, true);
        LWall(t, c, q, -w / 2, w / 2, -d / 2, fh, th, doorsX, 2.2f, wall, true);
        LWall(t, c, q, -d / 2, d / 2, -w / 2, fh, th, new[] { 0f }, 2.2f, wall, false);
        LWall(t, c, q, -d / 2, d / 2, w / 2, fh, th, new[] { 0f }, 2.2f, wall, false);
        // внутренние стены: коридор вдоль и перегородки
        if (d > 14f)
        {
            LWall(t, c, q, -w / 2, w / 2, 2f, fh, 0.25f, new[] { -w * 0.3f, -w * 0.1f, w * 0.1f, w * 0.3f, 0f }, 1.4f, wall, true);
            LWall(t, c, q, -w / 2, w / 2, -2f, fh, 0.25f, new[] { -w * 0.3f, -w * 0.1f, w * 0.1f, w * 0.3f, 0f }, 1.4f, wall, true);
        }
        for (float x = -w / 2 + 8f; x < w / 2 - 4f; x += 8f)
            if (Mathf.Abs(x) > 3f) LWall(t, c, q, -d / 2, d / 2, x, fh, 0.25f, new[] { 0f, d * 0.32f, -d * 0.32f }, 1.3f, wall, false);
        // верхние этажи — сплошной объём
        if (floors > 1) S(new Vector3(0, fh + (H - fh) / 2 + 0.3f, 0), new Vector3(w, H - fh, d), wall);
        // ленточные окна и козырьки над входами
        if (windows)
            for (int f = 0; f < floors; f++)
            {
                float wy = f * fh + 2.0f;
                foreach (float side in new[] { -1f, 1f })
                    for (float x = -w / 2 + 2f; x < w / 2 - 2f; x += 3.2f)
                    {
                        bool door = false;
                        if (f == 0) foreach (var dx in doorsX) if (Mathf.Abs(x - dx) < 2.6f) door = true;
                        if (door) continue;
                        MeshKit.Box(t, new Vector3(x + 1.2f, wy, side * (d / 2 + th / 2 + 0.02f)), new Vector3(2.2f, 1.4f, 0.04f), glassDark);
                        MeshKit.Box(t, new Vector3(x + 1.2f, wy - 0.75f, side * (d / 2 + th / 2 + 0.08f)), new Vector3(2.4f, 0.1f, 0.16f), wallGrey);
                    }
            }
        foreach (float side in new[] { -1f, 1f })
            foreach (var dx in doorsX)
            {
                MeshKit.Box(t, new Vector3(dx, fh - 0.3f, side * (d / 2 + 1.1f)), new Vector3(3.4f, 0.15f, 2f), metalDark);
                if (Night) Lamp(c + q * new Vector3(dx, fh - 0.5f, side * (d / 2 + 1.2f)), new Color(1f, 0.9f, 0.7f), 9f, 1.4f, t);
            }
        // кровля: парапет, вентиляция, кондиционеры
        float top = floors > 1 ? H + 0.3f : fh + 0.3f;
        S(new Vector3(0, top + 0.05f, 0), new Vector3(w, 0.2f, d), roofMat);
        foreach (float side in new[] { -1f, 1f })
        {
            S(new Vector3(0, top + 0.6f, side * (d / 2 - 0.15f)), new Vector3(w, 1f, 0.3f), wall);
            S(new Vector3(side * (w / 2 - 0.15f), top + 0.6f, 0), new Vector3(0.3f, 1f, d), wall);
        }
        for (int i = 0; i < Mathf.Max(2, (int)(w / 12f)); i++)
        {
            float x = -w / 2 + 5f + i * 11f;
            MeshKit.Box(t, new Vector3(x, top + 0.9f, d * 0.2f), new Vector3(2.4f, 1.6f, 1.6f), metalDark);
            MeshKit.Cyl(t, new Vector3(x + 3f, top + 1.2f, -d * 0.2f), 0.4f, 2.2f, new Color(0.55f, 0.56f, 0.58f));
        }
        // вывеска
        SignText(t, new Vector3(0, Mathf.Min(top - 1f, fh + 1.6f), -(d / 2 + th / 2 + 0.05f)), 0f, sign, 0.16f);
        if (Night) Lamp(c + q * new Vector3(0, 2.6f, 0), new Color(1f, 0.95f, 0.85f), Mathf.Max(w, d) * 0.6f, 1.2f, t);
        MeshKit.CombineParts(t);
        Reserve(c.x, c.z, (Mathf.Abs(Mathf.Sin(yaw * Mathf.Deg2Rad)) > 0.5f ? d : w) + 6f, (Mathf.Abs(Mathf.Sin(yaw * Mathf.Deg2Rad)) > 0.5f ? w : d) + 6f);
    }

    // Стена в локальных осях корпуса: вдоль X (alongX) на отметке «at» по Z, или вдоль Z на отметке «at» по X
    static void LWall(Transform t, Vector3 c, Quaternion q, float a0, float a1, float at, float h, float th, float[] doors, float dw, Material m, bool alongX)
    {
        var cuts = new List<float> { a0 };
        var ds = new List<float>(doors); ds.Sort();
        foreach (var dd in ds) { cuts.Add(dd - dw / 2); cuts.Add(dd + dw / 2); }
        cuts.Add(a1);
        Color cs = new Color(0.62f, 0.61f, 0.58f);
        for (int i = 0; i + 1 < cuts.Count; i += 2)
        {
            float a = cuts[i], b = cuts[i + 1];
            if (b - a < 0.05f) continue;
            Vector3 lp = alongX ? new Vector3((a + b) / 2, h / 2 + 0.2f, at) : new Vector3(at, h / 2 + 0.2f, (a + b) / 2);
            Vector3 sz = alongX ? new Vector3(b - a, h, th) : new Vector3(th, h, b - a);
            Solid(c + q * lp, sz, m, q, cs, false, t);
        }
        foreach (var dd in ds)
        {
            Vector3 lp = alongX ? new Vector3(dd, h - 0.45f + 0.2f, at) : new Vector3(at, h - 0.45f + 0.2f, dd);
            Vector3 sz = alongX ? new Vector3(dw, 0.9f, th) : new Vector3(th, 0.9f, dw);
            Solid(c + q * lp, sz, m, q, cs, false, t);
        }
    }

    static void SignText(Transform t, Vector3 lp, float yaw, string text, float scale)
    {
        var font = Helicopter.UIFont();
        if (font == null) return;
        var tg = new GameObject("sign"); tg.transform.SetParent(t, false);
        tg.transform.localPosition = lp; tg.transform.localRotation = Quaternion.Euler(0, yaw, 0);
        tg.transform.localScale = Vector3.one * scale;
        var tm = tg.AddComponent<TextMesh>();
        tm.font = font; tm.fontSize = 60; tm.anchor = TextAnchor.MiddleCenter; tm.alignment = TextAlignment.Center;
        tm.text = text; tm.color = new Color(0.12f, 0.12f, 0.12f);
        tg.GetComponent<MeshRenderer>().sharedMaterial = Helicopter.TextMat(font);
    }

    // ---------------- портал тяжёлой зоны: бункер в насыпи, гермоворота ----------------
    static void HeavyPortal(Transform root, Vector3 c, float yaw)
    {
        var q = Quaternion.Euler(0, yaw, 0);
        var go = new GameObject("HCZ"); go.transform.SetParent(root); go.transform.SetPositionAndRotation(c, q);
        var t = go.transform;
        Color cs = new Color(0.5f, 0.5f, 0.48f);
        void S(Vector3 lp, Vector3 size, Material m, Vector3 e = default) => Solid(c + q * lp, size, m, q * Quaternion.Euler(e), cs, false, t);
        // насыпь (земляной вал) и бетонный портал
        S(new Vector3(0, 3f, 6f), new Vector3(40, 6, 14), roofMat);
        S(new Vector3(0, 1.6f, -2f), new Vector3(40, 4.6f, 4f), roofMat, new Vector3(-38, 0, 0));
        S(new Vector3(-9f, 4f, -1.5f), new Vector3(3, 8, 3), wallGrey);
        S(new Vector3(9f, 4f, -1.5f), new Vector3(3, 8, 3), wallGrey);
        S(new Vector3(0, 7.2f, -1.5f), new Vector3(21, 1.6f, 3), wallGrey);
        // гермоворота (закрыты) с предупреждающей окраской
        S(new Vector3(0, 3.2f, -0.6f), new Vector3(15, 6.4f, 0.8f), metalDark);
        MeshKit.Box(t, new Vector3(0, 0.5f, -1.05f), new Vector3(15, 0.6f, 0.05f), hazard);
        MeshKit.Box(t, new Vector3(0, 6.3f, -1.05f), new Vector3(15, 0.4f, 0.05f), hazard);
        MeshKit.Box(t, new Vector3(0, 3.2f, -1.06f), new Vector3(0.12f, 5.6f, 0.04f), Mats.Get(new Color(0.05f, 0.05f, 0.05f)));
        SignText(t, new Vector3(0, 7.2f, -3.05f), 0f, "ЗОНА ТЯЖЁЛОГО СОДЕРЖАНИЯ\nДОСТУП: УРОВЕНЬ 4", 0.18f);
        // въезд к воротам и отбойники
        for (int i = -1; i <= 1; i += 2)
            for (int k = 0; k < 4; k++)
                S(new Vector3(i * 8.5f, 0.5f, -6f - k * 4f), new Vector3(0.8f, 1f, 2.6f), wallGrey);
        // вентиляционные шахты на насыпи
        for (int i = -1; i <= 1; i += 2)
        {
            S(new Vector3(i * 14f, 7.5f, 8f), new Vector3(3, 3, 3), wallGrey);
            MeshKit.Box(t, new Vector3(i * 14f, 9.1f, 8f), new Vector3(3.2f, 0.2f, 3.2f), metalDark);
        }
        if (Night) Lamp(c + q * new Vector3(0, 8f, -4f), new Color(1f, 0.6f, 0.3f), 18f, 2f, t, true);
        MeshKit.CombineParts(t);
        Reserve(c.x, c.z + 4f, 44, 26);
    }

    // ---------------- электростанция: машинный зал, трубы, трансформаторы ----------------
    static void PowerPlant(Transform root, Vector3 c)
    {
        var go = new GameObject("Power"); go.transform.SetParent(root); go.transform.position = c;
        var t = go.transform;
        Color cs = new Color(0.5f, 0.5f, 0.48f);
        void S(Vector3 lp, Vector3 size, Material m) => Solid(c + lp, size, m, Quaternion.identity, cs, false, t);
        // машинный зал с воротами
        LWall(t, c, Quaternion.identity, -18, 18, -10, 10f, 0.5f, new[] { -8f, 8f }, 4f, wallGrey, true);
        LWall(t, c, Quaternion.identity, -18, 18, 10, 10f, 0.5f, new[] { 0f }, 2.2f, wallGrey, true);
        LWall(t, c, Quaternion.identity, -10, 10, -18, 10f, 0.5f, new[] { 0f }, 2.2f, wallGrey, false);
        LWall(t, c, Quaternion.identity, -10, 10, 18, 10f, 0.5f, new float[0], 2.2f, wallGrey, false);
        S(new Vector3(0, 10.4f, 0), new Vector3(36.5f, 0.5f, 20.5f), metalDark);
        S(new Vector3(0, 0.1f, 0), new Vector3(36, 0.3f, 20), roofMat);
        // генераторы внутри (укрытия)
        for (int i = -1; i <= 1; i++)
        {
            S(new Vector3(i * 10f, 1.4f, 2f), new Vector3(6, 2.6f, 3.4f), metalDark);
            MeshKit.Cyl(t, new Vector3(i * 10f, 3.2f, 2f), 0.6f, 1.2f, new Color(0.4f, 0.42f, 0.45f));
        }
        // две трубы
        foreach (float x in new[] { -8f, 8f })
        {
            var p = new GameObject("stack"); p.transform.SetParent(t); p.transform.position = c + new Vector3(x, 0, 16f);
            MeshKit.Cyl(p.transform, new Vector3(0, 16f, 0), 2.2f, 32f, new Color(0.62f, 0.6f, 0.57f));
            MeshKit.Cyl(p.transform, new Vector3(0, 30.5f, 0), 2.35f, 1.4f, new Color(0.7f, 0.15f, 0.12f));
            MeshKit.Cyl(p.transform, new Vector3(0, 26.5f, 0), 2.35f, 1.4f, new Color(0.9f, 0.9f, 0.88f));
            var cc = p.AddComponent<CapsuleCollider>(); cc.center = new Vector3(0, 16f, 0); cc.radius = 1.1f; cc.height = 32f;
            if (Night) MeshKit.Ball(p.transform, new Vector3(0, 32.3f, 0), Vector3.one * 0.35f, Mats.Glow(Color.red, 5f));
        }
        // трансформаторная площадка за сеткой
        for (int i = 0; i < 3; i++)
        {
            S(new Vector3(-12f + i * 8f, 1.3f, -18f), new Vector3(3, 2.6f, 2.4f), metalDark);
            for (int k = -1; k <= 1; k++) MeshKit.Cyl(t, new Vector3(-12f + i * 8f + k * 0.8f, 3.1f, -18f), 0.12f, 1f, new Color(0.75f, 0.55f, 0.35f));
        }
        Fence(t, c + new Vector3(-17, 0, -22), c + new Vector3(5, 0, -22));
        Fence(t, c + new Vector3(-17, 0, -14), c + new Vector3(-17, 0, -22));
        SignText(t, new Vector3(0, 8.5f, -10.35f), 0f, "ЭНЕРГОБЛОК", 0.2f);
        MeshKit.CombineParts(t);
        Reserve(c.x, c.z - 2f, 42, 32);
    }

    // ---------------- гараж / склад техники ----------------
    static void Hangar(Transform root, Vector3 c, float w, float d)
    {
        var go = new GameObject("Hangar"); go.transform.SetParent(root); go.transform.position = c;
        var t = go.transform;
        LWall(t, c, Quaternion.identity, -w / 2, w / 2, d / 2, 7f, 0.4f, new float[0], 1f, metalDark, true);
        LWall(t, c, Quaternion.identity, -d / 2, d / 2, -w / 2, 7f, 0.4f, new[] { 0f }, 2f, metalDark, false);
        LWall(t, c, Quaternion.identity, -d / 2, d / 2, w / 2, 7f, 0.4f, new[] { 0f }, 2f, metalDark, false);
        // фасад с тремя открытыми воротами
        LWall(t, c, Quaternion.identity, -w / 2, w / 2, -d / 2, 7f, 0.4f, new[] { -w / 3, 0f, w / 3 }, 6f, metalDark, true);
        Solid(c + new Vector3(0, 7.4f, 0), new Vector3(w + 0.6f, 0.4f, d + 0.6f), metalDark, Quaternion.identity, new Color(0.4f, 0.42f, 0.44f), true, t);
        Solid(c + new Vector3(0, 0.1f, 0), new Vector3(w, 0.3f, d), roofMat, Quaternion.identity, new Color(0.4f, 0.4f, 0.4f), false, t);
        foreach (float x in new[] { -w / 3, 0f, w / 3 }) MeshKit.Box(t, new Vector3(x, 6.6f, -d / 2 - 0.25f), new Vector3(6f, 0.8f, 0.1f), hazard);
        Truck(c + new Vector3(-w / 3, 0.2f, 2f), 0f, t);
        Truck(c + new Vector3(w / 3, 0.2f, -1f), 180f, t);
        for (int i = 0; i < 8; i++) Crate(c + new Vector3(R(-w / 2 + 2, w / 2 - 2), 0.2f, R(d / 2 - 5, d / 2 - 2)), t);
        SignText(t, new Vector3(0, 8.4f, -d / 2 - 0.3f), 0f, "АВТОТРАНСПОРТНЫЙ УЧАСТОК", 0.18f);
        if (Night) Lamp(c + new Vector3(0, 6.5f, 0), new Color(1f, 0.9f, 0.7f), 26f, 1.6f, t);
        MeshKit.CombineParts(t);
        Reserve(c.x, c.z, w + 6, d + 6);
    }

    static void WaterTower(Transform root, Vector3 c)
    {
        var go = new GameObject("WaterTower"); go.transform.SetParent(root); go.transform.position = c;
        var t = go.transform;
        var m = Mats.Get(new Color(0.45f, 0.47f, 0.48f), 0.4f, 0.6f);
        for (int i = 0; i < 4; i++)
        {
            float a = i * Mathf.PI / 2 + Mathf.PI / 4;
            MeshKit.Box(t, new Vector3(Mathf.Cos(a) * 3.2f, 9f, Mathf.Sin(a) * 3.2f), new Vector3(0.35f, 18f, 0.35f), m);
        }
        MeshKit.Cyl(t, new Vector3(0, 21f, 0), 4.5f, 6f, new Color(0.82f, 0.82f, 0.8f));
        MeshKit.Part(t, MeshKit.Frustum(0.1f), Mats.Get(new Color(0.7f, 0.7f, 0.68f)), new Vector3(0, 25f, 0), new Vector3(9.2f, 2f, 9.2f));
        SignText(t, new Vector3(0, 21f, -4.6f), 0f, "ЗОНА-19", 0.4f);
        MeshKit.CombineParts(t);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 12f, 0); bc.size = new Vector3(7f, 24f, 7f);
        Reserve(c.x, c.z, 10, 10);
    }

    static void RadioMast(Transform root, Vector3 c)
    {
        var go = new GameObject("Mast"); go.transform.SetParent(root); go.transform.position = c;
        var t = go.transform;
        var m = Mats.Get(new Color(0.75f, 0.2f, 0.15f), 0.3f, 0.5f);
        var w = Mats.Get(new Color(0.9f, 0.9f, 0.9f), 0.3f, 0.5f);
        for (int i = 0; i < 10; i++)
        {
            float h = i * 4f;
            MeshKit.Box(t, new Vector3(0, h + 2f, 0), new Vector3(1.2f - i * 0.06f, 4f, 1.2f - i * 0.06f), i % 2 == 0 ? m : w);
        }
        if (Night) MeshKit.Ball(t, new Vector3(0, 40.4f, 0), Vector3.one * 0.4f, Mats.Glow(Color.red, 6f));
        MeshKit.CombineParts(t);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 20f, 0); bc.size = new Vector3(1.2f, 40f, 1.2f);
        Reserve(c.x, c.z, 6, 6);
    }

    static void Parking(Transform root, Vector3 c, float w, float d)
    {
        var go = new GameObject("Parking"); go.transform.SetParent(root); go.transform.position = c;
        var t = go.transform;
        Solid(c + new Vector3(0, 0.05f, 0), new Vector3(w, 0.2f, d), asphalt, Quaternion.identity, new Color(0.25f, 0.25f, 0.25f), false, t);
        var line = Mats.Get(new Color(0.85f, 0.85f, 0.8f), 0.2f);
        for (float x = -w / 2 + 3f; x < w / 2; x += 3f) foreach (float s in new[] { -1f, 1f }) MeshKit.Box(t, new Vector3(x, 0.16f, s * d / 4), new Vector3(0.12f, 0.02f, d / 2 - 2f), line);
        Color[] cars = { new Color(0.12f, 0.12f, 0.13f), new Color(0.7f, 0.7f, 0.72f), new Color(0.25f, 0.28f, 0.22f), new Color(0.5f, 0.1f, 0.08f) };
        for (float x = -w / 2 + 4.5f; x < w / 2 - 2f; x += 3f)
            foreach (float s in new[] { -1f, 1f })
                if (R() < 0.6f) Car(t, c + new Vector3(x, 0.15f, s * (d / 4 + 0.6f)), s > 0 ? 180f : 0f, cars[rng.Next(cars.Length)]);
        MeshKit.CombineParts(t);
        Reserve(c.x, c.z, w, d);
    }

    static void Car(Transform root, Vector3 p, float yaw, Color col)
    {
        var go = new GameObject("car"); go.transform.SetParent(root); go.transform.SetPositionAndRotation(p, Quaternion.Euler(0, yaw + R(-6, 6), 0));
        var t = go.transform;
        MeshKit.Box(t, new Vector3(0, 0.6f, 0), new Vector3(1.8f, 0.7f, 4.4f), col, default, 0.7f, 0.5f);
        MeshKit.Box(t, new Vector3(0, 1.2f, -0.2f), new Vector3(1.6f, 0.55f, 2.3f), col, default, 0.7f, 0.5f);
        MeshKit.Box(t, new Vector3(0, 1.2f, -0.2f), new Vector3(1.64f, 0.42f, 2.1f), glassDark);
        foreach (var w in new[] { new Vector3(-0.85f, 0.35f, 1.4f), new Vector3(0.85f, 0.35f, 1.4f), new Vector3(-0.85f, 0.35f, -1.4f), new Vector3(0.85f, 0.35f, -1.4f) })
            MeshKit.Cyl(t, w, 0.35f, 0.25f, new Color(0.06f, 0.06f, 0.06f), new Vector3(0, 0, 90));
        MeshKit.CombineParts(t);
        var bc = go.AddComponent<BoxCollider>(); bc.center = new Vector3(0, 0.8f, 0); bc.size = new Vector3(1.8f, 1.5f, 4.4f);
        go.AddComponent<Surface>().metal = true;
    }

    // ---------------- периметр: стена, колючка, вышки, КПП ----------------
    static void Perimeter(Transform root, float y)
    {
        var go = new GameObject("Perimeter"); go.transform.SetParent(root);
        var t = go.transform;
        float h = 4.5f;
        Color cs = new Color(0.5f, 0.5f, 0.48f);
        var wire = Mats.Get(new Color(0.3f, 0.3f, 0.3f), 0.5f, 0.7f);
        // ворота: юг и север (x≈0), запад и восток (z≈10 / -20)
        void Run(Vector3 a, Vector3 b, float gapAt, float gapW, bool alongX)
        {
            float len = alongX ? b.x - a.x : b.z - a.z;
            float g0 = gapAt - gapW / 2, g1 = gapAt + gapW / 2;
            foreach (var seg in new[] { new Vector2(alongX ? a.x : a.z, g0), new Vector2(g1, alongX ? b.x : b.z) })
            {
                float s0 = seg.x, s1 = seg.y;
                for (float u = s0; u < s1 - 0.1f; u += 6f)
                {
                    float u1 = Mathf.Min(s1, u + 6f), mid = (u + u1) / 2;
                    Vector3 p = alongX ? new Vector3(mid, 0, a.z) : new Vector3(a.x, 0, mid);
                    float gy = Height(p.x, p.z);
                    Solid(new Vector3(p.x, gy + h / 2 - 0.3f, p.z), alongX ? new Vector3(u1 - u + 0.02f, h, 0.6f) : new Vector3(0.6f, h, u1 - u + 0.02f), wallGrey, Quaternion.identity, cs, false, t);
                    MeshKit.Box(t, new Vector3(p.x, gy + h + 0.1f - 0.3f, p.z), alongX ? new Vector3(u1 - u, 0.2f, 0.9f) : new Vector3(0.9f, 0.2f, u1 - u), roofMat);
                    // спираль колючей проволоки
                    for (int k = 0; k < 3; k++)
                    {
                        float uu = u + (k + 0.5f) * (u1 - u) / 3f;
                        Vector3 wp = alongX ? new Vector3(uu, gy + h + 0.55f - 0.3f, a.z) : new Vector3(a.x, gy + h + 0.55f - 0.3f, uu);
                        MeshKit.Box(t, wp, alongX ? new Vector3(2f, 0.06f, 0.6f) : new Vector3(0.6f, 0.06f, 2f), wire, alongX ? new Vector3(45, 0, 0) : new Vector3(0, 0, 45));
                        MeshKit.Box(t, wp, alongX ? new Vector3(2f, 0.06f, 0.6f) : new Vector3(0.6f, 0.06f, 2f), wire, alongX ? new Vector3(-45, 0, 0) : new Vector3(0, 0, -45));
                    }
                }
            }
            Checkpoint(t, alongX ? new Vector3(gapAt, 0, a.z) : new Vector3(a.x, 0, gapAt), alongX ? 0f : 90f, gapW);
        }
        Reserve(0, -SiteZ, SiteX * 2 + 2, 3); Reserve(0, SiteZ, SiteX * 2 + 2, 3);
        Reserve(-SiteX, 0, 3, SiteZ * 2 + 2); Reserve(SiteX, 0, 3, SiteZ * 2 + 2);
        Run(new Vector3(-SiteX, 0, -SiteZ), new Vector3(SiteX, 0, -SiteZ), 0f, 12f, true);
        Run(new Vector3(-SiteX, 0, SiteZ), new Vector3(SiteX, 0, SiteZ), 0f, 12f, true);
        Run(new Vector3(-SiteX, 0, -SiteZ), new Vector3(-SiteX, 0, SiteZ), 10f, 10f, false);
        Run(new Vector3(SiteX, 0, -SiteZ), new Vector3(SiteX, 0, SiteZ), -20f, 10f, false);
        MeshKit.CombineParts(t);
        // вышки по углам и серединам
        foreach (var p in new[] { new Vector2(-1, -1), new Vector2(1, -1), new Vector2(-1, 1), new Vector2(1, 1), new Vector2(-0.5f, -1), new Vector2(0.5f, -1), new Vector2(-0.5f, 1), new Vector2(0.5f, 1), new Vector2(-1, -0.5f), new Vector2(1, 0.5f) })
        {
            Vector3 tp = new Vector3(p.x * (SiteX - 5f), 0, p.y * (SiteZ - 5f));
            Tower(OnGround(tp.x, tp.z), root);
        }
    }

    static void Checkpoint(Transform t, Vector3 c, float yaw, float gap)
    {
        var q = Quaternion.Euler(0, yaw, 0);
        float gy = Height(c.x, c.z);
        Color cs = new Color(0.6f, 0.6f, 0.58f);
        // будка охраны и шлагбаум
        Vector3 booth = c + q * new Vector3(gap / 2 + 3f, 0, -4f);
        Solid(new Vector3(booth.x, gy + 1.4f, booth.z), new Vector3(3f, 2.8f, 3f), wallWhite, q, cs, false, t);
        MeshKit.Box(t, booth + Vector3.up * (gy + 1.8f) + q * new Vector3(0, 0, -1.52f), new Vector3(2.4f, 1f, 0.04f), glassDark, new Vector3(0, yaw, 0));
        MeshKit.Box(t, booth + Vector3.up * (gy + 2.95f), new Vector3(3.6f, 0.2f, 3.6f), metalDark, new Vector3(0, yaw, 0));
        Vector3 arm = c + q * new Vector3(0, 0, -4f);
        MeshKit.Box(t, arm + Vector3.up * (gy + 1.05f), new Vector3(gap - 1f, 0.12f, 0.12f), hazard, new Vector3(0, yaw, 0));
        Solid(new Vector3(arm.x, gy + 0.55f, arm.z) + q * new Vector3(gap / 2 - 0.3f, 0, 0), new Vector3(0.5f, 1.1f, 0.5f), metalDark, q, cs, true, t);
        // бетонные блоки «змейкой» перед въездом
        for (int i = 0; i < 3; i++)
        {
            Vector3 b = c + q * new Vector3((i % 2 == 0 ? -1 : 1) * gap * 0.22f, 0, -9f - i * 5f);
            Solid(new Vector3(b.x, gy + 0.45f, b.z), new Vector3(gap * 0.55f, 0.9f, 0.7f), wallGrey, q, cs, false, t);
        }
        if (Night) Lamp(booth + Vector3.up * (gy + 3.5f), new Color(1f, 0.9f, 0.7f), 16f, 1.8f, t);
        Vector3 rc = c + q * new Vector3(0, 0, -10f);
        bool ax = Mathf.Abs(Mathf.Sin(yaw * Mathf.Deg2Rad)) < 0.5f;
        Reserve(rc.x, rc.z, ax ? gap + 12f : 26f, ax ? 26f : gap + 12f);
    }

    static void Fence(Transform t, Vector3 a, Vector3 b)
    {
        var m = Mats.Get(new Color(0.35f, 0.36f, 0.36f), 0.4f, 0.6f);
        var net = Mats.Get(new Color(0.3f, 0.31f, 0.31f, 0.5f), 0.3f, 0.5f);
        Vector3 d = b - a; float len = d.magnitude; d /= Mathf.Max(0.01f, len);
        float yaw = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg;
        for (float u = 0; u <= len; u += 3f)
        {
            Vector3 p = a + d * u; p.y = Height(p.x, p.z);
            MeshKit.Box(t, p + Vector3.up * 1.25f, new Vector3(0.08f, 2.5f, 0.08f), m);
        }
        Vector3 mid = (a + b) / 2; mid.y = Height(mid.x, mid.z);
        MeshKit.Box(t, mid + Vector3.up * 1.25f, new Vector3(0.03f, 2.4f, len), net, new Vector3(0, yaw, 0));
    }

    // ---------------- дороги комплекса ----------------
    static void SiteRoads(float y)
    {
        var m = asphalt;
        // въезды через КПП и кольцевая дорога вокруг Ворот A
        RoadStraight(new Vector3(0, 0, -Size / 2), new Vector3(0, 0, -36f), 8f, m);
        RoadStraight(new Vector3(0, 0, 36f), new Vector3(0, 0, Size / 2), 8f, m);
        RoadStraight(new Vector3(-Size / 2, 0, 10f), new Vector3(-50f, 0, 10f), 7f, m);
        RoadStraight(new Vector3(50f, 0, -20f), new Vector3(Size / 2, 0, -20f), 7f, m);
        RoadStraight(new Vector3(-60f, 0, -42f), new Vector3(60f, 0, -42f), 7f, m);
        RoadStraight(new Vector3(-60f, 0, 42f), new Vector3(60f, 0, 42f), 7f, m);
        RoadStraight(new Vector3(-60f, 0, -42f), new Vector3(-60f, 0, 42f), 7f, m);
        RoadStraight(new Vector3(60f, 0, -42f), new Vector3(60f, 0, 42f), 7f, m);
    }

    static void RoadStraight(Vector3 a, Vector3 b, float w, Material m) => Road(new[] { a, (a + b) / 2, b }, w, m);
}
