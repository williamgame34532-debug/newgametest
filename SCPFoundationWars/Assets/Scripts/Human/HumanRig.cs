using System.Collections.Generic;
using UnityEngine;

// Пропорции тела (для бойцов и человекоподобных SCP)
public class BodyShape
{
    public float armU = 0.29f, armL = 0.27f, legU = 0.45f, legL = 0.44f;
    public float shoulder = 0.2f, torso = 1f, neck = 1f, bulk = 1f, headSize = 1f;
    public bool model;              // тело — готовая модель солдата
    public Vector3[] joints;        // точные смещения суставов (из модели)

    public static BodyShape Soldier(float bulk = 1f) => new BodyShape { bulk = bulk };
    public static BodyShape Tall096() => new BodyShape { armU = 0.46f, armL = 0.44f, legU = 0.56f, legL = 0.55f, shoulder = 0.19f, torso = 1.15f, neck = 1.5f, bulk = 0.62f, headSize = 1.05f };
    public static BodyShape Old106() => new BodyShape { armU = 0.31f, armL = 0.3f, legU = 0.46f, legL = 0.45f, shoulder = 0.19f, torso = 1.0f, neck = 1.1f, bulk = 0.85f };
}

// Скелет человека: кости-трансформы, построенные кодом. Конечности направлены вниз по -Y,
// поэтому поза "по стойке смирно" — это нулевые повороты всех костей.
public class HumanRig : MonoBehaviour
{
    public const int Hips = 0, Spine = 1, Chest = 2, Neck = 3, Head = 4,
        UArmL = 5, LArmL = 6, HandL = 7, UArmR = 8, LArmR = 9, HandR = 10,
        ULegL = 11, LLegL = 12, FootL = 13, ULegR = 14, LLegR = 15, FootR = 16, Count = 17;

    public Transform[] b = new Transform[Count];
    public Transform aimPivot, eye, jaw, headTop;
    public BodyShape shape;
    public Look look;
    public float hipsHeight;
    public Vector3 hipsRest;

    public Transform hips => b[Hips];
    public Transform chest => b[Chest];
    public Transform head => b[Head];

    Transform Bone(int idx, string name, Transform parent, Vector3 pos)
    {
        var t = new GameObject(name).transform;
        t.SetParent(parent, false);
        t.localPosition = pos;
        b[idx] = t;
        return t;
    }

    public static HumanRig Create(Transform root, BodyShape s)
    {
        var rig = root.gameObject.AddComponent<HumanRig>();
        rig.shape = s;
        float tor = s.torso;
        if (s.joints != null)
        {
            var j = s.joints;
            rig.hipsHeight = j[Hips].y;
            var hp = rig.Bone(Hips, "hips", root, j[Hips]);
            var sp = rig.Bone(Spine, "spine", hp, j[Spine]);
            var chx = rig.Bone(Chest, "chest", sp, j[Chest]);
            var nk = rig.Bone(Neck, "neck", chx, j[Neck]);
            rig.Bone(Head, "head", nk, j[Head]);
            var a1 = rig.Bone(UArmL, "uArmL", chx, j[UArmL]); var a2 = rig.Bone(LArmL, "lArmL", a1, j[LArmL]); rig.Bone(HandL, "handL", a2, j[HandL]);
            var a3 = rig.Bone(UArmR, "uArmR", chx, j[UArmR]); var a4 = rig.Bone(LArmR, "lArmR", a3, j[LArmR]); rig.Bone(HandR, "handR", a4, j[HandR]);
            var l1 = rig.Bone(ULegL, "uLegL", hp, j[ULegL]); var l2 = rig.Bone(LLegL, "lLegL", l1, j[LLegL]); rig.Bone(FootL, "footL", l2, j[FootL]);
            var l3 = rig.Bone(ULegR, "uLegR", hp, j[ULegR]); var l4 = rig.Bone(LLegR, "lLegR", l3, j[LLegR]); rig.Bone(FootR, "footR", l4, j[FootR]);
        }
        else
        {
            rig.hipsHeight = s.legU + s.legL + 0.075f;
            var hips = rig.Bone(Hips, "hips", root, new Vector3(0, rig.hipsHeight, 0));
            var spine = rig.Bone(Spine, "spine", hips, new Vector3(0, 0.1f * tor, 0));
            var chest = rig.Bone(Chest, "chest", spine, new Vector3(0, 0.17f * tor, 0));
            var neck = rig.Bone(Neck, "neck", chest, new Vector3(0, 0.25f * tor, 0));
            rig.Bone(Head, "head", neck, new Vector3(0, 0.085f * s.neck, 0));
            var ual = rig.Bone(UArmL, "uArmL", chest, new Vector3(-s.shoulder, 0.205f * tor, 0));
            var lal = rig.Bone(LArmL, "lArmL", ual, new Vector3(0, -s.armU, 0));
            rig.Bone(HandL, "handL", lal, new Vector3(0, -s.armL, 0));
            var uar = rig.Bone(UArmR, "uArmR", chest, new Vector3(s.shoulder, 0.205f * tor, 0));
            var lar = rig.Bone(LArmR, "lArmR", uar, new Vector3(0, -s.armU, 0));
            rig.Bone(HandR, "handR", lar, new Vector3(0, -s.armL, 0));
            var ull = rig.Bone(ULegL, "uLegL", hips, new Vector3(-0.1f, -0.05f, 0));
            var lll = rig.Bone(LLegL, "lLegL", ull, new Vector3(0, -s.legU, 0));
            rig.Bone(FootL, "footL", lll, new Vector3(0, -s.legL, 0));
            var ulr = rig.Bone(ULegR, "uLegR", hips, new Vector3(0.1f, -0.05f, 0));
            var llr = rig.Bone(LLegR, "lLegR", ulr, new Vector3(0, -s.legU, 0));
            rig.Bone(FootR, "footR", llr, new Vector3(0, -s.legL, 0));
        }
        var chest0 = rig.b[Chest];
        rig.aimPivot = new GameObject("aimPivot").transform;
        rig.aimPivot.SetParent(chest0, false);
        rig.aimPivot.localPosition = new Vector3(0.1f, 0.17f * tor, 0.02f);

        rig.eye = new GameObject("eye").transform;
        rig.eye.SetParent(rig.b[Head], false);
        rig.eye.localPosition = s.model ? new Vector3(0, 0.135f, 0.16f) : new Vector3(0, 0.12f * s.headSize, 0.1f);
        rig.headTop = new GameObject("headTop").transform;
        rig.headTop.SetParent(rig.b[Head], false);
        rig.headTop.localPosition = new Vector3(0, s.model ? 0.3f : 0.25f * s.headSize, 0);
        rig.hipsRest = rig.b[Hips].localPosition;
        return rig;
    }

