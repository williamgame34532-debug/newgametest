using System.Collections.Generic;
using UnityEngine;

// Синтезатор звуков: все звуки (выстрелы, взрывы, лопасти вертолёта, крик SCP-096...) генерируются кодом.
public static class Sfx
{
    const int SR = 44100;
    static readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();
    static readonly List<AudioSource> pool = new List<AudioSource>();
    static GameObject host;
    static int next;
    public static float Volume = 0.9f;

    static System.Random rng = new System.Random(1234);
    static float N() => (float)(rng.NextDouble() * 2.0 - 1.0);

    public static void Init()
    {
        if (host != null) return;
        host = new GameObject("SfxPool");
        Object.DontDestroyOnLoad(host);
        for (int i = 0; i < 56; i++)
        {
            var go = new GameObject("src");
            go.transform.SetParent(host.transform);
            var s = go.AddComponent<AudioSource>();
            s.playOnAwake = false;
            s.rolloffMode = AudioRolloffMode.Linear;
            s.dopplerLevel = 0f;
            pool.Add(s);
        }
        Build();
    }

    public static AudioClip Clip(string name) { clips.TryGetValue(name, out var c); return c; }

    public static void Play(string name, Vector3 pos, float vol = 1f, float pitch = 1f, float maxDist = 120f, float spatial = 1f)
    {
        if (!clips.TryGetValue(name, out var c) || c == null) return;
        var s = pool[next]; next = (next + 1) % pool.Count;
        // не перебиваем громкие звуки, если источник ещё играет — ищем свободный
        for (int i = 0; i < 6 && s.isPlaying; i++) { s = pool[next]; next = (next + 1) % pool.Count; }
        s.transform.position = pos;
        s.clip = c;
        s.volume = vol * Volume;
        s.pitch = pitch * Time.timeScale;
        s.spatialBlend = spatial;
        s.minDistance = 2f;
        s.maxDistance = maxDist;
        s.Play();
    }

    public static void Play2D(string name, float vol = 1f, float pitch = 1f)
    {
        var cam = Camera.main;
        Play(name, cam != null ? cam.transform.position : Vector3.zero, vol, pitch, 50f, 0f);
    }

    public static AudioSource Loop(string name, Transform parent, float vol = 1f, float maxDist = 150f, float pitch = 1f)
    {
        var go = new GameObject("loop_" + name);
        go.transform.SetParent(parent, false);
        var s = go.AddComponent<AudioSource>();
        s.clip = Clip(name);
        s.loop = true;
        s.volume = vol * Volume;
        s.pitch = pitch;
        s.spatialBlend = 1f;
        s.rolloffMode = AudioRolloffMode.Linear;
        s.minDistance = 4f;
        s.maxDistance = maxDist;
        s.dopplerLevel = 0.3f;
        if (s.clip != null) s.Play();
        return s;
    }

    // ---------------- синтез ----------------
    static AudioClip Make(string name, float seconds, System.Func<float, int, float> fn)
    {
        int n = Mathf.Max(1, (int)(seconds * SR));
        var data = new float[n];
        for (int i = 0; i < n; i++) data[i] = fn(i / (float)SR, i);
        Normalize(data, 0.95f);
        var c = AudioClip.Create(name, n, 1, SR, false);
        c.SetData(data, 0);
        clips[name] = c;
        return c;
    }

    static void Normalize(float[] d, float peak)
    {
        float m = 0.0001f;
        for (int i = 0; i < d.Length; i++) m = Mathf.Max(m, Mathf.Abs(d[i]));
        float k = peak / m;
        for (int i = 0; i < d.Length; i++) d[i] *= k;
    }

