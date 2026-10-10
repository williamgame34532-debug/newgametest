using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public static class ScpFactory
{
    public static Unit Spawn(ScpKind kind, Vector3 pos, Quaternion rot)
    {
        switch (kind)
        {
            case ScpKind.S173: return Scp173.Create(pos, rot);
            case ScpKind.S096: return Scp096.Create(pos, rot);
            case ScpKind.S049: return Scp049.Create(pos, rot);
            case ScpKind.S0492: return Soldier.CreateZombie(pos, rot);
            case ScpKind.S106: return Scp106.Create(pos, rot);
            case ScpKind.S939: return QuadScp.Create939(pos, rot);
            case ScpKind.S682: return QuadScp.Create682(pos, rot);
            case ScpKind.S457: return Scp457.Create(pos, rot);
        }
        return null;
    }
}

// Базовый класс SCP-объектов
public abstract class ScpUnit : Unit
{
    public ScpKind kind;
    protected NavMeshAgent agent;
    protected bool held;
    protected Unit target;
    protected float thinkT;
    protected Vector3 vel;
    public override Vector3 Velocity => vel;

    protected void Init(ScpKind k, string name)
    {
        kind = k;
        team = Team.SCP;
        isScp = true;
        displayName = name;
        var def = DB.Scp(k);
        maxHp = hp = def != null ? def.hp : 1000f;
        threat = Mathf.Clamp(maxHp / 400f, 1.5f, 6f);
    }

    float agR = 0.4f, agH = 1.9f, agSpeed = 3f, agAccel = 12f;

    // Параметры агента; сам агент создаётся, когда объект окажется на навмеше
    protected void SetupAgent(float radius, float height, float speed, float accel = 12f)
    {
        agR = radius; agH = height; agSpeed = speed; agAccel = accel;
    }

    protected bool EnsureAgent()
    {
        if (!NavMesh.SamplePosition(transform.position, out var nh, 6f, NavMesh.AllAreas)) return false;
        transform.position = nh.position;
        if (agent == null)
        {
            agent = gameObject.AddComponent<NavMeshAgent>();
            agent.radius = agR;
            agent.height = agH;
            agent.speed = agSpeed;
            agent.acceleration = agAccel;
            agent.angularSpeed = 0;
            agent.updateRotation = false;
            agent.stoppingDistance = 0.3f;
            agent.obstacleAvoidanceType = ObstacleAvoidanceType.LowQualityObstacleAvoidance;
        }
        agent.enabled = true;
        agent.Warp(nh.position);
        return true;
    }

    public void Hold(bool h)
    {
        held = h;
        if (h) { if (agent != null) agent.enabled = false; }
        else EnsureAgent();
    }

    public virtual void SetAnimVelocity(Vector3 v) { vel = v; }

    protected bool AgentOk => agent != null && agent.enabled && agent.isOnNavMesh;

    protected void GoTo(Vector3 p)
    {
        if (!AgentOk) return;
        if (NavMesh.SamplePosition(p, out var nh, 4f, NavMesh.AllAreas)) agent.SetDestination(nh.position);
    }

    protected void Face(Vector3 dir, float speed, float dt)
    {
        dir.y = 0;
        if (dir.sqrMagnitude < 0.001f) return;
        transform.rotation = Quaternion.RotateTowards(transform.rotation, Quaternion.LookRotation(dir), speed * dt);
    }

    protected virtual void Update()
    {
        if (!alive || held) return;
        float dt = Time.deltaTime;
        if (dt <= 0) return;
        if (agent != null && agent.enabled) vel = agent.velocity;
        Tick(dt);
    }

    protected abstract void Tick(float dt);

    // Мгновенное убийство с отлётом тела
    protected void Slay(Unit u, DamageType type, Vector3 dir, float force, string how)
    {
        if (u == null || !u.alive) return;
        u.TakeDamage(new DamageInfo { amount = 99999, type = type, dir = dir, force = force, point = u.AimPoint, attacker = this, weapon = how });
    }
}

// Человекоподобный SCP со скелетом, анимацией и физическим телом
public abstract class HumanScp : ScpUnit
{
    public HumanRig rig;
    public HumanAnimator anim;
    public Ragdoll ragdoll;
    protected Vector3 aimDir;
    protected float attackStart = -1;

    protected void BuildBody(BodyShape shape, AnimStyle style)
    {
        rig = HumanRig.Create(transform, shape);
        Dress();
        rig.Finish();
        ragdoll = Ragdoll.BuildHuman(rig, this, 1.1f);
        anim = gameObject.AddComponent<HumanAnimator>();
        anim.rig = rig;
        anim.style = style;
        eye = rig.eye;
        chestPoint = rig.b[HumanRig.Chest];
        aimDir = transform.forward;
    }

    protected abstract void Dress();

    public override void SetAnimVelocity(Vector3 v) { vel = v; if (anim != null) anim.velocity = v; }

    protected void Animate(Vector3 look)
    {
        anim.velocity = vel;
        aimDir = Vector3.RotateTowards(aimDir, look.sqrMagnitude > 0.001f ? look.normalized : transform.forward, 3f * Time.deltaTime, 1f);
        anim.aimDir = aimDir;
    }

    protected override void OnHurt(DamageInfo d, float dmg) { anim.Flinch(d.dir, Mathf.Clamp(dmg / 80f, 0.1f, 0.6f)); }

    protected override void Die(DamageInfo d)
    {
        StopAllCoroutines();
        if (agent != null) agent.enabled = false;
        anim.enabled = false;
        ragdoll.Activate(d, vel * 0.5f);
        Battle.Message(displayName + " НЕЙТРАЛИЗОВАН", new Color(0.4f, 0.9f, 1f));
    }

    public override void CorpseHit(Hitbox hb, Vector3 point, Vector3 impulse) { ragdoll.Hit(hb.rb, point, impulse); }

