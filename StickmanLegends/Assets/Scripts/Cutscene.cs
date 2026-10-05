using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Катсцена перед «Один против всех»: герой появляется во вспышке, удивляется, в него бьёт молния,
    // он встаёт, впервые применяет свою силу, получает своё снаряжение и называет себя.
    // И усилители, которые падают с неба во время выживания.
    public partial class Battle
    {
        public bool playCutscene;          // выставляет Game перед первым запуском выживания
        public bool cutsceneOn;
        public float cutT;
        int cutStep;
        FighterBuild cutFull;              // полный герой (со снаряжением) — появится к концу сцены
        bool cutRevealDone;
        public string dialogWho, dialogText;
        public float dialogT, dialogMax;
        public Color dialogCol = Color.white;
        public float cutBlack;             // затемнение в начале

        public static FighterBuild PlainBuild(FighterBuild full)
        {
            var p = full.Clone();
            p.acc.Clear(); p.accCol.Clear(); p.items.Clear();
            p.headKind = 0; p.skullArmor = false; p.weapon = null; p.secondary = null; p.eyes2 = false;
            return p;
        }

        static bool HasGear(FighterBuild b)
        {
            return b.acc.Count > 0 || b.items.Count > 0 || b.headKind != 0 || b.weapon != null || b.skullArmor;
        }

        void StartCutscene(FighterBuild full)
        {
            cutsceneOn = true; cutT = 0f; cutStep = 0; cutFull = full; cutRevealDone = !HasGear(full);
            cutBlack = 1f;
            dialogText = null;
            if (hero != null) hero.cutHidden = true;
        }

        void Say(string who, string text, float t, Color c)
        {
            dialogWho = who; dialogText = text; dialogT = dialogMax = t; dialogCol = c;
            audio.Sfx("click", 0.4f, 0f);
        }

        public void SkipCutscene()
        {
            if (!cutsceneOn) return;
            if (hero != null) { hero.cutHidden = false; hero.hp = hero.maxHp; }
            Reveal();
            EndCutscene();
        }

        void Reveal()
        {
            if (cutRevealDone || hero == null || cutFull == null) { cutRevealDone = true; return; }
            cutRevealDone = true;
            hero.RevealAs(cutFull);
        }

        void EndCutscene()
        {
            cutsceneOn = false; dialogText = null; cutBlack = 0f;
            if (hero != null) { hero.cutHidden = false; hero.hp = hero.maxHp; }
            phase = Phase.Fight; phaseT = 0;
            Announce("ОДИН ПРОТИВ ВСЕХ", new Color(1f, 0.2f, 0.15f), 1.6f);
            audio.Sfx("gong", 0.9f, 0f);
            audio.Sfx("explosion", 0.5f, 0f);
            cam.Shake(0.5f);
        }

        void CutsceneTick(float raw)
        {
            if (hero == null) { EndCutscene(); return; }
            cutT += raw;
            if (dialogT > 0f) dialogT -= raw;
            cutBlack = Mathf.MoveTowards(cutBlack, cutStep >= 1 ? 0f : 1f, raw * 1.5f);
            cam.Focus(hero.Center, 0.3f);
            string nm = hero.B.name;
            if (nm.Contains(" (")) nm = nm.Substring(0, nm.IndexOf(" ("));
            Color hc = Color.Lerp(hero.B.color, Color.white, 0.45f);
            switch (cutStep)
            {
                case 0:
                    if (cutT > 0.7f)
                    {
                        // появление со вспышкой
                        hero.cutHidden = false;
                        Flash(0.25f, new Color(1, 1, 1, 1f));
                        Shock(hero.Center, 3.5f, Color.white);
                        for (int i = 0; i < 40; i++) fx.Emit(hero.Center, Random.insideUnitCircle * 9f, new Color(1f, 1f, 0.9f), 0.12f, 0.6f, 0f, false, 2f, true, 1, 1, true);
                        audio.Sfx("cine", 1f, 0f); audio.Sfx("teleport", 0.8f, 0f);
                        Cinematic3D(hero.Center, 2.6f, -45f, -10f, 7f, 5f);
                        cutStep = 1; cutT = 0f;
                    }
                    break;
                case 1: if (cutT > 1.2f) { Say(nm, "Где я?..", 2.2f, hc); cutStep = 2; cutT = 0f; } break;
                case 2: if (cutT > 2.4f) { Say(nm, "Я чувствую в себе какую-то силу...", 2.4f, hc); cutStep = 3; cutT = 0f; } break;
                case 3:
                    if (cutT > 2.6f)
                    {
                        // в него бьёт молния — он падает
                        dialogText = null;
                        LightningVisual(new Vector2(hero.pos.x, 0));
                        Flash(0.15f, new Color(1f, 1f, 0.8f, 0.9f));
                        fx.Sparks(hero.Center, Vector2.up, 30, new Color(1f, 1f, 0.6f));
                        audio.Sfx("zap", 1f, 0f); audio.Sfx("explosion", 0.6f, 0f);
                        cam.Shake(0.8f);
                        var h = new HitInfo { dmg = 1f, type = DmgType.Lightning, elem = Element.Lightning, dir = new Vector2(-hero.facing, 0.8f).normalized, point = hero.Center, knock = 7f, stun = 0.5f, knockdown = true, blast = true, lift = 6f };
                        hero.TakeHit(h);
                        cutStep = 4; cutT = 0f;
                    }
                    break;
                case 4:
                    if (cutT > 2.4f && hero.body == Fighter.BodyS.Normal)
                    {
                        // встаёт и впервые применяет силу
                        hero.CutsceneAbility();
                        cutStep = 5; cutT = 0f;
                    }
                    break;
                case 5: if (cutT > 1.8f) { Say(nm, "Раз у меня появились суперсилы — пора ими и пользоваться!", 2.8f, hc); cutStep = 6; cutT = 0f; } break;
                case 6:
                    if (cutT > 3f)
                    {
                        if (!cutRevealDone) { Reveal(); }
                        cutStep = 7; cutT = 0f;
                    }
                    break;
                case 7: if (cutT > 1f) { Say(nm, "Я — " + nm + ", и мой путь теперь — путь воина.", 3f, hc); cutStep = 8; cutT = 0f; } break;
                case 8: if (cutT > 3.2f) EndCutscene(); break;
            }
        }

        // ======================= УСИЛИТЕЛИ =======================
        public class Boost
        {
            public GameObject go;
            public SpriteRenderer core, glow, ring;
            public Vector2 pos;
            public float vy, life, t;
            public int kind;
            public bool landed;
        }
        public readonly List<Boost> boosts = new List<Boost>();
        public readonly int[] boostTaken = new int[6];
        float boostT = 12f;
        public static readonly string[] BoostNames = { "ЛЕЧЕНИЕ", "СИЛА", "СКОРОСТЬ", "МОЩЬ УМЕНИЙ", "ЗДОРОВЬЕ+", "ЩИТ" };
        public static readonly Color[] BoostCols = { new Color(0.3f, 1f, 0.4f), new Color(1f, 0.3f, 0.2f), new Color(1f, 0.9f, 0.25f), new Color(0.75f, 0.35f, 1f), new Color(1f, 0.45f, 0.7f), new Color(0.35f, 0.9f, 1f) };

        public void SpawnBoost(int kind, float x)
        {
            var b = new Boost { kind = kind, pos = new Vector2(Mathf.Clamp(x, -W + 1.5f, W - 1.5f), 11f), vy = -2.5f, life = 22f };
            b.go = new GameObject("boost");
            b.go.transform.SetParent(transform, false);
            Color c = BoostCols[kind];
            b.glow = Draw.Spr(b.go.transform, "glow", Draw.Soft, Draw.A(c, 0.6f), 60);
            b.glow.transform.localScale = Vector3.one * 2.2f;
            b.ring = Draw.Spr(b.go.transform, "ring", Draw.Circle, Color.Lerp(c, Color.black, 0.5f), 61);
            b.ring.transform.localScale = Vector3.one * 0.62f;
            b.core = Draw.Spr(b.go.transform, "core", Draw.Circle, c, 62);
            b.core.transform.localScale = Vector3.one * 0.5f;
            boosts.Add(b);
        }

        void ClearBoosts()
        {
            foreach (var b in boosts) if (b.go != null) Destroy(b.go);
            boosts.Clear();
            for (int i = 0; i < boostTaken.Length; i++) boostTaken[i] = 0;
            boostT = 12f;
        }

        void BoostsTick(float dt)
        {
            if (mode != Mode.Survival) return;
            if (phase == Phase.Fight && !intermission && hero != null && !hero.dead)
            {
                boostT -= dt;
                if (boostT <= 0f && boosts.Count < 3)
                {
                    boostT = Random.Range(13f, 21f);
                    SpawnBoost(Random.Range(0, 6), hero.pos.x + Random.Range(-6f, 6f));
                }
            }
            for (int i = boosts.Count - 1; i >= 0; i--)
            {
                var b = boosts[i];
                b.t += dt; b.life -= dt;
                if (!b.landed)
                {
                    b.pos.y += b.vy * dt;
                    if (b.pos.y <= 0.55f) { b.pos.y = 0.55f; b.landed = true; Shock(new Vector2(b.pos.x, 0.05f), 1f, BoostCols[b.kind]); audio.Sfx("land", 0.4f); }
                }
                Vector2 p = b.pos + Vector2.up * (b.landed ? Mathf.Sin(b.t * 4f) * 0.12f : 0f);
                b.go.transform.position = p;
                float pulse = 1f + Mathf.Sin(b.t * 7f) * 0.12f;
                b.glow.transform.localScale = Vector3.one * 2.2f * pulse;
                if (Random.value < dt * 8f) fx.Emit(p + Random.insideUnitCircle * 0.3f, Vector2.up * Random.Range(0.5f, 1.5f), Draw.A(BoostCols[b.kind], 0.9f), 0.06f, 0.5f, 0f, false, 0.5f, true, 1, 1, true);
                bool taken = hero != null && !hero.dead && (hero.Center - p).magnitude < 1.3f * hero.Size;
                if (taken) { ApplyBoost(b.kind); }
                if (taken || b.life <= 0f) { Destroy(b.go); boosts.RemoveAt(i); }
                else if (b.life < 3f) b.go.SetActive(Mathf.Repeat(b.life, 0.3f) > 0.12f);
            }
        }

        void ApplyBoost(int kind)
        {
            var f = hero;
            boostTaken[kind]++;
            Color c = BoostCols[kind];
            switch (kind)
            {
                case 0: f.hp = Mathf.Min(f.maxHp, f.hp + f.maxHp * 0.5f); break;
                case 1: Each(f, b => b.str *= 1.12f); break;
                case 2: Each(f, b => { b.atkSpeed = Mathf.Min(4f, b.atkSpeed * 1.1f); b.spd = Mathf.Min(2.5f, b.spd * 1.06f); }); break;
                case 3: foreach (var sp in f.B.specs) sp.power = Mathf.Min(3f, sp.power * 1.15f); Each(f, b => b.cdMul = Mathf.Max(0.35f, b.cdMul * 0.88f)); break;
                case 4: Each(f, b => b.hp *= 1.15f); f.maxHp *= 1.15f; f.hp = Mathf.Min(f.maxHp, f.hp + f.maxHp * 0.15f); break;
                case 5: f.shieldT = Mathf.Max(f.shieldT, 7f); break;
            }
            Popup("+" + BoostNames[kind], f.J[2] + Vector2.up * 1f, c, 1.1f);
            Shock(f.Center, 2f, c);
            Flash(0.06f, Draw.A(c, 0.4f));
            for (int i = 0; i < 24; i++) fx.Emit(f.Center + Random.insideUnitCircle * 0.5f, Vector2.up * Random.Range(2f, 5f) + Random.insideUnitCircle * 2f, c, 0.1f, 0.7f, 0f, false, 1f, true, 1, 1, true);
            audio.Sfx("heal", 0.9f); audio.Sfx("charge", 0.5f);
        }

        // усиление применяется и к основной сборке, и к той, в которую боец вернётся после превращения
        static void Each(Fighter f, System.Action<FighterBuild> a)
        {
            a(f.B);
            if (f.morphOrig != null && f.morphOrig != f.B) a(f.morphOrig);
        }
    }
}
