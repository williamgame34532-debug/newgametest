using UnityEngine;

namespace StickWars
{
    // Кровь, искры, дым, дождь — всё одним динамическим мешем. Пятна крови — отдельным мешем.
    public class Particles : MonoBehaviour
    {
        struct P
        {
            public Vector2 pos, vel;
            public float life, max, size, grav, drag, sx, sy;
            public Color col;
            public bool stain, fade, shrink, alive, streak;
        }

        struct S
        {
            public Vector2 pos;
            public float w, h, grow, maxW, rot, age, dripMax;
            public Color col, col0;
        }

        const int MAXP = 3500, MAXS = 2600;
        P[] ps = new P[MAXP];
        int pHead;
        S[] ss = new S[MAXS];
        int sCount, sHead;
        bool sDirty;
        float dryT;

        Mesh pm, sm;
        Vector3[] pv, sv;
        Color[] pc, sc;
        public float W = 15f;
        public float groundY = 0f;
        // запись для повтора: (тип, точка, вектор, число, цвет)
        public System.Action<int, Vector2, Vector2, float, Color> Rec;

        void Awake()
        {
            pm = MakeMesh("particles", 400, MAXP, out pv, out pc);
            sm = MakeMesh("stains", -2, MAXS, out sv, out sc);
        }

        Mesh MakeMesh(string name, int order, int n, out Vector3[] v, out Color[] c)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            var mf = go.AddComponent<MeshFilter>();
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = Draw.ParticleMat;
            mr.sortingOrder = order;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var m = new Mesh();
            m.MarkDynamic();
            v = new Vector3[n * 4];
            c = new Color[n * 4];
            var uv = new Vector2[n * 4];
            var t = new int[n * 6];
            for (int i = 0; i < n; i++)
            {
                uv[i * 4] = new Vector2(0, 0); uv[i * 4 + 1] = new Vector2(0, 1); uv[i * 4 + 2] = new Vector2(1, 1); uv[i * 4 + 3] = new Vector2(1, 0);
                t[i * 6] = i * 4; t[i * 6 + 1] = i * 4 + 1; t[i * 6 + 2] = i * 4 + 2;
                t[i * 6 + 3] = i * 4; t[i * 6 + 4] = i * 4 + 2; t[i * 6 + 5] = i * 4 + 3;
            }
            if (n * 4 > 65000) m.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            m.vertices = v; m.colors = c; m.uv = uv; m.triangles = t;
            m.bounds = new Bounds(Vector3.zero, new Vector3(10000, 10000, 10));
            mf.sharedMesh = m;
            return m;
        }

        public void Clear(bool stainsToo)
        {
            for (int i = 0; i < MAXP; i++) ps[i].alive = false;
            if (stainsToo) { sCount = 0; sHead = 0; sDirty = true; }
        }

        public void Emit(Vector2 pos, Vector2 vel, Color col, float size, float life, float grav, bool stain, float drag = 0.5f, bool fade = true, float sx = 1, float sy = 1, bool shrink = false, bool streak = false)
        {
            var p = new P();
            p.pos = pos; p.vel = vel; p.col = col; p.size = size; p.life = life; p.max = life;
            p.grav = grav; p.stain = stain; p.drag = drag; p.fade = fade; p.sx = sx; p.sy = sy; p.alive = true; p.shrink = shrink; p.streak = streak;
            ps[pHead] = p;
            pHead = (pHead + 1) % MAXP;
        }

        public static int InkMode; // 0 кровь, 1 чёрная тушь, 2 графит, 3 яркая алая (нуар)
        // мрачная кровь: густой тёмно-багровый с редкими влажными алыми бликами
        public static Color BloodColor()
        {
            if (InkMode == 1) return new Color(Random.Range(0.02f, 0.1f), Random.Range(0.02f, 0.08f), Random.Range(0.02f, 0.08f), 1f);
            if (InkMode == 2) return new Color(Random.Range(0.25f, 0.4f), Random.Range(0.25f, 0.4f), Random.Range(0.27f, 0.42f), 1f);
            if (InkMode == 3) return new Color(Random.Range(0.85f, 1f), Random.Range(0f, 0.05f), Random.Range(0.02f, 0.06f), 1f);
            if (Random.value < 0.18f) return new Color(Random.Range(0.72f, 0.86f), Random.Range(0.02f, 0.05f), Random.Range(0.03f, 0.06f), 1f);
            float d = Random.Range(0.26f, 0.55f);
            return new Color(d, d * Random.Range(0f, 0.06f), d * Random.Range(0.02f, 0.1f), 1f);
        }
        static Color DarkBlood(float a)
        {
            if (InkMode == 1) return new Color(0.02f, 0.02f, 0.03f, a);
            if (InkMode == 2) return new Color(0.3f, 0.3f, 0.32f, a);
            if (InkMode == 3) return new Color(0.7f, 0f, 0.02f, a);
            return new Color(0.2f, 0.0f, 0.015f, a);
        }