    // Общий удар рукой: возвращает true в момент попадания
    protected bool MeleeStep(float duration, ref bool hitDone)
    {
        if (attackStart < 0) return false;
        float a = (Time.time - attackStart) / duration;
        anim.attack01 = a;
        bool fire = false;
        if (!hitDone && a > 0.5f) { hitDone = true; fire = true; }
        if (a >= 1f) { attackStart = -1; anim.attack01 = -1; }
        return fire;
    }
}

// ================= SCP-173 =================
public class Scp173 : ScpUnit
{
    float observedCheckT;
    bool observed;
    AudioSource scrape;
    float lastMoveSnd;
    Transform model;

    public static Scp173 Create(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-173");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Scp173>();
        s.Init(ScpKind.S173, "SCP-173");
        s.armor = 0.6f;
        s.threat = 5f;
        s.BuildModel();
        s.SetupAgent(0.4f, 2f, 20f, 300f);
        s.scrape = Sfx.Loop("scrape", go.transform, 0f, 40f);
        return s;
    }

    void BuildModel()
    {
        model = new GameObject("model").transform;
        model.SetParent(transform, false);
        var t = model;
        Color con = new Color(0.7f, 0.66f, 0.58f), red = new Color(0.55f, 0.08f, 0.05f), green = new Color(0.2f, 0.45f, 0.15f), brown = new Color(0.35f, 0.22f, 0.12f);
        var cm = Mats.Get(con, 0.1f);
        MeshKit.Part(t, MeshKit.Frustum(0.8f), cm, new Vector3(-0.11f, 0.3f, 0), new Vector3(0.2f, 0.6f, 0.22f));
        MeshKit.Part(t, MeshKit.Frustum(0.8f), cm, new Vector3(0.11f, 0.3f, 0), new Vector3(0.2f, 0.6f, 0.22f));
        MeshKit.Part(t, MeshKit.Frustum(1.45f), cm, new Vector3(0, 1.05f, 0), new Vector3(0.42f, 0.95f, 0.36f));
        MeshKit.Ball(t, new Vector3(0, 1.52f, 0), new Vector3(0.6f, 0.2f, 0.42f), cm);
        MeshKit.Cyl(t, new Vector3(-0.33f, 1.15f, 0.02f), 0.09f, 0.8f, con, new Vector3(0, 0, -4));
        MeshKit.Cyl(t, new Vector3(0.33f, 1.15f, 0.02f), 0.09f, 0.8f, con, new Vector3(0, 0, 4));
        MeshKit.Cyl(t, new Vector3(0, 1.66f, 0), 0.16f, 0.12f, con);
        MeshKit.Ball(t, new Vector3(0, 1.84f, 0.01f), new Vector3(0.34f, 0.38f, 0.33f), cm);
        // аэрозольная краска
        MeshKit.Cyl(t, new Vector3(-0.07f, 1.88f, 0.155f), 0.1f, 0.01f, green, new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(0.07f, 1.88f, 0.155f), 0.1f, 0.01f, green, new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(-0.07f, 1.88f, 0.16f), 0.04f, 0.01f, new Color(0.05f, 0.05f, 0.05f), new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(0.07f, 1.88f, 0.16f), 0.04f, 0.01f, new Color(0.05f, 0.05f, 0.05f), new Vector3(90, 0, 0));
        MeshKit.Box(t, new Vector3(0, 1.74f, 0.155f), new Vector3(0.16f, 0.035f, 0.01f), red);
        MeshKit.Box(t, new Vector3(0, 1.0f, 0.18f), new Vector3(0.3f, 0.08f, 0.01f), red, new Vector3(0, 0, 12));
        MeshKit.Box(t, new Vector3(0.05f, 1.25f, 0.175f), new Vector3(0.06f, 0.4f, 0.01f), brown, new Vector3(0, 0, -20));
        MeshKit.Box(t, new Vector3(-0.1f, 1.35f, -0.16f), new Vector3(0.25f, 0.1f, 0.01f), green, new Vector3(0, 0, 30));
        MeshKit.Box(t, new Vector3(0.0f, 0.7f, 0.15f), new Vector3(0.1f, 0.3f, 0.01f), red, new Vector3(0, 0, 50));
        MeshKit.CombineParts(t);

        var rb = gameObject.AddComponent<Rigidbody>(); rb.isKinematic = true;
        var bodyHb = new GameObject("hb_body");
        bodyHb.transform.SetParent(transform, false);
        bodyHb.layer = Layers.Body;
        Ragdoll.Capsule(bodyHb.transform, new Vector3(0, 0.9f, 0), 0.32f, 1.8f);
        var hb = bodyHb.AddComponent<Hitbox>(); hb.owner = this; hb.mul = 1f;
        var headHb = new GameObject("hb_head");
        headHb.transform.SetParent(transform, false);
        headHb.layer = Layers.Body;
        Ragdoll.SphereC(headHb.transform, new Vector3(0, 1.84f, 0), 0.2f);
        var hh = headHb.AddComponent<Hitbox>(); hh.owner = this; hh.mul = 1.2f; hh.head = true;
        var e = new GameObject("eye").transform; e.SetParent(transform, false); e.localPosition = new Vector3(0, 1.85f, 0.15f);
        eye = e;
        var c = new GameObject("chest").transform; c.SetParent(transform, false); c.localPosition = new Vector3(0, 1.2f, 0);
        chestPoint = c;
    }

    // Наблюдают ли за статуей прямо сейчас
    bool IsObserved()
    {
        Vector3 me = transform.position + Vector3.up * 1.2f;
        foreach (var u in Unit.All)
        {
            if (u == null || !u.alive || u.isScp || u.inVehicle) continue;
            if (u is Soldier s && s.Blinking) continue;
            if (u.isPlayer && PlayerController.I != null && PlayerController.I.Blinking) continue;
            Vector3 e = u.EyePos;
            Vector3 to = me - e;
            float d = to.magnitude;
            if (d > 90f) continue;
            if (Vector3.Angle(u.LookDir, to) > (u.isPlayer ? 42f : 60f)) continue;
            if (!Combat.Visible(e, me) && !Combat.Visible(e, transform.position + Vector3.up * 1.8f)) continue;
            return true;
        }
        return false;
    }

