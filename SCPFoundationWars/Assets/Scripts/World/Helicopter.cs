using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

// Транспортный вертолёт: прилетает, гасит скорость (задирая нос), садится или зависает,
// высаживает отряд (прыжком из дверей или по канатам), улетает. Может быть сбит.
public class Helicopter : MonoBehaviour
{
    public static readonly List<Helicopter> Active = new List<Helicopter>();

    public Team team;
    public float hp = 900f, maxHp = 900f;
    public Vector3 velocity;
    public bool rope;
    public string label;
    public readonly List<Transform> seats = new List<Transform>();
    public readonly List<Soldier> passengers = new List<Soldier>();
    public PlayerController playerPassenger;
    public ScpContainer sling;
    public bool Done => phase == Phase.Outbound || phase == Phase.Dead || phase == Phase.Crash;
    public bool Unloaded { get; private set; }

    enum Phase { Waiting, Inbound, Approach, Descend, Unload, Climb, Outbound, Crash, Dead }
    Phase phase = Phase.Waiting;
    Transform rotor, tailRotor, rotorDisc;
    Vector3 entry, lz, exit, approachDir;
    float groundY, hoverH, startTime;
    float rotorSpeed = 1f;
    Vector3 accelSm;
    float yaw;
    AudioSource rotorSnd;
    LineRenderer[] ropeLines;
    LineRenderer cable;
    Unit lastAttacker;
    float crashSpin;
    readonly List<Collider> hull = new List<Collider>();
    bool ropesOut;

    static Material textMat;

    // Материал для 3D-текста, который не просвечивает сквозь стены
    public static Material TextMat(Font f)
    {
        if (textMat != null) return textMat;
        var sh = Shader.Find("SCP/WorldText");
        if (sh == null) return f.material;
        textMat = new Material(sh) { mainTexture = f.material.mainTexture };
        return textMat;
    }

