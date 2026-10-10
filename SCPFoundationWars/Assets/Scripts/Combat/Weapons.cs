using UnityEngine;

// Модель оружия: точки хвата, дульный срез, магазин, прицел.
public class GunModel : MonoBehaviour
{
    public WeaponDef def;
    public Transform muzzle, grip, foregrip, mag, sight, pump;
    public Vector3 magRest;
    public Vector3 pumpRest;
    public Light flashlight;
}

public static class WeaponModels
{
    static Color Dark(Color c, float k) => new Color(c.r * k, c.g * k, c.b * k, 1);

    // Модель из шаблона (Resources/Models/guns.txt + M4 из FBX); если шаблона нет — старая процедурная
    public static GunModel Build(WeaponDef def, Transform parent, bool flashlight = false)
    {
        var tpl = ModelLib.Gun(def);
        if (tpl == null || tpl.body == null) return BuildProcedural(def, parent, flashlight);
        var root = new GameObject("gun_" + def.id);
        root.transform.SetParent(parent, false);
        var gm = root.AddComponent<GunModel>();
        gm.def = def;
        var t = root.transform;
        GameObject Piece(string n, Mesh m, Material[] mats, Vector3 pos)
        {
            var g = new GameObject(n);
            g.transform.SetParent(t, false);
            g.transform.localPosition = pos;
            g.AddComponent<MeshFilter>().sharedMesh = m;
            g.AddComponent<MeshRenderer>().sharedMaterials = mats;
            return g;
        }
        Piece("body", tpl.body, tpl.bodyMats, Vector3.zero);
        if (tpl.mag != null) gm.mag = Piece("mag", tpl.mag, tpl.magMats, tpl.magPos).transform;
        if (tpl.pump != null) { gm.pump = Piece("pump", tpl.pump, tpl.pumpMats, tpl.pumpPos).transform; gm.pumpRest = tpl.pumpPos; }
        Transform Anchor(string n, Vector3 p) { var g = new GameObject(n).transform; g.SetParent(t, false); g.localPosition = p; return g; }
        gm.muzzle = Anchor("muzzle", tpl.muzzle);
        gm.grip = Anchor("grip", tpl.grip);
        gm.foregrip = Anchor("foregrip", tpl.fore);
        gm.sight = Anchor("sight", tpl.sight);
        if (gm.mag != null) gm.magRest = gm.mag.localPosition;
        bool light = def.kind == WeaponKind.Rifle || def.kind == WeaponKind.SMG || def.kind == WeaponKind.LMG || def.kind == WeaponKind.Shotgun;
        if (light)
        {
            var lt = Anchor("lightMod", new Vector3(0.036f, 0.03f, tpl.fore.z + 0.04f));
            MeshKit.Cyl(lt, Vector3.zero, 0.028f, 0.08f, new Color(0.07f, 0.07f, 0.07f), new Vector3(90, 0, 0));
            MeshKit.Cyl(lt, new Vector3(0, 0, 0.041f), 0.024f, 0.003f, Mats.Glow(new Color(1f, 0.95f, 0.8f), 1.5f), new Vector3(90, 0, 0));
            if (flashlight)
            {
                var lgo = new GameObject("flashlight");
                lgo.transform.SetParent(lt, false);
                lgo.transform.localPosition = new Vector3(0, 0, 0.05f);
                var l = lgo.AddComponent<Light>();
                l.type = LightType.Spot; l.spotAngle = 42; l.range = 30; l.intensity = 2.2f;
                l.color = new Color(1f, 0.96f, 0.86f); l.shadows = LightShadows.None;
                gm.flashlight = l;
            }
        }
        return gm;
    }

