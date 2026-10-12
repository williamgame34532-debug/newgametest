using System.Collections.Generic;
using UnityEngine;

// Геометрия рук от первого лица: рукав со складками, перчатка с пальцами в полухвате, ремешок на запястье,
// накладка на костяшках, часы на левой руке. Чистая математика (без Mesh) — собирается в меш в FPArms.
// Пространство руки в покое: плечо в нуле, рука вдоль -Y; кисть: X — ладонь (у левой), -Y — пальцы, Z — большой палец.
public class ArmGeo
{
    public const int SLEEVE = 0, GLOVE = 1, PAD = 2, WATCH = 3, SUBS = 4;
    public readonly List<Vector3> v = new List<Vector3>();
    public readonly List<Vector3> n = new List<Vector3>();
    public readonly List<Vector2> uv = new List<Vector2>();
    public readonly List<Vector3> w = new List<Vector3>();   // веса: плечо, предплечье, кисть
    public readonly List<int>[] sub = new List<int>[SUBS];
    readonly List<int> weld = new List<int>();
    public float L1, L2;
    public bool mirror;

    // центр «кольца» хвата (ось удерживаемого цевья/рукояти идёт через него вдоль Z кисти)
    public static readonly Vector3 Ring = new Vector3(0.074f, -0.084f, 0f);

    public delegate Vector3 WFn(int i, Vector3 p);
    public delegate float RFn(int i, float a);

    Vector3 Wrist => new Vector3(0, -L1 - L2, 0);
    Vector3 Elbow => new Vector3(0, -L1, 0);

    public ArmGeo(float l1, float l2, bool left)
    {
        L1 = l1; L2 = l2; mirror = !left;
        for (int i = 0; i < SUBS; i++) sub[i] = new List<int>();
    }

    int Add(Vector3 p, Vector2 t, Vector3 wt, int weldTo = -1)
    {
        if (mirror) p.x = -p.x;
        v.Add(p); uv.Add(t); w.Add(wt); n.Add(Vector3.zero);
        weld.Add(weldTo);
        return v.Count - 1;
    }

    // треугольник, развёрнутый наружу (от точки inside)
    void Tri(int s, int a, int b, int c, Vector3 inside)
    {
        if (mirror) inside.x = -inside.x;
        Vector3 nn = Vector3.Cross(v[b] - v[a], v[c] - v[a]);
        Vector3 mid = (v[a] + v[b] + v[c]) / 3f;
        if (Vector3.Dot(nn, mid - inside) < 0) { int t = b; b = c; c = t; }
        sub[s].Add(a); sub[s].Add(b); sub[s].Add(c);
    }

    static float SPow(float x, float e) => Mathf.Sign(x) * Mathf.Pow(Mathf.Abs(x), e);

