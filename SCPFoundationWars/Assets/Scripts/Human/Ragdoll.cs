using System.Collections.Generic;
using UnityEngine;

// Физическое тело (тряпичная кукла). Пока юнит жив — все кости кинематические и служат хитбоксами.
// При смерти тело получает скорости, которые кости имели в анимации, и плавно "обмякает", а не замирает.
// Суставы ограничены реальными углами (шея, колени, локти), с проекцией — голова не выворачивается и не отрывается.
[DefaultExecutionOrder(200)]
public class Ragdoll : MonoBehaviour
{
    public class Part
    {
        public Transform t;
        public Rigidbody rb;
        public Collider col;
        public Hitbox hb;
        public CharacterJoint joint;
        public Vector3 prev, vel, angVel;
        public Quaternion prevRot;
    }

    public readonly List<Part> parts = new List<Part>();
    public bool active, frozen;
    public Unit owner;
    public float activatedAt;
    float calm;
    bool fellSound;
    public bool sinking;
    float sinkT;

    public static readonly List<Ragdoll> Corpses = new List<Ragdoll>();
    public static int MaxCorpses = 90;

    public Part Add(Transform t, Collider col, float mass, Part parent, float lowTwist, float highTwist, float swing1, float swing2, float hitMul, bool head = false)
    {
        var p = new Part { t = t, col = col };
        p.rb = t.gameObject.AddComponent<Rigidbody>();
        p.rb.mass = mass;
        p.rb.isKinematic = true;
        p.rb.useGravity = true;
        p.rb.drag = 0.08f;
        p.rb.angularDrag = 1.6f;
        p.rb.solverIterations = 14;
        p.rb.solverVelocityIterations = 6;
        p.rb.maxAngularVelocity = 25f;
        p.rb.maxDepenetrationVelocity = 2.5f;
        p.rb.sleepThreshold = 0.08f;
        p.rb.interpolation = RigidbodyInterpolation.None;
        t.gameObject.layer = Layers.Body;
        p.hb = t.gameObject.AddComponent<Hitbox>();
        p.hb.owner = owner;
        p.hb.mul = hitMul;
        p.hb.head = head;
        p.hb.rb = p.rb;
        if (parent != null)
        {
            var j = t.gameObject.AddComponent<CharacterJoint>();
            j.connectedBody = parent.rb;
            j.axis = Vector3.right;
            j.swingAxis = Vector3.forward;
            j.lowTwistLimit = new SoftJointLimit { limit = lowTwist };
            j.highTwistLimit = new SoftJointLimit { limit = highTwist };
            j.swing1Limit = new SoftJointLimit { limit = swing1 };
            j.swing2Limit = new SoftJointLimit { limit = swing2 };
            j.twistLimitSpring = new SoftJointLimitSpring { spring = 0, damper = 0 };
            j.enableProjection = true;
            j.projectionDistance = 0.02f;
            j.projectionAngle = 4f;
            j.enablePreprocessing = false;
            j.enableCollision = false;
            p.joint = j;
        }
        p.prev = t.position; p.prevRot = t.rotation;
        parts.Add(p);
        return p;
    }

    // Колайдеры деталей, у которых нет своего тела (кисть, стопа), прикрепляются к родительскому телу
    public static Collider ChildBox(Transform t, Vector3 center, Vector3 size, Unit owner, float mul)
    {
        var c = t.gameObject.AddComponent<BoxCollider>();
        c.center = center; c.size = size;
        t.gameObject.layer = Layers.Body;
        var hb = t.gameObject.AddComponent<Hitbox>();
        hb.owner = owner; hb.mul = mul;
        hb.rb = t.GetComponentInParent<Rigidbody>();
        return c;
    }

    public static CapsuleCollider Capsule(Transform t, Vector3 center, float r, float h, int dir = 1)
    {
        var c = t.gameObject.AddComponent<CapsuleCollider>();
        c.center = center; c.radius = r; c.height = h; c.direction = dir;
        return c;
    }

    public static BoxCollider BoxC(Transform t, Vector3 center, Vector3 size)
    {
        var c = t.gameObject.AddComponent<BoxCollider>();
        c.center = center; c.size = size;
        return c;
    }

    public static SphereCollider SphereC(Transform t, Vector3 center, float r)
    {
        var c = t.gameObject.AddComponent<SphereCollider>();
        c.center = center; c.radius = r;
        return c;
    }