    // Объединяет детали каждой кости в один меш (меньше отрисовок)
    public void Finish()
    {
        foreach (var t in b) MeshKit.CombineParts(t);
    }

    // ---------------- модель солдата ----------------
    public SkinnedMeshRenderer body;

    // Одевает готовую модель: перекраска частей под отряд, своя голова/каска, рюкзак, наплечники
    // Цвета/материалы частей модели под отряд. slotOf[group] — номер материала или -1 (скрыто).
    public static void ModelMaterials(Look L, out int[] slotOf, out Material[] matsOut, out bool openFace)
    {
        var cols = new Color[ModelLib.G_COUNT];
        var vis = new bool[ModelLib.G_COUNT];
        for (int i = 0; i < vis.Length; i++) vis[i] = true;
        Color black = new Color(0.07f, 0.07f, 0.075f);
        cols[ModelLib.G_SKIN] = L.skin;
        cols[ModelLib.G_JACKET] = L.uniform;
        cols[ModelLib.G_PANTS] = L.uniform2;
        cols[ModelLib.G_VEST] = L.vest ? L.armor : L.uniform * 0.95f;
        cols[ModelLib.G_GEAR] = L.gear;
        cols[ModelLib.G_POUCH] = L.vest ? Color.Lerp(L.armor, L.gear, 0.45f) : L.uniform * 0.85f;
        cols[ModelLib.G_HELMET] = L.helmet;
        cols[ModelLib.G_BAND] = Color.Lerp(L.helmet, L.accent, 0.35f);
        cols[ModelLib.G_MASK] = black;
        cols[ModelLib.G_CUFF] = Color.Lerp(L.uniform, L.gear, 0.6f);
        openFace = false;
        bool hideHelmet = false, hideGoggles = false;
        switch (L.head)
        {
            case HeadGear.Cap: case HeadGear.Bare: hideHelmet = hideGoggles = true; openFace = true; break;
            case HeadGear.Hazmat: hideHelmet = hideGoggles = true; cols[ModelLib.G_MASK] = L.uniform; break;
            case HeadGear.Balaclava: hideHelmet = hideGoggles = true; break;
            case HeadGear.Cyborg: hideHelmet = hideGoggles = true; cols[ModelLib.G_MASK] = L.helmet * 0.9f; break;
            case HeadGear.GasMask: hideGoggles = true; cols[ModelLib.G_MASK] = new Color(0.1f, 0.1f, 0.09f); break;
        }
        if (openFace) cols[ModelLib.G_MASK] = L.skin;
        if (hideHelmet) { vis[ModelLib.G_HELMET] = false; vis[ModelLib.G_BAND] = false; }
        if (hideGoggles) vis[ModelLib.G_GOGGLES] = false;
        var mats = new List<Material>();
        slotOf = new int[ModelLib.G_COUNT];
        for (int g = 0; g < ModelLib.G_COUNT; g++)
        {
            if (!vis[g]) { slotOf[g] = -1; continue; }
            Material m;
            if (g == ModelLib.G_GOGGLES) m = Mats.Glass(L.visor, 0.95f, L.visorGlow);
            else m = Mats.Get(cols[g], g == ModelLib.G_HELMET || g == ModelLib.G_VEST ? 0.3f : g == ModelLib.G_SKIN ? 0.25f : 0.12f);
            int slot = mats.IndexOf(m);
            if (slot < 0) { slot = mats.Count; mats.Add(m); }
            slotOf[g] = slot;
        }
        matsOut = mats.ToArray();
    }

