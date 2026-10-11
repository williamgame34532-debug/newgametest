using System.Collections.Generic;
using UnityEngine;

// Тело SCP-682: один гладкий скинированный меш по скелету QuadScp (хвост → таз → грудь → шея → голова, челюсть, лапы).
// Сечение — суперэллипс с костными бляшками на спине и поперечными щитками на брюхе; текстура — чешуя (ячейки Вороного),
// тёмная спина, светлее брюхо, свежие раны и мясо в разрывах (объект постоянно регенерирует).
public static class Scp682Body
{
    class G
    {
        public readonly List<Vector3> v = new List<Vector3>(), n = new List<Vector3>();
        public readonly List<Vector2> uv = new List<Vector2>();
        public readonly List<BoneWeight> w = new List<BoneWeight>();
        public readonly List<int> t = new List<int>();
        public readonly List<int> weld = new List<int>();
    }

    static float Smooth(float a, float b, float x) { float k = Mathf.Clamp01((x - a) / (b - a)); return k * k * (3f - 2f * k); }
    static float SPow(float x, float e) => Mathf.Sign(x) * Mathf.Pow(Mathf.Abs(x), e);

    static Vector3 CR(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, float t)
    {
        float t2 = t * t, t3 = t2 * t;
        return 0.5f * (2f * p1 + (-p0 + p2) * t + (2f * p0 - 5f * p1 + 4f * p2 - p3) * t2 + (-p0 + 3f * p1 - 3f * p2 + p3) * t3);
    }

    // Трубка: кольца по центрам c, оси сечения N (боковая) и B (вертикальная), радиусы rx/ry, веса по кольцу
    static void Tube(G g, Vector3[] c, Vector3[] side, float[] rx, float[] ry, BoneWeight[] bw, int seg, System.Func<int, float, float> mod, float uvScale, bool capStart, bool capEnd, float sq = 0.85f)
    {
        int m = c.Length, start = g.v.Count;
        float len = 0f;
        for (int i = 0; i < m; i++)
        {
            if (i > 0) len += (c[i] - c[i - 1]).magnitude;
            Vector3 T = (c[Mathf.Min(i + 1, m - 1)] - c[Mathf.Max(i - 1, 0)]).normalized;
            Vector3 N = Vector3.ProjectOnPlane(side[i], T).normalized;
            Vector3 B = Vector3.Cross(T, N).normalized;   // для T вперёд и N вправо — вверх
            if (Vector3.Dot(B, Vector3.up) < 0) B = -B;
            int first = -1;
            for (int k = 0; k <= seg; k++)
            {
                float a = k / (float)seg * Mathf.PI * 2f;
                float md = mod != null ? mod(i, a) : 1f;
                Vector3 p = c[i] + (N * SPow(Mathf.Cos(a), sq) * rx[i] + B * SPow(Mathf.Sin(a), sq) * ry[i]) * md;
                g.v.Add(p); g.n.Add(Vector3.zero); g.uv.Add(new Vector2(k / (float)seg * 2f, len * uvScale)); g.w.Add(bw[i]);
                g.weld.Add(k == seg ? first : -1);
                if (k == 0) first = g.v.Count - 1;
            }
        }
        int row = seg + 1;
        for (int i = 0; i + 1 < m; i++)
        {
            Vector3 inside = (c[i] + c[i + 1]) * 0.5f;
            for (int k = 0; k < seg; k++)
            {
                int a = start + i * row + k, b = a + 1, cc = a + row, d = cc + 1;
                Tri(g, a, cc, b, inside); Tri(g, b, cc, d, inside);
            }
        }
        void Cap(int ri, Vector3 inside)
        {
            int ctr = g.v.Count;
            g.v.Add(c[ri]); g.n.Add(Vector3.zero); g.uv.Add(new Vector2(1f, ri == 0 ? 0 : len * uvScale)); g.w.Add(bw[ri]); g.weld.Add(-1);
            for (int k = 0; k < seg; k++) Tri(g, ctr, start + ri * row + k, start + ri * row + k + 1, inside);
        }
        if (capStart && m > 1) Cap(0, c[1]);
        if (capEnd && m > 1) Cap(m - 1, c[m - 2]);
    }

