using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Конструктор моделей: примитивы, собственные меши (усечённые конусы, клинья) и объединение деталей,
// чтобы у каждого бойца было мало отрисовок.
public static class MeshKit
{
    static Mesh cube, sphere, cylinder, capsule, quad;
    static readonly Dictionary<int, Mesh> frustums = new Dictionary<int, Mesh>();

    static Mesh Prim(PrimitiveType t)
    {
        var go = GameObject.CreatePrimitive(t);
        var m = go.GetComponent<MeshFilter>().sharedMesh;
        go.SetActive(false); // временный объект не должен попасть в физику/навмеш
        Object.Destroy(go);
        return m;
    }

    public static Mesh Cube { get { if (cube == null) cube = Prim(PrimitiveType.Cube); return cube; } }
    public static Mesh Sphere { get { if (sphere == null) sphere = Prim(PrimitiveType.Sphere); return sphere; } }
    public static Mesh Cylinder { get { if (cylinder == null) cylinder = Prim(PrimitiveType.Cylinder); return cylinder; } }
    public static Mesh Capsule { get { if (capsule == null) capsule = Prim(PrimitiveType.Capsule); return capsule; } }
    public static Mesh Quad { get { if (quad == null) quad = Prim(PrimitiveType.Quad); return quad; } }

    // Усечённый конус высотой 1 (от y=-0.5 до y=0.5), нижний радиус 0.5, верхний 0.5*top
    public static Mesh Frustum(float top, int seg = 12)
    {
        int key = Mathf.RoundToInt(top * 100) * 100 + seg;
        if (frustums.TryGetValue(key, out var m) && m != null) return m;
        var v = new List<Vector3>(); var n = new List<Vector3>(); var t = new List<int>();
        float rb = 0.5f, rt = 0.5f * top;
        float slope = (rb - rt);
        for (int i = 0; i <= seg; i++)
        {
            float a = i / (float)seg * Mathf.PI * 2f;
            float c = Mathf.Cos(a), s = Mathf.Sin(a);
            var nn = new Vector3(c, slope, s).normalized;
            v.Add(new Vector3(c * rb, -0.5f, s * rb)); n.Add(nn);
            v.Add(new Vector3(c * rt, 0.5f, s * rt)); n.Add(nn);
        }
        for (int i = 0; i < seg; i++)
        {
            int a = i * 2;
            t.Add(a); t.Add(a + 1); t.Add(a + 2);
            t.Add(a + 1); t.Add(a + 3); t.Add(a + 2);
        }
        // крышки
        int cb = v.Count; v.Add(new Vector3(0, -0.5f, 0)); n.Add(Vector3.down);
        for (int i = 0; i <= seg; i++) { float a = i / (float)seg * Mathf.PI * 2f; v.Add(new Vector3(Mathf.Cos(a) * rb, -0.5f, Mathf.Sin(a) * rb)); n.Add(Vector3.down); }
        for (int i = 0; i < seg; i++) { t.Add(cb); t.Add(cb + 1 + i); t.Add(cb + 2 + i); }
        int ct = v.Count; v.Add(new Vector3(0, 0.5f, 0)); n.Add(Vector3.up);
        for (int i = 0; i <= seg; i++) { float a = i / (float)seg * Mathf.PI * 2f; v.Add(new Vector3(Mathf.Cos(a) * rt, 0.5f, Mathf.Sin(a) * rt)); n.Add(Vector3.up); }
        for (int i = 0; i < seg; i++) { t.Add(ct); t.Add(ct + 2 + i); t.Add(ct + 1 + i); }
        m = new Mesh { name = "frustum" };
        m.SetVertices(v); m.SetNormals(n); m.SetTriangles(t, 0);
        m.RecalculateBounds();
        frustums[key] = m;
        return m;
    }