    public void DressModel(Look L, string key)
    {
        look = L;
        ModelMaterials(L, out int[] slotOf, out Material[] matArr, out bool openFace);
        var mats = new List<Material>(matArr);
        var sig = new System.Text.StringBuilder();
        foreach (var x in slotOf) sig.Append(x).Append(',');
        var mesh = ModelLib.BodyMesh(sig.ToString(), slotOf, mats.Count);
        var go = new GameObject("body");
        go.transform.SetParent(transform, false);
        body = go.AddComponent<SkinnedMeshRenderer>();
        body.sharedMesh = mesh;
        body.bones = b;
        body.rootBone = b[Hips];
        body.sharedMaterials = mats.ToArray();
        body.localBounds = new Bounds(new Vector3(0, 0.1f, 0), new Vector3(2.6f, 2.6f, 2.6f));
        body.updateWhenOffscreen = false;
        body.skinnedMotionVectors = false;
        body.quality = SkinQuality.Bone4;

        ModelHead(L, openFace);
        // снаряжение поверх модели
        var ch = b[Chest];
        if (L.backpack)
        {
            Color bp = Color.Lerp(L.uniform, L.gear, 0.35f);
            MeshKit.Box(ch, new Vector3(0, 0.04f, -0.27f), new Vector3(0.3f, 0.36f, 0.15f), bp, default, 0.12f);
            MeshKit.Box(ch, new Vector3(0, -0.1f, -0.27f), new Vector3(0.26f, 0.09f, 0.16f), bp * 0.85f);
            MeshKit.Box(ch, new Vector3(0, 0.25f, -0.25f), new Vector3(0.22f, 0.05f, 0.12f), L.gear);
        }
        if (L.heavy) MeshKit.Box(ch, new Vector3(0, 0.18f, 0.2f), new Vector3(0.3f, 0.12f, 0.04f), L.armor, default, 0.35f);
        MeshKit.Box(ch, new Vector3(0.11f, 0.2f, 0.205f), new Vector3(0.06f, 0.04f, 0.012f), Mats.Get(L.accent, 0.3f)); // нашивка отряда
        for (int side = 0; side < 2; side++)
        {
            float sx = side == 0 ? -1 : 1;
            var ua = b[side == 0 ? UArmL : UArmR];
            if (L.shoulderPads) MeshKit.Ball(ua, new Vector3(sx * 0.02f, -0.03f, 0), new Vector3(0.17f, 0.11f, 0.16f), L.armor, default, 0.3f);
            MeshKit.Box(ua, new Vector3(sx * 0.062f, -0.09f, 0), new Vector3(0.012f, 0.06f, 0.06f), Mats.Get(L.accent, 0.3f)); // шеврон
        }
        foreach (var t in b) MeshKit.CombineParts(t);
    }

