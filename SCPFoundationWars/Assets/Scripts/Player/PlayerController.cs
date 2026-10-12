using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// "Тело" игрока для ИИ: позиция, взгляд, урон
public class PlayerUnit : Unit
{
    public PlayerController pc;
    public override Vector3 EyePos => pc != null && pc.camHolder != null ? pc.camHolder.position : base.EyePos;
    public override Vector3 LookDir => pc != null && pc.camHolder != null ? pc.camHolder.forward : transform.forward;
    public override Vector3 AimPoint => transform.position + Vector3.up * (pc != null && pc.crouching ? 0.85f : 1.25f);
    public override Vector3 Velocity => pc != null ? pc.velocity : Vector3.zero;
    protected override void OnHurt(DamageInfo d, float dmg) { pc.OnHurt(d, dmg); }
    protected override void Die(DamageInfo d) { Net.LocalDied(d); pc.OnDeath(d); }
    public override void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Blood(point, dir, 0.6f);
        Sfx.Play2D("flesh", 0.6f, Random.Range(0.8f, 1.1f));
    }
}

public class PlayerController : MonoBehaviour
{
    public static PlayerController I;

    public PlayerUnit unit;
    public SquadDef squad;
    public CharacterController cc;
    public Transform camHolder;
    public FPView fp;
    readonly Gun[] guns = new Gun[3];
    int cur;
    public Vector3 velocity;
    public bool crouching;
    float yaw, pitch, recoilP, recoilY, recoilVelP;
    float camH = 1.65f;
    public float adsW, sprintW, bob, bobAmt, landKick;
    float switchT = -1; int switchTo = -1; bool swapped;
    public float SwitchT => switchT;
    public float ThrowT => throwT >= 0 ? Mathf.Clamp01(throwT) : -1f;
    public float HealT => healT >= 0 ? Mathf.Clamp01(1f - (healEndT - Time.time) / 1.4f) : -1f;
    public bool OnRope { get; private set; }
    public bool Airborne => !grounded && !riding && !scripted;
    float healEndT;
    bool meleeHit;
    public int grenades, medkits = 2;
    float throwT = -1, healT = -1;
    public bool riding;
    Transform rideSeat;
    bool scripted;
    public bool dead;
    public float deathTime;
    Soldier corpse;
    public float suppress, hurt;
    public readonly List<Vector2> dmgDirs = new List<Vector2>(); // x — угол, y — время
    public readonly List<Vector4> screenBlood = new List<Vector4>(); // x,y — место (0..1), z — размер, w — время
    public float hitMarkT = -1; public bool hitKill, hitHead;
    public int hits, kills;
    public bool magCheck;
    float rDownT = -1f;
    public bool Blinking => Time.time < blinkEnd;
    float blinkT, blinkEnd;
    bool grounded;
    float vy;
    Vector3 knock;
    bool flashlightOn;
    public float spreadNow;
    float barrelHeat, lastShotT;
    // приёмы: выглядывание (Q/E), лёжа (Z), подкат (присед на бегу), перелезание (пробел у препятствия)
    // выносливость (бег, прыжки), задержка дыхания в прицеле (Shift), свободный обзор (Alt), раскачка прицела
    public float stamina = 1f, breath = 1f; public bool holdingBreath, freeLook;
    public float freeYaw, freePitch;
    float swayP, swayY, breathT, staminaT, exhaleT = -1f;
    public Quaternion FreeRot => Quaternion.Euler(freePitch, freeYaw, 0);
    // куда смотрит оружие (при свободном обзоре — не туда, куда камера)
    public Vector3 AimForward => camHolder.rotation * Quaternion.Inverse(FreeRot) * Vector3.forward;
    public float lean; public bool prone; float slideT = -1f; Vector3 slideDir; public bool vaulting;
    public bool Sliding => slideT >= 0f;
    public Gun Current => guns[cur];
    public int CurIndex => cur;
    public Gun GunAt(int i) => guns[i];

    // ---------------- создание ----------------
    public static PlayerController Create(SquadDef def)
    {
        Remove();
        var go = new GameObject("Player");
        go.layer = Layers.Player;
        var pc = go.AddComponent<PlayerController>();
        I = pc;
        pc.squad = def;
        pc.cc = go.AddComponent<CharacterController>();
        pc.cc.height = 1.8f; pc.cc.radius = 0.32f; pc.cc.center = new Vector3(0, 0.9f, 0);
        pc.cc.stepOffset = 0.45f; pc.cc.slopeLimit = 50f; pc.cc.skinWidth = 0.04f;
        pc.unit = go.AddComponent<PlayerUnit>();
        pc.unit.pc = pc;
        pc.unit.isPlayer = true;
        pc.unit.team = def.team;
        pc.unit.squad = def;
        pc.unit.displayName = "Игрок";
        pc.unit.maxHp = pc.unit.hp = def.hp;
        pc.unit.armor = def.armor;
        pc.unit.threat = 1.3f;
        var hb = go.AddComponent<Hitbox>(); hb.owner = pc.unit; hb.mul = 1f;
        Ballistics.player = pc;

        pc.camHolder = new GameObject("camHolder").transform;
        pc.camHolder.SetParent(go.transform, false);
        pc.camHolder.localPosition = new Vector3(0, pc.camH, 0);
        pc.unit.eye = pc.camHolder;
        var cam = Game.Cam;
        cam.transform.SetParent(pc.camHolder, false);
        cam.transform.localPosition = Vector3.zero;
        cam.transform.localRotation = Quaternion.identity;
        cam.nearClipPlane = 0.04f;
        cam.cullingMask = ~(1 << Layers.ViewModel);

        // оружие и руки от первого лица
        pc.fp = FPView.Create(pc, cam);

        pc.guns[0] = new Gun(DB.W(def.primary)); pc.guns[0].UseMagPouches(DB.W(def.primary).kind == WeaponKind.LMG ? 3 : 6);
        pc.guns[1] = def.secondary != null ? new Gun(DB.W(def.secondary)) : null;
        if (pc.guns[1] != null) pc.guns[1].UseMagPouches(3);
        pc.guns[2] = def.special != null ? new Gun(DB.W(def.special)) { reserveMags = DB.W(def.special).rocket ? 4 : 3 } : null;
        pc.grenades = Mathf.Max(1, def.grenades);
        pc.flashlightOn = MapGen.Night;
        pc.Equip(0);
        pc.blinkT = Time.time + 6f;
        return pc;
    }

