using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Процедурная графика: материалы, спрайты, линии, полигоны.
    public static class Draw
    {
        static Material _line, _gl, _particle;
        static Texture2D _circleTex, _softTex, _white;
        static Sprite _circle, _soft, _square;

        public static Material LineMat
        {
            get
            {
                if (_line == null) _line = new Material(Shader.Find("Sprites/Default"));
                return _line;
            }
        }

        public static Material ParticleMat
        {
            get
            {
                if (_particle == null) { _particle = new Material(Shader.Find("Sprites/Default")); _particle.mainTexture = CircleTex; }
                return _particle;
            }
        }

        public static Material GLMat
        {
            get
            {
                if (_gl == null)
                {
                    _gl = new Material(Shader.Find("Hidden/Internal-Colored"));
                    _gl.hideFlags = HideFlags.HideAndDontSave;
                    _gl.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    _gl.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    _gl.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
                    _gl.SetInt("_ZWrite", 0);
                    _gl.SetInt("_ZTest", (int)UnityEngine.Rendering.CompareFunction.Always);
                }
                return _gl;
            }
        }

        public static Texture2D White
        {
            get
            {
                if (_white == null)
                {
                    _white = new Texture2D(2, 2);
                    _white.SetPixels(new[] { Color.white, Color.white, Color.white, Color.white });
                    _white.Apply();
                }
                return _white;
            }
        }

        public static Texture2D CircleTex
        {
            get
            {
                if (_circleTex == null)
                {
                    int n = 64;
                    _circleTex = new Texture2D(n, n, TextureFormat.RGBA32, false);
                    _circleTex.wrapMode = TextureWrapMode.Clamp;
                    var px = new Color[n * n];
                    float r = n / 2f;
                    for (int y = 0; y < n; y++)
                        for (int x = 0; x < n; x++)
                        {
                            float d = Mathf.Sqrt((x + 0.5f - r) * (x + 0.5f - r) + (y + 0.5f - r) * (y + 0.5f - r));
                            float a = Mathf.Clamp01(r - d - 0.5f);
                            px[y * n + x] = new Color(1, 1, 1, a);
                        }
                    _circleTex.SetPixels(px);
                    _circleTex.Apply();
                }
                return _circleTex;
            }
        }

        public static Texture2D SoftTex
        {
            get
            {
                if (_softTex == null)
                {
                    int n = 64;
                    _softTex = new Texture2D(n, n, TextureFormat.RGBA32, false);
                    _softTex.wrapMode = TextureWrapMode.Clamp;
                    var px = new Color[n * n];
                    float r = n / 2f;
                    for (int y = 0; y < n; y++)
                        for (int x = 0; x < n; x++)
                        {
                            float d = Mathf.Sqrt((x + 0.5f - r) * (x + 0.5f - r) + (y + 0.5f - r) * (y + 0.5f - r)) / r;
                            float a = Mathf.Clamp01(1 - d);
                            px[y * n + x] = new Color(1, 1, 1, a * a);
                        }
                    _softTex.SetPixels(px);
                    _softTex.Apply();
                }
                return _softTex;
            }
        }

        public static Sprite Circle
        {
            get
            {
                if (_circle == null) _circle = Sprite.Create(CircleTex, new Rect(0, 0, 64, 64), new Vector2(0.5f, 0.5f), 64f);
                return _circle;
            }
        }

        public static Sprite Soft
        {
            get
            {
                if (_soft == null) _soft = Sprite.Create(SoftTex, new Rect(0, 0, 64, 64), new Vector2(0.5f, 0.5f), 64f);
                return _soft;
            }
        }

        public static Sprite Square
        {
            get
            {
                if (_square == null) _square = Sprite.Create(White, new Rect(0, 0, 2, 2), new Vector2(0.5f, 0.5f), 2f);
                return _square;
            }
        }

        public static Color Mul(Color c, float k) { return new Color(c.r * k, c.g * k, c.b * k, c.a); }
        public static Color A(Color c, float a) { return new Color(c.r, c.g, c.b, a); }

        public static LineRenderer Line(Transform parent, string name, float width, Color c, int order, bool world = true, int caps = 5)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            var lr = go.AddComponent<LineRenderer>();
            lr.sharedMaterial = LineMat;
            lr.useWorldSpace = world;
            lr.widthMultiplier = width;
            lr.numCapVertices = caps;
            lr.numCornerVertices = caps;
            lr.startColor = c; lr.endColor = c;
            lr.sortingOrder = order;
            lr.positionCount = 2;
            lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            lr.receiveShadows = false;
            lr.textureMode = LineTextureMode.Stretch;
            return lr;
        }

        public static void Col(LineRenderer lr, Color c) { lr.startColor = c; lr.endColor = c; }

        public static void Set(LineRenderer lr, Vector2 a, Vector2 b)
        {
            if (lr.positionCount != 2) lr.positionCount = 2;
            lr.SetPosition(0, a); lr.SetPosition(1, b);
        }

        public static void Set(LineRenderer lr, Vector2 a, Vector2 b, Vector2 c)
        {
            if (lr.positionCount != 3) lr.positionCount = 3;
            lr.SetPosition(0, a); lr.SetPosition(1, b); lr.SetPosition(2, c);
        }

        public static void Set(LineRenderer lr, IList<Vector2> pts)
        {
            if (lr.positionCount != pts.Count) lr.positionCount = pts.Count;
            for (int i = 0; i < pts.Count; i++) lr.SetPosition(i, pts[i]);
        }

        public static void Taper(LineRenderer lr, float start, float end)
        {
            lr.widthMultiplier = 1f;
            lr.widthCurve = AnimationCurve.Linear(0, start, 1, end);
        }

        public static SpriteRenderer Spr(Transform parent, string name, Sprite s, Color c, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = s; sr.color = c; sr.sortingOrder = order;
            return sr;
        }

        public static SpriteRenderer Rect(Transform parent, Rect r, Color c, int order)
        {
            var sr = Spr(parent, "rect", Square, c, order);
            sr.transform.localPosition = new Vector3(r.center.x, r.center.y, 0);
            sr.transform.localScale = new Vector3(r.width, r.height, 1);
            return sr;
        }

        public static MeshRenderer MeshObj(Transform parent, string name, Vector3[] v, Color[] c, int[] tris, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            var mf = go.AddComponent<MeshFilter>();
            var mr = go.AddComponent<MeshRenderer>();
            var m = new Mesh();
            m.vertices = v; m.colors = c; m.triangles = tris;
            var uv = new Vector2[v.Length];
            for (int i = 0; i < uv.Length; i++) uv[i] = new Vector2(0.5f, 0.5f);
            m.uv = uv;
            m.RecalculateBounds();
            mf.sharedMesh = m;
            mr.sharedMaterial = LineMat;
            mr.sortingOrder = order;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            mr.receiveShadows = false;
            return mr;
        }

        // Звёздно-выпуклый полигон (веер от центра масс)
        public static MeshRenderer Poly(Transform parent, Vector2[] pts, Color c, int order, string name = "poly")
        {
            Vector2 cen = Vector2.zero;
            foreach (var p in pts) cen += p;
            cen /= pts.Length;
            var v = new Vector3[pts.Length + 1];
            var col = new Color[v.Length];
            v[0] = cen; col[0] = c;
            for (int i = 0; i < pts.Length; i++) { v[i + 1] = pts[i]; col[i + 1] = c; }
            var tris = new int[pts.Length * 3];
            for (int i = 0; i < pts.Length; i++)
            {
                tris[i * 3] = 0; tris[i * 3 + 1] = i + 1; tris[i * 3 + 2] = (i + 1) % pts.Length + 1;
            }
            return MeshObj(parent, name, v, col, tris, order);
        }

        // Прямоугольник с вертикальным градиентом
        public static MeshRenderer Gradient(Transform parent, Rect r, Color top, Color bottom, int order)
        {
            var v = new Vector3[] { new Vector3(r.xMin, r.yMin), new Vector3(r.xMin, r.yMax), new Vector3(r.xMax, r.yMax), new Vector3(r.xMax, r.yMin) };
            var c = new Color[] { bottom, top, top, bottom };
            return MeshObj(parent, "gradient", v, c, new[] { 0, 1, 2, 0, 2, 3 }, order);
        }

        // Треугольный конус света
        public static MeshRenderer Cone(Transform parent, Vector2 apex, Vector2 bl, Vector2 br, Color cApex, Color cBase, int order)
        {
            var v = new Vector3[] { apex, bl, br };
            var c = new Color[] { cApex, cBase, cBase };
            return MeshObj(parent, "cone", v, c, new[] { 0, 1, 2 }, order);
        }

        // ---------- GL (для IMGUI) ----------
        public static void GLBegin()
        {
            GLMat.SetPass(0);
            GL.PushMatrix();
            GL.LoadPixelMatrix(0, Screen.width, Screen.height, 0);
            GL.MultMatrix(GUI.matrix);
        }

        public static void GLEnd() { GL.PopMatrix(); }

        public static void GLLine(Vector2 a, Vector2 b, float w, Color c)
        {
            Vector2 d = b - a;
            if (d.sqrMagnitude < 0.0001f) d = Vector2.right * 0.01f;
            Vector2 n = new Vector2(-d.y, d.x).normalized * (w * 0.5f);
            GL.Begin(GL.QUADS);
            GL.Color(c);
            GL.Vertex3(a.x + n.x, a.y + n.y, 0);
            GL.Vertex3(b.x + n.x, b.y + n.y, 0);
            GL.Vertex3(b.x - n.x, b.y - n.y, 0);
            GL.Vertex3(a.x - n.x, a.y - n.y, 0);
            GL.End();
        }

        public static void GLDisc(Vector2 c, float r, Color col, int seg = 14)
        {
            GL.Begin(GL.TRIANGLES);
            GL.Color(col);
            for (int i = 0; i < seg; i++)
            {
                float a0 = i * Mathf.PI * 2 / seg, a1 = (i + 1) * Mathf.PI * 2 / seg;
                GL.Vertex3(c.x, c.y, 0);
                GL.Vertex3(c.x + Mathf.Cos(a0) * r, c.y + Mathf.Sin(a0) * r, 0);
                GL.Vertex3(c.x + Mathf.Cos(a1) * r, c.y + Mathf.Sin(a1) * r, 0);
            }
            GL.End();
        }

        public static void GLRing(Vector2 c, float r, float w, Color col, int seg = 40)
        {
            for (int i = 0; i < seg; i++)
            {
                float a0 = i * Mathf.PI * 2 / seg, a1 = (i + 1) * Mathf.PI * 2 / seg;
                GLLine(c + new Vector2(Mathf.Cos(a0), Mathf.Sin(a0)) * r, c + new Vector2(Mathf.Cos(a1), Mathf.Sin(a1)) * r, w, col);
            }
        }
    }
}