        // Плёнка поверх экрана: брызги на «объектив» камеры при мощных ударах (рисует GameUI)
        public struct Splat { public Vector2 p; public float r, t, max; public Color c; public int seed; }
        public static readonly System.Collections.Generic.List<Splat> ScreenSplats = new System.Collections.Generic.List<Splat>();
        public static void ScreenSplat(int n, float power)
        {
            if (Game.I != null && (Game.I.S.blood <= 0.01f || !Game.I.S.screenBlood)) return;
            for (int i = 0; i < n && ScreenSplats.Count < 14; i++)
            {
                var sp = new Splat();
                // ближе к краям кадра, чтобы не закрывать бой
                float ang = Random.value * Mathf.PI * 2f;
                sp.p = new Vector2(0.5f + Mathf.Cos(ang) * Random.Range(0.32f, 0.5f), 0.5f + Mathf.Sin(ang) * Random.Range(0.3f, 0.48f));
                sp.r = Random.Range(0.04f, 0.1f) * power;
                sp.max = sp.t = Random.Range(1.6f, 2.8f);
                sp.c = BloodColor(); sp.c.a = 0.9f;
                sp.seed = Random.Range(0, 99999);
                ScreenSplats.Add(sp);
            }
        }
        public static void TickSplats(float dt)
        {
            for (int i = ScreenSplats.Count - 1; i >= 0; i--)
            {
                var sp = ScreenSplats[i]; sp.t -= dt; sp.p.y -= dt * 0.012f; // медленно стекают
                if (sp.t <= 0) ScreenSplats.RemoveAt(i); else ScreenSplats[i] = sp;
            }
        }