    public static void Remove()
    {
        if (I == null) return;
        if (Game.Cam != null && Game.Cam.transform.IsChildOf(I.transform)) Game.Cam.transform.SetParent(null, true);
        if (I.fp != null) I.fp.Dispose();
        Destroy(I.gameObject);
        I = null;
        Ballistics.player = null;
    }

    void Equip(int i)
    {
        if (guns[i] == null) return;
        cur = i;
        fp.Equip(guns[i], flashlightOn);
    }

    // ---------------- передовая база ----------------
    float lockT; bool wasLocked; float lastYawBC, bcRoll;
    public bool safe;   // на базе оружие на предохранителе
    public void StandAt(Vector3 p, float yawDeg)
    {
        transform.SetParent(null, true);
        riding = false; rideSeat = null; scripted = false; OnRope = false;
        cc.enabled = false;
        transform.position = p + Vector3.up * 0.05f;
        yaw = yawDeg; pitch = 4f;
        transform.rotation = Quaternion.Euler(0, yaw, 0);
        cc.enabled = true;
        unit.inVehicle = true;
        safe = true;
        velocity = Vector3.zero; vy = 0;
    }

    // Появление на ногах (карта «комплекс»): без вертолёта, оружие сразу готово
    public void SpawnAt(Vector3 p, float yawDeg)
    {
        transform.SetParent(null, true);
        riding = false; rideSeat = null; scripted = false; OnRope = false; safe = false;
        unit.inVehicle = false;
        yaw = yawDeg; pitch = 0f;
        transform.rotation = Quaternion.Euler(0, yaw, 0);
        Teleport(p);
    }

    public void Teleport(Vector3 p)
    {
        cc.enabled = false;
        transform.position = p;
        cc.enabled = true;
        velocity = Vector3.zero; vy = 0f;
    }

    // ---------------- вертолёт ----------------
    public void RideIn(Helicopter heli, Transform seat)
    {
        riding = true;
        safe = false;
        rideSeat = seat;
        cc.enabled = false;
        unit.inVehicle = true;
        transform.SetParent(seat, false);
        transform.localPosition = Vector3.zero;
        transform.localRotation = Quaternion.identity;
        yaw = 0; pitch = 5;
    }