    protected override void Tick(float dt)
    {
        if (Time.time > observedCheckT)
        {
            observedCheckT = Time.time + 0.06f;
            observed = IsObserved();
        }
        if (!AgentOk) { if (!held) EnsureAgent(); return; }
        if (observed)
        {
            agent.isStopped = true;
            agent.velocity = Vector3.zero;
            vel = Vector3.zero;
            if (scrape != null) scrape.volume = Mathf.MoveTowards(scrape.volume, 0, dt * 8f);
            return;
        }
        agent.isStopped = false;
        if (Time.time > thinkT)
        {
            thinkT = Time.time + 0.25f;
            target = Battle.NearestEnemyUnit(this, true);
            if (target != null) GoTo(target.transform.position);
        }
        if (scrape != null) scrape.volume = Mathf.MoveTowards(scrape.volume, vel.magnitude > 1f ? 0.8f * Sfx.Volume : 0f, dt * 10f);
        if (target != null)
        {
            Face(target.transform.position - transform.position, 2000f, dt);
            if (Vector3.Distance(target.transform.position, transform.position) < 1.4f && target.alive)
            {
                Slay(target, DamageType.NeckSnap, transform.forward, 80f, "Сломанная шея");
                agent.velocity = Vector3.zero;
                observedCheckT = 0;
                thinkT = 0;
            }
        }
    }

    public override void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Impact(point, normal, new Color(0.7f, 0.66f, 0.58f), true);
        if (Random.value < 0.4f) Sfx.Play("ricochet", point, 0.4f, Random.Range(0.8f, 1.2f), 40f);
    }

    protected override void Die(DamageInfo d)
    {
        if (agent != null) agent.enabled = false;
        if (scrape != null) scrape.Stop();
        // статуя рассыпается на куски
        Color con = new Color(0.7f, 0.66f, 0.58f);
        for (int i = 0; i < 26; i++)
        {
            var ch = new GameObject("chunk");
            ch.layer = Layers.Corpse;
            ch.transform.position = transform.position + new Vector3(Random.Range(-0.25f, 0.25f), Random.Range(0.2f, 1.9f), Random.Range(-0.2f, 0.2f));
            ch.transform.rotation = Random.rotation;
            float sz = Random.Range(0.12f, 0.3f);
            MeshKit.Box(ch.transform, Vector3.zero, Vector3.one * sz, con);
            var bc = ch.AddComponent<BoxCollider>(); bc.size = Vector3.one * sz;
            var rb = ch.AddComponent<Rigidbody>(); rb.mass = sz * 30f;
            rb.velocity = (Random.insideUnitSphere * 3f + d.dir * 3f + Vector3.up * 2f);
            Destroy(ch, 40f);
        }
        Fx.Smoke(transform.position + Vector3.up, 3f, new Color(0.7f, 0.68f, 0.62f, 0.6f), 4f, Vector3.up);
        Fx.Impact(transform.position + Vector3.up, Vector3.up, con, false);
        Sfx.Play("explosion", transform.position, 0.6f, 1.6f, 80f);
        model.gameObject.SetActive(false);
        foreach (var c in GetComponentsInChildren<Collider>()) c.enabled = false;
        Battle.Message("SCP-173 УНИЧТОЖЕН", new Color(0.4f, 0.9f, 1f));
    }
}

// ================= SCP-096 =================
public class Scp096 : HumanScp
{
    enum Mode { Calm, Triggered, Rage }
    Mode mode = Mode.Calm;
    readonly List<Unit> targets = new List<Unit>();
    float modeT, checkT, wanderT;
    Vector3 home;
    AudioSource cry;
    bool hitDone;

    public bool Enraged => mode != Mode.Calm;

    public static Scp096 Create(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-096");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Scp096>();
        s.Init(ScpKind.S096, "SCP-096");
        s.armor = 0.55f;
        s.BuildBody(BodyShape.Tall096(), AnimStyle.Shy);
        s.SetupAgent(0.4f, 2.4f, 1.2f, 40f);
        s.home = pos;
        s.cry = Sfx.Loop("cry", go.transform, 0.5f, 35f);
        return s;
    }