    static GunModel BuildProcedural(WeaponDef def, Transform parent, bool flashlight)
    {
        var root = new GameObject("gun_" + def.id);
        root.transform.SetParent(parent, false);
        var gm = root.AddComponent<GunModel>();
        gm.def = def;
        var t = root.transform;
        Color b = def.body, a = def.accent, metal = new Color(0.08f, 0.08f, 0.085f);
        float L = def.length;

        Transform Anchor(string n, Vector3 p) { var g = new GameObject(n).transform; g.SetParent(t, false); g.localPosition = p; return g; }

        switch (def.kind)
        {
            case WeaponKind.Pistol:
                MeshKit.Box(t, new Vector3(0, 0.045f, 0.06f), new Vector3(0.032f, 0.038f, 0.19f), b, default, 0.5f, 0.6f);      // затвор
                MeshKit.Box(t, new Vector3(0, 0.02f, 0.05f), new Vector3(0.03f, 0.02f, 0.16f), Dark(b, 0.8f));
                MeshKit.Box(t, new Vector3(0, -0.03f, -0.01f), new Vector3(0.028f, 0.1f, 0.045f), a, new Vector3(-12, 0, 0)); // рукоять
                MeshKit.Box(t, new Vector3(0, 0.0f, 0.03f), new Vector3(0.01f, 0.025f, 0.035f), metal);                         // скоба
                gm.mag = MeshKit.Box(t, new Vector3(0, -0.07f, -0.015f), new Vector3(0.022f, 0.03f, 0.035f), metal, new Vector3(-12, 0, 0)).transform;
                gm.muzzle = Anchor("muzzle", new Vector3(0, 0.048f, 0.16f));
                gm.grip = Anchor("grip", new Vector3(0, -0.02f, -0.01f));
                gm.foregrip = Anchor("foregrip", new Vector3(-0.025f, -0.04f, 0.0f));
                gm.sight = Anchor("sight", new Vector3(0, 0.075f, -0.03f));
                break;

            case WeaponKind.Launcher:
                if (def.id == "rpg")
                {
                    MeshKit.Cyl(t, new Vector3(0, 0.08f, 0.05f), 0.07f, 1.0f, b, new Vector3(90, 0, 0));
                    MeshKit.Cyl(t, new Vector3(0, 0.08f, -0.1f), 0.085f, 0.25f, a, new Vector3(90, 0, 0)); // деревянная накладка
                    MeshKit.Part(t, MeshKit.Frustum(0.25f), Mats.Get(new Color(0.25f, 0.28f, 0.2f)), new Vector3(0, 0.08f, 0.68f), new Vector3(0.11f, 0.22f, 0.11f), new Vector3(90, 0, 0)); // боеголовка
                    MeshKit.Part(t, MeshKit.Frustum(0.4f), Mats.Get(new Color(0.25f, 0.28f, 0.2f)), new Vector3(0, 0.08f, 0.53f), new Vector3(0.11f, 0.1f, 0.11f), new Vector3(-90, 0, 0));
                    gm.mag = MeshKit.Cyl(t, new Vector3(0, 0.08f, 0.62f), 0.05f, 0.05f, metal, new Vector3(90, 0, 0)).transform;
                    MeshKit.Box(t, new Vector3(0, -0.02f, 0), new Vector3(0.03f, 0.1f, 0.04f), metal, new Vector3(-10, 0, 0));
                    MeshKit.Box(t, new Vector3(0, -0.02f, 0.2f), new Vector3(0.03f, 0.1f, 0.04f), metal, new Vector3(-10, 0, 0));
                    MeshKit.Box(t, new Vector3(-0.045f, 0.13f, 0.12f), new Vector3(0.02f, 0.05f, 0.08f), metal);
                    gm.muzzle = Anchor("muzzle", new Vector3(0, 0.08f, 0.8f));
                    gm.foregrip = Anchor("foregrip", new Vector3(0, -0.04f, 0.2f));
                    gm.sight = Anchor("sight", new Vector3(-0.045f, 0.165f, 0.05f));
                }
                else
                {
                    MeshKit.Cyl(t, new Vector3(0, 0.05f, 0.18f), 0.06f, 0.36f, b, new Vector3(90, 0, 0));
                    gm.mag = MeshKit.Cyl(t, new Vector3(0, 0.03f, 0.02f), 0.15f, 0.13f, Dark(b, 0.7f), new Vector3(90, 0, 0)).transform; // барабан
                    MeshKit.Box(t, new Vector3(0, 0.0f, -0.18f), new Vector3(0.05f, 0.08f, 0.24f), metal);
                    MeshKit.Box(t, new Vector3(0, -0.05f, -0.02f), new Vector3(0.03f, 0.1f, 0.04f), metal, new Vector3(-12, 0, 0));
                    MeshKit.Box(t, new Vector3(0, -0.04f, 0.22f), new Vector3(0.03f, 0.09f, 0.04f), metal, new Vector3(-8, 0, 0));
                    gm.muzzle = Anchor("muzzle", new Vector3(0, 0.05f, 0.38f));
                    gm.foregrip = Anchor("foregrip", new Vector3(0, -0.05f, 0.22f));
                    gm.sight = Anchor("sight", new Vector3(0, 0.12f, -0.02f));
                    MeshKit.Box(t, new Vector3(0, 0.1f, 0.0f), new Vector3(0.035f, 0.035f, 0.06f), metal);
                    MeshKit.Box(t, new Vector3(0, 0.11f, 0.03f), new Vector3(0.025f, 0.02f, 0.004f), Mats.Glass(new Color(0.4f, 0.1f, 0.1f, 0.4f), 0.9f, true));
                }
                gm.grip = Anchor("grip", new Vector3(0, -0.03f, 0));
                break;

            default:
            {
                bool lmg = def.kind == WeaponKind.LMG, sg = def.kind == WeaponKind.Shotgun, sn = def.kind == WeaponKind.Sniper, smg = def.kind == WeaponKind.SMG;
                float recvLen = smg ? 0.24f : lmg ? 0.36f : 0.3f;
                float recvH = lmg ? 0.11f : 0.085f;
                MeshKit.Box(t, new Vector3(0, 0.035f, 0.06f), new Vector3(0.06f, recvH, recvLen), b, default, 0.35f, 0.3f);           // ствольная коробка
                MeshKit.Box(t, new Vector3(0, 0.085f, 0.07f), new Vector3(0.022f, 0.012f, recvLen * 0.95f), metal, default, 0.4f, 0.5f); // планка
                float barrelStart = 0.06f + recvLen * 0.5f;
                float barrelLen = Mathf.Max(0.12f, L - recvLen * 0.5f - 0.1f);
                MeshKit.Cyl(t, new Vector3(0, 0.045f, barrelStart + barrelLen * 0.5f), sg ? 0.032f : 0.022f, barrelLen, metal, new Vector3(90, 0, 0), 0.5f, 0.7f);
                // цевьё
                float hgLen = barrelLen * (sn ? 0.55f : 0.65f);
                if (sg)
                {
                    MeshKit.Cyl(t, new Vector3(0, 0.015f, barrelStart + barrelLen * 0.45f), 0.028f, barrelLen * 0.85f, metal, new Vector3(90, 0, 0));
                    gm.pump = MeshKit.Box(t, new Vector3(0, 0.012f, barrelStart + 0.12f), new Vector3(0.05f, 0.045f, 0.16f), a).transform;
                    gm.pumpRest = gm.pump.localPosition;
                }
                else
                    MeshKit.Box(t, new Vector3(0, 0.04f, barrelStart + hgLen * 0.5f), new Vector3(0.058f, 0.062f, hgLen), smg ? b : a, default, 0.3f);
                // приклад
                if (!smg || def.id != "p90")
                {
                    MeshKit.Box(t, new Vector3(0, 0.02f, -0.17f), new Vector3(0.04f, 0.075f, 0.22f), sn || sg || def.id == "ak" ? a : Dark(b, 0.9f), new Vector3(4, 0, 0));
                    MeshKit.Box(t, new Vector3(0, 0.0f, -0.285f), new Vector3(0.045f, 0.12f, 0.025f), metal);
                }
                else
                    MeshKit.Box(t, new Vector3(0, 0.0f, -0.12f), new Vector3(0.065f, 0.1f, 0.16f), b);
                // рукоять
                MeshKit.Box(t, new Vector3(0, -0.045f, -0.015f), new Vector3(0.03f, 0.09f, 0.042f), Dark(b, 0.8f), new Vector3(-16, 0, 0));
                MeshKit.Box(t, new Vector3(0, -0.01f, 0.035f), new Vector3(0.012f, 0.03f, 0.05f), metal);
                // магазин
                if (lmg)
                {
                    gm.mag = MeshKit.Box(t, new Vector3(0.0f, -0.05f, 0.1f), new Vector3(0.09f, 0.1f, 0.11f), new Color(0.2f, 0.22f, 0.17f)).transform;
                    MeshKit.Box(t, new Vector3(0, 0.12f, 0.06f), new Vector3(0.02f, 0.03f, 0.14f), metal);   // ручка
                    // сошки
                    MeshKit.Cyl(t, new Vector3(0.025f, -0.05f, barrelStart + barrelLen * 0.75f), 0.012f, 0.22f, metal, new Vector3(-20, 0, 15));
                    MeshKit.Cyl(t, new Vector3(-0.025f, -0.05f, barrelStart + barrelLen * 0.75f), 0.012f, 0.22f, metal, new Vector3(-20, 0, -15));
                }
                else if (sg)
                    gm.mag = MeshKit.Box(t, new Vector3(0, -0.02f, 0.1f), new Vector3(0.03f, 0.02f, 0.05f), metal).transform;
                else if (def.id == "p90")
                    gm.mag = MeshKit.Box(t, new Vector3(0, 0.1f, 0.02f), new Vector3(0.05f, 0.02f, 0.26f), Mats.Glass(new Color(0.6f, 0.55f, 0.3f, 0.6f), 0.8f)).transform;
                else
                {
                    float magLen = smg ? 0.14f : sn ? 0.09f : 0.17f;
                    var mag = new GameObject("p").transform;
                    mag.SetParent(t, false);
                    mag.localPosition = new Vector3(0, -0.02f, 0.11f);
                    mag.localRotation = Quaternion.Euler(def.id == "ak" ? 18 : 8, 0, 0);
                    MeshKit.Box(mag, new Vector3(0, -magLen * 0.5f, 0), new Vector3(0.028f, magLen, 0.065f), metal);
                    if (def.id == "ak") MeshKit.Box(mag, new Vector3(0, -magLen, 0.02f), new Vector3(0.028f, 0.06f, 0.06f), metal, new Vector3(25, 0, 0));
                    gm.mag = mag;
                }
                // прицел
                float sightY = 0.105f;
                if (def.scope)
                {
                    MeshKit.Cyl(t, new Vector3(0, 0.125f, 0.05f), 0.042f, 0.3f, metal, new Vector3(90, 0, 0), 0.6f, 0.6f);
                    MeshKit.Cyl(t, new Vector3(0, 0.125f, 0.2f), 0.055f, 0.05f, metal, new Vector3(90, 0, 0));
                    MeshKit.Cyl(t, new Vector3(0, 0.125f, -0.1f), 0.05f, 0.04f, metal, new Vector3(90, 0, 0));
                    MeshKit.Cyl(t, new Vector3(0, 0.125f, 0.226f), 0.046f, 0.004f, Mats.Glass(new Color(0.2f, 0.4f, 0.6f, 0.6f), 1f, true), new Vector3(90, 0, 0));
                    sightY = 0.125f;
                }
                else if (def.redDot)
                {
                    MeshKit.Box(t, new Vector3(0, 0.11f, 0.02f), new Vector3(0.035f, 0.035f, 0.07f), metal);
                    MeshKit.Box(t, new Vector3(0, 0.118f, 0.055f), new Vector3(0.028f, 0.022f, 0.003f), Mats.Glass(new Color(0.5f, 0.15f, 0.1f, 0.35f), 0.95f));
                    MeshKit.Ball(t, new Vector3(0, 0.118f, 0.04f), Vector3.one * 0.004f, Mats.Glow(new Color(1, 0.1f, 0.05f), 6f));
                    sightY = 0.118f;
                }
                else
                {
                    MeshKit.Box(t, new Vector3(0, 0.098f, barrelStart + barrelLen - 0.04f), new Vector3(0.008f, 0.03f, 0.01f), metal);
                    MeshKit.Box(t, new Vector3(0, 0.1f, -0.03f), new Vector3(0.03f, 0.02f, 0.012f), metal);
                    sightY = 0.112f;
                }
                if (sn)
                {
                    MeshKit.Cyl(t, new Vector3(0.02f, -0.02f, barrelStart + barrelLen * 0.6f), 0.01f, 0.2f, metal, new Vector3(-25, 0, 12));
                    MeshKit.Cyl(t, new Vector3(-0.02f, -0.02f, barrelStart + barrelLen * 0.6f), 0.01f, 0.2f, metal, new Vector3(-25, 0, -12));
                }
                float muzzleZ = barrelStart + barrelLen;
                if (def.suppressor)
                {
                    MeshKit.Cyl(t, new Vector3(0, 0.045f, muzzleZ + 0.08f), 0.042f, 0.17f, new Color(0.06f, 0.06f, 0.06f), new Vector3(90, 0, 0));
                    muzzleZ += 0.17f;
                }
                else
                    MeshKit.Cyl(t, new Vector3(0, 0.045f, muzzleZ), 0.032f, 0.04f, metal, new Vector3(90, 0, 0));
                gm.muzzle = Anchor("muzzle", new Vector3(0, 0.045f, muzzleZ + 0.02f));
                gm.grip = Anchor("grip", new Vector3(0, -0.035f, -0.02f));
                gm.foregrip = Anchor("foregrip", sg && gm.pump != null ? gm.pumpRest + new Vector3(0, -0.02f, 0) : new Vector3(0, 0.0f, barrelStart + hgLen * (lmg ? 0.35f : 0.5f)));
                gm.sight = Anchor("sight", new Vector3(0, sightY, -0.06f));
                if (flashlight || smg || def.kind == WeaponKind.Rifle)
                {
                    MeshKit.Cyl(t, new Vector3(0.04f, 0.03f, barrelStart + 0.08f), 0.03f, 0.08f, metal, new Vector3(90, 0, 0));
                    MeshKit.Cyl(t, new Vector3(0.04f, 0.03f, barrelStart + 0.121f), 0.026f, 0.003f, Mats.Glow(new Color(1f, 0.95f, 0.8f), 1.5f), new Vector3(90, 0, 0));
                    if (flashlight)
                    {
                        var lgo = new GameObject("flashlight");
                        lgo.transform.SetParent(t, false);
                        lgo.transform.localPosition = new Vector3(0.04f, 0.03f, barrelStart + 0.13f);
                        var l = lgo.AddComponent<Light>();
                        l.type = LightType.Spot;
                        l.spotAngle = 42;
                        l.range = 30;
                        l.intensity = 2.2f;
                        l.color = new Color(1f, 0.96f, 0.86f);
                        l.shadows = LightShadows.None;
                        gm.flashlight = l;
                    }
                }
                break;
            }
        }
        if (gm.mag != null) gm.magRest = gm.mag.localPosition;
        MeshKit.NoShadows(root);
        foreach (var r in root.GetComponentsInChildren<MeshRenderer>()) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
        return gm;
    }
}