    // Посадка игрока: сам подходит к двери, поднимается на борт и садится (смотреть по сторонам можно)
    public bool boarded;
    public IEnumerator BoardRoutine(Helicopter h, Transform seat)
    {
        h.boarding++;
        scripted = true; boarded = false;
        cc.enabled = false;
        h.BoardPath(seat, out var outside, out var door);
        Vector3 local = h.transform.InverseTransformPoint(transform.position);
        Vector3 doorLocal = h.transform.InverseTransformPoint(outside);
        var path = new System.Collections.Generic.List<Vector3>();
        if (Mathf.Sign(local.x) != Mathf.Sign(doorLocal.x) || Mathf.Abs(local.x) < 2.5f)
        {
            Vector3 w = h.transform.TransformPoint(new Vector3(Mathf.Sign(doorLocal.x) * 4.5f, 0, local.z < -2f ? Mathf.Max(local.z, -13f) : doorLocal.z - 4f));
            w.y = Battle.GroundHeight(w);
            path.Add(w);
        }
        path.Add(outside);
        float stepT = 0;
        foreach (var target in path)
        {
            while (!dead)
            {
                Vector3 to = target - transform.position; to.y = 0;
                if (to.magnitude < 0.25f) break;
                Vector3 p = transform.position + to.normalized * Mathf.Min(to.magnitude, 2.6f * Time.deltaTime);
                p.y = Battle.GroundHeight(p) + 0.05f;
                transform.position = p;
                // взгляд мягко ведём по ходу, мышь добавляет поверх
                float want = Mathf.Atan2(to.x, to.z) * Mathf.Rad2Deg;
                yaw = Mathf.MoveTowardsAngle(yaw, want, 90f * Time.deltaTime);
                stepT += Time.deltaTime;
                if (stepT > 0.42f) { stepT = 0; Sfx.Play2D(Sfx.Step, 0.35f, Random.Range(0.9f, 1.1f)); }
                yield return null;
            }
        }
        Vector3 a = transform.position;
        float t = 0;
        while (t < 0.6f && !dead)
        {
            t += Time.deltaTime;
            float k = Mathf.SmoothStep(0, 1, t / 0.6f);
            transform.position = Vector3.Lerp(a, door, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 0.25f;
            yield return null;
        }
        Sfx.Play2D("land", 0.4f, 0.9f);
        a = transform.position;
        t = 0;
        while (t < 0.5f && !dead)
        {
            t += Time.deltaTime;
            transform.position = Vector3.Lerp(a, seat.position, Mathf.SmoothStep(0, 1, t / 0.5f));
            yield return null;
        }
        scripted = false;
        RideIn(h, seat);
        h.playerPassenger = this;
        boarded = true;
        h.boarding--;
    }

    public void ExitHeli(Helicopter heli, Vector3 door, Vector3 ground, Vector3? ropeTop)
    {
        StartCoroutine(ExitRoutine(door, ground, ropeTop));
    }

    IEnumerator ExitRoutine(Vector3 door, Vector3 ground, Vector3? ropeTop)
    {
        scripted = true;
        Vector3 worldFwd = camHolder.forward; worldFwd.y = 0;
        transform.SetParent(null, true);
        yaw = Mathf.Atan2(worldFwd.x, worldFwd.z) * Mathf.Rad2Deg;
        transform.rotation = Quaternion.Euler(0, yaw, 0);
        Vector3 start = transform.position;
        float t = 0;
        Vector3 doorFeet = door;
        while (t < 0.45f)
        {
            t += Time.deltaTime;
            transform.position = Vector3.Lerp(start, doorFeet, Mathf.SmoothStep(0, 1, t / 0.45f));
            yield return null;
        }
        if (ropeTop.HasValue)
        {
            Sfx.Play2D("rope", 0.7f);
            OnRope = true;
            Vector3 p = new Vector3(ropeTop.Value.x, transform.position.y, ropeTop.Value.z);
            float sp = 0;
            while (p.y > ground.y + 0.05f && !dead)
            {
                sp = Mathf.Min(sp + 14f * Time.deltaTime, 7f);
                if (p.y - ground.y < 2.5f) sp = Mathf.Max(2f, sp - 25f * Time.deltaTime);
                p.y -= sp * Time.deltaTime;
                transform.position = new Vector3(p.x, Mathf.Max(p.y, ground.y), p.z);
                bobAmt = 0.5f;
                yield return null;
            }
        }
        else
        {
            Vector3 a = transform.position;
            t = 0;
            Sfx.Play2D("whoosh", 0.4f, 1.3f);
            while (t < 0.6f)
            {
                t += Time.deltaTime;
                float k = t / 0.6f;
                transform.position = Vector3.Lerp(a, ground, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 0.7f;
                yield return null;
            }
        }
        OnRope = false;
        transform.position = ground + Vector3.up * 0.05f;
        landKick = 1f;
        Sfx.Play2D(Sfx.Step, 0.8f, 0.8f);
        riding = false;
        unit.inVehicle = false;
        cc.enabled = true;
        scripted = false;
        Battle.Message("ВЫСАДКА! Вперёд!", new Color(0.6f, 0.85f, 1f));
    }

    public void KillInHeli(Vector3 vel)
    {
        transform.SetParent(null, true);
        riding = false;
        unit.inVehicle = false;
        velocity = vel;
        unit.TakeDamage(new DamageInfo { amount = 99999, type = DamageType.Explosion, dir = Vector3.up, force = 600f, point = unit.AimPoint, weapon = "Крушение" });
    }

    public void Knock(Vector3 v) { knock += v; }

    // ---------------- урон ----------------
    public void Suppress(float a) { suppress = Mathf.Min(1f, suppress + a); }

    public void OnHurt(DamageInfo d, float dmg)
    {
        hurt = Mathf.Min(1f, hurt + dmg / 40f);
        // брызги на «объектив»: от сильных попаданий, взрывов и ближнего боя
        if (Game.Blood > 0.01f && (dmg > 18f || Random.value < dmg / 25f))
        {
            int n = dmg > 40f ? 3 : 1;
            for (int i = 0; i < n; i++)
                screenBlood.Add(new Vector4(Random.Range(0.05f, 0.95f), Random.Range(0.1f, 0.9f), Random.Range(0.18f, 0.42f) * Mathf.Clamp(dmg / 30f, 0.6f, 1.6f), Time.time));
            while (screenBlood.Count > 8) screenBlood.RemoveAt(0);
        }
        if (Random.value < 0.6f) Sfx.Play2D("pain", 0.55f, Random.Range(0.95f, 1.05f));
        Fx.shake = Mathf.Max(Fx.shake, 0.2f + dmg / 120f);
        if (d.attacker != null)
        {
            Vector3 to = d.attacker.transform.position - transform.position; to.y = 0;
            Vector3 f = camHolder.forward; f.y = 0;
            float ang = Vector3.SignedAngle(f, to, Vector3.up);
            dmgDirs.Add(new Vector2(ang, Time.time));
            if (dmgDirs.Count > 6) dmgDirs.RemoveAt(0);
        }
        recoilP += Random.Range(1f, 3f);
        recoilY += Random.Range(-2f, 2f);
    }

    public void HitMarker(bool kill, bool head)
    {
        // реализм: ни звука, ни маркера — попал ли ты, видно только по цели
        hits++;
        if (kill) kills++;
    }

    public void OnDeath(DamageInfo d)
    {
        if (dead) return;
        dead = true;
        deathTime = Time.time;
        StopAllCoroutines();
        scripted = false;
        if (transform.parent != null) transform.SetParent(null, true);
        cc.enabled = false;
        // тело игрока — настоящий боец своего отряда, падает тряпичной куклой
        corpse = Soldier.Create(squad, transform.position, Quaternion.Euler(0, yaw, 0), 0, false);
        corpse.displayName = "Игрок";
        corpse.alive = false;
        corpse.hp = 0;
        corpse.inVehicle = false;
        corpse.state = Soldier.State.Dead;
        if (crouching) corpse.anim.crouch = true;
        StartCoroutine(DropCorpse(d));
        fp.SetVisible(false);
        // камера отделяется и смотрит на тело
        Game.Cam.transform.SetParent(null, true);
        Sfx.Play2D("heartbeat", 0.8f, 0.7f);
    }

    IEnumerator DropCorpse(DamageInfo d)
    {
        yield return null; // кадр, чтобы скелет встал в позу
        if (corpse == null) yield break;
        corpse.ForceDie(d, velocity);
    }

    // Ravenfield-стиль: взять под контроль живого бойца своей стороны
    public static bool TakeOver(Soldier s)
    {
        if (s == null || !s.alive || s.remoteHuman || (Net.IsClient && Net.InGame)) return false;
        int nid = s.netId;
        var def = s.squad;
        var pos = s.transform.position;
        var rot = s.transform.rotation;
        float hp = s.hp;
        if (s.squadRt != null) s.squadRt.members.Remove(s);
        Unit.All.Remove(s);
        Destroy(s.gameObject);
        SpectatorCam.Deactivate();
        var pc = Create(def);
        pc.transform.position = pos;
        pc.yaw = rot.eulerAngles.y;
        pc.unit.hp = hp;
        Net.Rebind(pc.unit, nid);
        Battle.Message("Вы взяли под контроль: " + def.name + " " + def.nick, new Color(0.6f, 0.85f, 1f));
        return true;
    }

    // ---------------- обновление ----------------
    void Update()
    {
        float dt = Time.deltaTime;
        if (Game.Paused) return;
        if (dead) { DeathCam(dt); return; }
        unit.alive = unit.hp > 0;
        Cinematic.Watchdog();
        if (!Cinematic.Active && !SpectatorCam.Active)
        {
            var gc = Game.Cam;
            if (gc != null && gc.transform.parent != camHolder) { gc.transform.SetParent(camHolder, false); gc.transform.localPosition = Vector3.zero; gc.transform.localRotation = Quaternion.identity; }
            if (fp != null) fp.EnsureShown();
        }

        // взгляд
        float wkg = Current != null ? Current.def.Weight : 3f;
        float sens = Game.Sensitivity * (1f - adsW * 0.45f) * (1f - adsW * Mathf.Clamp01(wkg / 8f) * 0.25f);
        freeLook = Input.GetKey(KeyCode.LeftAlt) && !dead;
        bool lockedNow = Cursor.lockState == CursorLockMode.Locked && Application.isFocused;
        if (lockedNow != wasLocked) { wasLocked = lockedNow; lockT = Time.unscaledTime; }
        if (Cursor.lockState == CursorLockMode.Locked)
        {
            // рывки мыши (подвисание кадра, возврат фокуса окна, захват курсора) не разворачивают камеру
            float rx = Input.GetAxisRaw("Mouse X"), ry = Input.GetAxisRaw("Mouse Y");
            if (Time.unscaledTime - lockT < 0.25f || Time.unscaledDeltaTime > 0.25f) { rx = 0; ry = 0; }
            rx = Mathf.Clamp(rx, -25f, 25f); ry = Mathf.Clamp(ry, -25f, 25f);
            float mx = rx * sens, my = ry * sens;
            if (freeLook) { freeYaw = Mathf.Clamp(freeYaw + mx, -80f, 80f); freePitch = Mathf.Clamp(freePitch - my, -45f, 50f); }
            else { yaw += mx; pitch -= my; }
        }
        if (!freeLook) { float k = 1f - Mathf.Exp(-10f * dt); freeYaw = Mathf.Lerp(freeYaw, 0f, k); freePitch = Mathf.Lerp(freePitch, 0f, k); }
        AimSway(dt, wkg);
        pitch = Mathf.Clamp(pitch, -85f, 85f);
        // отдача: подброс, который частично возвращается
        recoilVelP += (-recoilP * 40f - recoilVelP * 10f) * dt;
        recoilP += recoilVelP * dt;
        recoilY = Mathf.Lerp(recoilY, 0, dt * 6f);

        if (riding)
        {
            yaw = Mathf.Clamp(Mathf.DeltaAngle(0, yaw), -110f, 110f);
            transform.localRotation = Quaternion.Euler(0, yaw, 0);
            camHolder.localRotation = CamRot(0f);
            camHolder.localPosition = new Vector3(0, 1.15f, 0) + Fx.ShakeOffset;
            Blink();
            return;
        }
        transform.rotation = Quaternion.Euler(0, yaw + recoilY, 0);
        camHolder.localRotation = CamRot(0f);

        if (scripted) { camHolder.localPosition = new Vector3(0, camH, 0); return; }

        Move(dt);
        Weapons(dt);
        Blink();

        suppress = Mathf.MoveTowards(suppress, 0, dt * 0.5f);
        hurt = Mathf.MoveTowards(hurt, 0, dt * 0.6f);
        dmgDirs.RemoveAll(v => Time.time - v.y > 2f);
        if (healT >= 0 && Time.time > healEndT) { healT = -1; }
        if (healT >= 0 && healT < 0.5f && HealT >= 0.55f) { healT = 1f; unit.hp = Mathf.Min(unit.maxHp, unit.hp + 60f); Sfx.Play2D("magin", 0.6f, 0.7f); }

        float fovTarget = Game.Fov;
        var g = Current;
        if (g != null) fovTarget = Mathf.Lerp(Game.Fov, g.def.scope ? g.def.zoomFov : Game.Fov * 0.72f, adsW);
        Game.Cam.fieldOfView = Mathf.Lerp(Game.Cam.fieldOfView, fovTarget + sprintW * 6f, 1f - Mathf.Exp(-12f * dt));
        if (transform.position.y < -50) unit.Kill(DamageType.Fall);
    }

    void Move(float dt)
    {
        if (vaulting) return;
        Vector3 input = new Vector3((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0), 0, (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0));
        if (input.sqrMagnitude > 1) input.Normalize();
        bool crouchKey = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.C);
        bool crouchDown = Input.GetKeyDown(KeyCode.LeftControl) || Input.GetKeyDown(KeyCode.C);
        // подкат: присесть на полном бегу
        if (crouchDown && sprintW > 0.6f && grounded && slideT < 0 && !prone)
        {
            slideT = 0f; slideDir = new Vector3(velocity.x, 0, velocity.z).normalized;
            Sfx.Play2D("dirt", 0.5f, 0.8f); Sfx.Play2D("whoosh", 0.35f, 0.7f);
        }
        // лёжа: Z — лечь/встать (встать можно, только если над головой свободно)
        if (Input.GetKeyDown(KeyCode.Z) && grounded && slideT < 0)
        {
            if (!prone) { prone = true; Sfx.Play2D("bodyfall", 0.35f, 1.3f); }
            else if (!Physics.SphereCast(transform.position + Vector3.up * 0.4f, 0.3f, Vector3.up, out _, 1.2f, 1 << Layers.World, QueryTriggerInteraction.Ignore)) prone = false;
        }
        if (prone && Input.GetKeyDown(KeyCode.Space)) prone = false;
        crouching = (crouchKey || slideT >= 0) && !prone;
        bool sprint = Input.GetKey(KeyCode.LeftShift) && stamina > 0.04f && input.z > 0.5f && !crouching && !prone && adsW < 0.3f && (Current == null || !Current.reloading);
        float speed = prone ? 0.9f : crouching ? 2.3f : sprint ? 7.0f : 4.3f;
        speed *= squad.speed;
        if (adsW > 0.5f) speed *= 0.6f;
        Vector3 wish = transform.TransformDirection(input) * speed;
        if (slideT >= 0)
        {
            slideT += dt;
            wish = slideDir * Mathf.Lerp(8.8f, 2f, slideT / 0.8f);
            if (slideT > 0.8f || !crouchKey && slideT > 0.35f) slideT = -1f;
        }
        // выглядывание из-за укрытия: камера смещается вбок, если там свободно
        float leanIn = (Input.GetKey(KeyCode.E) ? 1f : 0f) - (Input.GetKey(KeyCode.Q) ? 1f : 0f);
        if (sprintW > 0.4f || slideT >= 0) leanIn = 0f;
        if (leanIn != 0f)
        {
            Vector3 head = transform.position + Vector3.up * camH;
            if (Physics.SphereCast(head, 0.15f, transform.right * leanIn, out var lh, 0.55f, 1 << Layers.World, QueryTriggerInteraction.Ignore))
                leanIn *= Mathf.Clamp01((lh.distance - 0.1f) / 0.45f);
        }
        lean = Mathf.Lerp(lean, leanIn, 1f - Mathf.Exp(-9f * dt));
        // перелезание: пробел перед препятствием по пояс-грудь
        if (grounded && !prone && !vaulting && Input.GetKeyDown(KeyCode.Space) && input.z > 0.3f && TryVault()) return;
        Vector3 hv = new Vector3(velocity.x, 0, velocity.z);
        float acc = grounded ? 14f : 3f;
        hv = Vector3.MoveTowards(hv, wish, acc * speed * dt * 0.5f + acc * dt);
        grounded = cc.isGrounded;
        if (grounded)
        {
            if (vy < -8f) { landKick = Mathf.Clamp01(-vy / 12f); Sfx.Play2D("land", 0.7f); }
            if (vy < -16f) unit.TakeDamage(new DamageInfo { amount = (-vy - 16f) * 10f, type = DamageType.Fall, dir = Vector3.down, point = transform.position });
            vy = -2f;
            if (Input.GetKeyDown(KeyCode.Space) && !crouching && !prone && !vaulting && stamina > 0.1f) { vy = 5.2f; stamina -= 0.08f; staminaT = Time.time; Sfx.Play2D("gear", 0.25f, Random.Range(0.9f, 1.1f)); }
        }
        else vy -= 20f * dt;
        knock = Vector3.Lerp(knock, Vector3.zero, dt * 3f);
        velocity = hv + Vector3.up * vy + knock;
        cc.Move(velocity * dt);
        sprintW = Mathf.Lerp(sprintW, sprint && hv.magnitude > 4f ? 1f : 0f, 1f - Mathf.Exp(-8f * dt));
        // присед
        float targetH = prone ? 0.6f : crouching ? 1.15f : 1.8f;
        cc.height = Mathf.Lerp(cc.height, targetH, 1f - Mathf.Exp(-12f * dt));
        cc.center = new Vector3(0, cc.height / 2f, 0);
        camH = Mathf.Lerp(camH, prone ? 0.36f : slideT >= 0 ? 0.85f : crouching ? 1.02f : 1.65f, 1f - Mathf.Exp(-(prone ? 6f : 12f) * dt));
        // покачивание головы
        float hs = hv.magnitude;
        if (grounded && hs > 0.5f)
        {
            float prev = bob;
            bob += hs * dt * 1.6f;
            if (Mathf.Floor(prev / Mathf.PI) != Mathf.Floor(bob / Mathf.PI)) { Sfx.Play2D(Sfx.Step, 0.18f + sprintW * 0.12f, Random.Range(0.85f, 1.15f)); if (Random.value < 0.3f + sprintW * 0.4f) Sfx.Play2D("gear", 0.07f + sprintW * 0.1f, Random.Range(0.9f, 1.15f)); }
        }
        bobAmt = Mathf.Lerp(bobAmt, grounded ? Mathf.Clamp01(hs / 7f) : 0f, 1f - Mathf.Exp(-6f * dt));
        landKick = Mathf.MoveTowards(landKick, 0, dt * 3f);
        Vector3 bobOff = new Vector3(Mathf.Cos(bob) * 0.03f, Mathf.Abs(Mathf.Sin(bob)) * 0.05f - 0.025f, 0) * bobAmt * (1f - adsW * 0.8f);
        // нательная камера: тяжелее раскачивается на шагах, запаздывает на поворотах, живая дрожь рук и тела
        Quaternion bc = Quaternion.identity;
        if (PostFX.Bodycam)
        {
            bobOff *= 1.7f;
            float yv = Mathf.DeltaAngle(lastYawBC, yaw) / Mathf.Max(dt, 0.001f); lastYawBC = yaw;
            bcRoll = Mathf.Lerp(bcRoll, Mathf.Clamp(-yv * 0.018f, -5f, 5f), 1f - Mathf.Exp(-6f * dt));
            float tt = Time.time;
            float still = 1f - adsW * 0.6f;
            float bp = (Mathf.PerlinNoise(tt * 0.7f, 11f) - 0.5f) * 0.7f * still + Mathf.Sin(bob * 2f) * 0.9f * bobAmt * (1f - adsW * 0.7f);
            float by = (Mathf.PerlinNoise(23f, tt * 0.6f) - 0.5f) * 0.7f * still + Mathf.Cos(bob) * 0.6f * bobAmt * (1f - adsW * 0.7f);
            float br = Mathf.Sin(bob) * 1.6f * bobAmt * (1f - adsW * 0.6f) + bcRoll;
            bc = Quaternion.Euler(bp, by, br);
        }
        camHolder.localPosition = new Vector3(lean * 0.42f, camH - landKick * 0.12f - Mathf.Abs(lean) * 0.07f, 0) + bobOff + Fx.ShakeOffset;
        camHolder.localRotation = CamRot(-lean * 13f + (slideT >= 0 ? 4f : 0f)) * bc;
    }

    Quaternion CamRot(float roll) => Quaternion.Euler(pitch - recoilP + swayP, swayY, roll) * FreeRot;

    // Раскачка прицела: дыхание и усталость, вес оружия; Shift в прицеле — задержать дыхание (на несколько секунд)
    void AimSway(float dt, float wkg)
    {
        bool want = adsW > 0.6f && Input.GetKey(KeyCode.LeftShift) && exhaleT < 0 && breath > 0.02f;
        if (want && !holdingBreath) Sfx.Play2D("breath_in", 0.35f, Random.Range(0.95f, 1.05f));
        if (!want && holdingBreath) Sfx.Play2D(breath < 0.05f ? "breath_heavy" : "breath_out", 0.35f, Random.Range(0.95f, 1.05f));
        if (holdingBreath && breath <= 0.02f) exhaleT = 0f;
        holdingBreath = want;
        if (holdingBreath) breath = Mathf.MoveTowards(breath, 0f, dt / 6f);
        else breath = Mathf.MoveTowards(breath, 1f, dt / 4f);
        if (exhaleT >= 0) { exhaleT += dt; if (exhaleT > 2.2f) exhaleT = -1f; }
        float tired = 1f - stamina;
        breathT += dt * (holdingBreath ? 0.25f : 1.1f + tired * 2f + (exhaleT >= 0 ? 1.5f : 0f));
        float amp = adsW * (0.18f + tired * 0.9f + wkg * 0.035f + (exhaleT >= 0 ? 0.8f : 0f)) * (holdingBreath ? 0.12f : 1f)
                    * (prone ? 0.35f : crouching ? 0.7f : 1f) * (1f + hurt * 1.5f);
        float t = Time.time;
        swayP = (Mathf.Sin(breathT * 1.9f) * 0.55f + (Mathf.PerlinNoise(t * 0.45f, 3.1f) - 0.5f) * 1.6f) * amp;
        swayY = ((Mathf.PerlinNoise(7.7f, t * 0.4f) - 0.5f) * 2f + Mathf.Sin(breathT * 0.95f) * 0.25f) * amp;
        // выносливость: бег и прыжки отнимают, отдых восстанавливает
        if (sprintW > 0.5f) { stamina = Mathf.MoveTowards(stamina, 0f, dt / 14f); staminaT = Time.time; }
        else if (Time.time - staminaT > 0.8f) stamina = Mathf.MoveTowards(stamina, 1f, dt / (crouching || prone ? 5f : 7f));
        if (stamina < 0.3f && Random.value < dt * 0.6f) Sfx.Play2D("breath_heavy", 0.18f * (1f - stamina), Random.Range(0.9f, 1.1f));
    }

    bool TryVault()
    {
        Vector3 f = transform.forward; f.y = 0; f.Normalize();
        Vector3 feet = transform.position;
        int mask = 1 << Layers.World;
        if (!Physics.Raycast(feet + Vector3.up * 0.55f, f, out var low, 1.1f, mask, QueryTriggerInteraction.Ignore)) return false;
        if (Physics.Raycast(feet + Vector3.up * 1.7f, f, low.distance + 0.6f, mask, QueryTriggerInteraction.Ignore)) return false;   // стена выше головы
        Vector3 probe = feet + f * (low.distance + 0.45f) + Vector3.up * 1.8f;
        if (!Physics.Raycast(probe, Vector3.down, out var top, 1.8f, mask, QueryTriggerInteraction.Ignore)) return false;
        float h = top.point.y - feet.y;
        if (h < 0.4f || h > 1.45f) return false;
        // за препятствием: спускаемся на землю, если оно тонкое
        Vector3 over = feet + f * (low.distance + 1.3f) + Vector3.up * (h + 1.2f);
        Vector3 land = top.point + f * 0.3f;
        if (Physics.Raycast(over, Vector3.down, out var beyond, h + 3f, mask, QueryTriggerInteraction.Ignore) && beyond.point.y < top.point.y - 0.3f)
            land = beyond.point;
        StartCoroutine(VaultRoutine(top.point, land, h));
        return true;
    }

    IEnumerator VaultRoutine(Vector3 top, Vector3 land, float h)
    {
        vaulting = true;
        cc.enabled = false;
        Sfx.Play2D("land", 0.35f, 1.3f);
        fp.Kick(-0.6f);
        Vector3 a = transform.position, mid = top + Vector3.up * 0.15f;
        float t = 0, d1 = 0.22f + h * 0.12f;
        while (t < d1 && !dead)
        {
            t += Time.deltaTime; float k = Mathf.SmoothStep(0, 1, t / d1);
            transform.position = Vector3.Lerp(a, mid, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 0.2f;
            camHolder.localRotation = Quaternion.Euler(pitch - recoilP + 6f * Mathf.Sin(k * Mathf.PI), 0, 8f * Mathf.Sin(k * Mathf.PI));
            yield return null;
        }
        t = 0;
        Vector3 b = transform.position;
        while (t < 0.25f && !dead)
        {
            t += Time.deltaTime; float k = Mathf.SmoothStep(0, 1, t / 0.25f);
            transform.position = Vector3.Lerp(b, land, k);
            yield return null;
        }
        Sfx.Play2D(Sfx.Step, 0.45f, 0.9f);
        cc.enabled = true;
        velocity = transform.forward * 3.5f; vy = -2f;
        vaulting = false;
    }

    void Weapons(float dt)
    {
        var g = Current;
        if (g == null) return;
        g.Tick(transform.position);
        // смена оружия
        int want = -1;
        if (Input.GetKeyDown(KeyCode.Alpha1)) want = 0;
        if (Input.GetKeyDown(KeyCode.Alpha2)) want = 1;
        if (Input.GetKeyDown(KeyCode.Alpha3)) want = 2;
        float wheel = Input.GetAxis("Mouse ScrollWheel");
        if (wheel != 0)
        {
            int d = wheel > 0 ? -1 : 1;
            for (int i = 1; i <= 3; i++) { int k = ((cur + d * i) % 3 + 3) % 3; if (guns[k] != null) { want = k; break; } }
        }
        if (want >= 0 && want != cur && guns[want] != null && switchT < 0)
        {
            magCheck = false;
            g.CancelReload();
            switchT = 0; switchTo = want; swapped = false;
            Sfx.Play2D("weapon_switch", 0.5f);
        }
        if (switchT >= 0)
        {
            switchT += dt / 0.55f;
            if (switchT >= 0.5f && !swapped) { swapped = true; Equip(switchTo); }
            if (switchT >= 1f) switchT = -1;
            return;
        }
        // фонарик
        if (Input.GetKeyDown(KeyCode.F))
        {
            flashlightOn = !flashlightOn;
            fp.SetFlashlight(flashlightOn);
            Sfx.Play2D("click", 0.5f);
        }
        // граната
        if (Input.GetKeyDown(KeyCode.G) && grenades > 0 && throwT < 0 && !safe)
        {
            magCheck = false;
            throwT = 0;
            g.CancelReload();
        }
        if (throwT >= 0)
        {
            // взвод (0.3–0.45 — чека), замах, бросок в 0.6
            float prev = throwT;
            throwT += dt / 1.05f;
            if (prev < 0.36f && throwT >= 0.36f) Sfx.Play2D("click", 0.7f, 1.6f);
            if (throwT >= 0.6f && prev < 0.6f && grenades > 0)
            {
                grenades--;
                Vector3 from = fp.GrenadeWorldPos;
                if (Physics.Linecast(camHolder.position, from, Layers.SightMask)) from = camHolder.position + camHolder.forward * 0.3f;
                Grenade.Spawn(from, camHolder.forward * 17f + Vector3.up * 3f + velocity * 0.5f, unit, false, 170f);
                Sfx.Play2D("whoosh", 0.5f);
            }
            if (throwT >= 1f) throwT = -1;
            return;
        }
        // удар прикладом
        if (Input.GetKeyDown(KeyCode.V) && !fp.Busy) { fp.Melee(); meleeHit = false; g.CancelReload(); Sfx.Play2D("whoosh", 0.5f, 1.4f); }
        if (fp.MeleeT >= 0)
        {
            if (!meleeHit && fp.MeleeT > 0.3f)
            {
                meleeHit = true;
                if (Combat.Ray(camHolder.position, camHolder.forward, 2.2f, unit, out var mh))
                {
                    var hb = mh.collider.GetComponent<Hitbox>();
                    if (hb != null && hb.owner != null && hb.owner.alive)
                    {
                        hb.owner.TakeDamage(new DamageInfo { amount = 55f, type = DamageType.Melee, attacker = unit, dir = camHolder.forward, force = 500f, point = mh.point, hitbox = hb, weapon = "Приклад" });
                        Fx.Blood(mh.point, camHolder.forward, 0.8f);
                        HitMarker(!hb.owner.alive, false);
                    }
                    else Fx.Impact(mh.point, mh.normal, new Color(0.5f, 0.5f, 0.5f), false);
                    Sfx.Play2D("flesh", 0.9f, 0.8f);
                    Fx.shake = Mathf.Max(Fx.shake, 0.25f);
                }
            }
            return;
        }
        if (Input.GetKeyDown(KeyCode.I)) fp.Inspect();
        // переводчик огня
        if (Input.GetKeyDown(KeyCode.B) && g.def.auto) { g.semi = !g.semi; Sfx.Play2D("click", 0.5f, 0.8f); }
        // команды своему отряду: X — занять точку, куда смотрю; Y — за мной; U — вернуться к приказу командира
        if (Input.GetKeyDown(KeyCode.X) || Input.GetKeyDown(KeyCode.Y) || Input.GetKeyDown(KeyCode.U)) SquadOrder();
        // аптечка
        if (Input.GetKeyDown(KeyCode.H) && medkits > 0 && healT < 0 && unit.hp < unit.maxHp)
        {
            medkits--;
            healT = 0f;
            healEndT = Time.time + 1.4f;
            Sfx.Play2D("magout", 0.6f, 0.6f);
        }
        // R: коротко — перезарядка, зажать — вынуть магазин и посмотреть, сколько осталось
        if (Input.GetKeyDown(KeyCode.R)) rDownT = Time.time;
        if (rDownT > 0 && Input.GetKey(KeyCode.R) && !magCheck && Time.time - rDownT > 0.28f && !g.reloading && !g.def.rocket)
        {
            magCheck = true;
            Sfx.Play2D(g.Shells ? "click" : "magout", 0.3f, 1.25f);
        }
        if (Input.GetKeyUp(KeyCode.R) || (rDownT > 0 && !Input.GetKey(KeyCode.R)))
        {
            if (magCheck) { magCheck = false; Sfx.Play2D(g.Shells ? "click" : "magin", 0.4f, 1.15f); }
            else if (rDownT > 0 && !g.reloading && g.ammo < g.def.mag) g.StartReload(transform.position);
            rDownT = -1;
        }
        if (magCheck || fp.MagCheckW > 0.05f) { adsW = Mathf.MoveTowards(adsW, 0f, dt / 0.18f); return; }
        // прицеливание
        bool ads = Input.GetMouseButton(1) && (!g.reloading || g.Shells) && sprintW < 0.5f && healT < 0 && !freeLook && fp.WallK < 0.5f;
        if (ads && adsW == 0f) Sfx.Play2D("gear", 0.2f, Random.Range(1.05f, 1.2f));
        adsW = Mathf.MoveTowards(adsW, ads ? 1f : 0f, dt / (0.13f + g.def.Weight * 0.028f));
        // стрельба
        bool trig = g.def.auto && !g.semi ? Input.GetMouseButton(0) : Input.GetMouseButtonDown(0);
        if (trig && safe && Input.GetMouseButtonDown(0)) Sfx.Play2D("click", 0.3f, 1.4f);
        if (trig && !safe && Cursor.lockState == CursorLockMode.Locked && sprintW < 0.4f && healT < 0 && !fp.Busy)
        {
            if (g.ammo <= 0 && !g.reloading)
            {
                // реализм: щелчок — и сам решай, когда перезаряжаться
                if (Input.GetMouseButtonDown(0)) Sfx.Play2D("click", 0.6f);
            }
            else
            {
                float hv = new Vector2(velocity.x, velocity.z).magnitude;
                float spread = Mathf.Lerp(1f, 0.3f, adsW) * (1f + hv / 6f) * (prone ? 0.55f : crouching ? 0.75f : 1f) * (grounded ? 1f : 2.5f) * (slideT >= 0 ? 1.8f : 1f);
                if (g.def.kind == WeaponKind.Shotgun) spread = Mathf.Max(spread, 0.8f);
                // мировая точка дульного среза (вьюмодель рисуется своей камерой — пересчитываем)
                Vector3 worldMuzzle = fp.gm != null ? fp.ToWorld(fp.gm.muzzle.position) : camHolder.position;
                if (g.Fire(unit, camHolder.position, AimForward, spread, worldMuzzle))
                {
                    float r = g.def.recoil * (1f - adsW * 0.35f) * (prone ? 0.6f : crouching ? 0.8f : 1f) * Mathf.Lerp(1.15f, 0.8f, Mathf.Clamp01((g.def.Weight - 1f) / 6f));
                    recoilVelP += r * 16f;
                    pitch -= r * 0.35f;
                    yaw += Random.Range(-0.35f, 0.35f) * r;
                    fp.Kick(r);
                    Fx.shake = Mathf.Max(Fx.shake, 0.05f * r);
                    Game.Cam.fieldOfView += r * (g.def.kind == WeaponKind.Sniper || g.def.kind == WeaponKind.Shotgun ? 1.6f : 0.6f);   // толчок выстрела
                    barrelHeat = Mathf.Min(1.5f, barrelHeat + (g.def.kind == WeaponKind.LMG ? 0.06f : 0.09f));
                    lastShotT = Time.time;
                }
            }
        }
        // ствол дымит после очереди
        barrelHeat = Mathf.MoveTowards(barrelHeat, 0f, dt * 0.25f);
        if (barrelHeat > 0.35f && Time.time - lastShotT > 0.25f && fp.gm != null && Random.value < dt * 14f * barrelHeat)
            Fx.BarrelSmoke(fp.ToWorld(fp.gm.muzzle.position), camHolder.forward, barrelHeat);
        spreadNow = g.def.spread * Mathf.Lerp(1f, 0.3f, adsW) * (1f + new Vector2(velocity.x, velocity.z).magnitude / 6f) * (crouching ? 0.75f : 1f);
    }

    void SquadOrder()
    {
        var b = Battle.I;
        var sq = b != null ? b.SquadOf(squad) : null;
        if (sq == null || sq.Alive == 0) return;
        string who = squad.name.Split(' ')[0];
        if (Input.GetKeyDown(KeyCode.U))
        {
            sq.playerCmdUntil = -1f;
            Battle.Message("Вы → " + who + ": Работаем по приказу командира операции.", new Color(0.7f, 0.85f, 1f), 4f);
        }
        else if (Input.GetKeyDown(KeyCode.Y))
        {
            sq.playerCmdUntil = Time.time + 120f; sq.playerFollow = true;
            Battle.Message("Вы → " + who + ": За мной! Держаться рядом.", new Color(0.7f, 0.85f, 1f), 4f);
        }
        else
        {
            Vector3 p = transform.position + transform.forward * 10f;
            if (Physics.Raycast(camHolder.position, camHolder.forward, out var h, 120f, 1 << Layers.World, QueryTriggerInteraction.Ignore)) p = h.point;
            sq.playerCmdUntil = Time.time + 120f; sq.playerFollow = false; sq.playerCmdPos = p;
            Battle.Message("Вы → " + who + ": Занять позицию, " + Mathf.RoundToInt(Vector3.Distance(transform.position, p)) + " м впереди!", new Color(0.7f, 0.85f, 1f), 4f);
        }
        Sfx.Play2D("radio", 0.35f);
        var l = sq.Leader; if (l != null) l.anim.DoSignal(Input.GetKeyDown(KeyCode.X) ? Signal.Point : Signal.Regroup);
    }

    void Blink()
    {
        if (Battle.I == null || !Battle.I.has173 || squad.blinkImmune) return;
        if (Time.time > blinkT)
        {
            blinkEnd = Time.time + 0.22f;
            blinkT = Time.time + Random.Range(5f, 8f);
        }
    }

    // ---------------- смерть ----------------
    void DeathCam(float dt)
    {
        var cam = Game.Cam.transform;
        Vector3 focus = corpse != null && corpse.rig != null ? corpse.rig.b[HumanRig.Chest].position : transform.position;
        float t = Time.time - deathTime;
        Vector3 back = (cam.position - focus); back.y = 0;
        if (back.sqrMagnitude < 0.01f) back = -transform.forward;
        back.Normalize();
        Vector3 want = focus + back * Mathf.Lerp(1.5f, 4.5f, Mathf.Clamp01(t / 3f)) + Vector3.up * Mathf.Lerp(0.8f, 2.6f, Mathf.Clamp01(t / 3f));
        cam.position = Vector3.Lerp(cam.position, want, 1f - Mathf.Exp(-3f * dt));
        cam.rotation = Quaternion.Slerp(cam.rotation, Quaternion.LookRotation(focus - cam.position), 1f - Mathf.Exp(-5f * dt));
        Game.Cam.fieldOfView = Mathf.Lerp(Game.Cam.fieldOfView, 60f, dt * 2f);
    }
}
