using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

// Отряд во время боя
public class SquadRt
{
    public SquadDef def;
    public Team team;
    public readonly List<Soldier> members = new List<Soldier>();
    public Soldier Leader { get { foreach (var m in members) if (m != null && m.alive && !m.zombie && m.state == Soldier.State.Combat) return m; return null; } }
    public int Alive { get { int n = 0; foreach (var m in members) if (m != null && m.alive) n++; return n; } }
}

// Боец (МОГ, Повстанцы, а также оживлённые SCP-049-2) с ИИ
public class Soldier : Unit
{
    public enum State { Transport, Scripted, Combat, Dead }

    public State state = State.Transport;
    public HumanRig rig;
    public HumanAnimator anim;
    public Ragdoll ragdoll;
    public NavMeshAgent agent;
    public SquadRt squadRt;
    public int index;
    public Gun primary, secondary, special, current;
    public int grenades;
    public bool zombie;
    public float accuracy = 1f, speedMul = 1f, courage = 1f;
    public Vector3 homeDir = Vector3.forward;   // откуда пришли (для отступления)

    Unit target;
    float thinkT, moveT, fireT, burstLeft, strafeT, grenadeT, switchT, blinkT, blinkEnd, crouchT, sightT;
    int strafeDir = 1;
    bool targetVisible;
    Vector3 aimDir;
    Vector3 aimNoise;
    float aimSettle;
    float throwStart = -1;
    float attackStart = -1;
    bool attackHit;
    Vector3 lastPos;
    Vector3 vel;

    public override Vector3 Velocity => vel;
    public override Vector3 LookDir => aimDir;
    public bool Blinking => Time.time < blinkEnd;

    // ---------------- создание ----------------
    public static Soldier Create(SquadDef def, Vector3 pos, Quaternion rot, int index, bool flashlight)
    {
        var go = new GameObject((def.team == Team.Foundation ? "MTF " : "CI ") + def.name + " #" + (index + 1));
        go.transform.SetPositionAndRotation(pos, rot);
        go.transform.localScale = Vector3.one * def.scale * Random.Range(0.97f, 1.03f);
        var s = go.AddComponent<Soldier>();
        s.team = def.team;
        s.squad = def;
        s.index = index;
        s.displayName = def.name;
        s.maxHp = s.hp = def.hp;
        s.armor = def.armor;
        s.accuracy = def.accuracy;
        s.speedMul = def.speed;
        s.courage = def.courage;
        s.grenades = def.grenades;
        s.threat = def.hp / 100f;

        var look = def.look;
        // немного разнообразия в оттенке кожи у открытых лиц
        if (look.head == HeadGear.Bare || look.head == HeadGear.Cap || look.head == HeadGear.Helmet || look.head == HeadGear.NightVision)
        {
            var l2 = look.Clone();
            float tone = Random.Range(0.45f, 1.05f);
            l2.skin = new Color(0.9f * tone + 0.05f, 0.7f * tone + 0.04f, 0.58f * tone + 0.03f);
            look = l2;
        }
        s.BuildBody(look, BodyShape.Soldier(look.bulk));

        s.primary = new Gun(DB.W(def.primary));
        if (def.secondary != null) s.secondary = new Gun(DB.W(def.secondary));
        if (def.special != null) { s.special = new Gun(DB.W(def.special)); s.special.reserveMags = def.special == "rpg" ? 4 : 3; }
        s.Equip(s.primary, flashlight);
        return s;
    }

    public void BuildBody(Look look, BodyShape shape)
    {
        rig = HumanRig.Create(transform, shape);
        if (look != null) rig.DressSoldier(look);
        rig.Finish();
        ragdoll = Ragdoll.BuildHuman(rig, this);
        anim = gameObject.AddComponent<HumanAnimator>();
        anim.rig = rig;
        eye = rig.eye;
        chestPoint = rig.b[HumanRig.Chest];
        aimDir = transform.forward;
        lastPos = transform.position;
        blinkT = Time.time + Random.Range(2f, 6f);
    }

    bool flashlightOn;
    public void Equip(Gun g, bool flashlight)
    {
        if (g == null) return;
        flashlightOn = flashlight;
        if (current != null && current.model != null) Destroy(current.model.gameObject);
        current = g;
        g.model = WeaponModels.Build(g.def, transform, flashlight && g.def.kind != WeaponKind.Launcher);
        anim.gun = g.model;
        switchT = Time.time + 0.5f;
    }