    public static Font UIFont()
    {
        Font f = null;
        try { f = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); } catch { }
        if (f == null) try { f = Resources.GetBuiltinResource<Font>("Arial.ttf"); } catch { }
        return f;
    }

    // ---------------- модель ----------------
    public static Helicopter Create(Team team, string label, Color body, Color stripe, int seatCount, bool rope)
    {
        var go = new GameObject("Heli " + label);
        var h = go.AddComponent<Helicopter>();
        h.team = team; h.label = label; h.rope = rope;
        var t = go.transform;
        Color dark = new Color(0.06f, 0.06f, 0.07f), glassC = new Color(0.1f, 0.15f, 0.2f, 0.55f);
        var bodyMat = Mats.Get(body, 0.35f, 0.2f);

        // кабина и фюзеляж
        MeshKit.Box(t, new Vector3(0, -0.08f, 0), new Vector3(2.5f, 0.16f, 4.6f), Mats.Get(new Color(0.15f, 0.15f, 0.15f)));
        MeshKit.Box(t, new Vector3(0, 2.05f, 0), new Vector3(2.5f, 0.2f, 4.8f), bodyMat);
        MeshKit.Box(t, new Vector3(0, -0.55f, 0.3f), new Vector3(2.3f, 0.8f, 5.4f), bodyMat);
        MeshKit.Box(t, new Vector3(0, 1.0f, -2.35f), new Vector3(2.5f, 2.3f, 0.2f), bodyMat);
        MeshKit.Ball(t, new Vector3(0, 0.75f, 3.15f), new Vector3(2.45f, 2.6f, 3.6f), bodyMat);
        MeshKit.Ball(t, new Vector3(0, 1.15f, 3.75f), new Vector3(2.1f, 1.7f, 2.6f), Mats.Glass(glassC, 0.95f));
        MeshKit.Box(t, new Vector3(0, 1.0f, 2.3f), new Vector3(2.5f, 2.3f, 0.15f), bodyMat);
        foreach (float sx in new[] { -1.18f, 1.18f })
            foreach (float sz in new[] { -2.25f, 2.2f })
                MeshKit.Box(t, new Vector3(sx, 1f, sz), new Vector3(0.14f, 2.1f, 0.18f), bodyMat);
        // сдвинутые назад двери
        MeshKit.Box(t, new Vector3(-1.3f, 1f, -2.9f), new Vector3(0.08f, 1.9f, 1.6f), bodyMat);
        MeshKit.Box(t, new Vector3(1.3f, 1f, -2.9f), new Vector3(0.08f, 1.9f, 1.6f), bodyMat);
        MeshKit.Box(t, new Vector3(-1.32f, 1.35f, -2.9f), new Vector3(0.02f, 0.5f, 0.6f), Mats.Glass(glassC));
        MeshKit.Box(t, new Vector3(1.32f, 1.35f, -2.9f), new Vector3(0.02f, 0.5f, 0.6f), Mats.Glass(glassC));
        // полосы и надписи
        MeshKit.Box(t, new Vector3(0, -0.3f, 0.3f), new Vector3(2.33f, 0.25f, 5.42f), Mats.Get(stripe, 0.4f));
        MeshKit.Box(t, new Vector3(0, 2.16f, 0), new Vector3(0.5f, 0.02f, 4.82f), Mats.Get(stripe, 0.4f));
        // двигатель
        MeshKit.Box(t, new Vector3(0, 2.55f, -0.6f), new Vector3(1.7f, 0.85f, 3.8f), bodyMat);
        MeshKit.Cyl(t, new Vector3(-0.6f, 2.6f, -2.6f), 0.45f, 0.6f, dark, new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(0.6f, 2.6f, -2.6f), 0.45f, 0.6f, dark, new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(-0.6f, 2.6f, 1.2f), 0.5f, 0.3f, dark, new Vector3(90, 0, 0));
        MeshKit.Cyl(t, new Vector3(0.6f, 2.6f, 1.2f), 0.5f, 0.3f, dark, new Vector3(90, 0, 0));
        // хвостовая балка
        MeshKit.Part(t, MeshKit.Frustum(0.35f), bodyMat, new Vector3(0, 1.45f, -6.2f), new Vector3(1.3f, 7.6f, 1.2f), new Vector3(-90, 0, 0));
        MeshKit.Box(t, new Vector3(0, 2.6f, -9.7f), new Vector3(0.18f, 2.4f, 1.3f), bodyMat, new Vector3(-18, 0, 0));
        MeshKit.Box(t, new Vector3(0, 1.4f, -9.4f), new Vector3(3.2f, 0.1f, 0.7f), bodyMat);
        MeshKit.Box(t, new Vector3(0, 3.3f, -10.05f), new Vector3(0.2f, 0.25f, 0.5f), Mats.Get(stripe, 0.4f), new Vector3(-18, 0, 0));
        // шасси (полозья)
        foreach (float sx in new[] { -1.25f, 1.25f })
        {
            MeshKit.Cyl(t, new Vector3(sx, -1.15f, 0.3f), 0.12f, 5f, dark, new Vector3(90, 0, 0));
            MeshKit.Cyl(t, new Vector3(sx * 0.9f, -0.95f, 1.6f), 0.1f, 0.6f, dark, new Vector3(0, 0, sx > 0 ? -25 : 25));
            MeshKit.Cyl(t, new Vector3(sx * 0.9f, -0.95f, -1.0f), 0.1f, 0.6f, dark, new Vector3(0, 0, sx > 0 ? -25 : 25));
        }
        // сиденья вдоль бортов (лицом к дверям)
        int perSide = Mathf.CeilToInt(seatCount / 2f);
        float span = Mathf.Min(4f, perSide * 0.58f);
        for (int i = 0; i < seatCount; i++)
        {
            int side = i % 2;
            int k = i / 2;
            float z = -span * 0.5f + (k + 0.5f) * span / perSide;
            float sx = side == 0 ? -0.45f : 0.45f;
            var seat = new GameObject("seat" + i).transform;
            seat.SetParent(t, false);
            seat.localPosition = new Vector3(sx, 0.02f, z);
            seat.localRotation = Quaternion.Euler(0, side == 0 ? -90 : 90, 0);
            h.seats.Add(seat);
        }
        MeshKit.Box(t, new Vector3(-0.32f, 0.38f, 0), new Vector3(0.4f, 0.08f, span + 0.2f), Mats.Get(new Color(0.2f, 0.2f, 0.18f)));
        MeshKit.Box(t, new Vector3(0.32f, 0.38f, 0), new Vector3(0.4f, 0.08f, span + 0.2f), Mats.Get(new Color(0.2f, 0.2f, 0.18f)));
        MeshKit.Box(t, new Vector3(0, 0.9f, 0), new Vector3(0.18f, 1f, span + 0.2f), Mats.Get(new Color(0.18f, 0.18f, 0.16f)));
        // огни
        MeshKit.Ball(t, new Vector3(-1.3f, 0.2f, 2.2f), Vector3.one * 0.12f, Mats.Glow(Color.red, 4f));
        MeshKit.Ball(t, new Vector3(1.3f, 0.2f, 2.2f), Vector3.one * 0.12f, Mats.Glow(Color.green, 4f));
        MeshKit.Ball(t, new Vector3(0, 3.0f, -9.8f), Vector3.one * 0.12f, Mats.Glow(Color.white, 6f));
        MeshKit.CombineParts(t);

        // надписи на бортах
        var font = UIFont();
        if (font != null)
        {
            foreach (int sd in new[] { -1, 1 })
            {
                var tg = new GameObject("label");
                tg.transform.SetParent(t, false);
                tg.transform.localPosition = new Vector3(sd * 1.17f, -0.32f, -0.8f);
                tg.transform.localRotation = Quaternion.Euler(0, sd > 0 ? -90 : 90, 0);
                tg.transform.localScale = Vector3.one * 0.06f;
                var tm = tg.AddComponent<TextMesh>();
                tm.font = font;
                tm.text = label;
                tm.fontSize = 48;
                tm.characterSize = 1f;
                tm.anchor = TextAnchor.MiddleCenter;
                tm.color = team == Team.Foundation ? Color.white : new Color(0.85f, 0.95f, 0.8f);
                tg.GetComponent<MeshRenderer>().sharedMaterial = TextMat(font);
            }
        }

        // несущий винт
        h.rotor = new GameObject("rotor").transform;
        h.rotor.SetParent(t, false);
        h.rotor.localPosition = new Vector3(0, 3.15f, 0.1f);
        MeshKit.Cyl(h.rotor, new Vector3(0, -0.15f, 0), 0.3f, 0.35f, dark);
        MeshKit.Cyl(h.rotor, Vector3.zero, 0.6f, 0.12f, dark);
        for (int i = 0; i < 4; i++)
        {
            var bl = new GameObject("p").transform;
            bl.SetParent(h.rotor, false);
            bl.localRotation = Quaternion.Euler(0, i * 90, 0);
            MeshKit.Box(bl, new Vector3(0, 0, 4.1f), new Vector3(0.55f, 0.05f, 7.6f), Mats.Get(new Color(0.08f, 0.08f, 0.08f)), new Vector3(0, 0, 4));
        }
        MeshKit.CombineParts(h.rotor);
        var disc = MeshKit.Cyl(h.rotor, new Vector3(0, 0.02f, 0), 16f, 0.01f, Mats.Glass(new Color(0.05f, 0.05f, 0.05f, 0.18f), 0.2f));
        h.rotorDisc = disc.transform;
        disc.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

        h.tailRotor = new GameObject("tailRotor").transform;
        h.tailRotor.SetParent(t, false);
        h.tailRotor.localPosition = new Vector3(0.22f, 2.85f, -10.15f);
        MeshKit.Box(h.tailRotor, new Vector3(0, 0, 0), new Vector3(0.05f, 2.3f, 0.2f), Mats.Get(dark));
        MeshKit.Box(h.tailRotor, new Vector3(0, 0, 0), new Vector3(0.05f, 0.2f, 2.3f), Mats.Get(dark));
        MeshKit.CombineParts(h.tailRotor);

        // коллайдеры корпуса (кинематика)
        var rb = go.AddComponent<Rigidbody>();
        rb.isKinematic = true;
        h.hull.Add(Ragdoll.BoxC(t, new Vector3(0, 0.6f, 0.4f), new Vector3(2.5f, 2.6f, 7.4f)));
        var tailCol = new GameObject("tailCol");
        tailCol.transform.SetParent(t, false);
        h.hull.Add(Ragdoll.BoxC(tailCol.transform, new Vector3(0, 1.6f, -6.8f), new Vector3(1f, 1.4f, 6.5f)));
        // пол кабины не должен блокировать линии прицеливания пассажиров? — кабина открыта по бокам
        MeshKit.SetLayer(go, Layers.Vehicle);

        h.rotorSnd = Sfx.Loop("rotor", t, 1f, 260f);
        h.maxHp = h.hp = team == Team.SCP ? 1400f : 900f;
        Active.Add(h);
        return h;
    }

    void OnDestroy() { Active.Remove(this); }

    // ---------------- полёт ----------------
    public void Launch(Vector3 entry, Vector3 lz, Vector3 exit, float delay)
    {
        this.entry = entry; this.lz = lz; this.exit = exit;
        approachDir = lz - entry; approachDir.y = 0; approachDir.Normalize();
        groundY = Battle.GroundHeight(lz);
        hoverH = sling != null ? 9f + sling.height : rope ? 9.5f : 1.2f;
        transform.position = entry;
        yaw = Mathf.Atan2(approachDir.x, approachDir.z) * Mathf.Rad2Deg;
        transform.rotation = Quaternion.Euler(0, yaw, 0);
        velocity = approachDir * 40f;
        startTime = Time.time + delay;
        phase = delay > 0 ? Phase.Waiting : Phase.Inbound;
    }

    void Fly(Vector3 target, float maxSpeed, float accel, float dt, bool holdHeading)
    {
        Vector3 to = target - transform.position;
        float dist = to.magnitude;
        float want = Mathf.Min(maxSpeed, Mathf.Sqrt(2f * accel * dist) * 0.85f);
        Vector3 desired = dist > 0.01f ? to / dist * want : Vector3.zero;
        Vector3 prev = velocity;
        velocity = Vector3.MoveTowards(velocity, desired, accel * dt);
        transform.position += velocity * dt;
        Vector3 acc = (velocity - prev) / Mathf.Max(0.0001f, dt);
        accelSm = Vector3.Lerp(accelSm, acc, 1f - Mathf.Exp(-4f * dt));
        Orient(dt, holdHeading);
    }

    void Orient(float dt, bool holdHeading)
    {
        Vector3 hv = new Vector3(velocity.x, 0, velocity.z);
        if (!holdHeading && hv.magnitude > 4f)
        {
            float targetYaw = Mathf.Atan2(hv.x, hv.z) * Mathf.Rad2Deg;
            yaw = Mathf.MoveTowardsAngle(yaw, targetYaw, 50f * dt);
        }
        else if (holdHeading)
        {
            float targetYaw = Mathf.Atan2(approachDir.x, approachDir.z) * Mathf.Rad2Deg;
            yaw = Mathf.MoveTowardsAngle(yaw, targetYaw, 30f * dt);
        }
        Quaternion yq = Quaternion.Euler(0, yaw, 0);
        Vector3 fwd = yq * Vector3.forward, right = yq * Vector3.right;
        float pitch = Mathf.Clamp(Vector3.Dot(accelSm, fwd) * 2.2f + Vector3.Dot(velocity, fwd) * 0.22f, -22f, 22f);
        float roll = Mathf.Clamp(-Vector3.Dot(accelSm, right) * 2.5f - Vector3.Dot(velocity, right) * 0.3f, -28f, 28f);
        float bob = phase == Phase.Unload ? Mathf.Sin(Time.time * 1.3f) * 1.2f : 0f;
        Quaternion target = Quaternion.Euler(pitch + bob * 0.5f, yaw, roll + bob);
        transform.rotation = Quaternion.Slerp(transform.rotation, target, 1f - Mathf.Exp(-3.5f * dt));
    }

    void Update()
    {
        float dt = Time.deltaTime;
        if (dt <= 0) return;
        // винты
        float targetRotor = phase == Phase.Dead ? 0f : phase == Phase.Crash ? 0.6f : 1f;
        rotorSpeed = Mathf.MoveTowards(rotorSpeed, targetRotor, dt * 0.4f);
        if (rotor != null) rotor.Rotate(0, 1150f * rotorSpeed * dt, 0, Space.Self);
        if (tailRotor != null) tailRotor.Rotate(2400f * rotorSpeed * dt, 0, 0, Space.Self);
        if (rotorDisc != null) rotorDisc.gameObject.SetActive(rotorSpeed > 0.5f);
        if (rotorSnd != null) { rotorSnd.pitch = (0.6f + 0.4f * rotorSpeed) * Time.timeScale; rotorSnd.volume = rotorSpeed * Sfx.Volume; }

        float agl = transform.position.y - Battle.GroundHeight(transform.position);
        // пыль от винта
        if (rotorSpeed > 0.5f && agl < 20f && phase != Phase.Dead)
        {
            Vector3 g = new Vector3(transform.position.x, Battle.GroundHeight(transform.position) + 0.3f, transform.position.z);
            int n = Mathf.RoundToInt((1f - agl / 20f) * 6f);
            for (int i = 0; i < n; i++)
            {
                float a = Random.Range(0f, Mathf.PI * 2f);
                Vector3 dir = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                Fx.GroundDust(g + dir * Random.Range(1f, 4f), dir * Random.Range(6f, 12f) + Vector3.up * 0.5f, Random.Range(1.5f, 3f), Battle.DustColor);
            }
        }

        switch (phase)
        {
            case Phase.Waiting:
                if (Time.time >= startTime) phase = Phase.Inbound;
                break;
            case Phase.Inbound:
            {
                Vector3 ap = lz - approachDir * 70f + Vector3.up * (groundY + 32f - lz.y);
                Fly(ap, 48f, 9f, dt, false);
                if ((ap - transform.position).magnitude < 25f) phase = Phase.Approach;
                break;
            }
            case Phase.Approach:
            {
                Vector3 hp = new Vector3(lz.x, groundY + Mathf.Max(hoverH, 12f), lz.z);
                Fly(hp, 20f, 6f, dt, false);
                if ((hp - transform.position).magnitude < 1.5f && velocity.magnitude < 2f) phase = Phase.Descend;
                break;
            }
            case Phase.Descend:
            {
                Vector3 hp = new Vector3(lz.x, groundY + hoverH, lz.z);
                Fly(hp, 4.5f, 3f, dt, true);
                if ((hp - transform.position).magnitude < 0.25f)
                {
                    phase = Phase.Unload;
                    StartCoroutine(UnloadRoutine());
                }
                break;
            }
            case Phase.Unload:
            {
                Vector3 hp = new Vector3(lz.x, groundY + hoverH, lz.z);
                Fly(hp, 2f, 3f, dt, true);
                break;
            }
            case Phase.Climb:
            {
                Vector3 cp = new Vector3(lz.x, groundY + 45f, lz.z) + approachDir * 15f;
                Fly(cp, 12f, 5f, dt, false);
                if (transform.position.y > groundY + 30f) phase = Phase.Outbound;
                break;
            }
            case Phase.Outbound:
                Fly(exit, 55f, 8f, dt, false);
                if ((exit - transform.position).magnitude < 30f) Destroy(gameObject);
                break;
            case Phase.Crash:
                CrashUpdate(dt, agl);
                break;
        }
        if (ropesOut) UpdateRopes();
        if (sling != null && cable != null)
        {
            cable.SetPosition(0, transform.TransformPoint(new Vector3(0, -0.6f, 0)));
            cable.SetPosition(1, sling.transform.position + Vector3.up * sling.height);
        }
        if (sling != null && sling.attached) sling.FollowHeli(this, dt);
    }

    IEnumerator UnloadRoutine()
    {
        yield return new WaitForSeconds(0.4f);
        Vector3 groundCenter = new Vector3(lz.x, groundY, lz.z);
        if (sling != null)
        {
            // опускаем контейнер
            sling.Release(groundCenter);
            if (cable != null) Destroy(cable.gameObject, 0.1f);
            yield return new WaitForSeconds(1f);
        }
        if (rope && passengers.Count > 0)
        {
            DeployRopes(true);
            yield return new WaitForSeconds(0.6f);
        }

        // игрок выходит первым
        if (playerPassenger != null)
        {
            var pp = playerPassenger;
            playerPassenger = null;
            Vector3 seatW = pp.transform.position;
            Vector3 outward = transform.right * (transform.InverseTransformPoint(seatW).x >= 0 ? 1 : -1);
            outward.y = 0; outward.Normalize();
            Vector3 g = groundCenter + outward * 3.5f;
            g.y = Battle.GroundHeight(g);
            pp.ExitHeli(this, transform.TransformPoint(new Vector3(Mathf.Sign(transform.InverseTransformPoint(seatW).x) * 1.25f, 0.1f, transform.InverseTransformPoint(seatW).z)), g, rope ? RopeTop(outward) : (Vector3?)null);
            yield return new WaitForSeconds(rope ? 1.4f : 0.5f);
        }

        int ropeBusyL = 0, ropeBusyR = 0;
        var list = new List<Soldier>(passengers);
        for (int i = 0; i < list.Count; i++)
        {
            var s = list[i];
            if (s == null || !s.alive || phase == Phase.Crash) continue;
            Vector3 local = transform.InverseTransformPoint(s.transform.position);
            float side = local.x >= 0 ? 1 : -1;
            Vector3 outward = transform.right * side; outward.y = 0; outward.Normalize();
            Vector3 door = transform.TransformPoint(new Vector3(side * 1.25f, 0.05f, Mathf.Clamp(local.z, -1.5f, 1.5f)));
            Vector3 g = groundCenter + outward * (rope ? 2.2f : 3.2f) + transform.forward * Mathf.Clamp(local.z, -1.5f, 1.5f);
            g.y = Battle.GroundHeight(g);
            if (rope)
            {
                Vector3 top = RopeTop(outward);
                Vector3 rg = new Vector3(top.x, Battle.GroundHeight(top), top.z);
                bool left = side < 0;
                // ждём, пока канат освободится
                float wait = 0;
                while ((left ? ropeBusyL : ropeBusyR) > 0 && wait < 3f) { wait += Time.deltaTime; yield return null; }
                if (left) ropeBusyL++; else ropeBusyR++;
                bool l2 = left;
                s.StartCoroutine(s.FastRope(transform.TransformPoint(new Vector3(side * 1.2f, 0.05f, 0)), top, rg, () => { if (l2) ropeBusyL--; else ropeBusyR--; }));
                passengers.Remove(s);
                yield return new WaitForSeconds(0.9f);
            }
            else
            {
                s.StartCoroutine(s.ExitLanded(door, outward, g));
                passengers.Remove(s);
                yield return new WaitForSeconds(0.3f);
            }
        }
        if (rope)
        {
            float w = 0;
            while ((ropeBusyL > 0 || ropeBusyR > 0) && w < 8f) { w += Time.deltaTime; yield return null; }
        }
        Unloaded = true;
        yield return new WaitForSeconds(1.2f);
        if (phase == Phase.Unload)
        {
            DeployRopes(false);
            phase = Phase.Climb;
        }
    }

    Vector3 RopeTop(Vector3 outward)
    {
        return transform.position + outward * 1.55f + Vector3.up * 1.9f;
    }

    void DeployRopes(bool on)
    {
        ropesOut = on;
        if (ropeLines == null && on)
        {
            ropeLines = new LineRenderer[2];
            for (int i = 0; i < 2; i++)
            {
                var g = new GameObject("rope");
                g.transform.SetParent(transform, false);
                var lr = g.AddComponent<LineRenderer>();
                lr.sharedMaterial = Mats.Get(new Color(0.12f, 0.1f, 0.08f));
                lr.widthMultiplier = 0.05f;
                lr.positionCount = 2;
                ropeLines[i] = lr;
            }
        }
        if (ropeLines != null) foreach (var r in ropeLines) r.enabled = on;
    }

    void UpdateRopes()
    {
        if (ropeLines == null) return;
        for (int i = 0; i < 2; i++)
        {
            Vector3 outward = transform.right * (i == 0 ? -1 : 1); outward.y = 0; outward.Normalize();
            Vector3 top = RopeTop(outward);
            Vector3 bottom = new Vector3(top.x, Battle.GroundHeight(top) + 0.05f, top.z) + new Vector3(Mathf.Sin(Time.time * 2f + i), 0, Mathf.Cos(Time.time * 1.7f + i)) * 0.25f;
            ropeLines[i].SetPosition(0, top);
            ropeLines[i].SetPosition(1, bottom);
        }
    }

    public void AttachSling(ScpContainer c)
    {
        sling = c;
        c.attached = true;
        var g = new GameObject("cable");
        g.transform.SetParent(transform, false);
        cable = g.AddComponent<LineRenderer>();
        cable.sharedMaterial = Mats.Get(new Color(0.1f, 0.1f, 0.1f));
        cable.widthMultiplier = 0.06f;
        cable.positionCount = 2;
    }

    // ---------------- урон и крушение ----------------
    public void Damage(float amount, Unit attacker)
    {
        if (phase == Phase.Crash || phase == Phase.Dead || phase == Phase.Waiting) return;
        if (attacker != null && attacker.team == team) return;
        hp -= amount;
        lastAttacker = attacker;
        if (hp <= 0) StartCrash();
    }

    void StartCrash()
    {
        phase = Phase.Crash;
        crashSpin = Random.value < 0.5f ? -1 : 1;
        Battle.Message("ВЕРТОЛЁТ " + label + " СБИТ!", new Color(1f, 0.5f, 0.2f));
        Fx.Explosion(transform.TransformPoint(new Vector3(0, 2.5f, -1)), 3f);
        Sfx.Play("explosion", transform.position, 1f, 0.8f, 400f);
        // пассажиры вываливаются
        foreach (var s in passengers.ToArray()) if (s != null && s.alive) s.KillInVehicle(velocity, lastAttacker);
        passengers.Clear();
        if (playerPassenger != null) { playerPassenger.KillInHeli(velocity); playerPassenger = null; }
        if (sling != null && sling.attached) sling.Release(transform.position + Vector3.down * 8f, true);
        StopAllCoroutines();
        DeployRopes(false);
    }

    void CrashUpdate(float dt, float agl)
    {
        velocity += Physics.gravity * 0.55f * dt;
        velocity = Vector3.Lerp(velocity, new Vector3(0, velocity.y, 0), dt * 0.3f);
        transform.position += velocity * dt;
        transform.Rotate(0, crashSpin * 220f * dt, 0, Space.World);
        transform.rotation = Quaternion.Slerp(transform.rotation, transform.rotation * Quaternion.Euler(15f * dt, 0, 25f * dt * crashSpin), 0.5f);
        Fx.Smoke(transform.TransformPoint(new Vector3(0, 2.5f, -1.5f)), 2f, new Color(0.1f, 0.1f, 0.1f, 0.8f), 4f, Vector3.up * 2f);
        Fx.Fire(transform.TransformPoint(new Vector3(0, 2.5f, -1.5f)), 1.5f, Vector3.zero, 0.5f);
        if (agl < 1.6f)
        {
            phase = Phase.Dead;
            Combat.Explode(transform.position + Vector3.up, 11f, 350f, lastAttacker, "Падение вертолёта", 1600f);
            Fx.Explosion(transform.position + Vector3.up * 2f, 6f);
            var p = transform.position; p.y = Battle.GroundHeight(p) + 1.15f;
            transform.position = p;
            transform.rotation = Quaternion.Euler(Random.Range(-10f, 10f), transform.eulerAngles.y, crashSpin * Random.Range(40f, 90f));
            if (rotor != null) Destroy(rotor.gameObject);
            if (rotorSnd != null) rotorSnd.Stop();
            MeshKit.Tint(gameObject, new Color(0.25f, 0.22f, 0.2f));
            gameObject.AddComponent<Wreck>();
            Active.Remove(this);
        }
    }
}

