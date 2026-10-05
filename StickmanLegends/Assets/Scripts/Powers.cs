using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Визуал собственных умений: молнии между точками, удар с неба, лучи, осколки статуй, отрубленные части тела
    public partial class Battle
    {
        // ломаная молния от a к b
        public void BoltBetween(Vector2 a, Vector2 b, Color col, bool dark)
        {
            var go = new GameObject("bolt");
            go.transform.SetParent(transform, false);
            Color coreC = dark ? Color.Lerp(col, Color.black, 0.55f) : Color.Lerp(col, Color.white, 0.7f);
            var glowL = Draw.Line(go.transform, "boltGlow", 0.42f, Draw.A(col, 0.45f), 344, true, 0);
            var core = Draw.Line(go.transform, "bolt", 0.1f, coreC, 345, true, 0);
            var pts = new List<Vector2>();
            int n = Mathf.Clamp((int)((b - a).magnitude * 2.2f), 4, 18);
            Vector2 d = b - a, nrm = new Vector2(-d.y, d.x).normalized;
            for (int i = 0; i <= n; i++)
            {
                float k = i / (float)n;
                pts.Add(a + d * k + (i > 0 && i < n ? nrm * Random.Range(-0.45f, 0.45f) : Vector2.zero));
            }
            Draw.Set(core, pts); Draw.Set(glowL, pts);
            // ответвления
            var branches = new List<LineRenderer>();
            for (int i = 0; i < 3; i++)
            {
                int at = Random.Range(1, Mathf.Max(2, n));
                var br = Draw.Line(go.transform, "branch", 0.05f, coreC, 345, true, 0);
                Vector2 p0 = pts[Mathf.Min(at, pts.Count - 1)];
                Draw.Set(br, new List<Vector2> { p0, p0 + Random.insideUnitCircle * 0.7f, p0 + Random.insideUnitCircle * 1.3f });
                branches.Add(br);
            }
            fx.Sparks(b, (b - a).normalized, 10, col);
            AddFx(go, 0.4f, (t, k) =>
            {
                float al = (1f - k) * (Random.value < 0.3f ? 0.35f : 1f);
                Draw.Col(core, Draw.A(coreC, al)); Draw.Col(glowL, Draw.A(col, 0.45f * al));
                foreach (var br in branches) Draw.Col(br, Draw.A(coreC, al));
            });
        }

        // столб силы с неба (огонь/молния/свет — цвет умения)
        public void ColumnStrike(Vector2 at, Color col, bool dark)
        {
            var go = new GameObject("column");
            go.transform.SetParent(transform, false);
            var glowL = Draw.Line(go.transform, "colGlow", 2.2f, Draw.A(col, 0.4f), 343, true, 0);
            var core = Draw.Line(go.transform, "col", 0.8f, dark ? Color.Lerp(col, Color.black, 0.5f) : Color.Lerp(col, Color.white, 0.6f), 344, true, 0);
            Draw.Set(glowL, new Vector2(at.x, 18f), new Vector2(at.x, 0f));
            Draw.Set(core, new Vector2(at.x, 18f), new Vector2(at.x, 0f));
            Shock(new Vector2(at.x, 0.05f), 2.4f, col);
            Crack(new Vector2(at.x, 0f), false);
            for (int i = 0; i < 26; i++) fx.Emit(new Vector2(at.x, 0.1f), new Vector2(Random.Range(-6f, 6f), Random.Range(2f, 9f)), col, Random.Range(0.08f, 0.2f), 0.7f, -14f, false, 1f, true, 1, 1, true);
            cam.Shake(0.5f);
            AddFx(go, 0.45f, (t, k) =>
            {
                float w = 1f - k;
                glowL.widthMultiplier = 2.2f * w; core.widthMultiplier = 0.8f * w;
            });
        }

        // луч
        public void BeamVisual(Vector2 a, Vector2 b, Color col, bool dark)
        {
            var go = new GameObject("beam");
            go.transform.SetParent(transform, false);
            var glowL = Draw.Line(go.transform, "beamGlow", 0.9f, Draw.A(col, 0.45f), 343, true, 2);
            var core = Draw.Line(go.transform, "beam", 0.28f, dark ? Color.Lerp(col, Color.black, 0.5f) : Color.Lerp(col, Color.white, 0.7f), 344, true, 2);
            Draw.Set(glowL, a, b); Draw.Set(core, a, b);
            AddFx(go, 0.35f, (t, k) => { glowL.widthMultiplier = 0.9f * (1f - k); core.widthMultiplier = 0.28f * (1f - k); });
        }

        // статуя рассыпается: каменные осколки и пыль
        public void StoneShatter(Vector2 at, float size)
        {
            for (int i = 0; i < 40; i++)
            {
                float g = Random.Range(0.4f, 0.65f);
                fx.Emit(at + Random.insideUnitCircle * 0.6f * size, Random.insideUnitCircle * 7f + Vector2.up * 4f, new Color(g, g * 0.97f, g * 0.92f), Random.Range(0.08f, 0.22f) * size, Random.Range(1.2f, 2.2f), -22f, false, 0.3f, false);
            }
            fx.Smoke(at, 18, new Color(0.6f, 0.58f, 0.55f, 0.6f), 0.6f * size, 0.7f);
            audio.Sfx("crunch", 1f);
            audio.Sfx("heavy", 0.7f);
            cam.Shake(0.4f);
        }

        // отрубленная часть тела летит, кувыркаясь, оставляя кровь, и остаётся на земле
        public void SeverLimb(Vector2 a, Vector2 b, float width, Color c, Vector2 v)
        {
            var go = new GameObject("limb");
            go.transform.SetParent(transform, false);
            var l = Draw.Line(go.transform, "limb", width, c, 60, true, 4);
            Vector2 mid = (a + b) * 0.5f;
            float half = (b - a).magnitude * 0.5f;
            float ang = Mathf.Atan2(b.y - a.y, b.x - a.x);
            float spin = Random.Range(-14f, 14f);
            Vector2 pos = mid, vel = v;
            bool landed = false;
            Popup("ОТРУБЛЕНО!", mid + Vector2.up * 0.6f, new Color(1f, 0.25f, 0.2f), 0.8f);
            AddFx(go, 9f, (t, k) =>
            {
                float dt = Time.deltaTime * (Frozen ? 0f : 1f);
                if (!landed)
                {
                    vel.y -= 25f * dt; pos += vel * dt; ang += spin * dt;
                    if (Random.value < 0.5f) fx.Drip(pos);
                    if (pos.y <= width * 0.5f) { pos.y = width * 0.5f; landed = true; fx.Blood(pos, Vector2.up, 6); fx.Pool(pos, 0.6f); }
                    if (Mathf.Abs(pos.x) > W) { vel.x = -vel.x * 0.4f; pos.x = Mathf.Sign(pos.x) * W; }
                }
                Vector2 d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * half;
                if (landed) d.y *= 0.15f;
                Draw.Set(l, pos - d, pos + d);
                Draw.Col(l, Draw.A(c, k > 0.85f ? (1f - k) / 0.15f : 1f));
            });
        }

        public Fighter SpawnAt(FighterBuild b, int team, int slot, Vector2 p, int face) { return Spawn(b, team, slot, p, face); }

        // изменения состава бойцов посреди перебора списка откладываем до конца кадра
        readonly List<System.Action> deferred = new List<System.Action>();
        public void Defer(System.Action a) { deferred.Add(a); }
        void RunDeferred()
        {
            for (int i = 0; i < deferred.Count && i < 64; i++) deferred[i]();
            deferred.Clear();
        }

        // чёрная дыра / вихрь: затягивает врагов, крутит, бьёт, в конце — выброс
        public void BlackHole(Vector2 at, Fighter caster, Color col, float dur, float dmg, bool lethal, bool tornado)
        {
            var go = new GameObject("blackhole");
            go.transform.SetParent(transform, false);
            var core = Draw.Spr(go.transform, "core", Draw.Circle, tornado ? Draw.A(col, 0.5f) : new Color(0.02f, 0f, 0.03f), 330);
            var halo = Draw.Spr(go.transform, "halo", Draw.Soft, Draw.A(col, 0.7f), 329);
            core.transform.position = at; halo.transform.position = at;
            var rings = new List<LineRenderer>();
            for (int i = 0; i < 3; i++)
            {
                var l = Draw.Line(go.transform, "ring", 0.06f, Draw.A(Color.Lerp(col, Color.white, 0.3f), 0.8f), 331, true, 0);
                l.positionCount = 24; l.loop = true; rings.Add(l);
            }
            float tick = 0f;
            audio.Sfx("charge", 0.9f); audio.Sfx("cine", 0.6f, 0f);
            Popup(tornado ? "ВИХРЬ!" : "ЧЁРНАЯ ДЫРА!", at + Vector2.up * 1.5f, Color.Lerp(col, Color.white, 0.4f), 1.1f);
            AddFx(go, dur, (t, k) =>
            {
                float grow = Mathf.Min(1f, t * 3f) * (k > 0.9f ? (1f - k) / 0.1f : 1f);
                float r = (tornado ? 1.6f : 1.1f) * grow;
                core.transform.localScale = tornado ? new Vector3(r * 1.2f, r * 3f, 1f) : Vector3.one * r * 1.6f;
                halo.transform.localScale = Vector3.one * r * 5f;
                for (int i = 0; i < rings.Count; i++)
                {
                    float rr = r * (1.4f + i * 0.55f), sp = t * (6f + i * 3f);
                    for (int j = 0; j < 24; j++)
                    {
                        float a = j / 24f * Mathf.PI * 2f + sp;
                        rings[i].SetPosition(j, at + new Vector2(Mathf.Cos(a) * rr, Mathf.Sin(a) * rr * (tornado ? 2.2f : 0.45f)));
                    }
                }
                if (Random.value < 0.6f)
                {
                    Vector2 from = at + Random.insideUnitCircle.normalized * Random.Range(2.5f, 5f);
                    fx.Emit(from, (at - from) * 2.5f, Draw.A(col, 0.9f), 0.08f, 0.4f, 0f, false, 0f, true, 1, 1, true);
                }
                float dt = Time.deltaTime * (Frozen ? 0f : 1f);
                tick -= dt;
                bool hit = tick <= 0f;
                if (hit) tick = 0.35f;
                foreach (var e in fighters)
                {
                    if (caster == null || e.dead || e.team == caster.team) continue;
                    Vector2 d = at - e.Center;
                    float dist = d.magnitude;
                    if (dist > 6.5f) continue;
                    e.vel = Vector2.Lerp(e.vel, d.normalized * Mathf.Lerp(14f, 5f, dist / 6.5f) + Vector2.up * (tornado ? 6f : 1.5f), dt * 5f);
                    e.grounded = false;
                    if (hit && dist < 2.2f)
                    {
                        var h = new HitInfo { dmg = dmg * 0.25f, type = DmgType.Shadow, elem = Element.Shadow, attacker = caster, dir = Random.insideUnitCircle.normalized, point = e.Center, knock = 1f, stun = 0.3f, blast = true };
                        h.extra |= HF.Magic | HF.Custom;
                        h.customTag = caster.B.customAbilityTag;
                        e.TakeHit(h);
                    }
                }
                if (k >= 0.98f && go.activeSelf)
                {
                    go.SetActive(false);
                    Shock(at, 4f, col);
                    fx.Explosion(at, 1.2f);
                    cam.Shake(0.7f);
                    audio.Sfx("explosion", 0.9f);
                    foreach (var e in fighters)
                    {
                        if (caster == null || e.dead || e.team == caster.team || (e.Center - at).magnitude > 4f) continue;
                        var h = new HitInfo { dmg = lethal ? dmg * 2.5f : dmg, type = DmgType.Blunt, attacker = caster, dir = (e.Center - at).normalized + Vector2.up * 0.5f, point = e.Center, knock = 12f, stun = 0.5f, knockdown = true, heavy = true, blast = true };
                        h.extra |= HF.Magic | HF.Custom | HF.Explosion;
                        e.TakeHit(h);
                    }
                }
            });
        }

        // эпичный момент умения: замедление, вспышка, облёт камеры в 3D
        public void PowerMoment(Fighter f, string name, Color col, bool desperate)
        {
            if (mode == Mode.Showroom) return;
            SlowMo(desperate ? 0.9f : 0.5f);
            Flash(0.09f, Draw.A(col, 0.55f));
            audio.Sfx("cine", 0.8f, 0f);
            // кат-ин во весь экран вместо обычной надписи
            cutInT = cutInMax = desperate ? 1.15f : 0.9f;
            cutInName = f.B.name; cutInAb = name; cutInCol = col; cutInRight = f.team == 1; cutInDesp = desperate;
            cutInBody = f.B.color;
            MagicCircle(new Vector2(f.pos.x, 0.03f), col, desperate ? 2.6f : 1.9f);
            if (!c3d && (desperate || c3dCooldown <= 0f))
            {
                float side = Random.value < 0.5f ? -1f : 1f;
                Cinematic3D(f.Center, desperate ? 1.5f : 1.0f, side * 50f, side * 15f, 6.5f, 4.2f);
            }
        }
    
        // кат-ин (рисует GameUI)
        public float cutInT, cutInMax;
        public string cutInName, cutInAb;
        public Color cutInCol, cutInBody;
        public bool cutInRight, cutInDesp;

        // магический круг на земле под кастующим: кольца, руны, звезда — плоский, вращается
        public void MagicCircle(Vector2 at, Color col, float r)
        {
            var go = new GameObject("magicCircle");
            go.transform.SetParent(transform, false);
            var lines = new List<LineRenderer>();
            var c1 = Draw.Line(go.transform, "c1", 0.06f, Draw.A(col, 0.9f), -2, true, 0); c1.positionCount = 40; c1.loop = true; lines.Add(c1);
            var c2 = Draw.Line(go.transform, "c2", 0.04f, Draw.A(Color.Lerp(col, Color.white, 0.4f), 0.9f), -2, true, 0); c2.positionCount = 40; c2.loop = true; lines.Add(c2);
            var star = Draw.Line(go.transform, "star", 0.04f, Draw.A(col, 0.85f), -2, true, 0); star.positionCount = 5; star.loop = true; lines.Add(star);
            var runes = new List<LineRenderer>();
            for (int i = 0; i < 10; i++) { var rl = Draw.Line(go.transform, "rune", 0.035f, Draw.A(Color.Lerp(col, Color.white, 0.6f), 0.9f), -2, true, 0); rl.positionCount = 3; runes.Add(rl); }
            var glowS = Draw.Spr(go.transform, "glow", Draw.Soft, Draw.A(col, 0.5f), -3);
            glowS.transform.position = at; glowS.transform.localScale = new Vector3(r * 3.2f, r * 0.9f, 1f);
            const float flat = 0.28f;
            AddFx(go, 1.1f, (t, k) =>
            {
                float grow = Mathf.Min(1f, t * 6f), fade = k > 0.7f ? (1f - k) / 0.3f : 1f;
                float rr = r * grow, rot = t * 2.2f;
                for (int i = 0; i < 40; i++)
                {
                    float a = i / 40f * Mathf.PI * 2f;
                    c1.SetPosition(i, at + new Vector2(Mathf.Cos(a) * rr, Mathf.Sin(a) * rr * flat));
                    c2.SetPosition(i, at + new Vector2(Mathf.Cos(a) * rr * 0.72f, Mathf.Sin(a) * rr * 0.72f * flat));
                }
                for (int i = 0; i < 5; i++)
                {
                    float a = rot + (i * 2 % 5) * Mathf.PI * 2f / 5f + Mathf.PI / 2f;   // пентаграмма
                    star.SetPosition(i, at + new Vector2(Mathf.Cos(a) * rr * 0.7f, Mathf.Sin(a) * rr * 0.7f * flat));
                }
                for (int i = 0; i < runes.Count; i++)
                {
                    float a = -rot * 1.5f + i * Mathf.PI * 2f / runes.Count;
                    Vector2 p0 = at + new Vector2(Mathf.Cos(a) * rr * 0.86f, Mathf.Sin(a) * rr * 0.86f * flat);
                    Vector2 tg = new Vector2(-Mathf.Sin(a), Mathf.Cos(a) * flat) * 0.12f * r;
                    runes[i].SetPosition(0, p0 - tg); runes[i].SetPosition(1, p0 + new Vector2(0, 0.08f * r)); runes[i].SetPosition(2, p0 + tg);
                }
                foreach (var l in lines) Draw.Col(l, Draw.A(l == c2 ? Color.Lerp(col, Color.white, 0.4f) : col, 0.9f * fade));
                foreach (var l in runes) Draw.Col(l, Draw.A(Color.Lerp(col, Color.white, 0.6f), 0.9f * fade));
                glowS.color = Draw.A(col, 0.5f * fade);
                if (Random.value < 0.5f) fx.Emit(at + new Vector2(Random.Range(-rr, rr), 0.05f), Vector2.up * Random.Range(1.5f, 4f), Draw.A(col, 0.9f), 0.07f, 0.6f, 0f, false, 0.5f, true, 1, 1, true);
            });
        }
    }
}
