using System.Collections.Generic;
using UnityEngine;

// Положение кисти на оружии (общее для вида от первого и третьего лица)
public static class HandPose
{
    static Quaternion Basis(Vector3 x, Vector3 y)
    {
        y.Normalize();
        x = Vector3.ProjectOnPlane(x, y).normalized;
        if (x.sqrMagnitude < 1e-6f) x = Vector3.Cross(y, Vector3.forward).normalized;
        Vector3 z = Vector3.Cross(x, y);
        return Quaternion.LookRotation(z, y);
    }

    // правая кисть обхватывает пистолетную рукоять: ладонь к рукояти, пальцы вперёд-вниз
    public static Quaternion Grip(Quaternion gun)
    {
        Vector3 f = gun * Vector3.forward, u = gun * Vector3.up, r = gun * Vector3.right;
        return Basis(r, -(f * 0.5f - u * 0.86f));
    }

    // левая кисть под цевьём: ладонь вверх, пальцы обхватывают справа
    public static Quaternion Support(Quaternion gun)
    {
        Vector3 f = gun * Vector3.forward, u = gun * Vector3.up, r = gun * Vector3.right;
        return Basis(u * 0.9f + r * 0.3f, -(r * 0.75f + f * 0.55f));
    }

    // левая кисть держит предмет перед собой (граната, шприц, магазин)
    public static Quaternion Hold(Quaternion view, float tilt = 0f)
    {
        Vector3 f = view * Vector3.forward, u = view * Vector3.up, r = view * Vector3.right;
        return Basis(r * 0.8f + u * 0.2f, -(f * 0.7f + u * (0.5f + tilt)));
    }

    // запястье: от точки ладони назад вдоль кисти
    public static Vector3 Wrist(Vector3 palm, Quaternion hand, float scale = 1f) => palm + hand * new Vector3(0, 0.075f, 0) * scale;
}

// Вид от первого лица: оружие и руки бойца (из той же модели, что и тело), анимации действий,
// а также собственное тело игрока — тень и ноги, которые видно, если посмотреть вниз.
public class FPView : MonoBehaviour
{
    PlayerController pc;
    Camera vmCam;
    Transform root, pivot;
    public GunModel gm;
    Gun gun;
    Transform uL, lL, hL, uR, lR, hR;
    readonly List<GameObject> props = new List<GameObject>();
    Transform grenadeProp, syringeProp, ropeL;
    Vector3 shoulderL = new Vector3(-0.17f, -0.34f, -0.02f), shoulderR = new Vector3(0.22f, -0.33f, -0.14f);
    float armScale = 1f;

    // тело игрока
    HumanRig bodyRig;
    HumanAnimator bodyAnim;
    GunModel bodyGun;

    Vector3 swayPos, swayRot, kick, kickVel;
    float lastReload = -1f;
    bool reloadWasEmpty, magDropped;
    float pumpT = -1f;
    float inspectT = -1f, meleeT = -1f;
    float drawT = 0f;
    Vector3 lastGunPos; Quaternion lastGunRot = Quaternion.identity;

    public bool Busy => inspectT >= 0 || meleeT >= 0;

    public static FPView Create(PlayerController pc, Camera cam)
    {
        var v = pc.gameObject.AddComponent<FPView>();
        v.pc = pc;
        var vgo = new GameObject("vmCam");
        vgo.transform.SetParent(cam.transform, false);
        v.vmCam = vgo.AddComponent<Camera>();
        v.vmCam.clearFlags = CameraClearFlags.Depth;
        v.vmCam.cullingMask = 1 << Layers.ViewModel;
        v.vmCam.depth = cam.depth + 1;
        v.vmCam.nearClipPlane = 0.01f;
        v.vmCam.farClipPlane = 6f;
        v.vmCam.fieldOfView = 55f;
        v.root = new GameObject("vmRoot").transform;
        v.root.SetParent(cam.transform, false);
        v.pivot = new GameObject("vmPivot").transform;
        v.pivot.SetParent(v.root, false);
        v.BuildArms();
        v.BuildProps();
        v.BuildBody();
        return v;
    }

    public Camera VmCam => vmCam;