// Оружие в руках: патроны, перезарядка, темп стрельбы
public class Gun
{
    public WeaponDef def;
    public int ammo;
    public int reserveMags = 99;
    public float nextFire;
    public bool reloading;
    public float reloadStart, reloadEnd;
    public GunModel model;

    public Gun(WeaponDef d) { def = d; ammo = d.mag; }

    public float ReloadProgress => reloading ? Mathf.Clamp01((Time.time - reloadStart) / Mathf.Max(0.01f, reloadEnd - reloadStart)) : 0f;
    public bool Ready => (!reloading || (Shells && ammo > 0)) && ammo > 0 && Time.time >= nextFire;

    // дробовик заряжается по одному патрону
    public bool Shells => def.kind == WeaponKind.Shotgun;
    const float ShellTime = 0.48f, ShellLead = 0.35f;
    int shellsLoaded;
    public float ShellPhase => !reloading || !Shells ? 0f : Mathf.Repeat((Time.time - reloadStart - ShellLead) / ShellTime, 1f);

    public void StartReload(Vector3 pos, float speedMul = 1f)
    {
        if (reloading || ammo >= def.mag || reserveMags <= 0) return;
        reloading = true;
        reloadStart = Time.time;
        shellsLoaded = 0;
        float dur = Shells ? ShellLead + ShellTime * (def.mag - ammo) + 0.3f : def.reload;
        reloadEnd = Time.time + dur / Mathf.Max(0.2f, speedMul);
        Sfx.Play(Shells ? "click" : "magout", pos, 0.5f, Random.Range(0.9f, 1.1f), 25f);
    }