    // Трубка вдоль ломаной c: сечение — суперэллипс (rx по опорной оси, rz поперёк), модуляция радиуса rm,
    // торцы закрываются полусферой (cap* — относительная длина купола, 0 — без крышки)
    public void Tube(int s, Vector3[] c, Vector3 refAxis, float[] rx, float[] rz, int seg, WFn wf, RFn rm = null,
                     float sq = 1f, float capStart = 0f, float capEnd = 0f, float uvScale = 10f)
    {
        int m = c.Length;
        var T = new Vector3[m]; var N = new Vector3[m]; var B = new Vector3[m];
        for (int i = 0; i < m; i++)
        {
            Vector3 d = c[Mathf.Min(i + 1, m - 1)] - c[Mathf.Max(i - 1, 0)];
            T[i] = d.normalized;
            Vector3 r = i == 0 ? refAxis : N[i - 1];
            Vector3 nn = r - Vector3.Dot(r, T[i]) * T[i];
            if (nn.sqrMagnitude < 1e-8f) nn = Vector3.Cross(T[i], Vector3.forward);
            N[i] = nn.normalized;
            B[i] = Vector3.Cross(T[i], N[i]);
        }
        // кольца: [купол начала] + основные + [купол конца]
        var rings = new List<(Vector3 c, Vector3 n, Vector3 b, float rx, float rz, int src, float k)>();
        const int capN = 4;
        if (capStart > 0)
            for (int j = capN; j >= 1; j--)
            {
                float ph = j / (float)capN * Mathf.PI * 0.5f;
                float rr = Mathf.Max(rx[0], rz[0]);
                rings.Add((c[0] - T[0] * Mathf.Sin(ph) * rr * capStart, N[0], B[0], rx[0], rz[0], 0, Mathf.Max(0.3f, Mathf.Cos(ph))));
            }
        for (int i = 0; i < m; i++) rings.Add((c[i], N[i], B[i], rx[i], rz[i], i, 1f));
        if (capEnd > 0)
            for (int j = 1; j <= capN; j++)
            {
                float ph = j / (float)capN * Mathf.PI * 0.5f;
                float rr = Mathf.Max(rx[m - 1], rz[m - 1]);
                rings.Add((c[m - 1] + T[m - 1] * Mathf.Sin(ph) * rr * capEnd, N[m - 1], B[m - 1], rx[m - 1], rz[m - 1], m - 1, Mathf.Max(0.3f, Mathf.Cos(ph))));
            }
        int start = v.Count;
        float len = 0f;
        float per = Mathf.PI * (rx[0] + rz[0]);
        for (int r = 0; r < rings.Count; r++)
        {
            var R = rings[r];
            if (r > 0) len += (R.c - rings[r - 1].c).magnitude;
            Vector3 wt = wf(R.src, R.c);
            int first = -1;
            for (int k = 0; k <= seg; k++)
            {
                float a = k / (float)seg * Mathf.PI * 2f;
                float mod = rm != null ? rm(R.src, a) : 1f;
                Vector3 p = R.c + (R.n * SPow(Mathf.Cos(a), sq) * R.rx + R.b * SPow(Mathf.Sin(a), sq) * R.rz) * mod * R.k;
                int idx = Add(p, new Vector2(k / (float)seg * per * uvScale, len * uvScale), wt, k == seg ? first : -1);
                if (k == 0) first = idx;
            }
        }
        int rowN = seg + 1;
        for (int r = 0; r + 1 < rings.Count; r++)
        {
            Vector3 inside = (rings[r].c + rings[r + 1].c) * 0.5f;
            for (int k = 0; k < seg; k++)
            {
                int a = start + r * rowN + k, b = a + 1, c2 = a + rowN, d = c2 + 1;
                Tri(s, a, c2, b, inside); Tri(s, b, c2, d, inside);
            }
        }
        // крышки-диски: центр + веер (без вырожденных треугольников — иначе битые касательные и чёрные точки)
        void Disc(int ringIdx, int nextIdx, float uvLen)
        {
            var R = rings[ringIdx];
            Vector3 inside = rings[nextIdx].c;
            int ctr = Add(R.c, new Vector2(per * uvScale * 0.5f, uvLen + 0.002f * uvScale), wf(R.src, R.c));
            int b0 = start + ringIdx * rowN;
            for (int k = 0; k < seg; k++) Tri(s, ctr, b0 + k, b0 + k + 1, inside);
        }
        if (capStart > 0 && rings.Count > 1) Disc(0, 1, 0f);
        if (capEnd > 0 && rings.Count > 1) Disc(rings.Count - 1, rings.Count - 2, len * uvScale);
    }

    // Коробка (часы): центр, оси, полуразмеры
    public void Box(int s, Vector3 ctr, Vector3 ax, Vector3 ay, Vector3 az, Vector3 half, Vector3 wt)
    {
        Vector3[] dirs = { ax, -ax, ay, -ay, az, -az };
        for (int f = 0; f < 6; f++)
        {
            Vector3 nrm = dirs[f];
            Vector3 u = f < 2 ? ay : f < 4 ? az : ax;
            Vector3 vv = f < 2 ? az : f < 4 ? ax : ay;
            float hn = f < 2 ? half.x : f < 4 ? half.y : half.z;
            float hu = f < 2 ? half.y : f < 4 ? half.z : half.x;
            float hv = f < 2 ? half.z : f < 4 ? half.x : half.y;
            Vector3 fc = ctr + nrm * hn;
            int i0 = Add(fc - u * hu - vv * hv, new Vector2(0, 0), wt);
            int i1 = Add(fc + u * hu - vv * hv, new Vector2(1, 0), wt);
            int i2 = Add(fc + u * hu + vv * hv, new Vector2(1, 1), wt);
            int i3 = Add(fc - u * hu + vv * hv, new Vector2(0, 1), wt);
            Tri(s, i0, i1, i2, ctr); Tri(s, i0, i2, i3, ctr);
        }
    }

