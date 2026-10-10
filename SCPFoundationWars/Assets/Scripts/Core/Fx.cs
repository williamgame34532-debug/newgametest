using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Визуальные эффекты: частицы (искры, пыль, кровь, дым, огонь), трассеры, вспышки, декали, тряска камеры.
public class Fx : MonoBehaviour
{
    public static Fx I;
    public static float BloodLevel = 1f;   // 0 — без крови, 1 — норм, 2 — много
    public static int MaxDecals = 500;

    ParticleSystem sparks, dust, blood, bloodMist, smoke, fire, flash, debris, muzzleSmoke, embers, groundDust, darkGoo;
    readonly List<Tracer> tracers = new List<Tracer>();
    readonly Queue<GameObject> decals = new Queue<GameObject>();
    readonly List<Light> lights = new List<Light>();
    readonly List<float> lightLife = new List<float>();
    readonly List<Grow> growing = new List<Grow>();
    Material tracerMat, bloodDecal, holeDecal, scorchDecal, gooDecal;

    public static float shake;
    public static Vector3 ShakeOffset;

    class Tracer { public LineRenderer lr; public Vector3 a, b; public float t, len, speed; public bool on; }
    class Grow { public Transform tr; public float t, dur, size; }

    public static void Init()
    {
        if (I != null) return;
        var go = new GameObject("Fx");
        DontDestroyOnLoad(go);
        I = go.AddComponent<Fx>();
        I.Build();
    }

    // Очистка между боями
    public static void Clear()
    {
        if (I == null) return;
        while (I.decals.Count > 0) { var d = I.decals.Dequeue(); if (d != null) Destroy(d); }
        I.growing.Clear();
        foreach (var ps in I.GetComponentsInChildren<ParticleSystem>()) ps.Clear();
        foreach (var t in I.tracers) { t.on = false; t.lr.enabled = false; }
    }