    // Удаляем всё, что висит на общей камере (иначе после рестарта боя оставалась "лишняя рука")
    public void Dispose()
    {
        if (root != null) Destroy(root.gameObject);
        if (vmCam != null) Destroy(vmCam.gameObject);
        root = null; vmCam = null;
    }

    void OnDestroy() { Dispose(); }

    public void SetVisible(bool on)
    {
        if (root != null) root.gameObject.SetActive(on);
        if (vmCam != null) vmCam.enabled = on;
        if (bodyRig != null) bodyRig.gameObject.SetActive(on);
    }

    // ---------------- руки ----------------
    void BuildArms()
    {
        var L = pc.squad.look;
        var d = ModelLib.Soldier;
        Transform Chain(string n, Vector3 sh, int side, out Transform l, out Transform h)
        {
            var u = new GameObject(n + "_u").transform; u.SetParent(root, false); u.localPosition = sh;
            l = new GameObject(n + "_l").transform; l.SetParent(u, false);
            h = new GameObject(n + "_h").transform; h.SetParent(l, false);
            if (d != null)
            {
                int b0 = side == 1 ? HumanRig.UArmL : HumanRig.UArmR;
                l.localPosition = d.jointLocal[b0 + 1];
                h.localPosition = d.jointLocal[b0 + 2];
                HumanRig.ModelMaterials(L, out int[] slotOf, out Material[] mats, out _);
                var go = new GameObject(n + "_mesh");
                go.transform.SetParent(root, false);
                var smr = go.AddComponent<SkinnedMeshRenderer>();
                smr.sharedMesh = ModelLib.ArmMesh(side, slotOf, mats.Length);
                smr.bones = new[] { u, l, h };
                smr.rootBone = u;
                smr.sharedMaterials = mats;
                smr.localBounds = new Bounds(Vector3.zero, Vector3.one * 2f);
                smr.updateWhenOffscreen = true;
                smr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                smr.receiveShadows = false;
            }
            else
            {
                l.localPosition = new Vector3(0, -0.28f, 0);
                h.localPosition = new Vector3(0, -0.27f, 0);
                MeshKit.Cyl(u, new Vector3(0, -0.14f, 0), 0.09f, 0.3f, L.uniform);
                MeshKit.Cyl(l, new Vector3(0, -0.13f, 0), 0.075f, 0.28f, L.uniform);
                MeshKit.Box(h, new Vector3(0, -0.05f, 0), new Vector3(0.06f, 0.1f, 0.035f), L.gear);
            }
            return u;
        }
        uL = Chain("armL", shoulderL, 1, out lL, out hL);
        uR = Chain("armR", shoulderR, 2, out lR, out hR);
        MeshKit.SetLayer(root.gameObject, Layers.ViewModel);
    }

    void BuildProps()
    {
        // граната и шприц в левой руке, канат при спуске
        var g = new GameObject("grenadeProp").transform; g.SetParent(root, false);
        MeshKit.Ball(g, Vector3.zero, new Vector3(0.065f, 0.085f, 0.065f), new Color(0.2f, 0.25f, 0.15f));
        MeshKit.Box(g, new Vector3(0, 0.05f, 0), new Vector3(0.022f, 0.03f, 0.022f), new Color(0.35f, 0.35f, 0.35f), default, 0.5f, 0.6f);
        MeshKit.Box(g, new Vector3(0.018f, 0.035f, 0), new Vector3(0.008f, 0.06f, 0.012f), new Color(0.35f, 0.35f, 0.35f), default, 0.5f, 0.6f);
        grenadeProp = g;
        var s = new GameObject("syringe").transform; s.SetParent(root, false);
        MeshKit.Cyl(s, Vector3.zero, 0.022f, 0.12f, Mats.Glass(new Color(0.8f, 0.9f, 1f, 0.6f)));
        MeshKit.Cyl(s, new Vector3(0, 0.0f, 0), 0.016f, 0.09f, Mats.Glow(new Color(0.2f, 1f, 0.4f), 1.5f));
        MeshKit.Cyl(s, new Vector3(0, 0.075f, 0), 0.03f, 0.02f, new Color(0.9f, 0.9f, 0.9f));
        MeshKit.Cyl(s, new Vector3(0, -0.08f, 0), 0.004f, 0.05f, new Color(0.7f, 0.7f, 0.7f), default, 0.8f, 0.8f);
        syringeProp = s;
        var r = new GameObject("rope").transform; r.SetParent(root, false);
        MeshKit.Cyl(r, Vector3.zero, 0.03f, 3f, new Color(0.15f, 0.12f, 0.08f));
        ropeL = r;
        foreach (var p in new[] { g, s, r }) { MeshKit.SetLayer(p.gameObject, Layers.ViewModel); MeshKit.NoShadows(p.gameObject); p.gameObject.SetActive(false); }
    }