    // ---------------- человек ----------------
    public static Ragdoll BuildHuman(HumanRig rig, Unit owner, float massMul = 1f)
    {
        var rd = rig.gameObject.AddComponent<Ragdoll>();
        rd.owner = owner;
        var s = rig.shape;
        var b = rig.b;
        float k = s.bulk * (rig.look != null ? rig.look.bulk : 1f);
        float tor = s.torso;

        // Ограничения суставов: знак "twist" — сгибание вокруг оси X кости.
        // Бедро: вперёд до 85°, назад 20°. Колено: только назад до 125°. Локоть: только вперёд до 130°.
        // Шея: наклон вперёд 40°, назад 30°, поворот ±45°, вбок ±25° — голова не "ломается".
        var hips = rd.Add(b[HumanRig.Hips], BoxC(b[HumanRig.Hips], new Vector3(0, 0.03f, 0), new Vector3(0.31f * k, 0.24f, 0.22f * k)), 12f * massMul, null, 0, 0, 0, 0, 0.9f);
        var chest = rd.Add(b[HumanRig.Chest], BoxC(b[HumanRig.Chest], new Vector3(0, 0.04f * tor, 0.0f), new Vector3(0.37f * k, 0.42f * tor, 0.24f * k)), 17f * massMul, hips, -30f, 15f, 18f, 20f, 1f);
        var head = rd.Add(b[HumanRig.Head], SphereC(b[HumanRig.Head], new Vector3(0, 0.11f * s.headSize, 0.01f), 0.125f * s.headSize), 5f * massMul, chest, -40f, 30f, 25f, 45f, 3.2f, true);

        var uaL = rd.Add(b[HumanRig.UArmL], Capsule(b[HumanRig.UArmL], new Vector3(0, -s.armU * 0.5f, 0), 0.055f * k, s.armU + 0.08f), 2.5f * massMul, chest, -45f, 100f, 75f, 30f, 0.7f);
        var laL = rd.Add(b[HumanRig.LArmL], Capsule(b[HumanRig.LArmL], new Vector3(0, -(s.armL + 0.06f) * 0.5f, 0), 0.045f * k, s.armL + 0.12f), 1.8f * massMul, uaL, 0f, 130f, 12f, 25f, 0.6f);
        var uaR = rd.Add(b[HumanRig.UArmR], Capsule(b[HumanRig.UArmR], new Vector3(0, -s.armU * 0.5f, 0), 0.055f * k, s.armU + 0.08f), 2.5f * massMul, chest, -45f, 100f, 75f, 30f, 0.7f);
        var laR = rd.Add(b[HumanRig.LArmR], Capsule(b[HumanRig.LArmR], new Vector3(0, -(s.armL + 0.06f) * 0.5f, 0), 0.045f * k, s.armL + 0.12f), 1.8f * massMul, uaR, 0f, 130f, 12f, 25f, 0.6f);

        var ulL = rd.Add(b[HumanRig.ULegL], Capsule(b[HumanRig.ULegL], new Vector3(0, -s.legU * 0.5f, 0), 0.075f * k, s.legU + 0.1f), 9f * massMul, hips, -20f, 85f, 30f, 15f, 0.75f);
        var llL = rd.Add(b[HumanRig.LLegL], Capsule(b[HumanRig.LLegL], new Vector3(0, -s.legL * 0.5f, 0), 0.06f * k, s.legL + 0.06f), 4.5f * massMul, ulL, -125f, 0f, 3f, 5f, 0.6f);
        var ulR = rd.Add(b[HumanRig.ULegR], Capsule(b[HumanRig.ULegR], new Vector3(0, -s.legU * 0.5f, 0), 0.075f * k, s.legU + 0.1f), 9f * massMul, hips, -20f, 85f, 30f, 15f, 0.75f);
        var llR = rd.Add(b[HumanRig.LLegR], Capsule(b[HumanRig.LLegR], new Vector3(0, -s.legL * 0.5f, 0), 0.06f * k, s.legL + 0.06f), 4.5f * massMul, ulR, -125f, 0f, 3f, 5f, 0.6f);

        ChildBox(b[HumanRig.FootL], new Vector3(0, -0.04f, 0.045f), new Vector3(0.1f * k, 0.08f, 0.24f), owner, 0.5f);
        ChildBox(b[HumanRig.FootR], new Vector3(0, -0.04f, 0.045f), new Vector3(0.1f * k, 0.08f, 0.24f), owner, 0.5f);

        // соседние части не толкают друг друга (меньше дрожания)
        rd.Ignore(head, uaL); rd.Ignore(head, uaR); rd.Ignore(hips, laL); rd.Ignore(hips, laR);
        rd.Ignore(chest, ulL); rd.Ignore(chest, ulR); rd.Ignore(hips, chest); rd.Ignore(head, chest);
        return rd;
    }

    public void Ignore(Part a, Part b)
    {
        if (a?.col != null && b?.col != null) Physics.IgnoreCollision(a.col, b.col);
    }

    public Part Find(Transform t)
    {
        foreach (var p in parts) if (p.t == t) return p;
        return null;
    }

