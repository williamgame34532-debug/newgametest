using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace StickWars
{
    // Запись в видеофайл .avi (MJPEG + звук PCM) — открывается в VLC, Windows «Кино и ТВ», монтажных программах.
    public class AviWriter
    {
        FileStream fs;
        BinaryWriter w;
        long riffSizePos, avihFramesPos, vidLenPos, audLenPos, moviSizePos, moviStart;
        struct Idx { public uint id, flags, off, size; }
        readonly List<Idx> idx = new List<Idx>();
        public int frames;
        long audioFrames;

        static uint FCC(string s) { return (uint)(s[0] | (s[1] << 8) | (s[2] << 16) | (s[3] << 24)); }

        void Patch(long sizePos)
        {
            long end = fs.Position;
            fs.Position = sizePos;
            w.Write((uint)(end - sizePos - 4));
            fs.Position = end;
        }

        public void Begin(string path, int wd, int ht, int fps, int sr)
        {
            fs = new FileStream(path, FileMode.Create, FileAccess.ReadWrite);
            w = new BinaryWriter(fs);
            w.Write(FCC("RIFF")); riffSizePos = fs.Position; w.Write(0u); w.Write(FCC("AVI "));
            w.Write(FCC("LIST")); long hdrl = fs.Position; w.Write(0u); w.Write(FCC("hdrl"));
            w.Write(FCC("avih")); w.Write(56u);
            w.Write((uint)(1000000 / fps)); w.Write(0u); w.Write(0u); w.Write(0x10u);
            avihFramesPos = fs.Position; w.Write(0u); w.Write(0u); w.Write(2u); w.Write(1024u * 1024u);
            w.Write((uint)wd); w.Write((uint)ht); w.Write(0u); w.Write(0u); w.Write(0u); w.Write(0u);

            // видеопоток
            w.Write(FCC("LIST")); long s1 = fs.Position; w.Write(0u); w.Write(FCC("strl"));
            w.Write(FCC("strh")); w.Write(56u);
            w.Write(FCC("vids")); w.Write(FCC("MJPG")); w.Write(0u); w.Write((ushort)0); w.Write((ushort)0); w.Write(0u);
            w.Write(1u); w.Write((uint)fps); w.Write(0u); vidLenPos = fs.Position; w.Write(0u);
            w.Write(1024u * 1024u); w.Write(0xFFFFFFFFu); w.Write(0u);
            w.Write((short)0); w.Write((short)0); w.Write((short)wd); w.Write((short)ht);
            w.Write(FCC("strf")); w.Write(40u);
            w.Write(40u); w.Write(wd); w.Write(ht); w.Write((ushort)1); w.Write((ushort)24); w.Write(FCC("MJPG"));
            w.Write((uint)(wd * ht * 3)); w.Write(0); w.Write(0); w.Write(0u); w.Write(0u);
            Patch(s1);

            // аудиопоток
            w.Write(FCC("LIST")); long s2 = fs.Position; w.Write(0u); w.Write(FCC("strl"));
            w.Write(FCC("strh")); w.Write(56u);
            w.Write(FCC("auds")); w.Write(0u); w.Write(0u); w.Write((ushort)0); w.Write((ushort)0); w.Write(0u);
            w.Write(1u); w.Write((uint)sr); w.Write(0u); audLenPos = fs.Position; w.Write(0u);
            w.Write((uint)(sr * 4)); w.Write(0xFFFFFFFFu); w.Write(4u);
            w.Write((short)0); w.Write((short)0); w.Write((short)0); w.Write((short)0);
            w.Write(FCC("strf")); w.Write(18u);
            w.Write((ushort)1); w.Write((ushort)2); w.Write((uint)sr); w.Write((uint)(sr * 4)); w.Write((ushort)4); w.Write((ushort)16); w.Write((ushort)0);
            Patch(s2);
            Patch(hdrl);

            w.Write(FCC("LIST")); moviSizePos = fs.Position; w.Write(0u); moviStart = fs.Position; w.Write(FCC("movi"));
        }

        void Chunk(string id, byte[] data, int len)
        {
            long pos = fs.Position;
            w.Write(FCC(id)); w.Write((uint)len); w.Write(data, 0, len);
            if ((len & 1) == 1) w.Write((byte)0);
            idx.Add(new Idx { id = FCC(id), flags = 0x10u, off = (uint)(pos - moviStart), size = (uint)len });
        }

        public void AddVideo(byte[] jpg) { Chunk("00dc", jpg, jpg.Length); frames++; }
        public void AddAudio(byte[] pcm, int len) { Chunk("01wb", pcm, len); audioFrames += len / 4; }

        public void End()
        {
            Patch(moviSizePos);
            w.Write(FCC("idx1")); w.Write((uint)(idx.Count * 16));
            foreach (var e in idx) { w.Write(e.id); w.Write(e.flags); w.Write(e.off); w.Write(e.size); }
            Patch(riffSizePos);
            fs.Position = avihFramesPos; w.Write((uint)frames);
            fs.Position = vidLenPos; w.Write((uint)frames);
            fs.Position = audLenPos; w.Write((uint)audioFrames);
            w.Flush();
            fs.Close();
        }
    }

    public class VideoRecorder : MonoBehaviour
    {
        public static VideoRecorder I;
        public bool Active;
        public string status = "", lastPath = "", lastDir = "";
        bool fixedStep;
        float clockT;
        AviWriter avi;
        RenderTexture rt;
        Texture2D tex;
        int W, H;
        const int FPS = 30, SR = 44100;
        struct Ev { public float t; public string name; public float vol; }
        readonly List<Ev> sfx = new List<Ev>();
        AudioClip musicClip;
        float musicStart;
        bool musicOn;
        float musicVol, sfxVol;
        readonly Dictionary<string, float[]> cache = new Dictionary<string, float[]>();

        void Awake() { I = this; }

        public float VideoTime { get { return fixedStep ? (avi != null ? avi.frames / (float)FPS : 0f) : clockT; } }

        // fixed = кадр за кадром (фильм битвы, ровно 30 к/с); иначе — запись живого боя в реальном времени
        public void Begin(bool fixedFrames, string prefix)
        {
            if (Active) End();
            fixedStep = fixedFrames;
            lastDir = Path.Combine(Application.persistentDataPath, "Duels");
            try { Directory.CreateDirectory(lastDir); } catch (System.Exception e) { status = "Ошибка папки: " + e.Message; return; }
            lastPath = Path.Combine(lastDir, prefix + "_" + System.DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + ".avi");
            H = Mathf.Min(720, Screen.height);
            W = Mathf.RoundToInt(H * (float)Screen.width / Screen.height / 2f) * 2;
            H = H / 2 * 2;
            rt = new RenderTexture(W, H, 0, RenderTextureFormat.ARGB32);
            tex = new Texture2D(W, H, TextureFormat.RGB24, false);
            avi = new AviWriter();
            try { avi.Begin(lastPath, W, H, FPS, SR); }
            catch (System.Exception e) { status = "Не удалось создать файл: " + e.Message; avi = null; return; }
            sfx.Clear();
            clockT = 0f;
            var au = Game.I != null ? Game.I.audio : null;
            musicClip = au != null ? au.MusicClip : null;
            musicStart = au != null ? au.MusicTime : 0f;
            musicOn = Game.I == null || Game.I.S.musicOn;
            musicVol = Game.I != null ? Game.I.S.musicVol : 0.6f;
            sfxVol = Game.I != null ? Game.I.S.sfxVol : 0.8f;
            Active = true;
            status = "● Идёт запись видео...";
            StartCoroutine(Loop());
        }

        public void Sfx(string name, float vol)
        {
            if (!Active) return;
            sfx.Add(new Ev { t = VideoTime, name = name, vol = vol });
        }

        IEnumerator Loop()
        {
            var eof = new WaitForEndOfFrame();
            while (Active)
            {
                yield return eof;
                if (!Active) break;
                Capture();
            }
        }

        void Capture()
        {
            if (avi == null) return;
            Texture2D full = null;
            try
            {
                full = ScreenCapture.CaptureScreenshotAsTexture();
                Graphics.Blit(full, rt);
                var prev = RenderTexture.active;
                RenderTexture.active = rt;
                tex.ReadPixels(new Rect(0, 0, W, H), 0, 0);
                tex.Apply(false);
                RenderTexture.active = prev;
                byte[] jpg = tex.EncodeToJPG(82);
                if (fixedStep) avi.AddVideo(jpg);
                else
                {
                    clockT += Time.unscaledDeltaTime;
                    int need = Mathf.FloorToInt(clockT * FPS);
                    int n = 0;
                    while (avi.frames < need && n < 6) { avi.AddVideo(jpg); n++; }
                    if (avi.frames < need) clockT = avi.frames / (float)FPS; // слишком долго — не догоняем бесконечно
                }
            }
            catch (System.Exception e) { status = "Ошибка записи: " + e.Message; }
            finally { if (full != null) Destroy(full); }
        }

        float[] Data(AudioClip c)
        {
            if (c == null) return null;
            float[] d;
            if (cache.TryGetValue(c.name + c.GetInstanceID(), out d)) return d;
            d = new float[c.samples * c.channels];
            try { if (!c.GetData(d, 0)) d = null; } catch { d = null; }
            cache[c.name + c.GetInstanceID()] = d;
            return d;
        }

        public void End()
        {
            if (!Active) return;
            Active = false;
            StopAllCoroutines();
            try
            {
                int frames = avi.frames;
                int total = Mathf.Max(1, Mathf.CeilToInt(frames / (float)FPS * SR));
                var L = new float[total];
                var R = new float[total];
                // музыка
                var md = musicOn ? Data(musicClip) : null;
                if (md != null && musicClip.samples > 0)
                {
                    int ch = musicClip.channels;
                    double ratio = musicClip.frequency / (double)SR;
                    double pos = musicStart * musicClip.frequency;
                    float mv = musicVol * 0.7f;
                    for (int i = 0; i < total; i++)
                    {
                        int s = (int)((pos + i * ratio) % musicClip.samples);
                        float l = md[s * ch], r = ch > 1 ? md[s * ch + 1] : l;
                        L[i] += l * mv; R[i] += r * mv;
                    }
                }
                // звуки боя — ровно в те моменты, когда они звучали в кадре
                var au = Game.I != null ? Game.I.audio : null;
                foreach (var e in sfx)
                {
                    var clip = au != null ? au.Clip(e.name) : null;
                    var d = Data(clip);
                    if (d == null) continue;
                    double ratio = clip.frequency / (double)SR;
                    int start = (int)(e.t * SR);
                    int len = (int)(clip.samples / ratio);
                    float v = e.vol * sfxVol * 0.8f;
                    for (int i = 0; i < len && start + i < total; i++)
                    {
                        if (start + i < 0) continue;
                        float x = d[(int)(i * ratio) * clip.channels] * v;
                        L[start + i] += x; R[start + i] += x;
                    }
                }
                var buf = new byte[SR * 4];
                int k = 0;
                for (int i = 0; i < total; i++)
                {
                    short l = (short)(Mathf.Clamp((float)System.Math.Tanh(L[i] * 1.1f), -1f, 1f) * 32000f);
                    short r = (short)(Mathf.Clamp((float)System.Math.Tanh(R[i] * 1.1f), -1f, 1f) * 32000f);
                    buf[k++] = (byte)l; buf[k++] = (byte)(l >> 8); buf[k++] = (byte)r; buf[k++] = (byte)(r >> 8);
                    if (k >= buf.Length) { avi.AddAudio(buf, k); k = 0; }
                }
                if (k > 0) avi.AddAudio(buf, k);
                avi.End();
                status = "Видео сохранено (" + (frames / FPS) + " сек): " + lastPath;
            }
            catch (System.Exception e) { status = "Ошибка сохранения видео: " + e.Message; }
            if (rt != null) { rt.Release(); Destroy(rt); rt = null; }
            if (tex != null) { Destroy(tex); tex = null; }
            avi = null;
            sfx.Clear();
        }

        public void OpenFolder()
        {
            if (string.IsNullOrEmpty(lastDir)) return;
            Application.OpenURL("file:///" + lastDir.Replace('\\', '/'));
        }

        void OnApplicationQuit() { End(); }
    }
}
