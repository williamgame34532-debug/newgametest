using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

// Готовые low-poly модели: солдат (из присланного FBX, переведён в позу покоя нашего скелета и привязан к его 17 костям),
// винтовка M4 и силуэты остального оружия (Resources/Models/guns.txt).
public static class ModelLib
{
    // группы треугольников солдата
    public const int G_SKIN = 0, G_JACKET = 1, G_PANTS = 2, G_VEST = 3, G_GEAR = 4, G_POUCH = 5, G_HELMET = 6, G_BAND = 7, G_MASK = 8, G_GOGGLES = 9, G_CUFF = 10, G_COUNT = 11;

    public class SoldierData
    {
        public int[] parent;
        public Vector3[] jointLocal, jointAbs;
        public Vector3[] pos;
        public BoneWeight[] bw;
        public int[] tris;
        public byte[] grp, side;
        public Vector2[] uv;          // только у текстурированных моделей (vanguard)
        // таблица материалов (SCPU v3: готовые персонажи-SCP со своими текстурами)
        public List<Color> matCol; public List<string> matTex, matNrm; public List<bool> matCut; public List<float> matSmooth;
    }

    // Материалы модели по её таблице: цвет + карта нормалей
    public static Material[] TableMaterials(string id, out int[] slotOf)
    {
        var d = Load(id);
        slotOf = new int[G_COUNT];
        for (int i = 0; i < slotOf.Length; i++) slotOf[i] = -1;
        if (d == null || d.matCol == null) return new Material[0];
        var mats = new Material[d.matCol.Count];
        for (int i = 0; i < mats.Length && i < slotOf.Length; i++)
        {
            slotOf[i] = i;
            var tex = Mats.BytesTex(d.matTex[i], false);
            mats[i] = tex != null ? Mats.Textured(tex, d.matCol[i], Vector2.one, d.matSmooth[i]) : Mats.Get(d.matCol[i], d.matSmooth[i]);
            mats[i].SetFloat("_Metallic", 0f);
            Mats.AddNormal(mats[i], Mats.BytesTex(d.matNrm[i], true));
            if (d.matCut[i])
            {
                mats[i].SetFloat("_Mode", 1f); mats[i].SetFloat("_Cutoff", 0.5f);
                mats[i].EnableKeyword("_ALPHATEST_ON"); mats[i].renderQueue = 2450;
            }
        }
        return mats;
    }

    // Модели бойцов: "soldier" — присланный low-poly солдат (открытое лицо, кепки, Класс-D),
    // "vanguard" — бронированный боец с текстурой (Mixamo/three.js), перекрашивается под отряд.
    static readonly Dictionary<string, SoldierData> soldiers = new Dictionary<string, SoldierData>();
    public static string Active { get; private set; } = "soldier";
    public static void Use(string id) { Active = Load(id) != null ? id : "soldier"; }

    public static string ModelFor(Look L)
    {
        if (L == null) return "soldier";
        switch (L.head)
        {
            case HeadGear.Cap: case HeadGear.Bare: return "soldier";
        }
        return Load("vanguard") != null ? "vanguard" : "soldier";
    }

    public static SoldierData Soldier => Load(Active);

    // ---- перекраска текстуры бронированного бойца под отряд ----
    // маска: R — класс (0 как есть, 60 бронепластины, 120 ткань, 180 нашивки/полосы), G — яркость детали (128 = средняя)
    static Color32[] vgSrc, vgMask; static int vgW, vgH;
    static readonly Dictionary<string, Material> vgMats = new Dictionary<string, Material>();
    public static Material VanguardMat(Look L)
    {
        string key = ColorUtility.ToHtmlStringRGB(L.uniform) + ColorUtility.ToHtmlStringRGB(L.uniform2) + ColorUtility.ToHtmlStringRGB(L.armor) + ColorUtility.ToHtmlStringRGB(L.accent);
        if (vgMats.TryGetValue(key, out var m) && m != null) return m;
        if (vgSrc == null)
        {
            var a = Resources.Load<TextAsset>("Models/vanguard_tex"); var b = Resources.Load<TextAsset>("Models/vanguard_mask");
            if (a == null || b == null) return Mats.Get(L.uniform);
            var t1 = new Texture2D(2, 2); t1.LoadImage(a.bytes);
            var t2 = new Texture2D(2, 2); t2.LoadImage(b.bytes);
            vgSrc = t1.GetPixels32(); vgMask = t2.GetPixels32(); vgW = t1.width; vgH = t1.height;
            Object.Destroy(t1); Object.Destroy(t2);
        }
        Color plate = Color.Lerp(L.uniform, L.armor, 0.3f) * 1.45f, fabric = L.uniform2 * 1.25f, acc = L.accent;
        var outPx = new Color32[vgSrc.Length];
        for (int i = 0; i < outPx.Length; i++)
        {
            int cls = (vgMask[i].r + 30) / 60;
            if (cls == 0) { outPx[i] = vgSrc[i]; continue; }
            float k = vgMask[i].g / 127.5f;
            Color c = cls == 1 ? plate : cls == 2 ? fabric : acc;
            outPx[i] = new Color32((byte)Mathf.Clamp(c.r * k * 255f, 0, 255), (byte)Mathf.Clamp(c.g * k * 255f, 0, 255), (byte)Mathf.Clamp(c.b * k * 255f, 0, 255), 255);
        }
        var tex = new Texture2D(vgW, vgH, TextureFormat.RGBA32, true);
        tex.SetPixels32(outPx);
        tex.Apply(true, true);
        tex.anisoLevel = 4;
        m = Mats.Textured(tex, Color.white, Vector2.one, 0.28f);
        vgMats[key] = m;
        return m;
    }