    // Агент навигации создаётся только когда боец уже стоит на навмеше (иначе Unity ругается)
    bool EnsureAgent(Vector3 pos)
    {
        if (!NavMesh.SamplePosition(pos, out var nh, 6f, NavMesh.AllAreas)) return false;
        transform.position = nh.position;
        if (agent == null)
        {
            agent = gameObject.AddComponent<NavMeshAgent>();
            agent.radius = 0.38f;
            agent.height = 1.8f;
            agent.speed = 4f;
            agent.acceleration = 14f;
            agent.angularSpeed = 0f;
            agent.updateRotation = false;
            agent.autoBraking = true;
            agent.stoppingDistance = 0.6f;
            agent.obstacleAvoidanceType = ObstacleAvoidanceType.MedQualityObstacleAvoidance;
            agent.avoidancePriority = Random.Range(30, 70);
        }
        agent.enabled = true;
        agent.Warp(nh.position);
        return true;
    }

    // ---------------- высадка ----------------
    public void SitIn(Transform seat)
    {
        state = State.Transport;
        inVehicle = true;
        transform.SetParent(seat, false);
        transform.localPosition = Vector3.zero;
        transform.localRotation = Quaternion.identity;
        anim.seated = true;
        anim.Snap();
    }

    public void BeginCombat(Vector3 groundPos)
    {
        transform.SetParent(null, true);
        inVehicle = false;
        anim.seated = false; anim.onRope = false; anim.airborne = false; anim.slung = false;
        if (!EnsureAgent(groundPos)) transform.position = groundPos;
        Vector3 f = transform.forward; f.y = 0;
        if (f.sqrMagnitude > 0.01f) transform.rotation = Quaternion.LookRotation(f);
        state = State.Combat;
        thinkT = Time.time + Random.Range(0.1f, 0.5f);
    }

