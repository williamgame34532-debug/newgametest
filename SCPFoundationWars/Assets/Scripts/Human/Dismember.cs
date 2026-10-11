using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// Расчленение: часть тела отделяется от модели (кусок меша со своей физикой), на теле кость сжимается,
// из культи бьёт кровь. Источники: взрывы, атаки SCP (096, 682, 939), мощные попадания (снайпер, дробь в упор).
public static class Dismember
{
    public static bool Enabled = true;

    static int[] ChainOf(int bone)
    {
        switch (bone)
        {
            case HumanRig.Head: case HumanRig.Neck: return new[] { HumanRig.Head };
            case HumanRig.UArmL: return new[] { HumanRig.UArmL, HumanRig.LArmL, HumanRig.HandL };
            case HumanRig.LArmL: case HumanRig.HandL: return new[] { HumanRig.LArmL, HumanRig.HandL };
            case HumanRig.UArmR: return new[] { HumanRig.UArmR, HumanRig.LArmR, HumanRig.HandR };
            case HumanRig.LArmR: case HumanRig.HandR: return new[] { HumanRig.LArmR, HumanRig.HandR };
            case HumanRig.ULegL: return new[] { HumanRig.ULegL, HumanRig.LLegL, HumanRig.FootL };
            case HumanRig.LLegL: case HumanRig.FootL: return new[] { HumanRig.LLegL, HumanRig.FootL };
            case HumanRig.ULegR: return new[] { HumanRig.ULegR, HumanRig.LLegR, HumanRig.FootR };
            case HumanRig.LLegR: case HumanRig.FootR: return new[] { HumanRig.LLegR, HumanRig.FootR };
            default: return null;
        }
    }

    static readonly int[] Limbs = { HumanRig.Head, HumanRig.UArmL, HumanRig.UArmR, HumanRig.LArmL, HumanRig.LArmR, HumanRig.ULegL, HumanRig.ULegR, HumanRig.LLegL, HumanRig.LLegR };

    // Решаем при смерти, что оторвать
    public static void OnDeath(Soldier s, DamageInfo d)
    {
        if (!Enabled || Fx.BloodLevel <= 0.01f || s == null || s.rig == null || s.rig.body == null) return;
        int hitBone = d.hitbox != null ? System.Array.IndexOf(s.rig.b, d.hitbox.transform) : -1;
        var scp = d.attacker as ScpUnit;
        Vector3 imp = d.dir * Mathf.Max(3f, d.force * 0.01f);
        if (d.type == DamageType.Explosion)
        {
            int n = Random.value < 0.5f ? 1 : Random.value < 0.5f ? 2 : 0;
            for (int i = 0; i < n; i++) Cut(s, Limbs[Random.Range(0, Limbs.Length)], (Random.insideUnitSphere + Vector3.up) * Random.Range(4f, 9f));
        }
        else if (scp != null)
        {
            if (scp.kind == ScpKind.S096) { Cut(s, Random.value < 0.7f ? HumanRig.Head : Limbs[Random.Range(1, 5)], imp + Vector3.up * 3f); if (Random.value < 0.4f) Cut(s, Limbs[Random.Range(1, Limbs.Length)], imp); }
            else if (scp.kind == ScpKind.S682) { if (Random.value < 0.75f) Cut(s, Limbs[Random.Range(0, Limbs.Length)], imp * 2f + Vector3.up * 4f); }
            else if (scp.kind == ScpKind.S939) { if (Random.value < 0.55f) Cut(s, Limbs[Random.Range(0, Limbs.Length)], imp + Vector3.up * 2f); }
        }
        else if (d.type == DamageType.Bullet && hitBone >= 0)
        {
            bool heavy = d.amount >= 85f || (d.weapon != null && (d.weapon.Contains("SVD") || d.weapon.Contains("DMR") || d.weapon.Contains("M870") || d.weapon.Contains("Сайга") || d.weapon.Contains("Saiga")));
            float chance = heavy ? (hitBone == HumanRig.Head ? 0.35f : 0.3f) : 0.03f;
            if (ChainOf(hitBone) != null && Random.value < chance) Cut(s, hitBone, imp);
        }
    }