    protected override void Dress()
    {
        Color skin = new Color(0.86f, 0.84f, 0.8f), dark = new Color(0.05f, 0.04f, 0.04f);
        var b = rig.b; var s = rig.shape;
        MeshKit.Box(b[HumanRig.Hips], new Vector3(0, -0.01f, 0), new Vector3(0.22f, 0.18f, 0.15f), skin);
        MeshKit.Box(b[HumanRig.Spine], new Vector3(0, 0.1f, 0), new Vector3(0.2f, 0.25f, 0.13f), skin);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.12f, 0), new Vector3(0.26f, 0.32f, 0.15f), skin);
        for (int i = 0; i < 4; i++) MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.02f + i * 0.06f, 0.075f), new Vector3(0.2f, 0.012f, 0.01f), skin * 0.85f); // рёбра
        MeshKit.Cyl(b[HumanRig.Neck], new Vector3(0, 0.06f, 0), 0.07f, 0.16f, skin);
        var h = b[HumanRig.Head];
        MeshKit.Ball(h, new Vector3(0, 0.15f, 0.0f), new Vector3(0.2f, 0.3f, 0.21f), skin);
        MeshKit.Ball(h, new Vector3(-0.045f, 0.19f, 0.09f), new Vector3(0.05f, 0.04f, 0.03f), dark);
        MeshKit.Ball(h, new Vector3(0.045f, 0.19f, 0.09f), new Vector3(0.05f, 0.04f, 0.03f), dark);
        // челюсть открывается при крике
        rig.jaw = new GameObject("jaw").transform;
        rig.jaw.SetParent(h, false);
        rig.jaw.localPosition = new Vector3(0, 0.1f, 0.02f);
        MeshKit.Box(rig.jaw, new Vector3(0, -0.06f, 0.06f), new Vector3(0.14f, 0.08f, 0.1f), skin);
        MeshKit.Box(rig.jaw, new Vector3(0, -0.03f, 0.08f), new Vector3(0.11f, 0.05f, 0.06f), dark);
        MeshKit.Box(h, new Vector3(0, 0.07f, 0.08f), new Vector3(0.11f, 0.04f, 0.06f), dark);
        for (int side = 0; side < 2; side++)
        {
            float sx = side == 0 ? -1 : 1;
            MeshKit.Taper(b[side == 0 ? HumanRig.UArmL : HumanRig.UArmR], new Vector3(0, -s.armU * 0.5f, 0), 0.055f, 0.07f, s.armU + 0.02f, skin);
            MeshKit.Taper(b[side == 0 ? HumanRig.LArmL : HumanRig.LArmR], new Vector3(0, -s.armL * 0.5f, 0), 0.045f, 0.055f, s.armL + 0.02f, skin);
            var hand = b[side == 0 ? HumanRig.HandL : HumanRig.HandR];
            MeshKit.Box(hand, new Vector3(0, -0.05f, 0), new Vector3(0.06f, 0.1f, 0.025f), skin);
            for (int f = 0; f < 4; f++) MeshKit.Box(hand, new Vector3(-0.022f + f * 0.015f, -0.15f, 0), new Vector3(0.011f, 0.12f, 0.012f), skin);
            MeshKit.Taper(b[side == 0 ? HumanRig.ULegL : HumanRig.ULegR], new Vector3(0, -s.legU * 0.5f, 0), 0.07f, 0.1f, s.legU + 0.02f, skin);
            MeshKit.Taper(b[side == 0 ? HumanRig.LLegL : HumanRig.LLegR], new Vector3(0, -s.legL * 0.5f, 0), 0.055f, 0.075f, s.legL + 0.02f, skin);
            MeshKit.Box(b[side == 0 ? HumanRig.FootL : HumanRig.FootR], new Vector3(0, -0.03f, 0.05f), new Vector3(0.07f, 0.05f, 0.22f), skin);
        }
    }

    // Кто-то увидел лицо?
    void CheckFaceSeen()
    {
        Vector3 face = rig.b[HumanRig.Head].position + Vector3.up * 0.15f;
        Vector3 faceFwd = rig.b[HumanRig.Head].forward;
        foreach (var u in Unit.All)
        {
            if (u == null || !u.alive || u.isScp || u.inVehicle || targets.Contains(u)) continue;
            if (u.squad != null && u.squad.ignores096) continue;
            Vector3 e = u.EyePos;
            Vector3 to = face - e;
            float d = to.magnitude;
            if (d > 80f) continue;
            if (Vector3.Angle(u.LookDir, to) > (u.isPlayer ? 18f : 22f)) continue;
            if (Vector3.Dot(faceFwd, -to.normalized) < 0.1f) continue;
            if (!Combat.Visible(e, face)) continue;
            targets.Add(u);
            if (u.isPlayer) Battle.Message("ВЫ ВИДЕЛИ ЛИЦО SCP-096", new Color(1f, 0.2f, 0.2f));
            if (mode == Mode.Calm) Trigger();
        }
    }

    void Trigger()
    {
        mode = Mode.Triggered;
        modeT = Time.time + 5f;
        if (agent != null && agent.enabled) agent.isStopped = true;
        Sfx.Play("scream", transform.position, 1f, 1f, 220f);
        Battle.Message("SCP-096 В ЯРОСТИ", new Color(1f, 0.15f, 0.15f));
        if (cry != null) cry.Stop();
    }

    protected override void Tick(float dt)
    {
        if (Time.time > checkT)
        {
            checkT = Time.time + 0.12f;
            CheckFaceSeen();
        }
        targets.RemoveAll(u => u == null || !u.alive);
        switch (mode)
        {
            case Mode.Calm:
                anim.style = AnimStyle.Shy;
                anim.handsOnFace = vel.magnitude < 0.3f;
                anim.crouch = vel.magnitude < 0.2f && Time.time % 20f < 12f;
                anim.mouth = 0;
                if (AgentOk)
                {
                    agent.speed = 1.1f;
                    agent.isStopped = false;
                    if (Time.time > wanderT)
                    {
                        wanderT = Time.time + Random.Range(5f, 12f);
                        GoTo(home + new Vector3(Random.Range(-6f, 6f), 0, Random.Range(-6f, 6f)));
                    }
                }
                if (vel.sqrMagnitude > 0.05f) Face(vel, 90f, dt);
                Animate(transform.forward + Vector3.down * 0.4f);
                break;

            case Mode.Triggered:
                anim.handsOnFace = true;
                anim.crouch = false;
                anim.mouth = 0.6f + Mathf.Sin(Time.time * 30f) * 0.3f;
                anim.Flinch(Random.insideUnitSphere, 0.2f);
                vel = Vector3.zero;
                Animate(transform.forward + Vector3.up * 0.3f);
                if (Time.time > modeT) { mode = Mode.Rage; if (AgentOk) agent.isStopped = false; }
                break;

            case Mode.Rage:
                anim.style = AnimStyle.ShyRage;
                anim.handsOnFace = false;
                anim.crouch = false;
                anim.mouth = 0.85f + Mathf.Sin(Time.time * 15f) * 0.15f;
                if (targets.Count == 0)
                {
                    // все, кто видел лицо, мертвы — успокаивается
                    mode = Mode.Calm;
                    home = transform.position;
                    if (cry != null) cry.Play();
                    break;
                }
                if (target == null || !target.alive || !targets.Contains(target))
                {
                    target = null; float best = float.MaxValue;
                    foreach (var u in targets) { float d = (u.transform.position - transform.position).sqrMagnitude; if (d < best) { best = d; target = u; } }
                }
                if (target == null) break;
                if (AgentOk)
                {
                    agent.speed = 15f;
                    agent.acceleration = 50f;
                    if (Time.time > thinkT) { thinkT = Time.time + 0.2f; GoTo(target.transform.position); }
                }
                // если цель в вертолёте или недосягаема — ждёт внизу
                Face(target.transform.position - transform.position, 600f, dt);
                Animate(target.AimPoint - EyePos);
                float dist = Vector3.Distance(target.transform.position, transform.position);
                if (attackStart < 0 && dist < 2.2f && target.Targetable) { attackStart = Time.time; hitDone = false; }
                if (MeleeStep(0.4f, ref hitDone) && target != null && Vector3.Distance(target.transform.position, transform.position) < 3f)
                {
                    Vector3 dir = (transform.forward + Vector3.up * 0.8f).normalized;
                    Fx.Blood(target.AimPoint, dir, 3f);
                    Fx.Blood(target.AimPoint, -dir, 2f);
                    Sfx.Play("flesh", target.AimPoint, 1f, 0.7f, 40f);
                    Slay(target, DamageType.Melee, dir, 2200f, "Разорван SCP-096");
                }
                break;
        }
    }

    protected override void OnHurt(DamageInfo d, float dmg)
    {
        base.OnHurt(d, dmg);
    }

    protected override void Die(DamageInfo d)
    {
        if (cry != null) cry.Stop();
        base.Die(d);
    }
}