    // Выход из приземлившегося вертолёта: шаг к двери, прыжок, приземление, отбегание
    public IEnumerator ExitLanded(Vector3 door, Vector3 outward, Vector3 ground)
    {
        state = State.Scripted;
        transform.SetParent(null, true);
        anim.seated = false;
        Vector3 start = transform.position;
        Quaternion startRot = transform.rotation;
        Quaternion faceOut = Quaternion.LookRotation(new Vector3(outward.x, 0, outward.z).normalized);
        float t = 0;
        while (t < 0.55f)
        {
            t += Time.deltaTime;
            float k = Mathf.SmoothStep(0, 1, t / 0.55f);
            Vector3 p = Vector3.Lerp(start, door, k);
            vel = (p - transform.position) / Mathf.Max(0.001f, Time.deltaTime);
            transform.position = p;
            transform.rotation = Quaternion.Slerp(startRot, faceOut, k);
            anim.velocity = vel; anim.aimDir = transform.forward;
            yield return null;
        }
        // прыжок
        anim.airborne = true;
        Vector3 a = transform.position;
        float dur = 0.55f;
        t = 0;
        Sfx.Play("whoosh", a, 0.25f, 1.3f, 20f);
        while (t < dur)
        {
            t += Time.deltaTime;
            float k = Mathf.Clamp01(t / dur);
            Vector3 p = Vector3.Lerp(a, ground, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 0.6f;
            vel = (p - transform.position) / Mathf.Max(0.001f, Time.deltaTime);
            transform.position = p;
            anim.velocity = new Vector3(vel.x, 0, vel.z) * 0.3f;
            yield return null;
        }
        anim.airborne = false;
        Sfx.Play("step", ground, 0.5f, 0.8f, 25f);
        if (!alive) yield break;
        inVehicle = false;
        BeginCombat(ground);
        // отбегаем от вертолёта
        if (agent != null && agent.enabled && agent.isOnNavMesh)
        {
            agent.speed = 4.5f * speedMul;
            agent.SetDestination(ground + outward.normalized * Random.Range(5f, 9f) + Random.insideUnitSphere * 2f);
            moveT = Time.time + 1.5f;
        }
    }

    // Спуск по канату с зависшего вертолёта
    public IEnumerator FastRope(Vector3 door, Vector3 ropeTop, Vector3 ground, System.Action onDone)
    {
        state = State.Scripted;
        transform.SetParent(null, true);
        anim.seated = false;
        anim.slung = true;
        Vector3 start = transform.position;
        float t = 0;
        while (t < 0.5f)
        {
            t += Time.deltaTime;
            float k = Mathf.SmoothStep(0, 1, t / 0.5f);
            transform.position = Vector3.Lerp(start, door, k);
            anim.velocity = Vector3.zero;
            yield return null;
        }
        anim.onRope = true;
        anim.ropePoint = ropeTop;
        Sfx.Play("rope", door, 0.6f, 1f, 30f);
        Vector3 p = new Vector3(ropeTop.x, door.y, ropeTop.z) - (ropeTop - door).normalized * 0f;
        float speed = 0;
        Vector3 ropeXZ = new Vector3(ropeTop.x, 0, ropeTop.z);
        while (p.y > ground.y + 0.05f)
        {
            speed = Mathf.Min(speed + 14f * Time.deltaTime, 7f);
            if (p.y - ground.y < 2.5f) speed = Mathf.Max(2f, speed - 25f * Time.deltaTime);
            p.y -= speed * Time.deltaTime;
            p.x = Mathf.Lerp(p.x, ropeXZ.x, 0.2f); p.z = Mathf.Lerp(p.z, ropeXZ.z, 0.2f);
            transform.position = new Vector3(p.x, Mathf.Max(p.y, ground.y), p.z) - transform.forward * 0.15f;
            anim.ropePoint = new Vector3(ropeTop.x, 0, ropeTop.z);
            anim.velocity = Vector3.zero;
            if (!alive) yield break;
            yield return null;
        }
        anim.onRope = false;
        anim.slung = false;
        onDone?.Invoke();
        Sfx.Play("step", ground, 0.5f, 0.8f, 25f);
        if (!alive) yield break;
        BeginCombat(ground);
        if (agent != null && agent.enabled && agent.isOnNavMesh)
        {
            Vector3 away = Random.insideUnitSphere; away.y = 0;
            agent.SetDestination(ground + away.normalized * Random.Range(4f, 8f));
            moveT = Time.time + 1.2f;
        }
    }

    public void KillInVehicle(Vector3 vehicleVel, Unit attacker)
    {
        if (!alive) return;
        transform.SetParent(null, true);
        inVehicle = false;
        anim.seated = false;
        TakeDamage(new DamageInfo { amount = 99999, type = DamageType.Explosion, dir = Vector3.up, point = AimPoint, force = 600f, attacker = attacker, weapon = "Крушение" });
        foreach (var p in ragdoll.parts) p.rb.velocity += vehicleVel + Random.insideUnitSphere * 4f;
    }

    // ---------------- ИИ ----------------
    void Update()
    {
        float dt = Time.deltaTime;
        if (dt <= 0) return;
        if (state == State.Dead || !alive) return;
        Vector3 p = transform.position;
        if (state == State.Combat) vel = agent != null && agent.enabled ? agent.velocity : Vector3.zero;
        lastPos = p;

        if (current != null) current.Tick(p);
        // моргание (важно для SCP-173)
        if (!zombie && (squad == null || !squad.blinkImmune) && Time.time > blinkT)
        {
            blinkEnd = Time.time + 0.25f;
            blinkT = Time.time + Random.Range(3.5f, 7f);
        }

        if (state != State.Combat)
        {
            if (state == State.Transport) { anim.velocity = Vector3.zero; anim.aimDir = transform.forward; }
            return;
        }
        if (agent == null || !agent.enabled || !agent.isOnNavMesh)
        {
            // упал с навмеша — пробуем вернуть
            EnsureAgent(p);
            return;
        }

        if (zombie) { ZombieUpdate(dt); return; }

        if (Time.time > thinkT)
        {
            thinkT = Time.time + Random.Range(0.35f, 0.7f);
            Think();
        }
        Aim(dt);
        Shoot();
        Move();

        // анимация
        anim.velocity = vel;
        anim.aimDir = aimDir;
        anim.aiming = target != null && targetVisible;
        anim.reload01 = current != null && current.reloading ? current.ReloadProgress : -1f;
        anim.throw01 = throwStart >= 0 ? (Time.time - throwStart) / 0.9f : -1f;
        if (throwStart >= 0 && Time.time - throwStart > 0.9f) throwStart = -1;
        anim.sprint = vel.magnitude > 4.8f && target == null;
        if (crouchT < Time.time)
        {
            crouchT = Time.time + Random.Range(2f, 5f);
            anim.crouch = target != null && targetVisible && vel.magnitude < 0.5f && Random.value < 0.45f && (current == null || current.def.kind != WeaponKind.Launcher);
        }
        if (vel.magnitude > 1.5f) anim.crouch = false;
        anim.speedMul = speedMul;

        // поворот корпуса
        Vector3 face = target != null && targetVisible ? aimDir : (vel.sqrMagnitude > 0.3f ? vel : transform.forward);
        face.y = 0;
        if (face.sqrMagnitude > 0.001f)
            transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(face), 400f * dt);
    }