    ParticleSystem MakePS(string name, Material mat, float gravity, int max, bool stretch = false, float drag = 0f, bool sizeGrow = false, bool fade = true)
    {
        var go = new GameObject(name);
        go.transform.SetParent(transform, false);
        var ps = go.AddComponent<ParticleSystem>();
        ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        var main = ps.main;
        main.loop = false;
        main.playOnAwake = false;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.gravityModifier = gravity;
        main.maxParticles = max;
        main.startLifetime = 1f;
        main.startSpeed = 0f;
        var em = ps.emission; em.enabled = false;
        var sh = ps.shape; sh.enabled = false;
        if (drag > 0)
        {
            var lim = ps.limitVelocityOverLifetime;
            lim.enabled = true;
            lim.dampen = drag;
            lim.limit = 0.5f;
        }
        if (fade)
        {
            var col = ps.colorOverLifetime;
            col.enabled = true;
            var g = new Gradient();
            g.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
                      new[] { new GradientAlphaKey(1, 0), new GradientAlphaKey(0.8f, 0.5f), new GradientAlphaKey(0, 1) });
            col.color = g;
        }
        if (sizeGrow)
        {
            var sz = ps.sizeOverLifetime;
            sz.enabled = true;
            sz.size = new ParticleSystem.MinMaxCurve(1f, AnimationCurve.EaseInOut(0, 0.4f, 1, 1.6f));
        }
        var r = go.GetComponent<ParticleSystemRenderer>();
        r.sharedMaterial = mat;
        r.renderMode = stretch ? ParticleSystemRenderMode.Stretch : ParticleSystemRenderMode.Billboard;
        if (stretch) { r.velocityScale = 0.04f; r.lengthScale = 1.5f; }
        r.shadowCastingMode = ShadowCastingMode.Off;
        r.receiveShadows = false;
        ps.Play();
        return ps;
    }

    void Build()
    {
        sparks = MakePS("sparks", Mats.Particle(2, true), 1.2f, 2000, true);
        dust = MakePS("dust", Mats.Particle(1), -0.02f, 1500, false, 0.08f, true);
        blood = MakePS("blood", Mats.Particle(0), 1.6f, 3000, true);
        bloodMist = MakePS("bloodmist", Mats.Particle(1), 0.05f, 1500, false, 0.15f, true);
        smoke = MakePS("smoke", Mats.Particle(1), -0.08f, 1500, false, 0.05f, true);
        fire = MakePS("fire", Mats.Particle(1, true), -0.35f, 2500, false, 0.05f, false);
        flash = MakePS("flash", Mats.Particle(0, true), 0f, 400);
        muzzleSmoke = MakePS("muzzlesmoke", Mats.Particle(1), -0.05f, 1000, false, 0.2f, true);
        embers = MakePS("embers", Mats.Particle(0, true), -0.15f, 1500);
        groundDust = MakePS("grounddust", Mats.Particle(1), 0f, 1500, false, 0.03f, true);
        darkGoo = MakePS("goo", Mats.Particle(0), 1.4f, 800, true);

        debris = MakePS("debris", Mats.Get(new Color(0.35f, 0.33f, 0.3f)), 2.2f, 800, false, 0f, false, false);
        var dr = debris.GetComponent<ParticleSystemRenderer>();
        dr.renderMode = ParticleSystemRenderMode.Mesh;
        dr.mesh = MeshKit.Cube;
        dr.shadowCastingMode = ShadowCastingMode.On;
        var dm = debris.main; dm.startRotation3D = true;
        var rot = debris.rotationOverLifetime; rot.enabled = true; rot.separateAxes = true;
        rot.x = new ParticleSystem.MinMaxCurve(-8, 8); rot.y = new ParticleSystem.MinMaxCurve(-8, 8); rot.z = new ParticleSystem.MinMaxCurve(-8, 8);
        var coll = debris.collision; coll.enabled = true; coll.type = ParticleSystemCollisionType.World; coll.bounce = 0.3f; coll.dampen = 0.4f; coll.lifetimeLoss = 0f;
        coll.collidesWith = 1 << 0; coll.quality = ParticleSystemCollisionQuality.Low;

        tracerMat = Mats.Particle(2, true);
        bloodDecal = Mats.Decal(Mats.BloodTex, new Color(0.38f, 0.02f, 0.02f, 0.95f));
        holeDecal = Mats.Decal(Mats.HoleTex, Color.white);
        scorchDecal = Mats.Decal(Mats.ScorchTex, Color.white);
        gooDecal = Mats.Decal(Mats.BloodTex, new Color(0.03f, 0.025f, 0.02f, 0.95f));

        for (int i = 0; i < 10; i++)
        {
            var lgo = new GameObject("flashLight");
            lgo.transform.SetParent(transform);
            var l = lgo.AddComponent<Light>();
            l.type = LightType.Point;
            l.enabled = false;
            l.shadows = LightShadows.None;
            lights.Add(l); lightLife.Add(0);
        }
    }

    // ---------------- эмиссия ----------------
    static void Emit(ParticleSystem ps, Vector3 pos, Vector3 vel, float size, float life, Color col)
    {
        var ep = new ParticleSystem.EmitParams
        {
            position = pos,
            velocity = vel,
            startSize = size,
            startLifetime = life,
            startColor = col,
            rotation = Random.Range(0f, 360f),
            applyShapeToPosition = false
        };
        ps.Emit(ep, 1);
    }

    static Vector3 Cone(Vector3 dir, float angle)
    {
        return Quaternion.Slerp(Quaternion.identity, Random.rotationUniform, angle / 180f) * dir;
    }

    public static void Sparks(Vector3 pos, Vector3 normal, int n = 10, float speed = 7f)
    {
        if (I == null) return;
        for (int i = 0; i < n; i++)
            Emit(I.sparks, pos, Cone(normal, 70) * speed * Random.Range(0.3f, 1.2f), Random.Range(0.02f, 0.05f), Random.Range(0.15f, 0.45f), new Color(1f, Random.Range(0.6f, 0.9f), 0.3f));
    }

    public static void Impact(Vector3 pos, Vector3 normal, Color surface, bool metal)
    {
        if (I == null) return;
        if (metal) Sparks(pos, normal, 8);
        for (int i = 0; i < 5; i++)
            Emit(I.dust, pos + normal * 0.05f, Cone(normal, 40) * Random.Range(0.5f, 2.5f), Random.Range(0.2f, 0.5f), Random.Range(0.6f, 1.4f), new Color(surface.r * 0.9f + 0.1f, surface.g * 0.9f + 0.1f, surface.b * 0.9f + 0.1f, 0.6f));
        if (!metal)
            for (int i = 0; i < 4; i++)
                Emit(I.debris, pos + normal * 0.05f, Cone(normal, 50) * Random.Range(2f, 5f), Random.Range(0.02f, 0.06f), Random.Range(0.8f, 1.6f), surface);
    }

    public static void Blood(Vector3 pos, Vector3 dir, float amount = 1f, Transform stickTo = null)
    {
        if (I == null || BloodLevel <= 0.01f) return;
        amount *= BloodLevel;
        int n = Mathf.RoundToInt(12 * amount);
        for (int i = 0; i < n; i++)
            Emit(I.blood, pos, (Cone(dir, 35) * Random.Range(1.5f, 6f) + Random.insideUnitSphere), Random.Range(0.03f, 0.08f), Random.Range(0.4f, 0.9f), new Color(Random.Range(0.35f, 0.55f), 0.01f, 0.01f, 1f));
        for (int i = 0; i < Mathf.CeilToInt(3 * amount); i++)
            Emit(I.bloodMist, pos, dir * Random.Range(0.3f, 1.5f) + Random.insideUnitSphere * 0.4f, Random.Range(0.25f, 0.5f), Random.Range(0.3f, 0.7f), new Color(0.45f, 0.02f, 0.02f, 0.6f));
        // брызги на стену/землю позади
        if (Physics.Raycast(pos, (dir + Vector3.down * 0.6f).normalized, out var hit, 4f, 1 << 0, QueryTriggerInteraction.Ignore))
            BloodSplat(hit.point, hit.normal, Random.Range(0.35f, 0.8f) * Mathf.Sqrt(amount), hit.collider.transform);
        if (stickTo != null && Random.value < 0.6f * amount)
            BloodSplat(pos, -dir, Random.Range(0.12f, 0.22f), stickTo);
    }

    public static void Goo(Vector3 pos, Vector3 dir, float amount = 1f)
    {
        if (I == null) return;
        for (int i = 0; i < 10 * amount; i++)
            Emit(I.darkGoo, pos, Cone(dir, 45) * Random.Range(1f, 4f), Random.Range(0.04f, 0.1f), Random.Range(0.4f, 0.9f), new Color(0.04f, 0.03f, 0.02f, 1f));
    }

    public static void MuzzleFlash(Vector3 pos, Vector3 dir, float size = 1f, bool suppressed = false)
    {
        if (I == null) return;
        if (!suppressed)
        {
            Emit(I.flash, pos + dir * 0.08f * size, Vector3.zero, 0.45f * size, 0.05f, new Color(1f, 0.75f, 0.35f));
            Emit(I.flash, pos + dir * 0.22f * size, dir * 2f, 0.3f * size, 0.04f, new Color(1f, 0.6f, 0.2f));
            Light(pos, new Color(1f, 0.7f, 0.35f), 3.5f, 7f, 0.05f);
        }
        for (int i = 0; i < 2; i++)
            Emit(I.muzzleSmoke, pos + dir * 0.1f, dir * Random.Range(0.5f, 1.5f) + Random.insideUnitSphere * 0.3f, Random.Range(0.15f, 0.3f), Random.Range(0.4f, 0.9f), new Color(0.8f, 0.8f, 0.8f, 0.25f));
    }

    public static void Explosion(Vector3 pos, float radius)
    {
        if (I == null) return;
        Emit(I.flash, pos, Vector3.zero, radius * 2.2f, 0.18f, new Color(1f, 0.85f, 0.5f));
        Light(pos, new Color(1f, 0.6f, 0.25f), 9f, radius * 5f, 0.35f);
        for (int i = 0; i < 30; i++)
            Emit(I.fire, pos + Random.insideUnitSphere * radius * 0.3f, Random.insideUnitSphere * radius * 2f + Vector3.up * 2f, Random.Range(0.8f, 1.8f) * radius * 0.4f, Random.Range(0.3f, 0.7f), new Color(1f, Random.Range(0.4f, 0.7f), 0.15f, 0.9f));
        for (int i = 0; i < 25; i++)
            Emit(I.smoke, pos + Random.insideUnitSphere * radius * 0.4f, Random.insideUnitSphere * 2.5f + Vector3.up * Random.Range(1f, 4f), Random.Range(1.5f, 3f) * radius * 0.35f, Random.Range(2.5f, 5f), new Color(0.18f, 0.17f, 0.16f, 0.75f));
        Sparks(pos, Vector3.up, 40, 16f);
        for (int i = 0; i < 18; i++)
            Emit(I.debris, pos + Vector3.up * 0.2f, (Random.insideUnitSphere + Vector3.up * 1.2f) * Random.Range(4f, 12f), Random.Range(0.05f, 0.18f), Random.Range(2f, 4f), new Color(0.3f, 0.27f, 0.22f));
        if (Physics.Raycast(pos + Vector3.up * 0.5f, Vector3.down, out var hit, radius + 1f, 1 << 0, QueryTriggerInteraction.Ignore))
            Decal(I.scorchDecal, hit.point, hit.normal, radius * 1.4f, hit.collider.transform);
        AddShake(pos, radius * 0.25f);
    }

    public static void Smoke(Vector3 pos, float size, Color c, float life = 3f, Vector3 vel = default(Vector3))
    {
        if (I == null) return;
        Emit(I.smoke, pos, vel + Random.insideUnitSphere * 0.3f, size, life, c);
    }

    public static void Fire(Vector3 pos, float size, Vector3 vel = default(Vector3), float life = 0.7f)
    {
        if (I == null) return;
        Emit(I.fire, pos, vel + Vector3.up * Random.Range(0.8f, 2f) + Random.insideUnitSphere * 0.3f, size * Random.Range(0.7f, 1.3f), life * Random.Range(0.7f, 1.2f), new Color(1f, Random.Range(0.35f, 0.65f), 0.1f, 0.85f));
        if (Random.value < 0.3f)
            Emit(I.embers, pos, Vector3.up * Random.Range(1f, 3f) + Random.insideUnitSphere, Random.Range(0.03f, 0.06f), Random.Range(0.8f, 1.6f), new Color(1f, 0.5f, 0.1f));
    }

    public static void GroundDust(Vector3 pos, Vector3 vel, float size, Color c)
    {
        if (I == null) return;
        Emit(I.groundDust, pos, vel, size, Random.Range(1.2f, 2.2f), c);
    }

    public static void Debris(Vector3 pos, Vector3 vel, float size, Color c, float life = 3f)
    {
        if (I == null) return;
        Emit(I.debris, pos, vel, size, life, c);
    }

    public static void Light(Vector3 pos, Color c, float intensity, float range, float life)
    {
        if (I == null) return;
        int best = 0; float bl = float.MaxValue;
        for (int i = 0; i < I.lights.Count; i++) if (I.lightLife[i] < bl) { bl = I.lightLife[i]; best = i; }
        var l = I.lights[best];
        l.transform.position = pos;
        l.color = c;
        l.intensity = intensity;
        l.range = range;
        l.enabled = true;
        I.lightLife[best] = life;
    }

    public static void TracerLine(Vector3 from, Vector3 to, Color c, float width = 0.035f)
    {
        if (I == null) return;
        Tracer t = null;
        foreach (var x in I.tracers) if (!x.on) { t = x; break; }
        if (t == null)
        {
            if (I.tracers.Count > 160) t = I.tracers[Random.Range(0, I.tracers.Count)];
            else
            {
                var go = new GameObject("tracer");
                go.transform.SetParent(I.transform);
                var lr = go.AddComponent<LineRenderer>();
                lr.sharedMaterial = I.tracerMat;
                lr.positionCount = 2;
                lr.shadowCastingMode = ShadowCastingMode.Off;
                lr.receiveShadows = false;
                lr.numCapVertices = 0;
                t = new Tracer { lr = lr };
                I.tracers.Add(t);
            }
        }
        t.a = from; t.b = to; t.t = 0; t.len = Vector3.Distance(from, to); t.speed = 420f; t.on = true;
        t.lr.enabled = true;
        t.lr.startWidth = width * 0.4f; t.lr.endWidth = width;
        t.lr.startColor = new Color(c.r, c.g, c.b, 0f); t.lr.endColor = c;
        t.lr.SetPosition(0, from); t.lr.SetPosition(1, from);
    }

    // ---------------- декали ----------------
    static GameObject Decal(Material m, Vector3 pos, Vector3 normal, float size, Transform parent)
    {
        if (I == null) return null;
        var go = new GameObject("decal");
        go.transform.position = pos + normal * 0.012f;
        go.transform.rotation = Quaternion.LookRotation(-normal) * Quaternion.Euler(0, 0, Random.Range(0f, 360f));
        go.transform.localScale = Vector3.one * size;
        // не прикрепляем к объектам с неравномерным масштабом — декаль исказится
        if (parent != null)
        {
            Vector3 ls = parent.lossyScale;
            if (ls.x > 0.001f && Mathf.Abs(ls.x - ls.y) < 0.01f && Mathf.Abs(ls.x - ls.z) < 0.01f) go.transform.SetParent(parent, true);
        }
        go.AddComponent<MeshFilter>().sharedMesh = MeshKit.Quad;
        var r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = m;
        r.shadowCastingMode = ShadowCastingMode.Off;
        I.decals.Enqueue(go);
        while (I.decals.Count > MaxDecals) { var d = I.decals.Dequeue(); if (d != null) Destroy(d); }
        return go;
    }

    public static void BloodSplat(Vector3 pos, Vector3 normal, float size, Transform parent = null)
    {
        if (I == null || BloodLevel <= 0.01f) return;
        Decal(I.bloodDecal, pos, normal, size * Mathf.Lerp(0.7f, 1.2f, BloodLevel / 2f), parent);
    }

    public static void BulletHole(Vector3 pos, Vector3 normal, Transform parent)
    {
        if (I == null) return;
        Decal(I.holeDecal, pos, normal, Random.Range(0.07f, 0.11f), parent);
    }

    public static void GooPuddle(Vector3 pos, float size)
    {
        if (I == null) return;
        var d = Decal(I.gooDecal, pos, Vector3.up, 0.1f, null);
        if (d != null) I.growing.Add(new Grow { tr = d.transform, dur = 1.5f, size = size });
    }

    // Лужа крови под трупом, растёт со временем
    public static void BloodPool(Vector3 pos, float size)
    {
        if (I == null || BloodLevel <= 0.01f) return;
        if (!Physics.Raycast(pos + Vector3.up * 0.5f, Vector3.down, out var hit, 2f, 1 << 0, QueryTriggerInteraction.Ignore)) return;
        var d = Decal(I.bloodDecal, hit.point, hit.normal, 0.1f, hit.collider.transform);
        if (d != null) I.growing.Add(new Grow { tr = d.transform, dur = Random.Range(6f, 12f), size = size * Mathf.Lerp(0.6f, 1.3f, BloodLevel / 2f) });
    }

    // ---------------- тряска ----------------
    public static void AddShake(Vector3 pos, float amount)
    {
        var cam = Camera.main;
        float d = cam != null ? Vector3.Distance(cam.transform.position, pos) : 0f;
        shake = Mathf.Max(shake, amount / (1f + d * 0.08f));
    }

    void Update()
    {
        float dt = Time.deltaTime;
        foreach (var t in tracers)
        {
            if (!t.on) continue;
            t.t += dt * t.speed;
            float head = Mathf.Min(t.t, t.len);
            float tail = Mathf.Max(0, t.t - 14f);
            if (tail >= t.len) { t.on = false; t.lr.enabled = false; continue; }
            Vector3 dir = (t.b - t.a) / Mathf.Max(0.001f, t.len);
            t.lr.SetPosition(0, t.a + dir * tail);
            t.lr.SetPosition(1, t.a + dir * head);
        }
        for (int i = 0; i < lights.Count; i++)
        {
            if (!lights[i].enabled) continue;
            lightLife[i] -= dt;
            lights[i].intensity *= Mathf.Exp(-dt * 12f);
            if (lightLife[i] <= 0) lights[i].enabled = false;
        }
        for (int i = growing.Count - 1; i >= 0; i--)
        {
            var g = growing[i];
            if (g.tr == null) { growing.RemoveAt(i); continue; }
            g.t += dt;
            float k = Mathf.Clamp01(g.t / g.dur);
            float s = Mathf.Lerp(0.1f, g.size, 1f - (1f - k) * (1f - k));
            var p = g.tr.parent;
            float ps = p != null ? Mathf.Max(0.001f, p.lossyScale.x) : 1f;
            g.tr.localScale = Vector3.one * s / ps;
            if (k >= 1) growing.RemoveAt(i);
        }
        shake = Mathf.MoveTowards(shake, 0, dt * 2.5f) * Mathf.Exp(-dt * 3f);
        float tt = Time.unscaledTime * 35f;
        ShakeOffset = new Vector3(Mathf.PerlinNoise(tt, 0) - 0.5f, Mathf.PerlinNoise(0, tt) - 0.5f, 0) * shake * 0.6f;
    }
}