    // Выстрел: щелчок + шумовой удар с фильтром + низкий "бум" + хвост-эхо
    static void Gunshot(string name, float len, float body, float low, float crack, float tail, float lp)
    {
        float lpState = 0, lp2 = 0, bp = 0;
        Make(name, len, (t, i) =>
        {
            float env = Mathf.Exp(-t * body);
            float n = N();
            lpState += (n - lpState) * lp;
            lp2 += (lpState - lp2) * lp;
            float boom = Mathf.Sin(2 * Mathf.PI * low * t * (1f - t * 2f)) * Mathf.Exp(-t * body * 0.6f);
            float c = t < 0.004f ? N() * crack : 0;
            float echo = t > 0.05f ? lp2 * Mathf.Exp(-(t - 0.05f) * tail) * 0.35f : 0;
            bp += (n - bp) * 0.5f;
            return (lpState * 0.7f + lp2 * 0.6f) * env + boom * env * 0.9f + c + echo + bp * env * 0.15f;
        });
    }

    static void Build()
    {
        Gunshot("rifle", 0.9f, 22f, 90f, 1.2f, 6f, 0.35f);
        Gunshot("smg", 0.6f, 30f, 120f, 1f, 9f, 0.45f);
        Gunshot("lmg", 0.9f, 18f, 75f, 1.3f, 5f, 0.3f);
        Gunshot("pistol", 0.6f, 28f, 140f, 1f, 9f, 0.5f);
        Gunshot("shotgun", 1.2f, 12f, 60f, 1.4f, 4f, 0.25f);
        Gunshot("sniper", 1.6f, 10f, 55f, 1.6f, 2.5f, 0.28f);
        {
            float lp = 0;
            Make("suppressed", 0.25f, (t, i) => { lp += (N() - lp) * 0.12f; return lp * Mathf.Exp(-t * 45f) + Mathf.Sin(t * 2 * Mathf.PI * 300) * Mathf.Exp(-t * 80) * 0.3f; });
        }
        {
            float lp = 0;
            Make("explosion", 3.2f, (t, i) =>
            {
                lp += (N() - lp) * (0.08f + 0.2f * Mathf.Exp(-t * 4f));
                float boom = Mathf.Sin(2 * Mathf.PI * (45f - t * 10f) * t) * Mathf.Exp(-t * 2.2f);
                float crack = t < 0.02f ? N() : 0;
                return lp * Mathf.Exp(-t * 1.6f) * 1.4f + boom * 1.1f + crack * 0.6f;
            });
        }
        {
            float lp = 0;
            Make("rocket", 1.4f, (t, i) => { lp += (N() - lp) * 0.3f; return lp * (Mathf.Min(1, t * 30f)) * Mathf.Exp(-t * 1.6f) + (t < 0.01f ? N() : 0); });
        }
        {
            float lp = 0;
            Make("flesh", 0.25f, (t, i) => { lp += (N() - lp) * 0.08f; return lp * Mathf.Exp(-t * 30f) + Mathf.Sin(t * 2 * Mathf.PI * 90) * Mathf.Exp(-t * 25) * 0.6f; });
        }
        {
            float lp = 0;
            Make("headshot", 0.3f, (t, i) => { lp += (N() - lp) * 0.3f; return lp * Mathf.Exp(-t * 35f) + Mathf.Sin(t * 2 * Mathf.PI * 1800) * Mathf.Exp(-t * 60) * 0.5f; });
        }
        Make("ricochet", 0.45f, (t, i) => Mathf.Sin(2 * Mathf.PI * (2600f - t * 3200f) * t) * Mathf.Exp(-t * 8f) * 0.6f + N() * Mathf.Exp(-t * 60f) * 0.6f);
        Make("metal", 0.5f, (t, i) => (Mathf.Sin(2 * Mathf.PI * 1250 * t) + Mathf.Sin(2 * Mathf.PI * 1930 * t) * 0.6f + Mathf.Sin(2 * Mathf.PI * 3170 * t) * 0.3f) * Mathf.Exp(-t * 12f) + N() * Mathf.Exp(-t * 80f));
        {
            float lp = 0;
            Make("dirt", 0.2f, (t, i) => { lp += (N() - lp) * 0.2f; return lp * Mathf.Exp(-t * 35f); });
        }
        Make("click", 0.06f, (t, i) => N() * Mathf.Exp(-t * 200f) + Mathf.Sin(2 * Mathf.PI * 2200 * t) * Mathf.Exp(-t * 150f));
        Make("magout", 0.15f, (t, i) => (N() * 0.5f + Mathf.Sin(2 * Mathf.PI * 700 * t)) * Mathf.Exp(-t * 45f));
        Make("magin", 0.2f, (t, i) => (t < 0.03f ? N() : 0) + Mathf.Sin(2 * Mathf.PI * 1100 * t) * Mathf.Exp(-t * 40f) + (t > 0.1f && t < 0.12f ? N() * 0.8f : 0));
        Make("bolt", 0.25f, (t, i) => (t < 0.02f || (t > 0.12f && t < 0.14f) ? N() : 0) + Mathf.Sin(2 * Mathf.PI * 900 * t) * Mathf.Exp(-t * 30f) * 0.5f);
        {
            float lp = 0;
            Make("step", 0.15f, (t, i) => { lp += (N() - lp) * 0.15f; return lp * Mathf.Exp(-t * 40f); });
        }
        {
            float lp = 0;
            Make("bodyfall", 0.5f, (t, i) => { lp += (N() - lp) * 0.06f; return lp * Mathf.Exp(-t * 12f) + Mathf.Sin(2 * Mathf.PI * 60 * t) * Mathf.Exp(-t * 14f) * 0.8f; });
        }
        Make("snap", 0.25f, (t, i) => (t < 0.01f ? N() : 0) + (t > 0.03f && t < 0.045f ? N() * 0.8f : 0) + Mathf.Sin(2 * Mathf.PI * 400 * t) * Mathf.Exp(-t * 50f) * 0.5f);
        {
            float lp = 0;
            Make("grenade_bounce", 0.2f, (t, i) => { lp += (N() - lp) * 0.4f; return lp * Mathf.Exp(-t * 50f) + Mathf.Sin(2 * Mathf.PI * 1500 * t) * Mathf.Exp(-t * 40) * 0.4f; });
        }
        // лопасти вертолёта: бесшовная петля 1 с, 5 ударов в секунду + турбина
        {
            float lp = 0, lp2 = 0;
            Make("rotor", 1f, (t, i) =>
            {
                float ph = (t * 5f) % 1f;
                float thump = Mathf.Exp(-ph * 9f);
                lp += (N() - lp) * 0.05f;
                lp2 += (N() - lp2) * 0.5f;
                float turb = Mathf.Sin(2 * Mathf.PI * 1100 * t) * 0.04f + Mathf.Sin(2 * Mathf.PI * 2200 * t) * 0.02f;
                return lp * (0.4f + thump * 1.6f) + Mathf.Sin(2 * Mathf.PI * 20 * t) * thump * 0.8f + turb + lp2 * 0.06f;
            });
        }
        // крик SCP-096
        {
            float lp = 0;
            Make("scream", 4f, (t, i) =>
            {
                float f = 520f + Mathf.Sin(t * 13f) * 60f + Mathf.Sin(t * 37f) * 25f + t * 40f;
                float ph = 2 * Mathf.PI * f * t;
                float v = Mathf.Sin(ph) + Mathf.Sin(ph * 2.01f) * 0.5f + Mathf.Sin(ph * 3.03f) * 0.3f;
                lp += (N() - lp) * 0.6f;
                float env = Mathf.Min(1f, t * 3f) * Mathf.Min(1f, (4f - t) * 2f);
                return (v * 0.6f + lp * 0.5f) * env;
            });
        }
        {
            float lp = 0;
            Make("cry", 2.5f, (t, i) =>
            {
                float sob = Mathf.Max(0, Mathf.Sin(t * 7f)) * (0.5f + 0.5f * Mathf.Sin(t * 1.3f));
                float f = 330f + Mathf.Sin(t * 20f) * 30f;
                lp += (N() - lp) * 0.2f;
                return (Mathf.Sin(2 * Mathf.PI * f * t) * 0.5f + lp * 0.4f) * sob;
            });
        }
        {
            float lp = 0, lp2 = 0;
            Make("scrape", 1f, (t, i) =>
            {
                lp += (N() - lp) * 0.25f; lp2 += (lp - lp2) * 0.3f;
                float grit = Mathf.Abs(Mathf.Sin(t * 2 * Mathf.PI * 23f)) * 0.5f + 0.5f;
                return (lp - lp2) * grit * 2.5f;
            });
        }
        // рёв SCP-682
        {
            float lp = 0;
            Make("roar", 3f, (t, i) =>
            {
                float f = 70f + Mathf.Sin(t * 3f) * 15f + (t < 0.4f ? t * 80f : 32f);
                float saw = ((f * t) % 1f) * 2f - 1f;
                lp += (N() - lp) * 0.15f;
                float env = Mathf.Min(1f, t * 4f) * Mathf.Exp(-Mathf.Max(0, t - 1.8f) * 2.5f);
                return (saw * 0.7f + lp * 0.8f) * env * (0.8f + 0.2f * Mathf.Sin(t * 40f));
            });
        }
        {
            float lp = 0;
            Make("growl", 1.6f, (t, i) =>
            {
                float f = 95f + Mathf.Sin(t * 9f) * 20f;
                float saw = ((f * t) % 1f) * 2f - 1f;
                lp += (N() - lp) * 0.1f;
                float env = Mathf.Sin(Mathf.PI * t / 1.6f);
                return (saw * 0.5f + lp) * env * (0.6f + 0.4f * Mathf.Abs(Mathf.Sin(t * 25f)));
            });
        }
        {
            float lp = 0;
            Make("groan", 1.8f, (t, i) =>
            {
                float f = 130f + Mathf.Sin(t * 2.5f) * 25f;
                float v = Mathf.Sin(2 * Mathf.PI * f * t) + Mathf.Sin(2 * Mathf.PI * f * 2.02f * t) * 0.4f;
                lp += (N() - lp) * 0.08f;
                return (v * 0.5f + lp * 0.7f) * Mathf.Sin(Mathf.PI * t / 1.8f);
            });
        }
        {
            float lp = 0;
            Make("laugh106", 2.4f, (t, i) =>
            {
                float pulse = Mathf.Max(0, Mathf.Sin(t * 2 * Mathf.PI * 3.2f));
                float f = 85f - t * 8f;
                lp += (N() - lp) * 0.12f;
                return (Mathf.Sin(2 * Mathf.PI * f * t) * 0.6f + lp * 0.7f) * pulse * Mathf.Exp(-t * 0.6f);
            });
        }
        {
            float lp = 0, lp2 = 0;
            Make("fire", 1f, (t, i) =>
            {
                lp += (N() - lp) * 0.2f; lp2 += (N() - lp2) * 0.02f;
                float crackle = rng.NextDouble() < 0.0015 ? N() * 2f : 0;
                return lp * 0.3f + lp2 * 1.2f + crackle;
            });
        }
        {
            float lp = 0;
            Make("whoosh", 0.6f, (t, i) => { lp += (N() - lp) * (0.05f + t * 0.4f); return lp * Mathf.Sin(Mathf.PI * t / 0.6f); });
        }
        Make("hitmarker", 0.08f, (t, i) => Mathf.Sin(2 * Mathf.PI * 2600 * t) * Mathf.Exp(-t * 60f));
        Make("ui", 0.08f, (t, i) => Mathf.Sin(2 * Mathf.PI * (900 + t * 4000) * t) * Mathf.Exp(-t * 50f));
        Make("alarm", 1.2f, (t, i) => Mathf.Sin(2 * Mathf.PI * (t % 0.6f < 0.3f ? 780 : 620) * t) * 0.6f * Mathf.Min(1, (1.2f - t) * 5f));
        {
            float lp = 0;
            Make("rope", 0.8f, (t, i) => { lp += (N() - lp) * 0.3f; return lp * 0.5f * Mathf.Min(1, t * 10) * Mathf.Min(1, (0.8f - t) * 6); });
        }
        Make("heartbeat", 0.8f, (t, i) => Mathf.Sin(2 * Mathf.PI * 50 * t) * (Mathf.Exp(-t * 18f) + (t > 0.25f ? Mathf.Exp(-(t - 0.25f) * 18f) * 0.7f : 0)));
    }
}
