using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

// Четвероногие SCP (939, 682): свой скелет, процедурная походка рысью/галопом, хвост, челюсть и физическое тело.
public class QuadScp : ScpUnit
{
    // кости
    Transform pelvis, chest, neck, head, jaw;
    readonly Transform[] legU = new Transform[4], legL = new Transform[4], foot = new Transform[4];
    readonly List<Transform> tail = new List<Transform>();
    Ragdoll ragdoll;
    float H, bodyLen, la, lb;
    float phase, spd, jawOpen, lunge = -1f, chargeT = -1f;
    Vector3 chargeDir;
    float attackCd, roarT;
    readonly Quaternion[] legCur = new Quaternion[8];
    Quaternion pelvisCur = Quaternion.identity, chestCur = Quaternion.identity, headCur = Quaternion.identity;
    readonly List<Unit> near = new List<Unit>();
    readonly HashSet<Unit> trampled = new HashSet<Unit>();
    bool big;
    float regen;
    Vector3 lookDir = Vector3.forward;

    public override Vector3 LookDir => head != null ? head.forward : transform.forward;
    float lie;   // 0..1 — ослаблен и лежит

    // ---------------- SCP-939 ----------------
    public static QuadScp Create939(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-939");
        go.transform.SetPositionAndRotation(pos, rot);
        go.transform.localScale = Vector3.one * Random.Range(0.95f, 1.08f);
        var q = go.AddComponent<QuadScp>();
        q.Init(ScpKind.S939, "SCP-939");
        q.armor = 0.15f;
        q.threat = 2.5f;
        q.Build(0.95f, 1.15f, 0.52f, 0.5f, 0.4f, new Color(0.55f, 0.1f, 0.07f), new Color(0.3f, 0.04f, 0.03f), false);
        q.SetupAgent(0.55f, 1.2f, 9f, 25f);
        return q;
    }

    // ---------------- SCP-682 ----------------
    public static QuadScp Create682(Vector3 pos, Quaternion rot)
    {
        var go = new GameObject("SCP-682");
        go.transform.SetPositionAndRotation(pos, rot);
        go.transform.localScale = Vector3.one * 2.3f;
        var q = go.AddComponent<QuadScp>();
        q.Init(ScpKind.S682, "SCP-682");
        q.armor = 0.45f;
        q.threat = 6f;
        q.big = true;
        q.regen = 30f;
        q.Build(0.75f, 1.55f, 0.42f, 0.4f, 0.55f, new Color(0.25f, 0.27f, 0.15f), new Color(0.13f, 0.12f, 0.07f), true);
        q.SetupAgent(0.9f, 1.5f, 6f, 10f);
        return q;
    }

    Transform B(string n, Transform p, Vector3 lp) { var t = new GameObject(n).transform; t.SetParent(p, false); t.localPosition = lp; return t; }