    // Тело игрока: отбрасывает тень, а ноги видны, если посмотреть вниз
    void BuildBody()
    {
        if (!ModelLib.HasSoldier) return;
        var go = new GameObject("selfBody");
        go.transform.SetParent(pc.transform, false);
        bodyRig = HumanRig.Create(go.transform, ModelLib.SoldierShape());
        bodyRig.DressModel(pc.squad.look, pc.squad.id);
        foreach (var r in go.GetComponentsInChildren<Renderer>()) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly;
        // ноги — видимый отдельный меш
        HumanRig.ModelMaterials(pc.squad.look, out int[] slotOf, out Material[] mats, out _);
        var legs = new GameObject("legs");
        legs.transform.SetParent(go.transform, false);
        var smr = legs.AddComponent<SkinnedMeshRenderer>();
        smr.sharedMesh = ModelLib.LegsMesh(slotOf, mats.Length);
        smr.bones = bodyRig.b;
        smr.rootBone = bodyRig.b[HumanRig.Hips];
        smr.sharedMaterials = mats;
        smr.localBounds = new Bounds(Vector3.zero, Vector3.one * 2.5f);
        smr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        bodyAnim = go.AddComponent<HumanAnimator>();
        bodyAnim.rig = bodyRig;
        bodyAnim.footsteps = false;
    }

    public void Equip(Gun g, bool flashlightOn)
    {
        gun = g;
        if (gm != null) Destroy(gm.gameObject);
        gm = WeaponModels.Build(g.def, pivot, true);
        if (gm.flashlight != null)
        {
            gm.flashlight.enabled = flashlightOn;
            gm.flashlight.range = 40; gm.flashlight.intensity = 2.6f; gm.flashlight.shadows = LightShadows.Soft;
        }
        MeshKit.SetLayer(gm.gameObject, Layers.ViewModel);
        MeshKit.NoShadows(gm.gameObject);
        drawT = 0f;
        if (bodyRig != null)
        {
            if (bodyGun != null) Destroy(bodyGun.gameObject);
            bodyGun = WeaponModels.Build(g.def, bodyRig.transform, false);
            foreach (var r in bodyGun.GetComponentsInChildren<Renderer>()) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly;
            bodyAnim.gun = bodyGun;
        }
    }

    public void SetFlashlight(bool on) { if (gm != null && gm.flashlight != null) gm.flashlight.enabled = on; }

    public void Kick(float r)
    {
        kickVel += new Vector3(Random.Range(-0.3f, 0.3f), 0.6f, -2.2f) * r;
        if (gun != null && gun.def.kind == WeaponKind.Shotgun) pumpT = 0f;
        if (bodyAnim != null) bodyAnim.Kick(r * 0.6f, r);
    }

    public void Inspect() { if (inspectT < 0 && meleeT < 0) inspectT = 0f; }
    public void Melee() { if (meleeT < 0) { meleeT = 0f; inspectT = -1f; } }
    public float MeleeT => meleeT;

    // Точка из пространства вьюмодели в мир (вьюмодель рисуется своей камерой с другим FOV)
    public Vector3 ToWorld(Vector3 vmWorldPos)
    {
        Vector3 vp = vmCam.WorldToViewportPoint(vmWorldPos);
        return Game.Cam.ViewportToWorldPoint(new Vector3(vp.x, vp.y, Mathf.Max(0.35f, vp.z)));
    }

    public Vector3 GrenadeWorldPos => ToWorld(grenadeProp.position);

