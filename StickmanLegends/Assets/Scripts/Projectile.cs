using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public class Projectile : MonoBehaviour
    {
        public enum Kind { Bullet, Arrow, Shuriken, Fireball, Ice, Bolt, Grenade }

        public Kind kind;
        public Vector2 pos, vel;
        public Fighter owner;
        public int team;
        HitInfo hit;
        float grav, life, radius, spin, angle;
        bool stuck;
        Transform vis;
        Color col;

        public void Init(Kind k, Vector2 from, Vector2 v, Fighter o, HitInfo h, Color c)
        {
            kind = k; pos = from; vel = v; owner = o; team = o.team; hit = h; col = c;
            vis = new GameObject("vis").transform;
            vis.SetParent(transform, false);
            life = 3f; radius = 0.12f;
            int ord = 300;
            switch (k)
            {
                case Kind.Bullet:
                    {
                        grav = 0f;
                        var lr = Draw.Line(vis, "tracer", 1f, new Color(1f, 0.95f, 0.6f), ord, false, 0);
                        Draw.Set(lr, new Vector2(-0.7f, 0), new Vector2(0.1f, 0));
                        Draw.Taper(lr, 0.0f, 0.07f);
                        break;
                    }
                case Kind.Arrow:
                    {
                        grav = -7f; radius = 0.14f;
                        var shaft = Draw.Line(vis, "shaft", 0.04f, new Color(0.45f, 0.3f, 0.15f), ord, false, 0);
                        Draw.Set(shaft, new Vector2(-0.7f, 0), new Vector2(0.15f, 0));
                        var tip = Draw.Line(vis, "tip", 1f, new Color(0.75f, 0.75f, 0.8f), ord + 1, false, 0);
                        Draw.Set(tip, new Vector2(0.1f, 0), new Vector2(0.3f, 0));
                        Draw.Taper(tip, 0.12f, 0f);
                        var fl = Draw.Line(vis, "fletch", 0.1f, new Color(0.9f, 0.9f, 0.9f), ord, false, 0);
                        Draw.Set(fl, new Vector2(-0.7f, 0), new Vector2(-0.5f, 0));
                        break;
                    }
                case Kind.Shuriken:
                    {
                        grav = -4f; radius = 0.16f;
                        for (int i = 0; i < 2; i++)
                        {
                            var l = Draw.Line(vis, "s", 0.06f, c, ord, false, 0);
                            float a = i * Mathf.PI / 2f + Mathf.PI / 4f;
                            Draw.Set(l, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * -0.18f, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 0.18f);
                        }
                        break;
                    }
                case Kind.Fireball:
                    {
                        grav = 0f; radius = 0.3f;
                        var g = Draw.Spr(vis, "glow", Draw.Soft, new Color(1f, 0.5f, 0.1f, 0.8f), ord);
                        g.transform.localScale = Vector3.one * 1.6f;
                        var core = Draw.Spr(vis, "core", Draw.Circle, new Color(1f, 0.85f, 0.4f), ord + 1);
                        core.transform.localScale = Vector3.one * 0.45f;
                        break;
                    }
                case Kind.Bolt:
                    {
                        grav = 0f; radius = 0.25f;
                        var g = Draw.Spr(vis, "glow", Draw.Soft, Draw.A(c, 0.8f), ord);
                        g.transform.localScale = Vector3.one * 1.3f;
                        var core = Draw.Spr(vis, "core", Draw.Circle, Color.Lerp(c, Color.white, 0.5f), ord + 1);
                        core.transform.localScale = Vector3.one * 0.32f;
                        break;
                    }
                case Kind.Ice:
                    {
                        grav = -2f; radius = 0.15f;
                        Draw.Poly(vis, new[] { new Vector2(0.3f, 0), new Vector2(0, 0.08f), new Vector2(-0.25f, 0), new Vector2(0, -0.08f) }, new Color(0.7f, 0.95f, 1f), ord, "shard");
                        var g = Draw.Spr(vis, "glow", Draw.Soft, new Color(0.5f, 0.9f, 1f, 0.5f), ord - 1);
                        g.transform.localScale = new Vector3(1f, 0.5f, 1f);
                        break;
                    }
                case Kind.Grenade:
                    {
                        grav = -18f; radius = 0.15f; life = 1.6f;
                        var b = Draw.Spr(vis, "nade", Draw.Circle, new Color(0.25f, 0.32f, 0.18f), ord);
                        b.transform.localScale = Vector3.one * 0.28f;
                        var pin = Draw.Line(vis, "pin", 0.04f, new Color(0.7f, 0.7f, 0.7f), ord, false, 0);
                        Draw.Set(pin, new Vector2(0, 0.12f), new Vector2(0.08f, 0.22f));
                        break;
                    }
            }
            Apply();
        }

        void Apply()
        {
            transform.position = pos;
            if (kind == Kind.Shuriken || kind == Kind.Grenade) vis.localRotation = Quaternion.Euler(0, 0, spin);
            else if (!stuck) { angle = Mathf.Atan2(vel.y, vel.x) * Mathf.Rad2Deg; vis.localRotation = Quaternion.Euler(0, 0, angle); }
        }

        // false = уничтожить
        public bool Tick(float dt, Battle b)
        {
            if (dt <= 0f) return true;
            life -= dt;
            if (stuck) return life > 0f;
            if (life <= 0f)
            {
                if (kind == Kind.Grenade) { b.Explosion(pos, 2.4f, hit, team); return false; }
                return false;
            }
            vel.y += grav * dt;
            Vector2 prev = pos;
            pos += vel * dt;
            spin += dt * (kind == Kind.Shuriken ? 1400f : 500f);

            switch (kind)
            {
                case Kind.Fireball: b.fx.Fire(pos, 2, 0.15f); break;
                case Kind.Bolt: if (Random.value < 0.6f) b.fx.Emit(pos, Random.insideUnitCircle, Draw.A(col, 0.7f), 0.12f, 0.3f, 0f, false, 1f, true, 1, 1, true); break;
                case Kind.Ice: if (Random.value < 0.4f) b.fx.Emit(pos, Random.insideUnitCircle * 0.5f, new Color(0.8f, 0.97f, 1f, 0.8f), 0.06f, 0.4f, -2f, false, 1f); break;
                case Kind.Grenade: if (Random.value < 0.5f) b.fx.Emit(pos, Vector2.up * 0.5f, new Color(0.6f, 0.6f, 0.6f, 0.5f), 0.12f, 0.4f, 0f, false, 1f); break;
            }

            // попадание по бойцам (проверяем отрезок пути, чтобы быстрые пули не пролетали насквозь)
            foreach (var f in b.fighters)
            {
                if (f.dead || f.team == team) continue;
                bool head;
                if (HitTest(f, prev, pos, out head))
                {
                    if (kind == Kind.Grenade) { b.Explosion(pos, 2.4f, hit, team); return false; }
                    var h = hit.Copy();
                    h.point = pos;
                    h.dir = vel.normalized;
                    h.headshot = head && (kind == Kind.Bullet || kind == Kind.Arrow);
                    if (h.headshot) b.Popup("ХЕДШОТ!", f.J[2] + Vector2.up * 0.9f, new Color(1f, 0.3f, 0.2f), 0.9f);
                    f.TakeHit(h);
                    if (kind == Kind.Fireball) { b.Explosion(pos, 1.3f, Weaker(hit), team); }
                    else if (kind == Kind.Bullet || kind == Kind.Arrow || kind == Kind.Shuriken) b.audio.Sfx("splat", 0.4f);
                    return false;
                }
            }

            if (pos.y <= 0.03f)
            {
                if (kind == Kind.Grenade)
                {
                    pos.y = 0.03f;
                    vel.y = Mathf.Abs(vel.y) * 0.4f;
                    vel.x *= 0.6f;
                    if (vel.y < 1f) vel.y = 0;
                }
                else if (kind == Kind.Arrow || kind == Kind.Shuriken)
                {
                    pos.y = 0.05f; stuck = true; life = 4f; Apply();
                    b.fx.Dust(pos, 2);
                    return true;
                }
                else
                {
                    if (kind == Kind.Fireball) b.Explosion(pos, 1.3f, Weaker(hit), team);
                    else b.fx.Sparks(pos, Vector2.up, 6, Draw.A(col, 1f));
                    return false;
                }
            }
            if (Mathf.Abs(pos.x) > b.W + 0.2f)
            {
                if (kind == Kind.Arrow || kind == Kind.Shuriken) { pos.x = Mathf.Sign(pos.x) * (b.W + 0.2f); stuck = true; life = 4f; Apply(); return true; }
                if (kind == Kind.Grenade) { vel.x = -vel.x * 0.5f; pos.x = Mathf.Sign(pos.x) * (b.W + 0.2f); }
                else
                {
                    if (kind == Kind.Fireball) b.Explosion(pos, 1.3f, Weaker(hit), team);
                    else b.fx.Sparks(pos, new Vector2(-Mathf.Sign(pos.x), 0), 6, new Color(1f, 0.9f, 0.5f));
                    return false;
                }
            }
            if (pos.y > 40f) return false;
            Apply();
            return true;
        }

        static HitInfo Weaker(HitInfo h)
        {
            var c = h.Copy();
            c.dmg *= 0.35f;
            return c;
        }

        bool HitTest(Fighter f, Vector2 a, Vector2 b, out bool head)
        {
            head = false;
            Vector2 h = f.J[2];
            float hr = Skel.HeadR * f.Size + radius;
            if (SegDist(h, a, b) < hr) { head = true; return true; }
            Vector2 bottom = f.pos + Vector2.up * 0.2f * f.Size;
            Vector2 top = f.J[1];
            float r = 0.3f * f.Size + radius;
            // расстояние между отрезком полёта и осью тела — проверяем несколько точек
            for (int i = 0; i <= 4; i++)
            {
                Vector2 p = Vector2.Lerp(a, b, i / 4f);
                if (SegDist(p, bottom, top) < r) return true;
            }
            return false;
        }

        static float SegDist(Vector2 p, Vector2 a, Vector2 b)
        {
            Vector2 ab = b - a;
            float l = ab.sqrMagnitude;
            if (l < 1e-6f) return Vector2.Distance(p, a);
            float t = Mathf.Clamp01(Vector2.Dot(p - a, ab) / l);
            return Vector2.Distance(p, a + ab * t);
        }
    }

    public class Pickup : MonoBehaviour
    {
        public WeaponStats w;
        public int ammo;
        public Vector2 pos, vel;
        public bool landed;
        bool parachute;
        Transform vis;
        LineRenderer chute;
        LineRenderer[] cords;
        SpriteRenderer glow;
        float t, spin;

        public void Init(WeaponStats ws, int am, Vector2 at, Vector2 v, bool para)
        {
            w = ws; ammo = am; pos = at; vel = v; parachute = para;
            vis = new GameObject("vis").transform;
            vis.SetParent(transform, false);
            var inner = new GameObject("inner").transform;
            inner.SetParent(vis, false);
            inner.localPosition = new Vector3(-0.45f * w.size, 0, 0);
            WeaponVisual.Build(inner, w, 1f, 250, false);
            glow = Draw.Spr(transform, "glow", Draw.Soft, new Color(1f, 0.95f, 0.6f, 0.5f), 249);
            glow.transform.localScale = new Vector3(2.2f, 1.2f, 1f);
            if (parachute)
            {
                chute = Draw.Line(transform, "chute", 0.18f, new Color(0.95f, 0.95f, 0.95f), 248, false, 3);
                var pts = new List<Vector2>();
                for (int i = 0; i <= 12; i++) { float a = Mathf.Lerp(0.15f, Mathf.PI - 0.15f, i / 12f); pts.Add(new Vector2(Mathf.Cos(a) * 1.1f, 1.6f + Mathf.Sin(a) * 0.6f)); }
                Draw.Set(chute, pts);
                cords = new LineRenderer[2];
                for (int i = 0; i < 2; i++)
                {
                    cords[i] = Draw.Line(transform, "cord", 0.02f, new Color(0.3f, 0.3f, 0.3f), 247, false, 0);
                    Draw.Set(cords[i], new Vector2(i == 0 ? -1.05f : 1.05f, 1.75f), Vector2.zero);
                }
            }
            transform.position = pos;
        }

        public void Tick(float dt, Battle b)
        {
            if (dt <= 0f) return;
            t += dt;
            if (!landed)
            {
                vel.y += (parachute ? -8f : -25f) * dt;
                if (parachute) { vel.y = Mathf.Max(vel.y, -3.2f); vel.x = Mathf.Sin(t * 1.3f) * 0.6f; }
                pos += vel * dt;
                pos.x = Mathf.Clamp(pos.x, -b.W + 0.5f, b.W - 0.5f);
                spin += dt * (parachute ? 0f : 600f);
                if (pos.y <= 0.15f)
                {
                    pos.y = 0.15f; landed = true; vel = Vector2.zero;
                    b.fx.Dust(pos, 6);
                    b.audio.Sfx("thud", 0.3f);
                    if (chute != null) { chute.enabled = false; foreach (var c in cords) c.enabled = false; }
                }
            }
            float rot = landed ? 0f : (parachute ? Mathf.Sin(t * 2f) * 12f : spin);
            vis.localRotation = Quaternion.Euler(0, 0, rot);
            if (chute != null && !landed) transform.localRotation = Quaternion.Euler(0, 0, Mathf.Sin(t * 1.3f + 1f) * 6f);
            else transform.localRotation = Quaternion.identity;
            glow.color = new Color(1f, 0.95f, 0.6f, landed ? 0.3f + 0.25f * Mathf.Sin(t * 5f) : 0.2f);
            transform.position = pos;
        }
    }
}
