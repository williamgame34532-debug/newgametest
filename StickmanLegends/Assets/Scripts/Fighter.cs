using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public class Fighter : MonoBehaviour
    {
        public FighterBuild B;
        public int team, slot;
        public Battle battle;
        public bool human;
        public int pindex;

        public Vector2 pos, vel;
        public int facing = 1;
        public bool grounded = true;
        public float hp, maxHp;
        public bool dead;
        public float deadTime;
        public WeaponStats weapon;
        public int ammo;
        public readonly Vector2[] J = new Vector2[11];
        public int kills;
        public float dmgDealt;

        public enum Act { None, Punch, Kick, Slash, Stab, Smash, Shoot, Throw, Cast, Block, Dash, Saw, Laser }
        public Act act;
        float actT, actDur;
        bool actFired, alt;
        Ability castAb;
        bool castFromStaff;
        float staffCd;
        float atkCd, stun, hurtT, flash;
        readonly Dictionary<Ability, float> cd = new Dictionary<Ability, float>();
        int jumps;
        public float shieldT, invisT, burnT, poisonT, slowT, bleedT, regenBlock;
        Fighter burnBy, poisonBy, bleedBy;
        bool slamPending;
        public bool tkSlam;
        Fighter tkBy;
        float animT, runPhase;
        Pose cur = Pose.Guard;
        Fighter target;
        float think, aiMove, dodgeT, demoT;
        int demoStep;
        Pickup pickupTarget;
        public Ragdoll rag;
        float fountainT, dripT, sawTick, laserTick, ghostT, fxT;
        bool pooled, headPooled;
        Vector2 aim = Vector2.right;
        readonly List<Fighter> dashHit = new List<Fighter>();
        float dotAcc;

        // --- визуал ---
        LineRenderer lTorso, lArmF, lArmB, lLegF, lLegB, lCape, lTails, lScarf, lShield, lLaser, lLaserGlow;
        LineRenderer[] glowLines;
        SpriteRenderer sHead, sHeadGlow, sShieldGlow;
        Transform headRoot, weaponRoot;
        readonly List<Renderer> headRends = new List<Renderer>();
        List<Renderer> weaponRends = new List<Renderer>();
        int baseOrder;
        bool glow;
        Color backCol, mainCol;

        public float Size { get { return B.size; } }
        public Vector2 Center { get { return dead && rag != null ? (rag.p[0] + rag.p[1]) * 0.5f : (J[0] + J[1]) * 0.5f; } }
        public Vector2 HeadPos { get { return dead && rag != null ? rag.p[2] : J[2]; } }
        public bool Invisible { get { return invisT > 0; } }
        public bool RageOn { get { return B.HasAb(Ability.Rage) && hp < maxHp * 0.45f; } }
        public bool Free { get { return act == Act.None && stun <= 0 && hurtT <= 0 && !dead; } }
        public bool WindingUp
        {
            get
            {
                if (act == Act.None || act == Act.Block || act == Act.Cast || act == Act.Shoot) return false;
                return actT / actDur < 0.45f;
            }
        }
        public float CooldownOf(Ability a) { float v; return cd.TryGetValue(a, out v) ? Mathf.Max(0, v) : 0; }

        // ===================== СОЗДАНИЕ =====================
        public void Init(FighterBuild b, int team, int slot, Vector2 start, int face, Battle battle, bool glow)
        {
            B = b; this.team = team; this.slot = slot; this.battle = battle; this.glow = glow;
            hp = maxHp = b.hp;
            pos = start; facing = face;
            foreach (var a in b.abilities) cd[a] = Random.Range(0.5f, 2f);
            jumps = b.HasAb(Ability.DoubleJump) ? 1 : 0;
            Skel.Compute(cur, pos, Size, facing, J);
            baseOrder = 100 + (team * 5 + slot) * 14;
            BuildVisual();
            SetWeapon(b.weapon != null ? b.weapon.Copy() : null, b.weapon != null ? b.weapon.ammo : 0);
            Render();
        }

        void BuildVisual()
        {
            float s = Size;
            float w = Skel.Width * s;
            mainCol = B.color;
            float lum = mainCol.r * 0.3f + mainCol.g * 0.59f + mainCol.b * 0.11f;
            backCol = lum < 0.15f ? Color.Lerp(mainCol, new Color(0.45f, 0.45f, 0.47f), 0.45f) : Color.Lerp(mainCol, Color.black, 0.3f);

            lLegB = Draw.Line(transform, "legB", w, backCol, baseOrder + 0, true, 6);
            lArmB = Draw.Line(transform, "armB", w, backCol, baseOrder + 1, true, 6);
            lTorso = Draw.Line(transform, "torso", w * 1.05f, mainCol, baseOrder + 3, true, 6);
            lLegF = Draw.Line(transform, "legF", w, mainCol, baseOrder + 5, true, 6);
            lArmF = Draw.Line(transform, "armF", w, mainCol, baseOrder + 8, true, 6);
            sHead = Draw.Spr(transform, "head", Draw.Circle, mainCol, baseOrder + 4);
            sHead.transform.localScale = Vector3.one * Skel.HeadR * 2f * s;

            if (glow)
            {
                glowLines = new LineRenderer[5];
                for (int i = 0; i < 5; i++)
                {
                    glowLines[i] = Draw.Line(transform, "glow", w * 2.8f, Draw.A(Color.Lerp(mainCol, Color.white, 0.3f), 0.22f), baseOrder - 1, true, 6);
                    glowLines[i].positionCount = 3;
                }
                sHeadGlow = Draw.Spr(transform, "headGlow", Draw.Soft, Draw.A(mainCol, 0.5f), baseOrder - 1);
                sHeadGlow.transform.localScale = Vector3.one * Skel.HeadR * 5f * s;
            }

            headRoot = new GameObject("headRoot").transform;
            headRoot.SetParent(transform, false);
            weaponRoot = new GameObject("weaponRoot").transform;
            weaponRoot.SetParent(transform, false);

            BuildAccessories();

            lShield = Draw.Line(transform, "shield", 0.06f, new Color(0.4f, 0.9f, 1f, 0.8f), baseOrder + 12, true, 0);
            lShield.loop = true;
            lShield.positionCount = 24;
            lShield.enabled = false;
            sShieldGlow = Draw.Spr(transform, "shieldGlow", Draw.Soft, new Color(0.4f, 0.9f, 1f, 0.2f), baseOrder + 11);
            sShieldGlow.enabled = false;

            lLaserGlow = Draw.Line(transform, "laserGlow", 0.45f, new Color(1f, 0.1f, 0.1f, 0.35f), 340, true, 2);
            lLaser = Draw.Line(transform, "laser", 0.12f, new Color(1f, 0.9f, 0.9f, 1f), 341, true, 2);
            lLaser.enabled = lLaserGlow.enabled = false;
        }

        void BuildAccessories()
        {
            float s = Size;
            int o = baseOrder + 6;
            Color contrast = (mainCol.r + mainCol.g + mainCol.b) < 0.9f ? new Color(0.9f, 0.1f, 0.1f) : new Color(0.12f, 0.12f, 0.14f);
            if (B.color.r > 0.6f && B.color.g < 0.3f && B.color.b < 0.3f) contrast = new Color(0.1f, 0.1f, 0.12f);
            float hr = Skel.HeadR * s;

            foreach (var a in B.acc)
            {
                switch (a)
                {
                    case Acc.Headband:
                        {
                            var band = Draw.Line(headRoot, "band", 0.08f * s, contrast, o, false, 2);
                            Draw.Set(band, new Vector2(-hr * 1.02f, hr * 0.25f), new Vector2(hr * 1.02f, hr * 0.25f));
                            headRends.Add(band);
                            lTails = Draw.Line(transform, "tails", 1f, contrast, baseOrder + 2, true, 2);
                            Draw.Taper(lTails, 0.08f * s, 0.03f * s);
                            lTails.positionCount = 4;
                            break;
                        }
                    case Acc.WizardHat:
                        {
                            Color hc = new Color(0.25f, 0.12f, 0.45f);
                            headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(-hr * 1.7f, hr * 0.55f), new Vector2(hr * 1.7f, hr * 0.55f), new Vector2(hr * 1.7f, hr * 0.8f), new Vector2(-hr * 1.7f, hr * 0.8f) }, hc, o, "brim"));
                            headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(-hr * 1f, hr * 0.7f), new Vector2(hr * 1f, hr * 0.7f), new Vector2(-hr * 0.7f, hr * 3.2f) }, hc, o, "cone"));
                            var star = Draw.Spr(headRoot, "star", Draw.Circle, new Color(1f, 0.85f, 0.2f), o + 1);
                            star.transform.localPosition = new Vector3(0, hr * 1.4f, 0); star.transform.localScale = Vector3.one * hr * 0.5f;
                            headRends.Add(star);
                            break;
                        }
                    case Acc.CowboyHat:
                        {
                            Color hc = new Color(0.45f, 0.28f, 0.12f);
                            var brim = Draw.Line(headRoot, "brim", 0.09f * s, hc, o, false, 3);
                            Draw.Set(brim, new List<Vector2> { new Vector2(-hr * 1.9f, hr * 0.95f), new Vector2(0, hr * 0.75f), new Vector2(hr * 1.9f, hr * 0.95f) });
                            headRends.Add(brim);
                            headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(-hr * 0.95f, hr * 0.8f), new Vector2(hr * 0.95f, hr * 0.8f), new Vector2(hr * 0.75f, hr * 1.9f), new Vector2(-hr * 0.75f, hr * 1.9f) }, hc, o, "crown"));
                            break;
                        }
                    case Acc.Horns:
                        {
                            Color hc = new Color(0.92f, 0.88f, 0.78f);
                            var h1 = Draw.Line(headRoot, "horn1", 1f, hc, o, false, 2);
                            Draw.Set(h1, new List<Vector2> { new Vector2(hr * 0.5f, hr * 0.7f), new Vector2(hr * 1.1f, hr * 1.4f), new Vector2(hr * 0.9f, hr * 2.0f) });
                            Draw.Taper(h1, 0.13f * s, 0.01f);
                            var h2 = Draw.Line(headRoot, "horn2", 1f, Draw.Mul(hc, 0.8f), baseOrder + 2, false, 2);
                            Draw.Set(h2, new List<Vector2> { new Vector2(-hr * 0.4f, hr * 0.75f), new Vector2(-hr * 1.0f, hr * 1.4f), new Vector2(-hr * 1.4f, hr * 1.9f) });
                            Draw.Taper(h2, 0.13f * s, 0.01f);
                            headRends.Add(h1); headRends.Add(h2);
                            break;
                        }
                    case Acc.Crown:
                        {
                            Color gc = new Color(1f, 0.8f, 0.15f);
                            headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(-hr * 0.85f, hr * 0.7f), new Vector2(hr * 0.85f, hr * 0.7f), new Vector2(hr * 0.85f, hr * 1.05f), new Vector2(-hr * 0.85f, hr * 1.05f) }, gc, o, "crownBase"));
                            for (int i = -1; i <= 1; i++)
                                headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(hr * (i * 0.6f - 0.3f), hr * 1.0f), new Vector2(hr * (i * 0.6f + 0.3f), hr * 1.0f), new Vector2(hr * i * 0.62f, hr * 1.65f) }, gc, o, "crownTip"));
                            break;
                        }
                    case Acc.Halo:
                        {
                            var h = Draw.Line(headRoot, "halo", 0.05f * s, new Color(1f, 0.9f, 0.4f), o, false, 0);
                            h.loop = true;
                            var pts = new List<Vector2>();
                            for (int i = 0; i < 20; i++) { float ang = i / 20f * Mathf.PI * 2; pts.Add(new Vector2(Mathf.Cos(ang) * hr * 1.1f, hr * 1.9f + Mathf.Sin(ang) * hr * 0.3f)); }
                            Draw.Set(h, pts);
                            var g = Draw.Spr(headRoot, "haloGlow", Draw.Soft, new Color(1f, 0.9f, 0.4f, 0.5f), o - 1);
                            g.transform.localPosition = new Vector3(0, hr * 1.9f, 0); g.transform.localScale = new Vector3(hr * 4f, hr * 1.6f, 1);
                            headRends.Add(h); headRends.Add(g);
                            break;
                        }
                    case Acc.Cape:
                        {
                            Color cc = (mainCol.r + mainCol.g + mainCol.b) < 0.5f ? new Color(0.55f, 0.05f, 0.08f) : Draw.Mul(mainCol, 0.55f);
                            lCape = Draw.Line(transform, "cape", 1f, cc, baseOrder - 2, true, 3);
                            Draw.Taper(lCape, 0.2f * s, 0.45f * s);
                            lCape.positionCount = 6;
                            break;
                        }
                    case Acc.Visor:
                        {
                            Color vc = glow ? new Color(0.1f, 1f, 1f) : new Color(1f, 0.15f, 0.15f);
                            var v = Draw.Line(headRoot, "visor", 0.09f * s, vc, o, false, 1);
                            Draw.Set(v, new Vector2(hr * 0.05f, hr * 0.15f), new Vector2(hr * 1.0f, hr * 0.15f));
                            var g = Draw.Spr(headRoot, "visorGlow", Draw.Soft, Draw.A(vc, 0.6f), o - 1);
                            g.transform.localPosition = new Vector3(hr * 0.6f, hr * 0.15f, 0); g.transform.localScale = new Vector3(hr * 3f, hr * 1.2f, 1);
                            headRends.Add(v); headRends.Add(g);
                            break;
                        }
                    case Acc.Scarf:
                        {
                            lScarf = Draw.Line(transform, "scarf", 1f, new Color(0.85f, 0.15f, 0.15f), baseOrder + 7, true, 2);
                            Draw.Taper(lScarf, 0.12f * s, 0.07f * s);
                            lScarf.positionCount = 4;
                            break;
                        }
                }
            }

            // нарисованное игроком (координаты планшета: голова радиусом 0.4)
            if (B.drawing != null)
            {
                float k = hr / 0.4f;
                foreach (var st in B.drawing)
                {
                    if (st.pts == null || st.pts.Count < 2) continue;
                    var lr = Draw.Line(headRoot, "drawn", Mathf.Max(0.02f, st.width * k), st.color, o + 2, false, 3);
                    var pts = new List<Vector2>();
                    foreach (var p in st.pts) pts.Add(p * k);
                    Draw.Set(lr, pts);
                    headRends.Add(lr);
                }
            }
        }

        public void SetWeapon(WeaponStats w, int am)
        {
            foreach (Transform c in weaponRoot) Destroy(c.gameObject);
            weaponRends.Clear();
            weapon = w;
            ammo = am;
            if (w != null) weaponRends = WeaponVisual.Build(weaponRoot, w, Size, baseOrder + 7, glow);
        }

        // ===================== ОБНОВЛЕНИЕ =====================
        public void Tick(float dt)
        {
            if (dt <= 0f) { Render(); return; }
            animT += dt;
            if (dead) { DeadTick(dt); Render(); return; }

            flash -= dt; hurtT -= dt; stun -= dt; atkCd -= dt; shieldT -= dt; invisT -= dt; regenBlock -= dt; slowT -= dt; staffCd -= dt;
            foreach (var k in B.abilities) cd[k] = CooldownOf(k) - dt;

            Status(dt);
            if (dead) { Render(); return; }

            target = battle.FindTarget(this);
            float move = 0; bool jump = false;
            bool free = Free;
            if (battle.mode == Battle.Mode.Showroom) move = Showroom(dt);
            else if (battle.phase == Battle.Phase.Fight)
            {
                if (human) HumanInput(ref move, ref jump, free);
                else AI(ref move, ref jump, free, dt);
            }

            if (act == Act.None && stun <= 0 && hurtT <= 0 && battle.mode != Battle.Mode.Showroom)
            {
                if (human && Mathf.Abs(move) > 0.1f) facing = move > 0 ? 1 : -1;
                else if (target != null) facing = target.pos.x >= pos.x ? 1 : -1;
            }

            Physics(dt, move, jump);
            ActTick(dt);
            TryPickup();

            Pose tgt = TargetPose(dt);
            float rate = (act != Act.None && act != Act.Block) ? 40f : 15f;
            cur = Pose.Lerp(cur, tgt, 1f - Mathf.Exp(-rate * dt));
            Skel.Compute(cur, pos, Size, facing, J);
            Render();
        }

        void Status(float dt)
        {
            float dot = 0;
            Fighter src = null;
            DmgType type = DmgType.Fire;
            if (burnT > 0)
            {
                burnT -= dt; dot += 3.5f * dt; src = burnBy; type = DmgType.Fire;
                fxT -= dt;
                if (fxT <= 0) { fxT = 0.05f; battle.fx.Fire(Center + Random.insideUnitCircle * 0.3f, 1, 0.3f); }
            }
            if (poisonT > 0)
            {
                poisonT -= dt; dot += 2.5f * dt; if (src == null) { src = poisonBy; type = DmgType.Poison; }
                if (Random.value < dt * 10) battle.fx.Emit(Center + Random.insideUnitCircle * 0.4f, Vector2.up * 0.8f, new Color(0.4f, 0.95f, 0.25f, 0.7f), 0.12f, 0.6f, 0f, false, 1f);
            }
            if (bleedT > 0)
            {
                bleedT -= dt; dot += 1.3f * dt; if (src == null) { src = bleedBy; type = DmgType.Blade; }
                dripT -= dt;
                if (dripT <= 0) { dripT = Random.Range(0.06f, 0.18f); battle.fx.Drip(Center + Random.insideUnitCircle * 0.25f); }
            }
            if (dot > 0)
            {
                dotAcc += dot;
                if (dotAcc >= 1f)
                {
                    float d = Mathf.Floor(dotAcc);
                    dotAcc -= d;
                    RawDamage(d, type, src, false);
                }
            }
            if (B.HasAb(Ability.Regen) && regenBlock <= 0 && hp < maxHp && !dead)
            {
                hp = Mathf.Min(maxHp, hp + 2.4f * dt);
                if (Random.value < dt * 4) battle.fx.Emit(Center + Random.insideUnitCircle * 0.4f, Vector2.up * 1.2f, new Color(0.3f, 1f, 0.4f, 0.8f), 0.1f, 0.6f, 0f, false, 1f);
            }
            if (RageOn && Random.value < dt * 14)
                battle.fx.Emit(J[Random.Range(0, 11)], Vector2.up * 1.5f + Random.insideUnitCircle, new Color(1f, 0.15f, 0.05f, 0.7f), 0.14f, 0.4f, 0f, false, 1f, true, 1, 1, true);
        }

        void Physics(float dt, float move, bool jump)
        {
            float spd = 5.3f * B.spd * (slowT > 0 ? 0.5f : 1f) * (RageOn ? 1.25f : 1f);
            if (act == Act.Dash) vel.x = facing * 21f;
            else if (stun > 0 || hurtT > 0) vel.x = Mathf.MoveTowards(vel.x, 0, (grounded ? 14f : 3f) * dt);
            else if (act != Act.None && act != Act.Saw)
            {
                float u = actT / Mathf.Max(0.01f, actDur);
                float lunge = (u > 0.33f && u < 0.5f && (act == Act.Punch || act == Act.Stab || act == Act.Slash || act == Act.Smash)) ? facing * 4f : 0f;
                if (grounded) vel.x = Mathf.MoveTowards(vel.x, lunge, 40f * dt);
            }
            else
            {
                float t = move * spd;
                vel.x = Mathf.MoveTowards(vel.x, t, (grounded ? 55f : 25f) * dt);
            }

            if (jump && stun <= 0 && hurtT <= 0 && (act == Act.None || act == Act.Block))
            {
                float jv = 12.5f * Mathf.Sqrt(B.agi);
                if (grounded)
                {
                    vel.y = jv; grounded = false; act = Act.None;
                    battle.fx.Dust(pos, 4);
                }
                else if (jumps > 0)
                {
                    jumps--;
                    vel.y = jv * 0.95f;
                    battle.Shock(pos, 0.8f, new Color(1, 1, 1, 0.6f));
                    battle.audio.Sfx("whoosh", 0.4f);
                }
            }

            float g = -32f;
            if (act == Act.Laser || (act == Act.Cast && !grounded)) g *= 0.25f;
            if (tkSlam && vel.y < 0) g *= 2.5f;
            if (slamPending && vel.y < 0) g *= 2f;
            vel.y += g * dt;
            pos += vel * dt;

            if (pos.y <= 0f)
            {
                if (!grounded) Land();
                pos.y = 0f;
                if (vel.y < 0) vel.y = 0;
                grounded = true;
            }
            else grounded = false;

            float lim = battle.W - 0.3f;
            if (Mathf.Abs(pos.x) > lim)
            {
                if (Mathf.Abs(vel.x) > 9f && hurtT > 0)
                {
                    RawDamage(Mathf.Abs(vel.x) * 0.7f, DmgType.Blunt, null, true);
                    battle.fx.Blood(new Vector2(Mathf.Sign(pos.x) * lim, Center.y), new Vector2(Mathf.Sign(pos.x), 0.3f), 18);
                    battle.cam.Shake(0.3f);
                    battle.audio.Sfx("thud", 0.8f);
                }
                pos.x = Mathf.Sign(pos.x) * lim;
                vel.x *= -0.3f;
            }

            // враги не проходят сквозь друг друга
            foreach (var e in battle.fighters)
            {
                if (e == this || e.dead || e.team == team) continue;
                float dx = pos.x - e.pos.x;
                float min = 0.42f * (Size + e.Size);
                if (Mathf.Abs(dx) < min && Mathf.Abs(pos.y - e.pos.y) < 1.4f)
                {
                    float sgn = Mathf.Abs(dx) < 0.001f ? -facing : Mathf.Sign(dx);
                    pos.x += sgn * (min - Mathf.Abs(dx)) * 0.5f;
                }
            }
        }

        void Land()
        {
            if (vel.y < -10f)
            {
                battle.fx.Dust(pos, 8);
                battle.audio.Sfx("thud", 0.35f);
            }
            jumps = B.HasAb(Ability.DoubleJump) ? 1 : 0;
            if (slamPending) { slamPending = false; DoSlam(); }
            if (tkSlam)
            {
                tkSlam = false;
                var h = new HitInfo { dmg = 18f, type = DmgType.Blunt, attacker = tkBy, dir = Vector2.down, point = pos + Vector2.up * 0.3f, knock = 3f, stun = 0.5f, heavy = true };
                battle.Shock(pos, 2.2f, new Color(0.7f, 0.4f, 1f, 0.8f));
                battle.fx.Dust(pos, 20);
                TakeHit(h);
            }
        }

        // ===================== ДЕЙСТВИЯ =====================
        void StartAct(Act a, float dur)
        {
            act = a; actT = 0; actDur = Mathf.Max(0.08f, dur); actFired = false;
            if (a != Act.Block) battle.OnAttackStart(this);
        }

        public float Reach()
        {
            if (weapon != null && !weapon.Ranged) return weapon.range * Size;
            return 0.95f * Size;
        }

        public void Attack(bool kick)
        {
            if (!Free) return;
            float sp = Mathf.Sqrt(B.spd) * (RageOn ? 1.2f : 1f);
            if (kick) { StartAct(Act.Kick, 0.48f / sp); atkCd = Random.Range(0.15f, 0.45f) / sp; return; }
            if (weapon != null)
            {
                float r = weapon.rate * sp;
                switch (weapon.kind)
                {
                    case WeaponKind.Blade: StartAct(Act.Slash, 0.48f / r); break;
                    case WeaponKind.Blunt: StartAct(Act.Smash, 0.62f / r); break;
                    case WeaponKind.Spear: StartAct(Act.Stab, 0.5f / r); break;
                    case WeaponKind.Chainsaw: StartAct(Act.Saw, 0.9f); sawTick = 0; break;
                    case WeaponKind.Staff:
                        if (target != null && Mathf.Abs(target.pos.x - pos.x) > 3f && staffCd <= 0f)
                        {
                            castAb = Ability.Fireball; castFromStaff = true; staffCd = 1.6f;
                            aim = AimAt(target); StartAct(Act.Cast, 0.45f);
                        }
                        else StartAct(Act.Slash, 0.5f / r);
                        break;
                    case WeaponKind.Gun:
                        if (ammo <= 0) { StartAct(Act.Punch, 0.32f / sp); break; }
                        aim = AimAt(target);
                        StartAct(Act.Shoot, (weapon.rifle ? 0.13f : 0.3f) / weapon.rate);
                        break;
                    case WeaponKind.Bow:
                        if (ammo <= 0) { StartAct(Act.Punch, 0.32f / sp); break; }
                        aim = AimAt(target);
                        if (target != null) aim = (aim + Vector2.up * Mathf.Abs(target.pos.x - pos.x) * 0.012f).normalized;
                        StartAct(Act.Shoot, 0.65f / weapon.rate);
                        break;
                    case WeaponKind.Thrown:
                        if (ammo <= 0) { StartAct(Act.Punch, 0.32f / sp); break; }
                        aim = AimAt(target);
                        StartAct(Act.Throw, 0.4f / weapon.rate);
                        break;
                }
            }
            else { alt = !alt; StartAct(Act.Punch, 0.32f / sp); }
            atkCd = Random.Range(0.12f, 0.45f) / sp;
        }

        Vector2 AimAt(Fighter t)
        {
            if (t == null) return new Vector2(facing, 0);
            Vector2 from = J[1];
            Vector2 d = t.Center - from;
            if (Mathf.Abs(d.x) < 0.1f) d.x = facing * 0.1f;
            return d.normalized;
        }

        public void StartBlock()
        {
            if (!Free) return;
            StartAct(Act.Block, 0.45f);
        }

        void ActTick(float dt)
        {
            if (act == Act.None) return;
            actT += dt;
            float u = actT / actDur;
            switch (act)
            {
                case Act.Saw:
                    sawTick -= dt;
                    if (sawTick <= 0f)
                    {
                        sawTick = 0.09f;
                        battle.audio.Sfx("saw", 0.5f);
                        Melee(weapon != null ? weapon.range : 1.4f, weapon != null ? weapon.dmg : 4f, DmgType.Blade, weapon != null ? weapon.element : Element.None, 0.8f, 0.12f, J[4], false, true);
                        battle.fx.Sparks(J[4] + new Vector2(facing * 0.6f, 0), new Vector2(facing, 0.5f), 2, new Color(1f, 0.8f, 0.3f));
                    }
                    break;
                case Act.Laser:
                    LaserTick(dt);
                    break;
                case Act.Dash:
                    ghostT -= dt;
                    if (ghostT <= 0) { ghostT = 0.04f; battle.AfterImage(this, Draw.A(mainCol, 0.5f)); }
                    foreach (var e in battle.fighters)
                    {
                        if (e.dead || e.team == team || dashHit.Contains(e)) continue;
                        if (Mathf.Abs(e.pos.x - pos.x) < 0.9f * Size && Mathf.Abs(e.pos.y - pos.y) < 1.3f)
                        {
                            dashHit.Add(e);
                            var h = MakeHit(14f, weapon != null && !weapon.Ranged ? weapon.Type : DmgType.Blunt, weapon != null ? weapon.element : B.affinity, 7f, 0.3f);
                            h.point = e.Center; h.dir = new Vector2(facing, 0.4f).normalized;
                            e.TakeHit(h);
                            battle.audio.Sfx("kick");
                        }
                    }
                    break;
                default:
                    if (!actFired && u >= 0.45f) { actFired = true; Fire(); }
                    break;
            }
            if (actT >= actDur)
            {
                if (act == Act.Laser) { lLaser.enabled = lLaserGlow.enabled = false; }
                act = Act.None;
            }
        }

        HitInfo MakeHit(float dmg, DmgType type, Element elem, float knock, float stun)
        {
            var h = new HitInfo();
            h.dmg = dmg * (RageOn ? 1.5f : 1f) * Random.Range(0.9f, 1.1f);
            h.type = type; h.elem = elem; h.knock = knock; h.stun = stun; h.attacker = this;
            h.dir = new Vector2(facing, 0.25f).normalized;
            return h;
        }

        void Fire()
        {
            switch (act)
            {
                case Act.Punch:
                    Melee(0.95f, 7f, DmgType.Blunt, B.affinity, 3.5f, 0.15f, alt ? J[6] : J[4], false, false);
                    break;
                case Act.Kick:
                    Melee(1.15f, 10f, DmgType.Blunt, B.affinity, 6.5f, 0.25f, J[8], false, false);
                    break;
                case Act.Slash:
                    if (weapon == null) break;
                    battle.audio.Sfx("slash", 0.7f);
                    Melee(weapon.range, weapon.dmg, weapon.Type, weapon.element, 4.5f * weapon.knock, 0.2f, J[4], true, weapon.bleed);
                    break;
                case Act.Smash:
                    if (weapon == null) break;
                    battle.audio.Sfx("whoosh", 0.7f);
                    if (Melee(weapon.range, weapon.dmg, DmgType.Blunt, weapon.element, 8f * weapon.knock, 0.35f, J[4], true, false)) battle.cam.Kick(0.6f);
                    if (grounded) battle.fx.Dust(new Vector2(pos.x + facing * weapon.range * 0.8f, 0), 5);
                    break;
                case Act.Stab:
                    if (weapon == null) break;
                    battle.audio.Sfx("slash", 0.5f);
                    Melee(weapon.range, weapon.dmg, weapon.Type, weapon.element, 5f * weapon.knock, 0.2f, J[4], false, weapon.bleed);
                    break;
                case Act.Shoot: FireGun(); break;
                case Act.Throw: FireThrown(); break;
                case Act.Cast: DoCast(); break;
            }
        }

        bool Melee(float reach, float dmg, DmgType type, Element elem, float knock, float stunT, Vector2 from, bool cleave, bool bleed)
        {
            float r = reach * Size;
            Vector2 c = Center;
            bool any = false;
            foreach (var e in battle.fighters)
            {
                if (e.team == team || e.dead) continue;
                Vector2 rel = e.Center - c;
                float fx = rel.x * facing;
                if (fx > -0.35f && fx < r + 0.3f * e.Size && Mathf.Abs(rel.y) < 1.0f * Size + 0.5f * e.Size)
                {
                    float str = (weapon != null && weapon.Ranged) ? 1f : B.str;
                    var h = MakeHit(dmg * str, type, elem, knock, stunT);
                    h.point = new Vector2(e.pos.x - facing * 0.12f * e.Size, Mathf.Clamp(from.y, e.pos.y + 0.5f * e.Size, e.J[2].y));
                    h.headshot = type == DmgType.Blade && Mathf.Abs(h.point.y - e.J[2].y) < Skel.HeadR * e.Size * 1.5f && Random.value < 0.25f;
                    h.heavy = knock > 7f;
                    if (bleed) e.bleedT = Mathf.Max(e.bleedT, 3f);
                    if (bleed) e.bleedBy = this;
                    e.TakeHit(h);
                    any = true;
                    if (!cleave) break;
                }
            }
            if (any)
            {
                atkCd = Mathf.Min(atkCd, 0.06f);
                if (type == DmgType.Blade) { battle.audio.Sfx("cut", 0.8f); battle.audio.Sfx("splat", 0.5f); }
                else battle.audio.Sfx(act == Act.Kick || act == Act.Smash ? "kick" : "punch", 0.9f);
            }
            else if (act != Act.Saw) battle.audio.Sfx("whoosh", 0.35f);
            return any;
        }

        void FireGun()
        {
            if (weapon == null) return;
            Vector2 from = J[4] + aim * 0.45f * Size;
            bool bow = weapon.kind == WeaponKind.Bow;
            for (int i = 0; i < weapon.pellets; i++)
            {
                float spread = weapon.pellets > 1 ? Random.Range(-9f, 9f) : Random.Range(-1.5f, 1.5f);
                Vector2 d = Quaternion.Euler(0, 0, spread) * aim;
                var h = MakeHit(weapon.dmg, DmgType.Pierce, weapon.element, bow ? 4f : 2.5f, 0.1f);
                battle.SpawnProjectile(bow ? Projectile.Kind.Arrow : Projectile.Kind.Bullet, from, d * (bow ? 22f : 32f), this, h, weapon.color);
            }
            if (!bow) { battle.fx.Fire(from, 4, 0.05f); battle.fx.Smoke(from, 2, new Color(0.7f, 0.7f, 0.7f, 0.4f), 0.1f, 0.25f); }
            battle.audio.Sfx(bow ? "bow" : "shot", bow ? 0.7f : (weapon.rifle ? 0.55f : 0.8f));
            if (!bow) battle.cam.Shake(weapon.pellets > 1 ? 0.25f : 0.08f);
            vel.x -= facing * (weapon.pellets > 1 ? 4f : 0.8f);
            ammo--;
            if (ammo <= 0) Discard();
        }

        void FireThrown()
        {
            if (weapon == null) return;
            Vector2 from = J[4];
            var h = MakeHit(weapon.dmg, weapon.explode ? DmgType.Blunt : DmgType.Blade, weapon.element, weapon.explode ? 8f : 2.5f, 0.15f);
            if (weapon.explode)
            {
                float dist = target != null ? Mathf.Abs(target.pos.x - pos.x) : 6f;
                var v = new Vector2(facing * Mathf.Clamp(dist * 1.1f, 4f, 13f), 7f);
                battle.SpawnProjectile(Projectile.Kind.Grenade, from, v, this, h, weapon.color);
            }
            else battle.SpawnProjectile(Projectile.Kind.Shuriken, from, aim * 18f, this, h, weapon.color);
            battle.audio.Sfx("whoosh", 0.6f);
            ammo--;
            if (ammo <= 0) Discard();
        }

        void Discard()
        {
            battle.Popup("Пусто!", J[2] + Vector2.up * 0.6f, new Color(0.8f, 0.8f, 0.8f), 0.7f);
            SetWeapon(null, 0);
        }

        // ===================== СПОСОБНОСТИ =====================
        public bool UseAbility(Ability a)
        {
            if (Info.Passive(a) || CooldownOf(a) > 0 || !Free) return false;
            switch (a)
            {
                case Ability.Fireball:
                case Ability.IceShard:
                case Ability.Telekinesis:
                case Ability.Lightning:
                    castAb = a;
                    castFromStaff = false;
                    aim = AimAt(target);
                    StartAct(Act.Cast, a == Ability.Lightning ? 0.6f : 0.5f);
                    break;
                case Ability.Laser:
                    aim = AimAt(target);
                    StartAct(Act.Laser, 1.0f);
                    laserTick = 0;
                    battle.audio.Sfx("laser", 0.6f);
                    break;
                case Ability.Teleport:
                    if (!DoTeleport()) return false;
                    break;
                case Ability.Dash:
                    dashHit.Clear();
                    StartAct(Act.Dash, 0.32f);
                    battle.audio.Sfx("whoosh", 0.9f);
                    break;
                case Ability.Shield:
                    shieldT = 3.5f;
                    battle.audio.Sfx("heal", 0.7f);
                    battle.Shock(Center, 1.4f, new Color(0.4f, 0.9f, 1f, 0.8f));
                    break;
                case Ability.GroundSlam:
                    slamPending = true;
                    if (grounded) { vel.y = 14f; grounded = false; }
                    else vel.y = -20f;
                    battle.audio.Sfx("whoosh", 0.8f);
                    break;
                case Ability.Invisibility:
                    invisT = 3.5f;
                    battle.fx.Smoke(Center, 14, new Color(0.3f, 0.3f, 0.35f, 0.6f), 0.5f, 0.6f);
                    battle.audio.Sfx("teleport", 0.6f);
                    break;
                default: return false;
            }
            cd[a] = Info.Cooldown(a);
            battle.Popup(Info.Name(a).Replace(" (пассив)", "").ToUpper() + "!", J[2] + Vector2.up * 0.7f, Color.Lerp(mainCol, Color.white, 0.4f), 0.8f);
            return true;
        }

        bool DoTeleport()
        {
            Fighter t = target;
            if (t == null) return false;
            Vector2 old = Center;
            float nx = t.pos.x - t.facing * 1.3f * Size;
            if (Mathf.Abs(nx) > battle.W - 0.5f) nx = t.pos.x + t.facing * 1.3f * Size;
            battle.AfterImage(this, Draw.A(mainCol, 0.6f));
            battle.fx.Smoke(old, 12, new Color(0.5f, 0.3f, 0.8f, 0.6f), 0.5f, 0.5f);
            pos = new Vector2(nx, t.pos.y);
            vel = Vector2.zero;
            facing = t.pos.x >= pos.x ? 1 : -1;
            Skel.Compute(cur, pos, Size, facing, J);
            battle.fx.Smoke(Center, 12, new Color(0.5f, 0.3f, 0.8f, 0.6f), 0.5f, 0.5f);
            battle.audio.Sfx("teleport", 0.8f);
            atkCd = 0;
            return true;
        }

        void DoCast()
        {
            Vector2 hand = J[4];
            float pw = 0.7f + 0.3f * B.str;
            switch (castAb)
            {
                case Ability.Fireball:
                    {
                        Element el = (castFromStaff && weapon != null) ? weapon.element : Element.Fire;
                        var h = MakeHit(16f * pw, Info.ToType(el == Element.None ? Element.Fire : el), el == Element.None ? Element.Fire : el, 5f, 0.2f);
                        var kind = el == Element.Fire || el == Element.None ? Projectile.Kind.Fireball : Projectile.Kind.Bolt;
                        if (kind == Projectile.Kind.Bolt) h.dmg = 11f * pw;
                        battle.SpawnProjectile(kind, hand + aim * 0.3f, aim * 13f, this, h, Info.ElemColor(el == Element.None ? Element.Fire : el));
                        battle.audio.Sfx(kind == Projectile.Kind.Fireball ? "fire" : "zap", 0.8f);
                        break;
                    }
                case Ability.IceShard:
                    for (int i = -1; i <= 1; i++)
                    {
                        var h = MakeHit(7.5f * pw, DmgType.Ice, Element.Ice, 2.5f, 0.15f);
                        Vector2 d = Quaternion.Euler(0, 0, i * 8f) * aim;
                        battle.SpawnProjectile(Projectile.Kind.Ice, hand, d * 17f, this, h, Info.ElemColor(Element.Ice));
                    }
                    battle.audio.Sfx("ice", 0.8f);
                    break;
                case Ability.Lightning:
                    {
                        float x = target != null ? target.pos.x : pos.x + facing * 4f;
                        battle.LightningStrike(new Vector2(x, 0), this, 20f * pw);
                        break;
                    }
                case Ability.Telekinesis:
                    if (target != null && Mathf.Abs(target.pos.x - pos.x) < 11f)
                    {
                        target.Lift(this);
                        battle.audio.Sfx("teleport", 0.7f);
                    }
                    break;
            }
        }

        public void Lift(Fighter by)
        {
            if (dead) return;
            stun = 1.2f;
            act = Act.None;
            vel = new Vector2((by.pos.x - pos.x) * 0.25f, 14f);
            grounded = false;
            tkSlam = true;
            tkBy = by;
            for (int i = 0; i < 16; i++) battle.fx.Emit(Center + Random.insideUnitCircle * 0.6f, Random.insideUnitCircle * 2f, new Color(0.7f, 0.4f, 1f, 0.8f), 0.15f, 0.6f, 0f, false, 1f, true, 1, 1, true);
        }

        void DoSlam()
        {
            float pw = 0.7f + 0.3f * B.str;
            battle.Shock(pos, 3.8f * Size, new Color(1f, 0.85f, 0.6f, 0.9f));
            battle.fx.Dust(pos, 30);
            battle.cam.Shake(0.7f);
            battle.cam.Kick(1f);
            battle.audio.Sfx("explosion", 0.6f);
            foreach (var e in battle.fighters)
            {
                if (e.dead || e.team == team) continue;
                if (Mathf.Abs(e.pos.x - pos.x) < 3.8f * Size && e.pos.y < 1.5f)
                {
                    var h = MakeHit(18f * pw, DmgType.Blunt, B.affinity, 8f, 0.4f);
                    h.dir = new Vector2(Mathf.Sign(e.pos.x - pos.x), 1.2f).normalized;
                    h.point = e.pos + Vector2.up * 0.4f;
                    h.heavy = true;
                    e.TakeHit(h);
                }
            }
        }

        void LaserTick(float dt)
        {
            Vector2 eye = J[2] + new Vector2(facing * 0.12f * Size, 0.03f);
            Vector2 dir = aim;
            if (target != null)
            {
                Vector2 want = (target.Center - eye).normalized;
                if (Mathf.Sign(want.x) == facing) dir = Vector2.Lerp(aim, want, dt * 2f).normalized;
            }
            if (Mathf.Sign(dir.x) != facing) dir = new Vector2(facing, 0);
            aim = dir;
            float len = 20f;
            if (dir.y < -0.01f) len = Mathf.Min(len, eye.y / -dir.y);
            float wall = (battle.W * facing - eye.x) / dir.x;
            if (wall > 0) len = Mathf.Min(len, wall);
            Vector2 end = eye + dir * len;
            lLaser.enabled = lLaserGlow.enabled = true;
            float flick = 1f + Mathf.Sin(animT * 80f) * 0.15f;
            lLaser.widthMultiplier = 0.1f * flick * Size;
            lLaserGlow.widthMultiplier = 0.45f * flick * Size;
            Draw.Set(lLaser, eye, end);
            Draw.Set(lLaserGlow, eye, end);
            battle.fx.Fire(end, 1, 0.1f);
            laserTick -= dt;
            if (laserTick <= 0f)
            {
                laserTick = 0.1f;
                foreach (var e in battle.fighters)
                {
                    if (e.dead || e.team == team) continue;
                    Vector2 c = e.Center;
                    Vector2 toC = c - eye;
                    float along = Vector2.Dot(toC, dir);
                    if (along < 0 || along > len) continue;
                    float perp = Mathf.Abs(toC.x * dir.y - toC.y * dir.x);
                    if (perp < 0.55f * e.Size)
                    {
                        var h = MakeHit(2.6f * (0.7f + 0.3f * B.str), DmgType.Fire, Element.Fire, 0.6f, 0.05f);
                        h.point = eye + dir * along; h.dir = dir; h.noFlinch = true;
                        e.TakeHit(h);
                        battle.fx.Sparks(h.point, -dir, 3, new Color(1f, 0.6f, 0.3f));
                    }
                }
            }
        }

        // ===================== УРОН =====================
        public void TakeHit(HitInfo h)
        {
            if (dead) return;
            float d = h.dmg;
            bool blocked = act == Act.Block && Mathf.Sign(h.dir.x) == -facing && h.type != DmgType.Lightning;
            if (blocked)
            {
                d *= 0.2f; h.knock *= 0.35f;
                battle.fx.Sparks(h.point, -h.dir, 10, new Color(1f, 0.9f, 0.5f));
                battle.audio.Sfx("clang", 0.6f);
            }
            bool weak = h.type == B.weakness || (h.elem != Element.None && Info.ToType(h.elem) == B.weakness);
            if (weak)
            {
                d *= 2f;
                regenBlock = 4f;
                if (Random.value < 0.6f) battle.Popup("СЛАБОСТЬ!", J[2] + Vector2.up * 0.9f, new Color(1f, 0.85f, 0.1f), 0.8f);
            }
            else if (h.elem != Element.None && h.elem == B.affinity) d *= 0.5f;
            d /= Mathf.Sqrt(B.def);
            if (shieldT > 0 && !weak)
            {
                d *= 0.25f; h.knock *= 0.3f;
                battle.fx.Sparks(h.point, -h.dir, 6, new Color(0.4f, 0.9f, 1f));
            }
            if (h.headshot) { d *= 1.4f; }
            if (h.attacker != null && h.attacker.RageOn) d *= 1f; // ярость уже в MakeHit
            d = Mathf.Max(0.5f, d);

            hp -= d;
            invisT = 0;
            if (h.attacker != null)
            {
                h.attacker.dmgDealt += d;
                if (h.attacker.B.HasAb(Ability.Vampire) && !h.attacker.dead) h.attacker.hp = Mathf.Min(h.attacker.maxHp, h.attacker.hp + d * 0.3f);
                if (h.elem == Element.Shadow && !h.attacker.dead) h.attacker.hp = Mathf.Min(h.attacker.maxHp, h.attacker.hp + d * 0.25f);
            }
            battle.DamageNumber(d, J[2] + Vector2.up * 0.5f, weak, h.headshot);

            if (!blocked)
            {
                float amt = d * (h.type == DmgType.Blade || h.type == DmgType.Pierce ? 2.2f : 1.3f);
                if (h.type == DmgType.Fire || h.type == DmgType.Lightning || h.type == DmgType.Ice) amt *= 0.4f;
                battle.fx.Blood(h.point, h.dir, amt);
                if (h.type == DmgType.Fire) battle.fx.Fire(h.point, 6, 0.2f);
                if (h.type == DmgType.Ice) battle.fx.Sparks(h.point, h.dir, 8, new Color(0.6f, 0.95f, 1f));
                if (h.type == DmgType.Lightning) battle.fx.Sparks(h.point, Vector2.up, 10, new Color(1f, 1f, 0.5f));
                flash = 0.08f;
            }

            switch (h.elem)
            {
                case Element.Fire: burnT = Mathf.Max(burnT, 2.5f); burnBy = h.attacker; break;
                case Element.Ice: slowT = Mathf.Max(slowT, 2.5f); break;
                case Element.Lightning: h.stun = Mathf.Max(h.stun, 0.45f); break;
                case Element.Poison: poisonT = Mathf.Max(poisonT, 5f); poisonBy = h.attacker; break;
            }

            bool superArmor = Size >= 1.25f && d < 9f && !h.heavy;
            if (!h.noFlinch && !superArmor)
            {
                float kn = h.knock / Mathf.Sqrt(Size);
                vel += new Vector2(h.dir.x * kn, Mathf.Max(kn * 0.35f, h.dir.y * kn));
                if (vel.y > 0.5f) grounded = false;
                if (act != Act.Block || !blocked) { if (act != Act.Laser) act = Act.None; }
                hurtT = blocked ? 0.08f : 0.22f;
                stun = Mathf.Max(stun, blocked ? 0f : h.stun);
                if (act == Act.Laser) { act = Act.None; lLaser.enabled = lLaserGlow.enabled = false; }
            }
            battle.Impact(d, h.point, h.heavy);

            if (hp <= 0) Die(h);
        }

        void RawDamage(float d, DmgType type, Fighter src, bool show)
        {
            if (dead) return;
            if (type == B.weakness) { d *= 2f; regenBlock = 4f; }
            hp -= d;
            if (src != null) src.dmgDealt += d;
            if (show) battle.DamageNumber(d, J[2] + Vector2.up * 0.5f, false, false);
            if (hp <= 0)
            {
                var h = new HitInfo { dmg = d, type = type, attacker = src, dir = new Vector2(-facing, 0.5f).normalized, point = Center, knock = 2f };
                Die(h);
            }
        }

        void Die(HitInfo h)
        {
            if (dead) return;
            dead = true; hp = 0; act = Act.None; deadTime = 0;
            shieldT = 0; invisT = 0;
            lLaser.enabled = lLaserGlow.enabled = false;
            if (weapon != null && (!weapon.Ranged || ammo > 0))
                battle.SpawnPickup(weapon, ammo, J[4], vel + new Vector2(Random.Range(-3f, 3f), 6f), false);
            SetWeapon(null, 0);
            Vector2 v = vel + h.dir * h.knock * 1.4f + Vector2.up * 2f;
            rag = new Ragdoll(J, v, Size);
            float bloodMul = Game.I != null ? Game.I.S.blood : 1f;
            bool decap = bloodMul > 0.01f && ((h.type == DmgType.Blade && (h.heavy || h.dmg > 14f || Random.value < 0.35f)) || h.headshot);
            if (decap)
            {
                rag.BreakNeck(new Vector2(h.dir.x * 6f + Random.Range(-1f, 1f), 7f));
                fountainT = 2.5f;
                battle.Popup("ГОЛОВА С ПЛЕЧ!", J[2] + Vector2.up * 1.2f, new Color(1f, 0.2f, 0.15f), 1.1f);
            }
            battle.fx.Blood(h.point, h.dir, 55);
            battle.audio.Sfx("splat", 1f);
            battle.audio.Sfx("thud", 0.8f);
            if (h.attacker != null && h.attacker != this) h.attacker.kills++;
            battle.OnDeath(this, h);
        }

        void DeadTick(float dt)
        {
            deadTime += dt;
            rag.Step(dt, battle.W);
            if (fountainT > 0)
            {
                fountainT -= dt;
                Vector2 neckDir = (rag.p[1] - rag.p[0]).normalized;
                if (Random.value < 0.7f) battle.fx.Fountain(rag.p[1], neckDir + Random.insideUnitCircle * 0.3f, Mathf.Max(1, (int)(fountainT * 1.5f)));
                if (Random.value < 0.3f) battle.fx.Drip(rag.p[2]);
            }
            if (deadTime < 6f && Random.value < dt * 6f) battle.fx.Drip(rag.p[Random.Range(0, 2)]);
            if (!pooled && rag.rest > 0.3f) { pooled = true; battle.fx.Pool(rag.p[0], 2.4f * Size); }
            if (rag.headOff && !headPooled && rag.rest > 0.3f) { headPooled = true; battle.fx.Pool(rag.p[2], 1.1f * Size); }
        }

        void TryPickup()
        {
            if (weapon != null || dead) return;
            foreach (var pk in battle.pickups)
            {
                if (!pk.landed && pk.pos.y > 1.8f) continue;
                if (Mathf.Abs(pk.pos.x - pos.x) < 0.8f && Mathf.Abs(pk.pos.y - pos.y) < 1.8f)
                {
                    SetWeapon(pk.w.Copy(), pk.ammo);
                    battle.RemovePickup(pk);
                    battle.audio.Sfx("pickup", 0.7f);
                    battle.Popup(weapon.name, J[2] + Vector2.up * 0.8f, Color.Lerp(weapon.color, Color.white, 0.3f), 0.8f);
                    return;
                }
            }
        }

        // ===================== УПРАВЛЕНИЕ =====================
        void HumanInput(ref float move, ref bool jump, bool free)
        {
            var g = Game.I;
            if (g == null) return;
            KeyCode L, R, U, D, A, K, Q1, Q2, Q3;
            if (pindex == 0) { L = KeyCode.A; R = KeyCode.D; U = KeyCode.W; D = KeyCode.S; A = KeyCode.F; K = KeyCode.G; Q1 = KeyCode.R; Q2 = KeyCode.T; Q3 = KeyCode.Y; }
            else { L = KeyCode.LeftArrow; R = KeyCode.RightArrow; U = KeyCode.UpArrow; D = KeyCode.DownArrow; A = KeyCode.K; K = KeyCode.L; Q1 = KeyCode.I; Q2 = KeyCode.O; Q3 = KeyCode.P; }
            if (g.Held(L)) move -= 1;
            if (g.Held(R)) move += 1;
            if (g.Pressed(U)) jump = true;
            if (pindex == 1)
            {
                if (g.Pressed(KeyCode.Keypad1)) A = KeyCode.Keypad1;
                if (g.Pressed(KeyCode.Keypad2)) K = KeyCode.Keypad2;
            }
            if (free)
            {
                if (g.Held(D)) StartBlock();
                else if (g.Pressed(A)) Attack(false);
                else if (g.Pressed(K)) Attack(true);
                else
                {
                    var acts = ActiveAbilities();
                    if (g.Pressed(Q1) && acts.Count > 0) UseAbility(acts[0]);
                    else if (g.Pressed(Q2) && acts.Count > 1) UseAbility(acts[1]);
                    else if (g.Pressed(Q3) && acts.Count > 2) UseAbility(acts[2]);
                }
            }
            else if (act == Act.Block && !g.Held(D) && actT > 0.1f) act = Act.None;
            else if (act == Act.Block && g.Held(D)) actT = Mathf.Min(actT, actDur * 0.5f);
            if (act == Act.Saw && !g.Held(A)) actT = Mathf.Max(actT, actDur - 0.05f);
        }

        public List<Ability> ActiveAbilities()
        {
            var l = new List<Ability>();
            foreach (var a in B.abilities) if (!Info.Passive(a)) l.Add(a);
            return l;
        }

        void AI(ref float move, ref bool jump, bool free, float dt)
        {
            think -= dt;
            if (target == null) { move = 0; return; }
            Vector2 d = target.pos - pos;
            float dist = Mathf.Abs(d.x);
            int dir = d.x >= 0 ? 1 : -1;
            bool ranged = weapon != null && weapon.Ranged && ammo > 0;
            float reach = Reach();

            if (think <= 0f)
            {
                think = Random.Range(0.12f, 0.3f);
                pickupTarget = null;
                if (weapon == null)
                {
                    var pk = battle.NearestPickup(pos.x);
                    if (pk != null && (pk.landed || pk.pos.y < 3f) && Mathf.Abs(pk.pos.x - pos.x) < dist + 3f) pickupTarget = pk;
                }
                if (free) TryAbilities(dist, d);
                if (grounded && Random.value < 0.05f * B.agi) jump = true;
                if (d.y > 1.2f && dist < 4f && grounded) jump = true;

                if (ranged) aiMove = dist < 3.5f ? -dir : (dist > 9f ? dir : (dist < 5f ? -dir * 0.7f : 0f));
                else if (dist > reach * 0.85f) aiMove = dir;
                else if (dist < reach * 0.35f && Random.value < 0.4f) aiMove = -dir;
                else aiMove = Random.value < 0.15f ? -dir * 0.5f : 0f;
                if (pickupTarget != null) aiMove = Mathf.Sign(pickupTarget.pos.x - pos.x);
                if (Mathf.Abs(pos.x) > battle.W - 1.5f && aiMove != 0 && Mathf.Sign(aiMove) == Mathf.Sign(pos.x))
                {
                    aiMove = 0;
                    if (ranged && grounded) jump = true;
                }
            }
            move = aiMove;
            if (dodgeT > 0f)
            {
                dodgeT -= dt;
                if (dodgeT <= 0f && grounded) jump = true;
            }

            if (free && atkCd <= 0f && Mathf.Abs(d.y) < 1.6f * Size + 0.4f && battle.phase == Battle.Phase.Fight)
            {
                if (ranged && dist > 2.2f && dist < weapon.range) Attack(false);
                else if (weapon != null && weapon.kind == WeaponKind.Staff && dist > 3f && dist < 12f && staffCd <= 0f) Attack(false);
                else if (!ranged && dist <= reach) Attack(weapon == null ? Random.value < 0.35f : Random.value < 0.12f);
                else if (ranged && dist <= 1.3f) Attack(true);
            }
        }

        void TryAbilities(float dist, Vector2 d)
        {
            foreach (var a in B.abilities)
            {
                if (Info.Passive(a) || CooldownOf(a) > 0) continue;
                bool use = false;
                switch (a)
                {
                    case Ability.Fireball:
                    case Ability.IceShard: use = dist > 3f && dist < 13f && Mathf.Abs(d.y) < 2f && Random.value < 0.5f; break;
                    case Ability.Lightning: use = Random.value < 0.4f; break;
                    case Ability.Laser: use = dist > 2f && dist < 12f && Mathf.Abs(d.y) < 2.5f && Random.value < 0.4f; break;
                    case Ability.Teleport: use = (dist > 6f && Random.value < 0.4f) || (hp < maxHp * 0.3f && dist < 2f && Random.value < 0.3f); break;
                    case Ability.Dash: use = dist > 2.5f && dist < 8f && Mathf.Abs(d.y) < 1f && Random.value < 0.5f; break;
                    case Ability.Shield: use = (hp < maxHp * 0.6f || (target != null && target.WindingUp)) && dist < 5f && Random.value < 0.5f; break;
                    case Ability.GroundSlam: use = dist < 3.5f && grounded && Random.value < 0.4f; break;
                    case Ability.Invisibility: use = hp < maxHp * 0.7f && Random.value < 0.25f; break;
                    case Ability.Telekinesis: use = dist < 10f && Random.value < 0.35f; break;
                }
                if (use && UseAbility(a)) return;
            }
        }

        public void NotifyIncoming(float delay)
        {
            if (human || dead) return;
            if (Random.value < 0.3f * B.agi) dodgeT = Mathf.Max(0.02f, delay);
        }

        // Витрина в редакторе: персонаж показывает приёмы
        float Showroom(float dt)
        {
            facing = -1;
            demoT -= dt;
            float back = (Free && Mathf.Abs(pos.x) > 0.4f) ? -Mathf.Sign(pos.x) * 0.6f : 0f;
            if (demoT > 0f || !Free) return back;
            demoT = 2.2f;
            var acts = ActiveAbilities();
            int n = 2 + acts.Count;
            int k = demoStep % n;
            demoStep++;
            if (k == 0) Attack(false);
            else if (k == 1) Attack(true);
            else
            {
                var a = acts[k - 2];
                cd[a] = 0;
                if (a == Ability.Teleport || a == Ability.Telekinesis) { castAb = Ability.Telekinesis; StartAct(Act.Cast, 0.5f); cd[a] = 0; battle.fx.Smoke(Center, 10, new Color(0.5f, 0.3f, 0.8f, 0.6f), 0.5f, 0.5f); }
                else { aim = new Vector2(facing, 0); UseAbility(a); }
            }
            if (weapon != null && weapon.Ranged && ammo < 3) ammo = weapon.ammo > 0 ? weapon.ammo : 3;
            return 0f;
        }

        // ===================== ПОЗЫ =====================
        Pose RestPose()
        {
            Pose p = Pose.Guard;
            if (weapon != null)
            {
                switch (weapon.kind)
                {
                    case WeaponKind.Gun: p = Pose.GuardGun; break;
                    case WeaponKind.Spear: case WeaponKind.Staff: p = Pose.GuardSpear; break;
                    case WeaponKind.Blade: case WeaponKind.Blunt: case WeaponKind.Chainsaw: p = Pose.GuardBlade; break;
                }
            }
            p.lean += Mathf.Sin(animT * 3f) * 2f;
            p.a2 += Mathf.Sin(animT * 3f + 1f) * 3f;
            return p;
        }

        Pose TargetPose(float dt)
        {
            if (hurtT > 0 || stun > 0)
            {
                Pose h = Pose.Hurt;
                h.a1 += Mathf.Sin(animT * 20f) * 25f; h.b1 += Mathf.Cos(animT * 17f) * 25f;
                if (tkSlam) { h.f1 += Mathf.Sin(animT * 15f) * 30f; h.k1 += Mathf.Cos(animT * 13f) * 30f; }
                return h;
            }
            Pose rest = RestPose();
            float u = act != Act.None ? Mathf.Clamp01(actT / actDur) : 0f;
            switch (act)
            {
                case Act.Punch: return alt ? Pose.Attack(rest, Pose.Punch2W, Pose.Punch2S, u) : Pose.Attack(rest, Pose.PunchW, Pose.PunchS, u);
                case Act.Kick: return Pose.Attack(rest, Pose.KickW, Pose.KickS, u);
                case Act.Slash: return Pose.Attack(rest, Pose.SlashW, Pose.SlashS, u);
                case Act.Smash: return Pose.Attack(rest, Pose.SmashW, Pose.SmashS, u);
                case Act.Stab: return Pose.Attack(rest, Pose.StabW, Pose.StabS, u);
                case Act.Throw: return Pose.Attack(rest, Pose.ThrowW, Pose.ThrowS, u);
                case Act.Shoot:
                    {
                        Pose p = Pose.GuardGun;
                        float ang = Mathf.Atan2(aim.x * facing, -aim.y) * Mathf.Rad2Deg;
                        p.a1 = ang; p.a2 = ang;
                        if (weapon != null && weapon.kind == WeaponKind.Bow) { p.b1 = ang - 5f; p.b2 = ang + 160f * (1f - u * 0.5f); }
                        else if (u > 0.45f && u < 0.65f) { p.a2 += 10f; p.a1 += 5f; }
                        return p;
                    }
                case Act.Cast: return castAb == Ability.Lightning ? Pose.CastUp : Pose.Cast;
                case Act.Laser: { Pose p = Pose.Cast; p.lean = -6f; p.a1 = 40f; p.a2 = 150f; return p; }
                case Act.Block: return Pose.Block;
                case Act.Dash: return Pose.Dash;
                case Act.Saw:
                    {
                        Pose p = Pose.Saw;
                        p.a1 += Mathf.Sin(animT * 70f) * 3f; p.lean += Mathf.Sin(animT * 50f) * 2f;
                        return p;
                    }
            }
            if (!grounded)
            {
                if (slamPending) return vel.y > 0 ? Pose.AirUp : Pose.SmashW;
                return vel.y > 0 ? Pose.AirUp : Pose.AirDown;
            }
            if (battle.phase == Battle.Phase.Victory && battle.winner == team)
            {
                Pose v = Pose.Victory;
                v.a2 += Mathf.Sin(animT * 8f) * 10f; v.b2 += Mathf.Cos(animT * 8f) * 10f;
                return v;
            }
            if (Mathf.Abs(vel.x) > 0.6f)
            {
                runPhase += dt * Mathf.Abs(vel.x) * 2.1f / Size;
                bool ninja = (weapon == null || weapon.kind == WeaponKind.Blade) && B.spd > 1.2f;
                Pose r = Pose.Run(runPhase, ninja);
                if (weapon != null && !ninja) { r.a1 = 35f; r.a2 = weapon.kind == WeaponKind.Gun ? 80f : 95f; }
                if (Mathf.Sign(vel.x) != facing) { r = Pose.Lerp(r, rest, 0.4f); r.lean = -5f; }
                return r;
            }
            return rest;
        }

        // ===================== ОТРИСОВКА =====================
        void Render()
        {
            Vector2[] P = dead && rag != null ? rag.p : J;
            float s = Size;
            Color c = mainCol, cb = backCol;
            if (flash > 0) { c = Color.white; cb = Color.white; }
            else
            {
                if (burnT > 0) { float k = 0.35f + 0.15f * Mathf.Sin(animT * 20f); c = Color.Lerp(c, new Color(1f, 0.45f, 0.1f), k); cb = Color.Lerp(cb, new Color(1f, 0.45f, 0.1f), k); }
                if (slowT > 0) { c = Color.Lerp(c, new Color(0.55f, 0.85f, 1f), 0.4f); cb = Color.Lerp(cb, new Color(0.55f, 0.85f, 1f), 0.4f); }
                if (poisonT > 0) { c = Color.Lerp(c, new Color(0.4f, 0.9f, 0.2f), 0.3f); cb = Color.Lerp(cb, new Color(0.4f, 0.9f, 0.2f), 0.3f); }
                if (RageOn) { float k = 0.25f + 0.15f * Mathf.Sin(animT * 12f); c = Color.Lerp(c, Color.red, k); }
                if (dead) { c = Color.Lerp(c, new Color(0.25f, 0.25f, 0.25f), Mathf.Clamp01(deadTime * 0.15f)); cb = Color.Lerp(cb, new Color(0.2f, 0.2f, 0.2f), Mathf.Clamp01(deadTime * 0.15f)); }
            }
            float alpha = invisT > 0 ? (human ? 0.35f : 0.1f) : 1f;
            c.a = alpha; cb.a = alpha;

            Vector2 sh = P[1] + (P[0] - P[1]).normalized * 0.06f * s;
            Draw.Set(lLegB, P[0], P[9], P[10]); Draw.Col(lLegB, cb);
            Draw.Set(lLegF, P[0], P[7], P[8]); Draw.Col(lLegF, c);
            Draw.Set(lTorso, P[0], P[1]); Draw.Col(lTorso, c);
            Draw.Set(lArmB, sh, P[5], P[6]); Draw.Col(lArmB, cb);
            Draw.Set(lArmF, sh, P[3], P[4]); Draw.Col(lArmF, c);
            sHead.transform.position = P[2];
            sHead.color = c;

            if (glowLines != null)
            {
                Color gc = Draw.A(Color.Lerp(mainCol, Color.white, 0.3f), 0.22f * alpha * (dead ? 0.3f : 1f));
                Draw.Set(glowLines[0], P[0], P[9], P[10]);
                Draw.Set(glowLines[1], P[0], P[7], P[8]);
                Draw.Set(glowLines[2], P[0], (P[0] + P[1]) * 0.5f, P[1]);
                Draw.Set(glowLines[3], sh, P[5], P[6]);
                Draw.Set(glowLines[4], sh, P[3], P[4]);
                foreach (var g in glowLines) Draw.Col(g, gc);
                sHeadGlow.transform.position = P[2];
                sHeadGlow.color = Draw.A(mainCol, 0.45f * alpha * (dead ? 0.3f : 1f));
            }

            Vector2 hd = P[2] - P[1];
            float ang = Mathf.Atan2(hd.y, hd.x) * Mathf.Rad2Deg - 90f;
            if (dead && rag != null && rag.headOff) ang += deadTime * 0f;
            headRoot.position = P[2];
            headRoot.rotation = Quaternion.Euler(0, 0, ang);
            headRoot.localScale = new Vector3(facing, 1, 1);
            foreach (var r in headRends) SetAlpha(r, alpha);

            Vector2 fd = P[4] - P[3];
            weaponRoot.position = P[4];
            weaponRoot.rotation = Quaternion.Euler(0, 0, Mathf.Atan2(fd.y, fd.x) * Mathf.Rad2Deg);
            weaponRoot.localScale = new Vector3(1, facing, 1);
            foreach (var r in weaponRends) SetAlpha(r, alpha);

            float t = animT;
            float wind = -facing * 0.2f * s - vel.x * 0.012f;
            if (lCape != null)
            {
                Vector2 p = P[1] - new Vector2(facing * 0.06f * s, 0.02f);
                lCape.SetPosition(0, p);
                for (int i = 1; i < 6; i++)
                {
                    p += new Vector2(wind * (dead ? 0.3f : 1f), -0.17f * s + Mathf.Sin(t * 9f + i) * 0.03f);
                    if (p.y < 0.03f) p.y = 0.03f;
                    lCape.SetPosition(i, p);
                }
                var cc = lCape.startColor; cc.a = alpha; Draw.Col(lCape, cc);
            }
            if (lTails != null)
            {
                Vector2 back = (Vector2)headRoot.TransformPoint(new Vector3(-Skel.HeadR * s, Skel.HeadR * 0.25f * s, 0));
                Vector2 p = back;
                lTails.SetPosition(0, p);
                for (int i = 1; i < 4; i++)
                {
                    p += new Vector2(wind * 0.9f, -0.04f + Mathf.Sin(t * 14f + i * 1.3f) * 0.05f);
                    lTails.SetPosition(i, p);
                }
                var tc = lTails.startColor; tc.a = alpha; Draw.Col(lTails, tc);
            }
            if (lScarf != null)
            {
                Vector2 p = P[1];
                lScarf.SetPosition(0, p);
                for (int i = 1; i < 4; i++)
                {
                    p += new Vector2(wind * 0.8f, -0.06f + Mathf.Sin(t * 12f + i) * 0.04f);
                    lScarf.SetPosition(i, p);
                }
                var sc = lScarf.startColor; sc.a = alpha; Draw.Col(lScarf, sc);
            }

            bool sh_on = shieldT > 0 && !dead;
            lShield.enabled = sh_on; sShieldGlow.enabled = sh_on;
            if (sh_on)
            {
                Vector2 cen = Center;
                float r = 1.15f * s * (1f + Mathf.Sin(t * 10f) * 0.03f);
                for (int i = 0; i < 24; i++)
                {
                    float a = i / 24f * Mathf.PI * 2f;
                    lShield.SetPosition(i, cen + new Vector2(Mathf.Cos(a), Mathf.Sin(a) * 1.15f) * r);
                }
                Draw.Col(lShield, new Color(0.4f, 0.9f, 1f, shieldT < 0.8f ? 0.4f + 0.4f * Mathf.Sin(t * 30f) : 0.8f));
                sShieldGlow.transform.position = cen;
                sShieldGlow.transform.localScale = new Vector3(r * 2.4f, r * 2.7f, 1);
            }
        }

        static void SetAlpha(Renderer r, float a)
        {
            var lr = r as LineRenderer;
            if (lr != null)
            {
                var c = lr.startColor;
                if (Mathf.Abs(c.a - a) > 0.01f) { c.a = a; lr.startColor = c; lr.endColor = c; }
                return;
            }
            var sr = r as SpriteRenderer;
            if (sr != null)
            {
                if (sr.sprite == Draw.Soft) sr.enabled = a > 0.5f;
                else { var c = sr.color; c.a = a; sr.color = c; }
                return;
            }
            r.enabled = a > 0.5f;
        }
    }
}
