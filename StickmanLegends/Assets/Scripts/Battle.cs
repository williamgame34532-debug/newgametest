using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public class Popup
    {
        public string text;
        public Vector2 pos, vel;
        public Color col;
        public float t, life, size;
    }

    public partial class Battle : MonoBehaviour
    {
        public enum Mode { Fight, Demo, Showroom, Replay, Survival }
        public enum Phase { Intro, Fight, Victory }

        public Mode mode;
        public Phase phase;
        public float phaseT;
        public int winner = -2;
        public float W = 15f;
        public bool paused;
        public const float IntroTime = 2.6f;

        public readonly List<Fighter> fighters = new List<Fighter>();
        public readonly List<Projectile> projs = new List<Projectile>();
        public readonly List<Pickup> pickups = new List<Pickup>();
        public readonly List<Popup> popups = new List<Popup>();
        readonly List<TimedFx> timed = new List<TimedFx>();

        public Particles fx;
        public Theme theme;
        public CameraDirector cam;
        public Audio audio;
        public int[] wins = new int[2];
        public string announce = "";
        public float announceT, announceMax;
        public Color announceCol = Color.white;

        float freeze, slowT, slowScale = 1f, dropTimer, killerT;
        public bool suddenDeath;
        public float fightTime, flashT;
        public Color flashCol = Color.white;
        public float SlowAmount { get { return 1f - slowScale; } }
        readonly List<WeaponStats> killerPool = new List<WeaponStats>();
        List<FighterBuild> redB, blueB;
        List<WeaponStats> dropPool;
        bool dropsOn, p1, p2;
        float dropInterval = 9f;
        Transform world;

        class TimedFx
        {
            public float t, life;
            public GameObject go;
            public System.Action<float, float> update;
        }

        public void Init(Camera c, Audio a)
        {
            audio = a;
            var tgo = new GameObject("Theme");
            tgo.transform.SetParent(transform, false);
            theme = tgo.AddComponent<Theme>();
            var pgo = new GameObject("Particles");
            pgo.transform.SetParent(transform, false);
            fx = pgo.AddComponent<Particles>();
            fx.W = W;
            cam = new CameraDirector(c);
            world = new GameObject("World").transform;
            world.SetParent(transform, false);
        }

        public void SetTheme(int id)
        {
            theme.Build(id, W);
            cam.cam.backgroundColor = theme.bg;
        }

        // ===================== НАСТРОЙКА БОЯ =====================
        public void Setup(Mode m, List<FighterBuild> red, List<FighterBuild> blue, List<WeaponStats> drops, bool dropsEnabled, float interval, bool p1Control, bool p2Control, bool keepStains)
        {
            Clear(keepStains);
            mode = m; redB = red; blueB = blue; dropPool = drops; dropsOn = dropsEnabled; dropInterval = Mathf.Max(3f, interval);
            p1 = p1Control; p2 = p2Control;
            winner = -2;
            paused = false;
            suddenDeath = false; fightTime = 0; flashT = 0; killerT = 7f;
            killerPool.Clear();
            freeze = 0; slowT = 0; slowScale = 1f;

            if (m == Mode.Showroom)
            {
                if (red != null && red.Count > 0) Spawn(red[0], 0, 0, new Vector2(0, 0), -1);
                phase = Phase.Fight;
                cam.Snap(new Vector2(-3f, 1.9f), 2.9f);
                return;
            }

            if (m == Mode.Survival) Spawn(red[0], 0, 0, new Vector2(0f, 0), 1);
            else for (int i = 0; i < red.Count; i++) Spawn(red[i], 0, i, new Vector2(-5f - i * 1.7f, 0), 1);
            for (int i = 0; i < blue.Count; i++) Spawn(blue[i], 1, i, new Vector2(5f + i * 1.7f, 0), -1);
            foreach (var f in fighters)
            {
                if (!f.B.killOnly && f.B.customWeak == null) continue;
                foreach (var km in f.B.killMasks)
                {
                    if (!f.B.killOnly && (km & (int)HF.Custom) == 0) continue;
                    var kw = Parser.KillerWeapon(km, f.B.name, f.B);
                    if (kw != null) { kw.killer = true; killerPool.Add(kw); }
                }
            }
            foreach (var f in fighters)
            {
                if (f.team == 0 && f.slot == 0 && p1) { f.human = true; f.pindex = 0; }
                if (f.team == 1 && f.slot == 0 && p2) { f.human = true; f.pindex = 1; }
            }
            phase = Phase.Intro;
            phaseT = 0;
            if (m == Mode.Survival)
            {
                SurvivalInit();
                Cinematic3D(new Vector2(0f, 1.2f), IntroTime * 0.85f, -70f, 0f, 12f, 7f);
                Announce("ОДИН ПРОТИВ ВСЕХ", new Color(1f, 0.2f, 0.15f), 2f);
                audio.Sfx("gong", 0.9f, 0f);
            }
            else ClearCrowd();
            if (m == Mode.Fight) BuildDuels(5); else if (m == Mode.Survival) BuildDuels(3); else ClearDuels();
            if (m == Mode.Fight)
            {
                StartRecording();
                float mid = 0f;
                Cinematic3D(new Vector2(mid, 1.2f), IntroTime * 0.85f, -55f, -5f, 13f, 9f);
            }
            dropTimer = dropInterval * 0.6f;
            cam.Snap(new Vector2(0, 2.5f), 9f);
            if (m == Mode.Fight)
            {
                Announce("ГОТОВЬСЯ...", new Color(1, 1, 1), 1.2f);
                audio.Sfx("gong", 0.8f, 0f);
            }
        }

        Fighter Spawn(FighterBuild b, int team, int slot, Vector2 p, int face)
        {
            var go = new GameObject("Fighter_" + b.name);
            go.transform.SetParent(world, false);
            var f = go.AddComponent<Fighter>();
            f.Init(b, team, slot, p, face, this, theme.glow);
            if (curStyle != 0) f.SetStyle(curStyle);
            fighters.Add(f);
            return f;
        }

        public void Restart(bool keepStains)
        {
            Setup(mode, redB, blueB, dropPool, dropsOn, dropInterval, p1, p2, keepStains);
        }

        public void Clear(bool keepStains)
        {
            End3D();
            foreach (var f in removedFighters) if (f != null) Destroy(f.gameObject);
            removedFighters.Clear();
            StopRecording();
            ResetStyle();
            foreach (var f in fighters) if (f != null) Destroy(f.gameObject);
            fighters.Clear();
            foreach (var p in projs) if (p != null) Destroy(p.gameObject);
            projs.Clear();
            foreach (var p in pickups) if (p != null) Destroy(p.gameObject);
            pickups.Clear();
            foreach (var t in timed) if (t.go != null) Destroy(t.go);
            timed.Clear();
            popups.Clear();
            announce = ""; announceT = 0;
            fx.Clear(!keepStains);
        }

        // ===================== ЦИКЛ =====================
        void Update()
        {
            float raw = Mathf.Min(Time.unscaledDeltaTime, 0.05f);
            float dt;
            if (paused) dt = 0f;
            else if (freeze > 0f) { freeze -= raw; dt = 0f; }
            else
            {
                if (slowT > 0f) { slowT -= raw; slowScale = Mathf.MoveTowards(slowScale, 0.22f, raw * 5f); }
                else slowScale = Mathf.MoveTowards(slowScale, 1f, raw * 1.5f);
                dt = raw * slowScale * Tempo;
            }
            float praw = paused ? 0f : raw;
            if (mode == Mode.Replay) { ReplayUpdate(raw); return; }
            StyleTick(raw);

            if (!paused) PhaseLogic(praw, dt);

            for (int i = 0; i < fighters.Count; i++) fighters[i].Tick(dt);
            RunDeferred();
            for (int i = fighters.Count - 1; i >= 0; i--)
                if (fighters[i].remove)
                {
                    if (mode == Mode.Survival) Destroy(fighters[i].gameObject); // в выживании повтора нет — не копим
                    else removedFighters.Add(fighters[i]);
                    fighters.RemoveAt(i);
                }
            CrowdTick(dt);
            DuelsTick(dt);
            for (int i = projs.Count - 1; i >= 0; i--)
            {
                var p = projs[i];
                if (p == null) { projs.RemoveAt(i); continue; }
                if (!p.Tick(dt, this)) { projs.RemoveAt(i); Destroy(p.gameObject); }
            }
            for (int i = pickups.Count - 1; i >= 0; i--) pickups[i].Tick(dt, this);
            for (int i = timed.Count - 1; i >= 0; i--)
            {
                var t = timed[i];
                t.t += dt;
                if (t.update != null) t.update(t.t, t.t / t.life);
                if (t.t >= t.life) { if (t.go != null) Destroy(t.go); timed.RemoveAt(i); }
            }
            fx.Tick(dt);
            for (int i = popups.Count - 1; i >= 0; i--)
            {
                var p = popups[i];
                p.t += praw;
                p.pos += p.vel * praw;
                p.vel *= 1f - praw * 3f;
                if (p.t >= p.life) popups.RemoveAt(i);
            }
            if (announceT > 0) announceT -= praw;
            if (flashT > 0) flashT -= raw;

            if (c3dCooldown > 0f) c3dCooldown -= raw;
            if (c3d) Cine3DTick(raw); else cam.Tick(praw, this);
            var cp = cam.cam.transform.position;
            float hh = cam.cam.orthographicSize;
            if (!c3d) cam2D = cp;
            if (!c3d) Always3DTick(raw);
            if (!alwaysOn || c3d) theme.Follow(cp);
            theme.Tick(dt, fx, cp, hh * cam.cam.aspect, hh);
            DecorFollow();
            if (!paused) RecordFrame(raw);
        }

        void PhaseLogic(float raw, float dt)
        {
            if (mode == Mode.Showroom) return;
            phaseT += raw;
            switch (phase)
            {
                case Phase.Intro:
                    float it = mode == Mode.Demo ? 0.6f : IntroTime;
                    if (phaseT >= it)
                    {
                        phase = Phase.Fight; phaseT = 0;
                        if (Epic)
                        {
                            Announce(mode == Mode.Survival ? "РЕЗНЯ!" : "БОЙ!", new Color(1f, 0.25f, 0.2f), 1.1f);
                            audio.Sfx("explosion", 0.5f, 0f);
                            cam.Shake(0.5f);
                        }
                    }
                    break;
                case Phase.Fight:
                    fightTime += dt;
                    if (killerPool.Count > 0)
                    {
                        bool onGround = false;
                        foreach (var p in pickups) if (p.w.killer) onGround = true;
                        foreach (var f in fighters) if (!f.dead && f.weapon != null && f.weapon.killer) onGround = true;
                        if (!onGround) killerT -= dt;
                        if (killerT <= 0f)
                        {
                            killerT = 12f;
                            var kw = killerPool[Random.Range(0, killerPool.Count)];
                            SpawnPickup(kw, kw.ammo, new Vector2(Random.Range(-W + 2f, W - 2f), 15f), Vector2.zero, true);
                            if (Epic) Announce("ОРУЖИЕ " + kw.name.ToUpper() + "!", new Color(1f, 0.8f, 0.2f), 1.6f);
                        }
                    }
                    if (!suddenDeath && fightTime > 100f)
                    {
                        bool any = false;
                        foreach (var f in fighters) if (!f.dead && f.B.killOnly) any = true;
                        if (any)
                        {
                            suddenDeath = true;
                            if (Epic) { Announce("ВНЕЗАПНАЯ СМЕРТЬ!", new Color(1f, 0.2f, 0.2f), 2f); audio.Sfx("gong", 0.8f, 0f); }
                        }
                    }
                    if (dropsOn && dropPool != null && dropPool.Count > 0 && pickups.Count < 3)
                    {
                        dropTimer -= dt;
                        if (dropTimer <= 0f)
                        {
                            dropTimer = dropInterval * Random.Range(0.7f, 1.3f);
                            var w = dropPool[Random.Range(0, dropPool.Count)];
                            SpawnPickup(w, w.ammo, new Vector2(Random.Range(-W + 2f, W - 2f), 15f), Vector2.zero, true);
                            if (Epic) Popup("СБРОС: " + w.name, new Vector2(cam.cam.transform.position.x, cam.cam.transform.position.y + cam.cam.orthographicSize * 0.6f), new Color(1f, 0.85f, 0.3f), 0.9f);
                        }
                    }
                    if (mode == Mode.Survival) { SurvivalTick(dt); break; }
                    bool r = false, b = false;
                    foreach (var f in fighters) { if (f.dead || f.minion || f.remove) continue; int tm = f.origTeam >= 0 ? f.origTeam : f.team; if (tm == 0) r = true; else b = true; }
                    if (!r || !b)
                    {
                        phase = Phase.Victory; phaseT = 0;
                        winner = r ? 0 : (b ? 1 : -1);
                        if (winner >= 0) wins[winner]++;
                        if (mode == Mode.Fight)
                        {
                            string name = winner == 0 ? "ПОБЕДА КРАСНЫХ!" : winner == 1 ? "ПОБЕДА СИНИХ!" : "НИЧЬЯ!";
                            Color col = winner == 0 ? new Color(1f, 0.3f, 0.25f) : winner == 1 ? new Color(0.35f, 0.6f, 1f) : Color.white;
                            Announce(name, col, 99f);
                            audio.Sfx("gong", 0.7f, 0f);
                        }
                        SlowMo(1.6f);
                    }
                    break;
                case Phase.Victory:
                    if (Epic && phaseT > 3f && VideoRecorder.I != null && VideoRecorder.I.Active && !capturing) VideoRecorder.I.End();
                    if (mode == Mode.Demo && phaseT > 4f && Game.I != null) Game.I.NextDemo();
                    break;
            }
        }

        public void Announce(string s, Color c, float t) { RecEvent(15, Vector2.zero, Vector2.zero, t, c, s); announce = s; announceCol = c; announceT = t; announceMax = t; }

        // ===================== ЗАПРОСЫ =====================
        public Fighter FindTarget(Fighter me)
        {
            Fighter best = null; float bd = 1e9f;
            Fighter bestInv = null; float bdi = 1e9f;
            foreach (var f in fighters)
            {
                if (f.dead || f.team == me.team) continue;
                float d = Mathf.Abs(f.pos.x - me.pos.x) + Mathf.Abs(f.pos.y - me.pos.y) * 0.5f;
                if (f.Invisible && d > 2.5f) { if (d < bdi) { bdi = d; bestInv = f; } continue; }
                if (d < bd) { bd = d; best = f; }
            }
            if (best == null && me.human) return bestInv;
            return best;
        }

        public Pickup NearestPickup(float x)
        {
            Pickup best = null; float bd = 1e9f;
            foreach (var p in pickups)
            {
                float d = Mathf.Abs(p.pos.x - x);
                if (d < bd) { bd = d; best = p; }
            }
            return best;
        }

        // ===================== СОБЫТИЯ =====================
        public void OnAttackStart(Fighter a)
        {
            if (mode == Mode.Showroom) return;
            foreach (var e in fighters)
            {
                if (e.dead || e.team == a.team || e.human) continue;
                if (Mathf.Abs(e.pos.x - a.pos.x) < a.Reach() + 1.4f) e.React(a);
            }
        }

        public void OnDeath(Fighter f, HitInfo h)
        {
            bool last = true;
            foreach (var o in fighters) if (!o.dead && o.team == f.team) last = false;
            if (mode == Mode.Showroom) return;
            bool big = true;
            if (mode == Mode.Survival)
            {
                if (f.team == 1 && !f.minion) survKills++;
                last = f == hero || f.boss;
                // в мясорубке эффектные кадры — только на боссах, каждом 10-м убийстве и гибели героя
                big = last || survKills % 10 == 0;
                if (survKills > 0 && survKills % 25 == 0 && f.team == 1) Announce(survKills + " УБИТО!", new Color(1f, 0.3f, 0.2f), 1.2f);
            }
            if (last || (big && (Random.value < 0.35f || h.heavy)))
            {
                SlowMo(last ? 1.4f : 0.8f);
                cam.Focus(f.Center, last ? 1.3f : 0.7f);
            }
            cam.Shake(0.6f);
            cam.Kick(1f);
            Flash(0.12f, new Color(1f, 1f, 1f, 0.75f));
            RecEvent(16, f.Center, Vector2.zero, 0, Color.white, null);
            if (Epic && (big || survKills % 5 == 0)) ImpactFrame();
            if (Epic && big) { float side = Random.value < 0.5f ? -1f : 1f; Cinematic3D(f.Center, last ? 1.6f : 1.1f, side * 40f, side * 12f, 7.5f, 4.5f); }
            Popup("K.O.", f.J[2] + Vector2.up * 0.8f, new Color(1f, 0.9f, 0.2f), 1.3f);
            audio.Duck(0.5f);
        }

        public void Impact(float dmg, Vector2 at, bool heavy)
        {
            if (mode == Mode.Showroom) return;
            freeze = Mathf.Max(freeze, Mathf.Min(0.12f, 0.025f + dmg * 0.003f + (heavy ? 0.03f : 0f)));
            cam.Shake(Mathf.Min(0.6f, dmg * 0.018f + (heavy ? 0.25f : 0f)));
            if (dmg > 12f || heavy) cam.Kick(Mathf.Min(1f, dmg / 25f));
            if (heavy && dmg > 10f) Flash(0.05f, new Color(1f, 1f, 1f, 0.3f));
            if (Epic && heavy && dmg > 16f && Random.value < 0.3f) { int[] fl = { 2, 3, 12, 13, 6 }; FlashStyle(fl[Random.Range(0, fl.Length)], 0.09f); }
            if (Epic && heavy && dmg > 12f && !c3d && c3dCooldown <= 0f && Random.value < (mode == Mode.Survival ? 0.12f : 0.3f)) { float side = Random.value < 0.5f ? -1f : 1f; Cinematic3D(at, 0.8f, side * 30f, side * 18f, 5.5f, 4.2f); }
            else if (Epic && (heavy || dmg > 14f) && Random.value < (mode == Mode.Survival ? 0.12f : 0.35f)) cam.Cut(at + Vector2.up * 0.4f, Random.Range(2.6f, 3.4f), Random.Range(0.35f, 0.6f));
        }

        public void SlowMo(float dur)
        {
            if (Game.I != null && !Game.I.S.slowmo) return;
            slowT = Mathf.Max(slowT, dur);
        }

        public void Popup(string text, Vector2 at, Color c, float size)
        {
            RecEvent(2, at, Vector2.zero, size, c, text);
            popups.Add(new Popup { text = text, pos = at, col = c, life = 1.1f, size = size, vel = new Vector2(Random.Range(-0.3f, 0.3f), 1.6f) });
        }

        public void DamageNumber(float d, Vector2 at, bool weak, bool head)
        {
            if (Game.I != null && !Game.I.S.damageNumbers) return;
            if (mode == Mode.Showroom) return;
            Color c = weak ? new Color(1f, 0.85f, 0.1f) : (head ? new Color(1f, 0.3f, 0.2f) : new Color(1f, 1f, 1f));
            RecEvent(2, at, Vector2.zero, Mathf.Clamp(0.5f + d / 30f, 0.5f, 1.1f), c, Mathf.RoundToInt(d).ToString() + (head ? "!" : ""));
            popups.Add(new Popup { text = Mathf.RoundToInt(d).ToString() + (head ? "!" : ""), pos = at + Random.insideUnitCircle * 0.3f, col = c, life = 0.8f, size = Mathf.Clamp(0.5f + d / 30f, 0.5f, 1.1f), vel = new Vector2(Random.Range(-1f, 1f), 2.5f) });
        }

        // ===================== СПАВН =====================
        public Projectile SpawnProjectile(Projectile.Kind k, Vector2 from, Vector2 v, Fighter owner, HitInfo hit, Color c)
        {
            var go = new GameObject("proj");
            go.transform.SetParent(world, false);
            var p = go.AddComponent<Projectile>();
            p.Init(k, from, v, owner, hit, c);
            projs.Add(p);
            foreach (var e in fighters)
            {
                if (e.dead || e.team == owner.team) continue;
                if (Mathf.Sign(e.pos.x - from.x) != Mathf.Sign(v.x)) continue;
                float delay = Mathf.Abs(e.pos.x - from.x) / Mathf.Max(1f, Mathf.Abs(v.x)) - 0.25f;
                e.NotifyIncoming(delay);
            }
            return p;
        }

        public void SpawnPickup(WeaponStats w, int ammo, Vector2 at, Vector2 v, bool parachute)
        {
            var go = new GameObject("pickup_" + w.name);
            go.transform.SetParent(world, false);
            var p = go.AddComponent<Pickup>();
            p.Init(w.Copy(), ammo, at, v, parachute);
            pickups.Add(p);
        }

        public void RemovePickup(Pickup p)
        {
            pickups.Remove(p);
            if (p != null) Destroy(p.gameObject);
        }

        TimedFx AddFx(GameObject go, float life, System.Action<float, float> upd)
        {
            if (go != null) go.transform.SetParent(world, true);
            var t = new TimedFx { go = go, life = life, update = upd };
            timed.Add(t);
            return t;
        }

        public int MinionCount(Fighter owner)
        {
            int n = 0;
            foreach (var f in fighters) if (f.minion && !f.dead && f.team == owner.team) n++;
            return n;
        }

        // Призыв помощников: магический круг, дым, маленькие бойцы на стороне хозяина
        public void SpawnMinions(Fighter owner, int n, string kind = "Помощник")
        {
            for (int i = 0; i < n; i++)
            {
                var b = new FighterBuild();
                b.name = kind ?? "Помощник";
                b.color = Color.Lerp(owner.B.color, Color.white, 0.35f);
                b.hp = 30f + owner.B.hp * 0.05f; b.str = 0.7f; b.spd = 1.15f; b.def = 0.7f; b.agi = 1.1f; b.size = 0.7f;
                b.killMasks.Add((int)HF.Blunt);
                b.style = Style.Brute;
                b.acc.Add(Acc.Eyes);
                b.accCol[Acc.Eyes] = new Color(0.7f, 0.4f, 1f);
                switch (b.name)
                {
                    case "Скелет": b.color = new Color(0.93f, 0.91f, 0.85f); b.accCol[Acc.Eyes] = new Color(0.3f, 1f, 0.6f); b.style = Style.Balanced; break;
                    case "Клон":
                        b.color = owner.B.color; b.size = 0.85f; b.hp = owner.B.hp * 0.25f;
                        foreach (var a in owner.B.acc) if (a != Acc.Wings && !b.acc.Contains(a)) b.acc.Add(a);
                        foreach (var kv in owner.B.accCol) b.accCol[kv.Key] = kv.Value;
                        b.style = owner.B.style; break;
                    case "Демон": b.color = new Color(0.65f, 0.05f, 0.05f); b.acc.Add(Acc.Horns); b.acc.Add(Acc.Tail); b.accCol[Acc.Eyes] = new Color(1f, 0.85f, 0.1f); b.str = 1f; break;
                    case "Зомби": b.color = new Color(0.4f, 0.6f, 0.3f); b.spd = 0.7f; b.hp *= 1.6f; break;
                    case "Дух": b.color = new Color(0.55f, 0.9f, 1f); b.acc.Add(Acc.Aura); b.accCol[Acc.Aura] = new Color(0.5f, 0.9f, 1f); b.agi = 1.5f; break;
                    case "Воин": b.color = new Color(0.45f, 0.45f, 0.5f); b.acc.Add(Acc.Helmet); b.acc.Add(Acc.Armor); b.def = 1.2f; break;
                    case "Дрон": b.color = new Color(0.35f, 0.38f, 0.42f); b.acc.Add(Acc.Visor); break;
                    case "Тень": b.color = new Color(0.05f, 0.05f, 0.06f); b.accCol[Acc.Eyes] = new Color(1f, 0.1f, 0.1f); b.style = Style.Acrobat; break;
                }
                if (owner.weapon != null && owner.weapon.kind == WeaponKind.Staff && b.name == "Помощник") b.acc.Add(Acc.Hood);
                float x = Mathf.Clamp(owner.pos.x + owner.facing * (1.2f + i * 0.9f) * (i % 2 == 0 ? 1 : -1), -W + 1f, W - 1f);
                var f = Spawn(b, owner.team, 4, new Vector2(x, 0), owner.facing);
                f.SetupMinion(owner, 15f);
                f.vel = new Vector2(0, 6f);
                Shock(new Vector2(x, 0.05f), 1.4f, new Color(0.7f, 0.4f, 1f, 0.9f));
                fx.Smoke(new Vector2(x, 0.6f), 14, new Color(0.5f, 0.3f, 0.8f, 0.6f), 0.5f, 0.6f);
                for (int k = 0; k < 14; k++) fx.Emit(new Vector2(x + Random.Range(-0.6f, 0.6f), 0.1f), Vector2.up * Random.Range(1f, 4f), new Color(0.75f, 0.5f, 1f, 0.9f), 0.12f, 0.6f, 0f, false, 1f, true, 1, 1, true);
            }
            audio.Sfx("teleport", 0.9f);
        }

        public void Flash(float t, Color c)
        {
            RecEvent(3, Vector2.zero, Vector2.zero, t, c, null);
            if (mode == Mode.Showroom) return;
            flashT = Mathf.Max(flashT, t); flashCol = c;
        }

        // Искра удара: вспышка, лучи, кольцо (как в стикмен-анимациях)
        static readonly string[] ONO = { "БАМ!", "ХРЯСЬ!", "БУМ!", "ПАФ!", "ТРАХ!", "КРАК!", "ВЖУХ!", "БАЦ!" };

        public void HitSpark(Vector2 at, Vector2 dir, float power, Color c)
        {
            RecEvent(0, at, dir, power, c, null);
            if (mode != Mode.Showroom && (power >= 1.6f || (curStyle == 6 && power >= 0.8f)))
            {
                FocusLines(at, Mathf.Min(1.5f, power * 0.7f));
                if (curStyle == 6 || Random.value < 0.45f)
                    popups.Add(new Popup { text = ONO[Random.Range(0, ONO.Length)], pos = at + new Vector2(Random.Range(-0.6f, 0.6f), 0.9f), col = curStyle == 6 ? Color.white : new Color(1f, 0.88f, 0.2f), life = 0.7f, size = 1.1f + power * 0.25f, vel = new Vector2(Random.Range(-1f, 1f), 2.2f) });
            }
            var go = new GameObject("spark");
            var core = Draw.Spr(go.transform, "core", Draw.Circle, Color.white, 352);
            core.transform.position = at;
            var glowS = Draw.Spr(go.transform, "glow", Draw.Soft, Draw.A(c, 0.8f), 350);
            glowS.transform.position = at;
            int n = 6 + (int)(power * 3);
            var rays = new List<LineRenderer>();
            var dirs = new List<Vector2>();
            var lens = new List<float>();
            float baseAng = Mathf.Atan2(dir.y, dir.x);
            for (int i = 0; i < n; i++)
            {
                var lr = Draw.Line(go.transform, "ray", 1f, c, 351, true, 0);
                Draw.Taper(lr, 0.11f * power, 0f);
                rays.Add(lr);
                float a = (i < n / 2) ? baseAng + Random.Range(-0.9f, 0.9f) : Random.Range(0f, Mathf.PI * 2f);
                dirs.Add(new Vector2(Mathf.Cos(a), Mathf.Sin(a)));
                lens.Add(Random.Range(0.5f, 1.2f) * power);
            }
            var ring = Draw.Line(go.transform, "ring", 0.06f, Draw.A(c, 0.8f), 351, true, 0);
            ring.loop = true; ring.positionCount = 20;
            AddFx(go, 0.16f + power * 0.03f, (t, k) =>
            {
                float e = 1f - (1f - k) * (1f - k);
                core.transform.localScale = Vector3.one * Mathf.Lerp(0.55f, 0f, k) * power;
                glowS.transform.localScale = Vector3.one * (1.6f + e) * power;
                glowS.color = Draw.A(c, 0.7f * (1f - k));
                for (int i = 0; i < rays.Count; i++)
                {
                    Vector2 s0 = at + dirs[i] * (0.15f + lens[i] * e * 0.6f);
                    Vector2 s1 = at + dirs[i] * (0.3f + lens[i] * e * 1.4f);
                    Draw.Set(rays[i], s1, s0);
                    Draw.Col(rays[i], Draw.A(c, 1f - k));
                }
                float r = Mathf.Lerp(0.2f, 1.1f, e) * power;
                for (int i = 0; i < 20; i++)
                {
                    float a = i / 20f * Mathf.PI * 2f;
                    ring.SetPosition(i, at + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r);
                }
                Draw.Col(ring, Draw.A(c, 0.7f * (1f - k)));
                ring.widthMultiplier = 0.08f * (1f - k) * power + 0.01f;
            });
        }

        // Трещины в земле / стене после мощного удара
        public void Crack(Vector2 at, bool wall)
        {
            RecEvent(6, at, Vector2.zero, wall ? 1 : 0, Color.black, null);
            var go = new GameObject("crack");
            var lines = new List<LineRenderer>();
            Color c = theme.id == 0 ? new Color(0.1f, 0.1f, 0.1f, 0.9f) : new Color(0.05f, 0.05f, 0.05f, 0.85f);
            if (theme.id == 4) c = new Color(0.1f, 0.95f, 1f, 0.9f);
            int n = Random.Range(3, 6);
            for (int i = 0; i < n; i++)
            {
                var lr = Draw.Line(go.transform, "c", 0.05f, c, -1, true, 0);
                var pts = new List<Vector2>();
                Vector2 p = wall ? new Vector2(at.x, at.y) : new Vector2(at.x, -0.02f);
                pts.Add(p);
                float ang = wall ? (Mathf.PI * 0.5f + Random.Range(-1.3f, 1.3f) + (i % 2 == 0 ? 0 : Mathf.PI)) : Random.Range(-Mathf.PI * 0.95f, -Mathf.PI * 0.05f);
                int segs = Random.Range(3, 6);
                for (int k = 0; k < segs; k++)
                {
                    ang += Random.Range(-0.5f, 0.5f);
                    p += new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * Random.Range(0.15f, 0.35f);
                    if (!wall) p.y = Mathf.Min(p.y, -0.02f);
                    pts.Add(p);
                }
                Draw.Set(lr, pts);
                Draw.Taper(lr, 0.07f, 0.01f);
                lines.Add(lr);
            }
            AddFx(go, 7f, (t, k) =>
            {
                float a = k < 0.8f ? 1f : 1f - (k - 0.8f) / 0.2f;
                foreach (var l in lines) Draw.Col(l, Draw.A(c, c.a * a));
            });
        }

        public void Shock(Vector2 at, float radius, Color c)
        {
            RecEvent(5, at, Vector2.zero, radius, c, null);
            var go = new GameObject("shock");
            var lr = Draw.Line(go.transform, "ring", 0.12f, c, 330, true, 0);
            lr.loop = true;
            lr.positionCount = 32;
            AddFx(go, 0.35f, (t, k) =>
            {
                float r = Mathf.Lerp(0.2f, radius, 1f - (1f - k) * (1f - k));
                for (int i = 0; i < 32; i++)
                {
                    float a = i / 32f * Mathf.PI * 2f;
                    lr.SetPosition(i, at + new Vector2(Mathf.Cos(a) * r, Mathf.Sin(a) * r * 0.35f + 0.05f));
                }
                Draw.Col(lr, Draw.A(c, c.a * (1f - k)));
                lr.widthMultiplier = 0.15f * (1f - k) + 0.02f;
            });
        }

        public void AfterImage(Fighter f, Color c)
        {
            var go = new GameObject("ghost");
            var pts = (Vector2[])f.J.Clone();
            float w = Skel.Width * f.Size;
            var lines = new List<LineRenderer>();
            int[][] chains = { new[] { 0, 9, 10 }, new[] { 0, 7, 8 }, new[] { 0, 1 }, new[] { 1, 5, 6 }, new[] { 1, 3, 4 } };
            foreach (var ch in chains)
            {
                var lr = Draw.Line(go.transform, "g", w, c, 90, true, 3);
                var l = new List<Vector2>();
                foreach (int i in ch) l.Add(pts[i]);
                Draw.Set(lr, l);
                lines.Add(lr);
            }
            var head = Draw.Spr(go.transform, "h", Draw.Circle, c, 90);
            head.transform.position = pts[2];
            head.transform.localScale = Vector3.one * Skel.HeadR * 2f * f.Size;
            AddFx(go, 0.3f, (t, k) =>
            {
                var cc = Draw.A(c, c.a * (1f - k));
                foreach (var lr in lines) Draw.Col(lr, cc);
                head.color = cc;
            });
        }

        public void LightningStrike(Vector2 at, Fighter caster, float dmg)
        {
            LightningVisual(at);
            fx.Sparks(at, Vector2.up, 20, new Color(1f, 1f, 0.5f));
            audio.Sfx("zap", 1f);
            cam.Shake(0.4f);
            foreach (var e in fighters)
            {
                if (e.dead || e.team == caster.team) continue;
                if (Mathf.Abs(e.pos.x - at.x) < 1.3f)
                {
                    var h = new HitInfo { dmg = dmg * Random.Range(0.9f, 1.1f), type = DmgType.Lightning, elem = Element.Lightning, attacker = caster, dir = new Vector2(Mathf.Sign(e.pos.x - at.x + 0.01f), 0.6f).normalized, point = e.Center, knock = 4f, stun = 0.7f };
                    e.TakeHit(h);
                }
            }
        }

        public void LightningVisual(Vector2 at)
        {
            RecEvent(11, at, Vector2.zero, 0, Color.white, null);
            var go = new GameObject("lightning");
            var core = Draw.Line(go.transform, "bolt", 0.12f, new Color(1f, 1f, 0.85f), 345, true, 0);
            var glowL = Draw.Line(go.transform, "boltGlow", 0.5f, new Color(1f, 0.95f, 0.4f, 0.35f), 344, true, 0);
            var pts = new List<Vector2>();
            float top = at.y + 16f;
            float x = at.x + Random.Range(-2f, 2f);
            for (int i = 0; i <= 14; i++)
            {
                float y = Mathf.Lerp(top, 0f, i / 14f);
                float xx = Mathf.Lerp(x, at.x, i / 14f) + (i > 0 && i < 14 ? Random.Range(-0.6f, 0.6f) : 0f);
                pts.Add(new Vector2(xx, y));
            }
            Draw.Set(core, pts);
            Draw.Set(glowL, pts);
            var flashS = Draw.Spr(go.transform, "flash", Draw.Soft, new Color(1f, 1f, 0.7f, 0.8f), 343);
            flashS.transform.position = at + Vector2.up * 0.8f;
            flashS.transform.localScale = Vector3.one * 6f;
            AddFx(go, 0.35f, (t, k) =>
            {
                float a = (1f - k) * (Random.value < 0.3f ? 0.3f : 1f);
                Draw.Col(core, new Color(1f, 1f, 0.85f, a));
                Draw.Col(glowL, new Color(1f, 0.95f, 0.4f, 0.35f * a));
                flashS.color = new Color(1f, 1f, 0.7f, 0.8f * (1f - k));
            });
        }

        public void Explosion(Vector2 at, float radius, HitInfo baseHit, int team)
        {
            fx.Explosion(at, radius);
            Shock(at, radius * 1.2f, new Color(1f, 0.7f, 0.3f, 0.9f));
            audio.Sfx("explosion", 0.9f);
            cam.Shake(0.6f);
            cam.Kick(0.8f);
            foreach (var e in fighters)
            {
                if (e.dead || e.team == team) continue;
                Vector2 d = e.Center - at;
                if (d.magnitude < radius + 0.4f * e.Size)
                {
                    var h = baseHit.Copy();
                    h.extra |= HF.Explosion;
                    h.knockdown = true;
                    h.dir = (d.normalized + Vector2.up * 0.6f).normalized;
                    h.point = e.Center;
                    h.knock = Mathf.Max(h.knock, 8f);
                    h.heavy = true;
                    e.TakeHit(h);
                }
            }
        }
    }

    // ===================== КАМЕРА =====================
    public class CameraDirector
    {
        public Camera cam;
        Vector2 c;
        float size = 6f, trauma, kick, focusT, t;
        Vector2 focusP;

        public CameraDirector(Camera cam)
        {
            this.cam = cam;
            cam.orthographic = true;
            cam.orthographicSize = 6f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.transform.position = new Vector3(0, 3, -10);
            cam.transform.rotation = Quaternion.identity;
            cam.nearClipPlane = 0.1f;
            cam.farClipPlane = 100f;
        }

        public void Snap(Vector2 center, float s) { c = center; size = s; trauma = 0; kick = 0; focusT = 0; cutT = 0; }
        float cutT, cutS;
        Vector2 cutC;
        // монтажная склейка: камера мгновенно «режет» на крупный план, как в анимации
        public void Cut(Vector2 at, float s, float dur) { cutC = at; cutS = s; cutT = dur; c = at; size = s; }
        public void Shake(float a) { if (Game.I != null && !Game.I.S.shake) return; trauma = Mathf.Min(1f, trauma + a); }
        public void Kick(float k) { kick = Mathf.Max(kick, k); }
        public void Focus(Vector2 p, float dur) { focusP = p; focusT = dur; }

        public void Tick(float raw, Battle b)
        {
            t += raw;
            float aspect = Mathf.Max(0.5f, cam.aspect);
            Vector2 tc; float ts;
            if (b.mode == Battle.Mode.Showroom)
            {
                ts = 2.9f;
                float fx = b.fighters.Count > 0 ? b.fighters[0].pos.x : 0f;
                tc = new Vector2(fx - ts * aspect * 0.55f, 1.9f);
            }
            else
            {
                float minX = 1e9f, maxX = -1e9f, minY = 0f, maxY = 2f;
                int n = 0;
                foreach (var f in b.fighters)
                {
                    if (f.dead && f.deadTime > 1.5f) continue;
                    if (b.mode == Battle.Mode.Survival && !b.SurvivalCamInclude(f)) continue;
                    Vector2 h = f.HeadPos;
                    Vector2 p = f.dead ? f.Center : f.pos;
                    minX = Mathf.Min(minX, Mathf.Min(p.x, h.x)); maxX = Mathf.Max(maxX, Mathf.Max(p.x, h.x));
                    minY = Mathf.Min(minY, p.y); maxY = Mathf.Max(maxY, h.y + 0.4f);
                    n++;
                }
                if (n == 0) { minX = -4; maxX = 4; }
                tc = new Vector2((minX + maxX) * 0.5f, (minY + maxY) * 0.5f);
                ts = Mathf.Max((maxY - minY) * 0.5f + 1.8f, ((maxX - minX) * 0.5f + 2.6f) / aspect);
                ts = Mathf.Clamp(ts, 3.6f, 10.5f);
                if (b.mode == Battle.Mode.Survival) ts = Mathf.Min(ts, 8.2f);
                if (b.phase == Battle.Phase.Intro && b.mode == Battle.Mode.Fight)
                {
                    float k = Mathf.Clamp01(b.phaseT / Battle.IntroTime);
                    ts *= Mathf.Lerp(1.5f, 1f, k * k);
                }
                if (b.phase == Battle.Phase.Victory) ts *= 0.85f;
                if (focusT > 0f)
                {
                    focusT -= raw;
                    tc = focusP + Vector2.up * 0.6f;
                    ts = 3.4f;
                }
            }
            if (cutT > 0f && b.mode != Battle.Mode.Showroom) { cutT -= raw; tc = cutC; ts = cutS; c = Vector2.Lerp(c, cutC, 1f - Mathf.Exp(-raw * 2f)); size = cutS; }
            else
            {
                size = Mathf.Lerp(size, ts, 1f - Mathf.Exp(-raw * 3.2f));
                c = Vector2.Lerp(c, tc, 1f - Mathf.Exp(-raw * 4.5f));
            }
            kick = Mathf.MoveTowards(kick, 0f, raw * 3f);
            float half = size * (1f - kick * 0.07f);
            Vector2 cc = c;
            float minCy = half - 2.4f;
            if (cc.y < minCy) cc.y = minCy;
            float limX = b.W + 3f - half * aspect;
            cc.x = limX > 0 ? Mathf.Clamp(cc.x, -limX, limX) : 0f;
            trauma = Mathf.MoveTowards(trauma, 0f, raw * 1.6f);
            float sh = trauma * trauma;
            Vector2 off = new Vector2(Mathf.PerlinNoise(t * 25f, 0.3f) - 0.5f, Mathf.PerlinNoise(0.7f, t * 25f) - 0.5f) * 2f * sh * 0.8f;
            cam.orthographicSize = half;
            cam.transform.position = new Vector3(cc.x + off.x, cc.y + off.y, -10f);
            cam.transform.rotation = Quaternion.Euler(0, 0, (Mathf.PerlinNoise(t * 18f, 5.1f) - 0.5f) * 2f * sh * 4f);
        }
    }
}