    void Build(float height, float len, float a, float b, float w, Color skin, Color dark, bool reptile)
    {
        H = height; bodyLen = len; la = a; lb = b;
        var sk = Mats.Get(skin, reptile ? 0.35f : 0.55f);
        var dk = Mats.Get(dark, 0.3f);
        var teeth = Mats.Get(new Color(0.9f, 0.86f, 0.75f), 0.6f);
        pelvis = B("pelvis", transform, new Vector3(0, H, -len * 0.25f));
        chest = B("chest", pelvis, new Vector3(0, 0.05f, len * 0.6f));
        neck = B("neck", chest, new Vector3(0, 0.12f, len * 0.3f));
        head = B("head", neck, new Vector3(0, 0.08f, reptile ? 0.35f : 0.3f));
        jaw = B("jaw", head, new Vector3(0, -0.06f, 0.0f));

        // туловище
        MeshKit.Ball(pelvis, new Vector3(0, 0, 0.05f), new Vector3(w * 1.0f, w * 0.9f, len * 0.6f), sk);
        MeshKit.Ball(chest, new Vector3(0, 0, -0.05f), new Vector3(w * 1.15f, w * 1.05f, len * 0.65f), sk);
        MeshKit.Ball(chest, new Vector3(0, -0.12f * w, -0.1f), new Vector3(w * 0.9f, w * 0.7f, len * 0.6f), dk);
        // гребень / шипы
        for (int i = 0; i < 6; i++)
        {
            var parent = i < 3 ? pelvis : chest;
            float z = (i % 3) * 0.18f * len - 0.1f;
            MeshKit.Part(parent, MeshKit.Frustum(0.1f), dk, new Vector3(0, w * 0.45f, z), new Vector3(0.08f * w * 2, 0.18f * w * 2, 0.08f * w * 2), new Vector3(-20, 0, 0));
        }
        if (reptile)
            for (int i = 0; i < 10; i++)
                MeshKit.Box(i < 5 ? pelvis : chest, new Vector3(Random.Range(-w, w) * 0.4f, w * 0.38f, Random.Range(-0.3f, 0.3f) * len), new Vector3(0.12f, 0.06f, 0.14f) * w * 2.2f, dk, new Vector3(Random.Range(-20, 20), Random.Range(0, 90), Random.Range(-20, 20)));
        // шея
        MeshKit.Taper(neck, new Vector3(0, 0, 0.12f), w * 0.55f, w * 0.75f, 0.32f, skin, new Vector3(-80, 0, 0));
        // голова: длинная безглазая морда (939) или крокодилья (682)
        float hl = reptile ? 0.5f : 0.38f;
        MeshKit.Box(head, new Vector3(0, 0.02f, hl * 0.5f), new Vector3(w * 0.55f, w * 0.32f, hl), sk);
        MeshKit.Box(head, new Vector3(0, 0.08f, hl * 0.15f), new Vector3(w * 0.6f, w * 0.25f, hl * 0.5f), sk);
        if (reptile)
        {
            MeshKit.Ball(head, new Vector3(-w * 0.27f, 0.1f, hl * 0.3f), Vector3.one * 0.06f, Mats.Glow(new Color(1f, 0.7f, 0.1f), 2f));
            MeshKit.Ball(head, new Vector3(w * 0.27f, 0.1f, hl * 0.3f), Vector3.one * 0.06f, Mats.Glow(new Color(1f, 0.7f, 0.1f), 2f));
        }
        for (int i = 0; i < 7; i++)
        {
            float z = hl * (0.15f + i * 0.12f);
            MeshKit.Part(head, MeshKit.Frustum(0.1f), teeth, new Vector3(-w * 0.22f, -0.07f, z), new Vector3(0.03f, 0.07f, 0.03f), new Vector3(180, 0, 0));
            MeshKit.Part(head, MeshKit.Frustum(0.1f), teeth, new Vector3(w * 0.22f, -0.07f, z), new Vector3(0.03f, 0.07f, 0.03f), new Vector3(180, 0, 0));
        }
        MeshKit.Box(jaw, new Vector3(0, -0.04f, hl * 0.45f), new Vector3(w * 0.5f, w * 0.15f, hl * 0.9f), sk);
        MeshKit.Box(jaw, new Vector3(0, -0.01f, hl * 0.45f), new Vector3(w * 0.4f, 0.02f, hl * 0.8f), Mats.Get(new Color(0.4f, 0.05f, 0.05f), 0.7f));
        for (int i = 0; i < 6; i++)
        {
            float z = hl * (0.2f + i * 0.13f);
            MeshKit.Part(jaw, MeshKit.Frustum(0.1f), teeth, new Vector3(-w * 0.2f, 0.02f, z), new Vector3(0.025f, 0.06f, 0.025f));
            MeshKit.Part(jaw, MeshKit.Frustum(0.1f), teeth, new Vector3(w * 0.2f, 0.02f, z), new Vector3(0.025f, 0.06f, 0.025f));
        }
        // ноги: 0 — ЛП, 1 — ПП, 2 — ЛЗ, 3 — ПЗ
        for (int i = 0; i < 4; i++)
        {
            bool front = i < 2;
            float sx = (i % 2 == 0) ? -1 : 1;
            var parent = front ? chest : pelvis;
            legU[i] = B("legU" + i, parent, new Vector3(sx * w * 0.42f, -0.05f, front ? 0.05f : -0.05f));
            legL[i] = B("legL" + i, legU[i], new Vector3(0, -a, 0));
            foot[i] = B("foot" + i, legL[i], new Vector3(0, -b, 0));
            MeshKit.Taper(legU[i], new Vector3(0, -a * 0.5f, 0), w * 0.3f, w * 0.45f, a + 0.05f, skin);
            MeshKit.Taper(legL[i], new Vector3(0, -b * 0.5f, 0), w * 0.2f, w * 0.3f, b + 0.03f, skin);
            MeshKit.Box(foot[i], new Vector3(0, -0.02f, 0.06f), new Vector3(w * 0.35f, 0.06f, w * 0.5f), dk);
            for (int c = -1; c <= 1; c++)
                MeshKit.Part(foot[i], MeshKit.Frustum(0.1f), teeth, new Vector3(c * w * 0.1f, -0.03f, w * 0.3f), new Vector3(0.025f, 0.08f, 0.025f), new Vector3(100, 0, 0));
        }
        // хвост
        Transform tp = pelvis;
        int segs = reptile ? 5 : 3;
        for (int i = 0; i < segs; i++)
        {
            var t = B("tail" + i, tp, new Vector3(0, i == 0 ? 0.0f : 0, i == 0 ? -len * 0.3f : -0.3f));
            float d = w * 0.5f * (1f - i / (float)(segs + 1));
            MeshKit.Taper(t, new Vector3(0, 0, -0.15f), d, d * 0.7f, 0.34f, skin, new Vector3(-90, 0, 0));
            tail.Add(t);
            tp = t;
        }
        // объединяем меши
        var bones = new List<Transform> { pelvis, chest, neck, head, jaw };
        bones.AddRange(legU); bones.AddRange(legL); bones.AddRange(foot); bones.AddRange(tail);
        foreach (var bt in bones) MeshKit.CombineParts(bt);

        // физика и хитбоксы
        ragdoll = gameObject.AddComponent<Ragdoll>();
        ragdoll.owner = this;
        var pP = ragdoll.Add(pelvis, Ragdoll.BoxC(pelvis, new Vector3(0, 0, 0.05f), new Vector3(w, w * 0.85f, len * 0.6f)), 40f, null, 0, 0, 0, 0, 0.9f);
        var pC = ragdoll.Add(chest, Ragdoll.BoxC(chest, new Vector3(0, 0, -0.05f), new Vector3(w * 1.1f, w, len * 0.65f)), 50f, pP, -25f, 25f, 15f, 20f, 1f);
        var pH = ragdoll.Add(head, Ragdoll.BoxC(head, new Vector3(0, 0.02f, hl * 0.5f), new Vector3(w * 0.6f, w * 0.45f, hl)), 10f, pC, -35f, 35f, 30f, 40f, 2f, true);
        var neckCol = Ragdoll.Capsule(neck, new Vector3(0, 0, 0.12f), w * 0.3f, 0.4f, 2);
        neck.gameObject.layer = Layers.Body;
        var nhb = neck.gameObject.AddComponent<Hitbox>(); nhb.owner = this; nhb.mul = 1.5f; nhb.rb = pC.rb;
        for (int i = 0; i < 4; i++)
        {
            var parent = i < 2 ? pC : pP;
            var u = ragdoll.Add(legU[i], Ragdoll.Capsule(legU[i], new Vector3(0, -a * 0.5f, 0), w * 0.17f, a + 0.1f), 6f, parent, -50f, 50f, 20f, 10f, 0.6f);
            ragdoll.Add(legL[i], Ragdoll.Capsule(legL[i], new Vector3(0, -b * 0.5f, 0), w * 0.12f, b + 0.12f), 3f, u, -70f, 70f, 5f, 5f, 0.5f);
            ragdoll.Ignore(u, parent);
        }
        if (tail.Count > 0)
            ragdoll.Add(tail[0], Ragdoll.Capsule(tail[0], new Vector3(0, 0, -0.15f), w * 0.2f, 0.4f, 2), 5f, pP, -30f, 30f, 30f, 30f, 0.5f);
        ragdoll.Ignore(pH, pC);

        eye = B("eye", head, new Vector3(0, 0.08f, hl * 0.3f));
        chestPoint = chest;
        for (int i = 0; i < 8; i++) legCur[i] = Quaternion.identity;
    }