    float EngageRange()
    {
        if (current == null) return 30f;
        switch (current.def.kind)
        {
            case WeaponKind.Shotgun: return 10f;
            case WeaponKind.SMG: return 22f;
            case WeaponKind.Pistol: return 16f;
            case WeaponKind.LMG: return 40f;
            case WeaponKind.Sniper: return 75f;
            case WeaponKind.Launcher: return 45f;
            default: return 32f;
        }
    }

    void Think()
    {
        // выбор цели
        Unit best = null;
        float bestScore = float.MaxValue;
        Vector3 e = EyePos;
        int checks = 0;
        var cands = Battle.SortedEnemies(this, 8);
        foreach (var u in cands)
        {
            float d = Vector3.Distance(e, u.AimPoint);
            if (d > 220f) continue;
            bool vis = Combat.Visible(e, u.AimPoint);
            checks++;
            if (!vis) continue;
            float score = d / Mathf.Max(0.3f, u.threat);
            if (u == target) score *= 0.6f;
            if (u.isPlayer) score *= 0.85f;
            if (u.isScp && u is Scp096 s096 && !s096.Enraged) score *= 3f; // спокойного 096 лучше не трогать
            if (score < bestScore) { bestScore = score; best = u; }
        }
        if (best != target) { aimSettle = 0; burstLeft = 0; }
        target = best;
        targetVisible = best != null;
        if (targetVisible) sightT = Time.time;

        // смена оружия: гранатомёт по вертолёту, крупному SCP или группе
        if (special != null && special.ammo + special.reserveMags > 0 && Time.time > switchT)
        {
            var heli = Battle.EnemyHeli(this, special.def.range);
            bool wantSpecial = heli != null || (target != null && target.isScp && target.maxHp > 1000) || (target != null && Vector3.Distance(target.transform.position, transform.position) > 15f && Random.value < 0.25f);
            if (wantSpecial && current != special && (special.ammo > 0 || special.reserveMags > 0)) Equip(special, flashlightOn);
            else if (!wantSpecial && current == special && Random.value < 0.4f) Equip(primary, flashlightOn);
            if (current == special && special.ammo == 0 && special.reserveMags <= 0) Equip(primary, flashlightOn);
        }
        // перезарядка в паузе
        if (current != null && !current.reloading && (current.ammo == 0 || (target == null && current.ammo < current.def.mag * 0.4f)))
        {
            if (current.reserveMags > 0) current.StartReload(transform.position, 1f);
            else if (current != primary) Equip(primary, flashlightOn);
        }
        // граната
        if (grenades > 0 && target != null && Time.time > grenadeT && throwStart < 0)
        {
            float d = Vector3.Distance(transform.position, target.transform.position);
            if (d > 10f && d < 32f && Random.value < 0.25f)
            {
                grenadeT = Time.time + Random.Range(10f, 20f);
                StartCoroutine(ThrowGrenade(target.transform.position));
            }
        }
    }

    IEnumerator ThrowGrenade(Vector3 at)
    {
        throwStart = Time.time;
        yield return new WaitForSeconds(0.55f);
        if (!alive) yield break;
        grenades--;
        Vector3 from = rig.b[HumanRig.HandR].position + Vector3.up * 0.1f;
        Vector3 v = BallisticVelocity(from, at + Random.insideUnitSphere * 2f, 40f);
        Grenade.Spawn(from, v, this, false, 170f);
        Sfx.Play("whoosh", from, 0.4f, 1f, 20f);
    }

    public static Vector3 BallisticVelocity(Vector3 from, Vector3 to, float angleDeg)
    {
        Vector3 d = to - from;
        float h = d.y;
        d.y = 0;
        float dist = d.magnitude;
        float a = angleDeg * Mathf.Deg2Rad;
        float g = -Physics.gravity.y;
        float denom = 2f * Mathf.Cos(a) * Mathf.Cos(a) * (dist * Mathf.Tan(a) - h);
        float v = denom > 0.01f ? Mathf.Sqrt(g * dist * dist / denom) : 14f;
        v = Mathf.Min(v, 25f);
        Vector3 dir = d.normalized * Mathf.Cos(a) + Vector3.up * Mathf.Sin(a);
        return dir * v;
    }