    public static void Cut(Soldier s, int bone, Vector3 impulse)
    {
        var chain = ChainOf(bone);
        var smr = s.rig.body;
        if (chain == null || smr == null || smr.sharedMesh == null) return;
        Transform root = s.rig.b[chain[0]];
        if (root.localScale.x < 0.01f) return;       // уже оторвано
        var inChain = new bool[HumanRig.Count];
        foreach (var c in chain) inChain[c] = true;

        // запекаем текущую позу и вырезаем треугольники этой части
        var baked = new Mesh();
        smr.BakeMesh(baked, true);
        var bv = baked.vertices;
        var src = smr.sharedMesh;
        var bw = src.boneWeights;
        Matrix4x4 l2w = Matrix4x4.TRS(smr.transform.position, smr.transform.rotation, Vector3.one);
        var verts = new List<Vector3>(); var uvs = new List<Vector2>(); var srcUV = new List<Vector2>(); src.GetUVs(0, srcUV);
        var map = new Dictionary<int, int>();
        var subs = new List<List<int>>(); var mats = new List<Material>();
        Vector3 center = root.position;
        for (int sm = 0; sm < src.subMeshCount; sm++)
        {
            var tris = src.GetTriangles(sm);
            List<int> outT = null;
            for (int t = 0; t < tris.Length; t += 3)
            {
                bool ok = true;
                for (int k = 0; k < 3 && ok; k++)
                {
                    var w = bw[tris[t + k]];
                    float inW = (inChain[w.boneIndex0] ? w.weight0 : 0) + (inChain[w.boneIndex1] ? w.weight1 : 0) + (inChain[w.boneIndex2] ? w.weight2 : 0) + (inChain[w.boneIndex3] ? w.weight3 : 0);
                    ok = inW > 0.5f;
                }
                if (!ok) continue;
                if (outT == null) { outT = new List<int>(); subs.Add(outT); mats.Add(smr.sharedMaterials[Mathf.Min(sm, smr.sharedMaterials.Length - 1)]); }
                for (int k = 0; k < 3; k++)
                {
                    int vi = tris[t + k];
                    if (!map.TryGetValue(vi, out int ni))
                    {
                        ni = verts.Count; map[vi] = ni;
                        verts.Add(l2w.MultiplyPoint3x4(bv[vi]) - center);
                        uvs.Add(vi < srcUV.Count ? srcUV[vi] : Vector2.zero);
                    }
                    outT.Add(ni);
                }
            }
        }
        Object.Destroy(baked);
        if (verts.Count < 12) return;

        var m = new Mesh { name = "gib" };
        m.SetVertices(verts);
        if (uvs.Count == verts.Count) m.SetUVs(0, uvs);
        m.subMeshCount = subs.Count;
        for (int i = 0; i < subs.Count; i++) m.SetTriangles(subs[i], i);
        m.RecalculateNormals(); m.RecalculateBounds();

        var go = new GameObject("gib");
        go.layer = Layers.Corpse;
        go.transform.position = center;
        go.AddComponent<MeshFilter>().sharedMesh = m;
        var mr = go.AddComponent<MeshRenderer>(); mr.sharedMaterials = mats.ToArray();
        // снаряжение, висевшее на оторванной части (каска, подсумки), уходит вместе с ней
        foreach (var c in chain)
            foreach (Transform ch in s.rig.b[c])
            {
                if (ch.GetComponent<MeshRenderer>() == null || System.Array.IndexOf(s.rig.b, ch) >= 0 || ch.GetComponentInChildren<Joint>() != null) continue;
                var copy = Object.Instantiate(ch.gameObject, ch.position, ch.rotation, go.transform);
                foreach (var col in copy.GetComponentsInChildren<Collider>()) Object.Destroy(col);
                foreach (var hb in copy.GetComponentsInChildren<Hitbox>()) Object.Destroy(hb);
                foreach (var rb in copy.GetComponentsInChildren<Rigidbody>()) Object.Destroy(rb);
            }
        var bc = go.AddComponent<BoxCollider>(); bc.center = m.bounds.center; bc.size = Vector3.Max(m.bounds.size, Vector3.one * 0.08f);
        var body = go.AddComponent<Rigidbody>();
        body.mass = chain[0] == HumanRig.Head ? 4.5f : chain.Length == 3 ? 7f : 3.5f;
        body.SetVel(impulse + Random.insideUnitSphere * 1.5f);
        body.angularVelocity = Random.insideUnitSphere * 8f;
        go.AddComponent<Surface>().color = new Color(0.45f, 0.02f, 0.02f);
        Object.Destroy(go, 90f);

        // часть исчезает с тела
        root.localScale = Vector3.one * 0.0001f;
        Sfx.Play("flesh", center, 1f, Random.Range(0.7f, 0.85f), 35f);
        Fx.Blood(center, impulse.normalized, 2.5f);
        // культя: кровь толчками несколько секунд, кровь и на оторванной части
        s.StartCoroutine(Stump(root.parent, root, impulse.normalized));
        go.AddComponent<GibBleed>();
    }

    static IEnumerator Stump(Transform parent, Transform cut, Vector3 dir)
    {
        float end = Time.time + Random.Range(3.5f, 6f);
        bool pool = false;
        while (Time.time < end && parent != null && cut != null)
        {
            Vector3 at = cut.position;
            Vector3 d = (at - parent.position).normalized;
            if (d.sqrMagnitude < 0.01f) d = dir;
            float pulse = 0.6f + 0.4f * Mathf.Sin(Time.time * 7f);
            Fx.Blood(at, (d + Random.insideUnitSphere * 0.3f).normalized, 0.35f * pulse);
            if (!pool && Time.time > end - 2.5f && Physics.Raycast(at + Vector3.up * 0.2f, Vector3.down, out var h, 2f, 1 << Layers.World, QueryTriggerInteraction.Ignore))
            { Fx.BloodPool(h.point, Random.Range(0.6f, 1.1f)); pool = true; }
            yield return new WaitForSeconds(0.12f);
        }
    }
}

// Оторванная часть: капает кровью первые секунды
public class GibBleed : MonoBehaviour
{
    float end;
    void Start() { end = Time.time + 3f; }
    void Update()
    {
        if (Time.time > end) { enabled = false; return; }
        if (Random.value < Time.deltaTime * 8f) Fx.Blood(transform.position, Random.onUnitSphere, 0.2f);
    }
}
