using System.Collections.Generic;
using System.IO;
using UnityEngine;

// Клипы захвата движения (CMU Graphics Lab Motion Capture Database, mocap.cs.cmu.edu),
// перенесённые на наш 17-костный скелет: циклы шага, бег, шаг спиной, вбок, гусиный шаг, ранение, зомби.
// Каждый клип — один цикл шага, начинается с постановки левой ноги; позы — локальные повороты костей.
public class MoClip
{
    public string name;
    public int n;
    public float dur, dist;
    public Vector2 dir;
    public Vector3[] hips;
    public Quaternion[] q;   // n * 17
    public float Speed => dist / Mathf.Max(0.01f, dur);

    // Шаг при скорости v: длина шага растёт медленнее скорости (частота тоже растёт)
    public float StrideAt(float v) => dist * Mathf.Sqrt(Mathf.Clamp(v / Mathf.Max(0.05f, Speed), 0.55f, 2.2f));

    public void Sample(float ph, int bone, out Quaternion r)
    {
        float f = Mathf.Repeat(ph, 1f) * n;
        int i0 = (int)f % n, i1 = (i0 + 1) % n;
        r = Quaternion.Slerp(q[i0 * HumanRig.Count + bone], q[i1 * HumanRig.Count + bone], f - Mathf.Floor(f));
    }

    public Vector3 SampleHips(float ph)
    {
        float f = Mathf.Repeat(ph, 1f) * n;
        int i0 = (int)f % n, i1 = (i0 + 1) % n;
        return Vector3.Lerp(hips[i0], hips[i1], f - Mathf.Floor(f));
    }
}

public static class Mocap
{
    static Dictionary<string, MoClip> clips;
    public static bool Ready => Load() && clips.Count > 0;

    static bool Load()
    {
        if (clips != null) return true;
        clips = new Dictionary<string, MoClip>();
        var ta = Resources.Load<TextAsset>("Anim/locomotion");
        if (ta == null) return true;
        using (var br = new BinaryReader(new MemoryStream(ta.bytes)))
        {
            br.ReadBytes(4); br.ReadInt32();
            int nc = br.ReadInt32();
            for (int c = 0; c < nc; c++)
            {
                var clip = new MoClip();
                int len = br.ReadByte();
                clip.name = System.Text.Encoding.UTF8.GetString(br.ReadBytes(len));
                clip.n = br.ReadInt32(); clip.dur = br.ReadSingle(); clip.dist = br.ReadSingle();
                clip.dir = new Vector2(br.ReadSingle(), br.ReadSingle());
                clip.hips = new Vector3[clip.n];
                clip.q = new Quaternion[clip.n * HumanRig.Count];
                for (int i = 0; i < clip.n; i++)
                {
                    clip.hips[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                    for (int j = 0; j < HumanRig.Count; j++)
                        clip.q[i * HumanRig.Count + j] = new Quaternion(br.ReadSingle(), br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                }
                clips[clip.name] = clip;
            }
        }
        return true;
    }

    public static MoClip Get(string name) { Load(); return clips.TryGetValue(name, out var c) ? c : null; }
}

// Смешивание нескольких клипов с общей фазой (blend space)
public class MocapBlend
{
    readonly List<MoClip> cl = new List<MoClip>();
    readonly List<float> w = new List<float>();
    readonly Vector4[] acc = new Vector4[HumanRig.Count];
    public readonly Quaternion[] pose = new Quaternion[HumanRig.Count];
    public Vector3 hips;

    public void Clear() { cl.Clear(); w.Clear(); }
    public void Add(MoClip c, float weight)
    {
        if (c == null || weight <= 0.0001f) return;
        for (int i = 0; i < cl.Count; i++) if (cl[i] == c) { w[i] += weight; return; }
        cl.Add(c); w.Add(weight);
    }
    public float Total { get { float t = 0; foreach (var x in w) t += x; return t; } }

    // Средняя длина шага при скорости v
    public float Stride(float v)
    {
        float t = Total, s = 0;
        if (t <= 0) return 1f;
        for (int i = 0; i < cl.Count; i++) s += cl[i].StrideAt(v) * w[i];
        return s / t;
    }

    public bool Evaluate(float ph)
    {
        float t = Total;
        if (t <= 0) return false;
        hips = Vector3.zero;
        for (int j = 0; j < HumanRig.Count; j++) acc[j] = Vector4.zero;
        for (int i = 0; i < cl.Count; i++)
        {
            float k = w[i] / t;
            hips += cl[i].SampleHips(ph) * k;
            for (int j = 0; j < HumanRig.Count; j++)
            {
                cl[i].Sample(ph, j, out var r);
                var v = new Vector4(r.x, r.y, r.z, r.w);
                if (i > 0 && Vector4.Dot(v, acc[j]) < 0) v = -v;
                acc[j] += v * k;
            }
        }
        for (int j = 0; j < HumanRig.Count; j++)
        {
            var v = acc[j].normalized;
            pose[j] = new Quaternion(v.x, v.y, v.z, v.w);
        }
        return true;
    }
}