    public void Tick(Vector3 pos)
    {
        if (reloading && Shells)
        {
            int should = Mathf.FloorToInt((Time.time - reloadStart - ShellLead) / ShellTime);
            while (shellsLoaded < should && ammo < def.mag)
            {
                shellsLoaded++; ammo++;
                Sfx.Play("magin", pos, 0.35f, Random.Range(1.3f, 1.5f), 20f);
            }
            if (ammo >= def.mag && Time.time >= reloadEnd - 0.3f && Time.time < reloadEnd) { }
            if (Time.time >= reloadEnd) { reloading = false; Sfx.Play("bolt", pos, 0.5f, 1f, 25f); }
            return;
        }
        if (reloading && Time.time >= reloadEnd)
        {
            reloading = false;
            ammo = def.mag;
            if (reserveMags < 99) reserveMags--;
            Sfx.Play(def.kind == WeaponKind.Shotgun || def.kind == WeaponKind.Sniper ? "bolt" : "magin", pos, 0.55f, Random.Range(0.9f, 1.1f), 25f);
        }
    }

    public void CancelReload() { reloading = false; }

    // Выстрел из origin по направлению dir. muzzle — откуда рисуется трассер.
    public bool Fire(Unit owner, Vector3 origin, Vector3 dir, float spreadMul, Vector3 muzzle)
    {
        if (!Ready) return false;
        if (reloading) reloading = false; // выстрел прерывает зарядку дробовика
        ammo--;
        nextFire = Time.time + def.Interval;
        Ballistics.Fire(def, owner, origin, dir, spreadMul, muzzle);
        return true;
    }
}