    void Aim(float dt)
    {
        Vector3 desired;
        if (target != null && targetVisible)
        {
            Vector3 tp = target.AimPoint + target.Velocity * 0.12f;
            var heli = current == special ? Battle.EnemyHeli(this, special.def.range) : null;
            if (heli != null) tp = heli.transform.position + heli.velocity * 0.6f;
            float dist = Vector3.Distance(EyePos, tp);
            aimSettle = Mathf.Min(1f, aimSettle + dt * 0.6f * accuracy);
            if (Random.value < dt * 3f) aimNoise = Random.insideUnitSphere;
            float err = (0.6f + dist * 0.025f) * (1.25f - aimSettle) / Mathf.Max(0.3f, accuracy);
            if (current != null && current.def.kind == WeaponKind.Launcher) err *= 0.7f;
            desired = (tp + aimNoise * err - EyePos).normalized;
            if (current != null && current.def.kind == WeaponKind.Launcher && current.def.id == "gl")
            {
                // навесной выстрел гранатомёта
                desired = (desired + Vector3.up * dist * 0.012f).normalized;
            }
        }
        else
        {
            Vector3 f = vel.sqrMagnitude > 0.5f ? vel.normalized : transform.forward;
            f.y = -0.05f;
            desired = f.normalized;
            // вертим головой по сторонам
            desired = Quaternion.Euler(0, Mathf.Sin(Time.time * 0.6f + index) * 35f, 0) * desired;
        }
        aimDir = Vector3.RotateTowards(aimDir, desired, 260f * Mathf.Deg2Rad * dt, 1f).normalized;
    }

    void Shoot()
    {
        if (current == null || target == null || !targetVisible || current.reloading || throwStart >= 0 || Time.time < switchT) return;
        if (!target.alive || !target.Targetable) return;
        Vector3 want = (target.AimPoint - EyePos).normalized;
        if (Vector3.Angle(aimDir, want) > 10f) return;
        if (Time.time < fireT) return;
        if (current.ammo <= 0) { current.StartReload(transform.position); return; }

        // не стреляем через своих
        Vector3 muzzle = current.model != null ? current.model.muzzle.position : EyePos;
        float dist = Vector3.Distance(muzzle, target.AimPoint);
        if (Combat.Ray(muzzle, aimDir, dist, this, out var hit, Layers.ShotMask))
        {
            var o = Combat.OwnerOf(hit.collider);
            if (o != null && o.alive && !IsEnemy(o) && o != target) { strafeT = 0; fireT = Time.time + 0.3f; return; }
        }
        if (current.def.kind == WeaponKind.Launcher)
        {
            // гранатомётом в упор не стреляем
            if (dist < 9f) { Equip(primary, flashlightOn); return; }
        }

        float spread = (vel.magnitude > 1f ? 1.7f : 1f) * (anim.crouch ? 0.75f : 1f) / Mathf.Max(0.4f, accuracy) * 1.25f;
        if (current.Fire(this, muzzle, aimDir, spread, muzzle))
        {
            anim.Kick(current.def.recoil * 0.8f, current.def.recoil);
            if (current.def.auto)
            {
                if (burstLeft <= 0) burstLeft = Random.Range(3, current.def.kind == WeaponKind.LMG ? 14 : 8);
                burstLeft--;
                if (burstLeft <= 0) fireT = Time.time + Random.Range(0.25f, 0.7f);
            }
            else fireT = Time.time + current.def.Interval * Random.Range(1.1f, 1.9f) + (current.def.kind == WeaponKind.Sniper ? Random.Range(0.4f, 1.2f) : 0);
        }
    }

