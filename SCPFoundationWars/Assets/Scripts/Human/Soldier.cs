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
    // приказ командира
    public Vector3 lz, orderPos;
    public string orderText = "Высадка";
    public bool orderSet, hold, overwatch;
    public int flank;
    public float arriveAt;      // время вылета вертолёта (Time.time)
    public bool reinforce, announced;
    public bool garrison;       // охрана объекта — держит свой сектор
    // патруль у точки приказа: командир ведёт группу по маршруту, часовые стоят на постах
    public Vector3 patrolPos; public float patrolUntil, pauseUntil; public bool patrolSet;
    public Vector3 lastOrderPos;
    // приказ игрока своему отряду (перекрывает командира на время)
    public float playerCmdUntil = -1f; public bool playerFollow; public Vector3 playerCmdPos;
    // группа предупреждена выжившим: работает тихо — пригнувшись, медленно, держит дистанцию до опасного места
    public bool cautious; public Vector3 dangerPos; public string dangerName;
    public bool Sentry(Soldier s) => (hold || garrison) && s.index % 4 == 3;
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
    bool wasReloading, reloadEmpty;
    float meleeStart = -1, meleeCd;
    bool meleeDone;
    float signalCd;
    bool holding;
    bool patrolLook; Vector3 sentryDir;
    // подавление: огонь по последнему месту, где видели противника
    Unit lastTarget; Vector3 lastSeenPos; float suppressUntil;
    // укрытие на время перезарядки и при ранении
    Vector3 coverPos; float coverT = -1f;
    // линия огня перекрыта — обходим препятствие
    float blockedT = -10f; Vector3 firePos; float firePosT = -1f;
    // медик отряда
    public int medkits = 2;
    Unit healTarget; float healStart = -1f, medT;
    bool IsMedic => squadRt != null && index == 1;
    // страх: видел, как SCP выкашивает группу; бегство к другой группе с докладом
    // сетевая игра: представитель живого игрока (у хоста — тело клиента, у клиента — тело хоста/других)
    public bool remoteHuman; public int netPeer = -1; public string nick;
    public float fear; public bool fleeing; SquadRt fleeTo; Vector3 dangerPos; string dangerName; float fleeStart;
    float chatT;

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
        if (def.special != null) { s.special = new Gun(DB.W(def.special)); s.special.reserveMags = DB.W(def.special).rocket ? 4 : 3; }
        s.Equip(s.primary, flashlight);
        return s;
    }

    public void BuildBody(Look look, BodyShape shape)
    {
        if (look != null) ModelLib.Use(ModelLib.ModelFor(look));
        bool mdl = look != null && ModelLib.HasSoldier;
        if (mdl) shape = ModelLib.SoldierShape(look.bulk);
        rig = HumanRig.Create(transform, shape);
        if (mdl) rig.DressModel(look, squad != null ? squad.id : "z");
        else
        {
            if (look != null) rig.DressSoldier(look);
            rig.Finish();
        }
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

    // Посадка в вертолёт на базе: подойти к двери, запрыгнуть в салон, пройти к месту и сесть
    public IEnumerator Board(Helicopter h, Transform seat, float delay)
    {
        h.boarding++;
        yield return new WaitForSeconds(delay);
        if (!alive || h == null) { if (h != null) h.boarding--; yield break; }
        state = State.Scripted;
        transform.SetParent(null, true);
        anim.seated = false;
        inVehicle = true;
        h.BoardPath(seat, out var outside, out var door);
        // обход хвоста: если стоим за вертолётом, сначала выходим на его борт
        Vector3 local = h.transform.InverseTransformPoint(transform.position);
        Vector3 doorLocal = h.transform.InverseTransformPoint(outside);
        var path = new List<Vector3>();
        if (Mathf.Sign(local.x) != Mathf.Sign(doorLocal.x) || Mathf.Abs(local.x) < 2.5f)
        {
            Vector3 w = h.transform.TransformPoint(new Vector3(Mathf.Sign(doorLocal.x) * 4.5f, 0, local.z < -2f ? Mathf.Max(local.z, -13f) : doorLocal.z - 4f));
            w.y = Battle.GroundHeight(w);
            path.Add(w);
        }
        path.Add(outside);
        float speed = Random.Range(2.3f, 2.9f);
        foreach (var target in path)
        {
            while (alive)
            {
                Vector3 to = target - transform.position; to.y = 0;
                if (to.magnitude < 0.25f) break;
                Vector3 step = to.normalized * Mathf.Min(to.magnitude, speed * Time.deltaTime);
                Vector3 p = transform.position + step;
                p.y = Mathf.Lerp(transform.position.y, Battle.GroundHeight(p), 0.5f);
                vel = (p - transform.position) / Mathf.Max(0.001f, Time.deltaTime);
                transform.position = p;
                transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(to), 360f * Time.deltaTime);
                anim.velocity = vel; anim.aimDir = transform.forward;
                yield return null;
            }
        }
        // шаг на порог (с подтягиванием) и проход к месту — уже на борту
        Vector3 a = transform.position;
        float t = 0;
        Quaternion faceIn = Quaternion.LookRotation(new Vector3(door.x - a.x, 0, door.z - a.z).normalized);
        while (t < 0.6f && alive)
        {
            t += Time.deltaTime;
            float k = Mathf.SmoothStep(0, 1, t / 0.6f);
            transform.position = Vector3.Lerp(a, door, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 0.25f;
            transform.rotation = Quaternion.Slerp(transform.rotation, faceIn, k);
            anim.airborne = k > 0.2f && k < 0.8f;
            anim.velocity = Vector3.zero;
            yield return null;
        }
        anim.airborne = false;
        Sfx.Play(Sfx.Step, door, 0.5f, 0.7f, 20f);
        a = transform.position;
        t = 0;
        while (t < 0.5f && alive)
        {
            t += Time.deltaTime;
            float k = Mathf.SmoothStep(0, 1, t / 0.5f);
            transform.position = Vector3.Lerp(a, seat.position, k);
            transform.rotation = Quaternion.Slerp(transform.rotation, seat.rotation, k);
            anim.velocity = Vector3.zero;
            yield return null;
        }
        if (alive) SitIn(seat);
        h.boarding--;
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
        Sfx.Play(Sfx.Step, ground, 0.5f, 0.8f, 25f);
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
        Sfx.Play(Sfx.Step, ground, 0.5f, 0.8f, 25f);
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
        foreach (var p in ragdoll.parts) p.rb.SetVel(p.rb.Vel() + vehicleVel + Random.insideUnitSphere * 4f);
    }

    // ---------------- ИИ ----------------
    void Update()
    {
        float dt = Time.deltaTime;
        if (dt <= 0) return;
        if (state == State.Dead || !alive) return;
        if (netPuppet) { PuppetUpdate(dt); return; }
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
        // лифт/спуск в подземный комплекс (связь навмеша): мгновенный переход
        if (agent.isOnOffMeshLink) agent.CompleteOffMeshLink();
        if (squadRt != null && squadRt.cautious && target == null && !fleeing)
        {
            // предупреждённая группа: тихо, пригнувшись
            if (agent.speed > 2.2f) agent.speed = 2.2f;
            anim.crouch = true;
        }
        if (target == null && Time.time > chatT) IdleChatter();
        if (Time.time > medT) { medT = Time.time + 1f; MedicThink(); }
        MedicUpdate();

        // анимация
        anim.velocity = vel;
        anim.aimDir = aimDir;
        anim.aiming = target != null && targetVisible;
        anim.reload01 = current != null && current.reloading ? current.ReloadProgress : -1f;
        if (current != null && current.reloading && !wasReloading) reloadEmpty = current.ammo == 0;
        wasReloading = current != null && current.reloading;
        anim.reloadEmpty = reloadEmpty;
        anim.shellPhase = current != null ? current.ShellPhase : 0f;
        anim.wounded = Mathf.Clamp01((0.5f - hp / maxHp) * 2f);
        anim.suppressed = Mathf.Clamp01(1f - (Time.time - lastHitTime) / 1.2f) * (courage < 1.5f ? 0.8f : 0.3f);
        // удар прикладом, если враг вплотную
        if (meleeStart >= 0)
        {
            float m = (Time.time - meleeStart) / 0.65f;
            anim.melee01 = m;
            if (!meleeDone && m > 0.42f)
            {
                meleeDone = true;
                if (target != null && target.alive && Vector3.Distance(target.transform.position, transform.position) < 2.2f)
                {
                    Vector3 dir = (target.AimPoint - EyePos).normalized;
                    target.TakeDamage(new DamageInfo { amount = 45f, type = DamageType.Melee, attacker = this, dir = dir, force = 450f, point = target.AimPoint, weapon = "Приклад" });
                    Sfx.Play("flesh", target.AimPoint, 0.7f, 0.8f, 25f);
                    Fx.Blood(target.AimPoint, dir, 0.6f);
                }
            }
            if (m >= 1f) { meleeStart = -1; anim.melee01 = -1; }
        }
        else if (target != null && target.alive && throwStart < 0 && Time.time > meleeCd && Vector3.Distance(target.transform.position, transform.position) < 1.7f)
        {
            meleeStart = Time.time; meleeDone = false; meleeCd = Time.time + 1.4f;
            Sfx.Play("whoosh", transform.position, 0.4f, 1.3f, 20f);
        }
        anim.throw01 = throwStart >= 0 ? (Time.time - throwStart) / 0.9f : -1f;
        if (throwStart >= 0 && Time.time - throwStart > 0.9f) throwStart = -1;
        anim.sprint = vel.magnitude > 4.8f && target == null;
        if (crouchT < Time.time)
        {
            crouchT = Time.time + Random.Range(2f, 5f);
            anim.crouch = target != null && targetVisible && vel.magnitude < 0.5f && Random.value < 0.45f && (current == null || current.def.kind != WeaponKind.Launcher);
        }
        if (holding && target == null && vel.magnitude < 0.5f) anim.crouch = index % 3 != 0;
        if (vel.magnitude > 1.5f && !(squadRt != null && squadRt.cautious && target == null)) anim.crouch = false;
        anim.speedMul = speedMul;

        // поворот корпуса
        Vector3 face = target != null && targetVisible ? aimDir : (vel.sqrMagnitude > 0.3f ? vel : transform.forward);
        face.y = 0;
        if (face.sqrMagnitude > 0.001f)
            transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(face), 400f * dt);
    }

    public void NetWarp(Vector3 p)
    {
        if (agent != null && agent.enabled) agent.Warp(p); else transform.position = p;
    }

    // Марионетка: положение, взгляд, поза и оружие — из сети
    void PuppetUpdate(float dt)
    {
        if (agent != null && agent.enabled) agent.enabled = false;
        if (current != null) current.Tick(transform.position);
        bool seatedNet = (netFlags & 2) != 0;
        if (transform.parent != null && netHas && !seatedNet) transform.SetParent(null, true);
        if (transform.parent == null) NetMove(dt);
        vel = transform.parent == null ? netVelocity : Vector3.zero;
        if (state == State.Transport && netHas && !seatedNet) state = State.Combat;
        anim.velocity = vel;
        anim.aimDir = netHas ? NetLook : transform.forward;
        anim.crouch = (netFlags & 1) != 0;
        anim.seated = seatedNet && transform.parent != null;
        anim.sprint = (netFlags & 32) != 0;
        anim.speedMul = speedMul;
        Gun want = netWeapon == 1 && secondary != null ? secondary : netWeapon == 2 && special != null ? special : primary;
        if (want != null && want != current) Equip(want, flashlightOn);
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
        if (fleeing && best != null && best.isScp) best = null;   // бегущий не стреляет по объекту — уносит ноги
        if (best != target) { aimSettle = 0; burstLeft = 0; }
        if (best != null && target == null && Time.time - sightT > 8f)
        {
            if (best is ScpUnit su && ScpCallout(su)) { }
            else Callout("Контакт! " + Bearing(best.transform.position) + ", " + Mathf.RoundToInt(Vector3.Distance(transform.position, best.transform.position)) + " метров!", "contact");
        }
        if (best != null) { lastTarget = best; lastSeenPos = best.AimPoint; }
        else if (target != null && lastTarget != null && lastTarget.alive && current != null && current.def.auto && Random.value < (current.def.kind == WeaponKind.LMG ? 0.9f : 0.45f))
        {
            // противник скрылся — прижимаем огнём, пока не высунется
            suppressUntil = Time.time + Random.Range(1.5f, 3.5f);
            if (Random.value < 0.3f) Callout("Прижимаю огнём!", "suppress");
        }
        if (best != null && target == null && squadRt != null && squadRt.Leader == this && Time.time > signalCd)
        {
            signalCd = Time.time + 15f;
            anim.DoSignal(Signal.Point);
        }
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
            if (current.reserveMags > 0)
            {
                current.StartReload(transform.position, 1f);
                if (target != null || Time.time - sightT < 5f) { Callout("Перезаряжаюсь, прикройте!", "reload"); coverT = -1f; }
            }
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
                Callout("Граната пошла!", "grenade", true);
            }
        }
    }

    // медик: ищет раненого в своём отряде (включая игрока), пока нет контакта
    void MedicThink()
    {
        if (!IsMedic || medkits <= 0 || target != null || Time.time - sightT < 6f) { if (healStart < 0) healTarget = null; return; }
        if (healTarget != null && (!healTarget.alive || healTarget.hp > healTarget.maxHp * 0.8f)) { healTarget = null; healStart = -1f; }
        if (healTarget != null) return;
        float worst = 0.55f;
        foreach (var m in squadRt.members)
            if (m != null && m != this && m.alive && !m.zombie && m.state == State.Combat && m.hp / m.maxHp < worst && Vector3.Distance(m.transform.position, transform.position) < 40f) { worst = m.hp / m.maxHp; healTarget = m; }
        var pc = PlayerController.I;
        if (pc != null && !pc.dead && pc.squad == squad && pc.unit.hp / pc.unit.maxHp < worst && !pc.riding && Vector3.Distance(pc.transform.position, transform.position) < 40f) healTarget = pc.unit;
        if (healTarget != null) Callout(healTarget.isPlayer ? "Ты ранен — стой, перевяжу!" : "Медик здесь, держись!", "medic");
    }

    void MedicUpdate()
    {
        if (healTarget == null) return;
        float d = Vector3.Distance(healTarget.transform.position, transform.position);
        if (d < 1.8f)
        {
            if (healStart < 0) { healStart = Time.time; Sfx.Play("magout", transform.position, 0.4f, 0.7f, 15f); }
            anim.crouch = true;
            anim.aimDir = (healTarget.transform.position - transform.position).normalized + Vector3.down * 0.8f;
            if (Time.time - healStart > 3.2f)
            {
                healTarget.hp = Mathf.Min(healTarget.maxHp, healTarget.hp + healTarget.maxHp * 0.45f);
                medkits--;
                Sfx.Play("magin", transform.position, 0.4f, 0.7f, 15f);
                if (healTarget.isPlayer) Battle.Message(CallSign + ": Готово, ты в строю.", new Color(0.6f, 0.9f, 0.6f), 3f);
                healTarget = null; healStart = -1f;
            }
        }
        else healStart = -1f;
    }

    public string CallSign => squad != null ? squad.name.Split(' ')[0].Split('-')[0] + "-" + (index + 1) : displayName;

    // Переговоры в бою: реплика над головой у любого бойца рядом с игроком (+голос, если есть запись);
    // доклады своего отряда — ещё и строкой в ленте. Не чаще раза в несколько секунд на бойца и на отряд.
    static readonly Dictionary<SquadDef, float> calloutT = new Dictionary<SquadDef, float>();
    float myCalloutT;
    // Опознание объекта по протоколам Фонда (голоса МОГ — SCP:CB)
    public static readonly HashSet<ScpKind> named = new HashSet<ScpKind>();
    bool ScpCallout(ScpUnit su)
    {
        string text = null, voice = null;
        bool mtf = team == Team.Foundation;
        switch (su.kind)
        {
            case ScpKind.S173: text = mtf ? "Вижу SCP-173! Глаз не сводить — моргаем по очереди, по команде!" : "Статуя! Не отводи от неё глаз!"; voice = mtf ? "mtf173" : null; break;
            case ScpKind.S096: text = mtf ? "SCP-096! Не смотреть на лицо! Глаза в пол!" : "Это Скромник — не смотри на него!"; voice = mtf ? "mtf096" : null; break;
            case ScpKind.S106: text = mtf ? "SCP-106 вне камеры! Держать дистанцию, не давать коснуться!" : "Старик! Не подпускай его!"; voice = mtf ? "mtf106" : null; break;
            case ScpKind.S049: text = mtf ? "SCP-049! Не давать ему касаться — касание смертельно!" : "Чумной доктор! Не подпускай!"; voice = mtf ? "mtf049" : null; break;
            case ScpKind.S939: text = "939-е! Не верьте голосам — это не наши!"; break;
            case ScpKind.S682: text = mtf ? "SCP-682! Его не убить — держим огнём и ждём средства сдерживания!" : "Ящер! Огонь по нему, не стоять на пути!"; break;
            default: return false;
        }
        Callout(text, voice ?? "contact", !named.Contains(su.kind));
        named.Add(su.kind);
        return true;
    }

    public void Callout(string text, string voice = null, bool force = false)
    {
        if (!alive || zombie || squad == null) return;
        var cam = Game.Cam;
        if (cam == null || Vector3.Distance(cam.transform.position, transform.position) > 70f) return;
        if (!force && Time.time < myCalloutT) return;
        calloutT.TryGetValue(squad, out float t);
        if (!force && Time.time < t) return;
        calloutT[squad] = Time.time + Random.Range(2.5f, 4.5f);
        myCalloutT = Time.time + Random.Range(6f, 10f);
        Color c = team == Team.Foundation ? new Color(0.65f, 0.82f, 1f) : team == Team.Chaos ? new Color(1f, 0.55f, 0.4f) : new Color(0.9f, 0.9f, 0.9f);
        string vk = voice == null ? null : voice.StartsWith("mtf") ? voice : "vo_" + voice + (team == Team.Chaos ? "_c" : "");
        Speech.Say(transform, CallSign, text, -1f, c, vk);
        var pc = PlayerController.I;
        if (pc != null && !pc.dead && pc.squad == squad && Vector3.Distance(pc.transform.position, transform.position) < 60f)
            Battle.Message(CallSign + ": " + text, new Color(0.75f, 0.85f, 0.95f), 3f);
    }

    // Гибель от SCP видят товарищи рядом: растёт страх; когда группа наполовину выбита — самый напуганный бежит
    void Witnesses(ScpUnit scp)
    {
        if (squadRt == null) return;
        int total = squadRt.members.Count, alive = squadRt.Alive;
        foreach (var m in squadRt.members)
        {
            if (m == null || m == this || !m.alive || m.zombie || m.fleeing || m.state != State.Combat) continue;
            if (Vector3.Distance(m.transform.position, transform.position) > 50f) continue;
            if (!Combat.Visible(m.EyePos, AimPoint)) continue;
            m.fear += 0.3f / Mathf.Max(0.5f, m.courage);
            m.dangerPos = scp.transform.position; m.dangerName = scp.displayName;
            if (m.fear > 0.55f && alive * 2 <= total && m.courage < 2.5f) m.StartFlee();
        }
    }

    public void StartFlee()
    {
        // к ближайшей живой группе своей стороны, подальше от опасности
        SquadRt best = null; float bd = float.MaxValue;
        if (Battle.I != null)
            foreach (var sq in Battle.I.squads)
            {
                if (sq == squadRt || sq.team != team || sq.Alive < 2) continue;
                var l = sq.Leader; if (l == null) continue;
                if (Vector3.Distance(l.transform.position, dangerPos) < 30f) continue;
                float d = Vector3.Distance(l.transform.position, transform.position);
                if (d < bd) { bd = d; best = sq; }
            }
        if (best == null) return;
        fleeing = true; fleeTo = best; fleeStart = Time.time; target = null;
        Callout(Random.value < 0.5f ? "Отходим! Оно всех положило!" : "Не могу, не могу — уходим отсюда!", "retreat", true);
    }

    bool FleeMove(Vector3 me, float baseSpeed)
    {
        var l = fleeTo != null ? fleeTo.Leader : null;
        if (l == null || Time.time - fleeStart > 120f) { fleeing = false; return false; }
        float d = Vector3.Distance(l.transform.position, me);
        if (d < 7f) { Report(l); return false; }
        Vector3 goal = l.transform.position; goal.y = me.y;
        agent.speed = baseSpeed * 1.45f;
        anim.crouch = false;
        if (NavMesh.SamplePosition(goal, out var h, 4f, NavMesh.AllAreas)) agent.SetDestination(h.position);
        moveT = Time.time + 0.5f;
        return true;
    }

    // Доклад выжившего другой группе: где и что; та группа дальше действует осторожно
    void Report(Soldier leader)
    {
        fleeing = false; fear = 0.3f;
        var sq = fleeTo;
        string where = leader.Bearing(dangerPos) + ", ~" + Mathf.RoundToInt(Vector3.Distance(leader.transform.position, dangerPos) / 10f) * 10 + " м";
        string text = "Там " + (dangerName ?? "объект") + " — " + where + "! Всю группу положило… я последний!";
        if (squadRt != null && squadRt.Alive > 1) text = "Там " + (dangerName ?? "объект") + " — " + where + "! Половину наших положило!";
        Callout(text, "report", true);
        Battle.Message(CallSign + " (" + squad.name + "): " + text, new Color(1f, 0.7f, 0.45f), 6f);
        if (sq != null)
        {
            sq.cautious = true; sq.dangerPos = dangerPos; sq.dangerName = dangerName;
            StartCoroutine(LeaderAnswer(leader, sq));
            // выживший присоединяется к этой группе
            if (squadRt != null) squadRt.members.Remove(this);
            sq.members.Add(this);
            squadRt = sq;
        }
    }

    IEnumerator LeaderAnswer(Soldier leader, SquadRt sq)
    {
        yield return new WaitForSeconds(3.2f);
        if (leader != null && leader.alive)
        {
            leader.Callout("Понял тебя. Всем — тихо, пригнуться, без лишнего шума. Идём осторожно.", "cautious", true);
            leader.anim.DoSignal(Signal.Hold);
        }
    }

    // Затишье: короткие разговоры рядом с товарищем
    static readonly string[][] chats =
    {
        new[] { "Тихо как-то… не нравится мне это.", "Не каркай." },
        new[] { "Сектор чист.", "Держим. Смотри по сторонам." },
        new[] { "Сколько ещё ждать?", "Сколько скажут." },
        new[] { "Слышал? Там, за постройками.", "Ветер. Наверное." },
        new[] { "После этого — отпуск.", "Ага. Мечтай." },
        new[] { "У кого есть вода?", "Держи, только не всё." },
        new[] { "Кто-нибудь видел объект своими глазами?", "И не хочу." },
    };
    void IdleChatter()
    {
        chatT = Time.time + Random.Range(25f, 70f);
        if (squadRt == null || zombie || Random.value < 0.4f) return;
        var cam = Game.Cam;
        if (cam == null || Vector3.Distance(cam.transform.position, transform.position) > 35f) return;
        Soldier mate = null;
        foreach (var m in squadRt.members)
            if (m != null && m != this && m.alive && m.target == null && Vector3.Distance(m.transform.position, transform.position) < 9f) { mate = m; break; }
        if (mate == null) return;
        var c = chats[Random.Range(0, chats.Length)];
        if (squadRt.cautious) c = new[] { "Шёпотом: ты видел, что от них осталось?", "Тише. Смотри в оба." };
        Speech.Say(transform, CallSign, c[0], -1f, new Color(0.85f, 0.88f, 0.92f));
        anim.DoSignal(Signal.Talk);
        mate.chatT = Time.time + 30f;
        StartCoroutine(ChatReply(mate, c[1]));
    }

    IEnumerator ChatReply(Soldier m, string text)
    {
        yield return new WaitForSeconds(Random.Range(2.2f, 3.2f));
        if (m != null && m.alive && m.target == null) Speech.Say(m.transform, m.CallSign, text, -1f, new Color(0.85f, 0.88f, 0.92f));
    }

    static readonly string[] downLines = { "Человек ранен! Минус один!", "Потеряли бойца!", "Он готов, двухсотый!", "Бойца убили!" };
    static readonly string[] killLines = { "Цель поражена!", "Минус один!", "Готов!", "Есть, лежит!" };
    static readonly string[] moveLines = { "Двигаюсь!", "Перемещаюсь, прикрой!", "Пошёл!", "Меняю позицию!" };
    public void SayMove() { if (Random.value < 0.25f) Callout(moveLines[Random.Range(0, moveLines.Length)], "move"); }

    // Смерть бойца: ближайший товарищ кричит «минус один», убийца-человек — «цель поражена»
    void DeathCallouts(DamageInfo d)
    {
        Soldier mate = null; float best = 30f * 30f;
        foreach (var u in Unit.All)
            if (u is Soldier s2 && s2 != this && s2.alive && s2.squad == squad)
            {
                float dd = (s2.transform.position - transform.position).sqrMagnitude;
                if (dd < best) { best = dd; mate = s2; }
            }
        if (mate != null) mate.Callout(downLines[Random.Range(0, downLines.Length)], "mandown", true);
        if (d.attacker is Soldier k && k.alive && Random.value < 0.6f) k.Callout(killLines[Random.Range(0, killLines.Length)], "enemydown");
    }

    public string Bearing(Vector3 p)
    {
        Vector3 d = p - transform.position; d.y = 0;
        float a = Mathf.Repeat(Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg, 360f);
        string[] n = { "север", "северо-восток", "восток", "юго-восток", "юг", "юго-запад", "запад", "северо-запад" };
        return "на " + n[Mathf.RoundToInt(a / 45f) % 8];
    }

    // Точка рядом, откуда ствол «видит» цель целиком (обход укрытия сбоку)
    bool FindFiringPos(Unit t, out Vector3 best)
    {
        best = transform.position;
        float bestD = float.MaxValue;
        Vector3 me = transform.position, tp = t.AimPoint;
        Vector3 to = tp - me; to.y = 0; to.Normalize();
        Vector3 side = Vector3.Cross(Vector3.up, to);
        for (int i = 0; i < 14; i++)
        {
            float lat = (i % 2 == 0 ? 1f : -1f) * (2f + (i / 2) * 1.6f);
            float fwd = (i % 3) * 2f;
            Vector3 c = me + side * lat + to * fwd;
            if (!NavMesh.SamplePosition(c, out var h, 1.5f, NavMesh.AllAreas)) continue;
            Vector3 muzzleH = h.position + Vector3.up * 1.25f;
            if (!Combat.Visible(muzzleH, tp) || !Combat.Visible(h.position + Vector3.up * 1.6f, tp)) continue;
            float d = Vector3.Distance(me, h.position);
            if (d < bestD) { bestD = d; best = h.position; }
        }
        return bestD < float.MaxValue;
    }

    // Ближайшая точка рядом, где противник нас не видит (за стеной, ящиком, машиной)
    bool FindCover(Vector3 threat, out Vector3 best)
    {
        best = transform.position;
        float bestD = float.MaxValue;
        Vector3 me = transform.position;
        for (int i = 0; i < 12; i++)
        {
            float a = i * 30f * Mathf.Deg2Rad + Random.Range(-0.2f, 0.2f);
            Vector3 c = me + new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a)) * Random.Range(2.5f, 9f);
            if (!NavMesh.SamplePosition(c, out var h, 1.5f, NavMesh.AllAreas)) continue;
            Vector3 head = h.position + Vector3.up * 1.0f;
            if (Combat.Visible(threat, head)) continue;
            float d = Vector3.Distance(me, h.position) + Vector3.Distance(h.position, threat) * 0.05f;
            if (d < bestD) { bestD = d; best = h.position; }
        }
        return bestD < float.MaxValue;
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
        else if (Time.time < suppressUntil)
        {
            if (Random.value < Time.deltaTime * 4f) aimNoise = Random.insideUnitSphere;
            desired = (lastSeenPos + aimNoise * 1.6f - EyePos).normalized;
        }
        else
        {
            Vector3 f = vel.sqrMagnitude > 0.5f ? vel.normalized : transform.forward;
            if (holding && sentryDir.sqrMagnitude > 0.1f && vel.sqrMagnitude < 0.25f) f = sentryDir;
            f.y = -0.05f;
            desired = f.normalized;
            // вертим головой по сторонам (на остановке патруля — шире, сектор за сектором)
            float sweep = patrolLook ? 70f : holding ? 45f : 35f;
            desired = Quaternion.Euler(0, Mathf.Sin(Time.time * (patrolLook ? 0.35f : 0.6f) + index * 1.7f) * sweep, 0) * desired;
        }
        aimDir = Vector3.RotateTowards(aimDir, desired, 260f * Mathf.Deg2Rad * dt, 1f).normalized;
    }

    void Shoot()
    {
        bool suppressing = (target == null || !targetVisible) && Time.time < suppressUntil && current != null && current.def.auto;
        if (current == null || (!suppressing && (target == null || !targetVisible)) || current.reloading || throwStart >= 0 || Time.time < switchT || healStart >= 0) return;
        if (suppressing)
        {
            if (current.ammo <= current.def.mag * 0.25f || Time.time < fireT) return;
            Vector3 sm = current.model != null ? current.model.muzzle.position : EyePos;
            if (Combat.Ray(sm, aimDir, 6f, this, out var fh, Layers.ShotMask)) { var fo = Combat.OwnerOf(fh.collider); if (fo != null && !IsEnemy(fo)) return; }
            if (current.Fire(this, sm, aimDir, 2.2f / Mathf.Max(0.4f, accuracy), sm))
            {
                anim.Kick(current.def.recoil * 0.8f, current.def.recoil);
                if (burstLeft <= 0) burstLeft = Random.Range(4, current.def.kind == WeaponKind.LMG ? 16 : 7);
                burstLeft--;
                if (burstLeft <= 0) fireT = Time.time + Random.Range(0.35f, 0.9f);
            }
            return;
        }
        if (!target.alive || !target.Targetable) return;
        Vector3 want = (target.AimPoint - EyePos).normalized;
        if (Vector3.Angle(aimDir, want) > 10f) return;
        if (Time.time < fireT) return;
        if (current.ammo <= 0) { current.StartReload(transform.position); return; }

        // не стреляем через своих и в укрытие перед целью (ствол ниже глаз: голова видит, а пуля уйдёт в ящик)
        Vector3 muzzle = current.model != null ? current.model.muzzle.position : EyePos;
        float dist = Vector3.Distance(muzzle, target.AimPoint);
        if (Combat.Ray(muzzle, aimDir, dist, this, out var hit, Layers.ShotMask))
        {
            var o = Combat.OwnerOf(hit.collider);
            if (o != null && o.alive && !IsEnemy(o) && o != target) { strafeT = 0; fireT = Time.time + 0.3f; return; }
            if (o == null && hit.distance < dist - 0.7f && current.def.kind != WeaponKind.Launcher)
            {
                blockedT = Time.time; fireT = Time.time + 0.25f;
                if (moveT > Time.time + 0.2f) moveT = Time.time + 0.1f;   // сразу ищем позицию для стрельбы
                return;
            }
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

        if (fleeing && FleeMove(me, baseSpeed)) return;
        // граната рядом — кричим и уходим от неё
        foreach (var gr in Grenade.Live)
        {
            if (gr == null || gr.Impact) continue;
            Vector3 gp = gr.transform.position;
            if ((gp - me).sqrMagnitude > 49f) continue;
            Vector3 away = me - gp; away.y = 0;
            if (away.sqrMagnitude < 0.01f) away = -transform.forward;
            Vector3 dst = me + away.normalized * 9f;
            agent.speed = baseSpeed * 1.5f;
            if (NavMesh.SamplePosition(dst, out var gh, 4f, NavMesh.AllAreas)) agent.SetDestination(gh.position);
            anim.crouch = false;
            Callout(Random.value < 0.5f ? "Граната! Ложись!" : "Граната! В укрытие!", "grenade");
            moveT = Time.time + 0.6f;
            return;
        }
        // носитель предмета содержания идёт к ослабленному объекту
        LoreItem li = null;
        foreach (var x in LoreItem.All) if (x != null && x.carrier == this) li = x;
        if (li != null && li.Goal(out var lg))
        {
            goal = lg; agent.speed = baseSpeed * 1.2f;
            goal.y = me.y;
            if (NavMesh.SamplePosition(goal, out var lh, 3f, NavMesh.AllAreas)) agent.SetDestination(lh.position);
            moveT = Time.time + 0.4f;
            return;
        }
        // медик идёт к раненому
        if (healTarget != null)
        {
            goal = healTarget.transform.position + (me - healTarget.transform.position).normalized * 1.1f;
            agent.speed = baseSpeed * 1.2f;
            goal.y = me.y;
            if (NavMesh.SamplePosition(goal, out var mh, 3f, NavMesh.AllAreas)) agent.SetDestination(mh.position);
            moveT = Time.time + 0.4f;
            return;
        }
        // перезарядка под огнём или тяжёлое ранение — в укрытие
        if (target != null && ((current != null && current.reloading) || (hp < maxHp * 0.4f && courage < 1.5f)))
        {
            if (coverT < Time.time)
            {
                coverT = Time.time + 3f;
                if (!FindCover(target.EyePos, out coverPos)) coverPos = me;
                else SayMove();
            }
            goal = coverPos; agent.speed = baseSpeed * 1.25f;
            goal.y = me.y;
            if (NavMesh.SamplePosition(goal, out var ch, 2f, NavMesh.AllAreas)) agent.SetDestination(ch.position);
            return;
        }
        // цель за укрытием — смещаемся туда, откуда есть чистая линия огня (обход, а не стрельба по ящикам)
        if (target != null && Time.time - blockedT < 2.5f)
        {
            if (firePosT < Time.time)
            {
                firePosT = Time.time + 2f;
                if (!FindFiringPos(target, out firePos)) firePos = me + Vector3.Cross(Vector3.up, (target.transform.position - me).normalized) * strafeDir * 5f;
            }
            goal = firePos; agent.speed = baseSpeed * 1.1f;
            goal.y = me.y;
            if (NavMesh.SamplePosition(goal, out var fh2, 2f, NavMesh.AllAreas)) agent.SetDestination(fh2.position);
            return;
        }
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
            // не уходим далеко от точки приказа
            if (squadRt != null && squadRt.orderSet)
            {
                float leash = squadRt.hold ? 28f : squadRt.overwatch ? 20f : 55f;
                if (Vector3.Distance(goal, squadRt.orderPos) > leash) goal = Vector3.Lerp(goal, squadRt.orderPos, 0.6f);
            }
            holding = false;
        }
        else if (squadRt != null && squadRt.orderSet)
        {
            var sq = squadRt;
            if ((sq.lastOrderPos - sq.orderPos).sqrMagnitude > 4f || !(sq.hold || sq.garrison)) { sq.lastOrderPos = sq.orderPos; sq.patrolSet = false; }
            var leader = sq.Leader;
            float dOrder = Vector3.Distance(me, sq.orderPos);
            float ang = index * 137.5f * Mathf.Deg2Rad;
            float rad = sq.hold ? 4f + (index % 3) * 2.5f : 3f + (index % 4) * 2f;
            Vector3 slot = sq.orderPos + new Vector3(Mathf.Cos(ang), 0, Mathf.Sin(ang)) * rad;
            holding = false;
            patrolLook = false;
            bool follow = sq.playerFollow && sq.playerCmdUntil > Time.time;
            if (follow)
            {
                float d = Vector3.Distance(me, slot);
                goal = d > 1.5f ? slot : me;
                agent.speed = baseSpeed * (d > 12f ? 1.3f : d > 4f ? 1f : 0.6f);
            }
            else if (sq.Sentry(this))
            {
                // часовой: свой пост лицом наружу, иногда переходит на пару метров
                float d = Vector3.Distance(me, slot);
                goal = d > 1.5f ? slot : me;
                agent.speed = baseSpeed * (d > 25f ? 1.3f : d > 6f ? 1f : 0.5f);
                holding = d < 3f;
                sentryDir = (slot - sq.orderPos).normalized;
            }
            else if (leader == this && (sq.hold || sq.garrison))
            {
                if (dOrder > 45f && !sq.patrolSet)
                {
                    goal = sq.orderPos; agent.speed = baseSpeed * (dOrder > 25f ? 1.2f : 1f);
                }
                else
                {
                    // маршрут: точки вокруг позиции, пауза — осмотреться
                    float pd = Vector3.Distance(me, sq.patrolPos);
                    if (!sq.patrolSet || pd < 2.5f || Time.time > sq.patrolUntil)
                    {
                        if (sq.patrolSet && pd < 2.5f && Time.time > sq.pauseUntil + 1f) sq.pauseUntil = Time.time + Random.Range(4f, 9f);
                        float leash = sq.hold || sq.garrison ? 26f : sq.overwatch ? 18f : 38f;
                        for (int k = 0; k < 6; k++)
                        {
                            Vector2 rr = Random.insideUnitCircle.normalized * Random.Range(leash * 0.35f, leash);
                            Vector3 cand = sq.orderPos + new Vector3(rr.x, 0, rr.y);
                            if (NavMesh.SamplePosition(cand, out var ph, 5f, NavMesh.AllAreas) && Vector3.Distance(ph.position, me) > 8f) { sq.patrolPos = ph.position; break; }
                        }
                        sq.patrolSet = true;
                        sq.patrolUntil = Time.time + 45f;
                    }
                    bool paused = Time.time < sq.pauseUntil;
                    goal = paused ? me : sq.patrolPos;
                    agent.speed = 1.55f;     // патрульный шаг
                    patrolLook = paused;
                }
            }
            else if (leader != null && leader != this && sq.patrolSet && (sq.hold || sq.garrison) && dOrder < 60f)
            {
                // колонна за командиром: по одному, со сдвигом через бойца
                int rank = 0;
                foreach (var m in sq.members) { if (m == this) break; if (m != null && m.alive && m != leader && !sq.Sentry(m)) rank++; }
                Transform lt = leader.transform;
                Vector3 back = -lt.forward;
                Vector3 off = back * (2.6f + rank * 2.3f) + lt.right * ((rank % 2 == 0 ? 1f : -1f) * 0.9f);
                Vector3 want = lt.position + off;
                float d = Vector3.Distance(me, want);
                goal = d > 1.2f ? want : me;
                agent.speed = d > 8f ? baseSpeed : Mathf.Max(1.4f, leader.vel.magnitude * (d > 3f ? 1.25f : 1f));
                patrolLook = leader.vel.magnitude < 0.3f;
            }
            else
            {
                // идём к точке приказа и занимаем место в построении вокруг неё
                float d = Vector3.Distance(me, slot);
                goal = d > 1.5f ? slot : me;
                agent.speed = baseSpeed * (d > 25f ? 1.3f : d > 6f ? 1f : 0.6f);
                holding = sq.hold && d < 3f;
            }
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
        anim.dying = -1f; anim.melee01 = -1f; anim.wounded = 0f; anim.idleActs = false;
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
        int bone = d.hitbox != null ? System.Array.IndexOf(rig.b, d.hitbox.transform) : -1;
        anim.HitReact(d.dir, Mathf.Clamp(dmg / 25f, 0.3f, 1.5f), bone < 0 ? HumanRig.Chest : bone);
        if (!zombie && target == null && d.attacker != null && IsEnemy(d.attacker)) { target = d.attacker; thinkT = Time.time + 0.2f; }
        if (!zombie && hp > 0 && Random.value < 0.4f) Sfx.Play("pain", AimPoint, 0.6f, Random.Range(0.9f, 1.1f), 40f);
        if (zombie && Random.value < 0.3f) Sfx.Play("groan", transform.position, 0.6f, 1.2f, 30f);
    }

    protected override void Die(DamageInfo d)
    {
        if (!zombie && !netPuppet) { DeathCallouts(d); if (d.attacker is ScpUnit killer) Witnesses(killer); }
        state = State.Dead;
        StopAllCoroutines();
        if (transform.parent != null) transform.SetParent(null, true);
        inVehicle = false;
        if (agent != null) agent.enabled = false;
        bool headshot = d.hitbox != null && d.hitbox.head;
        if (!headshot && d.type != DamageType.NeckSnap && d.type != DamageType.Corrosion && Random.value < 0.85f)
            Sfx.Play("death", AimPoint, 0.8f, Random.Range(0.88f, 1.08f), 55f);
        // от пули в корпус/конечности боец сначала оседает (подгибаются колени), а потом падает физически;
        // взрыв, выстрел в голову, удар SCP — сразу безвольное тело
        bool collapse = (d.type == DamageType.Bullet || d.type == DamageType.Melee || d.type == DamageType.Fire) && !headshot && d.force < 900f && anim.enabled && !zombie && !(d.attacker is ScpUnit);
        if (collapse) StartCoroutine(Collapse(d));
        else
        {
            anim.enabled = false;
            // шея ломается (SCP-173) — голова резко поворачивается, но в пределах сустава
            if (d.type == DamageType.NeckSnap)
            {
                rig.b[HumanRig.Head].localRotation = Quaternion.Euler(-25f, 50f, 20f);
                Sfx.Play("snap", rig.b[HumanRig.Head].position, 0.9f, 1f, 30f);
            }
            DropGun(d);
            ragdoll.Activate(d, vel * 0.6f);
        }
        if (d.hitbox != null && d.hitbox.head && d.type == DamageType.Bullet)
        {
            Fx.Blood(d.point, d.dir, 2.2f, d.hitbox.transform);
            Sfx.Play("headshot", d.point, 0.7f, Random.Range(0.9f, 1.1f), 30f);
        }
        if (d.type != DamageType.Corrosion && d.type != DamageType.Fire) StartCoroutine(BleedOut(d));
        if (!zombie) Dismember.OnDeath(this, d);
    }

    IEnumerator Collapse(DamageInfo d)
    {
        float dur = Random.Range(0.22f, 0.4f);
        float t = 0;
        anim.dying = 0f;
        anim.HitReact(d.dir, 1.2f, d.hitbox != null ? System.Array.IndexOf(rig.b, d.hitbox.transform) : HumanRig.Chest);
        Vector3 v0 = vel;
        bool dropped = false;
        while (t < dur)
        {
            t += Time.deltaTime;
            anim.dying = t / dur;
            anim.velocity = Vector3.Lerp(v0, Vector3.zero, t / dur);
            if (!dropped && t > dur * 0.35f) { dropped = true; DropGun(d); }
            yield return null;
        }
        if (!dropped) DropGun(d);
        anim.enabled = false;
        d.force *= 0.6f;
        ragdoll.Activate(d, v0 * 0.4f);
    }

    // Кровотечение: пульсирующие струйки из раны несколько секунд, потом лужи — под раной и под грудью;
    // одежда постепенно темнеет, пропитываясь кровью
    IEnumerator BleedOut(DamageInfo d)
    {
        Transform wound = d.hitbox != null ? d.hitbox.transform : rig.b[HumanRig.Chest];
        Vector3 local = wound.InverseTransformPoint(d.point.sqrMagnitude > 0.01f ? d.point : wound.position);
        float t = 0, dur = Random.Range(3f, 6f) * (d.hitbox != null && d.hitbox.head ? 0.6f : 1f);
        float pulse = 0;
        while (t < dur && this != null && ragdoll != null && !ragdoll.sinking)
        {
            t += Time.deltaTime; pulse += Time.deltaTime;
            float strength = 1f - t / dur;
            if (pulse > 0.75f)   // удары сердца
            {
                pulse = 0;
                Vector3 p = wound.TransformPoint(local);
                Vector3 outDir = (p - wound.position).sqrMagnitude > 0.0001f ? (p - wound.position).normalized : wound.forward;
                Fx.Blood(p, (outDir + Vector3.up * 0.5f).normalized, 0.35f * strength);
            }
            yield return null;
        }
        if (this == null || ragdoll == null || ragdoll.sinking) yield break;
        Fx.BloodPool(wound.position, Random.Range(0.6f, 1.1f));
        yield return new WaitForSeconds(Random.Range(0.6f, 1.4f));
        if (this == null || ragdoll == null || ragdoll.sinking) yield break;
        Fx.BloodPool(rig.b[HumanRig.Chest].position, Random.Range(0.9f, 1.6f));
        // пропитанная кровью одежда
        foreach (var r in GetComponentsInChildren<Renderer>())
        {
            if (r is ParticleSystemRenderer) continue;
            var ms = r.materials;
            foreach (var m in ms) if (m != null && m.renderQueue < 2500) m.color = Color.Lerp(m.color, new Color(0.25f, 0.05f, 0.04f), 0.18f);
            r.materials = ms;
        }
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
        rb.SetVel(vel + d.dir * 1.5f + Vector3.up * 1f);
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
