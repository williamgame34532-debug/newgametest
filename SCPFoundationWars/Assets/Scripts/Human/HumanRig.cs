using UnityEngine;

// Пропорции тела (для бойцов и человекоподобных SCP)
public class BodyShape
{
    public float armU = 0.29f, armL = 0.27f, legU = 0.45f, legL = 0.44f;
    public float shoulder = 0.2f, torso = 1f, neck = 1f, bulk = 1f, headSize = 1f;

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
        rig.hipsHeight = s.legU + s.legL + 0.075f;
        float tor = s.torso;
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

        rig.aimPivot = new GameObject("aimPivot").transform;
        rig.aimPivot.SetParent(chest, false);
        rig.aimPivot.localPosition = new Vector3(0.1f, 0.17f * tor, 0.02f);

        rig.eye = new GameObject("eye").transform;
        rig.eye.SetParent(rig.b[Head], false);
        rig.eye.localPosition = new Vector3(0, 0.12f * s.headSize, 0.1f);
        rig.headTop = new GameObject("headTop").transform;
        rig.headTop.SetParent(rig.b[Head], false);
        rig.headTop.localPosition = new Vector3(0, 0.25f * s.headSize, 0);
        rig.hipsRest = hips.localPosition;
        return rig;
    }

    // Объединяет детали каждой кости в один меш (меньше отрисовок)
    public void Finish()
    {
        foreach (var t in b) MeshKit.CombineParts(t);
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
