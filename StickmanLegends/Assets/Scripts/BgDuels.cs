using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // На заднем плане тоже дерутся: пары силуэтов-стикменов бьют друг друга, падают и встают
    public partial class Battle
    {
        class BgFig
        {
            public LineRenderer body, legA, legB, armA, armB;
            public SpriteRenderer head;
            public int state; // 0 стойка, 1 удар рукой, 2 удар ногой, 3 получил, 4 лежит, 5 встаёт, 6 блок
            public float t, x, slide;
            public int face;
        }

        class BgPair { public BgFig a, b; public float x, y, scale, next; }

        readonly List<BgPair> duels = new List<BgPair>();
        Transform duelRoot;

        void BuildDuels(int pairs)
        {
            ClearDuels();
            if (pairs <= 0) return;
            duelRoot = new GameObject("BgDuels").transform;
            duelRoot.SetParent(transform, false);
            for (int i = 0; i < pairs; i++)
            {
                var p = new BgPair();
                p.scale = Random.Range(0.32f, 0.5f);
                p.x = Mathf.Lerp(-26f, 26f, (i + Random.Range(0.2f, 0.8f)) / pairs);
                p.y = Mathf.Lerp(1.8f, 0.7f, (p.scale - 0.32f) / 0.18f);
                p.next = Random.Range(0.3f, 1.2f);
                p.a = NewFig(p.scale, 1); p.b = NewFig(p.scale, -1);
                p.a.x = p.x - 0.55f * p.scale * 2f; p.b.x = p.x + 0.55f * p.scale * 2f;
                duels.Add(p);
            }
        }

        void ClearDuels()
        {
            if (duelRoot != null) Destroy(duelRoot.gameObject);
            duelRoot = null;
            duels.Clear();
        }

        BgFig NewFig(float scale, int face)
        {
            var f = new BgFig { face = face };
            Color c = DuelColor(scale);
            float w = 0.2f * scale * 1.6f;
            int o = -46 + (int)(scale * 6f);
            f.body = Draw.Line(duelRoot, "db", w * 1.15f, c, o, false, 2);
            f.legA = Draw.Line(duelRoot, "dl", w, c, o, false, 2); f.legA.positionCount = 3;
            f.legB = Draw.Line(duelRoot, "dl", w, c, o, false, 2); f.legB.positionCount = 3;
            f.armA = Draw.Line(duelRoot, "da", w * 0.85f, c, o, false, 2); f.armA.positionCount = 3;
            f.armB = Draw.Line(duelRoot, "da", w * 0.85f, c, o, false, 2); f.armB.positionCount = 3;
            f.head = Draw.Spr(duelRoot, "dh", Draw.Circle, c, o);
            f.head.transform.localScale = Vector3.one * 0.6f * scale;
            return f;
        }

        Color DuelColor(float scale)
        {
            Color bg = cam.cam.backgroundColor;
            return Color.Lerp(new Color(0.03f, 0.02f, 0.04f), bg, Mathf.Lerp(0.5f, 0.15f, (scale - 0.32f) / 0.18f));
        }

        void DuelsTick(float dt)
        {
            if (duelRoot == null) return;
            bool show = (mode == Mode.Fight || mode == Mode.Survival) && !c3d && curStyle != 3;
            duelRoot.gameObject.SetActive(show);
            if (!show || dt <= 0f) return;
            var cp = cam.cam.transform.position;
            duelRoot.position = new Vector3(cp.x * 0.55f, cp.y * 0.35f, 0);
            foreach (var p in duels)
            {
                p.next -= dt;
                if (p.next <= 0f && p.a.state == 0 && p.b.state == 0)
                {
                    // кто-то атакует
                    bool aAtk = Random.value < 0.5f;
                    var atk = aAtk ? p.a : p.b;
                    atk.state = Random.value < 0.6f ? 1 : 2; atk.t = 0f;
                    p.next = Random.Range(0.35f, 1.1f) / Tempo;
                }
                Step(p, p.a, p.b, dt);
                Step(p, p.b, p.a, dt);
                // держим дистанцию
                float gap = p.b.x - p.a.x, want = 1.2f * p.scale * 2f;
                if (p.a.state <= 2 && p.b.state <= 2) { p.a.x += (gap - want) * dt * 1.5f; p.b.x -= (gap - want) * dt * 1.5f; }
                Pose(p, p.a); Pose(p, p.b);
            }
        }

        void Step(BgPair p, BgFig f, BgFig other, float dt)
        {
            f.t += dt * Tempo;
            f.x += f.slide * dt; f.slide = Mathf.MoveTowards(f.slide, 0f, dt * 8f);
            switch (f.state)
            {
                case 1:
                case 2:
                    if (f.t >= 0.12f && f.t - dt * Tempo < 0.12f)
                    {
                        // попадание
                        if (Random.value < 0.25f) { other.state = 6; other.t = 0f; other.slide = -other.face * 1.2f * p.scale * 2f; }
                        else
                        {
                            bool down = Random.value < 0.22f;
                            other.state = down ? 4 : 3; other.t = 0f; other.slide = -other.face * (down ? 3.5f : 2f) * p.scale * 2f;
                            Vector2 at = duelRoot.TransformPoint(new Vector2(other.x - other.face * 0.1f, p.y + 1.2f * p.scale * 2f));
                            for (int i = 0; i < 4; i++) fx.Emit(at, Random.insideUnitCircle * 2f, Draw.A(theme.ink, 0.7f), 0.05f, 0.15f, 0f, false, 2f, true, 1, 1, true);
                        }
                    }
                    if (f.t > 0.32f) { f.state = 0; f.t = 0f; }
                    break;
                case 3: case 6: if (f.t > 0.3f) { f.state = 0; f.t = 0f; } break;
                case 4: if (f.t > 1.4f) { f.state = 5; f.t = 0f; } break;
                case 5: if (f.t > 0.45f) { f.state = 0; f.t = 0f; } break;
            }
        }

        void Pose(BgPair p, BgFig f)
        {
            float s = p.scale * 2f, d = f.face, t = f.t;
            float bob = Mathf.Sin(Time.time * 6f + f.x) * 0.03f * s;
            Vector2 hip = new Vector2(f.x, p.y + 0.62f * s + bob);
            Vector2 neck, kA, fA, kB, fB, eA, hA, eB, hB;
            if (f.state == 4 || (f.state == 5 && t < 0.2f))
            {
                // лежит
                hip = new Vector2(f.x, p.y + 0.12f * s);
                neck = hip + new Vector2(-d * 0.85f * s, 0.05f * s);
                kA = hip + new Vector2(d * 0.35f * s, 0.15f * s); fA = kA + new Vector2(d * 0.35f * s, -0.12f * s);
                kB = hip + new Vector2(d * 0.4f * s, 0.02f * s); fB = kB + new Vector2(d * 0.3f * s, 0f);
                eA = neck + new Vector2(d * 0.2f * s, 0.25f * s); hA = eA + new Vector2(d * 0.25f * s, 0.05f * s);
                eB = neck + new Vector2(-d * 0.2f * s, -0.05f * s); hB = eB + new Vector2(-d * 0.2f * s, 0f);
            }
            else
            {
                float lean = f.state == 1 ? 0.25f : f.state == 2 ? -0.25f : f.state == 3 ? -0.45f : f.state == 5 ? 0.35f : f.state == 6 ? -0.15f : 0.08f;
                if (f.state == 5) hip.y -= (0.45f - t) * 0.6f * s;
                neck = hip + new Vector2(d * lean * s, 0.9f * s);
                kA = hip + new Vector2(d * 0.22f * s, -0.32f * s); fA = kA + new Vector2(d * 0.1f * s, -0.32f * s);
                kB = hip + new Vector2(-d * 0.22f * s, -0.32f * s); fB = kB + new Vector2(-d * 0.12f * s, -0.32f * s);
                eA = neck + new Vector2(d * 0.25f * s, -0.25f * s); hA = eA + new Vector2(d * 0.1f * s, 0.25f * s);
                eB = neck + new Vector2(d * 0.05f * s, -0.32f * s); hB = eB + new Vector2(d * 0.2f * s, 0.18f * s);
                if (f.state == 1)
                {
                    float k = Mathf.Clamp01(t / 0.12f) * (t < 0.2f ? 1f : Mathf.Clamp01((0.32f - t) / 0.12f));
                    eA = neck + new Vector2(d * (0.25f + 0.25f * k) * s, -0.1f * s); hA = eA + new Vector2(d * (0.1f + 0.35f * k) * s, 0.05f * s);
                }
                else if (f.state == 2)
                {
                    float k = Mathf.Clamp01(t / 0.12f) * (t < 0.2f ? 1f : Mathf.Clamp01((0.32f - t) / 0.12f));
                    kA = hip + new Vector2(d * (0.22f + 0.25f * k) * s, (-0.32f + 0.35f * k) * s); fA = kA + new Vector2(d * (0.1f + 0.3f * k) * s, (-0.32f + 0.35f * k) * s);
                }
                else if (f.state == 3)
                {
                    eA = neck + new Vector2(-d * 0.2f * s, 0.1f * s); hA = eA + new Vector2(-d * 0.2f * s, 0.2f * s);
                }
                else if (f.state == 6)
                {
                    eA = neck + new Vector2(d * 0.25f * s, -0.05f * s); hA = eA + new Vector2(-d * 0.02f * s, 0.3f * s);
                }
            }
            Draw.Set(f.body, hip, neck);
            f.head.transform.localPosition = neck + (neck - hip).normalized * 0.32f * s;
            f.legA.SetPosition(0, hip); f.legA.SetPosition(1, kA); f.legA.SetPosition(2, fA);
            f.legB.SetPosition(0, hip); f.legB.SetPosition(1, kB); f.legB.SetPosition(2, fB);
            Vector2 sh = Vector2.Lerp(hip, neck, 0.9f);
            f.armA.SetPosition(0, sh); f.armA.SetPosition(1, eA); f.armA.SetPosition(2, hA);
            f.armB.SetPosition(0, sh); f.armB.SetPosition(1, eB); f.armB.SetPosition(2, hB);
        }
    }
}