    public void Normals()
    {
        for (int i = 0; i < n.Count; i++) n[i] = Vector3.zero;
        foreach (var list in sub)
            for (int t = 0; t < list.Count; t += 3)
            {
                int a = list[t], b = list[t + 1], c = list[t + 2];
                Vector3 f = Vector3.Cross(v[b] - v[a], v[c] - v[a]);
                n[R(a)] += f; n[R(b)] += f; n[R(c)] += f;
            }
        for (int i = 0; i < n.Count; i++) n[i] = n[R(i)].normalized;
    }
    int R(int i) => weld[i] >= 0 ? weld[i] : i;

    // ---------------- сборка руки ----------------
    static float Bell(float a, float b, float x) { float k = Mathf.Clamp01((x - a) / (b - a)); return Mathf.Sin(k * Mathf.PI); }
    static float Smooth(float a, float b, float x) { float k = Mathf.Clamp01((x - a) / (b - a)); return k * k * (3f - 2f * k); }

    static Vector3[] CatmullRom(Vector3[] p, int per)
    {
        var o = new List<Vector3>();
        for (int i = 0; i + 1 < p.Length; i++)
        {
            Vector3 p0 = p[Mathf.Max(i - 1, 0)], p1 = p[i], p2 = p[i + 1], p3 = p[Mathf.Min(i + 2, p.Length - 1)];
            for (int k = 0; k < per; k++)
            {
                float t = k / (float)per, t2 = t * t, t3 = t2 * t;
                o.Add(0.5f * (2f * p1 + (-p0 + p2) * t + (2f * p0 - 5f * p1 + 4f * p2 - p3) * t2 + (-p0 + 3f * p1 - 3f * p2 + p3) * t3));
            }
        }
        o.Add(p[p.Length - 1]);
        return o.ToArray();
    }