// ================= SCP-049 =================
public class Scp049 : HumanScp
{
    bool hitDone;
    Soldier patient;
    float cureEnd;

    public static Scp049 Create(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-049");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Scp049>();
        s.Init(ScpKind.S049, "SCP-049");
        s.armor = 0.3f;
        s.BuildBody(BodyShape.Soldier(1f), AnimStyle.Doctor);
        s.SetupAgent(0.4f, 1.9f, 3.3f);
        return s;
    }

    protected override void Dress()
    {
        Color robe = new Color(0.07f, 0.065f, 0.06f), mask = new Color(0.85f, 0.8f, 0.68f), glove = new Color(0.04f, 0.04f, 0.04f);
        var b = rig.b; var s = rig.shape;
        // мантия до земли
        MeshKit.Part(b[HumanRig.Hips], MeshKit.Frustum(0.55f), Mats.Get(robe, 0.15f), new Vector3(0, -0.42f, 0.0f), new Vector3(0.62f, 0.95f, 0.5f));
        MeshKit.Box(b[HumanRig.Spine], new Vector3(0, 0.08f, 0), new Vector3(0.32f, 0.22f, 0.21f), robe);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.1f, 0), new Vector3(0.4f, 0.32f, 0.24f), robe);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.27f, -0.02f), new Vector3(0.44f, 0.08f, 0.28f), robe); // капюшон-плечи
        MeshKit.Box(b[HumanRig.Hips], new Vector3(0, 0.06f, 0), new Vector3(0.34f, 0.04f, 0.23f), new Color(0.25f, 0.18f, 0.1f));
        MeshKit.Cyl(b[HumanRig.Neck], new Vector3(0, 0.04f, 0), 0.13f, 0.12f, robe);
        var h = b[HumanRig.Head];
        MeshKit.Ball(h, new Vector3(0, 0.12f, -0.01f), new Vector3(0.26f, 0.3f, 0.27f), robe);              // капюшон
        MeshKit.Ball(h, new Vector3(0, 0.12f, 0.05f), new Vector3(0.19f, 0.22f, 0.17f), Mats.Get(mask, 0.5f)); // маска
        MeshKit.Part(h, MeshKit.Frustum(0.15f), Mats.Get(mask, 0.5f), new Vector3(0, 0.07f, 0.2f), new Vector3(0.09f, 0.22f, 0.1f), new Vector3(100, 0, 0)); // клюв
        MeshKit.Cyl(h, new Vector3(-0.045f, 0.145f, 0.125f), 0.05f, 0.015f, Mats.Glass(new Color(0.05f, 0.05f, 0.05f, 0.9f)), new Vector3(90, 0, 0));
        MeshKit.Cyl(h, new Vector3(0.045f, 0.145f, 0.125f), 0.05f, 0.015f, Mats.Glass(new Color(0.05f, 0.05f, 0.05f, 0.9f)), new Vector3(90, 0, 0));
        for (int side = 0; side < 2; side++)
        {
            MeshKit.Taper(b[side == 0 ? HumanRig.UArmL : HumanRig.UArmR], new Vector3(0, -s.armU * 0.5f, 0), 0.1f, 0.12f, s.armU + 0.03f, robe);
            MeshKit.Taper(b[side == 0 ? HumanRig.LArmL : HumanRig.LArmR], new Vector3(0, -s.armL * 0.5f, 0), 0.11f, 0.09f, s.armL + 0.02f, robe);
            MeshKit.Box(b[side == 0 ? HumanRig.HandL : HumanRig.HandR], new Vector3(0, -0.05f, 0), new Vector3(0.06f, 0.1f, 0.035f), glove);
            MeshKit.Taper(b[side == 0 ? HumanRig.ULegL : HumanRig.ULegR], new Vector3(0, -s.legU * 0.5f, 0), 0.11f, 0.13f, s.legU, robe);
            MeshKit.Taper(b[side == 0 ? HumanRig.LLegL : HumanRig.LLegR], new Vector3(0, -s.legL * 0.5f, 0), 0.09f, 0.11f, s.legL, robe);
            MeshKit.Box(b[side == 0 ? HumanRig.FootL : HumanRig.FootR], new Vector3(0, -0.035f, 0.045f), new Vector3(0.1f, 0.07f, 0.24f), glove);
        }
        // саквояж
        MeshKit.Box(b[HumanRig.HandL], new Vector3(0, -0.15f, 0), new Vector3(0.1f, 0.18f, 0.3f), new Color(0.2f, 0.12f, 0.07f));
    }

    protected override void Tick(float dt)
    {
        // "лечение" трупа
        if (patient != null)
        {
            anim.kneel = true;
            anim.attack01 = ((Time.time * 1.2f) % 1f);
            vel = Vector3.zero;
            if (AgentOk) agent.isStopped = true;
            Face(patient.rig.b[HumanRig.Chest].position - transform.position, 180f, dt);
            Animate(patient.rig.b[HumanRig.Chest].position - EyePos);
            if (Time.time > cureEnd)
            {
                anim.kneel = false;
                anim.attack01 = -1;
                var p = patient;
                patient = null;
                if (p != null && !p.alive && p.ragdoll != null && !p.ragdoll.sinking)
                {
                    p.Reanimate();
                    Battle.Register(p);
                    Battle.Message("SCP-049 «вылечил» бойца — встаёт SCP-049-2", new Color(0.8f, 0.9f, 0.6f));
                }
                if (AgentOk) agent.isStopped = false;
            }
            return;
        }
        if (Time.time > thinkT)
        {
            thinkT = Time.time + 0.4f;
            target = Battle.NearestEnemyUnit(this, true);
            if (target != null) GoTo(target.transform.position);
        }
        if (AgentOk) agent.speed = 3.3f;
        Vector3 look = target != null ? target.AimPoint - EyePos : transform.forward;
        Face(vel.sqrMagnitude > 0.1f ? vel : look, 240f, dt);
        Animate(look);
        if (target != null && attackStart < 0 && Vector3.Distance(target.transform.position, transform.position) < 1.8f && target.Targetable)
        {
            attackStart = Time.time; hitDone = false;
        }
        if (MeleeStep(0.7f, ref hitDone) && target != null && target.alive && Vector3.Distance(target.transform.position, transform.position) < 2.3f)
        {
            var victim = target;
            Slay(victim, DamageType.Touch, transform.forward, 150f, "Прикосновение SCP-049");
            Sfx.Play("snap", victim.AimPoint, 0.4f, 0.6f, 25f);
            if (victim is Soldier vs && !vs.zombie)
            {
                patient = vs;
                cureEnd = Time.time + 3.5f;
            }
        }
    }
}

