using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Поза: абсолютные углы конечностей (0 = вниз, + = вперёд по направлению взгляда).
    // spin — поворот всего тела (+ = назад, как сальто назад), применяется вокруг центра корпуса.
    public struct Pose
    {
        public float lean, a1, a2, b1, b2, f1, f2, k1, k2, spin;

        public Pose(float lean, float a1, float a2, float b1, float b2, float f1, float f2, float k1, float k2, float spin = 0f)
        {
            this.lean = lean; this.a1 = a1; this.a2 = a2; this.b1 = b1; this.b2 = b2;
            this.f1 = f1; this.f2 = f2; this.k1 = k1; this.k2 = k2; this.spin = spin;
        }

        public static Pose Lerp(Pose x, Pose y, float t)
        {
            return new Pose(
                Mathf.LerpUnclamped(x.lean, y.lean, t),
                Mathf.LerpUnclamped(x.a1, y.a1, t), Mathf.LerpUnclamped(x.a2, y.a2, t),
                Mathf.LerpUnclamped(x.b1, y.b1, t), Mathf.LerpUnclamped(x.b2, y.b2, t),
                Mathf.LerpUnclamped(x.f1, y.f1, t), Mathf.LerpUnclamped(x.f2, y.f2, t),
                Mathf.LerpUnclamped(x.k1, y.k1, t), Mathf.LerpUnclamped(x.k2, y.k2, t),
                Mathf.LerpUnclamped(x.spin, y.spin, t));
        }

        static float Ease(float k) { return k * k * (3 - 2 * k); }

        // стойка -> замах -> удар (резкий, как "смаз") -> удержание -> стойка
        public static Pose Attack(Pose rest, Pose wind, Pose strike, float u, float hitAt = 0.45f)
        {
            float w0 = hitAt * 0.7f;
            if (u < w0) return Lerp(rest, wind, Ease(u / w0));
            if (u < hitAt) { float k = (u - w0) / (hitAt - w0); return Lerp(wind, strike, 1f - (1f - k) * (1f - k) * (1f - k)); }
            float hold = hitAt + (1f - hitAt) * 0.4f;
            if (u < hold) return strike;
            return Lerp(strike, rest, Ease((u - hold) / (1f - hold)));
        }

        public static readonly Pose Guard = new Pose(8, 40, 155, 25, 140, 24, 4, -20, -8);
        public static readonly Pose GuardBlade = new Pose(6, 35, 105, 25, 135, 24, 4, -20, -8);
        public static readonly Pose GuardGun = new Pose(4, 85, 88, 35, 120, 20, 0, -18, -6);
        public static readonly Pose GuardSpear = new Pose(5, 45, 95, 60, 100, 24, 4, -20, -8);
        public static readonly Pose Block = new Pose(-6, 60, 175, 50, 168, 20, 0, -25, -12);
        public static readonly Pose Hurt = new Pose(-25, -30, 10, -50, -20, 15, 10, -30, -15);
        public static readonly Pose HurtHigh = new Pose(-38, -20, 25, -45, -5, 18, 10, -28, -12);
        public static readonly Pose HurtBody = new Pose(32, 45, 100, 35, 90, 20, -8, -25, -18);
        public static readonly Pose Tumble = new Pose(-10, 140, 170, -140, -170, 40, -30, -35, -60);
        public static readonly Pose Lying = new Pose(0, 35, 60, -30, -10, 8, 4, -8, -4);
        public static readonly Pose Tuck = new Pose(40, 70, 150, 60, 140, 115, -25, 100, -35);
        public static readonly Pose Victory = new Pose(-4, 150, 165, -150, -165, 14, 4, -14, -4);
        public static readonly Pose Cast = new Pose(10, 88, 88, 80, 82, 25, 5, -22, -8);
        public static readonly Pose CastUp = new Pose(-5, 170, 175, 165, 178, 15, 0, -15, 0);
        public static readonly Pose Taunt = new Pose(-6, 100, 160, 30, 150, 10, 2, -12, -4);

        public static readonly Pose PunchW = new Pose(0, 20, 130, 30, 150, 24, 4, -20, -8);
        public static readonly Pose PunchS = new Pose(22, 92, 90, 20, 150, 40, 10, -30, -10);
        public static readonly Pose Punch2W = new Pose(4, 40, 155, 5, 110, 24, 4, -20, -8);
        public static readonly Pose Punch2S = new Pose(25, 40, 150, 92, 90, 40, 10, -30, -10);
        public static readonly Pose JabW = new Pose(5, 30, 150, 25, 140, 24, 4, -20, -8);
        public static readonly Pose JabS = new Pose(16, 90, 90, 25, 145, 30, 6, -24, -8);
        public static readonly Pose HookW = new Pose(0, 70, 175, 25, 140, 24, 4, -20, -8);
        public static readonly Pose HookS = new Pose(22, 108, 118, 25, 140, 35, 8, -28, -10);
        public static readonly Pose UpperW = new Pose(28, 15, 60, 30, 150, 50, 10, -35, -35);
        public static readonly Pose UpperS = new Pose(-14, 165, 172, 30, 150, 12, 0, -15, -5);
        public static readonly Pose KneeW = new Pose(5, 60, 170, 40, 160, 40, -40, -20, -8);
        public static readonly Pose KneeS = new Pose(15, 70, 170, 50, 165, 100, -30, -20, -8);
        public static readonly Pose KickW = new Pose(0, 50, 160, 20, 140, 80, -20, -15, -5);
        public static readonly Pose KickS = new Pose(-22, 60, 170, -20, 40, 98, 95, -10, -5);
        public static readonly Pose RoundW = new Pose(5, 50, 160, 20, 140, 85, -25, -15, -5);
        public static readonly Pose RoundS = new Pose(-38, 70, 170, -25, 30, 125, 118, -12, -5);
        public static readonly Pose SweepW = new Pose(25, 50, 150, 30, 140, 60, -40, 60, -70);
        public static readonly Pose SweepS = new Pose(20, 60, 150, 30, 140, 82, 92, 70, -75);
        public static readonly Pose FlyKickW = new Pose(5, 110, 140, -40, -10, 70, -20, -10, -50);
        public static readonly Pose FlyKickS = new Pose(-28, 60, 170, -30, 40, 95, 95, 30, -90);
        public static readonly Pose DiveW = new Pose(-15, 170, 190, 160, 185, 160, 170, -10, -60);
        public static readonly Pose DiveS = new Pose(30, 60, 80, 50, 70, 25, 15, -30, -70);
        public static readonly Pose AirPunchS = new Pose(15, 95, 92, -30, 30, 50, -20, -10, -60);
        public static readonly Pose SlashW = new Pose(-8, 175, 200, 40, 130, 20, 0, -22, -8);
        public static readonly Pose SlashS = new Pose(25, 45, 25, 30, 120, 45, 20, -30, -15);
        public static readonly Pose RiseW = new Pose(25, 40, 20, 30, 120, 45, 20, -30, -15);
        public static readonly Pose RiseS = new Pose(-12, 170, 195, 30, 120, 20, 0, -22, -8);
        public static readonly Pose SpinSlashW = new Pose(10, 120, 140, 30, 120, 30, 8, -25, -10);
        public static readonly Pose SpinSlashS = new Pose(22, 90, 88, 60, 100, 45, 15, -30, -15);
        public static readonly Pose StabW = new Pose(-6, 30, 60, 50, 90, 15, 0, -25, -10);
        public static readonly Pose StabS = new Pose(25, 88, 90, 85, 92, 50, 30, -35, -20);
        public static readonly Pose SmashW = new Pose(-15, 190, 210, 185, 205, 15, 0, -20, -5);
        public static readonly Pose SmashS = new Pose(35, 60, 30, 55, 35, 40, 20, -35, -20);
        public static readonly Pose ThrowW = new Pose(-10, 190, 220, 40, 90, 15, 0, -25, -8);
        public static readonly Pose ThrowS = new Pose(25, 70, 60, 20, 120, 40, 15, -30, -12);
        public static readonly Pose Saw = new Pose(20, 75, 85, 70, 88, 35, 10, -28, -12);
        public static readonly Pose Dash = new Pose(35, -40, -20, -50, -30, 60, 40, -50, -60);
        public static readonly Pose AirUp = new Pose(5, 110, 140, -40, -10, 60, -10, -10, -50);
        public static readonly Pose AirDown = new Pose(0, 120, 160, 100, 150, 25, 10, -25, -20);
        public static readonly Pose Crouch = new Pose(20, 50, 150, 30, 140, 70, -30, -10, -70);
        public static readonly Pose Land = new Pose(25, 60, 140, 40, 120, 75, -35, -15, -75);

        public static Pose Run(float p, bool ninja)
        {
            float s = Mathf.Sin(p), c = Mathf.Cos(p);
            float th1 = 45f * s + 8f, th2 = -45f * s + 8f;
            float kb1 = 20f + 70f * Mathf.Max(0f, -c), kb2 = 20f + 70f * Mathf.Max(0f, c);
            if (ninja) return new Pose(30, -72, -55, -78, -60, th1, th1 - kb1, th2, th2 - kb2);
            return new Pose(18, -40f * s + 30f, -40f * s + 115f, 40f * s + 30f, 40f * s + 115f, th1, th1 - kb1, th2, th2 - kb2);
        }
    }

    public static class Skel
    {
        public const float Torso = 0.78f, Upper = 0.42f, Fore = 0.40f, Thigh = 0.52f, Shin = 0.52f, HeadR = 0.25f, Width = 0.17f;

        public static Vector2 Down(float deg, int f)
        {
            float r = deg * Mathf.Deg2Rad;
            return new Vector2(Mathf.Sin(r) * f, -Mathf.Cos(r));
        }

        // J: 0 таз, 1 шея, 2 голова, 3 локоть(перед), 4 кисть(перед), 5 локоть(зад), 6 кисть(зад), 7 колено(п), 8 стопа(п), 9 колено(з), 10 стопа(з)
        public static void Compute(Pose p, Vector2 feet, float s, int f, Vector2[] J, bool grounded = true)
        {
            Vector2 t1 = Down(p.f1, f) * Thigh * s, t2 = Down(p.f2, f) * Shin * s;
            Vector2 u1 = Down(p.k1, f) * Thigh * s, u2 = Down(p.k2, f) * Shin * s;
            float drop = Mathf.Max(-(t1.y + t2.y), -(u1.y + u2.y));
            drop = Mathf.Max(drop, 0.25f * s);
            Vector2 hip = feet + new Vector2(0, drop);
            Vector2 d = Down(p.lean, f);
            Vector2 up = new Vector2(d.x, -d.y);
            Vector2 neck = hip + up * Torso * s;
            Vector2 hd = Down(p.lean * 1.25f, f);
            Vector2 hup = new Vector2(hd.x, -hd.y);
            Vector2 head = neck + hup * (HeadR * 1.1f) * s;
            Vector2 sh = neck - up * 0.06f * s;
            J[0] = hip; J[1] = neck; J[2] = head;
            J[3] = sh + Down(p.a1, f) * Upper * s; J[4] = J[3] + Down(p.a2, f) * Fore * s;
            J[5] = sh + Down(p.b1, f) * Upper * s; J[6] = J[5] + Down(p.b2, f) * Fore * s;
            J[7] = hip + t1; J[8] = J[7] + t2;
            J[9] = hip + u1; J[10] = J[9] + u2;

            if (Mathf.Abs(p.spin) > 0.5f)
            {
                // вращение вокруг центра корпуса (+spin = назад)
                Vector2 c = (J[0] + J[1]) * 0.5f;
                float a = p.spin * f * Mathf.Deg2Rad;
                float cs = Mathf.Cos(a), sn = Mathf.Sin(a);
                for (int i = 0; i < J.Length; i++)
                {
                    Vector2 v = J[i] - c;
                    J[i] = c + new Vector2(v.x * cs - v.y * sn, v.x * sn + v.y * cs);
                }
                if (grounded)
                {
                    // самая низкая точка тела ложится на землю
                    float min = float.MaxValue;
                    for (int i = 0; i < J.Length; i++)
                    {
                        float r = i == 2 ? HeadR * s : Width * 0.5f * s;
                        min = Mathf.Min(min, J[i].y - r);
                    }
                    float shift = feet.y - min;
                    for (int i = 0; i < J.Length; i++) J[i].y += shift;
                }
            }
        }
    }

    // Тряпичная кукла (Верле) после смерти
    public class Ragdoll
    {
        public Vector2[] p, q;
        float[] r;
        struct Stick { public int a, b; public float len; public bool broken; }
        readonly List<Stick> sticks = new List<Stick>();
        float lastDt = 1f / 60f;
        public bool headOff;
        public float rest; // сколько времени тело почти неподвижно

        static readonly int[,] S = { { 0, 1 }, { 1, 2 }, { 1, 3 }, { 3, 4 }, { 1, 5 }, { 5, 6 }, { 0, 7 }, { 7, 8 }, { 0, 9 }, { 9, 10 } };

        public Ragdoll(Vector2[] J, Vector2 v, float size)
        {
            int n = J.Length;
            p = new Vector2[n]; q = new Vector2[n]; r = new float[n];
            for (int i = 0; i < n; i++)
            {
                p[i] = J[i];
                float k = (i >= 1 && i <= 6) ? 1.25f : 0.7f; // верх тела летит сильнее — кувырок
                Vector2 vi = v * k + Random.insideUnitCircle * 1.5f;
                q[i] = p[i] - vi * lastDt;
                r[i] = Skel.Width * 0.5f * size;
            }
            r[2] = Skel.HeadR * size;
            for (int i = 0; i < S.GetLength(0); i++)
                sticks.Add(new Stick { a = S[i, 0], b = S[i, 1], len = Vector2.Distance(J[S[i, 0]], J[S[i, 1]]) });
            // мягкие распорки, чтобы тело не складывалось в точку
            sticks.Add(new Stick { a = 2, b = 0, len = Vector2.Distance(J[2], J[0]) });
            sticks.Add(new Stick { a = 7, b = 9, len = Mathf.Max(0.2f, Vector2.Distance(J[7], J[9])) });
        }

        public void BreakNeck(Vector2 impulse)
        {
            for (int i = 0; i < sticks.Count; i++)
            {
                var s = sticks[i];
                if ((s.a == 1 && s.b == 2) || (s.a == 2 && s.b == 0)) { s.broken = true; sticks[i] = s; }
            }
            q[2] -= impulse * lastDt;
            headOff = true;
        }

        public void Step(float dt, float W)
        {
            if (dt <= 0) return;
            float k = dt / lastDt;
            lastDt = dt;
            float move = 0;
            for (int i = 0; i < p.Length; i++)
            {
                Vector2 vel = (p[i] - q[i]) * k * 0.995f;
                q[i] = p[i];
                p[i] += vel + new Vector2(0, -30f) * dt * dt;
                move += vel.sqrMagnitude;
            }
            for (int it = 0; it < 8; it++)
            {
                foreach (var s in sticks)
                {
                    if (s.broken) continue;
                    Vector2 d = p[s.b] - p[s.a];
                    float l = d.magnitude;
                    if (l < 0.0001f) continue;
                    float diff = (l - s.len) / l * 0.5f;
                    if (s.a == 2 || s.b == 2 || (s.a == 7 && s.b == 9)) diff *= 0.3f;
                    p[s.a] += d * diff;
                    p[s.b] -= d * diff;
                }
                for (int i = 0; i < p.Length; i++)
                {
                    if (p[i].y < r[i])
                    {
                        float vy = p[i].y - q[i].y;
                        p[i].y = r[i];
                        q[i].y = p[i].y + vy * 0.3f;
                        q[i].x = Mathf.Lerp(q[i].x, p[i].x, 0.35f);
                    }
                    float lim = W - r[i];
                    if (Mathf.Abs(p[i].x) > lim)
                    {
                        float vx = p[i].x - q[i].x;
                        p[i].x = Mathf.Sign(p[i].x) * lim;
                        q[i].x = p[i].x + vx * 0.4f;
                    }
                }
            }
            if (move < 0.00004f) rest += dt; else rest = 0;
        }
    }

    // Отрисовка оружия в локальных координатах (ось X — вдоль предплечья)
    public static class WeaponVisual
    {
        public static List<Renderer> Build(Transform root, WeaponStats w, float scale, int order, bool glow)
        {
            var list = new List<Renderer>();
            float s = scale * w.size;
            Color c = w.color;
            Color dark = new Color(0.22f, 0.15f, 0.1f);
            Color wood = new Color(0.45f, 0.3f, 0.15f);

            if (w.drawing != null && w.drawing.Count > 0)
            {
                foreach (var st in w.drawing)
                {
                    if (st.pts.Count < 2) continue;
                    var lr = Draw.Line(root, "drawn", st.width * 0.7f * s * 1.4f, st.color, order, false, 3);
                    var pts = new List<Vector2>();
                    foreach (var p in st.pts) pts.Add(new Vector2(p.x * 0.7f + 0.5f, p.y * 0.7f) * s);
                    Draw.Set(lr, pts);
                    list.Add(lr);
                }
                AddGlow(root, w, s, order, list);
                return list;
            }

            switch (w.kind)
            {
                case WeaponKind.Blade:
                    {
                        if (w.axe)
                        {
                            var h = Draw.Line(root, "handle", 0.07f * s, wood, order, false); Draw.Set(h, new Vector2(-0.2f, 0) * s, new Vector2(1.0f, 0) * s); list.Add(h);
                            list.Add(Draw.Poly(root, new[] { new Vector2(0.65f, 0.05f) * s, new Vector2(0.95f, 0.05f) * s, new Vector2(1.1f, 0.38f) * s, new Vector2(0.55f, 0.38f) * s }, c, order + 1, "axeHead"));
                            break;
                        }
                        var hd = Draw.Line(root, "handle", 0.07f * s, dark, order, false); Draw.Set(hd, new Vector2(-0.18f, 0) * s, new Vector2(0.1f, 0) * s); list.Add(hd);
                        var g = Draw.Line(root, "guard", 0.06f * s, Draw.Mul(c, 0.6f), order + 1, false); Draw.Set(g, new Vector2(0.1f, -0.13f) * s, new Vector2(0.1f, 0.13f) * s); list.Add(g);
                        var b = Draw.Line(root, "blade", 1f, c, order, false, 2);
                        Draw.Set(b, new List<Vector2> { new Vector2(0.1f, 0) * s, new Vector2(0.6f, 0.02f) * s, new Vector2(1.05f, 0.07f) * s });
                        Draw.Taper(b, 0.1f * s, 0.025f * s);
                        list.Add(b);
                        break;
                    }
                case WeaponKind.Blunt:
                    {
                        if (w.bat)
                        {
                            var b = Draw.Line(root, "bat", 1f, c.grayscale > 0.4f ? c : wood, order, false);
                            Draw.Set(b, new Vector2(-0.2f, 0) * s, new Vector2(1.0f, 0) * s);
                            Draw.Taper(b, 0.06f * s, 0.17f * s);
                            list.Add(b);
                            break;
                        }
                        var h = Draw.Line(root, "handle", 0.07f * s, wood, order, false); Draw.Set(h, new Vector2(-0.2f, 0) * s, new Vector2(0.8f, 0) * s); list.Add(h);
                        var hh = Draw.Line(root, "head", 0.3f * s, c, order + 1, false, 1); Draw.Set(hh, new Vector2(0.8f, -0.2f) * s, new Vector2(0.8f, 0.2f) * s); list.Add(hh);
                        break;
                    }
                case WeaponKind.Spear:
                    {
                        var h = Draw.Line(root, "shaft", 0.06f * s, wood, order, false); Draw.Set(h, new Vector2(-0.9f, 0) * s, new Vector2(1.45f, 0) * s); list.Add(h);
                        if (w.scythe)
                        {
                            var bl = Draw.Line(root, "scythe", 1f, c, order + 1, false, 2);
                            Draw.Set(bl, new List<Vector2> { new Vector2(1.45f, 0) * s, new Vector2(1.3f, 0.4f) * s, new Vector2(0.9f, 0.6f) * s, new Vector2(0.5f, 0.55f) * s });
                            Draw.Taper(bl, 0.14f * s, 0.02f * s);
                            list.Add(bl);
                        }
                        else
                        {
                            var tip = Draw.Line(root, "tip", 1f, c, order + 1, false, 0);
                            Draw.Set(tip, new Vector2(1.4f, 0) * s, new Vector2(1.8f, 0) * s);
                            Draw.Taper(tip, 0.16f * s, 0.0f);
                            list.Add(tip);
                        }
                        break;
                    }
                case WeaponKind.Gun:
                    {
                        float len = w.rifle ? 0.85f : (w.pellets > 1 ? 0.8f : 0.45f);
                        var body = Draw.Line(root, "body", 0.12f * s, c, order, false, 1); Draw.Set(body, new Vector2(-0.05f, 0.1f) * s, new Vector2(len, 0.1f) * s); list.Add(body);
                        var grip = Draw.Line(root, "grip", 0.09f * s, Draw.Mul(c, 0.7f), order, false, 1); Draw.Set(grip, new Vector2(0.02f, 0.1f) * s, new Vector2(-0.06f, -0.12f) * s); list.Add(grip);
                        if (w.rifle)
                        {
                            var stock = Draw.Line(root, "stock", 0.13f * s, Draw.Mul(c, 0.8f), order, false, 1); Draw.Set(stock, new Vector2(-0.05f, 0.08f) * s, new Vector2(-0.4f, 0.02f) * s); list.Add(stock);
                            var mag = Draw.Line(root, "mag", 0.08f * s, Draw.Mul(c, 0.6f), order, false, 1); Draw.Set(mag, new Vector2(0.3f, 0.08f) * s, new Vector2(0.35f, -0.15f) * s); list.Add(mag);
                        }
                        break;
                    }
                case WeaponKind.Bow:
                    {
                        var arc = Draw.Line(root, "bow", 0.06f * s, c, order, false, 2);
                        var pts = new List<Vector2>();
                        for (int i = 0; i <= 10; i++) { float a = Mathf.Lerp(-1.1f, 1.1f, i / 10f); pts.Add(new Vector2(0.05f + Mathf.Cos(a) * 0.35f, Mathf.Sin(a) * 0.7f) * s); }
                        Draw.Set(arc, pts); list.Add(arc);
                        var str = Draw.Line(root, "string", 0.015f * s, new Color(0.9f, 0.9f, 0.9f), order, false, 0);
                        Draw.Set(str, pts[0], new Vector2(-0.02f, 0) * s, pts[pts.Count - 1]); list.Add(str);
                        break;
                    }
                case WeaponKind.Thrown:
                    {
                        if (w.explode)
                        {
                            var gr = Draw.Spr(root, "grenade", Draw.Circle, new Color(0.25f, 0.32f, 0.18f), order);
                            gr.transform.localPosition = new Vector3(0.12f * s, 0, 0); gr.transform.localScale = Vector3.one * 0.26f * s;
                            list.Add(gr);
                            break;
                        }
                        var a1 = Draw.Line(root, "star1", 0.05f * s, c, order, false, 0); Draw.Set(a1, new Vector2(0.0f, -0.15f) * s, new Vector2(0.3f, 0.15f) * s); list.Add(a1);
                        var a2 = Draw.Line(root, "star2", 0.05f * s, c, order, false, 0); Draw.Set(a2, new Vector2(0.0f, 0.15f) * s, new Vector2(0.3f, -0.15f) * s); list.Add(a2);
                        break;
                    }
                case WeaponKind.Chainsaw:
                    {
                        var body = Draw.Line(root, "body", 0.3f * s, c, order + 1, false, 1); Draw.Set(body, new Vector2(-0.12f, 0) * s, new Vector2(0.3f, 0) * s); list.Add(body);
                        var bar = Draw.Line(root, "bar", 0.13f * s, new Color(0.7f, 0.72f, 0.75f), order, false, 3); Draw.Set(bar, new Vector2(0.3f, 0) * s, new Vector2(1.1f, 0) * s); list.Add(bar);
                        var teeth = Draw.Line(root, "teeth", 0.03f * s, new Color(0.2f, 0.2f, 0.2f), order + 1, false, 0);
                        var tp = new List<Vector2>();
                        for (int i = 0; i <= 16; i++) tp.Add(new Vector2(0.32f + i * 0.05f, (i % 2 == 0 ? 0.08f : 0.03f)) * s);
                        Draw.Set(teeth, tp); list.Add(teeth);
                        break;
                    }
                case WeaponKind.Staff:
                    {
                        var h = Draw.Line(root, "shaft", 0.06f * s, wood, order, false); Draw.Set(h, new Vector2(-0.9f, 0) * s, new Vector2(1.0f, 0) * s); list.Add(h);
                        var orb = Draw.Spr(root, "orb", Draw.Circle, Info.ElemColor(w.element), order + 1);
                        orb.transform.localPosition = new Vector3(1.1f * s, 0, 0); orb.transform.localScale = Vector3.one * 0.24f * s;
                        list.Add(orb);
                        var og = Draw.Spr(root, "orbGlow", Draw.Soft, Draw.A(Info.ElemColor(w.element), 0.7f), order);
                        og.transform.localPosition = new Vector3(1.1f * s, 0, 0); og.transform.localScale = Vector3.one * 0.9f * s;
                        list.Add(og);
                        break;
                    }
            }
            AddGlow(root, w, s, order, list);
            return list;
        }

        static void AddGlow(Transform root, WeaponStats w, float s, int order, List<Renderer> list)
        {
            if (w.element == Element.None || w.kind == WeaponKind.Staff) return;
            var g = Draw.Spr(root, "elemGlow", Draw.Soft, Draw.A(Info.ElemColor(w.element), 0.45f), order - 1);
            g.transform.localPosition = new Vector3(0.6f * s, 0, 0);
            g.transform.localScale = new Vector3(1.8f * s, 0.6f * s, 1);
            list.Add(g);
        }
    }
}
