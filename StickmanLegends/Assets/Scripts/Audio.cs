using System.Collections;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;
using UnityEngine.Networking;

namespace StickWars
{
    // Вся музыка и звуки синтезируются кодом. Можно подставить свою музыку по ссылке.
    public class Audio : MonoBehaviour
    {
        const int SR = 44100;
        const int SFX_SR = 22050;

        AudioSource music;
        AudioSource[] pool;
        int poolIdx;
        readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();

        AudioClip battleTrack, menuTrack, survTrack, customClip, customSurvClip;
        float[] battleData, menuData, survData;
        bool wantSurvival;
        public string urlStatus2 = "";
        volatile bool musicReady;
        bool wantBattle;
        public string urlStatus = "";
        public bool loadingUrl;
        public System.Action<string, float> OnSfx;
        float duck = 1f;

        void Awake()
        {
            music = gameObject.AddComponent<AudioSource>();
            music.loop = true;
            music.playOnAwake = false;
            pool = new AudioSource[14];
            for (int i = 0; i < pool.Length; i++)
            {
                pool[i] = gameObject.AddComponent<AudioSource>();
                pool[i].playOnAwake = false;
            }
            BuildSfx();
            var rev = gameObject.AddComponent<AudioReverbFilter>();
            rev.reverbPreset = AudioReverbPreset.Room;
            var th = new Thread(() =>
            {
                try
                {
                    battleData = Track(true);
                    menuData = Track(false);
                    survData = SurvivalTrack();
                }
                catch (System.Exception) { }
                musicReady = true;
            });
            th.IsBackground = true;
            th.Start();
        }

        void Update()
        {
            if (musicReady && battleTrack == null && battleData != null)
            {
                battleTrack = AudioClip.Create("battle", battleData.Length, 1, SR, false);
                battleTrack.SetData(battleData, 0);
                menuTrack = AudioClip.Create("menu", menuData.Length, 1, SR, false);
                menuTrack.SetData(menuData, 0);
                if (survData != null) { survTrack = AudioClip.Create("survival", survData.Length, 1, SR, false); survTrack.SetData(survData, 0); }
                PlayMusic(wantBattle, wantSurvival);
            }
            var s = Game.I != null ? Game.I.S : null;
            if (s != null)
            {
                duck = Mathf.MoveTowards(duck, 1f, Time.unscaledDeltaTime * 0.8f);
                music.volume = s.musicOn ? s.musicVol * duck * (wantBattle ? 1f : 0.75f) : 0f;
                if (music.clip != null && !music.isPlaying) music.Play();
            }
        }

        public AudioClip MusicClip { get { return music.clip; } }
        public float MusicTime { get { return music.clip != null ? music.time : 0f; } }
        public AudioClip Clip(string n) { AudioClip c; return clips.TryGetValue(n, out c) ? c : null; }

        public void Duck(float v) { duck = Mathf.Min(duck, v); }

        public void PlayMusic(bool battle) { PlayMusic(battle, false); }

        // у дуэли и у режима «Один против всех» — разная музыка (и своя ссылка для каждого)
        public void PlayMusic(bool battle, bool survival)
        {
            wantBattle = battle; wantSurvival = battle && survival;
            var s = Game.I != null ? Game.I.S : null;
            AudioClip c;
            if (wantSurvival)
                c = (s != null && s.useCustomSurvival && customSurvClip != null) ? customSurvClip : (s != null && s.useCustomMusic && customClip != null && customSurvClip == null) ? customClip : (survTrack ?? battleTrack);
            else
                c = (s != null && s.useCustomMusic && customClip != null) ? customClip : (battle ? battleTrack : menuTrack);
            if (c == null) return;
            if (music.clip != c)
            {
                music.clip = c;
                music.time = 0;
                music.Play();
            }
            else if (!music.isPlaying) music.Play();
        }

        public void RefreshMusic() { music.clip = null; PlayMusic(wantBattle, wantSurvival); }

