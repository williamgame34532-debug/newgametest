using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Режим «Один против всех»: один герой, бесконечные волны стикменов со всех сторон.
    // Сначала безоружная пехота, потом мечники, стрелки, маги, громилы и боссы. Между волнами — передышка и лечение.
    public partial class Battle
    {
        public Fighter hero;
        public int wave, survKills, waveTotal, waveSpawned;
        public float interT, survSpawnT;
        public bool intermission;
        public bool bossAlive;
        public bool IsSurvival { get { return mode == Mode.Survival; } }
        bool Epic { get { return mode == Mode.Fight || mode == Mode.Survival; } }
        readonly System.Random srng = new System.Random();
        static List<WeaponStats> sMelee, sRanged;

        public int EnemiesAlive
        {
            get { int n = 0; foreach (var f in fighters) if ((f.team == 1 || f.origTeam == 1) && !f.dead && !f.minion && !f.remove) n++; return n; }
        }
        public int EnemiesLeft { get { return EnemiesAlive + Mathf.Max(0, waveTotal - waveSpawned); } }

        static WeaponStats MkW(string name, string desc) { return Parser.BuildWeapon(new WeaponDef { name = name, description = desc }); }

        static void EnsureEnemyWeapons()
        {
            if (sMelee != null) return;
            sMelee = new List<WeaponStats>
            {
                MkW("Нож", "нож, клинок"), MkW("Бита", "бита, дубина"), MkW("Меч", "меч"), MkW("Топор", "топор"),
                MkW("Копьё", "копьё"), MkW("Катана", "катана"), MkW("Молот", "боевой молот"), MkW("Коса", "коса"),
            };
            sRanged = new List<WeaponStats> { MkW("Лук", "лук"), MkW("Пистолет", "пистолет"), MkW("Сюрикены", "сюрикены, метательные") };
        }

        void SurvivalInit()
        {
            EnsureEnemyWeapons();
            hero = null;
            foreach (var f in fighters) if (f.team == 0 && !f.minion) { hero = f; break; }
            wave = 0; survKills = 0; waveTotal = 0; waveSpawned = 0; interT = 0; intermission = false; bossAlive = false;
            BuildCrowd();
        }

        // ---------- волны ----------
        void StartWave(int n)
        {
            wave = n;
            intermission = false;
            waveTotal = 4 + n * 2;
            waveSpawned = 0;
            survSpawnT = 0.6f;
            bool boss = n % 5 == 0;
            string title = boss ? "ВОЛНА " + n + " — БОСС!" : "ВОЛНА " + n;
            Announce(title, boss ? new Color(1f, 0.15f, 0.1f) : new Color(1f, 0.85f, 0.4f), 1.8f);
            audio.Sfx("gong", boss ? 1f : 0.7f, 0f);
            audio.Sfx("charge", 0.6f, 0f);
            cam.Shake(0.4f);
            if (boss) SpawnEnemy(true);
            // рисовка меняется с каждой волной
            if (Game.I != null && Game.I.S.styleShift && n > 1)
            {
                int[] seq = { 0, 8, 13, 4, 0, 12, 6, 10, 0, 7, 13, 9, 11, 1 };
                baseStyle = seq[n % seq.Length];
                ApplyStyle(baseStyle);
                Flash(0.1f, new Color(1, 1, 1, 0.7f));
            }
            crowdTarget = Mathf.Min(46, 8 + n * 3);
        }

        void EndWave()
        {
            intermission = true;
            interT = 7f;
            Announce("ВОЛНА " + wave + " ЗАЧИЩЕНА — ПЕРЕДЫШКА", new Color(0.5f, 1f, 0.55f), 2.4f);
            // награда: усилители с неба
            if (hero != null) for (int i = 0; i < (wave % 5 == 0 ? 3 : 2); i++) SpawnBoost(Random.Range(0, 6), hero.pos.x + (i - 0.5f) * 4f);
            audio.Sfx("gong", 0.5f, 0f);
            SlowMo(0.8f);
            // оружие с неба в награду
            if (dropPool != null && dropPool.Count > 0)
                for (int i = 0; i < (wave % 3 == 0 ? 2 : 1); i++)
                {
                    var w = dropPool[Random.Range(0, dropPool.Count)];
                    SpawnPickup(w, w.ammo, new Vector2(Mathf.Clamp(hero != null ? hero.pos.x + Random.Range(-5f, 5f) : 0f, -W + 2f, W - 2f), 15f), Vector2.zero, true);
                }
            if (Game.I != null && wave > Game.I.data.survivalBest) Game.I.data.survivalBest = wave;
        }

        void SurvivalTick(float dt)
        {
            if (hero == null) return;
            if (hero.dead)
            {
                phase = Phase.Victory; phaseT = 0; winner = 1;
                Announce("ПАЛ НА ВОЛНЕ " + wave, new Color(1f, 0.2f, 0.15f), 99f);
                audio.Sfx("gong", 0.9f, 0f);
                SlowMo(2f);
                if (Game.I != null && wave - 1 > Game.I.data.survivalBest) Game.I.data.survivalBest = wave - 1;
                return;
            }
            if (intermission)
            {
                interT -= dt;
                // передышка: здоровье восполняется
                float heal = hero.maxHp * 0.065f * dt;
                if (hero.hp < hero.maxHp)
                {
                    hero.hp = Mathf.Min(hero.maxHp, hero.hp + heal);
                    if (Random.value < dt * 10f)
                        fx.Emit(hero.Center + new Vector2(Random.Range(-0.5f, 0.5f), Random.Range(-0.8f, 0.6f)), Vector2.up * Random.Range(0.8f, 2f), new Color(0.4f, 1f, 0.5f, 0.9f), 0.1f, 0.7f, 0f, false, 1f, true, 1, 1, true);
                }
                if (interT <= 0f) StartWave(wave + 1);
                return;
            }
            if (wave == 0) { StartWave(1); return; }

            int cap = Mathf.Min(10, 3 + wave);
            survSpawnT -= dt;
            if (waveSpawned < waveTotal && survSpawnT <= 0f && EnemiesAlive < cap)
            {
                survSpawnT = Mathf.Max(0.35f, 1.8f - wave * 0.12f) * Random.Range(0.6f, 1.2f);
                SpawnEnemy(false);
                // иногда вбегают сразу пачкой
                if (wave >= 3 && Random.value < 0.3f && waveSpawned < waveTotal && EnemiesAlive < cap) SpawnEnemy(false);
            }
            bossAlive = false;
            foreach (var f in fighters) if (f.team == 1 && f.boss && !f.dead) bossAlive = true;
            if (waveSpawned >= waveTotal && EnemiesAlive == 0) EndWave();

            // трупы убираем, чтобы арена не превратилась в кашу (кровь остаётся)
            int corpses = 0;
            for (int i = fighters.Count - 1; i >= 0; i--)
            {
                var f = fighters[i];
                if (!f.dead || f == hero) continue;
                corpses++;
                if (f.deadTime > 14f || corpses > 14) f.remove = true;
            }
        }

        void SpawnEnemy(bool boss)
        {
            var b = boss ? BossBuild() : EnemyBuild();
            float hx = hero != null ? hero.pos.x : 0f;
            int side = Random.value < 0.5f ? -1 : 1;
            Vector2 at;
            bool sky = boss || Random.value < 0.18f;
            float edge = side * (W - 0.6f);
            if (Mathf.Abs(edge - hx) < 4f) side = -side;
            edge = side * (W - 0.6f);
            if (sky) at = new Vector2(Mathf.Clamp(hx + Random.Range(3f, 7f) * side, -W + 1f, W - 1f), 9f);
            else at = new Vector2(edge, 0f);
            var f = Spawn(b, 1, 1 + (waveSpawned % 3), at, -side);
            f.boss = boss;
            if (!boss) waveSpawned++;
            if (sky)
            {
                f.vel = new Vector2(0, -6f);
                Shock(new Vector2(at.x, 0.05f), boss ? 3f : 1.2f, boss ? new Color(1f, 0.15f, 0.1f, 0.9f) : new Color(1f, 1f, 1f, 0.6f));
            }
            else f.vel = new Vector2(-side * 6f, 0f);
            if (boss)
            {
                Announce("БОСС: " + b.name.ToUpper(), new Color(1f, 0.15f, 0.1f), 2f);
                Cinematic3D(new Vector2(at.x, 1.5f), 1.4f, side * 35f, side * 10f, 9f, 6f);
                audio.Sfx("explosion", 0.7f, 0f);
                cam.Shake(0.8f);
            }
        }

        static readonly string[] GRUNT = { "Рядовой", "Боец", "Громила", "Новобранец", "Задира", "Драчун" };
        static readonly string[] BLADE = { "Мечник", "Головорез", "Мясник", "Наёмник", "Рубака" };
        static readonly string[] SHOOT = { "Стрелок", "Лучник", "Метатель" };
        static readonly string[] NINJA = { "Ниндзя", "Тень", "Акробат" };
        static readonly string[] MAGE = { "Колдун", "Маг", "Шаман", "Чернокнижник" };
        static readonly string[] BRUTE = { "Берсерк", "Палач", "Тяжеловес", "Латник" };

        FighterBuild EnemyBuild()
        {
            // какие враги доступны на этой волне
            var tiers = new List<int> { 0, 0 };
            if (wave >= 2) { tiers.Add(1); tiers.Add(1); }
            if (wave >= 4) { tiers.Add(2); tiers.Add(3); }
            if (wave >= 6) tiers.Add(4);
            if (wave >= 7) { tiers.Add(5); tiers.Add(1); }
            if (wave >= 10) { tiers.Remove(0); tiers.Add(4); tiers.Add(5); }
            int t = tiers[srng.Next(tiers.Count)];
            float sc = 1f + 0.1f * (wave - 1);
            var b = new FighterBuild();
            b.size = Random.Range(0.88f, 1.02f);
            float g = Random.Range(0.04f, 0.14f);
            b.color = new Color(g, g, g + Random.Range(0.02f, 0.12f)); // тёмные силуэты
            b.acc.Add(Acc.Eyes);
            b.accCol[Acc.Eyes] = new Color(1f, 0.15f, 0.1f);
            b.killMasks.Add((int)(Random.value < 0.5f ? HF.Head : HF.Blade));
            b.str = Mathf.Min(1.25f, 0.6f + wave * 0.04f);
            b.spd = Random.Range(0.95f, 1.15f);
            b.agi = 1f; b.def = 0.8f;
            switch (t)
            {
                case 0:
                    b.name = GRUNT[srng.Next(GRUNT.Length)]; b.hp = 28f * sc; b.style = Random.value < 0.5f ? Style.Boxer : Style.Balanced;
                    if (Random.value < 0.3f) b.acc.Add(Acc.Headband);
                    break;
                case 1:
                    b.name = BLADE[srng.Next(BLADE.Length)]; b.hp = 38f * sc; b.style = Style.Balanced;
                    b.weapon = sMelee[srng.Next(wave < 4 ? 3 : sMelee.Count)];
                    if (Random.value < 0.4f) b.acc.Add(Acc.Mask);
                    break;
                case 2:
                    b.name = SHOOT[srng.Next(SHOOT.Length)]; b.hp = 30f * sc; b.style = Style.Balanced;
                    b.weapon = sRanged[srng.Next(sRanged.Count)];
                    b.acc.Add(Acc.Hood);
                    break;
                case 3:
                    b.name = NINJA[srng.Next(NINJA.Length)]; b.hp = 34f * sc; b.style = Style.Acrobat; b.agi = 1.5f; b.spd = 1.3f;
                    b.acc.Add(Acc.Mask); b.acc.Add(Acc.Headband);
                    b.accCol[Acc.Headband] = new Color(0.7f, 0.05f, 0.05f);
                    if (Random.value < 0.5f) b.secondary = sRanged[2];
                    break;
                case 4:
                    b.name = MAGE[srng.Next(MAGE.Length)]; b.hp = 40f * sc; b.style = Style.Balanced;
                    var ab = new[] { Ability.Fireball, Ability.Lightning, Ability.IceShard, Ability.Teleport, Ability.Summon };
                    b.abilities.Add(ab[srng.Next(ab.Length)]);
                    b.acc.Add(Acc.Hood); b.acc.Add(Acc.Aura); b.auraKind = 3;
                    b.accCol[Acc.Aura] = new Color(0.5f, 0.1f, 0.7f);
                    b.summonName = "Скелет";
                    break;
                default:
                    b.name = BRUTE[srng.Next(BRUTE.Length)]; b.hp = 85f * sc; b.style = Style.Brute; b.size = 1.22f; b.spd = 0.85f; b.str = Mathf.Min(1.5f, b.str + 0.3f); b.def = 1.2f;
                    b.acc.Add(Acc.Helmet); b.acc.Add(Acc.Armor);
                    b.weapon = Random.value < 0.6f ? sMelee[6] : sMelee[3];
                    break;
            }
            // с ростом волн — всё злее: ауры ярости, броня
            if (wave >= 8 && Random.value < 0.25f) b.abilities.Add(Ability.Rage);
            if (wave >= 12 && Random.value < 0.3f && !b.acc.Contains(Acc.ShoulderPads)) b.acc.Add(Acc.ShoulderPads);
            return b;
        }

        FighterBuild BossBuild()
        {
            var b = Parser.BuildFighter(Parser.RandomFighter(srng), null);
            float sc = 1f + 0.12f * wave;
            b.hp = Mathf.Max(b.hp, 100f) * 2.2f * sc;
            b.size = Mathf.Max(b.size, 1.35f);
            b.str = Mathf.Max(b.str, 1.15f);
            b.killOnly = false;
            if (!b.acc.Contains(Acc.Eyes)) b.acc.Add(Acc.Eyes);
            b.accCol[Acc.Eyes] = new Color(1f, 0.1f, 0.05f);
            if (!b.acc.Contains(Acc.Aura)) { b.acc.Add(Acc.Aura); b.accCol[Acc.Aura] = new Color(0.9f, 0.1f, 0.1f); b.auraKind = 1; }
            if (!b.acc.Contains(Acc.Crown) && Random.value < 0.5f) b.acc.Add(Acc.Crown);
            if (b.killMasks.Count == 0) b.killMasks.Add((int)HF.Head);
            string[] titles = { "Воевода", "Титан", "Владыка", "Палач", "Король арены", "Повелитель теней" };
            b.name = titles[srng.Next(titles.Length)] + " " + b.name;
            return b;
        }

        // ---------- толпа на фоне: стикмены бегут к полю боя ----------
        class Runner
        {
            public LineRenderer body, legA, legB, armA, armB;
            public SpriteRenderer head;
            public float x, y, speed, phase, scale;
            public int dir;
        }
        readonly List<Runner> crowd = new List<Runner>();
        Transform crowdRoot;
        int crowdTarget;

        void BuildCrowd()
        {
            if (crowdRoot != null) Destroy(crowdRoot.gameObject);
            crowd.Clear();
            crowdRoot = new GameObject("Crowd").transform;
            crowdRoot.SetParent(transform, false);
            crowdTarget = 8;
        }

        void ClearCrowd()
        {
            if (crowdRoot != null) Destroy(crowdRoot.gameObject);
            crowdRoot = null;
            crowd.Clear();
        }

        Runner NewRunner()
        {
            var r = new Runner();
            r.scale = Random.Range(0.32f, 0.55f);
            r.y = Mathf.Lerp(1.7f, 0.6f, (r.scale - 0.32f) / 0.23f);
            r.dir = Random.value < 0.5f ? 1 : -1;
            r.x = -r.dir * Random.Range(22f, 40f);
            r.speed = Random.Range(4f, 7.5f) * r.scale;
            r.phase = Random.value * 10f;
            Color c = CrowdColor(r.scale);
            float w = 0.13f * r.scale * 1.6f;
            int o = -46 + (int)(r.scale * 6f);
            r.body = Draw.Line(crowdRoot, "rb", w * 1.1f, c, o, false, 2);
            r.legA = Draw.Line(crowdRoot, "rl", w, c, o, false, 2); r.legA.positionCount = 3;
            r.legB = Draw.Line(crowdRoot, "rl", w, c, o, false, 2); r.legB.positionCount = 3;
            r.armA = Draw.Line(crowdRoot, "ra", w * 0.85f, c, o, false, 2); r.armA.positionCount = 3;
            r.armB = Draw.Line(crowdRoot, "ra", w * 0.85f, c, o, false, 2); r.armB.positionCount = 3;
            r.head = Draw.Spr(crowdRoot, "rh", Draw.Circle, c, o);
            r.head.transform.localScale = Vector3.one * 0.55f * r.scale;
            if (Random.value < 0.35f)
            {
                // у некоторых в руке оружие — силуэтом
                var wl = Draw.Line(r.head.transform, "rw", 0.18f, c, o, false, 0);
                Draw.Set(wl, new Vector2(0.6f * r.dir, -1.2f), new Vector2(1.6f * r.dir, 0.6f));
            }
            return r;
        }

        Color CrowdColor(float scale)
        {
            Color bg = cam.cam.backgroundColor;
            // дальние — светлее (воздушная перспектива), ближние — почти чёрные силуэты
            return Color.Lerp(new Color(0.03f, 0.02f, 0.04f), bg, Mathf.Lerp(0.55f, 0.15f, (scale - 0.32f) / 0.23f));
        }

        void CrowdTick(float dt)
        {
            if (crowdRoot == null) return;
            bool show = mode == Mode.Survival && phase != Phase.Victory && !c3d;
            crowdRoot.gameObject.SetActive(show);
            if (!show) return;
            while (crowd.Count < crowdTarget) crowd.Add(NewRunner());
            var cp = cam.cam.transform.position;
            crowdRoot.position = new Vector3(cp.x * 0.55f, cp.y * 0.35f, 0);
            for (int i = 0; i < crowd.Count; i++)
            {
                var r = crowd[i];
                r.x += r.dir * r.speed * dt;
                r.phase += dt * r.speed * 2.6f / r.scale;
                // добежал до поля боя — исчезает за горизонтом и появляется снова с края
                if (r.dir * r.x > -1.5f + Random.value * 2f) { r.x = -r.dir * Random.Range(24f, 38f); }
                float s = r.scale, ph = r.phase;
                Vector2 hip = new Vector2(r.x, r.y + 0.95f * s + Mathf.Abs(Mathf.Sin(ph)) * 0.12f * s);
                Vector2 neck = hip + new Vector2(r.dir * 0.35f * s, 0.85f * s);
                Draw.Set(r.body, hip, neck);
                r.head.transform.localPosition = neck + new Vector2(r.dir * 0.12f * s, 0.3f * s);
                for (int k = 0; k < 2; k++)
                {
                    float a = ph + k * Mathf.PI;
                    Vector2 knee = hip + new Vector2(r.dir * Mathf.Sin(a) * 0.4f * s, -0.45f * s);
                    Vector2 foot = knee + new Vector2(r.dir * (Mathf.Sin(a) * 0.3f - 0.15f) * s, -0.45f * s + Mathf.Max(0f, Mathf.Cos(a)) * 0.2f * s);
                    var l = k == 0 ? r.legA : r.legB;
                    l.SetPosition(0, hip); l.SetPosition(1, knee); l.SetPosition(2, foot);
                    Vector2 elbow = neck + new Vector2(-r.dir * Mathf.Sin(a) * 0.35f * s, -0.35f * s);
                    Vector2 hand = elbow + new Vector2(r.dir * 0.3f * s, 0.15f * s - Mathf.Sin(a) * 0.1f * s);
                    var ar = k == 0 ? r.armA : r.armB;
                    ar.SetPosition(0, neck); ar.SetPosition(1, elbow); ar.SetPosition(2, hand);
                }
            }
        }

        // Камера в выживании держит героя и ближайших врагов
        public bool SurvivalCamInclude(Fighter f)
        {
            if (hero == null || f == hero) return true;
            return Mathf.Abs(f.pos.x - hero.pos.x) < 7.5f;
        }
    }
}
