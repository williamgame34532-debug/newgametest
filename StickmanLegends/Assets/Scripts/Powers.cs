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

        // эпичный момент умения: замедление, вспышка, облёт камеры в 3D
        public void PowerMoment(Fighter f, string name, Color col, bool desperate)
        {
            if (mode == Mode.Showroom) return;
            SlowMo(desperate ? 0.9f : 0.5f);
            Flash(0.09f, Draw.A(col, 0.55f));
            audio.Sfx("cine", 0.8f, 0f);
            Announce((desperate ? "⚡ " : "") + name.ToUpper() + "!", Color.Lerp(col, Color.white, 0.35f), 1.2f);
            if (!c3d && (desperate || c3dCooldown <= 0f))
            {
                float side = Random.value < 0.5f ? -1f : 1f;
                Cinematic3D(f.Center, desperate ? 1.5f : 1.0f, side * 50f, side * 15f, 6.5f, 4.2f);
            }
        }
    }
}