        public void Sfx(string name, float vol = 1f, float pitchVar = 0.08f)
        {
            if (OnSfx != null) OnSfx(name, vol);
            if (VideoRecorder.I != null && VideoRecorder.I.Active) VideoRecorder.I.Sfx(name, vol);
            AudioClip c;
            if (!clips.TryGetValue(name, out c)) return;
            var s = Game.I != null ? Game.I.S : null;
            float v = (s != null ? s.sfxVol : 0.8f) * vol;
            if (v <= 0.001f) return;
            var src = pool[poolIdx];
            poolIdx = (poolIdx + 1) % pool.Length;
            src.pitch = 1f + Random.Range(-pitchVar, pitchVar);
            src.clip = c;
            src.volume = Mathf.Clamp01(v);
            src.Play();
        }

        // ---------- музыка по ссылке ----------
        public void LoadUrl(string url) { LoadUrl(url, 0); }
        int loadSlot;
        public void LoadUrl(string url, int slot)
        {
            if (string.IsNullOrEmpty(url)) { if (slot == 0) urlStatus = "Пустая ссылка"; else urlStatus2 = "Пустая ссылка"; return; }
            loadSlot = slot;
            StartCoroutine(LoadRoutine(url.Trim()));
        }

        IEnumerator LoadRoutine(string url)
        {
            int slot = loadSlot;
            yield return LoadRoutineInner(url, slot);
            if (slot == 1) { urlStatus2 = urlStatus; urlStatus = ""; }
        }

        IEnumerator LoadRoutineInner(string url, int slot)
        {
            loadingUrl = true;
            urlStatus = "Загрузка...";
            string low = url.ToLowerInvariant();
            AudioType type = AudioType.UNKNOWN;
            if (low.Contains(".mp3")) type = AudioType.MPEG;
            else if (low.Contains(".ogg")) type = AudioType.OGGVORBIS;
            else if (low.Contains(".wav")) type = AudioType.WAV;
            if (!low.StartsWith("http") && !low.StartsWith("file:"))
            {
                string path = url.Replace('\\', '/');
                url = path.StartsWith("/") ? "file://" + path : "file:///" + path;
            }
            if (low.Contains("youtube.com") || low.Contains("youtu.be"))
            {
                urlStatus = "YouTube напрямую не поддерживается — нужна прямая ссылка на .mp3/.ogg/.wav";
                loadingUrl = false;
                yield break;
            }
            using (var req = UnityWebRequestMultimedia.GetAudioClip(url, type))
            {
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                {
                    urlStatus = "Ошибка: " + req.error;
                }
                else
                {
                    AudioClip c = null;
                    try { c = DownloadHandlerAudioClip.GetContent(req); } catch (System.Exception e) { urlStatus = "Ошибка формата: " + e.Message; }
                    if (c != null && c.length > 0.1f)
                    {
                        if (slot == 1) { customSurvClip = c; if (Game.I != null) Game.I.S.useCustomSurvival = true; }
                        else { customClip = c; if (Game.I != null) Game.I.S.useCustomMusic = true; }
                        urlStatus = "Загружено! (" + Mathf.RoundToInt(c.length) + " сек)";
                        music.clip = null;
                        PlayMusic(wantBattle, wantSurvival);
                    }
                    else if (c != null) urlStatus = "Файл пустой или неподдерживаемый формат";
                }
            }
            loadingUrl = false;
        }

        public bool HasCustom { get { return customClip != null; } }
        public bool HasCustomSurvival { get { return customSurvClip != null; } }

