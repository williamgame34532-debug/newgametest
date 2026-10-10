using System.Collections.Generic;
using System.IO;
using UnityEngine;

// Готовые модели (сконвертированы из glTF скриптом инструментов): части с текстурными координатами и точками вращения.
// Формат SCPX: материалы (цвет, текстура в Resources/Models, гладкость, металл), части (имя, материал, опорная точка, вершины, треугольники).
public class ModelX
{
    public class Part { public string name; public int mat; public Vector3 pivot; public Mesh mesh; }
    public readonly List<Part> parts = new List<Part>();
    public readonly List<Color> matColor = new List<Color>();
    public readonly List<string> matTex = new List<string>();
    public readonly List<Vector2> matSM = new List<Vector2>();

    static readonly Dictionary<string, ModelX> cache = new Dictionary<string, ModelX>();

    public static ModelX Load(string name)
    {
        if (cache.TryGetValue(name, out var m)) return m;
        var ta = Resources.Load<TextAsset>("Models/" + name);
        if (ta == null) { cache[name] = null; return null; }
        m = new ModelX();
        using (var br = new BinaryReader(new MemoryStream(ta.bytes)))
        {
            br.ReadBytes(4); br.ReadInt32();
            int nm = br.ReadInt32();
            for (int i = 0; i < nm; i++)
            {
                m.matColor.Add(new Color(br.ReadSingle(), br.ReadSingle(), br.ReadSingle(), br.ReadSingle()));
                int l = br.ReadByte();
                m.matTex.Add(System.Text.Encoding.UTF8.GetString(br.ReadBytes(l)));
                m.matSM.Add(new Vector2(br.ReadSingle(), br.ReadSingle()));
            }
            int np = br.ReadInt32();
            for (int i = 0; i < np; i++)
            {
                var p = new Part();
                int l = br.ReadByte();
                p.name = System.Text.Encoding.UTF8.GetString(br.ReadBytes(l));
                p.mat = br.ReadInt32();
                p.pivot = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                int nv = br.ReadInt32();
                var v = new Vector3[nv]; var n = new Vector3[nv]; var uv = new Vector2[nv];
                for (int k = 0; k < nv; k++)
                {
                    v[k] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                    n[k] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                    uv[k] = new Vector2(br.ReadSingle(), br.ReadSingle());
                }
                int nt = br.ReadInt32();
                var t = new int[nt * 3];
                for (int k = 0; k < t.Length; k++) t[k] = br.ReadInt32();
                p.mesh = new Mesh { name = p.name };
                if (nv > 65000) p.mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
                p.mesh.vertices = v; p.mesh.normals = n; p.mesh.uv = uv; p.mesh.triangles = t;
                p.mesh.RecalculateBounds();
                m.parts.Add(p);
            }
        }
        cache[name] = m;
        return m;
    }

    public Part Get(string name) { foreach (var p in parts) if (p.name == name) return p; return null; }

    // Материал части с оттенком (покраска под сторону)
    public Material Mat(int i, Color tint)
    {
        Color c = matColor[i] * tint; c.a = matColor[i].a;
        Material mat;
        if (c.a < 0.99f) mat = Mats.Glass(c, matSM[i].x);
        else
        {
            var tex = string.IsNullOrEmpty(matTex[i]) ? null : Resources.Load<Texture2D>("Models/" + matTex[i]);
            mat = tex != null ? Mats.Textured(tex, c, Vector2.one, matSM[i].x) : Mats.Get(c, matSM[i].x, matSM[i].y);
            mat.SetFloat("_Metallic", matSM[i].y);
        }
        return mat;
    }

    public GameObject Spawn(string part, Transform parent, Color tint, Vector3 localPos)
    {
        var p = Get(part);
        if (p == null) return null;
        var go = new GameObject(part);
        go.transform.SetParent(parent, false);
        go.transform.localPosition = localPos;
        go.AddComponent<MeshFilter>().sharedMesh = p.mesh;
        go.AddComponent<MeshRenderer>().sharedMaterial = Mat(p.mat, tint);
        return go;
    }
}
