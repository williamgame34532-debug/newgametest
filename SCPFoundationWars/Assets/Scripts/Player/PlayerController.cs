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
    protected override void Die(DamageInfo d) { pc.OnDeath(d); }
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
    public float hitMarkT = -1; public bool hitKill, hitHead;
    public bool Blinking => Time.time < blinkEnd;
    float blinkT, blinkEnd;
    bool grounded;
    float vy;
    Vector3 knock;
    bool flashlightOn;
    public float spreadNow;
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
        pc.unit.team = Team.Foundation;
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

        pc.guns[0] = new Gun(DB.W(def.primary)) { reserveMags = 8 };
        pc.guns[1] = def.secondary != null ? new Gun(DB.W(def.secondary)) { reserveMags = 6 } : null;
        pc.guns[2] = def.special != null ? new Gun(DB.W(def.special)) { reserveMags = def.special == "rpg" ? 4 : 3 } : null;
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

    // ---------------- вертолёт ----------------
    public void RideIn(Helicopter heli, Transform seat)
    {
        riding = true;
        rideSeat = seat;
        cc.enabled = false;
        unit.inVehicle = true;
        transform.SetParent(seat, false);
        transform.localPosition = Vector3.zero;
        transform.localRotation = Quaternion.identity;
        yaw = 0; pitch = 5;
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
        Sfx.Play2D("step", 0.8f, 0.8f);
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
        hitMarkT = Time.time;
        hitKill = kill; hitHead = head;
        Sfx.Play2D("hitmarker", kill ? 0.7f : 0.4f, kill ? 0.8f : head ? 1.4f : 1f);
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
        if (s == null || !s.alive) return false;
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

        // взгляд
        float sens = Game.Sensitivity * (1f - adsW * 0.45f);
        if (Cursor.lockState == CursorLockMode.Locked)
        {
            yaw += Input.GetAxisRaw("Mouse X") * sens;
            pitch -= Input.GetAxisRaw("Mouse Y") * sens;
        }
        pitch = Mathf.Clamp(pitch, -85f, 85f);
        // отдача: подброс, который частично возвращается
        recoilVelP += (-recoilP * 40f - recoilVelP * 10f) * dt;
        recoilP += recoilVelP * dt;
        recoilY = Mathf.Lerp(recoilY, 0, dt * 6f);

        if (riding)
        {
            yaw = Mathf.Clamp(Mathf.DeltaAngle(0, yaw), -110f, 110f);
            transform.localRotation = Quaternion.Euler(0, yaw, 0);
            camHolder.localRotation = Quaternion.Euler(pitch - recoilP, 0, 0);
            camHolder.localPosition = new Vector3(0, 1.15f, 0) + Fx.ShakeOffset;
            Blink();
            return;
        }
        transform.rotation = Quaternion.Euler(0, yaw + recoilY, 0);
        camHolder.localRotation = Quaternion.Euler(pitch - recoilP, 0, 0);

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
        Vector3 input = new Vector3((Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0), 0, (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0));
        if (input.sqrMagnitude > 1) input.Normalize();
        bool wantCrouch = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.C);
        crouching = wantCrouch;
        bool sprint = Input.GetKey(KeyCode.LeftShift) && input.z > 0.5f && !crouching && adsW < 0.3f && (Current == null || !Current.reloading);
        float speed = crouching ? 2.3f : sprint ? 7.0f : 4.3f;
        speed *= squad.speed;
        if (adsW > 0.5f) speed *= 0.6f;
        Vector3 wish = transform.TransformDirection(input) * speed;
        Vector3 hv = new Vector3(velocity.x, 0, velocity.z);
        float acc = grounded ? 14f : 3f;
        hv = Vector3.MoveTowards(hv, wish, acc * speed * dt * 0.5f + acc * dt);
        grounded = cc.isGrounded;
        if (grounded)
        {
            if (vy < -8f) { landKick = Mathf.Clamp01(-vy / 12f); Sfx.Play2D("step", 0.6f, 0.8f); }
            if (vy < -16f) unit.TakeDamage(new DamageInfo { amount = (-vy - 16f) * 10f, type = DamageType.Fall, dir = Vector3.down, point = transform.position });
            vy = -2f;
            if (Input.GetKeyDown(KeyCode.Space) && !crouching) vy = 5.2f;
        }
        else vy -= 20f * dt;
        knock = Vector3.Lerp(knock, Vector3.zero, dt * 3f);
        velocity = hv + Vector3.up * vy + knock;
        cc.Move(velocity * dt);
        sprintW = Mathf.Lerp(sprintW, sprint && hv.magnitude > 4f ? 1f : 0f, 1f - Mathf.Exp(-8f * dt));
        // присед
        float targetH = crouching ? 1.15f : 1.8f;
        cc.height = Mathf.Lerp(cc.height, targetH, 1f - Mathf.Exp(-12f * dt));
        cc.center = new Vector3(0, cc.height / 2f, 0);
        camH = Mathf.Lerp(camH, crouching ? 1.02f : 1.65f, 1f - Mathf.Exp(-12f * dt));
        // покачивание головы
        float hs = hv.magnitude;
        if (grounded && hs > 0.5f)
        {
            float prev = bob;
            bob += hs * dt * 1.6f;
            if (Mathf.Floor(prev / Mathf.PI) != Mathf.Floor(bob / Mathf.PI)) Sfx.Play2D("step", 0.18f + sprintW * 0.12f, Random.Range(0.85f, 1.15f));
        }
        bobAmt = Mathf.Lerp(bobAmt, grounded ? Mathf.Clamp01(hs / 7f) : 0f, 1f - Mathf.Exp(-6f * dt));
        landKick = Mathf.MoveTowards(landKick, 0, dt * 3f);
        Vector3 bobOff = new Vector3(Mathf.Cos(bob) * 0.03f, Mathf.Abs(Mathf.Sin(bob)) * 0.05f - 0.025f, 0) * bobAmt * (1f - adsW * 0.8f);
        camHolder.localPosition = new Vector3(0, camH - landKick * 0.12f, 0) + bobOff + Fx.ShakeOffset;
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
            g.CancelReload();
            switchT = 0; switchTo = want; swapped = false;
            Sfx.Play2D("magout", 0.3f, 1.4f);
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
        if (Input.GetKeyDown(KeyCode.G) && grenades > 0 && throwT < 0)
        {
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
        // аптечка
        if (Input.GetKeyDown(KeyCode.H) && medkits > 0 && healT < 0 && unit.hp < unit.maxHp)
        {
            medkits--;
            healT = 0f;
            healEndT = Time.time + 1.4f;
            Sfx.Play2D("magout", 0.6f, 0.6f);
        }
        // перезарядка
        if (Input.GetKeyDown(KeyCode.R) && !g.reloading && g.ammo < g.def.mag) g.StartReload(transform.position);
        // прицеливание
        bool ads = Input.GetMouseButton(1) && (!g.reloading || g.Shells) && sprintW < 0.5f && healT < 0;
        adsW = Mathf.MoveTowards(adsW, ads ? 1f : 0f, dt / 0.18f);
        // стрельба
        bool trig = g.def.auto ? Input.GetMouseButton(0) : Input.GetMouseButtonDown(0);
        if (trig && Cursor.lockState == CursorLockMode.Locked && sprintW < 0.4f && healT < 0 && !fp.Busy)
        {
            if (g.ammo <= 0 && !g.reloading)
            {
                if (Input.GetMouseButtonDown(0)) Sfx.Play2D("click", 0.6f);
                if (g.reserveMags > 0) g.StartReload(transform.position);
            }
            else
            {
                float hv = new Vector2(velocity.x, velocity.z).magnitude;
                float spread = Mathf.Lerp(1f, 0.3f, adsW) * (1f + hv / 6f) * (crouching ? 0.75f : 1f) * (grounded ? 1f : 2.5f);
                if (g.def.kind == WeaponKind.Shotgun) spread = Mathf.Max(spread, 0.8f);
                // мировая точка дульного среза (вьюмодель рисуется своей камерой — пересчитываем)
                Vector3 worldMuzzle = fp.gm != null ? fp.ToWorld(fp.gm.muzzle.position) : camHolder.position;
                if (g.Fire(unit, camHolder.position, camHolder.forward, spread, worldMuzzle))
                {
                    float r = g.def.recoil * (1f - adsW * 0.35f) * (crouching ? 0.8f : 1f);
                    recoilVelP += r * 16f;
                    pitch -= r * 0.35f;
                    yaw += Random.Range(-0.35f, 0.35f) * r;
                    fp.Kick(r);
                    Fx.shake = Mathf.Max(Fx.shake, 0.05f * r);
                }
            }
        }
        spreadNow = g.def.spread * Mathf.Lerp(1f, 0.3f, adsW) * (1f + new Vector2(velocity.x, velocity.z).magnitude / 6f) * (crouching ? 0.75f : 1f);
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