    public override void SetAnimVelocity(Vector3 v) { vel = v; }

    protected override void Tick(float dt)
    {
        // регенерация 682
        if (regen > 0 && hp < maxHp) hp = Mathf.Min(maxHp, hp + regen * dt);
        if (attackCd > 0) attackCd -= dt;

        if (Time.time > thinkT && chargeT < 0 && lunge < 0)
        {
            thinkT = Time.time + Random.Range(0.3f, 0.6f);
            target = Battle.NearestEnemyUnit(this, true);
            if (target != null) GoTo(target.transform.position);
            if (Random.value < 0.04f) Sfx.Play(big ? "roar" : "growl", transform.position, big ? 1f : 0.6f, big ? 0.8f : Random.Range(0.9f, 1.3f), big ? 200f : 60f);
        }
        if (big && Time.time > roarT && target != null)
        {
            roarT = Time.time + Random.Range(12f, 20f);
            Sfx.Play("roar", transform.position, 1f, 0.75f, 260f);
            Fx.AddShake(transform.position, 0.6f);
            jawOpen = 1f;
        }
        float dist = target != null ? Vector3.Distance(target.transform.position, transform.position) : 999f;
        float reach = big ? 4.5f : 1.9f;

        if (big)
        {
            // таран
            if (chargeT < 0 && target != null && dist > 10f && dist < 35f && attackCd <= 0 && Random.value < dt * 0.6f)
            {
                chargeT = 0;
                chargeDir = target.transform.position - transform.position; chargeDir.y = 0; chargeDir.Normalize();
                trampled.Clear();
                if (AgentOk) agent.isStopped = true;
                Sfx.Play("roar", transform.position, 1f, 0.9f, 260f);
            }
            if (chargeT >= 0)
            {
                chargeT += dt;
                float sp = chargeT < 0.5f ? 4f : 17f;
                Vector3 step = chargeDir * sp * dt;
                Vector3 np = transform.position + step;
                if (NavMesh.SamplePosition(np, out var nh, 2f, NavMesh.AllAreas) && AgentOk) agent.Move(step);
                vel = chargeDir * sp;
                Face(chargeDir, 300f, dt);
                Combat.OverlapUnits(transform.position + chargeDir * 2.5f, 3.2f, near);
                foreach (var u in near)
                {
                    if (!IsEnemy(u) || trampled.Contains(u) || u.inVehicle) continue;
                    trampled.Add(u);
                    Vector3 dir = ((u.transform.position - transform.position).normalized + chargeDir + Vector3.up * 0.9f).normalized;
                    u.TakeDamage(new DamageInfo { amount = 140f, type = DamageType.Crush, dir = dir, force = 2600f, attacker = this, point = u.AimPoint, weapon = "Таран SCP-682" });
                    if (u.isPlayer && u.alive && PlayerController.I != null) PlayerController.I.Knock(dir * 12f);
                    Fx.Blood(u.AimPoint, dir, 1.5f);
                    Sfx.Play("bodyfall", u.AimPoint, 1f, 0.7f, 60f);
                    Fx.AddShake(u.transform.position, 0.4f);
                }
                if (chargeT > 2.4f) { chargeT = -1; attackCd = 6f; if (AgentOk) agent.isStopped = false; }
            }
        }
        else
        {
            // прыжок-рывок 939
            if (lunge < 0 && target != null && dist < 7f && dist > 2.5f && attackCd <= 0 && target.Targetable)
            {
                lunge = 0;
                StartCoroutine(Lunge(target));
            }
        }

        // укус
        if (chargeT < 0 && lunge < 0 && target != null && dist < reach && attackCd <= 0 && target.Targetable)
        {
            attackCd = big ? 1.6f : 1.1f;
            jawOpen = 1f;
            StartCoroutine(Bite(target));
        }

        if (AgentOk && chargeT < 0) agent.speed = big ? 6.5f : (dist < 15f ? 9.5f : 7f);
        Vector3 look = target != null ? target.AimPoint - eye.position : transform.forward;
        if (chargeT < 0) Face(vel.sqrMagnitude > 0.2f ? vel : look, big ? 90f : 300f, dt);
        lookDir = Vector3.Slerp(lookDir, look.normalized, dt * 4f);
    }

