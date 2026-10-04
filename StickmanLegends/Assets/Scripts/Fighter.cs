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
        public float hp, maxHp, hpTrail;
        public bool dead;
        public float deadTime;
        public WeaponStats weapon;
        public int ammo;
        public readonly Vector2[] J = new Vector2[11];
        public int kills, maxCombo;
        public float dmgDealt;
        public int combo;
        public float comboT;

        public enum Act { None, Move, Shoot, Throw, Cast, Block, Dash, Saw, Laser, Roll, Flip, GetUp, ThrowSec }
        public enum BodyS { Normal, Tumble, Down }
        public Act act;
        public BodyS body;
        float actT, actDur;
        bool actFired;
        public Move mv;
        bool mvHit;
        readonly List<Fighter> mvHitList = new List<Fighter>();
        Move queued;
        int comboLeft;
        bool followAir;
        Ability castAb;
        bool castFromStaff;
        float staffCd;
        float atkCd, stun, hurtT, flash, iframes, landT, turnT;
        readonly Dictionary<Ability, float> cd = new Dictionary<Ability, float>();
        int jumps;
        public float shieldT, invisT, burnT, poisonT, slowT, bleedT, regenBlock;
        Fighter burnBy, poisonBy, bleedBy;
        bool slamPending;
        public bool tkSlam;
        Fighter tkBy;
        float animT, runPhase;
        Pose cur = Pose.Guard;
        Pose hurtPose = Pose.Hurt;
        Fighter target;
        float think, aiMove, dodgeT, demoT, tauntT;
        int demoStep;
        Pickup pickupTarget;
        public Ragdoll rag;
        float fountainT, dripT, sawTick, laserTick, ghostT, fxT, dustT, popupCd;
        bool pooled, headPooled;
        Vector2 aim = Vector2.right;
        readonly List<Fighter> dashHit = new List<Fighter>();
        float dotAcc;
        // пружинная анимация
        readonly float[] pv = new float[9];
        Vector2 prevTip;
        // второе оружие (ножи и т.п.), помощники
        public WeaponStats sec;
        public int secAmmo;
        float secCd;
        public bool minion, remove;
        public float life;
        Fighter owner;
        float downTarget, slideDustT;
        bool kipJumped;
        // кувырки / нокдаун
        float tumbleSpin, spinVel, downT, flipT = -1f, flipDur = 0.6f, flipDir = 1f, getUpFrom;
        bool bounced;
        int juggle, rollDir = 1;

        // --- визуал ---
        LineRenderer lTorso, lArmF, lArmB, lLegF, lLegB, lCape, lTails, lScarf, lShield, lLaser, lLaserGlow, lTrail;
        LineRenderer lArmor, lBelt, lBootF, lBootB, lTail;
        LineRenderer lShirt, lSleeveF, lSleeveB, lPantsF, lPantsB, lRobe, lCoat, lTie, lFootF, lFootB;
        SpriteRenderer sAura, sAura2, sFistF, sFistB;
        Color auraCol;
        float auraT;
        LineRenderer[] lWings;
        SpriteRenderer sGloveF, sGloveB, sPad;
        bool silhouette;
        public int lastRF = 1, styleMode;
        public float lastAlpha = 1f;
        public bool replaying;
        // рисованные стили: «дрожащая» линия, анимация на двойках, скетч/контур, призраки конечностей
        LineRenderer[] sketch;
        LineRenderer sketchHead, ghostA, ghostB;
        readonly Vector2[] disp = new Vector2[11], heldP = new Vector2[11], jit = new Vector2[11], jit2 = new Vector2[11];
        readonly Vector2[] g1 = new Vector2[3], g2 = new Vector2[3];
        bool g1ok, g2ok, heldOk;
        // классический стикман: трубки с контуром, суставы, яйцевидные кисти/стопы, голова с тенью, отбрасываемая тень
        bool classic;
        LineRenderer[] segF, shadowL;
        SpriteRenderer[] dotR, dotF;
        SpriteRenderer sHeadOut, sHeadShade, hOutF, hOutB, hFilF, hFilB, fOutF, fOutB, fFilF, fFilB, shadowHead;
        LineRenderer lNeckO, lNeckF;
        float boilT;
        int replayRF = 1;
        float replayAlpha = 1f;
        Color eyeCol = Color.red;
        LineRenderer[] under;
        SpriteRenderer sHead, sHeadUnder, sShieldGlow, sShadow;
        Transform headRoot, weaponRoot;
        readonly List<Renderer> headRends = new List<Renderer>();
        List<Renderer> weaponRends = new List<Renderer>();
        readonly List<Vector3> trailPts = new List<Vector3>();
        readonly List<float> trailAge = new List<float>();
        int baseOrder;
        bool glow, outline;
        Color backCol, mainCol, underCol;

        public float Size { get { return B.size; } }
        public Vector2 Center { get { return dead && rag != null && !replaying ? (rag.p[0] + rag.p[1]) * 0.5f : (J[0] + J[1]) * 0.5f; } }
        public Vector2 HeadPos { get { return dead && rag != null && !replaying ? rag.p[2] : J[2]; } }
        public bool Invisible { get { return invisT > 0; } }
        public bool RageOn { get { return B.HasAb(Ability.Rage) && hp < maxHp * 0.45f; } }
        public bool Free { get { return act == Act.None && stun <= 0 && hurtT <= 0 && !dead && body == BodyS.Normal; } }
        public bool Active { get { return act == Act.Move && mv != null && actT / actDur >= mv.hitAt && actT / actDur <= mv.hitAt + 0.15f; } }
        public bool WindingUp
        {
            get
            {
                if (act == Act.Move && mv != null) return actT / actDur < mv.hitAt;
                if (act == Act.Dash) return true;
                return false;
            }
        }
        public float CooldownOf(Ability a) { float v; return cd.TryGetValue(a, out v) ? Mathf.Max(0, v) : 0; }

        // ===================== СОЗДАНИЕ =====================
        public void Init(FighterBuild b, int team, int slot, Vector2 start, int face, Battle battle, bool glow)
        {
            B = b; this.team = team; this.slot = slot; this.battle = battle; this.glow = glow;
            outline = battle.theme.outline;
            hp = maxHp = hpTrail = b.hp;
            pos = start; facing = face;
            foreach (var a in b.abilities) cd[a] = Random.Range(0.5f, 2f);
            jumps = b.HasAb(Ability.DoubleJump) ? 1 : 0;
            Skel.Compute(cur, pos, Size, facing, J);
            baseOrder = 100 + (team * 5 + Mathf.Min(slot, 4)) * 20;
            silhouette = battle.theme.silhouette;
            if (b.accCol.ContainsKey(Acc.Eyes)) eyeCol = b.accCol[Acc.Eyes];
            if (silhouette) eyeCol = team == 0 ? new Color(1f, 0.15f, 0.1f) : new Color(0.2f, 0.7f, 1f);
            BuildVisual();
            SetWeapon(b.weapon != null ? b.weapon.Copy() : null, b.weapon != null ? b.weapon.ammo : 0);
            if (b.secondary != null) { sec = b.secondary.Copy(); secAmmo = Mathf.Max(1, sec.ammo); }
            Render();
        }

        void BuildVisual()
        {
            float s = Size;
            float w = Skel.Width * s;
            mainCol = silhouette ? new Color(0.05f, 0.05f, 0.06f) : B.color;
            float lum = mainCol.r * 0.3f + mainCol.g * 0.59f + mainCol.b * 0.11f;
            backCol = silhouette ? new Color(0.3f, 0.3f, 0.32f) : lum < 0.15f ? Color.Lerp(mainCol, new Color(0.45f, 0.45f, 0.47f), 0.45f) : Color.Lerp(mainCol, Color.black, 0.3f);

            sShadow = Draw.Spr(transform, "shadow", Draw.Soft, new Color(0, 0, 0, 0.35f), -1);

            if ((glow || outline) && !silhouette)
            {
                underCol = glow ? Draw.A(Color.Lerp(mainCol, Color.white, 0.3f), 0.22f) : battle.theme.outlineCol;
                if (outline && lum < 0.12f) underCol = new Color(0.95f, 0.95f, 0.95f, 0.9f);
                float uw = glow ? w * 2.8f : w + 0.07f * s;
                under = new LineRenderer[5];
                for (int i = 0; i < 5; i++)
                {
                    under[i] = Draw.Line(transform, "under", uw, underCol, baseOrder - 1, true, 6);
                    under[i].positionCount = 3;
                }
                sHeadUnder = Draw.Spr(transform, "headUnder", glow ? Draw.Soft : Draw.Circle, underCol, baseOrder - 1);
                sHeadUnder.transform.localScale = Vector3.one * (glow ? Skel.HeadR * 5f * s : (Skel.HeadR * 2f + 0.07f) * s);
            }

            lLegB = Draw.Line(transform, "legB", w, backCol, baseOrder + 0, true, 6);
            lArmB = Draw.Line(transform, "armB", w, backCol, baseOrder + 1, true, 6);
            lTorso = Draw.Line(transform, "torso", w * 1.12f, mainCol, baseOrder + 3, true, 6);
            lLegF = Draw.Line(transform, "legF", w, mainCol, baseOrder + 6, true, 6);
            lArmF = Draw.Line(transform, "armF", w, mainCol, baseOrder + 12, true, 6);
            sHead = Draw.Spr(transform, "head", Draw.Circle, mainCol, baseOrder + 8);
            sHead.transform.localScale = Vector3.one * Skel.HeadR * 2f * s;

            headRoot = new GameObject("headRoot").transform;
            headRoot.SetParent(transform, false);
            weaponRoot = new GameObject("weaponRoot").transform;
            weaponRoot.SetParent(transform, false);

            BuildAccessories();
            BuildClassic();

            lTrail = Draw.Line(transform, "trail", 1f, Color.white, baseOrder + 14, true, 2);
            sketch = new LineRenderer[5];
            for (int i = 0; i < 5; i++) { sketch[i] = Draw.Line(transform, "sketch", 0.04f, Color.black, baseOrder + 15, true, 3); sketch[i].positionCount = 3; sketch[i].enabled = false; }
            sketchHead = Draw.Line(transform, "sketchHead", 0.04f, Color.black, baseOrder + 15, true, 0);
            sketchHead.loop = true; sketchHead.positionCount = 18; sketchHead.enabled = false;
            ghostA = Draw.Line(transform, "ghostA", w, mainCol, baseOrder + 10, true, 5); ghostA.positionCount = 3; ghostA.enabled = false;
            ghostB = Draw.Line(transform, "ghostB", w, mainCol, baseOrder + 10, true, 5); ghostB.positionCount = 3; ghostB.enabled = false;
            lTrail.enabled = false;

            lShield = Draw.Line(transform, "shield", 0.06f, new Color(0.4f, 0.9f, 1f, 0.8f), baseOrder + 17, true, 0);
            lShield.loop = true;
            lShield.positionCount = 24;
            lShield.enabled = false;
            sShieldGlow = Draw.Spr(transform, "shieldGlow", Draw.Soft, new Color(0.4f, 0.9f, 1f, 0.2f), baseOrder + 16);
            sShieldGlow.enabled = false;

            lLaserGlow = Draw.Line(transform, "laserGlow", 0.45f, new Color(1f, 0.1f, 0.1f, 0.35f), 340, true, 2);
            lLaser = Draw.Line(transform, "laser", 0.12f, new Color(1f, 0.9f, 0.9f, 1f), 341, true, 2);
            lLaser.enabled = lLaserGlow.enabled = false;
        }

        void BuildAccessories()
        {
            float s = Size;
            int o = baseOrder + 9;
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

            BuildGear();

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

        Color AccC(Acc a, Color def) { Color c; return B.accCol.TryGetValue(a, out c) ? c : def; }

        // Снаряжение из описания: шлем, броня, маска, капюшон, волосы, борода, глаза, крылья, хвост, пояс, перчатки, сапоги
        void BuildGear()
        {
            float s = Size, hr = Skel.HeadR * s, w = Skel.Width * s;
            int o = baseOrder + 9;
            Color steel = new Color(0.62f, 0.65f, 0.7f);
            bool eyes = B.acc.Contains(Acc.Eyes) || silhouette;
            foreach (var a in B.acc)
            {
                switch (a)
                {
                    case Acc.Helmet:
                        {
                            Color c = AccC(a, steel);
                            var pts = new List<Vector2>();
                            float r = hr * 1.14f;
                            if (B.knightHelm)
                            {
                                for (int i = 0; i <= 16; i++) { float ang = Mathf.Lerp(-80f, 260f, i / 16f) * Mathf.Deg2Rad; pts.Add(new Vector2(Mathf.Cos(ang) * r, Mathf.Sin(ang) * r)); }
                                headRends.Add(Draw.Poly(headRoot, pts.ToArray(), c, o, "helm"));
                                var slit = Draw.Line(headRoot, "slit", 0.05f * s, new Color(0.05f, 0.05f, 0.05f), o + 1, false, 0);
                                Draw.Set(slit, new Vector2(hr * 0.15f, hr * 0.12f), new Vector2(r, hr * 0.12f));
                                headRends.Add(slit);
                                var crest = Draw.Line(headRoot, "crest", 1f, AccC(Acc.Helmet, new Color(0.8f, 0.1f, 0.1f)) == c ? new Color(0.8f, 0.1f, 0.1f) : c, o - 1, false, 2);
                                Draw.Set(crest, new List<Vector2> { new Vector2(hr * 0.5f, r * 0.9f), new Vector2(-hr * 0.2f, r * 1.35f), new Vector2(-hr * 1.2f, r * 1.1f) });
                                Draw.Taper(crest, 0.1f * s, 0.02f * s);
                                headRends.Add(crest);
                            }
                            else
                            {
                                for (int i = 0; i <= 12; i++) { float ang = Mathf.Lerp(-5f, 185f, i / 12f) * Mathf.Deg2Rad; pts.Add(new Vector2(Mathf.Cos(ang) * r, Mathf.Sin(ang) * r + hr * 0.08f)); }
                                headRends.Add(Draw.Poly(headRoot, pts.ToArray(), c, o, "helm"));
                                var rim = Draw.Line(headRoot, "rim", 0.07f * s, Draw.Mul(c, 0.7f), o + 1, false, 2);
                                Draw.Set(rim, new Vector2(-r * 1.05f, hr * 0.05f), new Vector2(r * 1.1f, hr * 0.05f));
                                headRends.Add(rim);
                            }
                            break;
                        }
                    case Acc.Mask:
                        {
                            Color c = AccC(a, new Color(0.1f, 0.1f, 0.12f));
                            var pts = new List<Vector2> { new Vector2(hr * 0.05f, hr * 0.02f) };
                            for (int i = 0; i <= 8; i++) { float ang = Mathf.Lerp(10f, -85f, i / 8f) * Mathf.Deg2Rad; pts.Add(new Vector2(Mathf.Cos(ang) * hr * 1.05f, Mathf.Sin(ang) * hr * 1.05f)); }
                            pts.Add(new Vector2(hr * 0.05f, -hr * 0.9f));
                            headRends.Add(Draw.Poly(headRoot, pts.ToArray(), c, o, "mask"));
                            break;
                        }
                    case Acc.Hood:
                        {
                            Color c = AccC(a, Draw.Mul(mainCol.grayscale < 0.1f ? new Color(0.25f, 0.22f, 0.3f) : mainCol, 0.6f));
                            var hood = Draw.Spr(headRoot, "hood", Draw.Circle, c, baseOrder + 7);
                            hood.transform.localPosition = new Vector3(-hr * 0.22f, hr * 0.12f, 0);
                            hood.transform.localScale = Vector3.one * hr * 2.7f;
                            headRends.Add(hood);
                            var tip = Draw.Line(headRoot, "hoodTip", 1f, c, baseOrder + 7, false, 2);
                            Draw.Set(tip, new List<Vector2> { new Vector2(-hr * 0.6f, hr * 0.9f), new Vector2(-hr * 1.3f, hr * 0.7f), new Vector2(-hr * 1.8f, hr * 0.1f) });
                            Draw.Taper(tip, 0.25f * s, 0.02f);
                            headRends.Add(tip);
                            break;
                        }
                    case Acc.Hair:
                        {
                            Color c = AccC(a, new Color(0.18f, 0.12f, 0.08f));
                            for (int i = 0; i < 5; i++)
                            {
                                float ang = Mathf.Lerp(70f, 190f, i / 4f) * Mathf.Deg2Rad;
                                Vector2 d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                                var sp = Draw.Line(headRoot, "hair", 1f, c, baseOrder + 7, false, 1);
                                Vector2 bend = new Vector2(-0.3f, 0.1f) * hr;
                                Draw.Set(sp, new List<Vector2> { d * hr * 0.6f, d * hr * 1.25f + bend * 0.5f, d * hr * (1.6f + (i % 2) * 0.25f) + bend });
                                Draw.Taper(sp, 0.18f * s, 0.01f);
                                headRends.Add(sp);
                            }
                            break;
                        }
                    case Acc.Beard:
                        {
                            Color c = AccC(a, new Color(0.35f, 0.22f, 0.1f));
                            headRends.Add(Draw.Poly(headRoot, new[] { new Vector2(hr * 0.1f, -hr * 0.45f), new Vector2(hr * 1.0f, -hr * 0.2f), new Vector2(hr * 0.75f, -hr * 1.25f), new Vector2(hr * 0.2f, -hr * 0.95f) }, c, o, "beard"));
                            break;
                        }
                    case Acc.Wings:
                        {
                            Color c = AccC(a, B.acc.Contains(Acc.Horns) ? new Color(0.25f, 0.05f, 0.08f) : new Color(0.97f, 0.97f, 1f));
                            lWings = new LineRenderer[2];
                            for (int i = 0; i < 2; i++)
                            {
                                lWings[i] = Draw.Line(transform, "wing", 1f, i == 0 ? c : Draw.Mul(c, 0.8f), baseOrder - 3 + i, true, 3);
                                Draw.Taper(lWings[i], 0.45f * s, 0.05f * s);
                                lWings[i].positionCount = 4;
                            }
                            break;
                        }
                    case Acc.Tail:
                        lTail = Draw.Line(transform, "tail", 1f, AccC(a, backCol), baseOrder - 1, true, 3);
                        Draw.Taper(lTail, 0.14f * s, 0.02f * s);
                        lTail.positionCount = 5;
                        break;
                    case Acc.Armor:
                        lArmor = Draw.Line(transform, "armor", w * 1.85f, AccC(a, steel), baseOrder + 4, true, 2);
                        break;
                    case Acc.ShoulderPads:
                        sPad = Draw.Spr(transform, "pad", Draw.Circle, AccC(a, AccC(Acc.Armor, steel)), baseOrder + 13);
                        sPad.transform.localScale = Vector3.one * 0.34f * s;
                        break;
                    case Acc.Belt:
                        lBelt = Draw.Line(transform, "belt", 0.09f * s, AccC(a, new Color(0.35f, 0.2f, 0.08f)), baseOrder + 5, true, 0);
                        break;
                    case Acc.Gloves:
                        {
                            Color c = AccC(a, new Color(0.15f, 0.15f, 0.15f));
                            sGloveF = Draw.Spr(transform, "gloveF", Draw.Circle, c, baseOrder + 13);
                            sGloveB = Draw.Spr(transform, "gloveB", Draw.Circle, Draw.Mul(c, 0.75f), baseOrder + 2);
                            sGloveF.transform.localScale = sGloveB.transform.localScale = Vector3.one * w * 1.55f;
                            break;
                        }
                    case Acc.Boots:
                        {
                            Color c = AccC(a, new Color(0.2f, 0.13f, 0.07f));
                            lBootF = Draw.Line(transform, "bootF", w * 1.35f, c, baseOrder + 7, true, 2);
                            lBootB = Draw.Line(transform, "bootB", w * 1.35f, Draw.Mul(c, 0.75f), baseOrder + 1, true, 2);
                            break;
                        }
                }
            }
            if (B.acc.Contains(Acc.Aura))
            {
                auraCol = AccC(Acc.Aura, Color.Lerp(mainCol, Color.white, 0.4f));
                sAura = Draw.Spr(transform, "aura", Draw.Soft, Draw.A(auraCol, 0.55f), baseOrder - 4);
                sAura2 = Draw.Spr(transform, "aura2", Draw.Soft, Draw.A(Color.Lerp(auraCol, Color.white, 0.5f), 0.35f), baseOrder - 4);
            }
            if (B.acc.Contains(Acc.Shirt))
            {
                Color c = AccC(Acc.Shirt, new Color(0.92f, 0.92f, 0.9f));
                lShirt = Draw.Line(transform, "shirt", w * 1.55f, c, baseOrder + 4, true, 2);
                lSleeveF = Draw.Line(transform, "sleeveF", w * 1.3f, c, baseOrder + 13, true, 2);
                lSleeveB = Draw.Line(transform, "sleeveB", w * 1.3f, Draw.Mul(c, 0.8f), baseOrder + 1, true, 2);
            }
            if (B.acc.Contains(Acc.Pants))
            {
                Color c = AccC(Acc.Pants, new Color(0.15f, 0.2f, 0.45f));
                lPantsF = Draw.Line(transform, "pantsF", w * 1.3f, c, baseOrder + 7, true, 3);
                lPantsB = Draw.Line(transform, "pantsB", w * 1.3f, Draw.Mul(c, 0.8f), baseOrder + 0, true, 3);
                lPantsF.positionCount = lPantsB.positionCount = 3;
            }
            if (B.acc.Contains(Acc.Robe))
            {
                Color c = AccC(Acc.Robe, new Color(0.85f, 0.45f, 0.1f));
                lRobe = Draw.Line(transform, "robe", 1f, c, baseOrder + 7, true, 2);
                Draw.Taper(lRobe, 0.32f * s, 0.85f * s);
                lRobe.positionCount = 3;
                if (lShirt == null)
                {
                    lShirt = Draw.Line(transform, "robeTop", w * 1.6f, c, baseOrder + 4, true, 2);
                    lSleeveF = Draw.Line(transform, "sleeveF", w * 1.6f, c, baseOrder + 13, true, 2);
                    lSleeveB = Draw.Line(transform, "sleeveB", w * 1.6f, Draw.Mul(c, 0.8f), baseOrder + 1, true, 2);
                }
            }
            if (B.acc.Contains(Acc.Coat))
            {
                Color c = AccC(Acc.Coat, new Color(0.12f, 0.12f, 0.14f));
                lCoat = Draw.Line(transform, "coatTails", 1f, Draw.Mul(c, 0.9f), baseOrder + 2, true, 2);
                Draw.Taper(lCoat, 0.3f * s, 0.42f * s);
                lCoat.positionCount = 4;
                if (lShirt == null) lShirt = Draw.Line(transform, "coat", w * 1.6f, c, baseOrder + 4, true, 2);
                if (lSleeveF == null)
                {
                    lSleeveF = Draw.Line(transform, "sleeveF", w * 1.35f, c, baseOrder + 13, true, 2);
                    lSleeveB = Draw.Line(transform, "sleeveB", w * 1.35f, Draw.Mul(c, 0.8f), baseOrder + 1, true, 2);
                }
            }
            if (B.acc.Contains(Acc.Tie)) lTie = Draw.Line(transform, "tie", 1f, AccC(Acc.Tie, new Color(0.8f, 0.1f, 0.1f)), baseOrder + 5, true, 0);
            if (lTie != null) Draw.Taper(lTie, 0.09f * s, 0.05f * s);
            // крупные круглые кулаки и стопы, как в стикмен-анимациях
            if (!B.acc.Contains(Acc.Gloves))
            {
                sFistF = Draw.Spr(transform, "fistF", Draw.Circle, mainCol, baseOrder + 12);
                sFistB = Draw.Spr(transform, "fistB", Draw.Circle, backCol, baseOrder + 1);
                sFistF.transform.localScale = sFistB.transform.localScale = Vector3.one * w * 1.35f;
            }
            if (!B.acc.Contains(Acc.Boots))
            {
                lFootF = Draw.Line(transform, "footF", w * 1.1f, mainCol, baseOrder + 6, true, 4);
                lFootB = Draw.Line(transform, "footB", w * 1.1f, backCol, baseOrder + 0, true, 4);
            }
            if (eyes)
            {
                var e = Draw.Line(headRoot, "eye", 1f, eyeCol, o + 2, false, 1);
                Draw.Set(e, new Vector2(hr * 0.28f, hr * 0.22f), new Vector2(hr * 0.85f, hr * 0.08f));
                Draw.Taper(e, 0.07f * s, 0.035f * s);
                var g = Draw.Spr(headRoot, "eyeGlow", Draw.Soft, Draw.A(eyeCol, 0.7f), o + 1);
                g.transform.localPosition = new Vector3(hr * 0.6f, hr * 0.15f, 0);
                g.transform.localScale = new Vector3(hr * 2.4f, hr * 1.2f, 1);
                headRends.Add(e); headRends.Add(g);
            }
        }

        public void SetWeapon(WeaponStats w, int am)
        {
            foreach (Transform c in weaponRoot) Destroy(c.gameObject);
            weaponRends.Clear();
            weapon = w;
            ammo = am;
            if (w != null) weaponRends = WeaponVisual.Build(weaponRoot, w, Size, baseOrder + 11, glow);
        }

        // ===================== ОБНОВЛЕНИЕ =====================
        public void Tick(float dt)
        {
            if (dt <= 0f) { Render(); return; }
            animT += dt;
            hpTrail = Mathf.MoveTowards(hpTrail, hp, dt * maxHp * (hpTrail - hp > maxHp * 0.3f ? 0.9f : 0.35f));
            if (dead) { DeadTick(dt); Render(); return; }

            flash -= dt; hurtT -= dt; stun -= dt; atkCd -= dt; shieldT -= dt; invisT -= dt; regenBlock -= dt; slowT -= dt; staffCd -= dt;
            iframes -= dt; landT -= dt; popupCd -= dt; comboT -= dt; secCd -= dt;
            if (minion)
            {
                life -= dt;
                if (life <= 0f || owner == null || owner.dead)
                {
                    battle.fx.Smoke(Center, 16, new Color(0.5f, 0.4f, 0.7f, 0.6f), 0.5f, 0.6f);
                    remove = true; dead = true;
                    gameObject.SetActive(false);
                    return;
                }
            }
            if (comboT <= 0f) combo = 0;
            foreach (var k in B.abilities) cd[k] = CooldownOf(k) - dt;

            Status(dt);
            if (dead) { Render(); return; }

            target = battle.FindTarget(this);
            float move = 0; bool jump = false;
            bool free = Free;
            if (battle.mode == Battle.Mode.Showroom) move = Showroom(dt);
            else if (battle.phase == Battle.Phase.Fight && body == BodyS.Normal)
            {
                if (human) HumanInput(ref move, ref jump, free);
                else AI(ref move, ref jump, free, dt);
            }

            if (body == BodyS.Down) DownTick(dt);
            if (body == BodyS.Tumble) { spinVel *= 1f - Mathf.Min(1f, dt * 0.9f); tumbleSpin += spinVel * dt; }

            // разворот: человек — мгновенно, ИИ — с небольшой задержкой (можно зайти за спину!)
            if (act == Act.None && stun <= 0 && hurtT <= 0 && body == BodyS.Normal && battle.mode != Battle.Mode.Showroom)
            {
                if (human && Mathf.Abs(move) > 0.1f) facing = move > 0 ? 1 : -1;
                else if (target != null)
                {
                    int want = target.pos.x >= pos.x ? 1 : -1;
                    if (want != facing)
                    {
                        turnT += dt;
                        if (human || turnT > 0.2f / Mathf.Sqrt(B.agi)) { facing = want; turnT = 0; }
                    }
                    else turnT = 0;
                }
            }

            Physics(dt, move, jump);
            ActTick(dt);
            if (body == BodyS.Normal) TryPickup();
            MotionFx(dt);

            Pose tgt = TargetPose(dt);
            // пружинная анимация: резкий удар с небольшим «перелётом» и отдачей
            float sk, sz;
            if (act == Act.Move || act == Act.Shoot || act == Act.Throw || act == Act.ThrowSec) { sk = 2600f; sz = 0.48f; }
            else if (hurtT > 0 || stun > 0) { sk = 1100f; sz = 0.32f; }
            else if (body != BodyS.Normal || act == Act.Roll || act == Act.Flip || act == Act.GetUp) { sk = 1500f; sz = 0.7f; }
            else if (!grounded) { sk = 900f; sz = 0.6f; }
            else { sk = 650f; sz = 0.62f; }
            SpringPose(tgt, dt, sk, sz);
            Skel.Compute(cur, pos, Size, RenderFacing(), J, grounded);
            Stretch();
            TrailTick(dt);
            Render();
        }

        void SpringPose(Pose tgt, float dt, float k, float zeta)
        {
            float c = 2f * zeta * Mathf.Sqrt(k);
            int n = Mathf.Clamp(Mathf.CeilToInt(dt / 0.006f), 1, 12);
            float h = dt / n;
            for (int step = 0; step < n; step++)
                for (int i = 0; i < 9; i++)
                {
                    float x = cur[i];
                    float a = (tgt[i] - x) * k - pv[i] * c;
                    pv[i] += a * h;
                    cur[i] = x + pv[i] * h;
                }
            cur.spin = tgt.spin;
        }

        // растяжение бьющей конечности в момент удара (squash & stretch)
        void Stretch()
        {
            if (act != Act.Move || mv == null) return;
            float u = actT / actDur;
            float d = (u - mv.hitAt) / 0.1f;
            float st = Mathf.Exp(-d * d) * 0.3f;
            if (st < 0.01f) return;
            int limb = mv.limb == 4 ? 0 : mv.limb;
            int root = limb < 2 ? 1 : 0, mid = 3 + limb * 2, tip = mid + 1;
            if (limb >= 2) { mid = limb == 2 ? 7 : 9; tip = mid + 1; }
            else { mid = limb == 0 ? 3 : 5; tip = mid + 1; }
            Vector2 d1 = J[mid] - J[root], d2 = J[tip] - J[mid];
            J[mid] = J[root] + d1 * (1f + st * 0.5f);
            J[tip] = J[mid] + d2 * (1f + st);
        }

        int RenderFacing()
        {
            if (act == Act.Move && mv != null && mv.flip)
            {
                float u = actT / actDur;
                if (u > 0.1f && u < mv.hitAt - 0.04f) return -facing; // разворот спиной — вертушка
            }
            return facing;
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
            float spd = 7f * B.spd * (slowT > 0 ? 0.5f : 1f) * (RageOn ? 1.25f : 1f);
            float u = act != Act.None ? actT / Mathf.Max(0.01f, actDur) : 0f;
            if (body == BodyS.Tumble) vel.x *= 1f - dt * 0.4f;
            else if (body == BodyS.Down) vel.x = Mathf.MoveTowards(vel.x, 0, 18f * dt);
            else if (act == Act.Dash) vel.x = facing * 24f;
            else if (act == Act.Roll) vel.x = rollDir * 11f * Mathf.Sqrt(B.agi);
            else if (act == Act.Flip) { }
            else if (stun > 0 || hurtT > 0) vel.x = Mathf.MoveTowards(vel.x, 0, (grounded ? 14f : 2f) * dt);
            else if (act == Act.Move && mv != null)
            {
                float w0 = mv.hitAt * 0.7f;
                if (grounded && mv.hopX == 0)
                {
                    float lunge = (u > w0 && u < mv.hitAt + 0.08f) ? facing * mv.lunge * Mathf.Sqrt(B.spd) : 0f;
                    vel.x = Mathf.MoveTowards(vel.x, lunge, 60f * dt);
                }
            }
            else if (act != Act.None && act != Act.Saw)
            {
                if (grounded) vel.x = Mathf.MoveTowards(vel.x, 0, 40f * dt);
            }
            else
            {
                float t = move * spd;
                vel.x = Mathf.MoveTowards(vel.x, t, (grounded ? 70f : 32f) * dt);
            }

            if (jump && stun <= 0 && hurtT <= 0 && body == BodyS.Normal && (act == Act.None || act == Act.Block))
            {
                float jv = 15f * Mathf.Sqrt(B.agi);
                if (grounded)
                {
                    vel.y = jv; grounded = false; act = Act.None;
                    battle.fx.Dust(pos, 5);
                    if (B.style == Style.Acrobat || Random.value < 0.25f * B.agi) StartAirFlip(Mathf.Abs(vel.x) > 2f && Mathf.Sign(vel.x) == facing ? -1f : 1f);
                }
                else if (Mathf.Abs(pos.x) > battle.W - 0.55f)
                {
                    // отскок от стены
                    float side = Mathf.Sign(pos.x);
                    vel = new Vector2(-side * 11f, jv * 0.95f);
                    facing = -(int)side;
                    battle.fx.Dust(new Vector2(side * (battle.W - 0.2f), pos.y + 0.5f), 6);
                    battle.audio.Sfx("whoosh", 0.5f);
                    StartAirFlip(1f);
                    jumps = B.HasAb(Ability.DoubleJump) ? 1 : 0;
                }
                else if (jumps > 0)
                {
                    jumps--;
                    vel.y = jv * 0.95f;
                    battle.Shock(pos, 0.9f, Draw.A(battle.theme.ink, 0.6f));
                    battle.audio.Sfx("whoosh", 0.4f);
                    StartAirFlip(-1f);
                }
            }

            float g = -38f;
            if (body == BodyS.Tumble) g *= 0.72f + 0.12f * juggle;
            if (act == Act.Laser || (act == Act.Cast && !grounded)) g *= 0.25f;
            if (act == Act.Move && mv != null && mv.air && !mv.slam && u < mv.hitAt + 0.1f) g *= 0.35f; // зависание в воздухе на ударе
            if (tkSlam && vel.y < 0) g *= 2.5f;
            if (slamPending && vel.y < 0) g *= 2f;
            vel.y += g * dt;
            pos += vel * dt;

            if (pos.y <= 0f)
            {
                bool was = grounded;
                pos.y = 0f;
                if (!was) Land();
                if (vel.y > 0.01f) { grounded = false; pos.y = 0.01f; }
                else { vel.y = 0; grounded = true; }
            }
            else grounded = false;

            float lim = battle.W - 0.3f;
            if (Mathf.Abs(pos.x) > lim)
            {
                if (Mathf.Abs(vel.x) > 8f && (body == BodyS.Tumble || hurtT > 0))
                {
                    // удар об стену — отскок
                    float sp = Mathf.Abs(vel.x);
                    vel.x = -vel.x * 0.45f;
                    vel.y = Mathf.Max(vel.y, 5f);
                    body = BodyS.Tumble; bounced = false;
                    Vector2 wp = new Vector2(Mathf.Sign(pos.x) * (battle.W + 0.2f), Center.y);
                    battle.fx.Blood(wp, new Vector2(Mathf.Sign(pos.x), 0.3f), 14);
                    battle.Crack(wp, true);
                    battle.HitSpark(wp, new Vector2(-Mathf.Sign(pos.x), 0), 1.2f, battle.theme.ink);
                    battle.cam.Shake(0.4f);
                    battle.audio.Sfx("thud", 0.9f);
                    RawDamage(sp * 0.6f, DmgType.Blunt, null, true, HF.Fall);
                }
                else vel.x *= -0.2f;
                pos.x = Mathf.Sign(pos.x) * lim;
            }

            if (act == Act.Roll || body != BodyS.Normal) return;
            foreach (var e in battle.fighters)
            {
                if (e == this || e.dead || e.team == team || e.body != BodyS.Normal || e.act == Act.Roll) continue;
                float dx = pos.x - e.pos.x;
                float min = 0.42f * (Size + e.Size);
                if (Mathf.Abs(dx) < min && Mathf.Abs(pos.y - e.pos.y) < 1.4f)
                {
                    float sgn = Mathf.Abs(dx) < 0.001f ? -facing : Mathf.Sign(dx);
                    pos.x += sgn * (min - Mathf.Abs(dx)) * 0.5f;
                }
            }
        }

        void StartAirFlip(float dir)
        {
            flipT = 0f; flipDir = dir;
            flipDur = Mathf.Clamp(vel.y / 38f * 1.6f, 0.4f, 0.75f);
        }

        void Land()
        {
            flipT = -1f;
            if (tkSlam)
            {
                tkSlam = false;
                var h = new HitInfo { dmg = 18f, type = DmgType.Blunt, attacker = tkBy, dir = Vector2.down, point = pos + Vector2.up * 0.3f, knock = 2f, stun = 0.5f, heavy = true, knockdown = true, extra = HF.Fall | HF.Magic };
                battle.Shock(pos, 2.2f, new Color(0.7f, 0.4f, 1f, 0.8f));
                battle.Crack(pos, false);
                battle.fx.Dust(pos, 20);
                TakeHit(h);
                if (dead) return;
            }
            if (body == BodyS.Tumble)
            {
                float sp = Mathf.Repeat(tumbleSpin + 180f, 360f) - 180f;
                tumbleSpin = sp;
                if (vel.y < -9f && !bounced)
                {
                    // удар всем телом о землю и отскок
                    bounced = true;
                    float vy = vel.y;
                    vel.y = Mathf.Min(5.5f, -vy * 0.32f);
                    vel.x *= 0.85f;
                    spinVel = Mathf.Sign(sp == 0 ? 1 : sp) * Mathf.Min(Mathf.Abs(spinVel) * 0.5f + 120f, 300f);
                    battle.fx.Dust(pos, 18);
                    battle.Shock(pos, 1.6f, Draw.A(battle.theme.ink, 0.5f));
                    battle.cam.Shake(0.35f);
                    battle.cam.Kick(0.4f);
                    battle.audio.Sfx("thud", 1f);
                    if (vy < -16f) { battle.Crack(pos, false); battle.HitSpark(pos + Vector2.up * 0.1f, Vector2.up, 1.3f, battle.theme.ink); }
                    RawDamage(2f + Mathf.Abs(vy) * 0.25f, DmgType.Blunt, null, true, HF.Fall);
                    return;
                }
                // ложится: на спину или на живот, скользит по земле
                body = BodyS.Down;
                downTarget = sp >= -10f ? 90f : -90f;
                downT = human ? 0.6f : Random.Range(0.55f, 1.0f) / Mathf.Sqrt(B.agi);
                vel.y = 0;
                vel.x *= 0.9f;
                battle.fx.Dust(pos, 12);
                battle.audio.Sfx("thud", 0.7f);
                juggle = 0;
                return;
            }
            if (vel.y < -10f)
            {
                battle.fx.Dust(pos, 8);
                battle.audio.Sfx("thud", 0.3f);
                landT = 0.12f;
            }
            jumps = B.HasAb(Ability.DoubleJump) ? 1 : 0;
            if (slamPending) { slamPending = false; DoSlam(); }
            if (act == Act.Move && mv != null && mv.air) { act = Act.None; landT = 0.15f; battle.fx.Dust(pos, 6); }
        }

        void DownTick(float dt)
        {
            downT -= dt;
            tumbleSpin = Mathf.MoveTowards(tumbleSpin, downTarget, 700f * dt);
            if (Mathf.Abs(vel.x) > 1f && grounded)
            {
                slideDustT -= dt;
                if (slideDustT <= 0f) { slideDustT = 0.05f; battle.fx.Dust(Center - Vector2.up * 0.3f, 1); if (bleedT > 0) battle.fx.Drip(Center); }
            }
            if (downT > 0f || !grounded) return;
            body = BodyS.Normal;
            act = Act.GetUp;
            actT = 0;
            kipJumped = false;
            getUpFrom = downTarget;
            bool kip = (B.style == Style.Acrobat || B.agi > 1.3f) && getUpFrom > 0;
            actDur = kip ? 0.55f : 0.8f / Mathf.Sqrt(B.agi);
            iframes = actDur * 0.85f;
            hurtT = 0; stun = 0;
        }

        void MotionFx(float dt)
        {
            float sp = vel.magnitude;
            if (sp > 13f && (body == BodyS.Tumble || act == Act.Dash || act == Act.Roll || hurtT > 0 || (act == Act.Move && mv != null && mv.hopX > 0)))
            {
                int n = Mathf.Max(1, (int)(dt * 60));
                for (int i = 0; i < n; i++)
                {
                    Vector2 p = Center + new Vector2(Random.Range(-0.6f, 0.6f), Random.Range(-1f, 1f)) * Size - vel.normalized * 0.8f;
                    battle.fx.Emit(p, Vector2.zero, Draw.A(battle.theme.ink, 0.45f), 0.06f, 0.14f, 0f, false, 0f, true, 16f, 0.5f);
                }
            }
            if (grounded && Mathf.Abs(vel.x) > 6f && body == BodyS.Normal)
            {
                dustT -= dt;
                if (dustT <= 0f) { dustT = 0.12f; battle.fx.Dust(pos, 1); }
            }
        }

        // ===================== ПРИЁМЫ =====================
        void StartAct(Act a, float dur)
        {
            act = a; actT = 0; actDur = Mathf.Max(0.08f, dur); actFired = false;
            if (a != Act.Block && a != Act.Roll && a != Act.Flip && a != Act.GetUp) battle.OnAttackStart(this);
        }

        public float Reach()
        {
            if (weapon != null && !weapon.Ranged) return weapon.range * Size;
            return 1.05f * Size;
        }

        bool MeleeWeapon { get { return weapon != null && !weapon.Ranged && weapon.kind != WeaponKind.Chainsaw; } }

        public void StartMove(Move m)
        {
            if (m == null) return;
            if (m.weapon && !MeleeWeapon) return;
            mv = m;
            act = Act.Move; actT = 0; actFired = false;
            float sp = Mathf.Sqrt(B.spd) * (RageOn ? 1.2f : 1f);
            float r = (m.weapon && weapon != null) ? Mathf.Sqrt(weapon.rate) : 1f;
            actDur = Mathf.Max(0.12f, m.dur / (sp * r) * (B.style == Style.Brute ? 1.1f : 1f));
            mvHit = false; mvHitList.Clear(); queued = null;
            if (m.hopX != 0 || m.hopY != 0)
            {
                vel = new Vector2(facing * m.hopX, Mathf.Max(vel.y, m.hopY));
                if (m.hopY > 0) grounded = false;
            }
            if (m.air && !grounded && vel.y < 2f) vel.y = 2f;
            ClearTrail();
            battle.OnAttackStart(this);
            if (m.heavy || m.flip) battle.audio.Sfx("whoosh", 0.5f);
        }

        public void Attack(bool kick)
        {
            if (!Free) return;
            float sp = Mathf.Sqrt(B.spd) * (RageOn ? 1.2f : 1f);
            if (weapon != null && !kick)
            {
                switch (weapon.kind)
                {
                    case WeaponKind.Chainsaw: StartAct(Act.Saw, 0.9f); sawTick = 0; atkCd = 0.2f; return;
                    case WeaponKind.Staff:
                        if (target != null && Mathf.Abs(target.pos.x - pos.x) > 3f && staffCd <= 0f)
                        {
                            castAb = Ability.Fireball; castFromStaff = true; staffCd = 1.6f;
                            aim = AimAt(target); StartAct(Act.Cast, 0.45f);
                            return;
                        }
                        break;
                    case WeaponKind.Gun:
                        if (ammo <= 0) break;
                        aim = AimAt(target);
                        StartAct(Act.Shoot, (weapon.rifle ? 0.13f : 0.3f) / weapon.rate);
                        atkCd = 0.05f;
                        return;
                    case WeaponKind.Bow:
                        if (ammo <= 0) break;
                        aim = AimAt(target);
                        if (target != null) aim = (aim + Vector2.up * Mathf.Abs(target.pos.x - pos.x) * 0.012f).normalized;
                        StartAct(Act.Shoot, 0.65f / weapon.rate);
                        return;
                    case WeaponKind.Thrown:
                        if (ammo <= 0) break;
                        aim = AimAt(target);
                        StartAct(Act.Throw, 0.4f / weapon.rate);
                        return;
                }
            }
            bool wantHigh = target != null && target.B.Needs(HF.Head) && Random.value < 0.7f;
            bool wantLow = target != null && target.body == BodyS.Down;
            StartMove(Move.Starter(B.style, kick, MeleeWeapon && !kick, weapon != null ? weapon.kind : WeaponKind.Fists, !grounded, wantHigh, wantLow));
            comboLeft = Random.Range(2, 5) + (B.agi > 1.3f ? 1 : 0);
            atkCd = Random.Range(0.1f, 0.35f) / sp;
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

        public void StartRoll(int dir)
        {
            if (!Free || !grounded) return;
            rollDir = dir;
            StartAct(Act.Roll, 0.42f);
            iframes = 0.42f;
            battle.fx.Dust(pos, 6);
            battle.audio.Sfx("whoosh", 0.5f);
        }

        public void StartBackflip()
        {
            if (!Free || !grounded) return;
            StartAct(Act.Flip, 0.55f);
            vel = new Vector2(-facing * 6f, 12f);
            grounded = false;
            iframes = 0.3f;
            battle.fx.Dust(pos, 6);
            battle.audio.Sfx("whoosh", 0.5f);
        }

        void ActTick(float dt)
        {
            if (act == Act.None) return;
            actT += dt;
            float u = actT / actDur;
            switch (act)
            {
                case Act.Move:
                    if (mv == null) { act = Act.None; break; }
                    if (mv.slam && mv.air && !grounded && u >= mv.hitAt * 0.7f && vel.y > -18f) vel = new Vector2(facing * 6f, -20f);
                    if (u >= mv.hitAt && u <= mv.hitAt + 0.15f) MoveHit();
                    // отмена восстановления в следующий приём (комбо)
                    if (mvHit && u >= mv.hitAt + 0.1f)
                    {
                        Move nx = null;
                        if (human) nx = queued;
                        else if (comboLeft > 0 && mv.next.Length > 0 && target != null && !target.dead && Random.value < 0.75f + 0.1f * B.agi)
                            nx = PickNext(mv);
                        if (nx != null && (!nx.air || !grounded) && (!nx.weapon || MeleeWeapon) && (nx.air || grounded))
                        {
                            comboLeft--;
                            if (mv.launcher && !human) followAir = true;
                            StartMove(nx);
                            return;
                        }
                    }
                    break;
                case Act.Saw:
                    sawTick -= dt;
                    if (sawTick <= 0f)
                    {
                        sawTick = 0.09f;
                        battle.audio.Sfx("saw", 0.5f);
                        SawHit();
                        battle.fx.Sparks(J[4] + new Vector2(facing * 0.6f, 0), new Vector2(facing, 0.5f), 2, new Color(1f, 0.8f, 0.3f));
                    }
                    break;
                case Act.Laser: LaserTick(dt); break;
                case Act.Dash:
                    ghostT -= dt;
                    if (ghostT <= 0) { ghostT = 0.04f; battle.AfterImage(this, Draw.A(mainCol, 0.5f)); }
                    foreach (var e in battle.fighters)
                    {
                        if (e.dead || e.team == team || dashHit.Contains(e)) continue;
                        if (Mathf.Abs(e.pos.x - pos.x) < 0.9f * Size && Mathf.Abs(e.pos.y - pos.y) < 1.3f)
                        {
                            dashHit.Add(e);
                            var h = MakeHit(14f, MeleeWeapon ? weapon.Type : DmgType.Blunt, weapon != null ? weapon.element : B.affinity, 8f, 0.3f);
                            h.point = e.Center; h.dir = new Vector2(facing, 0.4f).normalized; h.knockdown = true; h.lift = 5f;
                            if (!MeleeWeapon) h.extra |= HF.Unarmed;
                            e.TakeHit(h);
                            battle.audio.Sfx("kick");
                        }
                    }
                    break;
                case Act.Roll:
                    if (Random.value < 0.3f) battle.fx.Dust(pos, 1);
                    break;
                case Act.GetUp:
                    break;
                case Act.ThrowSec:
                    if (!actFired && u >= 0.45f) { actFired = true; FireSecondary(); }
                    break;
                default:
                    if (!actFired && u >= 0.45f) { actFired = true; Fire(); }
                    break;
            }
            if (actT >= actDur)
            {
                if (act == Act.Laser) { lLaser.enabled = lLaserGlow.enabled = false; }
                if (act == Act.Move && !human && followAir) { }
                act = Act.None;
                mv = null;
            }
        }

        Move PickNext(Move m)
        {
            if (m.next.Length == 0) return null;
            bool needHead = target != null && target.B.Needs(HF.Head);
            if (needHead)
                foreach (var n in m.next) if (n.high && Random.value < 0.7f) return n;
            if (target != null && target.body == BodyS.Tumble)
                foreach (var n in m.next) if (n.launcher || n.air) return n;
            Move pick = m.next[Random.Range(0, m.next.Length)];
            if (B.style == Style.Kicker) foreach (var n in m.next) if (n.limb >= 2 && Random.value < 0.6f) { pick = n; break; }
            if (B.style == Style.Boxer) foreach (var n in m.next) if (n.limb < 2 && Random.value < 0.6f) { pick = n; break; }
            return pick;
        }

        Vector2 Tip(int limb)
        {
            switch (limb)
            {
                case 0: return J[4];
                case 1: return J[6];
                case 2: return J[8];
                case 3: return J[10];
            }
            if (weapon == null) return J[4];
            return weaponRoot.TransformPoint(new Vector3(TipLen(), 0, 0));
        }

        float TipLen()
        {
            if (weapon == null) return 0.2f;
            float s = Size * weapon.size;
            switch (weapon.kind)
            {
                case WeaponKind.Blade: return 1.05f * s;
                case WeaponKind.Blunt: return (weapon.bat ? 1f : 0.85f) * s;
                case WeaponKind.Spear: return 1.8f * s;
                case WeaponKind.Staff: return 1.1f * s;
                case WeaponKind.Chainsaw: return 1.1f * s;
            }
            return 0.4f * s;
        }

        HitInfo MakeHit(float dmg, DmgType type, Element elem, float knock, float stun)
        {
            var h = new HitInfo();
            h.dmg = dmg * B.dmgMul * (RageOn ? 1.5f : 1f) * Random.Range(0.9f, 1.1f);
            h.type = type; h.elem = elem; h.knock = knock; h.stun = stun; h.attacker = this;
            if (weapon != null) h.customTag = weapon.customTag;
            h.dir = new Vector2(facing, 0.25f).normalized;
            return h;
        }

        void MoveHit()
        {
            float reach = mv.reach * (mv.weapon && weapon != null ? weapon.range : 1f) * Size;
            Vector2 c = Center;
            Vector2 tip = Tip(mv.limb);
            foreach (var e in battle.fighters)
            {
                if (e.team == team || e.dead || mvHitList.Contains(e)) continue;
                if (e.iframes > 0) continue;
                Vector2 rel = e.Center - c;
                float fx = rel.x * facing;
                float hy = 1.0f * Size + 0.6f * e.Size;
                if (e.body == BodyS.Down) hy = mv.low || mv.slam || mv.weapon ? hy : 0.4f;
                if (!(fx > -0.4f && fx < reach + 0.35f * e.Size && Mathf.Abs(rel.y) < hy)) continue;
                if (mv.low && !e.grounded) continue;

                // встречный удар — столкновение
                if (e.Active && e.facing == -facing && e.mv != null && !e.mvHit && Random.value < 0.45f)
                {
                    Clash(e);
                    return;
                }

                mvHitList.Add(e);
                bool wpn = mv.weapon && weapon != null;
                float dmg = wpn ? weapon.dmg * mv.dmg * (0.6f + 0.4f * B.str) : mv.dmg * B.str;
                DmgType type = wpn ? (mv.stab && weapon.kind == WeaponKind.Blade ? DmgType.Pierce : weapon.Type) : DmgType.Blunt;
                Element el = wpn ? weapon.element : B.affinity;
                var h = MakeHit(dmg, type, el, mv.knock.x * (wpn ? weapon.knock : 1f) * Mathf.Pow(B.str, 0.3f), mv.stun);
                h.lift = mv.knock.y;
                h.launcher = mv.launcher; h.slam = mv.slam; h.knockdown = mv.knockdown; h.heavy = mv.heavy;
                h.dir = new Vector2(facing, 0.2f).normalized;
                if (!wpn) h.extra |= HF.Unarmed;
                Vector2 headP = e.J[2];
                bool head = (mv.high && e.body == BodyS.Normal && Random.value < 0.85f) || Mathf.Abs(tip.y - headP.y) < Skel.HeadR * e.Size * 1.6f;
                if (e.body == BodyS.Down) head = Random.value < 0.25f;
                if (head) h.extra |= HF.Head;
                h.point = head ? headP - new Vector2(facing * Skel.HeadR * e.Size, 0) : new Vector2(e.pos.x - facing * 0.12f * e.Size, Mathf.Clamp(tip.y, e.pos.y + 0.4f * e.Size, e.J[1].y));
                if (wpn && weapon.bleed) { e.bleedT = Mathf.Max(e.bleedT, 3f); e.bleedBy = this; }
                e.TakeHit(h);
                OnLanded(h);
                if (!mv.cleave && !wpn) break;
            }
        }

        void OnLanded(HitInfo h)
        {
            mvHit = true;
            combo++;
            comboT = 1.2f;
            if (combo > maxCombo) maxCombo = combo;
            if (combo == 5 || combo == 10) battle.FlashStyle(2, 0.09f);
            if (combo >= 3) battle.Popup(combo + " HITS!", J[2] + new Vector2(-facing * 0.6f, 1.1f), Color.Lerp(mainCol, Color.white, 0.5f), 0.7f + Mathf.Min(0.6f, combo * 0.05f));
            atkCd = Mathf.Min(atkCd, 0.05f);
            if (h.type == DmgType.Blade || h.type == DmgType.Pierce) { battle.audio.Sfx("cut", 0.8f); battle.audio.Sfx("splat", 0.5f); }
            else battle.audio.Sfx(mv != null ? mv.sfx : "punch", 0.9f);
        }

        void Clash(Fighter e)
        {
            Vector2 mid = (Tip(mv.limb) + e.Tip(e.mv.limb)) * 0.5f;
            vel.x = -facing * 9f; e.vel.x = -e.facing * 9f;
            act = Act.None; e.act = Act.None; mv = null; e.mv = null;
            stun = 0.25f; e.stun = 0.25f;
            battle.HitSpark(mid, Vector2.up, 2f, new Color(1f, 0.9f, 0.4f));
            battle.fx.Sparks(mid, Vector2.up, 24, new Color(1f, 0.9f, 0.5f));
            battle.Popup("CLASH!", mid + Vector2.up * 0.8f, new Color(1f, 0.9f, 0.3f), 1.1f);
            battle.audio.Sfx("clang", 1f);
            battle.Impact(20f, mid, true);
            battle.Flash(0.06f, new Color(1, 1, 1, 0.5f));
        }

        void SawHit()
        {
            Vector2 c = Center;
            float r = (weapon != null ? weapon.range : 1.4f) * Size;
            foreach (var e in battle.fighters)
            {
                if (e.team == team || e.dead || e.iframes > 0) continue;
                Vector2 rel = e.Center - c;
                float fx = rel.x * facing;
                if (fx > -0.35f && fx < r + 0.3f * e.Size && Mathf.Abs(rel.y) < 1.2f * Size)
                {
                    var h = MakeHit(weapon != null ? weapon.dmg : 4f, DmgType.Blade, weapon != null ? weapon.element : Element.None, 0.8f, 0.12f);
                    h.point = new Vector2(e.pos.x - facing * 0.12f * e.Size, J[4].y);
                    e.bleedT = Mathf.Max(e.bleedT, 3f); e.bleedBy = this;
                    e.TakeHit(h);
                    combo++; comboT = 1.2f; if (combo > maxCombo) maxCombo = combo;
                }
            }
        }

        void Fire()
        {
            switch (act)
            {
                case Act.Shoot: FireGun(); break;
                case Act.Throw: FireThrown(); break;
                case Act.Cast: DoCast(); break;
            }
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
                case Ability.Summon:
                case Ability.Custom:
                    if (a == Ability.Summon && (minion || battle.MinionCount(this) >= 3)) return false;
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
                    if (grounded) { vel.y = 15f; grounded = false; StartAirFlip(1f); }
                    else vel.y = -22f;
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
            battle.Popup((a == Ability.Custom && B.customAbility != null ? B.customAbility : Info.Name(a).Replace(" (пассив)", "")).ToUpper() + "!", J[2] + Vector2.up * 0.7f, Color.Lerp(mainCol, Color.white, 0.4f), 0.8f);
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
                        h.extra |= HF.Magic;
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
                        h.extra |= HF.Magic;
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
                case Ability.Summon:
                    battle.SpawnMinions(this, 2, weapon != null && weapon.summon ? weapon.summonName : (sec != null && sec.summon ? sec.summonName : B.summonName));
                    break;
                case Ability.Custom:
                    {
                        // придуманное игроком умение: энергетический удар с его названием и уникальным цветом
                        Color cc = Color.HSVToRGB(Mathf.Abs((B.customAbility ?? "x").GetHashCode() % 360) / 360f, 0.75f, 1f);
                        var h = MakeHit(14f * pw, DmgType.Shadow, Element.None, 6f, 0.35f);
                        h.extra |= HF.Magic;
                        h.customTag = B.customAbilityTag;
                        h.knockdown = true;
                        battle.SpawnProjectile(Projectile.Kind.Bolt, hand + aim * 0.3f, aim * 15f, this, h, cc);
                        battle.Shock(hand, 1.2f, cc);
                        battle.audio.Sfx("zap", 0.7f);
                        break;
                    }
            }
        }

        public void SetupMinion(Fighter o, float lifetime)
        {
            minion = true; owner = o; life = lifetime;
            iframes = 0.4f;
        }

        // второе оружие: метательные ножи / пистолет из описания
        public bool UseSecondary()
        {
            if (sec == null || secAmmo <= 0 || secCd > 0f || !Free) return false;
            aim = target != null ? ((sec.alwaysHead ? target.J[2] : target.Center) - J[1]).normalized : new Vector2(facing, 0);
            if (target != null) facing = target.pos.x >= pos.x ? 1 : -1;
            StartAct(Act.ThrowSec, sec.Ranged && sec.kind != WeaponKind.Thrown ? 0.3f : 0.36f);
            secCd = 0.9f;
            return true;
        }

        void FireSecondary()
        {
            if (sec == null || secAmmo <= 0) return;
            Vector2 from = J[4];
            bool knife = sec.kind == WeaponKind.Thrown && !sec.explode;
            var h = MakeHit(sec.dmg * (sec.knives ? 1.2f : 1f), sec.kind == WeaponKind.Gun ? DmgType.Pierce : sec.explode ? DmgType.Blunt : DmgType.Blade, sec.element, 3f, 0.2f);
            h.customTag = sec.customTag;
            Projectile pr;
            if (sec.explode) pr = battle.SpawnProjectile(Projectile.Kind.Grenade, from, new Vector2(facing * 9f, 7f), this, h, sec.color);
            else if (sec.kind == WeaponKind.Gun) pr = battle.SpawnProjectile(Projectile.Kind.Bullet, from + aim * 0.4f, aim * 32f, this, h, sec.color);
            else if (sec.kind == WeaponKind.Bow) pr = battle.SpawnProjectile(Projectile.Kind.Arrow, from, aim * 22f, this, h, sec.color);
            else pr = battle.SpawnProjectile(sec.knives ? Projectile.Kind.Knife : Projectile.Kind.Shuriken, from, aim * 21f, this, h, sec.color);
            if (sec.alwaysHead && target != null) { pr.homing = target; pr.forceHead = true; }
            if (knife && sec.bleed) pr.bleed = true;
            battle.audio.Sfx(sec.kind == WeaponKind.Gun ? "shot" : "whoosh", 0.7f);
            secAmmo--;
            if (secAmmo <= 0) battle.Popup(sec.name + ": пусто", J[2] + Vector2.up * 0.7f, new Color(0.8f, 0.8f, 0.8f), 0.6f);
        }

        public void Lift(Fighter by)
        {
            if (dead || iframes > 0) return;
            if (act == Act.Laser) { lLaser.enabled = lLaserGlow.enabled = false; }
            act = Act.None; mv = null;
            body = BodyS.Tumble; bounced = true; spinVel = 180f;
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
                    h.extra |= HF.Magic;
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
                        h.extra |= HF.Magic;
                        h.point = eye + dir * along; h.dir = dir; h.noFlinch = true;
                        e.TakeHit(h);
                        battle.fx.Sparks(h.point, -dir, 3, new Color(1f, 0.6f, 0.3f));
                    }
                }
            }
        }

        // ===================== УРОН =====================
        int Flags(HitInfo h)
        {
            int f = (int)HFInfo.FromType(h.type) | (int)HFInfo.FromElem(h.elem) | (int)h.extra;
            if (TagMatch(h.customTag, B.customWeak)) f |= (int)HF.Custom;
            return f;
        }

        bool Matches(int flags)
        {
            foreach (var m in B.killMasks) if ((flags & m) == m) return true;
            return false;
        }

        bool KillOnly { get { return B.killOnly && !battle.suddenDeath; } }

        float ApplyRules(float d, int flags, Vector2 at, out bool match)
        {
            match = Matches(flags);
            if (match)
            {
                d *= KillOnly ? 2.5f : 2f;
                regenBlock = 4f;
                if (popupCd <= 0) { popupCd = 0.6f; battle.Popup(KillOnly ? "СЛАБОЕ МЕСТО!" : "СЛАБОСТЬ!", at + Vector2.up * 0.9f, new Color(1f, 0.85f, 0.1f), 0.85f); }
            }
            else
            {
                if ((flags & B.immuneMask) != 0)
                {
                    if (popupCd <= 0) { popupCd = 0.8f; battle.Popup("ИММУНИТЕТ", at + Vector2.up * 0.9f, new Color(0.7f, 0.85f, 1f), 0.7f); }
                    return 0f;
                }
                if (KillOnly) d *= 0.15f;
            }
            return d;
        }

        public void TakeHit(HitInfo h)
        {
            if (dead) return;
            if (iframes > 0 && !h.extra.HasFlag(HF.Fall))
            {
                if (popupCd <= 0) { popupCd = 0.4f; battle.Popup("ПРОМАХ", J[2] + Vector2.up * 0.6f, new Color(0.8f, 0.8f, 0.8f), 0.6f); }
                return;
            }
            if (h.attacker != null && h.attacker != this && body == BodyS.Normal && Mathf.Sign(h.attacker.pos.x - pos.x) == -facing && Mathf.Abs(h.attacker.pos.x - pos.x) > 0.05f)
                h.extra |= HF.Back;
            float d = h.dmg;
            bool blocked = act == Act.Block && Mathf.Sign(h.dir.x) == -facing && h.type != DmgType.Lightning && (h.extra & HF.Back) == 0;
            if (blocked)
            {
                if (h.heavy)
                {
                    d *= 0.45f; h.knock *= 0.6f; blocked = false;
                    battle.Popup("БЛОК ПРОБИТ!", J[2] + Vector2.up * 0.8f, new Color(1f, 0.5f, 0.2f), 0.8f);
                    stun = 0.5f;
                }
                else
                {
                    d *= 0.15f; h.knock *= 0.35f;
                    battle.fx.Sparks(h.point, -h.dir, 12, new Color(1f, 0.9f, 0.5f));
                    battle.HitSpark(h.point, -h.dir, 0.7f, new Color(1f, 0.9f, 0.5f));
                    battle.audio.Sfx("clang", 0.6f);
                    h.launcher = h.knockdown = h.slam = false;
                }
            }
            int flags = Flags(h);
            bool match;
            d = ApplyRules(d, flags, J[2], out match);
            if (!match && (flags & B.resistMask) != 0) d *= 0.4f;
            if (h.elem != Element.None && h.elem == B.affinity && !match) d *= 0.5f;
            d /= Mathf.Sqrt(B.def);
            if (shieldT > 0 && !match) { d *= 0.25f; h.knock *= 0.3f; battle.fx.Sparks(h.point, -h.dir, 6, new Color(0.4f, 0.9f, 1f)); }
            if ((h.extra & HF.Head) != 0) d *= 1.35f;
            if (body == BodyS.Down) { d *= 0.6f; }
            if (d > 0) d = Mathf.Max(0.5f, d);

            hp -= d;
            if (KillOnly && !match && hp < 1f)
            {
                hp = 1f;
                if (popupCd <= 0) { popupCd = 1f; battle.Popup("ЕГО ТАК НЕ УБИТЬ!", J[2] + Vector2.up * 1.1f, new Color(1f, 0.4f, 0.3f), 0.8f); }
            }
            invisT = 0;
            if (h.attacker != null)
            {
                h.attacker.dmgDealt += d;
                if (h.attacker.B.HasAb(Ability.Vampire) && !h.attacker.dead) h.attacker.hp = Mathf.Min(h.attacker.maxHp, h.attacker.hp + d * 0.3f);
                if (h.elem == Element.Shadow && !h.attacker.dead) h.attacker.hp = Mathf.Min(h.attacker.maxHp, h.attacker.hp + d * 0.25f);
            }
            if (d > 0) battle.DamageNumber(d, J[2] + Vector2.up * 0.5f, match, (h.extra & HF.Head) != 0);

            if (!blocked && d > 0)
            {
                float amt = d * (h.type == DmgType.Blade || h.type == DmgType.Pierce ? 2.2f : 1.3f);
                if (h.type == DmgType.Fire || h.type == DmgType.Lightning || h.type == DmgType.Ice) amt *= 0.4f;
                Vector2 bdir = (h.extra & HF.Head) != 0 ? (h.dir + Vector2.up * 0.8f) : h.dir;
                battle.fx.Blood(h.point, bdir, amt);
                if (h.type == DmgType.Fire) battle.fx.Fire(h.point, 6, 0.2f);
                if (h.type == DmgType.Ice) battle.fx.Sparks(h.point, h.dir, 8, new Color(0.6f, 0.95f, 1f));
                if (h.type == DmgType.Lightning) battle.fx.Sparks(h.point, Vector2.up, 10, new Color(1f, 1f, 0.5f));
                float pw = Mathf.Clamp(d / 10f, 0.5f, 2.2f) * (h.heavy ? 1.3f : 1f);
                Color sc = h.elem != Element.None ? Info.ElemColor(h.elem) : battle.theme.ink;
                battle.HitSpark(h.point, h.dir, pw, sc);
                flash = 0.07f;
            }

            switch (h.elem)
            {
                case Element.Fire: burnT = Mathf.Max(burnT, 2.5f); burnBy = h.attacker; break;
                case Element.Ice: slowT = Mathf.Max(slowT, 2.5f); break;
                case Element.Lightning: h.stun = Mathf.Max(h.stun, 0.45f); break;
                case Element.Poison: poisonT = Mathf.Max(poisonT, 5f); poisonBy = h.attacker; break;
            }

            bool superArmor = Size >= 1.25f && d < 9f && !h.heavy && !h.launcher && body == BodyS.Normal;
            float kn = h.knock / Mathf.Sqrt(Size);
            if (body == BodyS.Down)
            {
                vel.y = 3f; grounded = false; downT = Mathf.Max(downT, 0.35f);
                body = BodyS.Tumble; spinVel = 0; bounced = true;
            }
            else if (!h.noFlinch && !superArmor && !blocked && (h.launcher || h.knockdown || h.slam || d >= 20f || body == BodyS.Tumble || (!grounded && kn > 3f)))
            {
                bool wasAir = !grounded || body == BodyS.Tumble;
                body = BodyS.Tumble;
                if (act == Act.Laser) { lLaser.enabled = lLaserGlow.enabled = false; }
                act = Act.None; mv = null; ClearTrail();
                float lift = h.lift != 0 ? h.lift : Mathf.Max(4f, kn * 0.5f);
                if (h.slam && wasAir) vel = new Vector2(h.dir.x * kn * 0.4f, -20f);
                else vel = new Vector2(h.dir.x * kn, Mathf.Max(lift, 2f));
                grounded = false;
                if (wasAir) juggle++;
                bounced = false;
                float sgn = Mathf.Sign(h.dir.x) == facing ? -1f : 1f; // удар в спину — кувырок вперёд
                spinVel = sgn * (h.launcher ? 160f : Mathf.Clamp(kn * 38f, 140f, 520f));
                if (Mathf.Abs(Mathf.Repeat(tumbleSpin + 180f, 360f) - 180f) > 120f) tumbleSpin = 0;
                stun = Mathf.Max(stun, 0.3f);
                hurtT = 0;
            }
            else if (!h.noFlinch && !superArmor)
            {
                vel += new Vector2(h.dir.x * kn, Mathf.Max(kn * 0.2f, h.dir.y * kn));
                if (vel.y > 0.5f) grounded = false;
                if (!blocked) { if (act == Act.Laser) { lLaser.enabled = lLaserGlow.enabled = false; } act = Act.None; mv = null; ClearTrail(); }
                hurtT = blocked ? 0.08f : 0.26f;
                stun = Mathf.Max(stun, blocked ? 0f : h.stun);
                hurtPose = (h.extra & HF.Head) != 0 ? Pose.HurtHigh : (Random.value < 0.5f ? Pose.HurtBody : Pose.Hurt);
                // хлёсткая реакция: толчок пружины корпуса и рук
                float imp = Mathf.Clamp(d * 45f, 200f, 1400f);
                pv[0] += (h.extra & HF.Head) != 0 ? -imp : imp * 0.6f;
                pv[1] -= imp; pv[3] -= imp * 0.8f;
            }
            battle.Impact(d, h.point, h.heavy || h.launcher);

            if (hp <= 0) Die(h);
        }

        void RawDamage(float d, DmgType type, Fighter src, bool show, HF extra = HF.None)
        {
            if (dead) return;
            int flags = (int)HFInfo.FromType(type) | (int)extra;
            bool match;
            d = ApplyRules(d, flags, J[2], out match);
            hp -= d;
            if (KillOnly && !match && hp < 1f) hp = 1f;
            if (src != null) src.dmgDealt += d;
            if (show && d > 0) battle.DamageNumber(d, J[2] + Vector2.up * 0.5f, match, false);
            if (hp <= 0)
            {
                var h = new HitInfo { dmg = d, type = type, attacker = src, dir = new Vector2(-facing, 0.5f).normalized, point = Center, knock = 2f, extra = extra };
                Die(h);
            }
        }

        void Die(HitInfo h)
        {
            if (dead) return;
            dead = true; hp = 0; act = Act.None; deadTime = 0; mv = null;
            shieldT = 0; invisT = 0;
            ClearTrail();
            lLaser.enabled = lLaserGlow.enabled = false;
            if (weapon != null && (!weapon.Ranged || ammo > 0))
                battle.SpawnPickup(weapon, ammo, J[4], vel + new Vector2(Random.Range(-3f, 3f), 6f), false);
            SetWeapon(null, 0);
            Vector2 v = vel + h.dir * h.knock * 1.4f + Vector2.up * 3f;
            rag = new Ragdoll(J, v, Size);
            float bloodMul = Game.I != null ? Game.I.S.blood : 1f;
            bool head = (h.extra & HF.Head) != 0;
            bool decap = bloodMul > 0.01f && ((h.type == DmgType.Blade && (h.heavy || h.dmg > 14f || head || Random.value < 0.35f)) || (head && h.heavy) || h.headshot);
            if (decap)
            {
                rag.BreakNeck(new Vector2(h.dir.x * 6f + Random.Range(-1f, 1f), 8f));
                fountainT = 2.5f;
                battle.Popup("ГОЛОВА С ПЛЕЧ!", J[2] + Vector2.up * 1.2f, new Color(1f, 0.2f, 0.15f), 1.1f);
            }
            battle.fx.Blood(h.point, h.dir, 60);
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

        // подходит ли оружие под условие смерти цели
        public static bool TagMatch(string a, string b)
        {
            if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return false;
            return a.StartsWith(b) || b.StartsWith(a);
        }

        public static bool Satisfies(WeaponStats w, Fighter t)
        {
            if (w == null || t == null) return false;
            if (t.B.customWeak != null && TagMatch(w.customTag, t.B.customWeak)) return true;
            int f = (int)HFInfo.FromType(w.Type) | (int)HFInfo.FromElem(w.element) | (w.explode ? (int)HF.Explosion : 0);
            if (w.kind == WeaponKind.Blade) f |= (int)HF.Pierce; // выпад клинком = протыкание
            int pos = (int)(HF.Head | HF.Back | HF.Fall);
            foreach (var m in t.B.killMasks) { int need = m & ~pos; if (need != 0 && (f & need) == need) return true; }
            return false;
        }

        void TryPickup()
        {
            if (dead) return;
            bool armed = weapon != null && (!weapon.Ranged || ammo > 0);
            foreach (var pk in battle.pickups)
            {
                if (!pk.landed && pk.pos.y > 1.8f) continue;
                if (Mathf.Abs(pk.pos.x - pos.x) > 0.8f || Mathf.Abs(pk.pos.y - pos.y) > 1.8f) continue;
                if (armed)
                {
                    // поменять оружие можно на "убийцу", если текущее не подходит против цели
                    if (human || !pk.w.killer || target == null || Satisfies(weapon, target) || !Satisfies(pk.w, target)) continue;
                    battle.SpawnPickup(weapon, ammo, J[4], new Vector2(-facing * 3f, 5f), false);
                }
                SetWeapon(pk.w.Copy(), pk.ammo);
                battle.RemovePickup(pk);
                battle.audio.Sfx("pickup", 0.7f);
                battle.Popup(weapon.name, J[2] + Vector2.up * 0.8f, Color.Lerp(weapon.color, Color.white, 0.3f), 0.8f);
                return;
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
            if (pindex == 1)
            {
                if (g.Pressed(KeyCode.Keypad1)) A = KeyCode.Keypad1;
                if (g.Pressed(KeyCode.Keypad2)) K = KeyCode.Keypad2;
            }
            if (g.Held(L)) move -= 1;
            if (g.Held(R)) move += 1;
            bool atk = g.Pressed(A), kick = g.Pressed(K);
            if (g.Pressed(U) && !atk && !kick) jump = true;

            // буфер комбо: нажатие во время приёма ставит следующий удар в очередь
            if (act == Act.Move && mv != null && (atk || kick))
            {
                Move nx = null;
                foreach (var n in mv.next) if ((kick ? n.limb >= 2 : n.limb < 2 || n.weapon) && (n.air == !grounded)) { nx = n; break; }
                if (nx == null) foreach (var n in mv.next) if (n.air == !grounded) { nx = n; break; }
                if (g.Held(U)) foreach (var n in mv.next) if (n.launcher) { nx = n; break; }
                queued = nx;
            }

            if (free)
            {
                if (g.Held(D) && (g.Pressed(L) || g.Pressed(R))) StartRoll(g.Pressed(L) ? -1 : 1);
                else if (g.Held(D) && kick && grounded) StartMove(Move.Sweep);
                else if (g.Held(U) && atk && grounded) StartMove(MeleeWeapon ? Move.Rise : Move.Upper);
                else if (!grounded && kick) StartMove(MeleeWeapon ? Move.AirSmash : Move.DiveKick);
                else if (g.Held(D) && !atk && !kick) StartBlock();
                else if (atk) Attack(false);
                else if (kick)
                {
                    if (Mathf.Abs(vel.x) > 5f && grounded) StartMove(Move.FlyKick);
                    else Attack(true);
                }
                else
                {
                    var acts = ActiveAbilities();
                    if (g.Pressed(pindex == 0 ? KeyCode.E : KeyCode.U) || (pindex == 1 && g.Pressed(KeyCode.Keypad3))) UseSecondary();
                    else if (g.Pressed(Q1) && acts.Count > 0) UseAbility(acts[0]);
                    else if (g.Pressed(Q2) && acts.Count > 1) UseAbility(acts[1]);
                    else if (g.Pressed(Q3) && acts.Count > 2) UseAbility(acts[2]);
                }
            }
            else if (act == Act.Block && !g.Held(D) && actT > 0.1f) act = Act.None;
            else if (act == Act.Block && g.Held(D)) actT = Mathf.Min(actT, actDur * 0.5f);
            if (act == Act.Saw && !g.Held(A)) actT = Mathf.Max(actT, actDur - 0.05f);
        }

        public bool WeaponSummons { get { return (weapon != null && weapon.summon) || (sec != null && sec.summon); } }

        public List<Ability> ActiveAbilities()
        {
            var l = new List<Ability>();
            foreach (var a in B.abilities) if (!Info.Passive(a)) l.Add(a);
            if (WeaponSummons && !l.Contains(Ability.Summon) && !minion) l.Add(Ability.Summon);
            return l;
        }

        void AI(ref float move, ref bool jump, bool free, float dt)
        {
            think -= dt;
            tauntT -= dt;
            if (target == null) { move = 0; return; }
            Vector2 d = target.pos - pos;
            float dist = Mathf.Abs(d.x);
            int dir = d.x >= 0 ? 1 : -1;
            bool ranged = weapon != null && weapon.Ranged && ammo > 0;
            float reach = Reach();
            bool wantBack = target.B.Needs(HF.Back);

            // добивание в воздухе после подброса
            if (followAir && free && grounded && target.body == BodyS.Tumble && target.pos.y > 0.6f && dist < 3.5f)
            {
                jump = true; followAir = false;
                vel.x = dir * 4f;
            }
            if (free && !grounded && target.body == BodyS.Tumble && dist < 1.9f * Size && Mathf.Abs(target.Center.y - Center.y) < 1.7f && atkCd <= 0)
            {
                StartMove(MeleeWeapon ? Move.AirSlash : (Random.value < 0.6f ? Move.AirPunch : Move.AirKick));
                comboLeft = 3;
                return;
            }

            if (think <= 0f)
            {
                think = Random.Range(0.08f, 0.2f);
                pickupTarget = null;
                var pk = battle.NearestPickup(pos.x);
                if (pk != null && (pk.landed || pk.pos.y < 3f))
                {
                    bool killerNeed = pk.w.killer && !Satisfies(weapon, target) && Satisfies(pk.w, target);
                    if ((weapon == null && Mathf.Abs(pk.pos.x - pos.x) < dist + 3f) || killerNeed) pickupTarget = pk;
                }
                if (free) TryAbilities(dist, d);

                if (ranged) aiMove = dist < 3.5f ? -dir : (dist > 9f ? dir : (dist < 5f ? -dir * 0.7f : 0f));
                else if (target.body == BodyS.Down)
                {
                    // противник лежит: добить или подразнить
                    if (dist < reach * 0.9f && free && atkCd <= 0 && Random.value < 0.5f) { StartMove(MeleeWeapon ? Move.Overhead : Move.Sweep); }
                    aiMove = dist > reach ? dir : (Random.value < 0.5f ? -dir * 0.6f : 0f);
                    if (free && dist > 2f && tauntT <= 0 && Random.value < 0.15f) tauntT = 0.8f;
                }
                else if (dist > reach * 0.9f)
                {
                    aiMove = dir;
                    // рывок в атаку с середины дистанции
                    if (free && grounded && dist > 2.6f && dist < 5.5f && Random.value < 0.18f * B.agi * (B.style == Style.Kicker || B.style == Style.Acrobat ? 1.8f : 1f))
                    {
                        facing = dir;
                        StartMove(MeleeWeapon ? Move.Thrust : Move.FlyKick);
                    }
                    else if (free && grounded && dist > 2f && dist < 4.5f && Random.value < 0.06f * B.agi) StartRoll(dir);
                }
                else if (wantBack && free && grounded && dist < 2.4f && Random.value < 0.35f)
                {
                    StartRoll(dir); // прокат под противником — за спину
                }
                else if (dist < reach * 0.35f && Random.value < 0.4f) aiMove = -dir;
                else aiMove = Random.value < 0.15f ? -dir * 0.5f : 0f;
                if (pickupTarget != null) aiMove = Mathf.Sign(pickupTarget.pos.x - pos.x);
                if (Mathf.Abs(pos.x) > battle.W - 1.5f && aiMove != 0 && Mathf.Sign(aiMove) == Mathf.Sign(pos.x))
                {
                    aiMove = 0;
                    if (grounded && free) { if (Random.value < 0.5f) jump = true; else StartRoll(-(int)Mathf.Sign(pos.x)); }
                }
                if (grounded && free && Random.value < 0.03f * B.agi) jump = true;
                if (d.y > 1.2f && dist < 4f && grounded) jump = true;
                if (free && hp < maxHp * 0.35f && dist < 2f && Random.value < 0.08f * B.agi) StartBackflip();
            }
            move = tauntT > 0 ? 0 : aiMove;
            if (!grounded && Mathf.Abs(pos.x) > battle.W - 0.7f && vel.y < 3f && body == BodyS.Normal && Random.value < 0.2f) jump = true;
            if (dodgeT > 0f)
            {
                dodgeT -= dt;
                if (dodgeT <= 0f && grounded) { if (Random.value < 0.5f) jump = true; else StartRoll(Random.value < 0.5f ? dir : -dir); }
            }

            if (!Free || atkCd > 0f || battle.phase != Battle.Phase.Fight || target.iframes > 0.1f) return;
            if (Mathf.Abs(d.y) > 1.6f * Size + 0.4f && target.body != BodyS.Tumble) return;
            if (sec != null && secAmmo > 0 && secCd <= 0f && dist > 2.4f && dist < 13f && Random.value < (sec.alwaysHead && target.B.Needs(HF.Head) ? 0.5f : 0.2f)) { if (UseSecondary()) return; }
            if (ranged && dist > 2.2f && dist < weapon.range) Attack(false);
            else if (weapon != null && weapon.kind == WeaponKind.Staff && dist > 3f && dist < 12f && staffCd <= 0f) Attack(false);
            else if (!ranged && dist <= reach && target.body != BodyS.Down)
            {
                if (wantBack && (target.facing == dir)) { Attack(false); return; } // уже за спиной!
                float kickChance = B.style == Style.Kicker ? 0.7f : B.style == Style.Boxer ? 0.1f : weapon != null ? 0.12f : 0.35f;
                Attack(Random.value < kickChance);
            }
            else if (ranged && dist <= 1.3f) Attack(true);
        }

        void TryAbilities(float dist, Vector2 d)
        {
            foreach (var a in ActiveAbilities())
            {
                if (Info.Passive(a) || CooldownOf(a) > 0) continue;
                bool use = false;
                float need = 1f;
                // способность подходит под слабость цели — используем охотнее
                if ((a == Ability.Fireball || a == Ability.Laser) && target.B.Needs(HF.Fire)) need = 2.5f;
                if (a == Ability.Lightning && target.B.Needs(HF.Lightning)) need = 2.5f;
                if (a == Ability.IceShard && target.B.Needs(HF.Ice)) need = 2.5f;
                if (a == Ability.Teleport && target.B.Needs(HF.Back)) need = 3f;
                if (a == Ability.Telekinesis && target.B.Needs(HF.Fall)) need = 3f;
                switch (a)
                {
                    case Ability.Fireball:
                    case Ability.IceShard: use = dist > 3f && dist < 13f && Mathf.Abs(d.y) < 2f && Random.value < 0.45f * need; break;
                    case Ability.Lightning: use = Random.value < 0.35f * need; break;
                    case Ability.Laser: use = dist > 2f && dist < 12f && Mathf.Abs(d.y) < 2.5f && Random.value < 0.35f * need; break;
                    case Ability.Teleport: use = (dist > 5f && Random.value < 0.35f * need) || (hp < maxHp * 0.3f && dist < 2f && Random.value < 0.3f) || (need > 1f && dist < 3f && Random.value < 0.3f); break;
                    case Ability.Dash: use = dist > 2.5f && dist < 8f && Mathf.Abs(d.y) < 1f && Random.value < 0.5f; break;
                    case Ability.Shield: use = (hp < maxHp * 0.6f || target.WindingUp) && dist < 5f && Random.value < 0.5f; break;
                    case Ability.GroundSlam: use = dist < 3.5f && grounded && Random.value < 0.4f; break;
                    case Ability.Invisibility: use = hp < maxHp * 0.7f && Random.value < 0.25f; break;
                    case Ability.Telekinesis: use = dist < 10f && Random.value < 0.3f * need; break;
                    case Ability.Summon: use = Random.value < 0.5f; break;
                    case Ability.Custom: use = dist < 12f && Random.value < 0.4f; break;
                }
                if (use && UseAbility(a)) return;
            }
        }

        public void NotifyIncoming(float delay)
        {
            if (human || dead) return;
            if (Random.value < 0.3f * B.agi) dodgeT = Mathf.Max(0.02f, delay);
        }

        // реакция ИИ на начало атаки врага: блок, перекат, сальто назад
        public void React(Fighter attacker)
        {
            if (human || !Free || dead) return;
            float r = Random.value;
            if (r < 0.16f * B.def) StartBlock();
            else if (r < 0.16f * B.def + 0.12f * B.agi && grounded)
            {
                if (Random.value < 0.5f) StartRoll(attacker.pos.x > pos.x ? 1 : -1); // под атакой — за спину
                else if (Random.value < 0.5f) StartBackflip();
                else StartRoll(attacker.pos.x > pos.x ? -1 : 1);
            }
        }

        float Showroom(float dt)
        {
            facing = -1;
            demoT -= dt;
            float back = (Free && Mathf.Abs(pos.x) > 0.4f) ? -Mathf.Sign(pos.x) * 0.6f : 0f;
            if (demoT > 0f || !Free) return back;
            demoT = 1.7f;
            var acts = ActiveAbilities();
            int n = 4 + acts.Count;
            int k = demoStep % n;
            demoStep++;
            if (k == 0) { Attack(false); comboLeft = 0; }
            else if (k == 1) StartMove(MeleeWeapon ? Move.SpinSlash : Move.SpinKick);
            else if (k == 2) StartMove(MeleeWeapon ? Move.Rise : Move.Upper);
            else if (k == 3) { if (B.style == Style.Acrobat || Random.value < 0.5f) StartBackflip(); else StartMove(Move.FlyKick); }
            else
            {
                var a = acts[k - 4];
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
            // пружинистая боевая стойка
            float bob = Mathf.Sin(animT * 7f * Mathf.Sqrt(B.spd));
            p.lean += bob * 2f;
            p.f1 += 6f + bob * 6f; p.f2 -= 8f + bob * 8f;
            p.k1 -= 2f + bob * 5f; p.k2 -= 10f + bob * 8f;
            p.a2 += Mathf.Sin(animT * 7f + 1f) * 4f;
            if (B.style == Style.Boxer) { p.a1 = 50f; p.a2 = 165f; p.b1 = 40f; p.b2 = 160f; }
            return p;
        }

        Pose TargetPose(float dt)
        {
            if (body == BodyS.Tumble)
            {
                // полёт после мощного удара: тело выгнуто, руки и ноги отстают от движения
                bool up = vel.y > 0;
                Pose p = up ? Pose.Tumble : Pose.Lerp(Pose.Tumble, Pose.Slam, 0.5f);
                p.a1 += Mathf.Sin(animT * 9f) * 18f; p.b1 += Mathf.Cos(animT * 8f) * 18f;
                p.f1 += Mathf.Sin(animT * 7f) * 15f; p.k1 += Mathf.Cos(animT * 7.5f) * 15f;
                p.spin = tumbleSpin;
                return p;
            }
            if (body == BodyS.Down)
            {
                Pose p = Pose.Lying;
                float tw = Mathf.Max(0f, 0.4f - (animT % 2.2f)) * 2.5f;
                p.a2 += Mathf.Sin(animT * 3f) * 5f + tw * 20f;
                p.f2 -= tw * 25f;
                p.spin = tumbleSpin;
                return p;
            }
            if (hurtT > 0 || stun > 0)
            {
                Pose h = hurtPose;
                h.a1 += Mathf.Sin(animT * 20f) * 20f; h.b1 += Mathf.Cos(animT * 17f) * 20f;
                if (tkSlam) { h.f1 += Mathf.Sin(animT * 15f) * 30f; h.k1 += Mathf.Cos(animT * 13f) * 30f; }
                return h;
            }
            Pose rest = grounded ? RestPose() : (vel.y > 0 ? Pose.AirUp : Pose.AirDown);
            float u = act != Act.None ? Mathf.Clamp01(actT / actDur) : 0f;
            switch (act)
            {
                case Act.Move:
                    if (mv != null) return Pose.Attack(rest, mv.w, mv.s, u, mv.hitAt);
                    break;
                case Act.Throw: return Pose.Attack(rest, Pose.ThrowW, Pose.ThrowS, u);
                case Act.Shoot:
                    {
                        Pose p = Pose.GuardGun;
                        float ang = Mathf.Atan2(aim.x * facing, -aim.y) * Mathf.Rad2Deg;
                        p.a1 = ang; p.a2 = ang;
                        if (weapon != null && weapon.kind == WeaponKind.Bow) { p.b1 = ang - 5f; p.b2 = ang + 160f * (1f - u * 0.5f); }
                        else if (u > 0.45f && u < 0.65f) { p.a2 += 12f; p.a1 += 6f; p.lean -= 4f; }
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
                case Act.Roll:
                    {
                        Pose p = Pose.Tuck;
                        p.spin = (rollDir == facing ? -360f : 360f) * u;
                        return p;
                    }
                case Act.Flip:
                    {
                        Pose p = Pose.Lerp(Pose.Tuck, Pose.AirDown, Mathf.Max(0f, u * 2f - 1f));
                        p.spin = 360f * Mathf.Min(1f, u * 1.3f);
                        return p;
                    }
                case Act.GetUp:
                    {
                        Pose rp = RestPose();
                        bool kip = (B.style == Style.Acrobat || B.agi > 1.3f) && getUpFrom > 0;
                        if (kip)
                        {
                            // подъём разгибом: ноги к груди — рывок — приземление в стойку
                            if (u > 0.35f && !kipJumped) { kipJumped = true; vel.y = 9f; grounded = false; battle.fx.Dust(pos, 6); battle.audio.Sfx("whoosh", 0.5f); }
                            Pose a = Pose.Lying; a.spin = getUpFrom;
                            Pose b = Pose.Tuck; b.spin = getUpFrom + 25f;
                            Pose c = Pose.AirDown; c.spin = 0f;
                            Pose d = rp; d.spin = 0f;
                            return Pose.Keys(u, new[] { a, b, c, d }, new[] { 0f, 0.35f, 0.7f, 1f });
                        }
                        bool back = getUpFrom > 0;
                        Pose k0 = Pose.Lying; k0.spin = getUpFrom;
                        Pose k1 = back ? Pose.SitUp : Pose.PushUp; k1.spin = back ? 38f : -50f;
                        Pose k2 = Pose.Kneel; k2.spin = 0f;
                        Pose k3 = rp; k3.spin = 0f;
                        return Pose.Keys(u, new[] { k0, k1, k2, k3 }, new[] { 0f, 0.35f, 0.68f, 1f });
                    }
                case Act.ThrowSec: return Pose.Attack(rest, Pose.ThrowW, Pose.ThrowS, u);
            }
            if (!grounded)
            {
                if (slamPending) return vel.y > 0 ? Pose.AirUp : Pose.SmashW;
                Pose p = vel.y > 0 ? Pose.AirUp : Pose.AirDown;
                if (flipT >= 0f)
                {
                    flipT += dt;
                    float k = Mathf.Clamp01(flipT / flipDur);
                    p = Pose.Lerp(p, Pose.Tuck, Mathf.Sin(k * Mathf.PI));
                    p.spin = 360f * (k * k * (3 - 2 * k)) * flipDir;
                    if (k >= 1f) flipT = -1f;
                }
                return p;
            }
            if (landT > 0f) return Pose.Land;
            if (battle.phase == Battle.Phase.Victory && battle.winner == team)
            {
                Pose v = Pose.Victory;
                v.a2 += Mathf.Sin(animT * 8f) * 10f; v.b2 += Mathf.Cos(animT * 8f) * 10f;
                return v;
            }
            if (tauntT > 0f)
            {
                Pose t = Pose.Taunt;
                t.a2 += Mathf.Sin(animT * 14f) * 25f;
                return t;
            }
            if (Mathf.Abs(vel.x) > 0.6f)
            {
                runPhase += dt * Mathf.Abs(vel.x) * 1.9f / Size;
                bool ninja = (weapon == null || weapon.kind == WeaponKind.Blade) && (B.spd > 1.2f || B.style == Style.Acrobat);
                Pose r = Pose.Run(runPhase, ninja);
                if (weapon != null && !ninja) { r.a1 = 35f; r.a2 = weapon.kind == WeaponKind.Gun ? 80f : 95f; }
                if (Mathf.Sign(vel.x) != facing) { r = Pose.Lerp(r, rest, 0.4f); r.lean = -5f; }
                return r;
            }
            return rest;
        }

        // ===================== СЛЕДЫ УДАРОВ =====================
        void ClearTrail()
        {
            trailPts.Clear(); trailAge.Clear();
            if (lTrail != null) lTrail.enabled = false;
        }

        void TrailTick(float dt)
        {
            // призраки бьющей конечности (многократный «смаз», как в рисованных драках)
            bool ghost = false;
            if (act == Act.Move && mv != null)
            {
                float uu = actT / actDur;
                if (uu > mv.hitAt - 0.16f && uu < mv.hitAt + 0.08f)
                {
                    ghost = true;
                    int limb = mv.limb == 4 ? 0 : mv.limb;
                    int r0 = limb < 2 ? 1 : 0, m0 = limb == 0 ? 3 : limb == 1 ? 5 : limb == 2 ? 7 : 9;
                    Vector2 a0 = J[r0], a1 = J[m0], a2 = J[m0 + 1];
                    Color gc = Color.Lerp(mainCol, Color.white, 0.25f);
                    if (styleMode == 1 || styleMode == 3 || styleMode == 7 || silhouette) gc = new Color(0.1f, 0.1f, 0.1f);
                    if (g2ok) { Draw.Set(ghostB, g2[0], g2[1], g2[2]); Draw.Col(ghostB, Draw.A(gc, 0.18f)); ghostB.enabled = true; }
                    if (g1ok) { Draw.Set(ghostA, g1[0], g1[1], g1[2]); Draw.Col(ghostA, Draw.A(gc, 0.38f)); ghostA.enabled = true; }
                    for (int i = 0; i < 3; i++) g2[i] = g1[i];
                    g2ok = g1ok;
                    g1[0] = a0; g1[1] = a1; g1[2] = a2; g1ok = true;
                }
            }
            if (!ghost) { ghostA.enabled = ghostB.enabled = false; g1ok = g2ok = false; }
            for (int i = 0; i < trailAge.Count; i++) trailAge[i] += dt;
            while (trailAge.Count > 0 && trailAge[0] > 0.1f) { trailAge.RemoveAt(0); trailPts.RemoveAt(0); }
            if (act == Act.Move && mv != null)
            {
                float u = actT / actDur;
                if (u > mv.hitAt * 0.6f && u < mv.hitAt + 0.18f)
                {
                    Vector2 tip = Tip(mv.limb);
                    if (trailPts.Count == 0 || Vector2.Distance(trailPts[trailPts.Count - 1], tip) > 0.04f)
                    {
                        trailPts.Add(tip); trailAge.Add(0f);
                        if (trailPts.Count == 1)
                        {
                            bool w = mv.limb == 4 && weapon != null;
                            Color c = w ? (weapon.element != Element.None ? Info.ElemColor(weapon.element) : Color.Lerp(weapon.color, Color.white, 0.6f)) : (silhouette ? new Color(0.15f, 0.15f, 0.15f) : Color.Lerp(mainCol, Color.white, glow ? 0.5f : 0.15f));
                            var g = new Gradient();
                            g.SetKeys(new[] { new GradientColorKey(c, 0f), new GradientColorKey(c, 1f) }, new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(w ? 0.75f : 0.55f, 1f) });
                            lTrail.colorGradient = g;
                            lTrail.widthMultiplier = 1f;
                            lTrail.widthCurve = AnimationCurve.Linear(0f, 0.01f, 1f, (w ? 0.34f : 0.2f) * Size);
                        }
                    }
                }
            }
            // смаз-линии за кулаком/ногой (как в стикмен-анимациях)
            if (act == Act.Move && mv != null)
            {
                float u = actT / actDur;
                Vector2 tip = Tip(mv.limb);
                Vector2 mvd = tip - prevTip;
                if (u > mv.hitAt - 0.14f && u < mv.hitAt + 0.05f && mvd.magnitude > 0.05f && Mathf.Abs(mvd.normalized.x) > 0.55f)
                {
                    Vector2 dn = mvd.normalized;
                    Color sc = silhouette ? new Color(0.1f, 0.1f, 0.1f, 0.6f) : Draw.A(Color.Lerp(mainCol, Color.white, 0.2f), 0.65f);
                    for (int i = 0; i < 3; i++)
                        battle.fx.Emit(tip - dn * Random.Range(0.25f, 0.9f) + new Vector2(0, Random.Range(-0.1f, 0.1f)) * Size, Vector2.zero, sc, 0.035f, 0.09f, 0f, false, 0f, true, Random.Range(10f, 22f), 0.6f);
                }
                prevTip = tip;
            }
            if (trailPts.Count >= 2)
            {
                lTrail.enabled = true;
                lTrail.positionCount = trailPts.Count;
                lTrail.SetPositions(trailPts.ToArray());
            }
            else lTrail.enabled = false;
        }

        // ===================== ОТРИСОВКА =====================
        void Render()
        {
            Vector2[] src = dead && rag != null && !replaying ? rag.p : J;
            float s = Size;
            bool drawn = styleMode == 5 || styleMode == 6 || styleMode == 7;
            if (drawn)
            {
                // рисованная анимация: поза «на двойках» (12 кадров/с) и дрожание линий
                boilT += Time.unscaledDeltaTime;
                bool hold = styleMode != 6;
                if (!heldOk || boilT >= 1f / 12f)
                {
                    boilT = 0f; heldOk = true;
                    float jm = styleMode == 5 ? 0.035f : styleMode == 7 ? 0.02f : 0.012f;
                    for (int i = 0; i < 11; i++) { heldP[i] = src[i]; jit[i] = Random.insideUnitCircle * jm * s; jit2[i] = Random.insideUnitCircle * jm * 1.6f * s; }
                }
                for (int i = 0; i < 11; i++) disp[i] = (hold ? heldP[i] : src[i]) + jit[i];
            }
            else for (int i = 0; i < 11; i++) disp[i] = src[i];
            if (battle.Frozen && flash > 0f)
            {
                Vector2 sh0 = Random.insideUnitCircle * 0.07f * s; // дрожь от удара в стоп-кадре
                for (int i = 0; i < 11; i++) disp[i] += sh0;
            }
            Vector2[] P = disp;
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
            float alpha = invisT > 0 ? (human ? 0.35f : 0.1f) : (iframes > 0 && act == Act.GetUp ? 0.6f + 0.4f * Mathf.Sin(animT * 40f) : 1f);
            if (replaying) alpha = replayAlpha;
            if (styleMode != 0 && flash <= 0) StyleColors(ref c, ref cb);
            lastAlpha = alpha;
            c.a = alpha; cb.a = alpha;

            Vector2 sh = P[1] + (P[0] - P[1]).normalized * 0.06f * s;
            Draw.Set(lLegB, P[0], P[9], P[10]); Draw.Col(lLegB, cb);
            Draw.Set(lLegF, P[0], P[7], P[8]); Draw.Col(lLegF, c);
            Draw.Set(lTorso, P[0], P[1]); Draw.Col(lTorso, c);
            Draw.Set(lArmB, sh, P[5], P[6]); Draw.Col(lArmB, cb);
            Draw.Set(lArmF, sh, P[3], P[4]); Draw.Col(lArmF, c);
            sHead.transform.position = P[2];
            sHead.transform.rotation = Quaternion.identity;
            sHead.transform.localScale = Vector3.one * Skel.HeadR * 2f * s;
            sHead.color = c;

            if (under != null)
            {
                Color gc = underCol; gc.a *= alpha * (dead && glow ? 0.3f : 1f);
                Draw.Set(under[0], P[0], P[9], P[10]);
                Draw.Set(under[1], P[0], P[7], P[8]);
                Draw.Set(under[2], P[0], (P[0] + P[1]) * 0.5f, P[1]);
                Draw.Set(under[3], sh, P[5], P[6]);
                Draw.Set(under[4], sh, P[3], P[4]);
                foreach (var g in under) Draw.Col(g, gc);
                sHeadUnder.transform.position = P[2];
                Color hc = glow ? Draw.A(mainCol, 0.45f * alpha * (dead ? 0.3f : 1f)) : gc;
                sHeadUnder.color = hc;
            }

            // тень
            float minY = Mathf.Min(P[8].y, P[10].y);
            float hgt = Mathf.Max(0f, (dead ? Center.y - 0.3f : minY));
            float shK = Mathf.Clamp01(1f - hgt / 7f);
            sShadow.transform.position = new Vector3(Center.x, 0.02f, 0);
            sShadow.transform.localScale = new Vector3(1.7f * s * (0.6f + 0.4f * shK) * (dead ? 1.4f : 1f), 0.32f * s, 1f);
            sShadow.color = new Color(0, 0, 0, 0.3f * shK * alpha);

            Vector2 hd = P[2] - P[1];
            float ang = Mathf.Atan2(hd.y, hd.x) * Mathf.Rad2Deg - 90f;
            int rf = replaying ? replayRF : (dead ? facing : RenderFacing());
            lastRF = rf;
            headRoot.position = P[2];
            headRoot.rotation = Quaternion.Euler(0, 0, ang);
            headRoot.localScale = new Vector3(rf, 1, 1);
            foreach (var r in headRends) SetAlpha(r, alpha);

            Vector2 fd = P[4] - P[3];
            weaponRoot.position = P[4];
            weaponRoot.rotation = Quaternion.Euler(0, 0, Mathf.Atan2(fd.y, fd.x) * Mathf.Rad2Deg);
            weaponRoot.localScale = new Vector3(1, rf, 1);
            foreach (var r in weaponRends) SetAlpha(r, alpha);

            float t = animT;
            float wind = -rf * 0.2f * s - vel.x * 0.012f;
            if (lCape != null)
            {
                Vector2 p = P[1] - new Vector2(rf * 0.06f * s, 0.02f);
                lCape.SetPosition(0, p);
                for (int i = 1; i < 6; i++)
                {
                    p += new Vector2(wind * (dead ? 0.3f : 1f), -0.17f * s + Mathf.Sin(t * 9f + i) * 0.03f - vel.y * 0.004f);
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

            RenderGear(P, rf, alpha, c, cb);
            RenderSketch(P, sh, alpha);
            RenderClassic(P, sh, c, cb, alpha, rf);

            bool shOn = shieldT > 0 && !dead;
            lShield.enabled = shOn; sShieldGlow.enabled = shOn;
            if (shOn)
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

        LineRenderer SegLine(string n, int order, float width)
        {
            var l = Draw.Line(transform, n, width, Color.white, order, true, 4);
            l.positionCount = 2;
            return l;
        }

        SpriteRenderer Oval(string n, int order, Color col)
        {
            return Draw.Spr(transform, n, Draw.Circle, col, order);
        }

        void BuildClassic()
        {
            classic = (Game.I == null || Game.I.S.classicStick) && !glow && !silhouette;
            if (!classic) return;
            float s = Size, fw = 0.095f * s;
            // порядки: нога(з) 0, рука(з) 1, корпус 3, нога(п) 6, голова 8, рука(п) 12
            int[] ord = { baseOrder + 3, baseOrder + 12, baseOrder + 12, baseOrder + 1, baseOrder + 1, baseOrder + 6, baseOrder + 6, baseOrder + 0, baseOrder + 0 };
            segF = new LineRenderer[9];
            for (int i = 0; i < 9; i++) segF[i] = SegLine("seg", ord[i], i == 0 ? fw * 1.15f : fw);
            lNeckO = SegLine("neckO", baseOrder + 3, 0.075f * s);
            lNeckF = SegLine("neckF", baseOrder + 3, 0.035f * s);
            int[] dord = { baseOrder + 12, baseOrder + 1, baseOrder + 6, baseOrder + 0, baseOrder + 6, baseOrder + 12 };
            dotR = new SpriteRenderer[6]; dotF = new SpriteRenderer[6];
            for (int i = 0; i < 6; i++)
            {
                dotR[i] = Oval("dotR", dord[i], Color.black); dotR[i].transform.localScale = Vector3.one * 0.135f * s;
                dotF[i] = Oval("dotF", dord[i], Color.white); dotF[i].transform.localScale = Vector3.one * 0.07f * s;
            }
            sHeadOut = Oval("headOut", baseOrder + 8, Color.black);
            sHeadShade = Oval("headShade", baseOrder + 8, Color.gray);
            hOutF = Oval("handOutF", baseOrder + 12, Color.black); hFilF = Oval("handF", baseOrder + 12, Color.white);
            hOutB = Oval("handOutB", baseOrder + 1, Color.black); hFilB = Oval("handB", baseOrder + 1, Color.white);
            fOutF = Oval("footOutF", baseOrder + 6, Color.black); fFilF = Oval("footF", baseOrder + 6, Color.white);
            fOutB = Oval("footOutB", baseOrder + 0, Color.black); fFilB = Oval("footB", baseOrder + 0, Color.white);
            shadowL = new LineRenderer[5];
            for (int i = 0; i < 5; i++) { shadowL[i] = Draw.Line(transform, "castShadow", 0.12f * s, new Color(0, 0, 0, 0.15f), -1, true, 3); shadowL[i].positionCount = 3; }
            shadowHead = Draw.Spr(transform, "castShadowHead", Draw.Circle, new Color(0, 0, 0, 0.15f), -1);
            sShadow.enabled = false;
        }

        static void Z(Transform t, float z) { var p = t.position; p.z = z; t.position = p; }

        void Seg(LineRenderer l, Vector2 a, Vector2 b, float gap, Color c, float z)
        {
            Vector2 d = b - a;
            float len = d.magnitude;
            if (len < gap * 2.2f) { l.enabled = false; return; }
            l.enabled = true;
            d /= len;
            l.SetPosition(0, new Vector3(a.x + d.x * gap, a.y + d.y * gap, z));
            l.SetPosition(1, new Vector3(b.x - d.x * gap, b.y - d.y * gap, z));
            Draw.Col(l, c);
        }

        void PlaceOval(SpriteRenderer sr, Vector2 at, Vector2 axis, float w, float h, Color c, float z)
        {
            sr.transform.position = new Vector3(at.x, at.y, z);
            sr.transform.rotation = Quaternion.Euler(0, 0, Mathf.Atan2(axis.y, axis.x) * Mathf.Rad2Deg - 90f);
            sr.transform.localScale = new Vector3(w, h, 1f);
            sr.color = c;
        }

        void SetClassicVisible(bool on)
        {
            if (segF == null) return;
            foreach (var l in segF) l.enabled = on;
            foreach (var d in dotR) d.enabled = on;
            foreach (var d in dotF) d.enabled = on;
            foreach (var l in shadowL) l.enabled = on;
            lNeckO.enabled = lNeckF.enabled = on;
            sHeadOut.enabled = sHeadShade.enabled = on;
            hOutF.enabled = hOutB.enabled = hFilF.enabled = hFilB.enabled = on;
            fOutF.enabled = fOutB.enabled = fFilF.enabled = fFilB.enabled = on;
            shadowHead.enabled = on;
            sShadow.enabled = !on;
            if (under != null) { foreach (var u in under) u.enabled = !on && styleMode == 0; sHeadUnder.enabled = !on && styleMode == 0; }
            float w = Skel.Width * Size;
            float ow = on ? 0.15f * Size : w;
            lLegB.widthMultiplier = lLegF.widthMultiplier = lArmB.widthMultiplier = lArmF.widthMultiplier = ow;
            lTorso.widthMultiplier = on ? 0.165f * Size : w * 1.12f;
            if (sFistF != null) sFistF.enabled = sFistB.enabled = !on;
            if (lFootF != null) lFootF.enabled = lFootB.enabled = !on;
        }

        // Классический стикман как в анимациях: сегменты-трубки, суставы, кисти и стопы «яйцом», голова с тенью
        void RenderClassic(Vector2[] P, Vector2 sh, Color c, Color cb, float alpha, int rf)
        {
            bool on = classic && styleMode == 0;
            SetClassicVisible(on);
            if (!on) return;
            float s = Size;
            float lum = c.r * 0.3f + c.g * 0.59f + c.b * 0.11f;
            Color ink = lum < 0.22f ? new Color(0.82f, 0.82f, 0.84f) : new Color(0.06f, 0.06f, 0.07f);
            Color fill = flash > 0 ? Color.white : Color.Lerp(c, Color.white, lum < 0.22f ? 0.05f : 0.22f);
            Color fillB = flash > 0 ? Color.white : Color.Lerp(cb, Color.white, 0.1f);
            ink.a = fill.a = fillB.a = alpha;
            foreach (var l in new[] { lLegB, lLegF, lTorso, lArmB, lArmF }) Draw.Col(l, ink);
            float g = 0.045f * s, zf = -0.01f;
            Vector2 neckTop = P[1] + (P[2] - P[1]).normalized * 0.06f * s;
            // кости
            Seg(segF[0], P[0], neckTop, g, fill, zf);
            Seg(segF[1], sh, P[3], g, fill, zf); Seg(segF[2], P[3], P[4], g, fill, zf);
            Seg(segF[3], sh, P[5], g, fillB, zf); Seg(segF[4], P[5], P[6], g, fillB, zf);
            Seg(segF[5], P[0], P[7], g, fill, zf); Seg(segF[6], P[7], P[8], g, fill, zf);
            Seg(segF[7], P[0], P[9], g, fillB, zf); Seg(segF[8], P[9], P[10], g, fillB, zf);
            // шея
            Vector2 hd = (P[2] - P[1]).normalized;
            Vector2 headBottom = P[2] - hd * Skel.HeadR * s * 0.9f;
            lNeckO.SetPosition(0, new Vector3(P[1].x, P[1].y, 0)); lNeckO.SetPosition(1, new Vector3(headBottom.x, headBottom.y, 0));
            lNeckF.SetPosition(0, new Vector3(P[1].x, P[1].y, zf)); lNeckF.SetPosition(1, new Vector3(headBottom.x, headBottom.y, zf));
            Draw.Col(lNeckO, ink); Draw.Col(lNeckF, fill);
            // суставы
            Vector2[] jp = { sh, sh, P[7], P[9], P[0], P[3] };
            jp[0] = P[3]; jp[1] = P[5];
            Color[] jc = { fill, fillB, fill, fillB, fill, fill };
            for (int i = 0; i < 6; i++)
            {
                bool show = i < 4;
                dotR[i].enabled = dotF[i].enabled = show;
                if (!show) continue;
                dotR[i].transform.position = new Vector3(jp[i].x, jp[i].y, -0.02f); dotR[i].color = ink;
                dotF[i].transform.position = new Vector3(jp[i].x, jp[i].y, -0.03f); dotF[i].color = Color.Lerp(jc[i], ink, 0.2f);
            }
            // кисти и стопы «яйцом»
            Vector2 fa = (P[4] - P[3]).normalized, fb = (P[6] - P[5]).normalized;
            PlaceOval(hOutF, P[4] + fa * 0.05f * s, fa, 0.17f * s, 0.23f * s, ink, -0.02f);
            PlaceOval(hFilF, P[4] + fa * 0.05f * s, fa, 0.115f * s, 0.175f * s, fill, -0.03f);
            PlaceOval(hOutB, P[6] + fb * 0.05f * s, fb, 0.17f * s, 0.23f * s, ink, -0.02f);
            PlaceOval(hFilB, P[6] + fb * 0.05f * s, fb, 0.115f * s, 0.175f * s, fillB, -0.03f);
            Vector2 sa = (P[8] - P[7]).normalized, sb = (P[10] - P[9]).normalized;
            Vector2 fdir = (sa + new Vector2(rf * 0.55f, 0)).normalized, bdir = (sb + new Vector2(rf * 0.55f, 0)).normalized;
            PlaceOval(fOutF, P[8] + fdir * 0.06f * s, fdir, 0.17f * s, 0.27f * s, ink, -0.02f);
            PlaceOval(fFilF, P[8] + fdir * 0.06f * s, fdir, 0.115f * s, 0.215f * s, fill, -0.03f);
            PlaceOval(fOutB, P[10] + bdir * 0.06f * s, bdir, 0.17f * s, 0.27f * s, ink, -0.02f);
            PlaceOval(fFilB, P[10] + bdir * 0.06f * s, bdir, 0.115f * s, 0.215f * s, fillB, -0.03f);
            // голова: контур, тень-полумесяц сзади, заливка
            float hr = Skel.HeadR * s;
            PlaceOval(sHeadOut, P[2], hd, hr * 2f * 0.88f + 0.06f * s, hr * 2f + 0.06f * s, ink, 0f);
            PlaceOval(sHeadShade, P[2], hd, hr * 2f * 0.88f, hr * 2f, Color.Lerp(fill, ink.grayscale < 0.5f ? Color.black : Color.white, 0.22f), -0.01f);
            Vector2 fwd = new Vector2(hd.y, -hd.x) * -rf;
            PlaceOval(sHead, P[2] + fwd * 0.05f * s, hd, hr * 2f * 0.8f, hr * 2f * 0.95f, fill, -0.02f);
            // отбрасываемая тень на пол (свет слева сверху)
            float sa2 = Mathf.Clamp01(1f - Mathf.Min(P[8].y, P[10].y) / 8f) * 0.17f * alpha;
            int[][] ch = { new[] { 0, 9, 10 }, new[] { 0, 7, 8 }, new[] { 0, 1, 1 }, new[] { 1, 5, 6 }, new[] { 1, 3, 4 } };
            for (int k = 0; k < 5; k++)
            {
                for (int i = 0; i < 3; i++)
                {
                    Vector2 p = P[ch[k][i]];
                    shadowL[k].SetPosition(i, new Vector3(p.x + p.y * 0.6f, 0.02f + p.y * 0.05f, 0));
                }
                Draw.Col(shadowL[k], new Color(0, 0, 0, sa2));
            }
            shadowHead.transform.position = new Vector3(P[2].x + P[2].y * 0.6f, 0.02f + P[2].y * 0.05f, 0);
            shadowHead.transform.localScale = new Vector3(hr * 2.2f, hr * 0.5f, 1);
            shadowHead.color = new Color(0, 0, 0, sa2);
        }

        void RenderSketch(Vector2[] P, Vector2 sh, float alpha)
        {
            if (!sketch[0].enabled) return;
            bool comic = styleMode == 6;
            int[][] ch = { new[] { 0, 9, 10 }, new[] { 0, 7, 8 }, new[] { 0, 1, 1 }, new[] { 1, 5, 6 }, new[] { 1, 3, 4 } };
            for (int k = 0; k < 5; k++)
            {
                var l = sketch[k];
                for (int i = 0; i < 3; i++)
                {
                    int j = ch[k][i];
                    Vector2 p = (k >= 3 && i == 0) ? sh : P[j];
                    if (k == 2 && i == 1) p = (P[0] + P[1]) * 0.5f;
                    if (!comic) p += jit2[j] + (k % 2 == 0 ? Vector2.one : -Vector2.one) * 0.02f * Size;
                    l.SetPosition(i, p);
                }
                var cc = l.startColor; cc.a = (comic ? 1f : 0.7f) * alpha; Draw.Col(l, cc);
            }
            float r = Skel.HeadR * Size * (comic ? 1.12f : 1.04f);
            for (int i = 0; i < 18; i++)
            {
                float a = i / 18f * Mathf.PI * 2f;
                Vector2 o = comic ? Vector2.zero : jit2[i % 11] * 0.6f;
                sketchHead.SetPosition(i, P[2] + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r + o);
            }
            var hc = sketchHead.startColor; hc.a = (comic ? 1f : 0.75f) * alpha; Draw.Col(sketchHead, hc);
        }

        // смена рисовки: 0 обычная, 1 чернила, 2 негатив, 3 кадр удара, 4 плоская дуэль
        public void SetStyle(int st)
        {
            styleMode = st;
            if (under != null) { foreach (var u in under) u.enabled = st == 0; sHeadUnder.enabled = st == 0; }
            bool sk = st == 5 || st == 6;
            float w = Skel.Width * Size;
            foreach (var l in sketch)
            {
                l.enabled = sk;
                l.widthMultiplier = st == 6 ? w + 0.13f * Size : 0.035f;
                l.sortingOrder = st == 6 ? baseOrder - 1 : baseOrder + 15;
                Draw.Col(l, st == 6 ? new Color(0.02f, 0.02f, 0.02f) : new Color(0.12f, 0.12f, 0.14f, 0.7f));
            }
            sketchHead.enabled = sk;
            sketchHead.widthMultiplier = st == 6 ? 0.12f * Size : 0.035f;
            sketchHead.sortingOrder = st == 6 ? baseOrder - 1 : baseOrder + 15;
            Draw.Col(sketchHead, st == 6 ? new Color(0.02f, 0.02f, 0.02f) : new Color(0.12f, 0.12f, 0.14f, 0.75f));
            // тушь: конечности как мазки кисти — толстые у основания, тонкие к концу
            var curve = st == 7 ? new AnimationCurve(new Keyframe(0f, 1.35f), new Keyframe(0.5f, 0.95f), new Keyframe(1f, 0.5f)) : AnimationCurve.Constant(0f, 1f, 1f);
            foreach (var l in new[] { lArmF, lArmB, lLegF, lLegB, lTorso }) l.widthCurve = curve;
            heldOk = false;
        }

        void StyleColors(ref Color c, ref Color cb)
        {
            switch (styleMode)
            {
                case 1: c = new Color(0.05f, 0.05f, 0.06f); cb = new Color(0.33f, 0.33f, 0.35f); break;
                case 2: c = new Color(0.97f, 0.97f, 0.97f); cb = new Color(0.62f, 0.62f, 0.65f); break;
                case 3: c = new Color(0.03f, 0.03f, 0.03f); cb = new Color(0.03f, 0.03f, 0.03f); break;
                case 4:
                    c = team == 0 ? new Color(0.86f, 0.39f, 0.36f) : new Color(0.42f, 0.56f, 0.86f);
                    cb = Color.Lerp(c, Color.black, 0.18f);
                    break;
                case 5: c = new Color(0.25f, 0.25f, 0.27f); cb = new Color(0.55f, 0.55f, 0.57f); break;
                case 6:
                    c = team == 0 ? new Color(0.95f, 0.18f, 0.12f) : new Color(0.12f, 0.4f, 0.95f);
                    cb = Color.Lerp(c, Color.white, 0.25f);
                    break;
                case 7: c = new Color(0.04f, 0.04f, 0.05f); cb = new Color(0.3f, 0.29f, 0.28f); break;
            }
        }

        // показ кадра записи (с интерполяцией)
        public void ShowSnap(Battle.FSnap a, Battle.FSnap b, float k)
        {
            if (!gameObject.activeSelf) gameObject.SetActive(true);
            for (int i = 0; i < 11; i++) J[i] = b != null ? Vector2.Lerp(a.P[i], b.P[i], k) : a.P[i];
            replayRF = a.rf; replayAlpha = a.alpha;
            if (a.w != weapon) SetWeapon(a.w, ammo);
            animT += Time.unscaledDeltaTime;
            lTrail.enabled = false; lLaser.enabled = lLaserGlow.enabled = false;
            Render();
        }

        void RenderGear(Vector2[] P, int rf, float alpha, Color c, Color cb)
        {
            float s = Size;
            Vector2 u = (P[1] - P[0]); float ul = u.magnitude; u = ul > 0.001f ? u / ul : Vector2.up;
            Vector2 perp = new Vector2(-u.y, u.x);
            Vector2 sh = P[1] - u * 0.06f * s;
            if (sAura != null)
            {
                auraT += Time.deltaTime;
                bool on = !dead || deadTime < 1f;
                sAura.enabled = sAura2.enabled = on && alpha > 0.5f;
                Vector2 cen = Vector2.Lerp(P[0], P[1], 0.45f);
                float pulse = 1f + Mathf.Sin(auraT * 6f) * 0.08f;
                sAura.transform.position = cen; sAura.transform.localScale = new Vector3(2.3f * s * pulse, 3.4f * s * pulse, 1f);
                sAura2.transform.position = cen + Vector2.up * 0.2f * s; sAura2.transform.localScale = new Vector3(1.4f * s / pulse, 2.6f * s / pulse, 1f);
                if (on && Random.value < 0.5f)
                    battle.fx.Emit(cen + new Vector2(Random.Range(-0.5f, 0.5f), Random.Range(-1f, 0.6f)) * s, Vector2.up * Random.Range(1f, 2.5f), Draw.A(auraCol, 0.7f), Random.Range(0.06f, 0.14f) * s, 0.5f, 0f, false, 1f, true, 1f, 2.5f, true);
            }
            if (lShirt != null) { Draw.Set(lShirt, Vector2.Lerp(P[0], P[1], 0.05f), Vector2.Lerp(P[0], P[1], 0.92f)); SetAlpha(lShirt, alpha); }
            if (lSleeveF != null)
            {
                Draw.Set(lSleeveF, sh, Vector2.Lerp(sh, P[3], 0.75f)); Draw.Set(lSleeveB, sh, Vector2.Lerp(sh, P[5], 0.75f));
                SetAlpha(lSleeveF, alpha); SetAlpha(lSleeveB, alpha);
            }
            if (lPantsF != null)
            {
                Draw.Set(lPantsF, P[0], P[7], Vector2.Lerp(P[7], P[8], 0.85f)); Draw.Set(lPantsB, P[0], P[9], Vector2.Lerp(P[9], P[10], 0.85f));
                SetAlpha(lPantsF, alpha); SetAlpha(lPantsB, alpha);
            }
            if (lRobe != null)
            {
                Vector2 knees = (P[7] + P[9]) * 0.5f, feet = (P[8] + P[10]) * 0.5f;
                Vector2 hem = Vector2.Lerp(knees, feet, 0.55f) - new Vector2(vel.x * 0.02f, 0) + new Vector2(Mathf.Sin(animT * 7f) * 0.04f, 0);
                Draw.Set(lRobe, Vector2.Lerp(P[0], P[1], 0.15f), Vector2.Lerp(P[0], hem, 0.5f), hem);
                SetAlpha(lRobe, alpha);
            }
            if (lCoat != null)
            {
                Vector2 p0 = Vector2.Lerp(P[0], P[1], 0.6f) - new Vector2(rf * 0.05f * s, 0);
                lCoat.SetPosition(0, p0);
                Vector2 p = p0;
                for (int i = 1; i < 4; i++)
                {
                    p += new Vector2(-rf * 0.07f * s - vel.x * 0.01f, -0.3f * s + Mathf.Sin(animT * 8f + i) * 0.02f);
                    lCoat.SetPosition(i, p);
                }
                SetAlpha(lCoat, alpha);
            }
            if (lTie != null) { Vector2 t0 = P[1] - u * 0.12f * s + perp * 0.0f + new Vector2(rf * 0.04f * s, 0); Draw.Set(lTie, t0, t0 - u * 0.38f * s); SetAlpha(lTie, alpha); }
            if (sFistF != null)
            {
                sFistF.transform.position = P[4]; sFistB.transform.position = P[6];
                sFistF.color = c; sFistB.color = cb;
            }
            if (lFootF != null)
            {
                Draw.Set(lFootF, P[8], P[8] + new Vector2(rf * 0.1f * s, 0)); Draw.Set(lFootB, P[10], P[10] + new Vector2(rf * 0.1f * s, 0));
                Draw.Col(lFootF, c); Draw.Col(lFootB, cb);
            }
            if (lArmor != null) { Draw.Set(lArmor, Vector2.Lerp(P[0], P[1], 0.12f), Vector2.Lerp(P[0], P[1], 0.9f)); SetAlpha(lArmor, alpha); }
            if (lBelt != null) { Vector2 bc = Vector2.Lerp(P[0], P[1], 0.1f); Draw.Set(lBelt, bc - perp * 0.15f * s, bc + perp * 0.15f * s); SetAlpha(lBelt, alpha); }
            if (sPad != null) { sPad.transform.position = P[1] - u * 0.1f * s; SetAlpha(sPad, alpha); }
            if (sGloveF != null) { sGloveF.transform.position = P[4]; sGloveB.transform.position = P[6]; SetAlpha(sGloveF, alpha); SetAlpha(sGloveB, alpha); }
            if (lBootF != null)
            {
                Draw.Set(lBootF, Vector2.Lerp(P[7], P[8], 0.6f), P[8] + new Vector2(rf * 0.07f * s, 0));
                Draw.Set(lBootB, Vector2.Lerp(P[9], P[10], 0.6f), P[10] + new Vector2(rf * 0.07f * s, 0));
                SetAlpha(lBootF, alpha); SetAlpha(lBootB, alpha);
            }
            if (lWings != null)
            {
                Vector2 root = Vector2.Lerp(P[0], P[1], 0.8f) - new Vector2(rf * 0.08f * s, 0);
                float flap = Mathf.Sin(animT * (grounded ? 4f : 14f)) * (grounded ? 0.12f : 0.4f);
                for (int i = 0; i < 2; i++)
                {
                    float off = i == 0 ? 0f : 0.25f;
                    var l = lWings[i];
                    l.SetPosition(0, root);
                    l.SetPosition(1, root + new Vector2(-rf * (0.55f + off) * s, (0.55f + flap) * s));
                    l.SetPosition(2, root + new Vector2(-rf * (1.15f + off) * s, (0.85f + flap * 1.5f) * s));
                    l.SetPosition(3, root + new Vector2(-rf * (1.0f + off) * s, (0.05f + flap) * s));
                    SetAlpha(l, alpha);
                }
            }
            if (lTail != null)
            {
                Vector2 p = P[0] - new Vector2(rf * 0.05f * s, 0);
                for (int i = 0; i < 5; i++)
                {
                    lTail.SetPosition(i, p);
                    p += new Vector2(-rf * 0.22f * s, (-0.1f + i * 0.08f) * s + Mathf.Sin(animT * 6f + i) * 0.05f);
                }
                SetAlpha(lTail, alpha);
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