    // Голова модели: центр (0, 0.135, 0.03) от сустава головы, лицо в плоскости z = 0.165
    void ModelHead(Look L, bool openFace)
    {
        var h = b[Head];
        Color dark = new Color(0.06f, 0.06f, 0.06f);
        var visorMat = Mats.Glass(L.visor, 0.95f, L.visorGlow);
        if (openFace)
        {
            var white = Mats.Get(new Color(0.95f, 0.95f, 0.93f), 0.7f);
            var pupil = Mats.Get(new Color(0.07f, 0.05f, 0.04f), 0.8f);
            for (int s = -1; s <= 1; s += 2)
            {
                MeshKit.Ball(h, new Vector3(s * 0.042f, 0.138f, 0.158f), new Vector3(0.034f, 0.024f, 0.02f), white);
                MeshKit.Ball(h, new Vector3(s * 0.042f, 0.138f, 0.167f), new Vector3(0.015f, 0.015f, 0.008f), pupil);
                MeshKit.Box(h, new Vector3(s * 0.042f, 0.163f, 0.165f), new Vector3(0.045f, 0.009f, 0.012f), L.skin * 0.45f, new Vector3(0, 0, s * -6));
            }
            MeshKit.Part(h, MeshKit.Frustum(0.5f, 4), Mats.Get(L.skin * 0.95f), new Vector3(0, 0.11f, 0.172f), new Vector3(0.03f, 0.045f, 0.03f), new Vector3(-15, 45, 0));
            MeshKit.Box(h, new Vector3(0, 0.072f, 0.166f), new Vector3(0.045f, 0.008f, 0.008f), L.skin * 0.55f);
        }
        switch (L.head)
        {
            case HeadGear.HeavyHelmet:
                MeshKit.Ball(h, new Vector3(0, 0.2f, 0.02f), new Vector3(0.31f, 0.25f, 0.33f), L.helmet, default, 0.35f);
                MeshKit.Box(h, new Vector3(0, 0.12f, 0.2f), new Vector3(0.24f, 0.13f, 0.03f), visorMat, new Vector3(-8, 0, 0));
                MeshKit.Box(h, new Vector3(0, 0.035f, 0.16f), new Vector3(0.17f, 0.06f, 0.07f), L.helmet);
                MeshKit.Box(h, new Vector3(0, 0.3f, 0.02f), new Vector3(0.04f, 0.03f, 0.22f), L.accent);
                break;
            case HeadGear.GasMask:
                for (int s = -1; s <= 1; s += 2)
                    MeshKit.Cyl(h, new Vector3(s * 0.045f, 0.14f, 0.168f), 0.055f, 0.02f, visorMat, new Vector3(90, 0, 0));
                MeshKit.Cyl(h, new Vector3(0, 0.07f, 0.19f), 0.065f, 0.06f, dark, new Vector3(75, 0, 0));
                MeshKit.Cyl(h, new Vector3(0.065f, 0.06f, 0.17f), 0.06f, 0.07f, new Color(0.22f, 0.24f, 0.16f), new Vector3(70, 0, -50));
                break;
            case HeadGear.Hazmat:
                MeshKit.Ball(h, new Vector3(0, 0.15f, 0.02f), new Vector3(0.29f, 0.36f, 0.32f), L.uniform, default, 0.45f);
                MeshKit.Box(h, new Vector3(0, 0.14f, 0.18f), new Vector3(0.17f, 0.12f, 0.03f), visorMat);
                MeshKit.Cyl(h, new Vector3(0, 0.05f, 0.18f), 0.075f, 0.07f, dark, new Vector3(75, 0, 0));
                MeshKit.Cyl(h, new Vector3(0.1f, 0.05f, 0.13f), 0.065f, 0.07f, new Color(0.15f, 0.15f, 0.15f), new Vector3(70, 0, -60));
                break;
            case HeadGear.Balaclava:
                MeshKit.Ball(h, new Vector3(0, 0.155f, 0.025f), new Vector3(0.235f, 0.3f, 0.275f), Mats.Get(new Color(0.07f, 0.07f, 0.07f), 0.1f));
                MeshKit.Box(h, new Vector3(0, 0.138f, 0.163f), new Vector3(0.13f, 0.036f, 0.01f), L.skin);
                for (int s = -1; s <= 1; s += 2)
                    MeshKit.Ball(h, new Vector3(s * 0.04f, 0.138f, 0.168f), new Vector3(0.022f, 0.02f, 0.01f), new Color(0.08f, 0.06f, 0.05f), default, 0.8f);
                break;
            case HeadGear.NightVision:
                for (int i = 0; i < 4; i++)
                {
                    float x = (i - 1.5f) * 0.036f;
                    MeshKit.Cyl(h, new Vector3(x, 0.19f, 0.25f), 0.033f, 0.08f, dark, new Vector3(90, 0, 0));
                    MeshKit.Cyl(h, new Vector3(x, 0.19f, 0.291f), 0.027f, 0.005f, Mats.Glow(new Color(0.2f, 1f, 0.3f), 3f), new Vector3(90, 0, 0));
                }
                MeshKit.Box(h, new Vector3(0, 0.24f, 0.21f), new Vector3(0.09f, 0.06f, 0.06f), dark);
                break;
            case HeadGear.Cap:
                MeshKit.Ball(h, new Vector3(0, 0.215f, 0.02f), new Vector3(0.235f, 0.15f, 0.26f), L.helmet);
                MeshKit.Box(h, new Vector3(0, 0.215f, 0.17f), new Vector3(0.18f, 0.014f, 0.11f), L.helmet, new Vector3(-6, 0, 0));
                MeshKit.Box(h, new Vector3(0, 0.14f, 0.172f), new Vector3(0.14f, 0.035f, 0.015f), Mats.Glass(new Color(0.04f, 0.04f, 0.04f, 0.85f)));
                break;
            case HeadGear.Cyborg:
                MeshKit.Ball(h, new Vector3(0, 0.15f, 0.025f), new Vector3(0.265f, 0.33f, 0.3f), L.helmet, default, 0.75f);
                MeshKit.Box(h, new Vector3(0, 0.15f, 0.172f), new Vector3(0.18f, 0.032f, 0.02f), Mats.Glow(L.accent, 3f));
                MeshKit.Box(h, new Vector3(0, 0.1f, 0.178f), new Vector3(0.02f, 0.07f, 0.015f), Mats.Glow(L.accent, 2f));
                MeshKit.Box(h, new Vector3(-0.13f, 0.14f, 0.02f), new Vector3(0.03f, 0.1f, 0.11f), new Color(0.6f, 0.62f, 0.65f), default, 0.6f, 0.5f);
                MeshKit.Box(h, new Vector3(0.13f, 0.14f, 0.02f), new Vector3(0.03f, 0.1f, 0.11f), new Color(0.6f, 0.62f, 0.65f), default, 0.6f, 0.5f);
                break;
            case HeadGear.DeltaHelmet:
                MeshKit.Box(h, new Vector3(0, 0.14f, 0.178f), new Vector3(0.2f, 0.04f, 0.03f), Mats.Glow(new Color(1f, 0.08f, 0.04f), 3.5f));
                break;
            case HeadGear.Bare:
                MeshKit.Ball(h, new Vector3(0, 0.2f, 0.01f), new Vector3(0.215f, 0.2f, 0.25f), L.skin * 0.8f);
                break;
            case HeadGear.Helmet:
                MeshKit.Box(h, new Vector3(0, 0.27f, 0.18f), new Vector3(0.07f, 0.04f, 0.04f), dark);
                MeshKit.Box(h, new Vector3(0.14f, 0.2f, 0.0f), new Vector3(0.015f, 0.035f, 0.1f), L.accent);
                break;
        }
    }