    IEnumerator Bite(Unit t)
    {
        yield return new WaitForSeconds(0.18f);
        if (t == null || !t.alive || !alive) yield break;
        float reach = big ? 5.5f : 2.4f;
        if (Vector3.Distance(t.transform.position, transform.position) > reach) yield break;
        Vector3 dir = (t.AimPoint - eye.position).normalized;
        t.TakeDamage(new DamageInfo { amount = big ? 160f : 42f, type = DamageType.Melee, attacker = this, dir = dir + Vector3.up * 0.3f, force = big ? 1500f : 500f, point = t.AimPoint, weapon = displayName });
        Fx.Blood(t.AimPoint, dir, big ? 2.5f : 1.3f);
        Sfx.Play("flesh", t.AimPoint, 0.9f, big ? 0.6f : 0.9f, 40f);
        Sfx.Play("growl", transform.position, 0.6f, big ? 0.6f : 1.2f, 40f);
    }

    IEnumerator Lunge(Unit t)
    {
        if (AgentOk) agent.enabled = false;
        Vector3 a = transform.position;
        Vector3 b = t.transform.position - (t.transform.position - a).normalized * 1.2f;
        b.y = Battle.GroundHeight(b);
        Sfx.Play("growl", a, 0.8f, 1.4f, 40f);
        jawOpen = 1f;
        float tm = 0, dur = 0.45f;
        while (tm < dur)
        {
            tm += Time.deltaTime;
            float k = tm / dur;
            Vector3 p = Vector3.Lerp(a, b, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * 1.2f;
            vel = (p - transform.position) / Mathf.Max(0.001f, Time.deltaTime);
            transform.position = p;
            Face(b - a, 720f, Time.deltaTime);
            lunge = k;
            yield return null;
        }
        lunge = -1;
        EnsureAgent();
        if (t != null && t.alive && Vector3.Distance(t.transform.position, transform.position) < 2.6f)
        {
            Vector3 dir = (t.AimPoint - transform.position).normalized;
            t.TakeDamage(new DamageInfo { amount = 60f, type = DamageType.Melee, attacker = this, dir = dir, force = 900f, point = t.AimPoint, weapon = "SCP-939" });
            Fx.Blood(t.AimPoint, dir, 1.6f);
            Sfx.Play("flesh", t.AimPoint, 0.9f, 0.85f, 40f);
        }
        attackCd = 1.5f;
    }

    // ---------------- процедурная анимация ----------------
    void LateUpdate()
    {
        if (!alive || pelvis == null) return;
        float dt = Mathf.Min(Time.deltaTime, 0.05f);
        if (dt <= 0) return;
        lie = Mathf.MoveTowards(lie, subdued ? 1f : 0f, dt * 1.5f);
        float sc = transform.lossyScale.y;
        Vector3 lv = transform.InverseTransformDirection(vel);
        float raw = new Vector2(lv.x, lv.z).magnitude;
        spd = Mathf.Lerp(spd, raw, 1f - Mathf.Exp(-8f * dt));
        float gallop = Mathf.InverseLerp(5f * sc, 9f * sc, spd);
        float stride = Mathf.Lerp(1.3f, 2.6f, gallop) * (la + lb) / 0.9f * sc;
        phase += spd / Mathf.Max(0.2f, stride) * Mathf.PI * 2f * dt;
        float move = Mathf.Clamp01(spd / (0.8f * sc));
        float amp = Mathf.Lerp(25f, 45f, gallop) * move;
        float knee = Mathf.Lerp(30f, 70f, gallop) * move;
        // рысь: диагональные пары; галоп: передние и задние парами
        float[] offs = { 0f, Mathf.PI, Mathf.Lerp(Mathf.PI, 0.6f, gallop), Mathf.Lerp(0f, 0.6f + Mathf.PI * 0f, gallop) + Mathf.Lerp(0, Mathf.PI * 0.15f, gallop) };
        if (lunge >= 0) { amp = 0; knee = 0; }
        float k = 1f - Mathf.Exp(-18f * dt);
        for (int i = 0; i < 4; i++)
        {
            float ph = phase + offs[i];
            float s = Mathf.Sin(ph), c = Mathf.Cos(ph);
            bool front = i < 2;
            float ux = -s * amp;
            float lx = (front ? 1f : -1f) * (8f + Mathf.Max(0, c) * knee);
            if (lunge >= 0)
            {
                ux = front ? -60f : 50f;
                lx = front ? 20f : -30f;
            }
            if (chargeT >= 0 && chargeT < 0.5f) { ux = front ? 15f : -10f; lx = front ? 30f : -40f; }
            if (lie > 0.01f) { ux = Mathf.Lerp(ux, front ? -70f : 70f, lie); lx = Mathf.Lerp(lx, front ? 110f : -110f, lie); }
            legCur[i] = Quaternion.Slerp(legCur[i], Quaternion.Euler(ux, 0, 0), k);
            legCur[i + 4] = Quaternion.Slerp(legCur[i + 4], Quaternion.Euler(lx, 0, 0), k);
            legU[i].localRotation = legCur[i];
            legL[i].localRotation = legCur[i + 4];
            foot[i].localRotation = Quaternion.Euler(-(ux + lx) * 0.8f, 0, 0);
        }
        float bob = Mathf.Sin(phase * 2f) * 0.04f * move + Mathf.Sin(phase) * 0.05f * gallop;
        pelvis.localPosition = new Vector3(0, Mathf.Lerp(H + bob - (chargeT >= 0 && chargeT < 0.5f ? 0.12f : 0f), H * 0.38f, lie), -bodyLen * 0.25f);
        pelvisCur = Quaternion.Slerp(pelvisCur, Quaternion.Euler(Mathf.Sin(phase) * 5f * gallop, Mathf.Sin(phase) * 4f * move, Mathf.Cos(phase) * 3f * move), k);
        pelvis.localRotation = pelvisCur;
        chestCur = Quaternion.Slerp(chestCur, Quaternion.Euler(-Mathf.Sin(phase) * 7f * gallop + Mathf.Sin(Time.time * 2f) * 1.5f, -Mathf.Sin(phase) * 5f * move, 0), k);
        chest.localRotation = chestCur;
        // голова следит за целью
        Vector3 ld = transform.InverseTransformDirection(lookDir);
        float yaw = Mathf.Clamp(Mathf.Atan2(ld.x, ld.z) * Mathf.Rad2Deg, -50f, 50f);
        float pitch = Mathf.Clamp(-Mathf.Asin(Mathf.Clamp(ld.y, -1, 1)) * Mathf.Rad2Deg, -30f, 35f);
        headCur = Quaternion.Slerp(headCur, Quaternion.Euler(pitch * 0.5f + Mathf.Sin(phase * 2f) * 4f * move, yaw * 0.5f, 0), 1f - Mathf.Exp(-8f * dt));
        neck.localRotation = headCur;
        head.localRotation = headCur;
        jawOpen = Mathf.MoveTowards(jawOpen, 0, dt * 1.5f);
        jaw.localRotation = Quaternion.Euler(Mathf.Lerp(3f, 40f, jawOpen), 0, 0);
        for (int i = 0; i < tail.Count; i++)
            tail[i].localRotation = Quaternion.Euler(-3f + Mathf.Sin(Time.time * 2f - i) * 3f, Mathf.Sin(phase * 0.5f + Time.time * 1.5f - i * 0.7f) * (10f + 8f * move), 0);
    }

    protected override void OnHurt(DamageInfo d, float dmg)
    {
        if (Random.value < 0.2f) Sfx.Play("growl", transform.position, 0.5f, big ? 0.6f : 1.3f, 50f);
        // 939 бросается на обидчика
        if (d.attacker != null && IsEnemy(d.attacker) && Random.value < 0.4f) { target = d.attacker; thinkT = Time.time + 1f; GoTo(d.attacker.transform.position); }
    }

    protected override void Die(DamageInfo d)
    {
        StopAllCoroutines();
        if (agent != null) agent.enabled = false;
        ragdoll.Activate(d, vel * 0.5f);
        Fx.BloodPool(chest.position, big ? 4f : 1.5f);
        Sfx.Play(big ? "roar" : "growl", transform.position, 1f, big ? 0.5f : 0.7f, 120f);
        Battle.Message(displayName + " НЕЙТРАЛИЗОВАН", new Color(0.4f, 0.9f, 1f));
    }

    public override void CorpseHit(Hitbox hb, Vector3 point, Vector3 impulse) { ragdoll.Hit(hb.rb, point, impulse); }

    public override void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Blood(point, dir, big ? 1.4f : 1f, hb != null ? hb.transform : null);
        if (Random.value < 0.4f) Sfx.Play("flesh", point, 0.5f, big ? 0.6f : 0.9f, 30f);
    }
}
