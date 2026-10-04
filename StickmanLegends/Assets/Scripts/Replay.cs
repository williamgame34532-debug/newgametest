using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Запись дуэли, «фильм битвы» с режиссурой (ускорения, замедления, смена рисовки) и смена стиля в живом бою.
    public partial class Battle
    {
        // ===================== ДАННЫЕ ЗАПИСИ =====================
        public class FSnap
        {
            public Fighter f;
            public Vector2[] P = new Vector2[11];
            public int rf;
            public float alpha, hp;
            public WeaponStats w;
        }

        public class PSnap { public Vector2 pos; public float ang; public Color c; public int kind; }

        public class RecFrame
        {
            public float t;
            public Vector3 cam;
            public float size, rot;
            public readonly List<FSnap> f = new List<FSnap>();
            public readonly List<PSnap> p = new List<PSnap>();
        }

        public class RecEv
        {
            public float t;
            public int type;
            public Vector2 a, b;
            public float x;
            public Color c;
            public string s;
        }

        readonly List<RecFrame> recFrames = new List<RecFrame>();
        readonly List<RecEv> recEvs = new List<RecEv>();
        readonly List<Fighter> removedFighters = new List<Fighter>();
        bool recording;
        float recT, recAcc;
        public bool HasRecording { get { return recFrames.Count > 10; } }
        public float RecLength { get { return recFrames.Count > 0 ? recFrames[recFrames.Count - 1].t : 0f; } }

        void StartRecording()
        {
            recFrames.Clear(); recEvs.Clear();
            recT = 0; recAcc = 1f;
            recording = true;
            fx.Rec = (type, a, b, x, c) => RecEvent(type + 100, a, b, x, c, null);
            audio.OnSfx = (n, v) => RecEvent(4, Vector2.zero, Vector2.zero, v, Color.white, n);
        }

        void StopRecording()
        {
            recording = false;
            if (fx != null) fx.Rec = null;
            if (audio != null) audio.OnSfx = null;
        }

        void RecEvent(int type, Vector2 a, Vector2 b, float x, Color c, string s)
        {
            if (!recording) return;
            recEvs.Add(new RecEv { t = recT, type = type, a = a, b = b, x = x, c = c, s = s });
        }

        void RecordFrame(float raw)
        {
            if (!recording) return;
            if (phase == Phase.Victory && phaseT > 2.6f) { StopRecording(); return; }
            recT += raw;
            recAcc += raw;
            if (recAcc < 1f / 30f) return;
            recAcc = 0;
            var fr = new RecFrame { t = recT, cam = cam.cam.transform.position, size = cam.cam.orthographicSize, rot = cam.cam.transform.eulerAngles.z };
            foreach (var f in fighters)
            {
                var sn = new FSnap { f = f, rf = f.lastRF, alpha = f.lastAlpha, hp = f.hp, w = f.weapon };
                var P = f.dead && f.rag != null ? f.rag.p : f.J;
                System.Array.Copy(P, sn.P, 11);
                fr.f.Add(sn);
            }
            foreach (var p in projs)
            {
                if (p == null) continue;
                fr.p.Add(new PSnap { pos = p.pos, ang = Mathf.Atan2(p.vel.y, p.vel.x), c = p.Col, kind = (int)p.kind });
            }
            recFrames.Add(fr);
        }

        // ===================== СТИЛИ РИСОВКИ =====================
        // 0 — стиль арены, 1 — чернила (чёрные силуэты на светлом), 2 — негатив, 3 — красный кадр удара, 4 — плоская дуэль (красный/синий на тёмном)
        public static readonly string[] StyleNames = { "Арена", "Чернила", "Негатив", "Кадр удара", "Дуэль" };
        public int curStyle, baseStyle;
        float impactT;
        int styleStep, tempoAnn;
        Transform styleGround;
        SpriteRenderer sgFill;
        LineRenderer sgLine;

        public float Tempo
        {
            get
            {
                if (mode != Mode.Fight || phase != Phase.Fight || Game.I == null || !Game.I.S.tempoRamp) return 1f;
                return 1f + Mathf.Clamp01(fightTime / 90f) * 0.45f;
            }
        }

        void EnsureStyleGround()
        {
            if (styleGround != null) return;
            styleGround = new GameObject("StyleGround").transform;
            styleGround.SetParent(transform, false);
            sgFill = Draw.Rect(styleGround, new Rect(-80, -30, 160, 30), Color.gray, -10);
            sgLine = Draw.Line(styleGround, "line", 0.1f, Color.black, -3, true, 0);
            Draw.Set(sgLine, new Vector2(-80, -0.03f), new Vector2(80, -0.03f));
            styleGround.gameObject.SetActive(false);
        }

        public void ApplyStyle(int st)
        {
            EnsureStyleGround();
            curStyle = st;
            bool themeOn = st == 0;
            theme.gameObject.SetActive(themeOn);
            styleGround.gameObject.SetActive(!themeOn);
            Color bg = theme.bg, fill = Color.gray, line = Color.black;
            switch (st)
            {
                case 1: bg = new Color(0.93f, 0.92f, 0.89f); fill = new Color(0.85f, 0.84f, 0.8f); line = new Color(0.05f, 0.05f, 0.05f); break;
                case 2: bg = new Color(0.02f, 0.02f, 0.03f); fill = new Color(0.07f, 0.07f, 0.08f); line = new Color(0.95f, 0.95f, 0.95f); break;
                case 3: bg = new Color(0.78f, 0.04f, 0.04f); fill = new Color(0.5f, 0.02f, 0.02f); line = new Color(0.02f, 0.02f, 0.02f); break;
                case 4: bg = new Color(0.17f, 0.17f, 0.18f); fill = new Color(0.12f, 0.12f, 0.13f); line = new Color(0.85f, 0.85f, 0.85f); break;
            }
            cam.cam.backgroundColor = bg;
            sgFill.color = fill; Draw.Col(sgLine, line);
            foreach (var f in fighters) f.SetStyle(st);
            foreach (var f in removedFighters) if (f != null) f.SetStyle(st);
        }

        void ResetStyle()
        {
            impactT = 0; styleStep = 0; baseStyle = 0; tempoAnn = 0;
            if (theme != null && cam != null && curStyle != 0) ApplyStyle(0);
        }

        // кадр удара: на долю секунды всё становится силуэтами на красном
        public void ImpactFrame()
        {
            if (Game.I != null && !Game.I.S.styleShift) return;
            ApplyStyle(3);
            impactT = 0.13f;
        }

        void StyleTick(float raw)
        {
            if (impactT > 0f)
            {
                impactT -= raw;
                if (impactT <= 0f) ApplyStyle(baseStyle);
            }
            if (mode != Mode.Fight || phase != Phase.Fight || Game.I == null || !Game.I.S.styleShift) return;
            // рисовка меняется по ходу дуэли, как в анимациях
            int[] seq = { 4, 1, 0, 4, 2, 0 };
            float[] at = { 22f, 45f, 65f, 85f, 105f, 125f };
            if (styleStep < at.Length && fightTime >= at[styleStep])
            {
                baseStyle = seq[styleStep];
                styleStep++;
                Flash(0.1f, new Color(1, 1, 1, 0.8f));
                ApplyStyle(baseStyle);
                Popup("— " + StyleNames[baseStyle].ToUpper() + " —", new Vector2(cam.cam.transform.position.x, cam.cam.transform.position.y + cam.cam.orthographicSize * 0.55f), new Color(1f, 0.9f, 0.6f), 0.8f);
            }
            if (Game.I.S.tempoRamp && tempoAnn < 2 && fightTime >= 30f * (tempoAnn + 1))
            {
                tempoAnn++;
                Announce("ТЕМП РАСТЁТ!", new Color(1f, 0.6f, 0.2f), 1.1f);
            }
        }

        // ===================== ПОВТОР =====================
        public float replayT, replaySpeed = 1f;
        public bool replayDone, capturing;
        int capFrame;
        string capDir;
        float replayStyleT;
        int evCursor, replayStyleIdx;
        readonly List<LineRenderer> ghostPool = new List<LineRenderer>();
        public string capStatus = "";

        public void StartReplay()
        {
            if (!HasRecording) return;
            StopRecording();
            mode = Mode.Replay;
            paused = false;
            replayT = 0; replaySpeed = 1f; replayDone = false; evCursor = 0;
            replayStyleT = 0; replayStyleIdx = 0;
            foreach (var p in projs) if (p != null) Destroy(p.gameObject);
            projs.Clear();
            foreach (var p in pickups) if (p != null) p.gameObject.SetActive(false);
            foreach (var t in timed) if (t.go != null) Destroy(t.go);
            timed.Clear();
            popups.Clear();
            announce = ""; announceT = 0;
            fx.Clear(true);
            foreach (var f in fighters) f.replaying = true;
            foreach (var f in removedFighters) if (f != null) f.replaying = true;
            ApplyStyle(0);
            Announce("ФИЛЬМ БИТВЫ", new Color(1f, 0.9f, 0.6f), 1.6f);
        }

        public void StopReplay()
        {
            StopCapture();
            mode = Mode.Fight;
            foreach (var g in ghostPool) g.enabled = false;
            foreach (var p in pickups) if (p != null) p.gameObject.SetActive(true);
            foreach (var f in fighters) { f.replaying = false; f.gameObject.SetActive(true); }
            foreach (var f in removedFighters) if (f != null) { f.replaying = false; f.gameObject.SetActive(false); }
            ApplyStyle(0);
            announce = ""; announceT = 0;
            phase = Phase.Victory; phaseT = 5f;
        }

        public void StartCapture()
        {
            capDir = System.IO.Path.Combine(Application.persistentDataPath, "Duels", System.DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss"));
            try { System.IO.Directory.CreateDirectory(capDir); } catch (System.Exception e) { capStatus = "Ошибка: " + e.Message; return; }
            capturing = true; capFrame = 0;
            StartReplay();
            capStatus = "Запись кадров в: " + capDir;
        }

        void StopCapture()
        {
            if (!capturing) return;
            capturing = false;
            capStatus = "Сохранено " + capFrame + " кадров (30 fps) в " + capDir + ". Склеить в видео: ffmpeg -framerate 30 -i frame_%05d.png duel.mp4";
        }

        float NextEventGap(float t)
        {
            for (int i = evCursor; i < recEvs.Count; i++)
            {
                var e = recEvs[i];
                if (e.type == 0 || e.type == 16 || e.type == 101) return e.t - t;
            }
            return 99f;
        }

        float NearPower(float t)
        {
            float p = 0;
            for (int i = Mathf.Max(0, evCursor - 20); i < recEvs.Count; i++)
            {
                var e = recEvs[i];
                if (e.t > t + 0.35f) break;
                if (e.t < t - 0.15f) continue;
                if (e.type == 16) p = Mathf.Max(p, 3f);
                if (e.type == 0) p = Mathf.Max(p, e.x);
            }
            return p;
        }

        void ReplayUpdate(float raw)
        {
            float step = paused ? 0f : raw;
            if (capturing) step = 1f / 30f; // при записи кадров — ровно 30 кадров в секунду
            // режиссура: спокойные моменты быстрее, удары медленнее
            float pw = NearPower(replayT);
            float gap = NextEventGap(replayT);
            float want = pw >= 2.5f ? 0.25f : pw >= 1.3f ? 0.45f : pw > 0f ? 0.8f : gap > 1.2f ? 1.9f : 1.15f;
            replaySpeed = Mathf.MoveTowards(replaySpeed, want, raw * (want < replaySpeed ? 12f : 3f));
            float dt = step * replaySpeed;
            if (!replayDone) replayT += dt;
            if (replayT >= RecLength) { replayT = RecLength; if (!replayDone) { replayDone = true; StopCapture(); Announce("КОНЕЦ", Color.white, 99f); } }

            // события
            while (evCursor < recEvs.Count && recEvs[evCursor].t <= replayT)
            {
                PlayEvent(recEvs[evCursor]);
                evCursor++;
            }

            // смена рисовки по ходу фильма
            replayStyleT += dt;
            if (impactT > 0f) { impactT -= raw; if (impactT <= 0f) ApplyStyle(baseStyle); }
            else if (replayStyleT > 6.5f && pw < 1f)
            {
                replayStyleT = 0;
                int[] seq = { 4, 1, 0, 2, 4, 0 };
                baseStyle = seq[replayStyleIdx % seq.Length];
                replayStyleIdx++;
                Flash(0.08f, new Color(1, 1, 1, 0.7f));
                ApplyStyle(baseStyle);
            }

            // кадр
            int i0 = 0;
            int lo = 0, hi = recFrames.Count - 1;
            while (lo < hi) { int mid = (lo + hi + 1) / 2; if (recFrames[mid].t <= replayT) lo = mid; else hi = mid - 1; }
            i0 = lo;
            int i1 = Mathf.Min(i0 + 1, recFrames.Count - 1);
            var A = recFrames[i0]; var B = recFrames[i1];
            float k = B.t > A.t ? Mathf.Clamp01((replayT - A.t) / (B.t - A.t)) : 0f;

            var present = new HashSet<Fighter>();
            foreach (var sa in A.f)
            {
                if (sa.f == null) continue;
                FSnap sb = null;
                foreach (var x in B.f) if (x.f == sa.f) { sb = x; break; }
                present.Add(sa.f);
                sa.f.ShowSnap(sa, sb, k);
            }
            foreach (var f in fighters) if (!present.Contains(f)) f.gameObject.SetActive(false);
            foreach (var f in removedFighters) if (f != null && !present.Contains(f)) f.gameObject.SetActive(false);

            // снаряды-призраки
            for (int i = 0; i < A.p.Count; i++)
            {
                while (ghostPool.Count <= i) ghostPool.Add(Draw.Line(transform, "ghost", 0.1f, Color.white, 300, true, 2));
                var g = ghostPool[i];
                var ps = A.p[i];
                g.enabled = true;
                Vector2 d = new Vector2(Mathf.Cos(ps.ang), Mathf.Sin(ps.ang));
                bool round = ps.kind == (int)Projectile.Kind.Fireball || ps.kind == (int)Projectile.Kind.Bolt || ps.kind == (int)Projectile.Kind.Grenade;
                g.widthMultiplier = round ? 0.4f : 0.08f;
                Draw.Set(g, ps.pos - d * (round ? 0.05f : 0.45f), ps.pos + d * 0.05f);
                Draw.Col(g, round ? ps.c : Color.Lerp(ps.c, Color.white, 0.4f));
            }
            for (int i = A.p.Count; i < ghostPool.Count; i++) ghostPool[i].enabled = false;

            // камера: запись + режиссёрский наезд и наклон
            Vector3 cpos = Vector3.Lerp(A.cam, B.cam, k);
            float size = Mathf.Lerp(A.size, B.size, k) * Mathf.Lerp(0.88f, 0.7f, Mathf.Clamp01(pw / 2.5f));
            cam.cam.orthographicSize = size;
            cam.cam.transform.position = new Vector3(cpos.x, Mathf.Max(cpos.y, size - 2.4f), -10f);
            cam.cam.transform.rotation = Quaternion.Euler(0, 0, Mathf.Sin(replayT * 0.7f) * 1.5f + (pw > 1.3f ? Mathf.Sin(replayT * 40f) * pw * 0.8f : 0f));

            fx.Tick(dt);
            for (int i = timed.Count - 1; i >= 0; i--)
            {
                var t = timed[i];
                t.t += dt;
                if (t.update != null) t.update(t.t, t.t / t.life);
                if (t.t >= t.life) { if (t.go != null) Destroy(t.go); timed.RemoveAt(i); }
            }
            for (int i = popups.Count - 1; i >= 0; i--)
            {
                var p = popups[i];
                p.t += dt; p.pos += p.vel * dt; p.vel *= 1f - dt * 3f;
                if (p.t >= p.life) popups.RemoveAt(i);
            }
            if (announceT > 0) announceT -= raw;
            if (flashT > 0) flashT -= raw;
            var cp = cam.cam.transform.position;
            theme.Follow(cp);
            theme.Tick(dt, fx, cp, size * cam.cam.aspect, size);

            if (capturing && !replayDone)
            {
                ScreenCapture.CaptureScreenshot(System.IO.Path.Combine(capDir, "frame_" + capFrame.ToString("00000") + ".png"));
                capFrame++;
            }
        }

        void PlayEvent(RecEv e)
        {
            switch (e.type)
            {
                case 0: HitSpark(e.a, e.b, e.x, e.c); break;
                case 2: popups.Add(new Popup { text = e.s, pos = e.a, col = e.c, life = 1.1f, size = e.x, vel = new Vector2(Random.Range(-0.3f, 0.3f), 1.6f) }); break;
                case 3: Flash(e.x, e.c); break;
                case 4: audio.Sfx(e.s, e.x); break;
                case 5: Shock(e.a, e.x, e.c); break;
                case 6: Crack(e.a, e.x > 0.5f); break;
                case 11: LightningVisual(e.a); break;
                case 15: Announce(e.s, e.c, Mathf.Min(e.x, 2f)); break;
                case 16:
                    ApplyStyle(3); impactT = 0.16f;
                    Flash(0.12f, new Color(1, 1, 1, 0.8f));
                    break;
                case 101: fx.Blood(e.a, e.b, e.x); break;
                case 107: fx.Dust(e.a, (int)e.x); break;
                case 108: fx.Fire(e.a, (int)e.x, e.b.x); break;
                case 109: fx.Smoke(e.a, (int)e.x, e.c, e.b.x, e.b.y); break;
                case 110: fx.Explosion(e.a, e.x); break;
                case 112: fx.Sparks(e.a, e.b, (int)e.x, e.c); break;
                case 113: fx.Fountain(e.a, e.b, (int)e.x); break;
                case 114: fx.Drip(e.a); break;
                case 117: fx.Pool(e.a, e.x); break;
            }
        }
    }
}