// Горящие обломки
public class Wreck : MonoBehaviour
{
    float t;
    AudioSource fire;
    void Start() { fire = Sfx.Loop("fire", transform, 0.6f, 50f); }
    void Update()
    {
        t += Time.deltaTime;
        if (t < 40f)
        {
            if (Random.value < 0.6f) Fx.Fire(transform.position + Random.insideUnitSphere * 2f + Vector3.up, 1.2f, Vector3.zero, 0.8f);
            if (Random.value < 0.3f) Fx.Smoke(transform.position + Vector3.up * 2.5f, 2.5f, new Color(0.08f, 0.08f, 0.08f, 0.7f), 6f, Vector3.up * 2.5f);
        }
        else if (fire != null) { fire.Stop(); Destroy(fire.gameObject); fire = null; }
    }
}

// Контейнер для перевозки SCP: висит на тросе, ставится на землю, створки отстреливаются — объект выходит
public class ScpContainer : MonoBehaviour
{
    public bool attached;
    public float height = 3f;
    public ScpKind kind;
    public int count;
    Transform door;
    bool opened;
    Vector3 swing;
    public readonly List<Unit> spawned = new List<Unit>();

    public static ScpContainer Create(ScpKind kind, int count)
    {
        bool big = kind == ScpKind.S682;
        var go = new GameObject("Container " + kind);
        var c = go.AddComponent<ScpContainer>();
        c.kind = kind; c.count = count;
        float w = big ? 5f : 3.2f, h = big ? 4.4f : 3f, l = big ? 9f : 4.2f;
        c.height = h;
        var t = go.transform;
        Color metal = new Color(0.42f, 0.43f, 0.45f), dark = new Color(0.18f, 0.18f, 0.19f);
        Color hazard = new Color(0.95f, 0.75f, 0.1f);
        var m = Mats.Get(metal, 0.4f, 0.5f);
        MeshKit.Box(t, new Vector3(0, 0.1f, 0), new Vector3(w, 0.2f, l), dark);
        MeshKit.Box(t, new Vector3(0, h - 0.1f, 0), new Vector3(w, 0.2f, l), m);
        MeshKit.Box(t, new Vector3(-w / 2, h / 2, 0), new Vector3(0.15f, h, l), m);
        MeshKit.Box(t, new Vector3(w / 2, h / 2, 0), new Vector3(0.15f, h, l), m);
        MeshKit.Box(t, new Vector3(0, h / 2, -l / 2), new Vector3(w, h, 0.15f), m);
        for (int i = 0; i < 6; i++)
        {
            float z = -l / 2 + (i + 0.5f) * l / 6f;
            MeshKit.Box(t, new Vector3(-w / 2 - 0.05f, h / 2, z), new Vector3(0.08f, h, 0.15f), dark);
            MeshKit.Box(t, new Vector3(w / 2 + 0.05f, h / 2, z), new Vector3(0.08f, h, 0.15f), dark);
        }
        for (int i = 0; i < 5; i++)
        {
            MeshKit.Box(t, new Vector3(-w / 2 - 0.09f, 0.4f, -l / 2 + 0.4f + i * (l - 0.8f) / 4f), new Vector3(0.02f, 0.3f, 0.6f), hazard, new Vector3(0, 0, 0));
            MeshKit.Box(t, new Vector3(w / 2 + 0.09f, 0.4f, -l / 2 + 0.4f + i * (l - 0.8f) / 4f), new Vector3(0.02f, 0.3f, 0.6f), hazard, new Vector3(0, 0, 0));
        }
        MeshKit.Box(t, new Vector3(0, h + 0.15f, 0), new Vector3(0.6f, 0.3f, 0.6f), dark);
        MeshKit.Ball(t, new Vector3(w / 2 - 0.3f, h + 0.1f, l / 2 - 0.3f), Vector3.one * 0.25f, Mats.Glow(new Color(1f, 0.1f, 0.05f), 4f));
        MeshKit.CombineParts(t);
        // створка спереди
        c.door = new GameObject("door").transform;
        c.door.SetParent(t, false);
        c.door.localPosition = new Vector3(0, h / 2, l / 2);
        MeshKit.Box(c.door, Vector3.zero, new Vector3(w, h, 0.18f), m);
        MeshKit.Box(c.door, new Vector3(0, 0, 0.1f), new Vector3(w * 0.8f, 0.4f, 0.02f), hazard);
        MeshKit.CombineParts(c.door);
        var font = Helicopter.UIFont();
        if (font != null)
        {
            var tg = new GameObject("label");
            tg.transform.SetParent(c.door, false);
            tg.transform.localPosition = new Vector3(0, 0.6f, 0.11f);
            tg.transform.localScale = Vector3.one * 0.08f;
            var tm = tg.AddComponent<TextMesh>();
            tm.font = font; tm.fontSize = 60; tm.text = DB.Scp(kind).name; tm.anchor = TextAnchor.MiddleCenter;
            tm.color = new Color(0.05f, 0.05f, 0.05f);
            tg.GetComponent<MeshRenderer>().sharedMaterial = Helicopter.TextMat(font);
            tg.transform.localRotation = Quaternion.identity;
        }
        var bc = go.AddComponent<BoxCollider>();
        bc.center = new Vector3(0, h / 2, 0);
        bc.size = new Vector3(w, h, l);
        var rb = go.AddComponent<Rigidbody>(); rb.isKinematic = true;
        MeshKit.SetLayer(go, Layers.Vehicle);
        var obst = go.AddComponent<NavMeshObstacle>();
        obst.shape = NavMeshObstacleShape.Box;
        obst.center = bc.center; obst.size = bc.size + new Vector3(0.4f, 0, 0.4f);
        obst.carving = true;
        obst.enabled = false;
        return c;
    }