    // ---------------- экипировка бойца ----------------
    public void DressSoldier(Look L)
    {
        look = L;
        var s = shape;
        float k = L.bulk * s.bulk;
        Color uni = L.uniform, uni2 = L.uniform2, arm = L.armor, gear = L.gear, skin = L.skin;

        // таз и пояс
        var hips = b[Hips];
        MeshKit.Box(hips, new Vector3(0, -0.01f, 0), new Vector3(0.31f * k, 0.19f, 0.2f * k), uni2);
        MeshKit.Box(hips, new Vector3(0, 0.06f, 0), new Vector3(0.33f * k, 0.05f, 0.215f * k), gear, default, 0.4f);
        MeshKit.Box(hips, new Vector3(0, 0.06f, 0.11f * k), new Vector3(0.05f, 0.04f, 0.015f), new Color(0.5f, 0.5f, 0.45f), default, 0.6f, 0.8f);
        if (L.vest)
        {
            MeshKit.Box(hips, new Vector3(-0.13f * k, 0.02f, 0.06f * k), new Vector3(0.06f, 0.08f, 0.06f), arm);
            MeshKit.Box(hips, new Vector3(0.14f * k, 0.03f, -0.04f * k), new Vector3(0.05f, 0.09f, 0.08f), arm);
            MeshKit.Box(hips, new Vector3(0f, 0.03f, -0.11f * k), new Vector3(0.12f, 0.07f, 0.05f), arm);
        }

        // живот
        MeshKit.Box(b[Spine], new Vector3(0, 0.08f, 0), new Vector3(0.29f * k, 0.2f, 0.185f * k), uni);

        // грудь
        var ch = b[Chest];
        MeshKit.Box(ch, new Vector3(0, 0.1f, 0), new Vector3(0.37f * k, 0.3f, 0.215f * k), uni);
        MeshKit.Ball(ch, new Vector3(-s.shoulder * 0.95f, 0.2f, 0), new Vector3(0.13f, 0.12f, 0.13f) * k, uni);
        MeshKit.Ball(ch, new Vector3(s.shoulder * 0.95f, 0.2f, 0), new Vector3(0.13f, 0.12f, 0.13f) * k, uni);
        MeshKit.Cyl(ch, new Vector3(0, 0.255f, 0), 0.15f * k, 0.04f, uni);  // воротник
        if (L.vest)
        {
            MeshKit.Box(ch, new Vector3(0, 0.08f, 0.005f), new Vector3(0.4f * k, 0.31f, 0.27f * k), arm, default, 0.3f);
            if (L.heavy)
            {
                MeshKit.Box(ch, new Vector3(0, 0.2f, 0.01f), new Vector3(0.42f * k, 0.08f, 0.29f * k), arm, default, 0.35f);
                MeshKit.Box(ch, new Vector3(0, -0.04f, 0.01f), new Vector3(0.41f * k, 0.07f, 0.285f * k), Mats.Get(arm * 0.85f));
            }
            for (int i = -1; i <= 1; i++)
                MeshKit.Box(ch, new Vector3(i * 0.09f * k, 0.0f, 0.145f * k), new Vector3(0.07f, 0.11f, 0.05f), Color.Lerp(arm, gear, 0.4f));
            MeshKit.Box(ch, new Vector3(0.09f * k, 0.16f, 0.14f * k), new Vector3(0.07f, 0.05f, 0.025f), L.accent, default, 0.3f); // нашивка
            MeshKit.Box(ch, new Vector3(-0.1f * k, 0.17f, 0.14f * k), new Vector3(0.04f, 0.08f, 0.03f), gear);                 // рация
            MeshKit.Cyl(ch, new Vector3(-0.1f * k, 0.25f, 0.14f * k), 0.008f, 0.08f, gear);
        }
        if (L.backpack)
        {
            MeshKit.Box(ch, new Vector3(0, 0.07f, -0.19f * k), new Vector3(0.29f * k, 0.34f, 0.14f), Color.Lerp(uni, gear, 0.3f), default, 0.15f);
            MeshKit.Box(ch, new Vector3(0, -0.07f, -0.19f * k), new Vector3(0.24f * k, 0.08f, 0.15f), Color.Lerp(uni, gear, 0.5f));
        }

        // шея
        bool coveredNeck = L.head == HeadGear.Balaclava || L.head == HeadGear.GasMask || L.head == HeadGear.Hazmat || L.head == HeadGear.Cyborg || L.head == HeadGear.DeltaHelmet || L.head == HeadGear.HeavyHelmet;
        MeshKit.Cyl(b[Neck], new Vector3(0, 0.04f, 0), 0.105f, 0.11f, coveredNeck ? (L.head == HeadGear.Hazmat ? uni : L.head == HeadGear.Cyborg ? L.helmet : new Color(0.07f, 0.07f, 0.07f)) : skin);

        DressHead(L);

        // руки
        for (int side = 0; side < 2; side++)
        {
            var ua = b[side == 0 ? UArmL : UArmR];
            var la = b[side == 0 ? LArmL : LArmR];
            var h = b[side == 0 ? HandL : HandR];
            float sx = side == 0 ? -1 : 1;
            MeshKit.Taper(ua, new Vector3(0, -s.armU * 0.5f, 0), 0.085f * k, 0.108f * k, s.armU + 0.03f, uni);
            if (L.shoulderPads) MeshKit.Ball(ua, new Vector3(sx * 0.015f, -0.03f, 0), new Vector3(0.15f, 0.1f, 0.15f) * k, arm);
            MeshKit.Box(ua, new Vector3(sx * 0.048f * k, -0.08f, 0), new Vector3(0.01f, 0.05f, 0.05f), L.accent);  // нашивка на плече
            MeshKit.Taper(la, new Vector3(0, -s.armL * 0.5f, 0), 0.07f * k, 0.088f * k, s.armL + 0.02f, uni);
            if (L.heavy) MeshKit.Ball(la, new Vector3(0, 0.0f, -0.02f), new Vector3(0.09f, 0.08f, 0.09f) * k, arm);
            MeshKit.Cyl(la, new Vector3(0, -s.armL + 0.03f, 0), 0.078f * k, 0.05f, gear);
            Color glove = L.head == HeadGear.Bare ? skin : gear;
            MeshKit.Box(h, new Vector3(0, -0.045f, 0.005f), new Vector3(0.06f, 0.095f, 0.032f), glove);
            MeshKit.Box(h, new Vector3(sx * -0.032f, -0.03f, 0.015f), new Vector3(0.022f, 0.06f, 0.022f), glove, new Vector3(0, 0, sx * 25));
        }

        // ноги
        for (int side = 0; side < 2; side++)
        {
            var ul = b[side == 0 ? ULegL : ULegR];
            var ll = b[side == 0 ? LLegL : LLegR];
            var f = b[side == 0 ? FootL : FootR];
            float sx = side == 0 ? -1 : 1;
            MeshKit.Taper(ul, new Vector3(0, -s.legU * 0.5f, 0), 0.115f * k, 0.15f * k, s.legU + 0.04f, uni2);
            if (side == 1 && L.vest) MeshKit.Box(ul, new Vector3(sx * 0.075f * k, -0.12f, 0), new Vector3(0.04f, 0.14f, 0.07f), gear); // кобура
            if (side == 0) MeshKit.Box(ul, new Vector3(sx * 0.07f * k, -0.2f, 0.01f), new Vector3(0.03f, 0.1f, 0.08f), Color.Lerp(uni2, gear, 0.3f)); // карман
            MeshKit.Taper(ll, new Vector3(0, -s.legL * 0.5f, 0), 0.09f * k, 0.118f * k, s.legL + 0.02f, uni2);
            if (L.kneePads) MeshKit.Ball(ll, new Vector3(0, -0.01f, 0.045f), new Vector3(0.1f, 0.11f, 0.07f) * k, arm);
            MeshKit.Cyl(ll, new Vector3(0, -s.legL + 0.08f, 0), 0.1f * k, 0.14f, gear, default, 0.4f);
            MeshKit.Box(f, new Vector3(0, -0.035f, 0.045f), new Vector3(0.1f * k, 0.08f, 0.24f), gear, default, 0.4f);
            MeshKit.Box(f, new Vector3(0, -0.07f, 0.045f), new Vector3(0.105f * k, 0.02f, 0.25f), new Color(0.04f, 0.04f, 0.04f));
        }
    }