    static void Tri(G g, int a, int b, int c, Vector3 inside)
    {
        Vector3 nn = Vector3.Cross(g.v[b] - g.v[a], g.v[c] - g.v[a]);
        Vector3 mid = (g.v[a] + g.v[b] + g.v[c]) / 3f;
        if (Vector3.Dot(nn, mid - inside) < 0) { int x = b; b = c; c = x; }
        g.t.Add(a); g.t.Add(b); g.t.Add(c);
    }

    static BoneWeight W2(int b0, int b1, float k) => new BoneWeight { boneIndex0 = b0, weight0 = 1f - k, boneIndex1 = b1, weight1 = k };

    static float Bumps(float s, float a)
    {
        // костные бляшки рядами по спине
        float row = Mathf.Sin(s * 90f) * 0.5f + 0.5f;
        float col = Mathf.Sin(a * 9f + Mathf.Floor(s * 90f / Mathf.PI) * 1.7f) * 0.5f + 0.5f;
        return Mathf.Pow(row * col, 3f);
    }

    public static void Make(Transform root, Transform pelvis, Transform chest, Transform neck, Transform head, Transform jaw,
                            Transform[] legU, Transform[] legL, Transform[] foot, List<Transform> tail, float w, float hl)
    {
        // кости меша: 0 таз, 1 грудь, 2 шея, 3 голова, 4 челюсть, 5..8 бёдра, 9..12 голени, 13..16 стопы, 17.. хвост
        var bones = new List<Transform> { pelvis, chest, neck, head, jaw };
        bones.AddRange(legU); bones.AddRange(legL); bones.AddRange(foot); bones.AddRange(tail);
        Vector3 L(Transform t) => root.InverseTransformPoint(t.position);
        var g = new G();

        // ---- хребет: от кончика хвоста к морде ----
        var chain = new List<int>();
        for (int i = tail.Count - 1; i >= 0; i--) chain.Add(17 + i);
        chain.Add(0); chain.Add(1); chain.Add(2); chain.Add(3);
        var cp = new List<Vector3>();
        Vector3 tipDir = tail.Count > 1 ? (L(tail[tail.Count - 1]) - L(tail[tail.Count - 2])).normalized : Vector3.back;
        cp.Add(L(tail[tail.Count - 1]) + tipDir * 0.42f);
        foreach (int bi in chain) cp.Add(L(bones[bi]));
        Vector3 snout = L(head) + new Vector3(0, 0.0f, hl * 1.05f);
        cp.Add(snout);
        // радиусы в контрольных точках (ширина, высота)
        int nTail = tail.Count;
        var crx = new List<float>(); var cry = new List<float>();
        crx.Add(0.025f); cry.Add(0.02f);
        for (int i = nTail - 1; i >= 0; i--) { float k = (i + 1f) / (nTail + 1f); crx.Add(Mathf.Lerp(w * 0.58f, w * 0.12f, k)); cry.Add(Mathf.Lerp(w * 0.5f, w * 0.1f, k)); }
        crx.Add(w * 0.68f); cry.Add(w * 0.62f);    // таз
        crx.Add(w * 0.8f); cry.Add(w * 0.74f);     // грудь — мощная
        crx.Add(w * 0.52f); cry.Add(w * 0.48f);    // шея
        crx.Add(w * 0.46f); cry.Add(w * 0.28f);    // затылок
        crx.Add(w * 0.2f); cry.Add(w * 0.1f);      // кончик морды
        int per = 7;
        var C = new List<Vector3>(); var RX = new List<float>(); var RY = new List<float>(); var BW = new List<BoneWeight>(); var S = new List<float>();
        int total = (cp.Count - 1) * per;
        for (int i = 0; i < cp.Count - 1; i++)
        {
            for (int k = 0; k < per; k++)
            {
                float t = k / (float)per;
                Vector3 p0 = cp[Mathf.Max(i - 1, 0)], p1 = cp[i], p2 = cp[i + 1], p3 = cp[Mathf.Min(i + 2, cp.Count - 1)];
                C.Add(CR(p0, p1, p2, p3, t));
                RX.Add(Mathf.Lerp(crx[i], crx[i + 1], Mathf.SmoothStep(0, 1, t)));
                RY.Add(Mathf.Lerp(cry[i], cry[i + 1], Mathf.SmoothStep(0, 1, t)));
                // кость: участок между контрольными i и i+1 принадлежит кости точки i (хвостовой стороне сустава)
                int bA = i == 0 ? chain[0] : chain[Mathf.Min(i - 1, chain.Count - 1)];
                int bB = chain[Mathf.Min(i, chain.Count - 1)];
                BW.Add(W2(bA, bB, Smooth(0.0f, 1.0f, t)));
                S.Add((i * per + k) / (float)total);
            }
        }
        C.Add(cp[cp.Count - 1]); RX.Add(crx[crx.Count - 1]); RY.Add(cry[cry.Count - 1]); BW.Add(W2(3, 3, 0)); S.Add(1f);
        var sides = new Vector3[C.Count];
        for (int i = 0; i < sides.Length; i++) sides[i] = Vector3.right;
        var Ca = C.ToArray(); var Sa = S.ToArray();
        Tube(g, Ca, sides, RX.ToArray(), RY.ToArray(), BW.ToArray(), 22, (i, a) =>
        {
            float s = Sa[i];
            float up = Mathf.Sin(a);                       // +1 спина, -1 брюхо
            float dorsal = Smooth(0.1f, 0.8f, up);
            float belly = Smooth(-0.2f, -0.8f, up);
            float bump = Bumps(s, a) * 0.09f * dorsal;
            float scutes = Mathf.Sin(s * 260f) * 0.015f * belly;
            float ribs = Mathf.Sin(s * 60f) * 0.02f * (1f - Mathf.Abs(up)) * Smooth(0.35f, 0.5f, s) * (1f - Smooth(0.62f, 0.7f, s));
            // гребень по хребту
            float crest = Mathf.Exp(-Mathf.Pow((a - Mathf.PI * 0.5f) * 5f, 2f)) * 0.12f * (0.6f + 0.4f * Mathf.Sin(s * 140f));
            return 1f + bump + scutes + ribs + crest * (1f - Smooth(0.82f, 0.9f, s));
        }, 2.5f, true, true, 0.8f);

        // ---- нижняя челюсть ----
        {
            Vector3 j0 = L(jaw) + new Vector3(0, -0.02f, -0.02f), j1 = L(head) + new Vector3(0, -0.07f, hl * 0.98f);
            int m = 10; var c = new Vector3[m]; var rx = new float[m]; var ry = new float[m]; var bw = new BoneWeight[m]; var sd = new Vector3[m];
            for (int i = 0; i < m; i++)
            {
                float t = i / (m - 1f);
                c[i] = Vector3.Lerp(j0, j1, t) + Vector3.down * Mathf.Sin(t * Mathf.PI) * 0.015f;
                rx[i] = Mathf.Lerp(w * 0.38f, w * 0.17f, t); ry[i] = Mathf.Lerp(w * 0.14f, w * 0.06f, t);
                bw[i] = W2(4, 4, 0); sd[i] = Vector3.right;
            }
            Tube(g, c, sd, rx, ry, bw, 16, null, 2.5f, true, true, 0.8f);
        }

        // ---- лапы: бедро → колено → лодыжка → кисть с пальцами вперёд ----
        for (int li = 0; li < 4; li++)
        {
            bool front = li < 2;
            Vector3 a0 = L(legU[li]) + new Vector3(0, w * 0.12f, 0), a1 = L(legL[li]), a2 = L(foot[li]);
            Vector3 fwd = Vector3.forward;
            Vector3 toe = a2 + fwd * w * 0.42f + Vector3.down * 0.03f;
            Vector3 bend = (a1 + (front ? -fwd : fwd) * 0.05f);
            var pts = new[] { a0, Vector3.Lerp(a0, bend, 0.5f), bend, Vector3.Lerp(bend, a2, 0.5f), a2 + Vector3.up * 0.02f, Vector3.Lerp(a2, toe, 0.5f), toe };
            int m = pts.Length;
            var rx = new float[] { w * 0.5f, w * 0.42f, w * 0.3f, w * 0.24f, w * 0.2f, w * 0.23f, w * 0.15f };
            var ry = new float[] { w * 0.56f, w * 0.45f, w * 0.3f, w * 0.24f, w * 0.15f, w * 0.07f, w * 0.05f };
            var bw = new BoneWeight[] { W2(front ? 1 : 0, 5 + li, 0.6f), W2(5 + li, 5 + li, 0), W2(5 + li, 9 + li, 0.5f), W2(9 + li, 9 + li, 0), W2(9 + li, 13 + li, 0.5f), W2(13 + li, 13 + li, 0), W2(13 + li, 13 + li, 0) };
            var sd = new Vector3[m];
            for (int i = 0; i < m; i++) sd[i] = Vector3.forward;
            Tube(g, pts, sd, rx, ry, bw, 14, (i, a) => 1f + 0.05f * Mathf.Sin(a * 6f + i), 3f, true, true, 0.85f);
        }

        // нормали со сваркой шва
        for (int i = 0; i < g.t.Count; i += 3)
        {
            int a = g.t[i], b = g.t[i + 1], c = g.t[i + 2];
            Vector3 f = Vector3.Cross(g.v[b] - g.v[a], g.v[c] - g.v[a]);
            int ra = g.weld[a] >= 0 ? g.weld[a] : a, rb = g.weld[b] >= 0 ? g.weld[b] : b, rc = g.weld[c] >= 0 ? g.weld[c] : c;
            g.n[ra] += f; g.n[rb] += f; g.n[rc] += f;
        }
        for (int i = 0; i < g.n.Count; i++) g.n[i] = g.n[g.weld[i] >= 0 ? g.weld[i] : i].normalized;

        var mesh = new Mesh { name = "scp682" };
        if (g.v.Count > 65000) mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        mesh.SetVertices(g.v); mesh.SetNormals(g.n); mesh.SetUVs(0, g.uv);
        mesh.boneWeights = g.w.ToArray();
        mesh.SetTriangles(g.t, 0);
        var bp = new Matrix4x4[bones.Count];
        var go = new GameObject("body682");
        go.transform.SetParent(root, false);
        for (int i = 0; i < bones.Count; i++) bp[i] = bones[i].worldToLocalMatrix * go.transform.localToWorldMatrix;
        mesh.bindposes = bp;
        mesh.RecalculateTangents();
        mesh.RecalculateBounds();
        var smr = go.AddComponent<SkinnedMeshRenderer>();
        smr.sharedMesh = mesh;
        smr.bones = bones.ToArray();
        smr.rootBone = pelvis;
        smr.sharedMaterial = SkinMat();
        smr.updateWhenOffscreen = false;
        smr.localBounds = new Bounds(Vector3.zero, Vector3.one * 6f);
    }