    // ---------------- детали ----------------
    public static GameObject Part(Transform parent, Mesh mesh, Material mat, Vector3 pos, Vector3 scale, Vector3 euler = default(Vector3), string name = "p")
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        go.transform.localPosition = pos;
        go.transform.localRotation = Quaternion.Euler(euler);
        go.transform.localScale = scale;
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = mat;
        return go;
    }

    public static GameObject Box(Transform p, Vector3 pos, Vector3 size, Color c, Vector3 euler = default(Vector3), float smooth = 0.25f, float metal = 0f)
        => Part(p, Cube, Mats.Get(c, smooth, metal), pos, size, euler);

    public static GameObject Box(Transform p, Vector3 pos, Vector3 size, Material m, Vector3 euler = default(Vector3))
        => Part(p, Cube, m, pos, size, euler);

    public static GameObject Ball(Transform p, Vector3 pos, Vector3 size, Color c, Vector3 euler = default(Vector3), float smooth = 0.25f)
        => Part(p, Sphere, Mats.Get(c, smooth), pos, size, euler);

    public static GameObject Ball(Transform p, Vector3 pos, Vector3 size, Material m, Vector3 euler = default(Vector3))
        => Part(p, Sphere, m, pos, size, euler);

    // Цилиндр: диаметр d, длина h, вдоль локальной оси Y (поворот через euler)
    public static GameObject Cyl(Transform p, Vector3 pos, float d, float h, Color c, Vector3 euler = default(Vector3), float smooth = 0.25f, float metal = 0f)
        => Part(p, Cylinder, Mats.Get(c, smooth, metal), pos, new Vector3(d, h * 0.5f, d), euler);

    public static GameObject Cyl(Transform p, Vector3 pos, float d, float h, Material m, Vector3 euler = default(Vector3))
        => Part(p, Cylinder, m, pos, new Vector3(d, h * 0.5f, d), euler);

    // Сужающийся сегмент конечности: нижний диаметр d0, верхний d1 (относительно d0), длина h
    public static GameObject Taper(Transform p, Vector3 pos, float d0, float d1, float h, Color c, Vector3 euler = default(Vector3), float depthMul = 1f)
        => Part(p, Frustum(d1 / Mathf.Max(0.001f, d0)), Mats.Get(c), pos, new Vector3(d0, h, d0 * depthMul), euler);

    public static GameObject Caps(Transform p, Vector3 pos, float d, float h, Color c, Vector3 euler = default(Vector3))
        => Part(p, Capsule, Mats.Get(c), pos, new Vector3(d, h * 0.5f, d), euler);

    // ---------------- объединение ----------------
    // Сливает все детали (дочерние объекты с именем "p", рекурсивно внутри деталей) в один меш на кость.
    public static void CombineParts(Transform bone, bool castShadows = true)
    {
        var filters = new List<MeshFilter>();
        for (int i = 0; i < bone.childCount; i++)
        {
            var ch = bone.GetChild(i);
            if (ch.name != "p") continue;
            filters.AddRange(ch.GetComponentsInChildren<MeshFilter>());
        }
        if (filters.Count < 2) return;
        var byMat = new Dictionary<Material, List<CombineInstance>>();
        var order = new List<Material>();
        Matrix4x4 inv = bone.worldToLocalMatrix;
        int verts = 0;
        foreach (var f in filters)
        {
            var r = f.GetComponent<MeshRenderer>();
            if (r == null || f.sharedMesh == null) continue;
            var mat = r.sharedMaterial;
            if (!byMat.TryGetValue(mat, out var list)) { list = new List<CombineInstance>(); byMat[mat] = list; order.Add(mat); }
            list.Add(new CombineInstance { mesh = f.sharedMesh, transform = inv * f.transform.localToWorldMatrix });
            verts += f.sharedMesh.vertexCount;
        }
        var subMeshes = new List<Mesh>();
        foreach (var mat in order)
        {
            var sm = new Mesh();
            if (verts > 60000) sm.indexFormat = IndexFormat.UInt32;
            sm.CombineMeshes(byMat[mat].ToArray(), true, true);
            subMeshes.Add(sm);
        }
        var final = new Mesh { name = bone.name + "_mesh" };
        if (verts > 60000) final.indexFormat = IndexFormat.UInt32;
        var ci = new CombineInstance[subMeshes.Count];
        for (int i = 0; i < ci.Length; i++) ci[i] = new CombineInstance { mesh = subMeshes[i], transform = Matrix4x4.identity };
        final.CombineMeshes(ci, false, false);
        final.RecalculateBounds();
        foreach (var sm in subMeshes) Object.Destroy(sm);

        // удаляем детали
        var kill = new List<GameObject>();
        for (int i = 0; i < bone.childCount; i++) if (bone.GetChild(i).name == "p") kill.Add(bone.GetChild(i).gameObject);
        foreach (var k in kill) { k.SetActive(false); Object.Destroy(k); }

        var go = new GameObject("mesh");
        go.transform.SetParent(bone, false);
        go.AddComponent<MeshFilter>().sharedMesh = final;
        var mr = go.AddComponent<MeshRenderer>();
        mr.sharedMaterials = order.ToArray();
        mr.shadowCastingMode = castShadows ? ShadowCastingMode.On : ShadowCastingMode.Off;
    }

    // Перекрашивает все рендеры объекта (затемнение трупов, обугливание, зомби)
    public static void Tint(GameObject root, Color mul, float lerpToward = 0f, Color toward = default(Color))
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>())
        {
            if (r is ParticleSystemRenderer || r is LineRenderer) continue;
            var mats = r.sharedMaterials;
            for (int i = 0; i < mats.Length; i++)
            {
                if (mats[i] == null || !mats[i].HasProperty("_Color")) continue;
                if (mats[i].renderQueue >= 3000) continue;
                Color c = mats[i].color;
                Color n = Color.Lerp(c * mul, toward, lerpToward);
                n.a = c.a;
                mats[i] = Mats.Get(n, mats[i].HasProperty("_Glossiness") ? mats[i].GetFloat("_Glossiness") : 0.2f);
            }
            r.sharedMaterials = mats;
        }
    }

    public static void SetLayer(GameObject go, int layer)
    {
        go.layer = layer;
        foreach (Transform t in go.transform) SetLayer(t.gameObject, layer);
    }

    public static void NoShadows(GameObject go)
    {
        foreach (var r in go.GetComponentsInChildren<Renderer>()) r.shadowCastingMode = ShadowCastingMode.Off;
    }
}