// ================= SCP-106 =================
public class Scp106 : HumanScp
{
    bool hitDone;
    bool phased;
    float phaseCd, gooT;

    public override bool Targetable => base.Targetable && !phased;

    public static Scp106 Create(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-106");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Scp106>();
        s.Init(ScpKind.S106, "SCP-106");
        s.armor = 0.65f;
        s.BuildBody(BodyShape.Old106(), AnimStyle.Old);
        s.SetupAgent(0.4f, 1.9f, 2.4f);
        s.phaseCd = Time.time + 8f;
        return s;
    }

    protected override void Dress()
    {
        Color skin = new Color(0.1f, 0.085f, 0.07f), cloth = new Color(0.04f, 0.035f, 0.03f);
        var sk = Mats.Get(skin, 0.85f);
        var b = rig.b; var s = rig.shape;
        MeshKit.Box(b[HumanRig.Hips], new Vector3(0, -0.01f, 0), new Vector3(0.28f, 0.2f, 0.19f), cloth);
        MeshKit.Box(b[HumanRig.Spine], new Vector3(0, 0.08f, 0), new Vector3(0.27f, 0.2f, 0.18f), cloth);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.1f, 0), new Vector3(0.34f, 0.3f, 0.2f), cloth);
        MeshKit.Cyl(b[HumanRig.Neck], new Vector3(0, 0.05f, 0), 0.09f, 0.13f, sk);
        var h = b[HumanRig.Head];
        MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.2f, 0.26f, 0.22f), sk);
        MeshKit.Ball(h, new Vector3(-0.045f, 0.13f, 0.095f), Vector3.one * 0.03f, Mats.Get(new Color(0.01f, 0.01f, 0.01f), 0.95f));
        MeshKit.Ball(h, new Vector3(0.045f, 0.13f, 0.095f), Vector3.one * 0.03f, Mats.Get(new Color(0.01f, 0.01f, 0.01f), 0.95f));
        MeshKit.Box(h, new Vector3(0, 0.05f, 0.1f), new Vector3(0.1f, 0.025f, 0.02f), new Color(0.75f, 0.72f, 0.6f)); // оскал
        for (int side = 0; side < 2; side++)
        {
            MeshKit.Taper(b[side == 0 ? HumanRig.UArmL : HumanRig.UArmR], new Vector3(0, -s.armU * 0.5f, 0), 0.075f, 0.1f, s.armU + 0.02f, cloth);
            MeshKit.Taper(b[side == 0 ? HumanRig.LArmL : HumanRig.LArmR], new Vector3(0, -s.armL * 0.5f, 0), 0.055f, 0.07f, s.armL + 0.02f, sk.color);
            MeshKit.Box(b[side == 0 ? HumanRig.HandL : HumanRig.HandR], new Vector3(0, -0.06f, 0), new Vector3(0.06f, 0.13f, 0.03f), sk);
            MeshKit.Taper(b[side == 0 ? HumanRig.ULegL : HumanRig.ULegR], new Vector3(0, -s.legU * 0.5f, 0), 0.1f, 0.13f, s.legU, cloth);
            MeshKit.Taper(b[side == 0 ? HumanRig.LLegL : HumanRig.LLegR], new Vector3(0, -s.legL * 0.5f, 0), 0.08f, 0.1f, s.legL, cloth);
            MeshKit.Box(b[side == 0 ? HumanRig.FootL : HumanRig.FootR], new Vector3(0, -0.035f, 0.045f), new Vector3(0.09f, 0.06f, 0.22f), sk);
        }
    }

    protected override void Tick(float dt)
    {
        if (phased) return;
        if (Time.time > thinkT)
        {
            thinkT = Time.time + 0.5f;
            target = Battle.NearestEnemyUnit(this, true);
            if (target != null) GoTo(target.transform.position);
            if (target != null && Time.time > phaseCd && Vector3.Distance(target.transform.position, transform.position) > 22f)
            {
                StartCoroutine(PhaseTo(target));
                return;
            }
        }
        if (Time.time > gooT && vel.magnitude > 0.5f)
        {
            gooT = Time.time + 2.5f;
            Fx.GooPuddle(transform.position, 1.2f);
        }
        if (AgentOk) agent.speed = 2.4f;
        Vector3 look = target != null ? target.AimPoint - EyePos : transform.forward;
        Face(vel.sqrMagnitude > 0.1f ? vel : look, 160f, dt);
        Animate(look);
        if (target != null && attackStart < 0 && Vector3.Distance(target.transform.position, transform.position) < 1.7f && target.Targetable)
        {
            attackStart = Time.time; hitDone = false;
        }
        if (MeleeStep(0.8f, ref hitDone) && target != null && target.alive && Vector3.Distance(target.transform.position, transform.position) < 2.3f)
        {
            var victim = target;
            Fx.Goo(victim.AimPoint, Vector3.up, 1.5f);
            Sfx.Play("laugh106", transform.position, 0.8f, 1f, 50f);
            Slay(victim, DamageType.Corrosion, Vector3.down, 50f, "Карманное измерение");
            if (victim is Soldier vs) vs.CorrodeAndSink();
        }
    }

    // Проваливается сквозь пол и выходит рядом с целью
    IEnumerator PhaseTo(Unit t)
    {
        phased = true;
        phaseCd = Time.time + Random.Range(14f, 22f);
        if (AgentOk) agent.isStopped = true;
        Fx.GooPuddle(transform.position, 2.2f);
        Sfx.Play("laugh106", transform.position, 0.9f, 0.9f, 60f);
        if (agent != null) agent.enabled = false;
        Vector3 start = transform.position;
        float tm = 0;
        while (tm < 2.2f)
        {
            tm += Time.deltaTime;
            transform.position = start + Vector3.down * (tm / 2.2f) * 2.3f;
            Fx.Goo(start + Vector3.up * 0.1f, Vector3.up, 0.15f);
            vel = Vector3.zero; anim.velocity = Vector3.zero;
            yield return null;
        }
        yield return new WaitForSeconds(1.5f);
        if (t == null || !t.alive) t = Battle.NearestEnemyUnit(this, true);
        Vector3 dest = t != null ? t.transform.position - t.transform.forward * 3f : start;
        if (NavMesh.SamplePosition(dest, out var nh, 6f, NavMesh.AllAreas)) dest = nh.position;
        Fx.GooPuddle(dest, 2.4f);
        Sfx.Play("laugh106", dest, 1f, 0.85f, 70f);
        tm = 0;
        if (t != null) transform.rotation = Quaternion.LookRotation(Vector3.ProjectOnPlane(t.transform.position - dest, Vector3.up).normalized + transform.forward * 0.001f);
        while (tm < 2f)
        {
            tm += Time.deltaTime;
            transform.position = dest + Vector3.down * (1f - tm / 2f) * 2.3f;
            Fx.Goo(dest + Vector3.up * 0.1f, Vector3.up, 0.15f);
            yield return null;
        }
        transform.position = dest;
        EnsureAgent();
        if (AgentOk) agent.isStopped = false;
        phased = false;
    }

    public override void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Goo(point, -dir, 0.6f);
        if (Random.value < 0.4f) Sfx.Play("flesh", point, 0.4f, 0.6f, 25f);
    }
}