    public static ArmGeo Build(float l1, float l2, bool left, int detail = 1)
    {
        var g = new ArmGeo(l1, l2, left);
        int seg = 14 + detail * 4;
        Vector3 W = g.Wrist, E = g.Elbow;

        // ---- плечо (рукав) ----
        {
            int m = 16;
            var c = new Vector3[m]; var rx = new float[m]; var rz = new float[m];
            for (int i = 0; i < m; i++)
            {
                float t = i / (m - 1f);
                c[i] = new Vector3(0, 0.03f - (l1 + 0.05f) * t, 0);
                rx[i] = Mathf.Lerp(0.062f, 0.05f, t); rz[i] = Mathf.Lerp(0.066f, 0.053f, t);
            }
            g.Tube(SLEEVE, c, Vector3.right, rx, rz, seg,
                (i, p) => { float wl = Smooth(l1 - 0.05f, l1 + 0.03f, -p.y); return new Vector3(1f - wl, wl, 0); },
                (i, a) =>
                {
                    float y = -c[i].y;
                    float fold = Mathf.Sin(y * 70f + 1.6f * Mathf.Sin(a * 2f + 0.5f) + a) * (0.025f + 0.05f * Smooth(l1 - 0.1f, l1, y));
                    float seam = 1f - 0.012f * Mathf.Exp(-Mathf.Pow((a - 1.7f) * 9f, 2f));
                    return (1f + fold) * seam;
                }, 1f, 0.5f, 0f);
        }
        // ---- предплечье (рукав, у запястья собран складками над перчаткой) ----
        {
            int m = 22;
            var c = new Vector3[m]; var rx = new float[m]; var rz = new float[m];
            for (int i = 0; i < m; i++)
            {
                float t = i / (m - 1f);
                c[i] = E + new Vector3(0, 0.035f - (l2 - 0.005f) * t, 0);
                float bulk = 1f + 0.12f * Bell(-0.1f, 0.75f, t);
                rx[i] = Mathf.Lerp(0.05f, 0.038f, t) * bulk; rz[i] = Mathf.Lerp(0.054f, 0.044f, t) * bulk;
            }
            g.Tube(SLEEVE, c, Vector3.right, rx, rz, seg,
                (i, p) =>
                {
                    float y = -(p.y - E.y);
                    float wu = 1f - Smooth(-0.03f, 0.04f, y);
                    float wh = Smooth(l2 - 0.06f, l2, y) * 0.35f;
                    return new Vector3(wu, 1f - wu - wh, wh);
                },
                (i, a) =>
                {
                    float y = -(c[i].y - E.y);
                    float bunch = Smooth(l2 - 0.11f, l2 - 0.02f, y);
                    float elbowF = 1f - Smooth(0.02f, 0.08f, y);
                    float fold = Mathf.Sin(y * 85f + 1.8f * Mathf.Sin(a * 2f + 1.3f) + 0.7f * Mathf.Sin(a * 3f)) * (0.018f + 0.06f * bunch + 0.04f * elbowF);
                    float drape = 0.025f * Mathf.Sin(a * 2f + y * 9f);
                    return 1f + fold + drape;
                }, 1f, 0f, 0.35f);
        }

        // ---- перчатка ----
        Vector3 H(float x, float y, float z) => W + new Vector3(x, y, z);
        WFn wHand = (i, p) => new Vector3(0, 0, 1);
        // манжета: верх переходит в предплечье
        {
            int m = 8;
            var c = new Vector3[m]; var rx = new float[m]; var rz = new float[m];
            for (int i = 0; i < m; i++)
            {
                float t = i / (m - 1f);
                c[i] = H(0.002f, 0.055f - 0.07f * t, 0);
                rx[i] = Mathf.Lerp(0.035f, 0.029f, t); rz[i] = Mathf.Lerp(0.042f, 0.036f, t);
            }
            g.Tube(GLOVE, c, Vector3.right, rx, rz, seg, (i, p) => { float k = Smooth(0.0f, 0.04f, p.y - W.y) * 0.6f; return new Vector3(0, k, 1f - k); },
                (i, a) => 1f + 0.03f * Mathf.Sin(a * 5f + i) * (i < 3 ? 1f : 0.2f), 1f, 0.3f, 0f, 14f);
            // ремешок-липучка
            var cs = new[] { H(0.002f, 0.016f, 0), H(0.002f, 0.004f, 0), H(0.002f, -0.008f, 0) };
            g.Tube(PAD, cs, Vector3.right, new[] { 0.0335f, 0.034f, 0.0335f }, new[] { 0.0395f, 0.04f, 0.0395f }, seg,
                (i, p) => new Vector3(0, 0.15f, 0.85f), null, 0.8f, 0f, 0f, 14f);
        }
        // ладонь: от запястья к костяшкам, слегка согнута в хват
        float Cx(float t) => 0.002f + 0.03f * t * t;
        {
            int m = 12;
            var c = new Vector3[m]; var rx = new float[m]; var rz = new float[m];
            for (int i = 0; i < m; i++)
            {
                float t = -0.1f + 1.1f * i / (m - 1f);
                c[i] = H(Cx(Mathf.Max(0, t)), -0.092f * t, 0.002f);
                rx[i] = Mathf.Lerp(0.0165f, 0.0135f, Mathf.Clamp01(t)); rz[i] = Mathf.Lerp(0.03f, 0.044f, Smooth(0f, 0.85f, t));
            }
            g.Tube(GLOVE, c, Vector3.right, rx, rz, seg, wHand,
                (i, a) =>
                {
                    float t = -0.1f + 1.1f * i / (m - 1f);
                    // возвышение большого пальца (ладонь, сторона большого пальца) и мизинца
                    float thenar = 0.32f * Mathf.Exp(-Mathf.Pow((a - 0.75f) / 0.45f, 2f)) * Bell(0.05f, 0.75f, t);
                    float hypo = 0.18f * Mathf.Exp(-Mathf.Pow((a - 5.55f) / 0.4f, 2f)) * Bell(0.1f, 0.85f, t);
                    // тыльная сторона: сухожилия
                    float back = 0.03f * Mathf.Sin(a * 8f) * Mathf.Exp(-Mathf.Pow((a - 3.14f) / 0.8f, 2f)) * Bell(0.3f, 1f, t);
                    return 1f + thenar + hypo + back;
                }, 0.7f, 0f, 0.6f, 14f);
            // накладка на костяшках (тыл кисти)
            int pm = 7;
            var pc = new Vector3[pm]; var px = new float[pm]; var pz = new float[pm];
            for (int i = 0; i < pm; i++)
            {
                float zz = Mathf.Lerp(-0.038f, 0.04f, i / (pm - 1f));
                pc[i] = H(Cx(0.93f) - 0.0135f, -0.084f, zz);
                px[i] = 0.0055f; pz[i] = 0.013f;
            }
            g.Tube(PAD, pc, Vector3.right, px, pz, 10, wHand, null, 0.7f, 0.8f, 0.8f, 14f);
            // накладка тыла кисти
            var bc = new[] { H(Cx(0.25f) - 0.0145f, -0.025f, 0.002f), H(Cx(0.5f) - 0.0135f, -0.047f, 0.002f), H(Cx(0.7f) - 0.0125f, -0.066f, 0.002f) };
            g.Tube(PAD, bc, Vector3.right, new[] { 0.004f, 0.0045f, 0.004f }, new[] { 0.022f, 0.028f, 0.03f }, 12, wHand, null, 0.6f, 0.4f, 0.4f, 14f);
        }
        // пальцы — по дуге вокруг оси хвата
        {
            Vector3 C = Ring;
            float[] zs = { 0.03f, 0.0095f, -0.0105f, -0.0295f };
            float[] dy = { 0.002f, -0.003f, -0.001f, 0.007f };
            float[][] ph = { new[] { 0.043f, 0.026f, 0.021f }, new[] { 0.047f, 0.029f, 0.022f }, new[] { 0.044f, 0.027f, 0.021f }, new[] { 0.035f, 0.021f, 0.019f } };
            float[] rad = { 0.0102f, 0.0106f, 0.0101f, 0.0089f };
            for (int f = 0; f < 4; f++)
            {
                Vector3 b = H(Cx(1f) + 0.002f, -0.088f + dy[f], zs[f]) - W;
                float rf = Mathf.Max(0.04f, new Vector2(b.x - C.x, b.y - C.y).magnitude);
                float th0 = Mathf.Atan2(b.y - C.y, b.x - C.x);
                float curl = (!left && f == 0) ? 0.6f : 1.32f;           // указательный правой — на спуске
                var pts = new List<Vector3> { b + new Vector3(-0.012f, 0.014f, 0), b };
                Vector3 p = b; float acc = 0f;
                float baseDir = th0 + Mathf.PI * 0.5f;                   // касательная к окружности (по росту угла)
                foreach (float L in ph[f])
                {
                    float d = 2f * Mathf.Asin(Mathf.Clamp(L / (2f * rf), -1f, 1f));
                    float ang = baseDir + (acc + d * 0.5f) * curl;
                    p += new Vector3(Mathf.Cos(ang), Mathf.Sin(ang), 0) * L;
                    pts.Add(p);
                    acc += d;
                }
                var cl = CatmullRom(pts.ToArray(), 4);
                var rx = new float[cl.Length]; var rz = new float[cl.Length];
                // длина вдоль пальца для утолщений в суставах
                float tot = 0; var sl = new float[cl.Length];
                for (int i = 1; i < cl.Length; i++) { tot += (cl[i] - cl[i - 1]).magnitude; sl[i] = tot; }
                float j1 = (pts[1] - pts[0]).magnitude + ph[f][0], j2 = j1 + ph[f][1];
                for (int i = 0; i < cl.Length; i++)
                {
                    float k = sl[i] / tot;
                    float r = rad[f] * Mathf.Lerp(1.02f, 0.82f, k) * (1f + 0.07f * Mathf.Exp(-Mathf.Pow((sl[i] - j1) / 0.006f, 2f)) + 0.06f * Mathf.Exp(-Mathf.Pow((sl[i] - j2) / 0.005f, 2f)));
                    rx[i] = r * 1.06f; rz[i] = r * 0.93f;
                    cl[i] += W;
                }
                g.Tube(GLOVE, cl, Vector3.forward, rx, rz, 12, wHand, null, 1f, 0f, 1f, 14f);
                // накладки на основных фалангах (тыл пальца)
                Vector3 m0 = Vector3.Lerp(pts[1], pts[2], 0.55f);
                Vector3 dir = (pts[2] - pts[1]).normalized;
                Vector3 outw = new Vector3(-dir.y, dir.x, 0) * -1f;      // наружу от оси хвата
                if (Vector3.Dot(outw, (Vector3)new Vector2(m0.x - C.x, m0.y - C.y)) < 0) outw = -outw;
                var padC = new[] { W + m0 - dir * 0.011f + outw * rad[f] * 0.95f, W + m0 + outw * rad[f] * 1.0f, W + m0 + dir * 0.011f + outw * rad[f] * 0.95f };
                g.Tube(PAD, padC, outw, new[] { 0.0032f, 0.0036f, 0.0032f }, new[] { rad[f] * 0.75f, rad[f] * 0.8f, rad[f] * 0.75f }, 8, wHand, null, 0.6f, 0.9f, 0.9f, 14f);
            }
            // большой палец: из основания ладони через верх рукояти на дальнюю сторону
            var tp = new[] { H(0.01f, -0.03f, 0.014f), H(0.03f, -0.042f, 0.034f), H(0.064f, -0.046f, 0.05f), H(0.097f, -0.059f, 0.058f), H(0.113f, -0.085f, 0.062f) };
            var tc = CatmullRom(tp, 4);
            var trx = new float[tc.Length]; var trz = new float[tc.Length];
            for (int i = 0; i < tc.Length; i++)
            {
                float k = i / (tc.Length - 1f);
                float r = Mathf.Lerp(0.019f, 0.0098f, Mathf.Pow(k, 0.6f)) * (1f + 0.06f * Mathf.Exp(-Mathf.Pow((k - 0.62f) / 0.07f, 2f)));
                trx[i] = r * 1.05f; trz[i] = r * 0.92f;
            }
            g.Tube(GLOVE, tc, new Vector3(0.3f, 0.6f, -1f).normalized, trx, trz, 12, wHand, null, 1f, 0f, 1f, 14f);
        }
        // ---- часы на левом запястье (поверх рукава, тыльная сторона) ----
        if (left)
        {
            float y0 = 0.062f;
            var sc = new[] { H(0.002f, y0 + 0.008f, 0), H(0.002f, y0, 0), H(0.002f, y0 - 0.008f, 0) };
            g.Tube(WATCH, sc, Vector3.right, new[] { 0.0385f, 0.039f, 0.0385f }, new[] { 0.0465f, 0.047f, 0.0465f }, seg,
                (i, p) => new Vector3(0, 0.75f, 0.25f), null, 0.85f, 0f, 0f, 14f);
            g.Box(WATCH, H(-0.043f, y0, 0.0f), Vector3.right, Vector3.up, Vector3.forward, new Vector3(0.0075f, 0.0175f, 0.0195f), new Vector3(0, 0.75f, 0.25f));
            g.Box(WATCH, H(-0.0508f, y0, 0.0f), Vector3.right, Vector3.up, Vector3.forward, new Vector3(0.0006f, 0.0145f, 0.016f), new Vector3(0, 0.75f, 0.25f));
        }
        g.Normals();
        return g;
    }
}