public static class Ballistics
{
    public static PlayerController player;

    public static Color TracerColor(Team t)
    {
        switch (t)
        {
            case Team.Foundation: return new Color(0.75f, 0.85f, 1f, 0.9f);
            case Team.Chaos: return new Color(1f, 0.75f, 0.3f, 0.9f);
            default: return new Color(1f, 0.4f, 0.3f, 0.9f);
        }
    }

    public static string SoundFor(WeaponDef def)
    {
        if (def.suppressor) return "suppressed";
        switch (def.kind)
        {
            case WeaponKind.SMG: return "smg";
            case WeaponKind.LMG: return "lmg";
            case WeaponKind.Pistol: return "pistol";
            case WeaponKind.Shotgun: return "shotgun";
            case WeaponKind.Sniper: return "sniper";
            case WeaponKind.Launcher: return "rocket";
            default: return "rifle";
        }
    }

    public static void Fire(WeaponDef def, Unit owner, Vector3 origin, Vector3 dir, float spreadMul, Vector3 muzzle)
    {
        bool isPlayer = owner != null && owner.isPlayer;
        Sfx.Play(SoundFor(def), muzzle, isPlayer ? 0.85f : 0.75f, Random.Range(0.93f, 1.07f), def.suppressor ? 40f : def.kind == WeaponKind.Sniper ? 400f : 220f, isPlayer ? 0.4f : 1f);
        Fx.MuzzleFlash(muzzle, dir, def.kind == WeaponKind.Shotgun || def.kind == WeaponKind.LMG ? 1.3f : def.kind == WeaponKind.Pistol ? 0.7f : 1f, def.suppressor);

        if (def.kind == WeaponKind.Launcher)
        {
            Vector3 d = Spread(dir, def.spread * spreadMul);
            if (def.id == "rpg") Rocket.Spawn(muzzle + d * 0.2f, d, owner, def);
            else Grenade.Spawn(muzzle + d * 0.2f, d * 38f + Vector3.up * 2f, owner, true, def.damage);
            return;
        }

        Color tc = TracerColor(owner != null ? owner.team : Team.Foundation);
        for (int p = 0; p < def.pellets; p++)
        {
            Vector3 d = Spread(dir, def.spread * spreadMul);
            Vector3 end = origin + d * def.range;
            if (Combat.Ray(origin, d, def.range, owner, out var hit))
            {
                end = hit.point;
                float falloff = Mathf.Lerp(1f, 0.6f, Mathf.InverseLerp(def.range * 0.5f, def.range, hit.distance));
                HitSurface(hit, d, def.damage * falloff, def.force / def.pellets, owner, def.name);
            }
            if (def.pellets == 1 || p % 3 == 0)
                Fx.TracerLine(muzzle, end, tc, def.kind == WeaponKind.Sniper ? 0.06f : 0.035f);
            // свист пуль рядом с игроком
            if (player != null && player.unit.alive && owner != player.unit)
            {
                Vector3 e = player.unit.EyePos;
                Vector3 toE = e - origin;
                float along = Vector3.Dot(toE, d);
                if (along > 2f && along < Vector3.Distance(origin, end))
                {
                    float miss = (toE - d * along).magnitude;
                    if (miss < 1.4f && Random.value < 0.5f)
                    {
                        Sfx.Play("whoosh", origin + d * along, 0.35f, Random.Range(1.6f, 2.4f), 10f);
                        player.Suppress(0.15f);
                    }
                }
            }
        }
    }