    public void FollowHeli(Helicopter h, float dt)
    {
        Vector3 target = h.transform.position + Vector3.down * (9f + height);
        Vector3 acc = (target - transform.position) * 30f - swing * 6f;
        swing += acc * dt;
        transform.position += swing * dt;
        transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.Euler(0, h.transform.eulerAngles.y, 0) * Quaternion.Euler(Mathf.Clamp(-swing.z, -10, 10), 0, Mathf.Clamp(swing.x, -10, 10)), dt * 2f);
    }

    public void Release(Vector3 ground, bool fall = false)
    {
        attached = false;
        StartCoroutine(Drop(ground, fall));
    }

    IEnumerator Drop(Vector3 ground, bool fall)
    {
        Vector3 start = transform.position;
        float gy = Battle.GroundHeight(new Vector3(start.x, 0, start.z));
        Vector3 end = new Vector3(start.x, gy, start.z);
        float t = 0, dur = fall ? 1.4f : 1.0f;
        Quaternion r0 = transform.rotation;
        Quaternion r1 = Quaternion.Euler(0, transform.eulerAngles.y, 0);
        while (t < dur)
        {
            t += Time.deltaTime;
            float k = fall ? (t / dur) * (t / dur) : Mathf.SmoothStep(0, 1, t / dur);
            transform.position = Vector3.Lerp(start, end, k);
            transform.rotation = Quaternion.Slerp(r0, r1, k);
            yield return null;
        }
        transform.position = end;
        Sfx.Play("metal", end, 1f, 0.5f, 120f);
        Sfx.Play("bodyfall", end, 1f, 0.4f, 120f);
        for (int i = 0; i < 25; i++)
        {
            float a = Random.Range(0, Mathf.PI * 2);
            Vector3 d = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
            Fx.GroundDust(end + d * 2f, d * 5f, 2f, Battle.DustColor);
        }
        Fx.AddShake(end, 0.5f);
        GetComponent<NavMeshObstacle>().enabled = true;
        yield return new WaitForSeconds(fall ? 0.3f : 1.8f);
        Sfx.Play("alarm", end, 1f, 1f, 150f);
        yield return new WaitForSeconds(1.2f);
        Open();
    }

    void Open()
    {
        if (opened) return;
        opened = true;
        // створку выбивает пиропатронами
        Vector3 dp = door.position;
        door.SetParent(MapGen.Root != null ? MapGen.Root.transform : null, true);
        var bc = door.gameObject.AddComponent<BoxCollider>();
        bc.size = new Vector3(kind == ScpKind.S682 ? 5f : 3.2f, height, 0.18f);
        var rb = door.gameObject.AddComponent<Rigidbody>();
        rb.mass = 200;
        rb.velocity = transform.forward * 7f + Vector3.up * 3f;
        rb.angularVelocity = transform.right * 2f;
        door.gameObject.layer = Layers.World;
        foreach (Transform ch in door) ch.gameObject.layer = Layers.World;
        Fx.Explosion(dp, 1.2f);
        Sfx.Play("explosion", dp, 0.7f, 1.4f, 200f);
        Fx.Smoke(dp, 4f, new Color(0.6f, 0.6f, 0.6f, 0.5f), 5f, Vector3.up);
        // выпускаем объекты
        for (int i = 0; i < count; i++)
        {
            Vector3 p = transform.position + transform.forward * (kind == ScpKind.S682 ? 0f : -0.5f) + transform.right * ((i % 3) - 1) * 0.8f + transform.forward * -(i / 3) * 0.8f;
            var u = ScpFactory.Spawn(kind, p, transform.rotation);
            if (u != null)
            {
                spawned.Add(u);
                Battle.Register(u);
                StartCoroutine(Emerge(u, p, i * 0.5f));
            }
        }
        Battle.Message(DB.Scp(kind).name + " ВЫПУЩЕН!", new Color(1f, 0.25f, 0.2f));
    }

    IEnumerator Emerge(Unit u, Vector3 start, float delay)
    {
        if (u is ScpUnit su) su.Hold(true);
        if (u is Soldier zs) zs.state = Soldier.State.Scripted;
        yield return new WaitForSeconds(delay);
        if (u == null) yield break;
        Vector3 end = transform.position + transform.forward * (kind == ScpKind.S682 ? 8f : 4.5f) + Random.insideUnitSphere * 1.5f;
        end.y = Battle.GroundHeight(end);
        float t = 0, dur = kind == ScpKind.S173 ? 0.01f : 1.6f;
        while (t < dur && u != null && u.alive)
        {
            t += Time.deltaTime;
            Vector3 p = Vector3.Lerp(start, end, t / dur);
            var v = (p - u.transform.position) / Mathf.Max(0.001f, Time.deltaTime);
            u.transform.position = p;
            if (u is ScpUnit su2) su2.SetAnimVelocity(v);
            if (u is Soldier zs2) zs2.anim.velocity = v;
            yield return null;
        }
        if (u == null) yield break;
        if (kind == ScpKind.S173) u.transform.position = end;
        if (u is ScpUnit su3) su3.Hold(false);
        if (u is Soldier zs3) zs3.BeginCombat(u.transform.position);
    }
}