    void Move()
    {
        if (Time.time < moveT) return;
        moveT = Time.time + Random.Range(0.6f, 1.3f);
        Vector3 me = transform.position;
        float baseSpeed = 4.4f * speedMul;
        Vector3 goal = me;
        bool lowHp = hp < maxHp * 0.3f && courage < 1.2f;

        if (target != null)
        {
            float R = EngageRange();
            if (target.isScp) R = Mathf.Max(R * 1.3f, target.maxHp > 3000 ? 22f : 14f);
            Vector3 tp = target.transform.position;
            float d = Vector3.Distance(me, tp);
            Vector3 to = (tp - me); to.y = 0; to.Normalize();
            Vector3 perp = Vector3.Cross(Vector3.up, to);
            if (lowHp && Random.value < 0.5f)
            {
                goal = me - to * 8f + perp * Random.Range(-4f, 4f);
                agent.speed = baseSpeed * 1.2f;
            }
            else if (!targetVisible || d > R * 1.15f)
            {
                goal = tp - to * R * 0.8f + perp * ((index % 5) - 2) * 2.5f;
                agent.speed = baseSpeed * (d > R * 2f ? 1.35f : 1f);
            }
            else if (d < R * 0.45f || (target.isScp && d < 7f))
            {
                goal = me - to * 5f + perp * strafeDir * 2f;
                agent.speed = baseSpeed * 1.1f;
            }
            else
            {
                // держим дистанцию и смещаемся в стороны
                if (Time.time > strafeT)
                {
                    strafeT = Time.time + Random.Range(1.5f, 4f);
                    strafeDir = Random.value < 0.5f ? -1 : 1;
                    if (Random.value < 0.35f) strafeDir = 0;
                }
                goal = me + perp * strafeDir * 3f;
                agent.speed = baseSpeed * 0.55f;
            }
            if (current != null && current.reloading) agent.speed *= 0.7f;
        }
        else
        {
            var leader = squadRt != null ? squadRt.Leader : null;
            var enemy = Battle.NearestEnemyUnit(this);
            if (leader != null && leader != this && Vector3.Distance(leader.transform.position, me) > 14f)
            {
                Vector3 off = new Vector3(((index % 3) - 1) * 3f, 0, -(index / 3) * 3f);
                goal = leader.transform.position + leader.transform.rotation * off;
                agent.speed = baseSpeed * 1.3f;
            }
            else if (enemy != null)
            {
                Vector3 tp = enemy.transform.position;
                Vector3 to = tp - me; to.y = 0;
                float d = to.magnitude;
                to /= Mathf.Max(0.01f, d);
                Vector3 perp = Vector3.Cross(Vector3.up, to);
                float R = EngageRange() * 0.9f;
                goal = d > R ? me + to * Mathf.Min(14f, d - R) + perp * ((index % 5) - 2) * 2f : me + perp * Random.Range(-3f, 3f);
                agent.speed = baseSpeed * (d > 60f ? 1.35f : 1f);
            }
            else
            {
                goal = me + Random.insideUnitSphere * 4f;
                agent.speed = baseSpeed * 0.5f;
            }
        }
        goal.y = me.y;
        if (NavMesh.SamplePosition(goal, out var nh, 4f, NavMesh.AllAreas)) agent.SetDestination(nh.position);
    }