    static SoldierData Load(string id)
    {
        if (soldiers.TryGetValue(id, out var cached)) return cached;
        soldiers[id] = null;
        {
            var ta = Resources.Load<TextAsset>("Models/" + id);
            if (ta == null) { Debug.LogWarning("Нет Resources/Models/" + id + ".bytes"); return null; }
            using (var br = new BinaryReader(new MemoryStream(ta.bytes)))
            {
                bool hasUV = System.Text.Encoding.ASCII.GetString(br.ReadBytes(4)) == "SCPU"; int ver = br.ReadInt32();
                var d = new SoldierData();
                int nj = br.ReadInt32();
                d.parent = new int[nj]; d.jointLocal = new Vector3[nj]; d.jointAbs = new Vector3[nj];
                for (int i = 0; i < nj; i++)
                {
                    d.parent[i] = br.ReadInt32();
                    d.jointLocal[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                    d.jointAbs[i] = d.parent[i] < 0 ? d.jointLocal[i] : d.jointAbs[d.parent[i]] + d.jointLocal[i];
                }
                int nv = br.ReadInt32();
                d.pos = new Vector3[nv]; d.bw = new BoneWeight[nv];
                if (hasUV) d.uv = new Vector2[nv];
                for (int i = 0; i < nv; i++)
                {
                    d.pos[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                    if (hasUV) d.uv[i] = new Vector2(br.ReadSingle(), br.ReadSingle());
                    byte b0 = br.ReadByte(), b1 = br.ReadByte(), b2 = br.ReadByte(), b3 = br.ReadByte();
                    d.bw[i] = new BoneWeight
                    {
                        boneIndex0 = b0, boneIndex1 = b1, boneIndex2 = b2, boneIndex3 = b3,
                        weight0 = br.ReadSingle(), weight1 = br.ReadSingle(), weight2 = br.ReadSingle(), weight3 = br.ReadSingle()
                    };
                }
                int nt = br.ReadInt32();
                d.tris = new int[nt * 3]; d.grp = new byte[nt]; d.side = new byte[nt];
                for (int i = 0; i < nt; i++)
                {
                    d.tris[i * 3] = br.ReadInt32(); d.tris[i * 3 + 1] = br.ReadInt32(); d.tris[i * 3 + 2] = br.ReadInt32();
                    d.grp[i] = br.ReadByte(); d.side[i] = br.ReadByte();
                }
                if (hasUV && ver >= 3)
                {
                    int nm = br.ReadInt32();
                    d.matCol = new List<Color>(); d.matTex = new List<string>(); d.matNrm = new List<string>(); d.matCut = new List<bool>(); d.matSmooth = new List<float>();
                    for (int i = 0; i < nm; i++)
                    {
                        d.matCol.Add(new Color(br.ReadSingle(), br.ReadSingle(), br.ReadSingle(), br.ReadSingle()));
                        d.matTex.Add(System.Text.Encoding.UTF8.GetString(br.ReadBytes(br.ReadByte())));
                        d.matNrm.Add(System.Text.Encoding.UTF8.GetString(br.ReadBytes(br.ReadByte())));
                        d.matCut.Add(br.ReadByte() != 0); d.matSmooth.Add(br.ReadSingle());
                    }
                }
                soldiers[id] = d;
                return d;
            }
        }
    }

    public static bool HasSoldier => Soldier != null;

    // Пропорции скелета ровно под модель
    public static BodyShape SoldierShape(float bulk = 1f)
    {
        var d = Soldier;
        var s = new BodyShape { bulk = bulk, model = true };
        if (d == null) return s;
        s.joints = d.jointLocal;
        s.armU = d.jointLocal[HumanRig.LArmL].magnitude;
        s.armL = d.jointLocal[HumanRig.HandL].magnitude;
        s.legU = d.jointLocal[HumanRig.LLegL].magnitude;
        s.legL = d.jointLocal[HumanRig.FootL].magnitude;
        s.shoulder = Mathf.Abs(d.jointLocal[HumanRig.UArmR].x);
        s.headSize = 1.15f;
        return s;
    }

    static readonly Dictionary<string, Mesh> meshCache = new Dictionary<string, Mesh>();

    // Меш тела: slotOf[group] — номер подсетки (материала) или -1, если группа скрыта.
    // Только ноги и таз (видны игроку, когда он смотрит вниз)
    public static Mesh LegsMesh(int[] slotOf, int slots)
    {
        var d = Soldier;
        float cut = d.jointAbs[HumanRig.Hips].y * 0.95f;   // ниже пояса (у моделей разный рост таза)
        return BodyMesh("legs_" + string.Join(",", slotOf), slotOf, slots, t =>
        {
            float y = 0; int legs = 0;
            for (int k = 0; k < 3; k++)
            {
                int vi = d.tris[t * 3 + k];
                y += d.pos[vi].y;
                int b = d.bw[vi].boneIndex0;
                if (b >= HumanRig.ULegL) legs++;
            }
            return legs >= 2 && y / 3f < cut;
        });
    }

    public static Mesh BodyMesh(string key, int[] slotOf, int slots, System.Func<int, bool> filter = null)
    {
        key = Active + "_" + key;
        if (meshCache.TryGetValue(key, out var cached) && cached != null) return cached;
        var d = Soldier;
        var verts = new List<Vector3>();
        var uvs = new List<Vector2>();
        var bws = new List<BoneWeight>();
        var subs = new List<int>[slots];
        for (int i = 0; i < slots; i++) subs[i] = new List<int>();
        int nt = d.grp.Length;
        // текстурированные модели — общие вершины (гладкое затенение); простой солдат — гранями, как задуман
        bool share = d.uv != null;
        var remap = share ? new Dictionary<int, int>() : null;
        for (int t = 0; t < nt; t++)
        {
            int slot = d.grp[t] < slotOf.Length ? slotOf[d.grp[t]] : -1;
            if (slot < 0) continue;
            if (filter != null && !filter(t)) continue;
            for (int k = 0; k < 3; k++)
            {
                int vi = d.tris[t * 3 + k];
                if (share && remap.TryGetValue(vi, out int ni)) { subs[slot].Add(ni); continue; }
                if (share) remap[vi] = verts.Count;
                subs[slot].Add(verts.Count);
                verts.Add(d.pos[vi]);
                if (d.uv != null) uvs.Add(d.uv[vi]);
                bws.Add(d.bw[vi]);
            }
        }
        var m = new Mesh { name = "soldier_" + key };
        if (verts.Count > 65000) m.indexFormat = IndexFormat.UInt32;
        m.SetVertices(verts);
        if (uvs.Count == verts.Count) m.SetUVs(0, uvs);
        m.boneWeights = bws.ToArray();
        m.subMeshCount = slots;
        for (int i = 0; i < slots; i++) m.SetTriangles(subs[i], i);
        m.RecalculateNormals();
        if (uvs.Count == verts.Count) m.RecalculateTangents();
        m.RecalculateBounds();
        var bp = new Matrix4x4[d.jointAbs.Length];
        for (int i = 0; i < bp.Length; i++) bp[i] = Matrix4x4.Translate(-d.jointAbs[i]);
        m.bindposes = bp;
        meshCache[key] = m;
        return m;
    }

    // Рука для вида от первого лица (side: 1 — левая, 2 — правая). Кости: 0 — плечо, 1 — предплечье, 2 — кисть.
    // Вершины заданы относительно плечевого сустава.
    public static Mesh ArmMesh(int side, int[] slotOf, int slots)
    {
        string key = Active + "_arm" + side + "_" + string.Join(",", slotOf);
        if (meshCache.TryGetValue(key, out var cached) && cached != null) return cached;
        var d = Soldier;
        int b0 = side == 1 ? HumanRig.UArmL : HumanRig.UArmR;
        Vector3 sh = d.jointAbs[b0];
        var verts = new List<Vector3>();
        var uvs = new List<Vector2>();
        var bws = new List<BoneWeight>();
        var subs = new List<int>[slots];
        for (int i = 0; i < slots; i++) subs[i] = new List<int>();
        for (int t = 0; t < d.grp.Length; t++)
        {
            if (d.side[t] != side) continue;
            int slot = slotOf[d.grp[t]];
            if (slot < 0) continue;
            for (int k = 0; k < 3; k++)
            {
                int vi = d.tris[t * 3 + k];
                subs[slot].Add(verts.Count);
                // от первого лица руки чуть тоньше, чтобы не закрывать обзор
                Vector3 pv = d.pos[vi] - sh;
                Vector3 axisP = new Vector3(d.jointAbs[b0].x - sh.x, pv.y, d.jointAbs[b0].z - sh.z);
                verts.Add(axisP + (pv - axisP) * 0.85f);
                if (d.uv != null) uvs.Add(d.uv[vi]);
                var w = d.bw[vi];
                // переносим веса на 3 кости руки (всё лишнее — плечу)
                float[] acc = new float[3];
                void Add(int bi, float ww) { int r = bi - b0; if (r < 0 || r > 2) r = 0; acc[r] += ww; }
                Add(w.boneIndex0, w.weight0); Add(w.boneIndex1, w.weight1); Add(w.boneIndex2, w.weight2); Add(w.boneIndex3, w.weight3);
                float sum = acc[0] + acc[1] + acc[2];
                if (sum <= 0) { acc[0] = 1; sum = 1; }
                bws.Add(new BoneWeight { boneIndex0 = 0, weight0 = acc[0] / sum, boneIndex1 = 1, weight1 = acc[1] / sum, boneIndex2 = 2, weight2 = acc[2] / sum });
            }
        }
        var m = new Mesh { name = key };
        m.SetVertices(verts);
        if (uvs.Count == verts.Count) m.SetUVs(0, uvs);
        m.boneWeights = bws.ToArray();
        m.subMeshCount = slots;
        for (int i = 0; i < slots; i++) m.SetTriangles(subs[i], i);
        m.RecalculateNormals();
        m.RecalculateBounds();
        Vector3 el = d.jointAbs[b0 + 1] - sh, wr = d.jointAbs[b0 + 2] - sh;
        m.bindposes = new[] { Matrix4x4.identity, Matrix4x4.Translate(-el), Matrix4x4.Translate(-wr) };
        meshCache[key] = m;
        return m;
    }

    // ================= ОРУЖИЕ =================
    public class GunTemplate
    {
        public Mesh body, mag, pump;
        public Material[] bodyMats, magMats, pumpMats;
        public Vector3 magPos, pumpPos;
        public Vector3 muzzle, grip = new Vector3(0, -0.035f, -0.005f), fore, sight;
        public float length, minZ;
    }

    static readonly Dictionary<string, GunTemplate> guns = new Dictionary<string, GunTemplate>();
    static Dictionary<string, List<string[]>> gunSrc;
    static Mesh m4Body, m4Mag;

    static void LoadGunSrc()
    {
        if (gunSrc != null) return;
        gunSrc = new Dictionary<string, List<string[]>>();
        var ta = Resources.Load<TextAsset>("Models/guns");
        if (ta == null) return;
        List<string[]> cur = null;
        foreach (var raw in ta.text.Split('\n'))
        {
            string line = raw;
            int hash = line.IndexOf('#');
            if (hash >= 0) line = line.Substring(0, hash);
            line = line.Trim();
            if (line.Length == 0) continue;
            var w = line.Split(new[] { ' ', '\t' }, System.StringSplitOptions.RemoveEmptyEntries);
            if (w[0] == "gun") { cur = new List<string[]>(); gunSrc[w[1]] = cur; continue; }
            cur?.Add(w);
        }
    }

    static void LoadM4()
    {
        if (m4Body != null) return;
        var ta = Resources.Load<TextAsset>("Models/m4");
        if (ta == null) return;
        using (var br = new BinaryReader(new MemoryStream(ta.bytes)))
        {
            br.ReadBytes(4); br.ReadInt32();
            for (int i = 0; i < 4; i++) { br.ReadSingle(); br.ReadSingle(); br.ReadSingle(); }
            Mesh Read()
            {
                int nv = br.ReadInt32();
                var v = new Vector3[nv];
                for (int i = 0; i < nv; i++) v[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                int nt = br.ReadInt32();
                var verts = new List<Vector3>();
                var tri = new List<int>();
                for (int i = 0; i < nt; i++)
                {
                    int a = br.ReadInt32(), b = br.ReadInt32(), c = br.ReadInt32();
                    tri.Add(verts.Count); verts.Add(v[a]);
                    tri.Add(verts.Count); verts.Add(v[b]);
                    tri.Add(verts.Count); verts.Add(v[c]);
                }
                var m = new Mesh();
                m.SetVertices(verts); m.SetTriangles(tri, 0);
                m.RecalculateNormals(); m.RecalculateBounds();
                return m;
            }
            m4Body = Read();
            m4Mag = Read();
        }
    }

    static float F(string s) => float.Parse(s, System.Globalization.CultureInfo.InvariantCulture);

    static Material GunMat(string c, WeaponDef def)
    {
        switch (c)
        {
            case "body": return Mats.Get(def.body, 0.35f, 0.25f);
            case "accent": return Mats.Get(def.accent, 0.3f, 0.1f);
            case "metal": return Mats.Get(new Color(0.07f, 0.07f, 0.075f), 0.55f, 0.6f);
            case "dark": return Mats.Get(new Color(0.055f, 0.055f, 0.06f), 0.3f, 0.1f);
            case "wood": return Mats.Get(new Color(0.4f, 0.22f, 0.1f), 0.35f);
            case "olive": return Mats.Get(new Color(0.24f, 0.27f, 0.17f), 0.25f, 0.1f);
            case "glass": return Mats.Glass(new Color(0.3f, 0.45f, 0.55f, 0.35f), 0.95f);
            case "amber": return Mats.Glass(new Color(0.65f, 0.5f, 0.2f, 0.7f), 0.8f);
            case "dot": return Mats.Glow(new Color(1f, 0.08f, 0.04f), 8f);
            case "white": return Mats.Get(new Color(0.85f, 0.85f, 0.85f));
        }
        return Mats.Get(def.body);
    }

    public static GunTemplate Gun(WeaponDef def)
    {
        if (guns.TryGetValue(def.id, out var tpl)) return tpl;
        LoadGunSrc();
        if (gunSrc == null || !gunSrc.TryGetValue(def.id, out var cmds)) return null;
        tpl = new GunTemplate();
        var root = new GameObject("tpl").transform;
        var magT = new GameObject("mag").transform; magT.SetParent(root, false);
        var pumpT = new GameObject("pump").transform; pumpT.SetParent(root, false);
        bool nextMag = false, nextPump = false;
        var magParts = new List<Transform>();
        var pumpParts = new List<Transform>();
        float minZ = 0, maxZ = 0;
        foreach (var w in cmds)
        {
            GameObject part = null;
            switch (w[0])
            {
                case "mag": nextMag = true; continue;
                case "pump": nextPump = true; continue;
                case "dot": case "glass": continue;
                case "a":
                {
                    var v = new Vector3(F(w[2]), F(w[3]), F(w[4]));
                    if (w[1] == "muzzle") tpl.muzzle = v; else if (w[1] == "grip") tpl.grip = v; else if (w[1] == "fore") tpl.fore = v; else if (w[1] == "sight") tpl.sight = v;
                    continue;
                }
                case "mesh":
                    LoadM4();
                    if (m4Body != null)
                    {
                        part = MeshKit.Part(root, m4Body, GunMat("body", def), Vector3.zero, Vector3.one);
                        var mg = MeshKit.Part(root, m4Mag, GunMat("dark", def), Vector3.zero, Vector3.one);
                        magParts.Add(mg.transform);
                    }
                    break;
                case "glb":   // готовая модель (сконвертирована из glTF): части body_*, mag_*, pump_*
                {
                    var mx = ModelX.Load("gun_" + w[1]);
                    if (mx == null) break;
                    foreach (var mp in mx.parts)
                    {
                        var go = MeshKit.Part(root, mp.mesh, mx.Mat(mp.mat, Color.white), Vector3.zero, Vector3.one);
                        if (mp.name.StartsWith("mag")) magParts.Add(go.transform);
                        else if (mp.name.StartsWith("pump")) pumpParts.Add(go.transform);
                        var bb = mp.mesh.bounds;
                        minZ = Mathf.Min(minZ, bb.min.z); maxZ = Mathf.Max(maxZ, bb.max.z);
                    }
                    continue;
                }
                case "ext":
                {
                    var pts = new List<Vector2>();
                    for (int i = 4; i < w.Length; i++) { var p = w[i].Split(','); pts.Add(new Vector2(F(p[0]), F(p[1]))); }
                    float ew = F(w[2]);
                    part = MeshKit.Part(root, ExtrudeBevel(pts, ew, Mathf.Min(0.0035f, ew * 0.22f)), GunMat(w[1], def), new Vector3(F(w[3]), 0, 0), Vector3.one);
                    foreach (var p in pts) { minZ = Mathf.Min(minZ, p.x); maxZ = Mathf.Max(maxZ, p.x); }
                    break;
                }
                case "cyl":
                {
                    Vector3 c = new Vector3(F(w[3]), F(w[4]), F(w[5]));
                    float dd = F(w[6]), l = F(w[7]);
                    Vector3 e = w[2] == "z" ? new Vector3(90, 0, 0) : w[2] == "x" ? new Vector3(0, 0, 90) : Vector3.zero;
                    part = MeshKit.Part(root, MeshKit.Frustum(1f, 10), GunMat(w[1], def), c, new Vector3(dd, l, dd), e);
                    if (w[2] == "z") { minZ = Mathf.Min(minZ, c.z - l / 2); maxZ = Mathf.Max(maxZ, c.z + l / 2); }
                    break;
                }
                case "box":
                    part = MeshKit.Part(root, MeshKit.Cube, GunMat(w[1], def), new Vector3(F(w[2]), F(w[3]), F(w[4])), new Vector3(F(w[5]), F(w[6]), F(w[7])));
                    break;
                // ---- детали: планки, прорези, окно гильз, спуск, дульный тормоз, рёбра магазина ----
                case "rail": case "slots": case "port": case "tguard": case "brake": case "ribs": case "bolt": case "sling":
                {
                    var made = Detail(w, def, root);
                    if (nextMag) magParts.AddRange(made); else if (nextPump) pumpParts.AddRange(made);
                    nextMag = nextPump = false;
                    continue;
                }
                case "holo":
                {
                    // открытый голографический прицел: основание, две стойки, козырёк, прозрачное стекло и яркая марка
                    float cx = F(w[1]), cy = F(w[2]), cz = F(w[3]);
                    var dk = GunMat("dark", def);
                    MeshKit.Part(root, MeshKit.Cube, dk, new Vector3(cx, cy - 0.032f, cz), new Vector3(0.052f, 0.01f, 0.075f));
                    MeshKit.Part(root, MeshKit.Cube, dk, new Vector3(cx - 0.0275f, cy - 0.002f, cz + 0.02f), new Vector3(0.005f, 0.062f, 0.034f));
                    MeshKit.Part(root, MeshKit.Cube, dk, new Vector3(cx + 0.0275f, cy - 0.002f, cz + 0.02f), new Vector3(0.005f, 0.062f, 0.034f));
                    MeshKit.Part(root, MeshKit.Cube, dk, new Vector3(cx, cy + 0.03f, cz + 0.02f), new Vector3(0.06f, 0.006f, 0.034f));
                    MeshKit.Part(root, MeshKit.Cube, dk, new Vector3(cx + 0.033f, cy - 0.015f, cz - 0.01f), new Vector3(0.008f, 0.012f, 0.02f));
                    MeshKit.Part(root, MeshKit.Cube, Mats.Glass(new Color(0.75f, 0.55f, 0.35f, 0.12f), 1f), new Vector3(cx, cy, cz + 0.03f), new Vector3(0.05f, 0.056f, 0.002f));
                    var dot = Mats.Glow(new Color(1f, 0.1f, 0.05f), 10f);
                    MeshKit.Part(root, MeshKit.Sphere, dot, new Vector3(cx, cy, cz + 0.029f), new Vector3(0.0035f, 0.0035f, 0.001f));
                    // кольцо голографической марки (тонкие засечки)
                    for (int k = 0; k < 4; k++)
                    {
                        float a = k * Mathf.PI * 0.5f;
                        Vector3 o = new Vector3(Mathf.Cos(a), Mathf.Sin(a), 0) * 0.011f;
                        MeshKit.Part(root, MeshKit.Cube, dot, new Vector3(cx, cy, cz + 0.029f) + o, k % 2 == 0 ? new Vector3(0.0012f, 0.004f, 0.001f) : new Vector3(0.004f, 0.0012f, 0.001f));
                    }
                    continue;
                }
            }
            if (part == null) continue;
            if (nextMag) { magParts.Add(part.transform); nextMag = false; }
            else if (nextPump) { pumpParts.Add(part.transform); nextPump = false; }
        }
        if (tpl.fore == Vector3.zero) tpl.fore = new Vector3(0, 0, 0.3f);
        tpl.length = maxZ - minZ;
        tpl.minZ = minZ;
        // магазин и цевьё — отдельные объекты для анимации перезарядки
        tpl.magPos = Center(magParts);
        magT.localPosition = tpl.magPos;
        foreach (var p in magParts) p.SetParent(magT, true);
        tpl.pumpPos = Center(pumpParts);
        pumpT.localPosition = tpl.pumpPos;
        foreach (var p in pumpParts) p.SetParent(pumpT, true);
        (tpl.body, tpl.bodyMats) = Bake(root);
        (tpl.mag, tpl.magMats) = Bake(magT);
        (tpl.pump, tpl.pumpMats) = Bake(pumpT);
        Object.Destroy(root.gameObject);
        root.gameObject.SetActive(false);
        guns[def.id] = tpl;
        return tpl;
    }

    static Vector3 Center(List<Transform> parts)
    {
        if (parts.Count == 0) return Vector3.zero;
        var b = new Bounds();
        bool first = true;
        foreach (var p in parts)
        {
            var mf = p.GetComponent<MeshFilter>();
            if (mf == null) continue;
            var lb = mf.sharedMesh.bounds;
            var c = p.localPosition + p.localRotation * Vector3.Scale(lb.center, p.localScale);
            if (first) { b = new Bounds(c, Vector3.zero); first = false; } else b.Encapsulate(c);
        }
        return b.center;
    }

    // Объединяет прямых потомков в один меш (по материалам) в системе координат t
    static (Mesh, Material[]) Bake(Transform t)
    {
        var byMat = new Dictionary<Material, List<CombineInstance>>();
        var order = new List<Material>();
        var inv = t.worldToLocalMatrix;
        for (int i = 0; i < t.childCount; i++)
        {
            var ch = t.GetChild(i);
            var mf = ch.GetComponent<MeshFilter>();
            var mr = ch.GetComponent<MeshRenderer>();
            if (mf == null || mr == null) continue;
            if (!byMat.TryGetValue(mr.sharedMaterial, out var l)) { l = new List<CombineInstance>(); byMat[mr.sharedMaterial] = l; order.Add(mr.sharedMaterial); }
            l.Add(new CombineInstance { mesh = mf.sharedMesh, transform = inv * ch.localToWorldMatrix });
        }
        if (order.Count == 0) return (null, null);
        var subs = new CombineInstance[order.Count];
        for (int i = 0; i < order.Count; i++)
        {
            var sm = new Mesh();
            sm.CombineMeshes(byMat[order[i]].ToArray(), true, true);
            subs[i] = new CombineInstance { mesh = sm, transform = Matrix4x4.identity };
        }
        var m = new Mesh();
        m.CombineMeshes(subs, false, false);
        m.RecalculateBounds();
        return (m, order.ToArray());
    }

    // ---------------- вытягивание профиля ----------------
    // Профиль в плоскости (z, y), вытягивается по X на ширину w (по центру). Плоские нормали.
    // Детали оружия по командам guns.txt
    static List<Transform> Detail(string[] w, WeaponDef def, Transform parent)
    {
        var res = new List<Transform>();
        var metal = GunMat("metal", def); var dark = GunMat("dark", def); var body = GunMat("body", def);
        void Box(Material m, Vector3 c, Vector3 sz, Vector3 e = default(Vector3)) => res.Add(MeshKit.Part(parent, MeshKit.Cube, m, c, sz, e).transform);
        void Cyl(Material m, Vector3 c, float d, float l, Vector3 e) => res.Add(MeshKit.Part(parent, MeshKit.Frustum(1f, 10), m, c, new Vector3(d, l, d), e).transform);
        switch (w[0])
        {
            case "rail":   // rail x y z0 z1 — планка Пикатинни с поперечными пазами
            {
                float x = F(w[1]), y = F(w[2]), z0 = F(w[3]), z1 = F(w[4]);
                Box(metal, new Vector3(x, y, (z0 + z1) / 2), new Vector3(0.016f, 0.005f, z1 - z0));
                for (float z = z0 + 0.004f; z < z1 - 0.003f; z += 0.01f)
                    Box(metal, new Vector3(x, y + 0.0045f, z), new Vector3(0.021f, 0.004f, 0.0052f));
                break;
            }
            case "slots":  // slots x y z0 z1 n — прорези M-LOK по бокам цевья
            {
                float x = F(w[1]), y = F(w[2]), z0 = F(w[3]), z1 = F(w[4]); int n = int.Parse(w[5]);
                float step = (z1 - z0) / n;
                for (int i = 0; i < n; i++)
                    foreach (float sx in new[] { -x, x })
                        Box(dark, new Vector3(sx, y, z0 + step * (i + 0.5f)), new Vector3(0.002f, 0.009f, step * 0.62f));
                break;
            }
            case "port":   // port z y x — окно выброса гильз, отражатель, досылатель
            {
                float z = F(w[1]), y = F(w[2]), x = F(w[3]);
                Box(dark, new Vector3(x, y, z), new Vector3(0.003f, 0.016f, 0.05f));
                Box(metal, new Vector3(x + 0.002f, y + 0.012f, z - 0.03f), new Vector3(0.006f, 0.012f, 0.012f));
                Cyl(metal, new Vector3(x - 0.002f, y + 0.004f, z - 0.045f), 0.012f, 0.012f, new Vector3(0, 0, 90));
                break;
            }
            case "tguard": // tguard z y — спусковая скоба и спусковой крючок
            {
                float z = F(w[1]), y = F(w[2]);
                Box(metal, new Vector3(0, y - 0.03f, z + 0.03f), new Vector3(0.008f, 0.004f, 0.075f));
                Box(metal, new Vector3(0, y - 0.015f, z + 0.068f), new Vector3(0.008f, 0.03f, 0.004f));
                Box(metal, new Vector3(0, y - 0.012f, z + 0.03f), new Vector3(0.005f, 0.022f, 0.005f), new Vector3(-18f, 0, 0));
                break;
            }
            case "brake":  // brake z y d — дульный тормоз с окнами
            {
                float z = F(w[1]), y = F(w[2]), d = F(w[3]);
                Cyl(metal, new Vector3(0, y, z), d, 0.055f, new Vector3(90, 0, 0));
                for (int i = 0; i < 3; i++)
                    foreach (float sx in new[] { -1f, 1f })
                        Box(dark, new Vector3(sx * d * 0.48f, y, z - 0.018f + i * 0.016f), new Vector3(0.004f, d * 0.55f, 0.007f));
                Box(dark, new Vector3(0, y + d * 0.48f, z + 0.008f), new Vector3(d * 0.4f, 0.004f, 0.02f));
                break;
            }
            case "ribs":   // ribs z0 y0 z1 y1 n w — рёбра жёсткости магазина
            {
                float z0 = F(w[1]), y0 = F(w[2]), z1 = F(w[3]), y1 = F(w[4]); int n = int.Parse(w[5]); float mw = F(w[6]);
                for (int i = 0; i < n; i++)
                {
                    float k = (i + 0.5f) / n;
                    foreach (float sx in new[] { -1f, 1f })
                        Box(dark, new Vector3(sx * (mw * 0.5f + 0.001f), Mathf.Lerp(y0, y1, k), Mathf.Lerp(z0, z1, k)), new Vector3(0.002f, 0.005f, 0.03f));
                }
                break;
            }
            case "bolt":   // bolt z y — рукоять заряжания
            {
                float z = F(w[1]), y = F(w[2]);
                Box(metal, new Vector3(0, y, z), new Vector3(0.012f, 0.006f, 0.03f));
                Box(metal, new Vector3(0, y, z - 0.016f), new Vector3(0.034f, 0.008f, 0.008f));
                break;
            }
            case "sling":  // sling z y — антабка
            {
                float z = F(w[1]), y = F(w[2]);
                Box(metal, new Vector3(-0.012f, y, z), new Vector3(0.004f, 0.014f, 0.022f));
                Box(metal, new Vector3(-0.016f, y - 0.008f, z), new Vector3(0.006f, 0.004f, 0.024f));
                break;
            }
        }
        return res;
    }

    // Выдавливание профиля с фаской по краям: грани ловят свет, деталь не выглядит вырезанной из картона
    public static Mesh ExtrudeBevel(List<Vector2> pts, float w, float c)
    {
        int n = pts.Count;
        if (c < 0.0008f || n < 3) return Extrude(pts, w);
        float area = 0;
        for (int i = 0; i < n; i++) { var p = pts[i]; var q = pts[(i + 1) % n]; area += p.x * q.y - q.x * p.y; }
        // вершины, сдвинутые внутрь на c
        var inn = new List<Vector2>(n);
        for (int i = 0; i < n; i++)
        {
            Vector2 a = pts[(i + n - 1) % n], p = pts[i], b = pts[(i + 1) % n];
            Vector2 e1 = (p - a).normalized, e2 = (b - p).normalized;
            Vector2 n1 = area > 0 ? new Vector2(-e1.y, e1.x) : new Vector2(e1.y, -e1.x);
            Vector2 n2 = area > 0 ? new Vector2(-e2.y, e2.x) : new Vector2(e2.y, -e2.x);
            Vector2 m = n1 + n2;
            float d = 1f + Vector2.Dot(n1, n2);
            Vector2 off = d > 0.15f ? m / d * c : (n1 + n2).normalized * c;
            if (off.magnitude > c * 2.5f) off = off.normalized * c * 2.5f;
            inn.Add(p + off);
        }
        var tris = Triangulate(pts);
        var v = new List<Vector3>(); var t = new List<int>();
        float h = w / 2f, ho = h - c;
        foreach (var tr in tris)
        {
            Vector3 a = new Vector3(h, inn[tr.x].y, inn[tr.x].x), b = new Vector3(h, inn[tr.y].y, inn[tr.y].x), cc = new Vector3(h, inn[tr.z].y, inn[tr.z].x);
            AddTri(v, t, a, b, cc, Vector3.right);
            a.x = b.x = cc.x = -h;
            AddTri(v, t, a, b, cc, Vector3.left);
        }
        for (int i = 0; i < n; i++)
        {
            Vector2 p = pts[i], q = pts[(i + 1) % n], pi = inn[i], qi = inn[(i + 1) % n];
            Vector2 e = q - p;
            Vector2 nn = area > 0 ? new Vector2(e.y, -e.x) : new Vector2(-e.y, e.x);
            Vector3 outN = new Vector3(0, nn.y, nn.x).normalized;
            // пояс
            Vector3 A = new Vector3(-ho, p.y, p.x), B = new Vector3(ho, p.y, p.x), C = new Vector3(ho, q.y, q.x), D = new Vector3(-ho, q.y, q.x);
            AddTri(v, t, A, B, C, outN); AddTri(v, t, A, C, D, outN);
            // фаски с обеих сторон
            foreach (float sx in new[] { -1f, 1f })
            {
                Vector3 P0 = new Vector3(sx * ho, p.y, p.x), Q0 = new Vector3(sx * ho, q.y, q.x);
                Vector3 P1 = new Vector3(sx * h, pi.y, pi.x), Q1 = new Vector3(sx * h, qi.y, qi.x);
                Vector3 want = outN + Vector3.right * sx;
                AddTri(v, t, P0, Q0, Q1, want); AddTri(v, t, P0, Q1, P1, want);
            }
        }
        var mesh = new Mesh();
        mesh.SetVertices(v); mesh.SetTriangles(t, 0);
        mesh.RecalculateNormals(); mesh.RecalculateBounds();
        return mesh;
    }

    public static Mesh Extrude(List<Vector2> pts, float w)
    {
        int n = pts.Count;
        var tris = Triangulate(pts);
        var v = new List<Vector3>();
        var t = new List<int>();
        float h = w / 2f;
        // боковины
        foreach (var tr in tris)
        {
            // сторона +X: смотрим с +X, ось Z вправо... подбираем порядок по знаку
            Vector3 a = new Vector3(h, pts[tr.x].y, pts[tr.x].x), b = new Vector3(h, pts[tr.y].y, pts[tr.y].x), c = new Vector3(h, pts[tr.z].y, pts[tr.z].x);
            AddTri(v, t, a, b, c, Vector3.right);
            a.x = b.x = c.x = -h;
            AddTri(v, t, a, b, c, Vector3.left);
        }
        // торцы
        float area = 0;
        for (int i = 0; i < n; i++) { var p = pts[i]; var q = pts[(i + 1) % n]; area += p.x * q.y - q.x * p.y; }
        for (int i = 0; i < n; i++)
        {
            Vector2 p = pts[i], q = pts[(i + 1) % n];
            Vector3 A = new Vector3(-h, p.y, p.x), B = new Vector3(h, p.y, p.x), C = new Vector3(h, q.y, q.x), D = new Vector3(-h, q.y, q.x);
            // наружная нормаль ребра в плоскости (z,y)
            Vector2 e = q - p;
            Vector2 nn = area > 0 ? new Vector2(e.y, -e.x) : new Vector2(-e.y, e.x);
            Vector3 outN = new Vector3(0, nn.y, nn.x);
            AddTri(v, t, A, B, C, outN);
            AddTri(v, t, A, C, D, outN);
        }
        var m = new Mesh();
        m.SetVertices(v); m.SetTriangles(t, 0);
        m.RecalculateNormals(); m.RecalculateBounds();
        return m;
    }

    // треугольник с порядком вершин, дающим нормаль по направлению want (Unity: по часовой стрелке)
    static void AddTri(List<Vector3> v, List<int> t, Vector3 a, Vector3 b, Vector3 c, Vector3 want)
    {
        Vector3 n = Vector3.Cross(b - a, c - a);
        int i = v.Count;
        if (Vector3.Dot(n, want) >= 0) { v.Add(a); v.Add(b); v.Add(c); }
        else { v.Add(a); v.Add(c); v.Add(b); }
        t.Add(i); t.Add(i + 1); t.Add(i + 2);
    }

    // Триангуляция многоугольника "отсечением ушей"
    public static List<Vector3Int> Triangulate(List<Vector2> pts)
    {
        var res = new List<Vector3Int>();
        var idx = new List<int>();
        for (int i = 0; i < pts.Count; i++) idx.Add(i);
        float area = 0;
        for (int i = 0; i < pts.Count; i++) { var p = pts[i]; var q = pts[(i + 1) % pts.Count]; area += p.x * q.y - q.x * p.y; }
        if (area < 0) idx.Reverse();
        int guard = 0;
        while (idx.Count > 3 && guard++ < 2000)
        {
            bool cut = false;
            for (int k = 0; k < idx.Count; k++)
            {
                int a = idx[(k - 1 + idx.Count) % idx.Count], b = idx[k], c = idx[(k + 1) % idx.Count];
                Vector2 A = pts[a], B = pts[b], C = pts[c];
                float cr = (B.x - A.x) * (C.y - A.y) - (B.y - A.y) * (C.x - A.x);
                if (cr <= 1e-9f) continue;
                bool inside = false;
                foreach (int o in idx)
                {
                    if (o == a || o == b || o == c) continue;
                    Vector2 P = pts[o];
                    float d1 = (B.x - A.x) * (P.y - A.y) - (B.y - A.y) * (P.x - A.x);
                    float d2 = (C.x - B.x) * (P.y - B.y) - (C.y - B.y) * (P.x - B.x);
                    float d3 = (A.x - C.x) * (P.y - C.y) - (A.y - C.y) * (P.x - C.x);
                    if (d1 >= 0 && d2 >= 0 && d3 >= 0) { inside = true; break; }
                }
                if (inside) continue;
                res.Add(new Vector3Int(a, b, c));
                idx.RemoveAt(k);
                cut = true;
                break;
            }
            if (!cut) break;
        }
        if (idx.Count == 3) res.Add(new Vector3Int(idx[0], idx[1], idx[2]));
        return res;
    }
}