    void Face(Transform h, Color skin, bool eyes = true)
    {
        MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.195f, 0.245f, 0.215f), skin);
        if (!eyes) return;
        MeshKit.Ball(h, new Vector3(-0.042f, 0.125f, 0.096f), Vector3.one * 0.028f, new Color(0.95f, 0.95f, 0.95f), default, 0.7f);
        MeshKit.Ball(h, new Vector3(0.042f, 0.125f, 0.096f), Vector3.one * 0.028f, new Color(0.95f, 0.95f, 0.95f), default, 0.7f);
        MeshKit.Ball(h, new Vector3(-0.042f, 0.125f, 0.108f), Vector3.one * 0.014f, new Color(0.08f, 0.06f, 0.05f), default, 0.8f);
        MeshKit.Ball(h, new Vector3(0.042f, 0.125f, 0.108f), Vector3.one * 0.014f, new Color(0.08f, 0.06f, 0.05f), default, 0.8f);
        MeshKit.Box(h, new Vector3(0, 0.1f, 0.112f), new Vector3(0.028f, 0.05f, 0.03f), skin * 0.95f);
        MeshKit.Box(h, new Vector3(0, 0.05f, 0.1f), new Vector3(0.05f, 0.01f, 0.01f), skin * 0.6f);
        MeshKit.Ball(h, new Vector3(-0.1f, 0.11f, 0), new Vector3(0.025f, 0.05f, 0.035f), skin * 0.95f);
        MeshKit.Ball(h, new Vector3(0.1f, 0.11f, 0), new Vector3(0.025f, 0.05f, 0.035f), skin * 0.95f);
        MeshKit.Box(h, new Vector3(-0.042f, 0.155f, 0.1f), new Vector3(0.04f, 0.008f, 0.01f), skin * 0.45f);
        MeshKit.Box(h, new Vector3(0.042f, 0.155f, 0.1f), new Vector3(0.04f, 0.008f, 0.01f), skin * 0.45f);
    }

    void DressHead(Look L)
    {
        var h = b[Head];
        Color dark = new Color(0.06f, 0.06f, 0.06f);
        var visorMat = Mats.Glass(L.visor, 0.95f, L.visorGlow);
        switch (L.head)
        {
            case HeadGear.Helmet:
                Face(h, L.skin);
                MeshKit.Ball(h, new Vector3(0, 0.165f, -0.005f), new Vector3(0.255f, 0.205f, 0.27f), L.helmet, default, 0.3f);
                MeshKit.Box(h, new Vector3(0, 0.19f, 0.12f), new Vector3(0.08f, 0.04f, 0.04f), dark); // крепление ПНВ
                MeshKit.Box(h, new Vector3(0, 0.12f, 0.115f), new Vector3(0.205f, 0.065f, 0.03f), visorMat);
                MeshKit.Box(h, new Vector3(-0.125f, 0.11f, 0), new Vector3(0.03f, 0.07f, 0.07f), dark);
                MeshKit.Box(h, new Vector3(0.125f, 0.11f, 0), new Vector3(0.03f, 0.07f, 0.07f), dark);
                MeshKit.Box(h, new Vector3(0.13f, 0.2f, -0.02f), new Vector3(0.012f, 0.03f, 0.08f), L.accent);
                break;
            case HeadGear.HeavyHelmet:
                MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.2f, 0.245f, 0.215f), dark);
                MeshKit.Ball(h, new Vector3(0, 0.14f, 0f), new Vector3(0.29f, 0.29f, 0.3f), L.helmet, default, 0.35f);
                MeshKit.Box(h, new Vector3(0, 0.1f, 0.13f), new Vector3(0.22f, 0.12f, 0.04f), visorMat);
                MeshKit.Box(h, new Vector3(0, 0.03f, 0.1f), new Vector3(0.16f, 0.06f, 0.07f), L.helmet);
                MeshKit.Box(h, new Vector3(0, 0.27f, 0f), new Vector3(0.04f, 0.03f, 0.2f), L.accent);
                break;
            case HeadGear.GasMask:
                MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.205f, 0.25f, 0.225f), new Color(0.12f, 0.12f, 0.11f), default, 0.5f);
                MeshKit.Cyl(h, new Vector3(-0.045f, 0.13f, 0.1f), 0.055f, 0.02f, visorMat, new Vector3(90, 0, 0));
                MeshKit.Cyl(h, new Vector3(0.045f, 0.13f, 0.1f), 0.055f, 0.02f, visorMat, new Vector3(90, 0, 0));
                MeshKit.Cyl(h, new Vector3(0, 0.055f, 0.125f), 0.07f, 0.06f, dark, new Vector3(70, 0, 0));
                MeshKit.Cyl(h, new Vector3(0.06f, 0.05f, 0.11f), 0.065f, 0.05f, new Color(0.2f, 0.22f, 0.15f), new Vector3(70, 0, -50));
                MeshKit.Ball(h, new Vector3(0, 0.18f, -0.01f), new Vector3(0.24f, 0.17f, 0.26f), L.helmet, default, 0.3f);
                break;
            case HeadGear.Hazmat:
                MeshKit.Ball(h, new Vector3(0, 0.12f, 0f), new Vector3(0.27f, 0.32f, 0.28f), L.uniform, default, 0.45f);
                MeshKit.Box(h, new Vector3(0, 0.12f, 0.122f), new Vector3(0.17f, 0.12f, 0.03f), visorMat);
                Face(h, L.skin);
                MeshKit.Cyl(h, new Vector3(0.0f, 0.04f, 0.13f), 0.07f, 0.06f, dark, new Vector3(75, 0, 0));
                MeshKit.Cyl(h, new Vector3(0.09f, 0.04f, 0.09f), 0.06f, 0.06f, new Color(0.15f, 0.15f, 0.15f), new Vector3(70, 0, -60));
                break;
            case HeadGear.Balaclava:
                MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.205f, 0.25f, 0.222f), new Color(0.07f, 0.07f, 0.07f), default, 0.1f);
                MeshKit.Box(h, new Vector3(0, 0.127f, 0.1f), new Vector3(0.13f, 0.035f, 0.025f), L.skin);
                MeshKit.Ball(h, new Vector3(-0.04f, 0.127f, 0.11f), Vector3.one * 0.02f, new Color(0.1f, 0.08f, 0.06f), default, 0.8f);
                MeshKit.Ball(h, new Vector3(0.04f, 0.127f, 0.11f), Vector3.one * 0.02f, new Color(0.1f, 0.08f, 0.06f), default, 0.8f);
                break;
            case HeadGear.NightVision:
                Face(h, L.skin);
                MeshKit.Ball(h, new Vector3(0, 0.165f, -0.005f), new Vector3(0.255f, 0.205f, 0.27f), L.helmet, default, 0.3f);
                for (int i = 0; i < 4; i++)
                {
                    float x = (i - 1.5f) * 0.035f;
                    MeshKit.Cyl(h, new Vector3(x, 0.135f, 0.14f), 0.032f, 0.07f, dark, new Vector3(90, 0, 0));
                    MeshKit.Cyl(h, new Vector3(x, 0.135f, 0.177f), 0.026f, 0.005f, Mats.Glow(new Color(0.2f, 1f, 0.3f), 3f), new Vector3(90, 0, 0));
                }
                MeshKit.Box(h, new Vector3(0, 0.19f, 0.12f), new Vector3(0.09f, 0.05f, 0.05f), dark);
                break;
            case HeadGear.Cap:
                Face(h, L.skin);
                MeshKit.Ball(h, new Vector3(0, 0.185f, 0f), new Vector3(0.215f, 0.12f, 0.232f), L.helmet);
                MeshKit.Box(h, new Vector3(0, 0.185f, 0.13f), new Vector3(0.17f, 0.012f, 0.1f), L.helmet);
                MeshKit.Box(h, new Vector3(0, 0.127f, 0.112f), new Vector3(0.14f, 0.035f, 0.02f), Mats.Glass(new Color(0.05f, 0.05f, 0.05f, 0.85f)));
                break;
            case HeadGear.Cyborg:
                MeshKit.Ball(h, new Vector3(0, 0.12f, 0.005f), new Vector3(0.245f, 0.29f, 0.262f), L.helmet, default, 0.75f);
                MeshKit.Box(h, new Vector3(0, 0.135f, 0.122f), new Vector3(0.17f, 0.03f, 0.03f), Mats.Glow(L.accent, 3f));
                MeshKit.Box(h, new Vector3(0, 0.085f, 0.13f), new Vector3(0.02f, 0.07f, 0.02f), Mats.Glow(L.accent, 2f));
                MeshKit.Box(h, new Vector3(-0.125f, 0.12f, 0), new Vector3(0.025f, 0.09f, 0.1f), new Color(0.6f, 0.62f, 0.65f), default, 0.6f, 0.5f);
                MeshKit.Box(h, new Vector3(0.125f, 0.12f, 0), new Vector3(0.025f, 0.09f, 0.1f), new Color(0.6f, 0.62f, 0.65f), default, 0.6f, 0.5f);
                break;
            case HeadGear.DeltaHelmet:
                MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.205f, 0.25f, 0.222f), dark);
                MeshKit.Ball(h, new Vector3(0, 0.165f, -0.005f), new Vector3(0.26f, 0.21f, 0.275f), L.helmet, default, 0.3f);
                MeshKit.Box(h, new Vector3(0, 0.07f, 0.1f), new Vector3(0.17f, 0.11f, 0.05f), new Color(0.05f, 0.05f, 0.05f));
                MeshKit.Box(h, new Vector3(0, 0.128f, 0.116f), new Vector3(0.18f, 0.035f, 0.025f), Mats.Glow(new Color(1f, 0.08f, 0.04f), 3.5f));
                break;
            default: // Bare — заключённый класса D
                Face(h, L.skin);
                MeshKit.Ball(h, new Vector3(0, 0.17f, -0.01f), new Vector3(0.2f, 0.15f, 0.21f), L.skin * 0.75f);
                break;
        }
    }
}