    public static Vector3 Spread(Vector3 dir, float deg)
    {
        if (deg <= 0.001f) return dir;
        Vector2 r = Random.insideUnitCircle * Mathf.Tan(deg * Mathf.Deg2Rad);
        var rot = Quaternion.LookRotation(dir);
        return (dir + rot * new Vector3(r.x, r.y, 0)).normalized;
    }

    public static void HitSurface(RaycastHit hit, Vector3 dir, float damage, float force, Unit attacker, string weapon)
    {
        var hb = hit.collider.GetComponent<Hitbox>();
        if (hb != null && hb.owner != null)
        {
            var u = hb.owner;
            u.HitFx(hit.point, hit.normal, dir, hb);
            if (u.alive)
            {
                u.TakeDamage(new DamageInfo { amount = damage * hb.mul, point = hit.point, dir = dir, force = force, attacker = attacker, hitbox = hb, type = DamageType.Bullet, weapon = weapon });
                if (attacker != null && attacker.isPlayer && player != null) player.HitMarker(!u.alive, hb.head);
            }
            else if (hb.rb != null)
            {
                u.CorpseHit(hb, hit.point, dir * force);
            }
            return;
        }
        var heli = hit.collider.GetComponentInParent<Helicopter>();
        if (heli != null)
        {
            heli.Damage(damage * 0.6f, attacker);
            Fx.Sparks(hit.point, hit.normal, 6);
            if (Random.value < 0.4f) Sfx.Play("metal", hit.point, 0.4f, Random.Range(0.8f, 1.2f), 60f);
            Fx.BulletHole(hit.point, hit.normal, hit.collider.transform);
            return;
        }
        var cont = hit.collider.GetComponentInParent<ScpContainer>();
        var rb = hit.collider.attachedRigidbody;
        if (rb != null && !rb.isKinematic) rb.AddForceAtPosition(dir * force * 0.2f, hit.point, ForceMode.Impulse);
        var surf = hit.collider.GetComponent<Surface>();
        bool metal = cont != null || (surf != null && surf.metal);
        Color c = surf != null ? surf.color : new Color(0.4f, 0.36f, 0.3f);
        Fx.Impact(hit.point, hit.normal, c, metal);
        Fx.BulletHole(hit.point, hit.normal, hit.collider.transform);
        float r = Random.value;
        if (r < 0.12f) Sfx.Play("ricochet", hit.point, 0.4f, Random.Range(0.8f, 1.3f), 50f);
        else if (r < 0.5f) Sfx.Play(metal ? "metal" : "dirt", hit.point, 0.35f, Random.Range(0.8f, 1.2f), 35f);
    }
}

