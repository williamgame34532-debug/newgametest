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
            public bool stain, fade, shrink, alive;
        }

        struct S
        {
            public Vector2 pos;
            public float w, h, grow, maxW, rot;
            public Color col;
        }

        const int MAXP = 3500, MAXS = 2600;
        P[] ps = new P[MAXP];
        int pHead;
        S[] ss = new S[MAXS];
        int sCount, sHead;
        bool sDirty;

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

        public void Emit(Vector2 pos, Vector2 vel, Color col, float size, float life, float grav, bool stain, float drag = 0.5f, bool fade = true, float sx = 1, float sy = 1, bool shrink = false)
        {
            var p = new P();
            p.pos = pos; p.vel = vel; p.col = col; p.size = size; p.life = life; p.max = life;
            p.grav = grav; p.stain = stain; p.drag = drag; p.fade = fade; p.sx = sx; p.sy = sy; p.alive = true; p.shrink = shrink;
            ps[pHead] = p;
            pHead = (pHead + 1) % MAXP;
        }

        public static int InkMode; // 0 кровь, 1 чёрная тушь, 2 графит
        public static Color BloodColor()
        {
            if (InkMode == 1) return new Color(Random.Range(0.02f, 0.1f), Random.Range(0.02f, 0.08f), Random.Range(0.02f, 0.08f), 1f);
            if (InkMode == 2) return new Color(Random.Range(0.25f, 0.4f), Random.Range(0.25f, 0.4f), Random.Range(0.27f, 0.42f), 1f);
            return new Color(Random.Range(0.45f, 0.72f), Random.Range(0f, 0.04f), Random.Range(0f, 0.03f), 1f);
        }

        // Брызги крови
        public void Blood(Vector2 at, Vector2 dir, float amount)
        {
            if (Rec != null) Rec(1, at, dir, amount, Color.red);
            float mul = Game.I != null ? Game.I.S.blood : 1f;
            if (mul <= 0.01f) { Sparks(at, dir, 4, new Color(0.3f, 0.3f, 0.3f)); return; }
            int n = Mathf.Clamp((int)(amount * 2.2f * mul), 2, 160);
            for (int i = 0; i < n; i++)
            {
                Vector2 v = (dir.normalized * Random.Range(2f, 9f) + Random.insideUnitCircle * 3.5f + Vector2.up * Random.Range(0.5f, 4f)) * Random.Range(0.5f, 1.2f);
                Emit(at + Random.insideUnitCircle * 0.08f, v, BloodColor(), Random.Range(0.05f, 0.16f), Random.Range(0.8f, 2.2f), -22f, true, 0.4f, false);
            }
            // мелкая пыль крови
            for (int i = 0; i < n / 3; i++)
                Emit(at, (dir.normalized * Random.Range(1f, 4f) + Random.insideUnitCircle * 2f), Draw.A(BloodColor(), 0.6f), Random.Range(0.15f, 0.35f), Random.Range(0.15f, 0.35f), -4f, false, 3f, true, 1, 1, true);
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
                Emit(at, v, BloodColor(), Random.Range(0.05f, 0.12f), 2f, -22f, true, 0.3f, false);
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
            s.pos = at; s.w = w; s.h = h; s.col = c; s.grow = grow; s.maxW = maxW > 0 ? maxW : w;
            s.rot = Random.Range(-0.2f, 0.2f);
            ss[sHead] = s;
            sHead = (sHead + 1) % MAXS;
            sCount = Mathf.Min(sCount + 1, MAXS);
            sDirty = true;
        }

        public void Pool(Vector2 at, float maxW)
        {
            if (Rec != null) Rec(17, at, Vector2.zero, maxW, Color.red);
            if (Game.I != null && Game.I.S.blood <= 0.01f) return;
            Stain(new Vector2(at.x, groundY + 0.015f), 0.1f, 0.08f, new Color(0.42f, 0.0f, 0.02f, 0.95f), 0.5f, maxW * Game.I.S.blood);
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
                        Stain(new Vector2(p.pos.x, groundY + 0.01f), sz * 1.6f, sz * 0.35f, p.col);
                        p.alive = false;
                    }
                    else if (Mathf.Abs(p.pos.x) >= W + 0.2f)
                    {
                        float sz = p.size * Random.Range(1.2f, 2.5f);
                        Stain(new Vector2(Mathf.Sign(p.pos.x) * (W + 0.2f), p.pos.y), sz * 0.5f, sz * 1.4f, p.col);
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
            for (int i = 0; i < sCount; i++)
            {
                if (ss[i].grow > 0 && ss[i].w < ss[i].maxW)
                {
                    ss[i].w = Mathf.Min(ss[i].maxW, ss[i].w + ss[i].grow * dt);
                    ss[i].h = Mathf.Min(0.16f, ss[i].w * 0.12f);
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
                float hx = s * p.sx * 0.5f, hy = s * p.sy * 0.5f;
                pv[k] = new Vector3(p.pos.x - hx, p.pos.y - hy);
                pv[k + 1] = new Vector3(p.pos.x - hx, p.pos.y + hy);
                pv[k + 2] = new Vector3(p.pos.x + hx, p.pos.y + hy);
                pv[k + 3] = new Vector3(p.pos.x + hx, p.pos.y - hy);
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
                    sv[k] = new Vector3(s.pos.x - hx, s.pos.y - hy);
                    sv[k + 1] = new Vector3(s.pos.x - hx, s.pos.y + hy);
                    sv[k + 2] = new Vector3(s.pos.x + hx, s.pos.y + hy);
                    sv[k + 3] = new Vector3(s.pos.x + hx, s.pos.y - hy);
                    sc[k] = sc[k + 1] = sc[k + 2] = sc[k + 3] = s.col;
                }
                sm.vertices = sv; sm.colors = sc;
            }
        }
    }
}