    // Отслеживаем скорости костей из анимации
    void LateUpdate()
    {
        float dt = Time.deltaTime;
        if (!active)
        {
            if (dt <= 0) return;
            foreach (var p in parts)
            {
                Vector3 pos = p.t.position;
                p.vel = Vector3.Lerp(p.vel, (pos - p.prev) / dt, 0.6f);
                Quaternion dq = p.t.rotation * Quaternion.Inverse(p.prevRot);
                dq.ToAngleAxis(out float ang, out Vector3 axis);
                if (ang > 180) ang -= 360;
                if (float.IsNaN(axis.x) || float.IsInfinity(axis.x)) axis = Vector3.up;
                p.angVel = Vector3.Lerp(p.angVel, axis * (ang * Mathf.Deg2Rad / dt), 0.5f);
                p.prev = pos; p.prevRot = p.t.rotation;
            }
            return;
        }
        if (sinking)
        {
            sinkT += dt;
            transform.position += Vector3.down * dt * 0.35f;
            if (sinkT > 6f) { Corpses.Remove(this); Destroy(gameObject); }
            return;
        }
        if (frozen) return;
        // успокоение: когда тело лежит неподвижно — замораживаем (экономия физики и никакой дрожи)
        float maxV = 0;
        foreach (var p in parts) if (!p.rb.isKinematic) maxV = Mathf.Max(maxV, p.rb.velocity.sqrMagnitude + p.rb.angularVelocity.sqrMagnitude * 0.05f);
        if (!fellSound && Time.time - activatedAt > 0.25f && maxV < 6f)
        {
            fellSound = true;
            Sfx.Play("bodyfall", parts[0].t.position, 0.6f, Random.Range(0.85f, 1.1f), 30f);
        }
        if (maxV < 0.03f) calm += dt; else calm = 0;
        if (calm > 1.6f || Time.time - activatedAt > 25f) Freeze();
    }

    public void Activate(DamageInfo d, Vector3 extraVel = default(Vector3))
    {
        if (active) return;
        active = true;
        activatedAt = Time.time;
        Corpses.Add(this);
        foreach (var p in parts)
        {
            p.t.gameObject.layer = Layers.Corpse;
            p.rb.isKinematic = false;
            p.rb.interpolation = RigidbodyInterpolation.Interpolate;
            p.rb.collisionDetectionMode = CollisionDetectionMode.ContinuousSpeculative;
            Vector3 v = p.vel + extraVel;
            if (v.magnitude > 14f) v = v.normalized * 14f;
            p.rb.velocity = v;
            Vector3 av = p.angVel;
            if (av.magnitude > 10f) av = av.normalized * 10f;
            p.rb.angularVelocity = av;
            p.rb.WakeUp();
        }
        foreach (var c in GetComponentsInChildren<Collider>()) if (c.gameObject.layer == Layers.Body) c.gameObject.layer = Layers.Corpse;
        // импульс от попадания: в ту часть тела, куда попали
        if (d.force > 0)
        {
            Rigidbody target = d.hitbox != null && d.hitbox.rb != null ? d.hitbox.rb : parts.Count > 1 ? parts[1].rb : parts[0].rb;
            float f = Mathf.Min(d.force, 2500f);
            if (d.type == DamageType.Explosion)
            {
                foreach (var p in parts) p.rb.AddForce((d.dir + Vector3.up * 0.6f).normalized * f * 0.012f * p.rb.mass, ForceMode.Impulse);
            }
            else
            {
                target.AddForceAtPosition(d.dir * f * 0.12f, d.point, ForceMode.Impulse);
                if (parts.Count > 0) parts[0].rb.AddForce(d.dir * f * 0.03f, ForceMode.Impulse);
            }
        }
        TrimCorpses();
    }

    public void Freeze()
    {
        if (frozen) return;
        frozen = true;
        foreach (var p in parts)
        {
            p.rb.isKinematic = true;
            p.rb.interpolation = RigidbodyInterpolation.None;
        }
    }

    public void Wake()
    {
        if (!active) return;
        frozen = false;
        calm = 0;
        activatedAt = Time.time - 5f;
        foreach (var p in parts)
        {
            p.rb.isKinematic = false;
            p.rb.interpolation = RigidbodyInterpolation.Interpolate;
            p.rb.WakeUp();
        }
    }

    public void Hit(Rigidbody rb, Vector3 point, Vector3 impulse)
    {
        if (sinking) return;
        Wake();
        if (rb != null && !rb.isKinematic) rb.AddForceAtPosition(Vector3.ClampMagnitude(impulse * 0.08f, 25f), point, ForceMode.Impulse);
    }

    // Обратно в кинематику (для оживления SCP-049)
    public void Deactivate()
    {
        active = false;
        frozen = false;
        Corpses.Remove(this);
        foreach (var p in parts)
        {
            p.rb.isKinematic = true;
            p.rb.interpolation = RigidbodyInterpolation.None;
            p.t.gameObject.layer = Layers.Body;
            p.prev = p.t.position; p.prevRot = p.t.rotation;
            p.vel = Vector3.zero; p.angVel = Vector3.zero;
        }
        foreach (var c in GetComponentsInChildren<Collider>()) if (c.gameObject.layer == Layers.Corpse) c.gameObject.layer = Layers.Body;
    }

    public void Sink()
    {
        Freeze();
        sinking = true;
        foreach (var p in parts) if (p.col != null) p.col.enabled = false;
    }

    public Vector3 Center => parts.Count > 0 ? parts[0].t.position : transform.position;

    static void TrimCorpses()
    {
        Corpses.RemoveAll(c => c == null);
        while (Corpses.Count > MaxCorpses)
        {
            var old = Corpses[0];
            Corpses.RemoveAt(0);
            if (old != null) old.Sink();
        }
    }
}