// Метка поверхности: цвет для пыли и металл/не металл
public class Surface : MonoBehaviour
{
    public Color color = new Color(0.4f, 0.36f, 0.3f);
    public bool metal;
}

// Реактивная граната РПГ
public class Rocket : MonoBehaviour
{
    Unit owner;
    WeaponDef def;
    Vector3 vel;
    float life;

    public static void Spawn(Vector3 pos, Vector3 dir, Unit owner, WeaponDef def)
    {
        var go = new GameObject("rocket");
        go.transform.position = pos;
        go.transform.rotation = Quaternion.LookRotation(dir);
        MeshKit.Cyl(go.transform, Vector3.zero, 0.06f, 0.5f, new Color(0.25f, 0.28f, 0.2f), new Vector3(90, 0, 0));
        MeshKit.Part(go.transform, MeshKit.Frustum(0.2f), Mats.Get(new Color(0.25f, 0.28f, 0.2f)), new Vector3(0, 0, 0.35f), new Vector3(0.1f, 0.2f, 0.1f), new Vector3(90, 0, 0));
        MeshKit.Ball(go.transform, new Vector3(0, 0, -0.27f), Vector3.one * 0.12f, Mats.Glow(new Color(1f, 0.6f, 0.2f), 6f));
        var r = go.AddComponent<Rocket>();
        r.owner = owner; r.def = def; r.vel = dir * 70f;
        var l = go.AddComponent<Light>();
        l.color = new Color(1f, 0.6f, 0.25f); l.range = 8; l.intensity = 2.5f;
    }