// ================= SCP-457 =================
public class Scp457 : HumanScp
{
    bool hitDone;
    Light glow;
    AudioSource fireSnd;
    float auraT;
    readonly List<Unit> near = new List<Unit>();

    public static Scp457 Create(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-457");
        go.transform.SetPositionAndRotation(pos, rot);
        var s = go.AddComponent<Scp457>();
        s.Init(ScpKind.S457, "SCP-457");
        s.armor = 0.5f;
        s.BuildBody(BodyShape.Soldier(1.05f), AnimStyle.Burning);
        s.SetupAgent(0.4f, 1.9f, 4f);
        var lg = new GameObject("glow");
        lg.transform.SetParent(s.rig.b[HumanRig.Chest], false);
        s.glow = lg.AddComponent<Light>();
        s.glow.type = LightType.Point; s.glow.color = new Color(1f, 0.5f, 0.15f); s.glow.range = 9f; s.glow.intensity = 3f;
        s.fireSnd = Sfx.Loop("fire", go.transform, 0.8f, 40f);
        return s;
    }

    protected override void Dress()
    {
        Color coal = new Color(0.08f, 0.06f, 0.05f);
        var hot = Mats.Glow(new Color(1f, 0.45f, 0.08f), 4f);
        var cm = Mats.Get(coal, 0.1f);
        var b = rig.b; var s = rig.shape;
        MeshKit.Box(b[HumanRig.Hips], new Vector3(0, -0.01f, 0), new Vector3(0.3f, 0.2f, 0.2f), cm);
        MeshKit.Box(b[HumanRig.Spine], new Vector3(0, 0.08f, 0), new Vector3(0.29f, 0.2f, 0.19f), cm);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.1f, 0), new Vector3(0.38f, 0.3f, 0.22f), cm);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0, 0.1f, 0.112f), new Vector3(0.05f, 0.25f, 0.01f), hot);
        MeshKit.Box(b[HumanRig.Chest], new Vector3(0.06f, 0.05f, 0.112f), new Vector3(0.18f, 0.02f, 0.01f), hot, new Vector3(0, 0, 30));
        MeshKit.Box(b[HumanRig.Spine], new Vector3(-0.05f, 0.08f, 0.097f), new Vector3(0.14f, 0.02f, 0.01f), hot, new Vector3(0, 0, -25));
        MeshKit.Cyl(b[HumanRig.Neck], new Vector3(0, 0.04f, 0), 0.1f, 0.11f, cm);
        var h = b[HumanRig.Head];
        MeshKit.Ball(h, new Vector3(0, 0.11f, 0.01f), new Vector3(0.2f, 0.25f, 0.22f), cm);
        MeshKit.Ball(h, new Vector3(-0.042f, 0.125f, 0.098f), Vector3.one * 0.035f, Mats.Glow(new Color(1f, 0.85f, 0.4f), 8f));
        MeshKit.Ball(h, new Vector3(0.042f, 0.125f, 0.098f), Vector3.one * 0.035f, Mats.Glow(new Color(1f, 0.85f, 0.4f), 8f));
        MeshKit.Box(h, new Vector3(0, 0.05f, 0.1f), new Vector3(0.08f, 0.03f, 0.02f), hot);
        for (int side = 0; side < 2; side++)
        {
            var ua = b[side == 0 ? HumanRig.UArmL : HumanRig.UArmR];
            var la = b[side == 0 ? HumanRig.LArmL : HumanRig.LArmR];
            MeshKit.Taper(ua, new Vector3(0, -s.armU * 0.5f, 0), 0.085f, 0.105f, s.armU + 0.02f, coal);
            MeshKit.Box(ua, new Vector3(0, -s.armU * 0.5f, 0.045f), new Vector3(0.015f, s.armU * 0.7f, 0.01f), hot);
            MeshKit.Taper(la, new Vector3(0, -s.armL * 0.5f, 0), 0.07f, 0.085f, s.armL + 0.02f, coal);
            MeshKit.Box(la, new Vector3(0, -s.armL * 0.5f, 0.037f), new Vector3(0.012f, s.armL * 0.6f, 0.01f), hot);
            MeshKit.Box(b[side == 0 ? HumanRig.HandL : HumanRig.HandR], new Vector3(0, -0.05f, 0), new Vector3(0.06f, 0.1f, 0.035f), hot);
            var ul = b[side == 0 ? HumanRig.ULegL : HumanRig.ULegR];
            MeshKit.Taper(ul, new Vector3(0, -s.legU * 0.5f, 0), 0.115f, 0.15f, s.legU + 0.03f, coal);
            MeshKit.Box(ul, new Vector3(0, -s.legU * 0.5f, 0.065f), new Vector3(0.015f, s.legU * 0.6f, 0.01f), hot);
            MeshKit.Taper(b[side == 0 ? HumanRig.LLegL : HumanRig.LLegR], new Vector3(0, -s.legL * 0.5f, 0), 0.09f, 0.118f, s.legL + 0.02f, coal);
            MeshKit.Box(b[side == 0 ? HumanRig.FootL : HumanRig.FootR], new Vector3(0, -0.035f, 0.045f), new Vector3(0.1f, 0.07f, 0.24f), cm);
        }
    }

    protected override void Tick(float dt)
    {
        // пламя по всему телу
        for (int i = 0; i < 3; i++)
        {
            var bone = rig.b[Random.Range(0, HumanRig.Count)];
            Fx.Fire(bone.position + Random.insideUnitSphere * 0.12f, Random.Range(0.25f, 0.5f), vel * 0.5f, 0.5f);
        }
        if (glow != null) glow.intensity = 2.5f + Mathf.PerlinNoise(Time.time * 8f, 0) * 2f;
        // аура жара
        if (Time.time > auraT)
        {
            auraT = Time.time + 0.25f;
            Combat.OverlapUnits(transform.position, 4.2f, near);
            foreach (var u in near)
            {
                if (!IsEnemy(u) || u.inVehicle) continue;
                u.TakeDamage(new DamageInfo { amount = 9f, type = DamageType.Fire, attacker = this, dir = (u.transform.position - transform.position).normalized, point = u.AimPoint, weapon = "Пламя SCP-457" });
                Fx.Fire(u.AimPoint + Random.insideUnitSphere * 0.2f, 0.4f);
                if (!u.alive && u is Soldier s) { s.Char(); s.StartCoroutine(Burn(s)); }
            }
        }
        if (Time.time > thinkT)
        {
            thinkT = Time.time + 0.4f;
            target = Battle.NearestEnemyUnit(this, true);
            if (target != null) GoTo(target.transform.position);
        }
        if (AgentOk) agent.speed = 4f;
        Vector3 look = target != null ? target.AimPoint - EyePos : transform.forward;
        Face(vel.sqrMagnitude > 0.1f ? vel : look, 240f, dt);
        Animate(look);
        if (target != null && attackStart < 0 && Vector3.Distance(target.transform.position, transform.position) < 1.8f && target.Targetable)
        { attackStart = Time.time; hitDone = false; }
        if (MeleeStep(0.6f, ref hitDone) && target != null && target.alive && Vector3.Distance(target.transform.position, transform.position) < 2.4f)
        {
            target.TakeDamage(new DamageInfo { amount = 45f, type = DamageType.Fire, attacker = this, dir = transform.forward, force = 400f, point = target.AimPoint, weapon = "Пламя SCP-457" });
            Fx.Explosion(target.AimPoint, 0.4f);
            if (!target.alive && target is Soldier s) { s.Char(); s.StartCoroutine(Burn(s)); }
        }
    }

    static IEnumerator Burn(Soldier s)
    {
        float t = 0;
        while (t < 8f && s != null)
        {
            t += Time.deltaTime;
            if (Random.value < 0.5f) Fx.Fire(s.rig.b[Random.Range(0, HumanRig.Count)].position, 0.4f);
            yield return null;
        }
    }

    public override void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Sparks(point, -dir, 6, 4f);
        Fx.Fire(point, 0.3f);
    }

    protected override void Die(DamageInfo d)
    {
        if (glow != null) glow.enabled = false;
        if (fireSnd != null) fireSnd.Stop();
        Fx.Smoke(transform.position + Vector3.up, 2.5f, new Color(0.15f, 0.15f, 0.15f, 0.7f), 5f, Vector3.up * 1.5f);
        base.Die(d);
    }
}