    static float S(float a, float b, float t) => Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(a, b, t));
    static float Bell(float a, float b, float t) { float k = Mathf.InverseLerp(a, b, t); return Mathf.Sin(k * Mathf.PI); }

    // ---------------- кадр ----------------
    void LateUpdate()
    {
        if (pc == null || pc.dead || gm == null || root == null || !root.gameObject.activeSelf) return;
        float dt = Time.deltaTime;
        if (dt <= 0) return;
        var def = gun.def;
        float ads = pc.adsW, spr = pc.sprintW;
        bool pistol = def.kind == WeaponKind.Pistol, rpg = def.id == "rpg";
        drawT = Mathf.Min(1f, drawT + dt / 0.45f);
        if (inspectT >= 0) { inspectT += dt / 2.6f; if (inspectT >= 1f || ads > 0.1f || gun.reloading) inspectT = -1f; }
        if (meleeT >= 0) { meleeT += dt / 0.55f; if (meleeT >= 1f) meleeT = -1f; }
        if (pumpT >= 0) { pumpT += dt / Mathf.Max(0.3f, def.Interval * 0.85f); if (pumpT >= 1f) pumpT = -1f; }

        // ---- базовая поза оружия ----
        Vector3 hip = pistol ? new Vector3(0.12f, -0.16f, 0.33f) : rpg ? new Vector3(0.17f, -0.17f, 0.18f) : new Vector3(0.15f, -0.17f, 0.26f);
        Vector3 rot = Vector3.zero;
        Vector3 pos = hip;
        float calm = 1f - ads * 0.92f;
        // бег: оружие развёрнуто, руки работают в такт
        pos += new Vector3(-0.05f, -0.06f, -0.05f) * spr;
        rot += new Vector3(14f, -42f, 22f) * spr;
        float bob = pc.bob, bw = pc.bobAmt * calm;
        pos += new Vector3(Mathf.Cos(bob) * 0.013f * (1f + spr * 2f), -Mathf.Abs(Mathf.Sin(bob)) * 0.018f * (1f + spr * 1.5f), Mathf.Sin(bob * 2f) * 0.004f) * bw;
        rot += new Vector3(Mathf.Abs(Mathf.Sin(bob)) * 2.5f, Mathf.Cos(bob) * 1.8f, Mathf.Cos(bob) * (2.5f + spr * 6f)) * bw;
        // присед: оружие чуть ниже и ближе
        pos += new Vector3(-0.01f, -0.015f, -0.01f) * (pc.crouching ? 1f : 0f) * calm;
        // дыхание и мелкое покачивание в покое
        float t = Time.time;
        pos += new Vector3(Mathf.Sin(t * 0.9f) * 0.002f, Mathf.Sin(t * 1.4f) * 0.004f, 0) * calm;
        rot += new Vector3(Mathf.Sin(t * 1.4f) * 0.6f, Mathf.Sin(t * 0.7f) * 0.5f, 0) * calm;
        // инерция взгляда
        bool locked = Cursor.lockState == CursorLockMode.Locked;
        float mx = locked ? Input.GetAxisRaw("Mouse X") : 0, my = locked ? Input.GetAxisRaw("Mouse Y") : 0;
        swayRot = Vector3.Lerp(swayRot, new Vector3(my * 1.6f, -mx * 2.2f, -mx * 2.8f), 1f - Mathf.Exp(-9f * dt));
        swayPos = Vector3.Lerp(swayPos, new Vector3(-mx * 0.007f, -my * 0.007f, 0), 1f - Mathf.Exp(-9f * dt));
        pos += swayPos * calm; rot += swayRot * (1f - ads * 0.8f);
        // прыжок/приземление
        pos.y -= pc.landKick * 0.06f;
        rot.x += pc.landKick * 7f - (pc.Airborne ? 4f : 0f);
        // отдача (пружина)
        kickVel += (-kick * 260f - kickVel * 21f) * dt;
        kick += kickVel * dt;
        rot += new Vector3(-kick.y * 2.6f - Mathf.Abs(kick.z) * 1.3f, kick.x * 2f, kick.x * 1.6f);
        Vector3 kickPos = new Vector3(kick.x * 0.004f, kick.y * 0.004f, kick.z * 0.013f);
        // доставание оружия
        float dr = 1f - Mathf.SmoothStep(0, 1, drawT);
        pos += new Vector3(0.02f, -0.22f, -0.05f) * dr; rot += new Vector3(45f, 10f, 15f) * dr;

        // ---- действия ----
        Vector3? lTarget = null, rTarget = null;
        Quaternion lRot = Quaternion.identity, rRot = Quaternion.identity;
        float lW = 0f, rW = 0f;
        bool showGrenade = false, showSyringe = false, magInHand = false, magHidden = false;
        Vector3 magOffset = Vector3.zero;
        Quaternion view = root.rotation;

        // перезарядка
        float rl = gun.reloading ? gun.ReloadProgress : -1f;
        if (rl >= 0 && lastReload < 0) { reloadWasEmpty = gun.ammo == 0; magDropped = false; }
        lastReload = rl;
        bool shells = def.kind == WeaponKind.Shotgun;
        if (rl >= 0 && !shells)
        {
            float tilt = S(0f, 0.12f, rl) * (1f - S(0.86f, 1f, rl));
            pos += new Vector3(-0.02f, -0.04f, -0.02f) * tilt;
            rot += new Vector3(-8f, -14f, 28f) * tilt;
            // магазин: вынуть (0.12–0.25), новый подвести (0.45–0.62), вставить (0.62–0.7)
            Vector3 mdown = new Vector3(0, -0.3f, -0.05f);
            if (rl < 0.12f) magOffset = Vector3.zero;
            else if (rl < 0.25f) { magOffset = Vector3.Lerp(Vector3.zero, mdown, S(0.12f, 0.25f, rl)); magInHand = true; }
            else if (rl < 0.45f) { magHidden = true; magOffset = mdown; }
            else if (rl < 0.62f) { magOffset = Vector3.Lerp(mdown * 1.2f, new Vector3(0, -0.06f, 0), S(0.45f, 0.62f, rl)); magInHand = true; }
            else if (rl < 0.7f) { magOffset = Vector3.Lerp(new Vector3(0, -0.06f, 0), Vector3.zero, S(0.62f, 0.7f, rl)); magInHand = true; pos.y += Bell(0.66f, 0.72f, rl) * 0.012f; }
            if (rl > 0.2f && !magDropped && reloadWasEmpty) { magDropped = true; DropMag(); }
            // левая рука: к магазину, вниз к подсумку, обратно; при пустом — затвор
            Vector3 magW = gm.mag != null ? gm.mag.position : gm.foregrip.position;
            Vector3 pouch = root.TransformPoint(new Vector3(-0.12f, -0.55f, 0.18f));
            float toMag = S(0.02f, 0.12f, rl) * (1f - S(0.7f, 0.76f, rl));
            if (toMag > 0.001f)
            {
                lTarget = magW + gm.transform.up * -0.03f; lW = toMag;
                lRot = HandPose.Hold(gm.transform.rotation, 0.6f);
                if (rl > 0.25f && rl < 0.45f) lTarget = Vector3.Lerp(magW, pouch, Bell(0.25f, 0.45f, rl) * 1.2f);
            }
            // передёргивание затвора / удар по магазину
            if (rl > 0.72f && rl < 0.9f)
            {
                float k = Bell(0.72f, 0.9f, rl);
                Vector3 bolt = def.id == "ak" || def.id == "saiga" || def.id == "svd"
                    ? gm.transform.TransformPoint(new Vector3(0.05f, 0.07f, 0.17f - 0.08f * S(0.78f, 0.84f, rl)))
                    : pistol ? gm.transform.TransformPoint(new Vector3(0f, 0.06f, -0.04f - 0.05f * S(0.78f, 0.84f, rl)))
                    : gm.transform.TransformPoint(new Vector3(0f, 0.09f, -0.08f - 0.07f * S(0.78f, 0.84f, rl)));
                Vector3 slap = gm.mag != null ? gm.mag.position - gm.transform.up * 0.08f : bolt;
                lTarget = reloadWasEmpty ? bolt : slap; lW = k;
                lRot = reloadWasEmpty ? HandPose.Hold(gm.transform.rotation, -0.4f) : HandPose.Hold(gm.transform.rotation, 0.9f);
                if (reloadWasEmpty) rot += new Vector3(0, 0, 6f) * Bell(0.78f, 0.86f, rl);
            }
        }
        // дробовик: по патрону в окно снизу
        if (rl >= 0 && shells)
        {
            float tilt = S(0f, 0.08f, rl) * (1f - S(0.9f, 1f, rl));
            pos += new Vector3(-0.03f, 0.0f, 0.0f) * tilt;
            rot += new Vector3(-12f, -10f, -35f) * tilt;
            float ph = gun.ShellPhase;
            Vector3 port = gm.transform.TransformPoint(new Vector3(0, -0.01f, 0.1f));
            Vector3 pouch = root.TransformPoint(new Vector3(-0.15f, -0.5f, 0.2f));
            float k = Mathf.Sin(ph * Mathf.PI);
            lTarget = Vector3.Lerp(port, pouch, k); lW = tilt;
            lRot = HandPose.Hold(gm.transform.rotation, 0.3f);
        }
        // помповый затвор после выстрела
        if (pumpT >= 0 && gm.pump != null)
        {
            float k = Bell(0.15f, 0.85f, pumpT);
            gm.pump.localPosition = gm.pumpRest + new Vector3(0, 0, -0.09f * k);
            rot += new Vector3(-3f, 0, 4f) * k;
        }
        else if (gm.pump != null && rl < 0) gm.pump.localPosition = gm.pumpRest;

        // граната
        float th = pc.ThrowT;
        if (th >= 0)
        {
            float low = S(0f, 0.15f, th) * (1f - S(0.8f, 1f, th));
            pos += new Vector3(0.1f, -0.22f, -0.02f) * low;
            rot += new Vector3(28f, 22f, -5f) * low;
            showGrenade = th > 0.05f && th < 0.62f;
            Vector3 hold = new Vector3(-0.06f, -0.12f, 0.36f), wind = new Vector3(-0.28f, 0.08f, 0.08f), rel = new Vector3(-0.02f, 0.06f, 0.62f), rest = new Vector3(-0.2f, -0.5f, 0.2f);
            Vector3 p;
            if (th < 0.3f) p = Vector3.Lerp(rest, hold, S(0.05f, 0.3f, th));
            else if (th < 0.45f) p = hold;
            else if (th < 0.55f) p = Vector3.Lerp(hold, wind, S(0.45f, 0.55f, th));
            else if (th < 0.64f) p = Vector3.Lerp(wind, rel, S(0.55f, 0.64f, th));
            else p = Vector3.Lerp(rel, rest, S(0.64f, 0.85f, th));
            lTarget = root.TransformPoint(p); lW = 1f - S(0.85f, 1f, th);
            lRot = HandPose.Hold(view, th > 0.45f && th < 0.64f ? -0.6f : 0.2f);
            // правая рука выдёргивает чеку
            if (th > 0.28f && th < 0.48f)
            {
                rTarget = root.TransformPoint(hold + new Vector3(0.05f + 0.08f * S(0.36f, 0.44f, th), 0.07f, 0f)); rW = Bell(0.28f, 0.48f, th);
                rRot = HandPose.Hold(view, 0.3f) * Quaternion.Euler(0, 0, -40f);
            }
        }

        // аптечка (укол в бедро)
        float hl = pc.HealT;
        if (hl >= 0)
        {
            float low = S(0f, 0.15f, hl) * (1f - S(0.85f, 1f, hl));
            pos += new Vector3(0.08f, -0.25f, -0.03f) * low;
            rot += new Vector3(35f, 15f, 0) * low;
            Vector3 a = new Vector3(-0.08f, -0.14f, 0.34f), b = new Vector3(0.05f, -0.42f, 0.16f);
            Vector3 p = Vector3.Lerp(new Vector3(-0.2f, -0.5f, 0.2f), a, S(0.05f, 0.35f, hl));
            p = Vector3.Lerp(p, b, S(0.5f, 0.62f, hl));
            p = Vector3.Lerp(p, new Vector3(-0.2f, -0.55f, 0.2f), S(0.8f, 0.95f, hl));
            lTarget = root.TransformPoint(p); lW = 1f - S(0.9f, 1f, hl);
            lRot = HandPose.Hold(view, -0.2f + 1.2f * S(0.45f, 0.6f, hl));
            showSyringe = hl > 0.05f && hl < 0.9f;
        }

        // удар прикладом
        if (meleeT >= 0)
        {
            float wind = S(0f, 0.2f, meleeT) * (1f - S(0.25f, 0.32f, meleeT));
            float hit = S(0.22f, 0.32f, meleeT) * (1f - S(0.45f, 0.85f, meleeT));
            pos += new Vector3(0.06f, -0.04f, -0.08f) * wind + new Vector3(-0.12f, 0.06f, 0.2f) * hit;
            rot += new Vector3(-10f, 25f, 20f) * wind + new Vector3(-25f, -55f, -35f) * hit;
        }
        // осмотр оружия
        if (inspectT >= 0)
        {
            float a = S(0f, 0.18f, inspectT) * (1f - S(0.45f, 0.55f, inspectT));
            float b = S(0.48f, 0.6f, inspectT) * (1f - S(0.85f, 1f, inspectT));
            pos += new Vector3(-0.1f, 0.05f, 0.04f) * a + new Vector3(-0.08f, 0.02f, 0.06f) * b;
            rot += new Vector3(-5f, -50f, -35f) * a + new Vector3(-40f, -20f, 70f) * b;
        }
        // смена оружия
        if (pc.SwitchT >= 0)
        {
            float k = Mathf.Sin(Mathf.Clamp01(pc.SwitchT) * Mathf.PI);
            pos += new Vector3(0, -0.32f, -0.05f) * k;
            rot += new Vector3(45f, 0, 10f) * k;
        }
        // сидение в вертолёте: оружие стволом вверх между коленей
        if (pc.riding && !pc.OnRope)
        {
            pos = Vector3.Lerp(pos, new Vector3(0.05f, -0.42f, 0.32f), 0.9f);
            rot = Vector3.Lerp(rot, new Vector3(-65f, -10f, 0), 0.9f);
        }
        // спуск по канату: оружие на ремне, обе руки на канате
        bool rope = pc.OnRope;
        ropeL.gameObject.SetActive(rope);
        if (rope)
        {
            pos = new Vector3(0.1f, -0.6f, 0.15f); rot = new Vector3(60f, 0, 0);
            Vector3 rp = new Vector3(0.0f, 0.0f, 0.32f);
            ropeL.localPosition = rp; ropeL.localRotation = Quaternion.Euler(-8f, 0, 0);
            float slide = Mathf.Sin(Time.time * 9f) * 0.03f;
            lTarget = root.TransformPoint(rp + new Vector3(-0.025f, 0.12f + slide, 0)); lW = 1f;
            rTarget = root.TransformPoint(rp + new Vector3(0.025f, -0.08f - slide, 0)); rW = 1f;
            lRot = HandPose.Hold(view, -1.2f); rRot = HandPose.Hold(view, -1.2f) * Quaternion.Euler(0, 180, 0);
        }

        // ---- ставим оружие; в прицеле — прицельная марка ровно в центре экрана ----
        Quaternion q = Quaternion.Euler(rot);
        Vector3 sight = gm.sight.localPosition;
        float eye = def.scope ? 0.12f : pistol ? 0.36f : 0.24f;
        Vector3 adsPos = new Vector3(0, 0, eye) - q * sight;
        float adsK = Mathf.SmoothStep(0f, 1f, ads);
        pivot.localRotation = q;
        pivot.localPosition = Vector3.Lerp(pos, adsPos, adsK) + kickPos;

        // магазин
        if (gm.mag != null)
        {
            gm.mag.localPosition = gm.magRest + magOffset;
            gm.mag.gameObject.SetActive(!magHidden);
        }
        grenadeProp.gameObject.SetActive(showGrenade);
        syringeProp.gameObject.SetActive(showSyringe);

        // ---- руки (IK) ----
        Quaternion gq = gm.transform.rotation;
        Quaternion rq = HandPose.Grip(gq);
        Vector3 rPalm = gm.grip.position + gm.transform.right * 0.022f;
        Quaternion lq = HandPose.Support(gq);
        Vector3 lPalm = gm.foregrip.position - gm.transform.up * 0.025f;
        if (pistol) { lq = HandPose.Grip(gq) * Quaternion.Euler(0, 160, 0); lPalm = gm.grip.position - gm.transform.right * 0.03f + gm.transform.forward * 0.01f; }
        if (lTarget.HasValue) { lPalm = Vector3.Lerp(lPalm, lTarget.Value, lW); lq = Quaternion.Slerp(lq, lRot, lW); }
        if (rTarget.HasValue) { rPalm = Vector3.Lerp(rPalm, rTarget.Value, rW); rq = Quaternion.Slerp(rq, rRot, rW); }
        if (magInHand && gm.mag != null && lW > 0.5f) gm.mag.position = Vector3.Lerp(gm.mag.position, lPalm + lq * new Vector3(0, -0.04f, 0), 0.6f);
        // плечи слегка следуют за оружием (корпус)
        uL.localPosition = Vector3.Lerp(uL.localPosition, shoulderL + new Vector3(pos.x * 0.3f, pos.y * 0.25f, 0), 1f - Mathf.Exp(-12f * dt));
        uR.localPosition = Vector3.Lerp(uR.localPosition, shoulderR + new Vector3(pos.x * 0.3f, pos.y * 0.25f, 0), 1f - Mathf.Exp(-12f * dt));
        Vector3 down = -root.up, right = root.right, back = -root.forward;
        HumanAnimator.TwoBone(uR, lR, hR, HandPose.Wrist(rPalm, rq), uR.position + down * 0.8f + right * 0.5f + back * 0.2f, 1f);
        hR.rotation = rq;
        HumanAnimator.TwoBone(uL, lL, hL, HandPose.Wrist(lPalm, lq), uL.position + down * 0.8f - right * 0.5f + back * 0.1f, 1f);
        hL.rotation = lq;
        if (showGrenade) grenadeProp.position = hL.position + hL.rotation * new Vector3(0, -0.09f, 0.0f);
        if (showSyringe) { syringeProp.position = hL.position + hL.rotation * new Vector3(0, -0.08f, 0); syringeProp.rotation = hL.rotation * Quaternion.Euler(90, 0, 0); }

        // ---- тело игрока ----
        if (bodyAnim != null)
        {
            bodyAnim.velocity = pc.velocity;
            bodyAnim.aimDir = pc.camHolder.forward;
            bodyAnim.aiming = ads > 0.5f || Input.GetMouseButton(0);
            bodyAnim.crouch = pc.crouching;
            bodyAnim.sprint = spr > 0.5f;
            bodyAnim.seated = pc.riding && !pc.OnRope;
            bodyAnim.onRope = pc.OnRope;
            bodyAnim.airborne = pc.Airborne;
            bodyAnim.reload01 = rl;
            bodyAnim.throw01 = th;
        }
    }

    // Пустой магазин падает на землю
    void DropMag()
    {
        if (gm.mag == null) return;
        var mf = gm.mag.GetComponent<MeshFilter>();
        var mr = gm.mag.GetComponent<MeshRenderer>();
        if (mf == null || mr == null) return;
        var go = new GameObject("droppedMag");
        go.layer = Layers.Corpse;
        go.transform.position = ToWorld(gm.mag.position);
        go.transform.rotation = Game.Cam.transform.rotation * Quaternion.Inverse(root.rotation) * gm.mag.rotation;
        go.AddComponent<MeshFilter>().sharedMesh = mf.sharedMesh;
        go.AddComponent<MeshRenderer>().sharedMaterials = mr.sharedMaterials;
        var bc = go.AddComponent<BoxCollider>();
        bc.center = mf.sharedMesh.bounds.center; bc.size = mf.sharedMesh.bounds.size;
        var rb = go.AddComponent<Rigidbody>();
        rb.mass = 0.4f;
        rb.velocity = pc.velocity + Vector3.down * 1.5f + Game.Cam.transform.right * -0.5f;
        rb.angularVelocity = Random.insideUnitSphere * 5f;
        Destroy(go, 25f);
    }
}