    void Update()
    {
        float dt = Time.deltaTime;
        life += dt;
        vel += Vector3.down * 2.5f * dt;
        Vector3 step = vel * dt;
        if (Combat.Ray(transform.position, step.normalized, step.magnitude + 0.3f, owner, out var hit, Layers.ShotMask) || life > 5f)
        {
            Vector3 p = life > 5f ? transform.position : hit.point - step.normalized * 0.2f;
            if (life <= 5f)
            {
                var heli = hit.collider.GetComponentInParent<Helicopter>();
                if (heli != null) heli.Damage(def.damage * 2.5f, owner);
            }
            Combat.Explode(p, 6.5f, def.damage, owner, def.name, 1100f);
            Destroy(gameObject);
            return;
        }
        transform.position += step;
        transform.rotation = Quaternion.LookRotation(vel);
        Fx.Smoke(transform.position - transform.forward * 0.3f, 0.35f, new Color(0.75f, 0.75f, 0.75f, 0.5f), 1.6f, -vel * 0.03f);
        Fx.Fire(transform.position - transform.forward * 0.3f, 0.25f, -vel * 0.05f, 0.12f);
    }
}

// Ручная граната / выстрел гранатомёта
public class Grenade : MonoBehaviour
{
    Unit owner;
    bool impact;
    float damage, t, fuse;
    bool armed;

    public static void Spawn(Vector3 pos, Vector3 vel, Unit owner, bool impact, float damage = 160f)
    {
        var go = new GameObject("grenade");
        go.layer = Layers.Corpse;
        go.transform.position = pos;
        if (impact)
            MeshKit.Cyl(go.transform, Vector3.zero, 0.045f, 0.08f, new Color(0.6f, 0.55f, 0.2f), new Vector3(90, 0, 0));
        else
        {
            MeshKit.Ball(go.transform, Vector3.zero, new Vector3(0.07f, 0.09f, 0.07f), new Color(0.2f, 0.25f, 0.15f));
            MeshKit.Box(go.transform, new Vector3(0, 0.05f, 0), new Vector3(0.025f, 0.03f, 0.025f), new Color(0.3f, 0.3f, 0.3f));
        }
        var col = go.AddComponent<SphereCollider>(); col.radius = 0.05f;
        var rb = go.AddComponent<Rigidbody>();
        rb.mass = 0.4f;
        rb.velocity = vel;
        rb.angularVelocity = Random.insideUnitSphere * 10f;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
        rb.drag = 0.05f;
        var g = go.AddComponent<Grenade>();
        g.owner = owner; g.impact = impact; g.damage = damage; g.fuse = impact ? 6f : Random.Range(2.6f, 3.2f);
        if (owner != null)
            foreach (var c in owner.GetComponentsInChildren<Collider>()) Physics.IgnoreCollision(col, c);
    }

    void Update()
    {
        t += Time.deltaTime;
        if (t > 0.15f) armed = true;
        if (t >= fuse) Boom();
    }

    void OnCollisionEnter(Collision c)
    {
        if (impact && armed) { Boom(); return; }
        if (c.relativeVelocity.magnitude > 1.5f) Sfx.Play("grenade_bounce", transform.position, 0.5f, Random.Range(0.9f, 1.2f), 30f);
    }

    void Boom()
    {
        if (this == null || !enabled) return;
        enabled = false;
        Combat.Explode(transform.position + Vector3.up * 0.2f, impact ? 5f : 7f, damage, owner, impact ? "Гранатомёт" : "Граната", 1000f);
        Destroy(gameObject);
    }
}