    static Material skinMat;
    static Material SkinMat()
    {
        if (skinMat != null) return skinMat;
        const int N = 512;
        // ячейки Вороного: центры по сетке со сдвигом (бесшовно)
        int cells = 24;
        var pts = new Vector2[cells * cells];
        var rnd = new System.Random(682);
        for (int y = 0; y < cells; y++) for (int x = 0; x < cells; x++) pts[y * cells + x] = new Vector2((x + 0.15f + 0.7f * (float)rnd.NextDouble()) / cells, (y + 0.15f + 0.7f * (float)rnd.NextDouble()) / cells);
        var h = new float[N * N]; var col = new Color[N * N];
        Color back = new Color(0.17f, 0.18f, 0.11f), mid = new Color(0.27f, 0.25f, 0.15f), bellyC = new Color(0.42f, 0.37f, 0.25f), wound = new Color(0.45f, 0.06f, 0.05f), flesh = new Color(0.62f, 0.2f, 0.16f);
        for (int y = 0; y < N; y++)
            for (int x = 0; x < N; x++)
            {
                float u = (x + 0.5f) / N, v = (y + 0.5f) / N;
                int cx = Mathf.FloorToInt(u * cells), cy = Mathf.FloorToInt(v * cells);
                float d1 = 9f, d2 = 9f; int id = 0;
                for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++)
                {
                    int gx = (cx + ox + cells) % cells, gy = (cy + oy + cells) % cells;
                    Vector2 p = pts[gy * cells + gx] + new Vector2(cx + ox - gx, cy + oy - gy) / cells;
                    float d = (new Vector2(u, v) - p).magnitude * cells;
                    if (d < d1) { d2 = d1; d1 = d; id = gy * cells + gx; } else if (d < d2) d2 = d;
                }
                float edge = Mathf.Clamp01((d2 - d1) * 3f);              // 0 на границе ячеек
                float dome = Mathf.Clamp01(1f - d1 * 0.9f);
                h[y * N + x] = edge * 0.6f + dome * 0.4f;
                // u — вокруг тела: 0/2 сбоку, 0.5 спина, 1.5 брюхо (UV вокруг = 0..2)
                float around = Mathf.Sin(u * Mathf.PI * 2f);               // +1 спина, -1 брюхо
                Color c = Color.Lerp(mid, back, Mathf.Clamp01(around));
                c = Color.Lerp(c, bellyC, Mathf.Clamp01(-around * 1.3f));
                float tone = 0.85f + 0.3f * (float)((id * 2654435761u) % 1000) / 1000f;
                c *= tone * (0.55f + 0.45f * edge);
                // раны и рубцы
                float wn = Mathf.PerlinNoise(u * 6f + 3f, v * 6f + 9f), wn2 = Mathf.PerlinNoise(u * 21f, v * 21f);
                float wk = Mathf.Clamp01((wn - 0.68f) * 9f);
                c = Color.Lerp(c, Color.Lerp(wound, flesh, wn2), wk);
                if (wk > 0.5f) h[y * N + x] = 0.2f + wn2 * 0.3f;
                c.a = 1f; col[y * N + x] = c;
            }
        var albedo = new Texture2D(N, N, TextureFormat.RGBA32, true);
        albedo.SetPixels(col); albedo.wrapMode = TextureWrapMode.Repeat; albedo.anisoLevel = 4; albedo.Apply(true);
        var nrm = new Color[N * N];
        for (int y = 0; y < N; y++)
            for (int x = 0; x < N; x++)
            {
                float dx = h[y * N + (x + 1) % N] - h[y * N + (x + N - 1) % N];
                float dy = h[((y + 1) % N) * N + x] - h[((y + N - 1) % N) * N + x];
                Vector3 nn = new Vector3(-dx * 4f, -dy * 4f, 1f).normalized;
                nrm[y * N + x] = new Color(nn.x * 0.5f + 0.5f, nn.y * 0.5f + 0.5f, nn.z * 0.5f + 0.5f, 1f);
            }
        var nt = new Texture2D(N, N, TextureFormat.RGBA32, true, true);
        nt.SetPixels(nrm); nt.wrapMode = TextureWrapMode.Repeat; nt.Apply(true);
        skinMat = new Material(Mats.Std) { name = "scp682skin" };
        skinMat.mainTexture = albedo;
        skinMat.mainTextureScale = new Vector2(3f, 3f);
        skinMat.SetFloat("_Glossiness", 0.38f);
        Mats.AddNormal(skinMat, nt, 1.2f);
        skinMat.SetTextureScale("_BumpMap", new Vector2(3f, 3f));
        return skinMat;
    }
}
