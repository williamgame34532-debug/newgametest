using System.Collections.Generic;
using UnityEngine;

// Сканированные предметы (Poly Haven, CC0) и постройки (shadow-six, CC0) из Resources/Props:
// ставит модель с материалами (цвет, нормали, металл/шероховатость), коллайдером и типом поверхности для попаданий.
public static class PropKit
{
    static readonly Dictionary<string, Material[]> mats = new Dictionary<string, Material[]>();

    public static ModelX Model(string key) => ModelX.Load("prop_" + key, "Props/");
    public static bool Has(string key) => Model(key) != null;

    // collide: 0 — без столкновений, 1 — коробка по габаритам, 2 — точная сетка (постройки)
    public static GameObject Place(string key, Vector3 pos, float yaw, Transform parent, float scale = 1f, int collide = 1, bool metal = false, string name = "prop")
        => Place(key, pos, Quaternion.Euler(0, yaw, 0), parent, scale, collide, metal, name);
    public static GameObject Place(string key, Vector3 pos, Quaternion rot, Transform parent, float scale = 1f, int collide = 1, bool metal = false, string name = "prop")
    {
        var mx = Model(key);
        if (mx == null) return null;
        if (!mats.TryGetValue(key, out var mm))
        {
            mm = new Material[mx.matColor.Count];
            for (int i = 0; i < mm.Length; i++) { mm[i] = mx.Mat(i, Color.white); mm[i].enableInstancing = true; }
            mats[key] = mm;
        }
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        go.transform.position = pos;
        go.transform.rotation = rot;
        go.transform.localScale = Vector3.one * scale;
        go.layer = Layers.World;
        Bounds b = new Bounds(); bool first = true;
        foreach (var p in mx.parts)
        {
            var pg = new GameObject("p");
            pg.transform.SetParent(go.transform, false);
            pg.layer = Layers.World;
            pg.AddComponent<MeshFilter>().sharedMesh = p.mesh;
            pg.AddComponent<MeshRenderer>().sharedMaterial = mm[Mathf.Clamp(p.mat, 0, mm.Length - 1)];
            if (collide == 2) pg.AddComponent<MeshCollider>().sharedMesh = p.mesh;
            if (first) { b = p.mesh.bounds; first = false; } else b.Encapsulate(p.mesh.bounds);
        }
        if (collide == 1)
        {
            var bc = go.AddComponent<BoxCollider>();
            bc.center = b.center; bc.size = b.size;
        }
        if (collide > 0)
        {
            var sf = go.AddComponent<Surface>();
            sf.color = mx.matColor.Count > 0 ? mx.matColor[0] : Color.gray;
            sf.metal = metal;
        }
        return go;
    }

    // габариты модели (м) без масштаба
    public static Vector3 Size(string key)
    {
        var mx = Model(key);
        if (mx == null) return Vector3.one;
        Bounds b = new Bounds(); bool first = true;
        foreach (var p in mx.parts) { if (first) { b = p.mesh.bounds; first = false; } else b.Encapsulate(p.mesh.bounds); }
        return b.size;
    }
}