    // ---------------- зомби SCP-049-2 ----------------
    void ZombieUpdate(float dt)
    {
        if (Time.time > thinkT)
        {
            thinkT = Time.time + Random.Range(0.4f, 0.8f);
            target = Battle.NearestEnemyUnit(this);
            if (target != null && agent.isOnNavMesh) agent.SetDestination(target.transform.position);
            if (Random.value < 0.06f) Sfx.Play("groan", transform.position, 0.5f, Random.Range(0.8f, 1.1f), 30f);
        }
        agent.speed = 3.1f * speedMul;
        float d = target != null ? Vector3.Distance(target.transform.position, transform.position) : 999f;
        if (attackStart >= 0)
        {
            float a = (Time.time - attackStart) / 0.8f;
            anim.attack01 = a;
            if (!attackHit && a > 0.5f)
            {
                attackHit = true;
                if (target != null && target.alive && d < 1.9f)
                {
                    Vector3 dir = (target.AimPoint - EyePos).normalized;
                    target.TakeDamage(new DamageInfo { amount = 32f, type = DamageType.Melee, attacker = this, dir = dir, point = target.AimPoint, force = 250f, weapon = "Руки" });
                    Fx.Blood(target.AimPoint, dir, 0.8f);
                    Sfx.Play("flesh", target.AimPoint, 0.6f, Random.Range(0.8f, 1.1f), 25f);
                }
            }
            if (a >= 1f) { attackStart = -1; anim.attack01 = -1; }
        }
        else if (target != null && d < 1.6f)
        {
            attackStart = Time.time; attackHit = false;
        }
        anim.velocity = vel;
        Vector3 look = target != null ? (target.AimPoint - EyePos).normalized : transform.forward;
        aimDir = Vector3.RotateTowards(aimDir, look, 3f * dt, 1f);
        anim.aimDir = aimDir;
        Vector3 face = target != null && d < 4f ? target.transform.position - transform.position : vel;
        face.y = 0;
        if (face.sqrMagnitude > 0.01f) transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(face), 200f * dt);
    }

    // Превращение трупа в SCP-049-2: тело "подбирается" из позы лёжа и встаёт
    public void Reanimate()
    {
        if (alive || ragdoll == null) return;
        StartCoroutine(ReanimateRoutine());
    }

    IEnumerator ReanimateRoutine()
    {
        var hips = rig.b[HumanRig.Hips];
        Vector3 hipPos = hips.position;
        Quaternion hr = hips.rotation;
        // переносим корень под таз
        Vector3 ground = hipPos;
        if (Physics.Raycast(hipPos + Vector3.up, Vector3.down, out var gh, 5f, 1 << Layers.World, QueryTriggerInteraction.Ignore)) ground = gh.point;
        Vector3 fwd = hr * Vector3.up; // по направлению тела (от таза к голове)
        fwd.y = 0;
        if (fwd.sqrMagnitude < 0.01f) fwd = transform.forward;
        // запоминаем мировые позы всех костей
        var pos = new Vector3[HumanRig.Count];
        var rot = new Quaternion[HumanRig.Count];
        for (int i = 0; i < HumanRig.Count; i++) { pos[i] = rig.b[i].position; rot[i] = rig.b[i].rotation; }
        ragdoll.Deactivate();
        transform.position = ground;
        transform.rotation = Quaternion.LookRotation(fwd.normalized);
        for (int i = 0; i < HumanRig.Count; i++) { rig.b[i].position = pos[i]; rig.b[i].rotation = rot[i]; }
        // восстанавливаем длины (только таз может смещаться)
        for (int i = 1; i < HumanRig.Count; i++) rig.b[i].localPosition = RestLocal(i);

        zombie = true;
        alive = true;
        team = Team.SCP;
        isScp = true;
        displayName = "SCP-049-2";
        maxHp = hp_zombie; hp = maxHp;
        armor = 0.1f;
        state = State.Combat;
        anim.enabled = true;
        anim.style = AnimStyle.Zombie;
        anim.gun = null;
        anim.aiming = false; anim.crouch = false; anim.reload01 = -1; anim.throw01 = -1;
        anim.BlendFromCurrent(1.6f);
        MeshKit.Tint(gameObject, new Color(0.75f, 0.8f, 0.72f), 0.25f, new Color(0.35f, 0.4f, 0.32f));
        if (agent != null) { agent.enabled = false; }
        Sfx.Play("groan", transform.position, 0.8f, 0.8f, 40f);
        yield return new WaitForSeconds(1.5f);
        if (!alive) yield break;
        EnsureAgent(transform.position);
        thinkT = 0;
    }

    const float hp_zombie = 170f;

    Vector3 RestLocal(int i)
    {
        var s = rig.shape; float tor = s.torso;
        switch (i)
        {
            case HumanRig.Spine: return new Vector3(0, 0.1f * tor, 0);
            case HumanRig.Chest: return new Vector3(0, 0.17f * tor, 0);
            case HumanRig.Neck: return new Vector3(0, 0.25f * tor, 0);
            case HumanRig.Head: return new Vector3(0, 0.085f * s.neck, 0);
            case HumanRig.UArmL: return new Vector3(-s.shoulder, 0.205f * tor, 0);
            case HumanRig.UArmR: return new Vector3(s.shoulder, 0.205f * tor, 0);
            case HumanRig.LArmL: case HumanRig.LArmR: return new Vector3(0, -s.armU, 0);
            case HumanRig.HandL: case HumanRig.HandR: return new Vector3(0, -s.armL, 0);
            case HumanRig.ULegL: return new Vector3(-0.1f, -0.05f, 0);
            case HumanRig.ULegR: return new Vector3(0.1f, -0.05f, 0);
            case HumanRig.LLegL: case HumanRig.LLegR: return new Vector3(0, -s.legU, 0);
            case HumanRig.FootL: case HumanRig.FootR: return new Vector3(0, -s.legL, 0);
        }
        return rig.b[i].localPosition;
    }

    // Чистый зомби (для отряда SCP-049-2)
    public static Soldier CreateZombie(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-049-2");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Soldier>();
        bool sci = Random.value < 0.45f;
        var look = new Look
        {
            uniform = sci ? new Color(0.92f, 0.92f, 0.9f) : new Color(0.95f, 0.45f, 0.1f),
            uniform2 = sci ? new Color(0.2f, 0.22f, 0.28f) : new Color(0.92f, 0.43f, 0.09f),
            armor = sci ? new Color(0.92f, 0.92f, 0.9f) : new Color(0.95f, 0.45f, 0.1f),
            skin = new Color(0.62f, 0.66f, 0.55f), gear = new Color(0.2f, 0.18f, 0.16f), accent = new Color(0.3f, 0.05f, 0.05f),
            head = HeadGear.Bare, vest = false, backpack = false, kneePads = false
        };
        s.BuildBody(look, BodyShape.Soldier(1f));
        s.team = Team.SCP;
        s.isScp = true;
        s.zombie = true;
        s.displayName = "SCP-049-2";
        s.maxHp = s.hp = DB.Scp(ScpKind.S0492).hp;
        s.armor = 0.1f;
        s.threat = 1.2f;
        s.speedMul = Random.Range(0.85f, 1.15f);
        s.anim.style = AnimStyle.Zombie;
        s.state = State.Scripted;
        // кровавые пятна на одежде
        for (int i = 0; i < 4; i++)
        {
            var bone = s.rig.b[Random.Range(0, 3)];
            Fx.BloodSplat(bone.position + Random.insideUnitSphere * 0.1f + go.transform.forward * 0.14f, go.transform.forward, 0.2f, bone);
        }
        return s;
    }

    // ---------------- урон и смерть ----------------
    protected override void OnHurt(DamageInfo d, float dmg)
    {
        anim.Flinch(d.dir, Mathf.Clamp(dmg / 25f, 0.3f, 1.5f));
        if (!zombie && target == null && d.attacker != null && IsEnemy(d.attacker)) { target = d.attacker; thinkT = Time.time + 0.2f; }
        if (zombie && Random.value < 0.3f) Sfx.Play("groan", transform.position, 0.6f, 1.2f, 30f);
    }

    protected override void Die(DamageInfo d)
    {
        state = State.Dead;
        StopAllCoroutines();
        if (transform.parent != null) transform.SetParent(null, true);
        inVehicle = false;
        if (agent != null) agent.enabled = false;
        anim.enabled = false;
        // шея ломается (SCP-173) — голова резко поворачивается, но в пределах сустава
        if (d.type == DamageType.NeckSnap)
        {
            rig.b[HumanRig.Head].localRotation = Quaternion.Euler(-25f, 50f, 20f);
            Sfx.Play("snap", rig.b[HumanRig.Head].position, 0.9f, 1f, 30f);
        }
        DropGun(d);
        ragdoll.Activate(d, vel * 0.6f);
        if (d.hitbox != null && d.hitbox.head && d.type == DamageType.Bullet)
        {
            Fx.Blood(d.point, d.dir, 2.2f, d.hitbox.transform);
            Sfx.Play("headshot", d.point, 0.7f, Random.Range(0.9f, 1.1f), 30f);
        }
        if (d.type != DamageType.Corrosion && d.type != DamageType.Fire) StartCoroutine(BleedOut());
    }

    IEnumerator BleedOut()
    {
        yield return new WaitForSeconds(Random.Range(0.8f, 1.6f));
        if (this == null || ragdoll == null || ragdoll.sinking) yield break;
        Fx.BloodPool(rig.b[HumanRig.Chest].position, Random.Range(0.9f, 1.6f));
    }

    void DropGun(DamageInfo d)
    {
        if (current == null || current.model == null) return;
        var g = current.model.gameObject;
        anim.gun = null;
        g.transform.SetParent(null, true);
        MeshKit.SetLayer(g, Layers.Corpse);
        var box = g.AddComponent<BoxCollider>();
        box.center = new Vector3(0, 0.03f, current.def.length * 0.3f);
        box.size = new Vector3(0.06f, 0.14f, current.def.length + 0.2f);
        var rb = g.AddComponent<Rigidbody>();
        rb.mass = 3.5f;
        rb.velocity = vel + d.dir * 1.5f + Vector3.up * 1f;
        rb.angularVelocity = Random.insideUnitSphere * 4f;
        rb.interpolation = RigidbodyInterpolation.Interpolate;
        if (current.model.flashlight != null) current.model.flashlight.enabled = false;
        foreach (var c in GetComponentsInChildren<Collider>()) Physics.IgnoreCollision(box, c);
        Destroy(g, 60f);
        current.model = null;
    }

    // Для тела игрока: сразу умереть с заданной скоростью
    public void ForceDie(DamageInfo d, Vector3 v)
    {
        alive = false;
        vel = v;
        Die(d);
    }

    public override void CorpseHit(Hitbox hb, Vector3 point, Vector3 impulse)
    {
        if (ragdoll != null) ragdoll.Hit(hb.rb, point, impulse);
    }

    public void CorrodeAndSink()
    {
        MeshKit.Tint(gameObject, new Color(0.35f, 0.3f, 0.25f), 0.5f, new Color(0.08f, 0.06f, 0.04f));
        StartCoroutine(SinkLater());
    }

    IEnumerator SinkLater()
    {
        yield return new WaitForSeconds(1.2f);
        if (ragdoll != null) ragdoll.Sink();
        Fx.GooPuddle(rig.b[HumanRig.Hips].position, 2f);
    }

    public void Char()
    {
        MeshKit.Tint(gameObject, new Color(0.2f, 0.18f, 0.16f), 0.4f, new Color(0.05f, 0.04f, 0.03f));
    }
}