        // Кровавая дуга: лента капель вдоль траектории клинка — как в аниме-рубке
        public void BloodArc(Vector2 at, Vector2 dir, float power)
        {
            if (Rec != null) Rec(18, at, dir, power, Color.red);
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) return;
            dir = dir.sqrMagnitude > 0.001f ? dir.normalized : Vector2.right;
            Vector2 perp = new Vector2(-dir.y, dir.x);
            if (perp.y < 0) perp = -perp;
            int n = Mathf.Clamp((int)(26 * power * mul), 8, 90);
            for (int i = 0; i < n; i++)
            {
                float k = i / (float)n;
                float a = Mathf.Lerp(-0.9f, 1.2f, k);
                Vector2 v = (dir * Mathf.Cos(a) + perp * Mathf.Sin(a)) * Random.Range(5f, 11f) * (0.7f + power * 0.3f);
                Emit(at + dir * (k - 0.5f) * 0.4f, v, BloodColor(), Random.Range(0.05f, 0.13f), Random.Range(0.9f, 1.8f), -20f, true, 0.6f, false, 1, 1, false, true);
            }
            Mist(at, dir, power);
        }

        // Тёмная кровавая взвесь
        public void Mist(Vector2 at, Vector2 dir, float power)
        {
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) return;
            int n = Mathf.Clamp((int)(6 * power * mul), 2, 18);
            for (int i = 0; i < n; i++)
                Emit(at + Random.insideUnitCircle * 0.15f, dir.normalized * Random.Range(0.5f, 2.5f) + Random.insideUnitCircle * 0.8f, DarkBlood(Random.Range(0.25f, 0.45f)), Random.Range(0.4f, 0.9f) * Mathf.Sqrt(power), Random.Range(0.5f, 1.1f), -0.6f, false, 2.5f, true);
        }

        // Брызги крови
        public void Blood(Vector2 at, Vector2 dir, float amount)
        {
            if (Rec != null) Rec(1, at, dir, amount, Color.red);
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) { Sparks(at, dir, 4, new Color(0.3f, 0.3f, 0.3f)); return; }
            int n = Mathf.Clamp((int)(amount * 2.2f * mul), 2, 160);
            Vector2 dn = dir.sqrMagnitude > 0.001f ? dir.normalized : Vector2.up;
            for (int i = 0; i < n; i++)
            {
                // основной конус — быстрые вытянутые капли-штрихи
                bool fast = i % 3 != 0;
                Vector2 v = (dn * Random.Range(2f, fast ? 13f : 7f) + Random.insideUnitCircle * (fast ? 2f : 3.5f) + Vector2.up * Random.Range(0.5f, 4f)) * Random.Range(0.5f, 1.2f);
                Emit(at + Random.insideUnitCircle * 0.08f, v, BloodColor(), Random.Range(0.04f, fast ? 0.12f : 0.18f), Random.Range(0.8f, 2.2f), -22f, true, 0.4f, false, 1, 1, false, fast);
            }
            // крупные густые сгустки
            for (int i = 0; i < Mathf.Max(1, n / 12); i++)
                Emit(at, dn * Random.Range(1.5f, 4f) + Vector2.up * Random.Range(1f, 3f), DarkBlood(1f), Random.Range(0.16f, 0.26f), 2f, -24f, true, 0.2f, false);
            // мелкая взвесь
            for (int i = 0; i < n / 4; i++)
                Emit(at, (dn * Random.Range(1f, 4f) + Random.insideUnitCircle * 2f), DarkBlood(0.55f), Random.Range(0.15f, 0.35f), Random.Range(0.2f, 0.45f), -4f, false, 3f, true, 1, 1, true);
            if (amount >= 30) Mist(at, dn, amount / 30f);
        }


        public void Fountain(Vector2 at, Vector2 dir, int n)
        {
            if (Rec != null) Rec(13, at, dir, n, Color.red);
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) return;
            n = Mathf.Max(1, (int)(n * mul));
            for (int i = 0; i < n; i++)
            {
                Vector2 v = dir.normalized * Random.Range(3f, 7f) + Random.insideUnitCircle * 1.2f;
                Emit(at, v, BloodColor(), Random.Range(0.05f, 0.12f), 2f, -22f, true, 0.3f, false, 1, 1, false, true);
            }
        }

        public void Drip(Vector2 at)
        {
            if (Rec != null) Rec(14, at, Vector2.zero, 0, Color.red);
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) return;
            Emit(at, new Vector2(Random.Range(-0.3f, 0.3f), -0.5f), BloodColor(), Random.Range(0.04f, 0.08f), 3f, -18f, true, 0.2f, false);
        }

        public void Sparks(Vector2 at, Vector2 dir, int n, Color c)
        {
            if (Rec != null) Rec(12, at, dir, n, c);
            for (int i = 0; i < n; i++)
            {
                Vector2 v = dir.normalized * Random.Range(3f, 10f) + Random.insideUnitCircle * 5f;
                Emit(at, v, c, Random.Range(0.04f, 0.09f), Random.Range(0.15f, 0.4f), -15f, false, 2f, true, 1, 1, true);
            }
        }

        public void Smoke(Vector2 at, int n, Color c, float spread = 0.4f, float size = 0.5f)
        {
            if (Rec != null) Rec(9, at, new Vector2(spread, size), n, c);
            for (int i = 0; i < n; i++)
                Emit(at + Random.insideUnitCircle * spread, Random.insideUnitCircle * 1.2f + Vector2.up * 0.6f, c, Random.Range(size * 0.6f, size * 1.3f), Random.Range(0.4f, 0.9f), 0.5f, false, 2f, true);
        }

        public void Dust(Vector2 at, int n)
        {
            if (Rec != null) Rec(7, at, Vector2.zero, n, Color.white);
            for (int i = 0; i < n; i++)
            {
                float sgn = Random.value < 0.5f ? -1 : 1;
                Emit(at + new Vector2(Random.Range(-0.3f, 0.3f), 0.05f), new Vector2(sgn * Random.Range(1f, 4f), Random.Range(0.2f, 1.5f)), new Color(0.6f, 0.58f, 0.55f, 0.5f), Random.Range(0.2f, 0.45f), Random.Range(0.3f, 0.6f), 0f, false, 3f, true);
            }
        }

        public void Fire(Vector2 at, int n, float spread = 0.2f)
        {
            if (Rec != null) Rec(8, at, new Vector2(spread, 0), n, Color.white);
            for (int i = 0; i < n; i++)
            {
                var c = Color.Lerp(new Color(1f, 0.85f, 0.2f), new Color(1f, 0.25f, 0.05f), Random.value);
                Emit(at + Random.insideUnitCircle * spread, Random.insideUnitCircle * 0.8f + Vector2.up * Random.Range(1f, 2.5f), c, Random.Range(0.12f, 0.3f), Random.Range(0.25f, 0.55f), 2f, false, 1f, true, 1, 1, true);
            }
        }

        public void Explosion(Vector2 at, float r)
        {
            if (Rec != null) Rec(10, at, Vector2.zero, r, Color.white);
            for (int i = 0; i < 40; i++)
            {
                var c = Color.Lerp(new Color(1f, 0.9f, 0.3f), new Color(1f, 0.3f, 0.05f), Random.value);
                Emit(at, Random.insideUnitCircle * r * 7f, c, Random.Range(0.25f, 0.6f), Random.Range(0.25f, 0.6f), 0f, false, 4f, true, 1, 1, true);
            }
            Smoke(at, 20, new Color(0.2f, 0.2f, 0.2f, 0.6f), r * 0.6f, 0.9f);
        }

        public void Stain(Vector2 at, float w, float h, Color c, float grow = 0, float maxW = 0)
        {
            var s = new S();
            s.pos = at; s.w = w; s.h = h; s.col = c; s.col0 = c; s.grow = grow; s.maxW = maxW > 0 ? maxW : w;
            s.rot = Random.Range(-0.12f, 0.12f);
            ss[sHead] = s;
            sHead = (sHead + 1) % MAXS;
            sCount = Mathf.Min(sCount + 1, MAXS);
            sDirty = true;
        }

        public void Pool(Vector2 at, float maxW)
        {
            if (Rec != null) Rec(17, at, Vector2.zero, maxW, Color.red);
            if (Game.I != null && Game.I.S.blood <= 0.01f) return;
            Stain(new Vector2(at.x, groundY + 0.015f), 0.1f, 0.08f, DarkBlood(0.97f), 0.5f, maxW * Game.I.S.blood);
            // влажный блик поверх лужи
            Stain(new Vector2(at.x + 0.05f, groundY + 0.02f), 0.05f, 0.03f, new Color(0.45f, 0.02f, 0.04f, 0.8f), 0.2f, maxW * 0.45f * Game.I.S.blood);
        }

        public void Tick(float dt)
        {
            if (dt <= 0) return;
            for (int i = 0; i < MAXP; i++)
            {
                if (!ps[i].alive) continue;
                var p = ps[i];
                p.life -= dt;
                if (p.life <= 0) { p.alive = false; ps[i] = p; continue; }
                p.vel.y += p.grav * dt;
                p.vel *= 1f / (1f + p.drag * dt);
                p.pos += p.vel * dt;
                if (p.stain)
                {
                    if (p.pos.y <= groundY)
                    {
                        float sz = p.size * Random.Range(1.5f, 3.2f);
                        float spd = Mathf.Abs(p.vel.x);
                        // быстрые капли размазываются полосой по направлению полёта, вокруг — мелкие брызги
                        Stain(new Vector2(p.pos.x, groundY + 0.01f), sz * (1.6f + Mathf.Min(spd * 0.25f, 2.5f)), sz * 0.33f, p.col);
                        if (sz > 0.18f && sCount < MAXS - 4)
                            for (int k = 0; k < 2; k++)
                                Stain(new Vector2(p.pos.x + Random.Range(-0.35f, 0.35f) * sz * 3f, groundY + 0.012f), sz * 0.35f, sz * 0.12f, p.col);
                        p.alive = false;
                    }
                    else if (Mathf.Abs(p.pos.x) >= W + 0.2f)
                    {
                        float sz = p.size * Random.Range(1.2f, 2.5f);
                        Stain(new Vector2(Mathf.Sign(p.pos.x) * (W + 0.2f), p.pos.y), sz * 0.5f, sz * 1.4f, p.col);
                        // потёк по стене
                        int last = (sHead - 1 + MAXS) % MAXS;
                        ss[last].dripMax = Random.Range(0.4f, 1.6f);
                        p.alive = false;
                    }
                }
                else if (p.pos.y < groundY)
                {
                    if (p.sy > 3f) p.alive = false; // дождь
                    else if (p.grav < 0) { p.pos.y = groundY; p.vel.y *= -0.3f; p.vel.x *= 0.6f; }
                }
                ps[i] = p;
            }
            dryT += dt;
            bool dry = dryT > 0.5f;
            if (dry) dryT = 0f;
            for (int i = 0; i < sCount; i++)
            {
                if (ss[i].grow > 0 && ss[i].w < ss[i].maxW)
                {
                    ss[i].w = Mathf.Min(ss[i].maxW, ss[i].w + ss[i].grow * dt);
                    ss[i].h = Mathf.Min(0.16f, ss[i].w * 0.12f);
                    sDirty = true;
                }
                if (ss[i].dripMax > 0 && ss[i].h < ss[i].dripMax)
                {
                    float g = dt * 0.35f;
                    ss[i].h += g; ss[i].pos.y -= g * 0.5f;
                    if (ss[i].pos.y - ss[i].h * 0.5f < groundY) ss[i].dripMax = 0;
                    sDirty = true;
                }
                if (dry)
                {
                    // кровь засыхает: темнеет до почти чёрно-бурой
                    ss[i].age += 0.5f;
                    float k = Mathf.Clamp01(ss[i].age / 25f);
                    Color c0 = ss[i].col0;
                    ss[i].col = Color.Lerp(c0, new Color(c0.r * 0.45f, c0.g * 0.4f, c0.b * 0.45f, c0.a), k);
                    sDirty = true;
                }
            }
        }

        void LateUpdate()
        {
            for (int i = 0; i < MAXP; i++)
            {
                int k = i * 4;
                if (!ps[i].alive)
                {
                    pv[k] = pv[k + 1] = pv[k + 2] = pv[k + 3] = Vector3.zero;
                    continue;
                }
                var p = ps[i];
                float t = p.life / p.max;
                float s = p.size * (p.shrink ? Mathf.Lerp(0.2f, 1f, t) : 1f);
                if (p.streak)
                {
                    // капля вытягивается вдоль скорости — штрих, а не кружок
                    float sp = p.vel.magnitude;
                    Vector2 d = sp > 0.01f ? p.vel / sp : Vector2.up;
                    Vector2 n = new Vector2(-d.y, d.x);
                    float len = s * (1f + Mathf.Min(sp * 0.09f, 3.5f)) * 0.5f, wid = s * 0.42f;
                    Vector2 a0 = p.pos - d * len, a1 = p.pos + d * len;
                    pv[k] = a0 - n * wid; pv[k + 1] = a0 + n * wid; pv[k + 2] = a1 + n * wid; pv[k + 3] = a1 - n * wid;
                }
                else
                {
                    float hx = s * p.sx * 0.5f, hy = s * p.sy * 0.5f;
                    pv[k] = new Vector3(p.pos.x - hx, p.pos.y - hy);
                    pv[k + 1] = new Vector3(p.pos.x - hx, p.pos.y + hy);
                    pv[k + 2] = new Vector3(p.pos.x + hx, p.pos.y + hy);
                    pv[k + 3] = new Vector3(p.pos.x + hx, p.pos.y - hy);
                }
                Color c = p.col;
                if (p.fade) c.a *= Mathf.Clamp01(t * 1.5f);
                pc[k] = pc[k + 1] = pc[k + 2] = pc[k + 3] = c;
            }
            pm.vertices = pv; pm.colors = pc;

            if (sDirty)
            {
                sDirty = false;
                for (int i = 0; i < MAXS; i++)
                {
                    int k = i * 4;
                    if (i >= sCount) { sv[k] = sv[k + 1] = sv[k + 2] = sv[k + 3] = Vector3.zero; continue; }
                    var s = ss[i];
                    float hx = s.w * 0.5f, hy = s.h * 0.5f;
                    float cr = Mathf.Cos(s.rot * 0.15f), sr = Mathf.Sin(s.rot * 0.15f);
                    Vector2 ax = new Vector2(cr, sr) * hx, ay = new Vector2(-sr, cr) * hy;
                    sv[k] = s.pos - ax - ay; sv[k + 1] = s.pos - ax + ay; sv[k + 2] = s.pos + ax + ay; sv[k + 3] = s.pos + ax - ay;
                    sc[k] = sc[k + 1] = sc[k + 2] = sc[k + 3] = s.col;
                }
                sm.vertices = sv; sm.colors = sc;
            }
        }
    }
}