        // «Один против всех»: 168 bpm, фригийский ми-минор, двойная бочка, рубленые гитарные риффы, хор, тремоло-мелодия
        static float[] SurvivalTrack()
        {
            var r = new System.Random(11);
            float bpm = 168f, beat = 60f / bpm, step = beat / 4f;
            int bars = 16;
            int n = (int)(bars * 4 * beat * SR);
            var d = new float[n];
            int[] roots = { 40, 40, 41, 40, 40, 43, 41, 38, 40, 40, 41, 40, 36, 38, 41, 40 };
            int[] lead = { 76, 77, 76, 74, 72, 74, 76, 79, 77, 76, 74, 71, 72, 74, 76, 76 };
            for (int bar = 0; bar < bars; bar++)
            {
                int root = roots[bar];
                float bt = bar * 4 * beat;
                // хор/пэд: квинта + октава, тёмный
                foreach (int iv in new[] { 12, 19, 24 })
                {
                    Tone(d, bt, 4 * beat, Mtof(root + iv), 0.035f, 1, 0.3f, 0.5f, 700f, 0.005f);
                    Tone(d, bt, 4 * beat, Mtof(root + iv) * 1.008f, 0.025f, 1, 0.35f, 0.5f, 650f, 0.005f);
                }
                // рубленый рифф (палм-мьют) шестнадцатыми: квинта-аккорд
                int[] riff = { 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
                for (int s = 0; s < 16; s++)
                {
                    if (riff[s] == 0) continue;
                    int note = root + (bar % 4 == 3 && s >= 12 ? (s - 11) : 0);
                    Tone(d, bt + s * step, step * 0.55f, Mtof(note), 0.13f, 1, 0.002f, 0.03f, 900f);
                    Tone(d, bt + s * step, step * 0.55f, Mtof(note + 7), 0.08f, 2, 0.002f, 0.03f, 1100f);
                    Tone(d, bt + s * step, step * 0.55f, Mtof(note - 12), 0.1f, 1, 0.002f, 0.03f, 400f);
                }
                // двойная бочка, малый на 2 и 4
                for (int s = 0; s < 16; s++)
                {
                    if (bar >= 4 || s % 2 == 0) Kick(d, bt + s * step, s % 4 == 0 ? 0.8f : 0.55f);
                    if (s == 4 || s == 12) Snare(d, bt + s * step, 0.7f, r);
                    if (s % 2 == 0) Hat(d, bt + s * step, 0.18f, r);
                }
                if (bar % 4 == 3) for (int s = 8; s < 16; s++) Taiko(d, bt + s * step, 0.25f + s * 0.02f, r);
                if (bar % 2 == 0) Taiko(d, bt, 0.55f, r);
                // тремоло-мелодия во второй половине
                if (bar >= 8)
                {
                    int ln = lead[bar];
                    for (int s = 0; s < 16; s++)
                    {
                        int note = s < 8 ? ln : lead[(bar + 1) % lead.Length];
                        Tone(d, bt + s * step, step * 0.8f, Mtof(note), 0.05f, 1, 0.003f, 0.04f, 2600f, 0.004f);
                    }
                }
                else if (bar % 2 == 1)
                {
                    // «медь»: тревожный подъём
                    Tone(d, bt, beat * 2f, Mtof(root + 13), 0.05f, 1, 0.05f, 0.3f, 1400f);
                    Tone(d, bt + beat * 2f, beat * 2f, Mtof(root + 12), 0.05f, 1, 0.05f, 0.3f, 1400f);
                }
            }
            float peak = 0.001f;
            for (int i = 0; i < n; i++) { d[i] = (float)System.Math.Tanh(d[i] * 1.5f); peak = Mathf.Max(peak, Mathf.Abs(d[i])); }
            float g = 0.9f / peak;
            for (int i = 0; i < n; i++) d[i] *= g;
            return d;
        }

        // ================== СИНТЕЗ МУЗЫКИ ==================
        static float Mtof(float m) { return 440f * Mathf.Pow(2f, (m - 69f) / 12f); }

        static void Tone(float[] d, float start, float dur, float freq, float amp, int wave, float attack, float decay, float cutoff, float vib = 0f)
        {
            int s0 = (int)(start * SR), n = (int)((dur + decay) * SR);
            float ph = 0, lp = 0;
            float a = 1f - Mathf.Exp(-2f * Mathf.PI * cutoff / SR);
            for (int i = 0; i < n; i++)
            {
                int k = s0 + i;
                if (k >= d.Length) k -= d.Length; // зацикливание хвостов
                if (k < 0 || k >= d.Length) continue;
                float t = (float)i / SR;
                float f = freq * (1f + vib * Mathf.Sin(t * 5.5f * 6.283f));
                ph += f / SR; ph -= Mathf.Floor(ph);
                float v;
                if (wave == 0) v = Mathf.Sin(ph * 6.283185f);
                else if (wave == 1) v = 2f * ph - 1f;
                else v = ph < 0.5f ? 1f : -1f;
                lp += (v - lp) * a;
                float env = t < attack ? t / attack : (t < dur ? 1f : Mathf.Exp(-(t - dur) * 6f / Mathf.Max(0.01f, decay)));
                d[k] += lp * env * amp;
            }
        }

        static void Kick(float[] d, float start, float amp)
        {
            int s0 = (int)(start * SR), n = (int)(0.35f * SR);
            float ph = 0;
            for (int i = 0; i < n && s0 + i < d.Length; i++)
            {
                float t = (float)i / SR;
                float f = 45f + 110f * Mathf.Exp(-t * 28f);
                ph += f / SR;
                d[s0 + i] += Mathf.Sin(ph * 6.283185f) * Mathf.Exp(-t * 9f) * amp;
            }
        }

        static void Snare(float[] d, float start, float amp, System.Random r)
        {
            int s0 = (int)(start * SR), n = (int)(0.25f * SR);
            float lp = 0;
            for (int i = 0; i < n && s0 + i < d.Length; i++)
            {
                float t = (float)i / SR;
                float nz = (float)r.NextDouble() * 2 - 1;
                lp += (nz - lp) * 0.5f;
                d[s0 + i] += (lp * Mathf.Exp(-t * 16f) * 0.8f + Mathf.Sin(t * 190f * 6.283f) * Mathf.Exp(-t * 30f) * 0.5f) * amp;
            }
        }

        static void Hat(float[] d, float start, float amp, System.Random r)
        {
            int s0 = (int)(start * SR), n = (int)(0.06f * SR);
            float prev = 0;
            for (int i = 0; i < n && s0 + i < d.Length; i++)
            {
                float t = (float)i / SR;
                float nz = (float)r.NextDouble() * 2 - 1;
                d[s0 + i] += (nz - prev) * 0.5f * Mathf.Exp(-t * 70f) * amp;
                prev = nz;
            }
        }

        static void Taiko(float[] d, float start, float amp, System.Random r)
        {
            int s0 = (int)(start * SR), n = (int)(0.8f * SR);
            float ph = 0, lp = 0;
            for (int i = 0; i < n && s0 + i < d.Length; i++)
            {
                float t = (float)i / SR;
                float f = 70f + 40f * Mathf.Exp(-t * 15f);
                ph += f / SR;
                float nz = (float)r.NextDouble() * 2 - 1;
                lp += (nz - lp) * 0.08f;
                d[s0 + i] += (Mathf.Sin(ph * 6.283185f) * 0.9f + lp * 1.5f) * Mathf.Exp(-t * 5f) * amp;
            }
        }

        static float[] Track(bool battle)
        {
            var r = new System.Random(battle ? 7 : 3);
            float bpm = battle ? 150f : 96f;
            float beat = 60f / bpm, step = beat / 4f;
            int bars = 16;
            int n = (int)(bars * 4 * beat * SR);
            var d = new float[n];
            // D-минор, эпичная прогрессия
            int[] roots = battle ? new[] { 50, 50, 46, 48, 50, 50, 46, 45 } : new[] { 50, 46, 41, 48, 50, 46, 43, 45 };
            int[] mel = { 74, 77, 81, 79, 77, 76, 74, 76, 77, 74, 72, 74, 69, 72, 74, 74 };
            for (int bar = 0; bar < bars; bar++)
            {
                int root = roots[bar % 8];
                float bt = bar * 4 * beat;
                bool minorThird = root != 46 && root != 41 && root != 48 && root != 43; // Bb, F, C, G — мажор
                int third = minorThird ? 3 : 4;
                // струнные/пэд
                float padAmp = battle ? 0.05f : 0.06f;
                foreach (int iv in new[] { 0, third, 7, 12 })
                {
                    float f = Mtof(root + iv);
                    Tone(d, bt, 4 * beat, f, padAmp, 1, 0.25f, 0.6f, 900f, 0.004f);
                    Tone(d, bt, 4 * beat, f * 1.006f, padAmp * 0.7f, 1, 0.3f, 0.6f, 800f, 0.004f);
                }
                if (!battle)
                {
                    // меню: медленный бас и редкие удары
                    Tone(d, bt, 2 * beat, Mtof(root - 12), 0.18f, 1, 0.02f, 0.3f, 300f);
                    Tone(d, bt + 2 * beat, 2 * beat, Mtof(root - 12), 0.15f, 1, 0.02f, 0.3f, 300f);
                    Taiko(d, bt, 0.5f, r);
                    if (bar % 2 == 1) Taiko(d, bt + 2.5f * beat, 0.35f, r);
                    Taiko(d, bt + 3 * beat, 0.3f, r);
                    for (int s = 0; s < 8; s++) Hat(d, bt + s * 2 * step, 0.12f, r);
                    if (bar >= 8)
                    {
                        // колокольчики
                        for (int k = 0; k < 4; k++)
                            Tone(d, bt + k * beat, beat * 0.5f, Mtof(mel[(bar * 4 + k) % mel.Length]), 0.05f, 0, 0.005f, 0.8f, 4000f);
                    }
                    continue;
                }
                // бой: остинато баса шестнадцатыми
                int[] bpat = { 0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 0, 12, 0, 12 };
                for (int s = 0; s < 16; s++)
                    Tone(d, bt + s * step, step * 0.8f, Mtof(root - 12 + bpat[s]), 0.16f, 1, 0.003f, 0.05f, 700f);
                // барабаны
                int[] kp = { 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1 };
                for (int s = 0; s < 16; s++)
                {
                    if (kp[s] == 1) Kick(d, bt + s * step, 0.75f);
                    if (s == 4 || s == 12) Snare(d, bt + s * step, 0.55f, r);
                    if (s % 2 == 0) Hat(d, bt + s * step, 0.22f, r);
                }
                if (bar % 4 == 3) for (int s = 12; s < 16; s++) Snare(d, bt + s * step, 0.35f + s * 0.02f, r);
                Taiko(d, bt, 0.45f, r);
                // мелодия во второй половине
                if (bar >= 8)
                {
                    for (int k = 0; k < 4; k++)
                    {
                        int note = mel[((bar - 8) * 2 + k / 2) % mel.Length];
                        if (k % 2 == 1) note += (k == 3 ? -2 : 0);
                        Tone(d, bt + k * beat, beat * 0.9f, Mtof(note), 0.075f, 2, 0.01f, 0.15f, 2500f, 0.006f);
                        Tone(d, bt + k * beat, beat * 0.9f, Mtof(note - 12), 0.05f, 1, 0.01f, 0.15f, 1800f);
                    }
                }
                else
                {
                    // "медь" — акценты power-chord
                    Tone(d, bt, beat * 1.5f, Mtof(root), 0.06f, 1, 0.02f, 0.2f, 1500f);
                    Tone(d, bt, beat * 1.5f, Mtof(root + 7), 0.05f, 1, 0.02f, 0.2f, 1500f);
                }
            }
            // мягкое ограничение и нормализация
            float peak = 0.001f;
            for (int i = 0; i < n; i++) { d[i] = (float)System.Math.Tanh(d[i] * 1.3f); peak = Mathf.Max(peak, Mathf.Abs(d[i])); }
            float g = 0.9f / peak;
            for (int i = 0; i < n; i++) d[i] *= g;
            return d;
        }

        // ================== ЗВУКИ ==================
        delegate float Gen(float t, System.Random r, float[] st);

        void Make(string name, float dur, Gen g)
        {
            int n = (int)(dur * SFX_SR);
            var d = new float[n];
            var r = new System.Random(name.Length * 977 + name[0]);
            var st = new float[8];
            float peak = 0.0001f;
            for (int i = 0; i < n; i++)
            {
                float t = (float)i / SFX_SR;
                d[i] = g(t, r, st);
                peak = Mathf.Max(peak, Mathf.Abs(d[i]));
            }
            float k = 0.9f / peak;
            for (int i = 0; i < n; i++) d[i] *= k;
            // убираем щелчок в конце
            int fade = Mathf.Min(n, 200);
            for (int i = 0; i < fade; i++) d[n - 1 - i] *= i / (float)fade;
            var c = AudioClip.Create(name, n, 1, SFX_SR, false);
            c.SetData(d, 0);
            clips[name] = c;
        }

        static float N(System.Random r) { return (float)r.NextDouble() * 2f - 1f; }
        static float S(float ph) { return Mathf.Sin(ph * 6.283185f); }

        void BuildSfx()
        {
            Make("punch", 0.2f, (t, r, s) => { s[0] += (50f + 120f * Mathf.Exp(-t * 25f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.3f; return S(s[0]) * Mathf.Exp(-t * 22f) + s[1] * Mathf.Exp(-t * 50f) * 0.8f; });
            Make("kick", 0.28f, (t, r, s) => { s[0] += (40f + 90f * Mathf.Exp(-t * 18f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.25f; return S(s[0]) * Mathf.Exp(-t * 14f) + s[1] * Mathf.Exp(-t * 35f); });
            Make("slash", 0.28f, (t, r, s) => { float c = Mathf.Lerp(0.05f, 0.6f, Mathf.Sin(Mathf.Clamp01(t / 0.28f) * Mathf.PI)); s[1] += (N(r) - s[1]) * c; s[2] += (s[1] - s[2]) * 0.1f; return (s[1] - s[2]) * Mathf.Sin(Mathf.Clamp01(t / 0.28f) * Mathf.PI); });
            Make("cut", 0.25f, (t, r, s) => { s[1] += (N(r) - s[1]) * 0.5f; s[0] += 70f / SFX_SR; return s[1] * Mathf.Exp(-t * 18f) * 0.8f + S(s[0]) * Mathf.Exp(-t * 20f) * 0.6f; });
            Make("shot", 0.45f, (t, r, s) => { s[1] += (N(r) - s[1]) * Mathf.Lerp(0.9f, 0.1f, t * 3f); s[0] += 60f / SFX_SR; return s[1] * Mathf.Exp(-t * 14f) + S(s[0]) * Mathf.Exp(-t * 12f) * 0.7f; });
            Make("bow", 0.35f, (t, r, s) => { s[0] += 180f / SFX_SR; s[1] += 362f / SFX_SR; return (S(s[0]) + S(s[1]) * 0.4f) * Mathf.Exp(-t * 14f) + N(r) * Mathf.Exp(-t * 60f) * 0.3f; });
            Make("whoosh", 0.3f, (t, r, s) => { float e = Mathf.Sin(Mathf.Clamp01(t / 0.3f) * Mathf.PI); s[1] += (N(r) - s[1]) * (0.05f + 0.25f * e); return s[1] * e; });
            Make("explosion", 1.3f, (t, r, s) => { s[1] += (N(r) - s[1]) * Mathf.Lerp(0.6f, 0.03f, Mathf.Clamp01(t * 1.5f)); s[0] += (30f + 40f * Mathf.Exp(-t * 6f)) / SFX_SR; return s[1] * Mathf.Exp(-t * 3.5f) * 1.4f + S(s[0]) * Mathf.Exp(-t * 4f); });
            Make("zap", 0.5f, (t, r, s) => { if (r.NextDouble() < 0.004) s[2] = 200f + (float)r.NextDouble() * 1800f; s[0] += (s[2] + 300f) / SFX_SR; float sq = s[0] % 1f < 0.5f ? 1 : -1; return (sq * 0.5f + N(r) * 0.6f) * Mathf.Exp(-t * 5f); });
            Make("splat", 0.35f, (t, r, s) => { s[1] += (N(r) - s[1]) * 0.15f; s[0] += (300f + 200f * Mathf.Sin(t * 70f)) / SFX_SR; return s[1] * Mathf.Exp(-t * 12f) * 1.3f + S(s[0]) * Mathf.Exp(-t * 25f) * 0.3f; });
            Make("clang", 0.7f, (t, r, s) => { float e = Mathf.Exp(-t * 7f); return (Mathf.Sin(t * 820f * 6.283f) + Mathf.Sin(t * 1290f * 6.283f) * 0.7f + Mathf.Sin(t * 1960f * 6.283f) * 0.5f + Mathf.Sin(t * 2710f * 6.283f) * 0.3f) * e + N(r) * Mathf.Exp(-t * 80f); });
            Make("thud", 0.4f, (t, r, s) => { s[0] += (40f + 50f * Mathf.Exp(-t * 10f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.08f; return S(s[0]) * Mathf.Exp(-t * 9f) + s[1] * Mathf.Exp(-t * 12f) * 2f; });
            Make("pickup", 0.35f, (t, r, s) => { float f = t < 0.1f ? 660f : t < 0.2f ? 880f : 1320f; s[0] += f / SFX_SR; return (s[0] % 1f < 0.5f ? 0.5f : -0.5f) * Mathf.Exp(-(t % 0.1f) * 10f); });
            Make("fire", 0.6f, (t, r, s) => { s[1] += (N(r) - s[1]) * 0.12f; float crack = r.NextDouble() < 0.01 ? N(r) * 2f : 0f; return (s[1] * 1.5f + crack) * Mathf.Sin(Mathf.Clamp01(t / 0.6f) * Mathf.PI); });
            Make("ice", 0.5f, (t, r, s) => { return (Mathf.Sin(t * 2100f * 6.283f) + Mathf.Sin(t * 3170f * 6.283f) * 0.6f + Mathf.Sin(t * 4400f * 6.283f) * 0.4f) * Mathf.Exp(-t * 8f) + N(r) * Mathf.Exp(-t * 30f) * 0.4f; });
            Make("teleport", 0.4f, (t, r, s) => { s[0] += (300f + 2400f * t) / SFX_SR; return S(s[0]) * Mathf.Sin(Mathf.Clamp01(t / 0.4f) * Mathf.PI) * (0.7f + 0.3f * Mathf.Sin(t * 120f)); });
            Make("laser", 0.25f, (t, r, s) => { s[0] += (900f + 120f * Mathf.Sin(t * 90f)) / SFX_SR; return (2f * (s[0] % 1f) - 1f) * 0.6f + S(s[0] * 0.5f) * 0.4f; });
            Make("saw", 0.2f, (t, r, s) => { s[0] += (95f + 10f * Mathf.Sin(t * 60f)) / SFX_SR; return (2f * (s[0] % 1f) - 1f) * 0.7f + N(r) * 0.4f; });
            Make("gong", 2.5f, (t, r, s) => { s[0] += (55f + 30f * Mathf.Exp(-t * 8f)) / SFX_SR; float e = Mathf.Exp(-t * 1.6f); return S(s[0]) * Mathf.Exp(-t * 3f) * 1.2f + (Mathf.Sin(t * 440f * 6.283f) + Mathf.Sin(t * 659f * 6.283f) * 0.6f + Mathf.Sin(t * 1047f * 6.283f) * 0.3f) * e * 0.4f + N(r) * Mathf.Exp(-t * 20f) * 0.6f; });
            Make("heal", 0.5f, (t, r, s) => { s[0] += (500f + 600f * t) / SFX_SR; return S(s[0]) * Mathf.Sin(Mathf.Clamp01(t / 0.5f) * Mathf.PI) * 0.6f; });
            // --- новые, более «киношные» звуки ---
            // тяжёлый удар: низкий бум + хруст
            Make("heavy", 0.55f, (t, r, s) => { s[0] += (38f + 120f * Mathf.Exp(-t * 14f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.35f; float crunch = r.NextDouble() < 0.03 * Mathf.Exp(-t * 10f) ? N(r) * 3f : 0f; return S(s[0]) * Mathf.Exp(-t * 6f) * 1.3f + s[1] * Mathf.Exp(-t * 22f) * 0.9f + crunch; });
            // хлёсткий удар рукой: щелчок + шлепок + шорох
            Make("snap", 0.18f, (t, r, s) => { s[0] += (90f + 260f * Mathf.Exp(-t * 60f)) / SFX_SR; return S(s[0]) * Mathf.Exp(-t * 30f) + N(r) * Mathf.Exp(-t * 90f) * 1.2f; });
            // металлический свист меча
            Make("shing", 0.6f, (t, r, s) => { float e = Mathf.Exp(-t * 6f); s[1] += (N(r) - s[1]) * 0.6f; return (Mathf.Sin(t * 3150f * 6.283f) * 0.5f + Mathf.Sin(t * 4720f * 6.283f) * 0.35f + Mathf.Sin(t * 6230f * 6.283f) * 0.2f) * e * (1f + 0.3f * Mathf.Sin(t * 40f)) + s[1] * Mathf.Exp(-t * 25f) * 0.5f; });
            // взмах оружием: тяжёлый свист
            Make("swing", 0.35f, (t, r, s) => { float e = Mathf.Sin(Mathf.Clamp01(t / 0.35f) * Mathf.PI); float c = 0.03f + 0.18f * e * e; s[1] += (N(r) - s[1]) * c; s[2] += (s[1] - s[2]) * 0.05f; return (s[1] - s[2]) * e * 2.2f; });
            // разрез плоти
            Make("slice", 0.32f, (t, r, s) => { s[1] += (N(r) - s[1]) * 0.7f; s[0] += (200f - 120f * t) / SFX_SR; return s[1] * Mathf.Exp(-t * 14f) * 0.8f + S(s[0]) * Mathf.Exp(-t * 18f) * 0.4f + (r.NextDouble() < 0.02 ? N(r) : 0f) * Mathf.Exp(-t * 8f); });
            // хруст костей
            Make("crunch", 0.4f, (t, r, s) => { bool click = r.NextDouble() < 0.06 * Mathf.Exp(-t * 6f); s[1] += ((click ? N(r) * 4f : 0f) - s[1]) * 0.5f; s[2] += (N(r) - s[2]) * 0.1f; return s[1] + s[2] * Mathf.Exp(-t * 10f) * 0.8f; });
            // падение тела
            Make("bodyfall", 0.6f, (t, r, s) => { s[0] += (48f + 30f * Mathf.Exp(-t * 8f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.06f; float second = t > 0.16f ? Mathf.Exp(-(t - 0.16f) * 14f) * 0.6f : 0f; return S(s[0]) * (Mathf.Exp(-t * 12f) + second) + s[1] * Mathf.Exp(-t * 7f) * 2.2f; });
            // блок: глухой удар с лязгом
            Make("block", 0.3f, (t, r, s) => { s[0] += 140f / SFX_SR; return S(s[0]) * Mathf.Exp(-t * 20f) + (Mathf.Sin(t * 1600f * 6.283f) + Mathf.Sin(t * 2400f * 6.283f) * 0.5f) * Mathf.Exp(-t * 16f) * 0.4f + N(r) * Mathf.Exp(-t * 70f) * 0.6f; });
            // прыжок, приземление, шаг
            Make("jump", 0.22f, (t, r, s) => { float e = Mathf.Sin(Mathf.Clamp01(t / 0.22f) * Mathf.PI); s[1] += (N(r) - s[1]) * (0.04f + 0.15f * e); return s[1] * e * 1.5f; });
            Make("land", 0.25f, (t, r, s) => { s[0] += (50f + 40f * Mathf.Exp(-t * 20f)) / SFX_SR; s[1] += (N(r) - s[1]) * 0.12f; return S(s[0]) * Mathf.Exp(-t * 16f) + s[1] * Mathf.Exp(-t * 18f) * 1.5f; });
            Make("step", 0.1f, (t, r, s) => { s[1] += (N(r) - s[1]) * 0.2f; return s[1] * Mathf.Exp(-t * 45f); });
            // зарядка энергии
            Make("charge", 0.7f, (t, r, s) => { s[0] += (180f + 900f * t * t) / SFX_SR; s[1] += (190f + 905f * t * t) / SFX_SR; float e = Mathf.Clamp01(t / 0.6f); return (S(s[0]) + S(s[1])) * 0.5f * e * (0.6f + 0.4f * Mathf.Sin(t * 50f)); });
            // кинематографичный «вжух» для 3D-перехода
            Make("cine", 1.2f, (t, r, s) => { float e = Mathf.Sin(Mathf.Clamp01(t / 1.2f) * Mathf.PI); s[1] += (N(r) - s[1]) * (0.02f + 0.1f * e); s[0] += (60f + 40f * t) / SFX_SR; return s[1] * e * 2f + S(s[0]) * e * 0.4f; });
            Make("click", 0.06f, (t, r, s) => { s[0] += 1200f / SFX_SR; return S(s[0]) * Mathf.Exp(-t * 60f); });
        }
    }
}
