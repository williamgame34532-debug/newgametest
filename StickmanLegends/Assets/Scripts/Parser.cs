using System;
using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Превращает текстовое описание игрока в бойца / оружие.
    public static class Parser
    {
        static string Norm(string s) { return (s ?? "").ToLowerInvariant().Replace('ё', 'е'); }

        static int Find(string t, string[] keys)
        {
            int best = -1;
            foreach (var k in keys)
            {
                int i = t.IndexOf(k, StringComparison.Ordinal);
                if (i >= 0 && (best < 0 || i < best)) best = i;
            }
            return best;
        }

        static bool Has(string t, params string[] keys) { return Find(t, keys) >= 0; }

        static int Count(string t, string[] keys)
        {
            int c = 0;
            foreach (var k in keys)
            {
                int i = 0;
                while ((i = t.IndexOf(k, i, StringComparison.Ordinal)) >= 0) { c++; i += k.Length; }
            }
            return c;
        }

        static string Consume(string t, string[] keys)
        {
            foreach (var k in keys) t = t.Replace(k, new string(' ', k.Length));
            return t;
        }

        static int Hash(string s)
        {
            unchecked
            {
                int h = 23;
                foreach (char c in s ?? "") h = h * 31 + c;
                return h & 0x7fffffff;
            }
        }

        // ---------- словари ----------
        static readonly string[] IMMORTAL = { "бессмерт", "неуязвим", "неубиваем", "не может умереть", "не умирает", "невозможно убить", "нельзя убить", "не убить", "immortal", "invincib", "invulnerab", "unkillable", "cannot die", "can't die", "never dies" };
        static readonly string[] WEAKM = { "слабост", "слабое место", "слабо к", "слаб к", "слаб перед", "боится", "уязвим", "погибает от", "умирает от", "weak to", "weakness", "fear", "afraid", "vulnerab", "dies from" };

        static readonly string[] SPEED = { "быстр", "скорост", "стремител", "молниенос", "шустр", "fast", "quick", "speed", "swift" };
        static readonly string[] STRENGTH = { "сильн", "мощн", "сила", "силач", "мускул", "качок", "громил", "берсерк", "strong", "power", "mighty", "brute" };
        static readonly string[] DEFENSE = { "стойк", "крепк", "брон", "живуч", "выносл", "танк", "толст", "прочн", "tank", "tough", "armor", "durable", "sturdy" };
        static readonly string[] AGILITY = { "ловк", "прыг", "акробат", "паркур", "гибк", "ниндзя", "agile", "acrobat", "jump", "ninja", "parkour" };
        static readonly string[] FRAIL = { "хрупк", "дохл", "тощ", "frail", "fragile", "skinny" };
        static readonly string[] SLOW = { "медлен", "неуклюж", "slow", "clumsy" };
        static readonly string[] BIG = { "огромн", "гигант", "великан", "громадн", "больш", "huge", "giant", "big", "massive" };
        static readonly string[] SMALL = { "маленьк", "крошечн", "мелк", "карлик", "гном", "tiny", "small", "little" };
        static readonly string[] FALSE_POS = { "огромн", "громил", "громад", "строг", "дорог" };
        static readonly string[] INTENS = { "очень", "супер", "мега", "невероятно", "крайне", "very", "super", "extremely", "ultra" };

        struct AbKw { public Ability a; public string[] k; public AbKw(Ability a, params string[] k) { this.a = a; this.k = k; } }

        static readonly AbKw[] ABIL =
        {
            new AbKw(Ability.Fireball, "огненн", "фаербол", "fireball", "огнем", "огонь", "огня", "пламя", "пламен", "fire", "flame", "пирокин"),
            new AbKw(Ability.Lightning, "молни", "электр", "гром", "разряд", "lightning", "thunder", "electric", "shock", "зевс", "zeus"),
            new AbKw(Ability.Teleport, "телепорт", "перемещ", "портал", "blink", "teleport", "portal"),
            new AbKw(Ability.Dash, "рывок", "рывк", "дэш", "таран", "dash", "charge"),
            new AbKw(Ability.Shield, "щит", "барьер", "защитное поле", "shield", "barrier", "force field"),
            new AbKw(Ability.Regen, "регенер", "лечит", "исцел", "восстанавл", "самолеч", "regen", "heal"),
            new AbKw(Ability.DoubleJump, "двойной прыжок", "летает", "полет", "крыль", "левитир", "джетпак", "ранец", "double jump", "fly", "flight", "wings", "jetpack"),
            new AbKw(Ability.IceShard, "ледян", "лед", "льд", "холод", "мороз", "заморажив", "замороз", "снег", "крио", "ice", "frost", "freeze", "cold"),
            new AbKw(Ability.GroundSlam, "по земле", "землетряс", "сотряс", "топает", "ударная волна", "ударной волн", "slam", "quake", "shockwave"),
            new AbKw(Ability.Invisibility, "невидим", "стелс", "камуфл", "призрак", "invisible", "stealth", "cloak", "ghost"),
            new AbKw(Ability.Rage, "ярост", "берсерк", "гнев", "бешен", "rage", "berserk", "fury"),
            new AbKw(Ability.Vampire, "вампир", "кровосос", "пьет кровь", "высасыв", "кровопийц", "vampire", "lifesteal", "drain"),
            new AbKw(Ability.Laser, "лазер", "луч", "из глаз", "laser", "beam"),
            new AbKw(Ability.Telekinesis, "телекинез", "силой мысли", "поднимает врагов", "псионик", "telekines", "psychic"),
        };

        static readonly string[] MAGE = { "маг ", "маг,", "маг.", "колдун", "волшеб", "чародей", "ведьм", "wizard", "mage", "sorcer", "witch" };

        struct AccKw { public Acc a; public string[] k; public AccKw(Acc a, params string[] k) { this.a = a; this.k = k; } }
        static readonly AccKw[] ACC =
        {
            new AccKw(Acc.Headband, "ниндзя", "повязк", "бандан", "ninja", "bandana", "headband"),
            new AccKw(Acc.WizardHat, "колдун", "волшеб", "чародей", "ведьм", "маг ", "маг,", "маг.", "wizard", "witch", "mage"),
            new AccKw(Acc.CowboyHat, "ковбой", "шляп", "шериф", "cowboy", "sheriff", " hat"),
            new AccKw(Acc.Horns, "рога", "рогат", "рогами", "демон", "дьявол", "викинг", "horn", "demon", "devil", "viking"),
            new AccKw(Acc.Crown, "корон", "корол", "царь", "царица", "принц", "king", "queen", "crown", "prince"),
            new AccKw(Acc.Halo, "ангел", "нимб", "святой", "angel", "halo", "holy"),
            new AccKw(Acc.Cape, "плащ", "накидк", "мантия", "супергер", "дракул", "cape", "cloak", "superhero"),
            new AccKw(Acc.Visor, "кибер", "робот", "киборг", "андроид", "визор", "очки", "cyber", "robot", "cyborg", "android", "visor"),
            new AccKw(Acc.Scarf, "шарф", "scarf"),
        };

        struct ColKw { public Color c; public string[] k; public ColKw(Color c, params string[] k) { this.c = c; this.k = k; } }
        static readonly ColKw[] COLORS =
        {
            new ColKw(new Color(0.82f, 0.08f, 0.08f), "красн", "алый", "алая", "red", "crimson"),
            new ColKw(new Color(0.1f, 0.25f, 0.85f), "синий", "синяя", "синего", "синем", "blue"),
            new ColKw(new Color(0.35f, 0.75f, 0.95f), "голуб", "cyan", "light blue"),
            new ColKw(new Color(0.15f, 0.65f, 0.2f), "зелен", "green"),
            new ColKw(new Color(0.06f, 0.06f, 0.07f), "черн", "black"),
            new ColKw(new Color(0.95f, 0.95f, 0.95f), "белый", "белая", "белого", "белом", "white"),
            new ColKw(new Color(0.95f, 0.85f, 0.1f), "желт", "yellow"),
            new ColKw(new Color(1f, 0.5f, 0.05f), "оранж", "orange"),
            new ColKw(new Color(0.55f, 0.15f, 0.8f), "фиолет", "пурпур", "purple", "violet"),
            new ColKw(new Color(1f, 0.45f, 0.7f), "розов", "pink"),
            new ColKw(new Color(0.5f, 0.5f, 0.52f), "серый", "серая", "серого", "grey", "gray"),
            new ColKw(new Color(0.9f, 0.72f, 0.2f), "золот", "gold"),
        };

        public static bool FindColor(string text, out Color c)
        {
            string t = Norm(text);
            int best = -1; c = Color.white;
            foreach (var ck in COLORS)
            {
                int i = Find(t, ck.k);
                if (i >= 0 && (best < 0 || i < best)) { best = i; c = ck.c; }
            }
            return best >= 0;
        }

        static readonly string[] T_FIRE = { "огн", "огон", "пламе", "жар", "свет", "солн", "свят", "fire", "flame", "light", "sun", "holy" };
        static readonly string[] T_ICE = { "лед", "льд", "холод", "мороз", "вод", "снег", "ice", "cold", "frost", "water" };
        static readonly string[] T_LIGHT = { "молни", "электр", "ток", "гром", "lightning", "electr", "thunder", "shock" };
        static readonly string[] T_POIS = { "яд", "токс", "отрав", "poison", "toxic", "venom" };
        static readonly string[] T_SHAD = { "тьм", "тен", "темн", "мрак", "shadow", "dark" };
        static readonly string[] T_BLADE = { "меч", "клин", "лезв", "нож", "остр", "топор", "blade", "sword", "knife", "cut", "axe" };
        static readonly string[] T_PIERCE = { "пул", "огнестрел", "стрел", "выстр", "bullet", "gun", "arrow" };
        static readonly string[] T_BLUNT = { "удар", "дуб", "молот", "тупо", "кулак", "blunt", "hammer", "punch", "fist" };

        static bool ParseType(string t, out DmgType type)
        {
            type = DmgType.Blunt;
            int best = -1;
            var tables = new List<KeyValuePair<string[], DmgType>>
            {
                new KeyValuePair<string[], DmgType>(T_FIRE, DmgType.Fire),
                new KeyValuePair<string[], DmgType>(T_ICE, DmgType.Ice),
                new KeyValuePair<string[], DmgType>(T_LIGHT, DmgType.Lightning),
                new KeyValuePair<string[], DmgType>(T_POIS, DmgType.Poison),
                new KeyValuePair<string[], DmgType>(T_SHAD, DmgType.Shadow),
                new KeyValuePair<string[], DmgType>(T_BLADE, DmgType.Blade),
                new KeyValuePair<string[], DmgType>(T_PIERCE, DmgType.Pierce),
                new KeyValuePair<string[], DmgType>(T_BLUNT, DmgType.Blunt),
            };
            foreach (var kv in tables)
            {
                int i = Find(t, kv.Key);
                if (i >= 0 && (best < 0 || i < best)) { best = i; type = kv.Value; }
            }
            return best >= 0;
        }

        static Element ParseElement(string t)
        {
            int best = -1; Element e = Element.None;
            var tables = new List<KeyValuePair<string[], Element>>
            {
                new KeyValuePair<string[], Element>(new[] { "огн", "пыла", "пламе", "свет", "свят", "fire", "flame", "burn", "лава", "lava", "holy" }, Element.Fire),
                new KeyValuePair<string[], Element>(new[] { "лед", "льд", "ледян", "мороз", "холод", "крио", "ice", "frost", "cryo" }, Element.Ice),
                new KeyValuePair<string[], Element>(new[] { "молни", "электр", "гром", "шок", "lightning", "electr", "thunder", "shock", "volt" }, Element.Lightning),
                new KeyValuePair<string[], Element>(new[] { "яд", "токс", "отрав", "кисл", "poison", "toxic", "venom", "acid" }, Element.Poison),
                new KeyValuePair<string[], Element>(new[] { "тьм", "тенев", "темн", "мрак", "проклят", "shadow", "dark", "cursed", "void" }, Element.Shadow),
            };
            foreach (var kv in tables)
            {
                int i = Find(t, kv.Key);
                if (i >= 0 && (best < 0 || i < best)) { best = i; e = kv.Value; }
            }
            return e;
        }

        // ================== БОЕЦ ==================
        public static FighterBuild BuildFighter(FighterDef d, List<WeaponDef> library)
        {
            var b = new FighterBuild();
            b.name = string.IsNullOrEmpty(d.name) ? "Безымянный" : d.name;
            b.color = d.color;
            b.drawing = d.drawing ?? new List<Stroke>();

            string t = " " + Norm(d.description + " " + d.name) + " ";

            // 1) Бессмертие запрещено
            bool imm = Has(t, IMMORTAL) || (Has(t, "бесконечн", "infinite") && Has(t, "здоров", "жизн", " hp", "health"));
            t = Consume(t, IMMORTAL);

            // 2) Слабость (вырезаем из текста, чтобы "боится огня" не давало огненных способностей)
            bool weakFound = false; DmgType weak = DmgType.Fire;
            int wi = Find(t, WEAKM);
            if (wi >= 0)
            {
                int len = Mathf.Min(45, t.Length - wi);
                string wt = t.Substring(wi, len);
                weakFound = ParseType(wt, out weak);
                t = t.Substring(0, wi) + new string(' ', len) + t.Substring(wi + len);
            }

            // 3) Характеристики (бюджет нормализуется: всемогущих не бывает)
            float intens = Count(t, INTENS) * 0.5f;
            float rs = 1 + Count(t, STRENGTH);
            float rv = 1 + Count(t, SPEED);
            t = Consume(t, new[] { "молниенос" });
            float rd = 1 + Count(t, DEFENSE);
            float ra = 1 + Count(t, AGILITY);
            rd -= Count(t, FRAIL) * 0.6f;
            rv -= Count(t, SLOW) * 0.6f;
            // усилитель уходит в самую выраженную черту
            float mx = Mathf.Max(Mathf.Max(rs, rv), Mathf.Max(rd, ra));
            if (intens > 0) { if (rs == mx) rs += intens; else if (rv == mx) rv += intens; else if (rd == mx) rd += intens; else ra += intens; }
            rs = Mathf.Max(0.4f, rs); rv = Mathf.Max(0.4f, rv); rd = Mathf.Max(0.4f, rd); ra = Mathf.Max(0.4f, ra);
            float mean = (rs + rv + rd + ra) / 4f;
            b.str = Mathf.Clamp(rs / mean, 0.6f, 1.7f);
            b.spd = Mathf.Clamp(rv / mean, 0.6f, 1.7f);
            b.def = Mathf.Clamp(rd / mean, 0.6f, 1.7f);
            b.agi = Mathf.Clamp(ra / mean, 0.6f, 1.7f);

            if (Has(t, BIG)) { b.size = 1.3f; b.str *= 1.15f; b.def *= 1.15f; b.spd *= 0.85f; b.agi *= 0.85f; }
            else if (Has(t, SMALL)) { b.size = 0.8f; b.str *= 0.9f; b.def *= 0.9f; b.spd *= 1.15f; b.agi *= 1.15f; }

            t = Consume(t, FALSE_POS);

            b.hp = Mathf.Round(100f * Mathf.Lerp(0.8f, 1.3f, Mathf.InverseLerp(0.6f, 1.7f, b.def)) * Mathf.Pow(b.size, 0.8f));

            // 4) Способности — в порядке упоминания, максимум 3
            var found = new List<KeyValuePair<int, Ability>>();
            foreach (var ak in ABIL)
            {
                int i = Find(t, ak.k);
                if (i >= 0) found.Add(new KeyValuePair<int, Ability>(i, ak.a));
            }
            found.Sort((x, y) => x.Key.CompareTo(y.Key));
            foreach (var kv in found) if (!b.abilities.Contains(kv.Value) && b.abilities.Count < 3) b.abilities.Add(kv.Value);
            if (Has(t, MAGE) && !b.abilities.Contains(Ability.Fireball) && b.abilities.Count < 3) b.abilities.Add(Ability.Fireball);

            var rnd = new System.Random(Hash(d.name + d.description));
            if (b.abilities.Count == 0)
            {
                Ability[] pool = { Ability.Dash, Ability.Fireball, Ability.Teleport, Ability.GroundSlam, Ability.Shield, Ability.IceShard, Ability.Lightning };
                b.abilities.Add(pool[rnd.Next(pool.Length)]);
                b.notes.Add("Способности не описаны — арена выдала случайную: " + Info.Name(b.abilities[0]));
            }

            // Стихия бойца (удары руками получают её)
            b.affinity = ParseElement(t);
            if (b.affinity == Element.None)
            {
                if (b.HasAb(Ability.Fireball)) b.affinity = Element.Fire;
                else if (b.HasAb(Ability.IceShard)) b.affinity = Element.Ice;
                else if (b.HasAb(Ability.Lightning)) b.affinity = Element.Lightning;
            }

            if (imm)
            {
                if (!b.abilities.Contains(Ability.Regen))
                {
                    if (b.abilities.Count >= 3) b.abilities.RemoveAt(2);
                    b.abilities.Insert(0, Ability.Regen);
                }
                b.notes.Add("БЕССМЕРТИЕ ЗАПРЕЩЕНО правилами арены! Заменено на регенерацию. Всё живое можно убить.");
            }

            if (!weakFound)
            {
                DmgType[] pool = { DmgType.Fire, DmgType.Ice, DmgType.Lightning, DmgType.Poison, DmgType.Blade, DmgType.Pierce, DmgType.Blunt, DmgType.Shadow };
                do { weak = pool[rnd.Next(pool.Length)]; }
                while (b.affinity != Element.None && weak == Info.ToType(b.affinity));
                b.notes.Add("Слабость не указана — арена назначила: " + Info.Name(weak));
            }
            b.weakness = weak;

            // 5) Внешность
            foreach (var ac in ACC) if (Has(t, ac.k) && !b.acc.Contains(ac.a)) b.acc.Add(ac.a);
            if (b.acc.Contains(Acc.WizardHat) && b.acc.Contains(Acc.CowboyHat)) b.acc.Remove(Acc.CowboyHat);
            if (b.acc.Contains(Acc.Crown)) { b.acc.Remove(Acc.WizardHat); b.acc.Remove(Acc.CowboyHat); }

            // 6) Оружие
            b.weapon = null;
            string wd = (d.weaponDesc ?? "").Trim();
            if (wd.Length > 0)
            {
                WeaponDef fromLib = null;
                if (library != null)
                    foreach (var w in library)
                        if (w != null && string.Equals(w.name.Trim(), wd, StringComparison.OrdinalIgnoreCase)) { fromLib = w; break; }
                b.weapon = fromLib != null ? BuildWeapon(fromLib) : BuildWeapon(new WeaponDef { name = wd, description = wd });
            }
            return b;
        }

        // ================== ОРУЖИЕ ==================
        struct WKw { public WeaponKind k; public string[] w; public WKw(WeaponKind k, params string[] w) { this.k = k; this.w = w; } }
        static readonly WKw[] WKINDS =
        {
            new WKw(WeaponKind.Chainsaw, "бензопил", "пила", "chainsaw"),
            new WKw(WeaponKind.Gun, "пистол", "револьв", "автомат", "винтов", "дробов", "ружь", "бласт", "пулемет", "снайпер", "узи", "дробаш", "gun", "pistol", "rifle", "shotgun", "blaster", "revolver", "uzi", "smg"),
            new WKw(WeaponKind.Bow, "арбалет", "лук ", "лук,", "лук.", "луком", "bow"),
            new WKw(WeaponKind.Thrown, "сюрикен", "метат", "гранат", "бомб", "дротик", "звездочк", "shuriken", "throwing", "grenade", "bomb", "dart"),
            new WKw(WeaponKind.Staff, "посох", "жезл", "палочк", "staff", "wand"),
            new WKw(WeaponKind.Spear, "копь", "копье", "алебард", "трезуб", "глеф", "коса", "spear", "lance", "halberd", "trident", "scythe", "пика"),
            new WKw(WeaponKind.Blunt, "молот", "дубин", "бита", "биту", "битой", "булав", "кувалд", "кастет", "лом", "труба", "сковород", "hammer", "club", "bat", "mace", "crowbar", "pan"),
            new WKw(WeaponKind.Blade, "меч", "катан", "нож", "клинок", "сабл", "топор", "секир", "кинжал", "мачете", "sword", "katana", "knife", "blade", "axe", "dagger", "machete"),
        };

        public static WeaponStats BuildWeapon(WeaponDef d)
        {
            var w = new WeaponStats();
            w.name = string.IsNullOrEmpty(d.name) ? "Оружие" : d.name;
            w.drawing = (d.drawing != null && d.drawing.Count > 0) ? d.drawing : null;
            string t = " " + Norm(d.name + " " + d.description) + " ";

            int best = -1; w.kind = WeaponKind.Blade;
            foreach (var wk in WKINDS)
            {
                int i = Find(t, wk.w);
                if (i >= 0 && (best < 0 || i < best)) { best = i; w.kind = wk.k; }
            }

            switch (w.kind)
            {
                case WeaponKind.Blade: w.dmg = 13; w.range = 1.6f; w.rate = 1f; w.bleed = true; w.knock = 1f; w.color = new Color(0.82f, 0.84f, 0.88f); break;
                case WeaponKind.Blunt: w.dmg = 15; w.range = 1.5f; w.rate = 0.85f; w.knock = 1.7f; w.color = new Color(0.35f, 0.32f, 0.3f); break;
                case WeaponKind.Spear: w.dmg = 12; w.range = 2.5f; w.rate = 0.95f; w.knock = 1.2f; w.bleed = true; w.color = new Color(0.75f, 0.78f, 0.8f); break;
                case WeaponKind.Gun: w.dmg = 8; w.range = 12f; w.rate = 1f; w.ammo = 14; w.knock = 0.8f; w.color = new Color(0.18f, 0.18f, 0.2f); break;
                case WeaponKind.Bow: w.dmg = 15; w.range = 14f; w.rate = 0.6f; w.ammo = 8; w.knock = 1f; w.bleed = true; w.color = new Color(0.45f, 0.28f, 0.12f); break;
                case WeaponKind.Thrown: w.dmg = 9; w.range = 10f; w.rate = 1.1f; w.ammo = 8; w.knock = 0.8f; w.bleed = true; w.color = new Color(0.6f, 0.62f, 0.66f); break;
                case WeaponKind.Chainsaw: w.dmg = 4; w.range = 1.5f; w.rate = 1f; w.knock = 0.4f; w.bleed = true; w.color = new Color(1f, 0.5f, 0.05f); break;
                case WeaponKind.Staff: w.dmg = 10; w.range = 1.8f; w.rate = 0.9f; w.knock = 1.3f; w.color = new Color(0.45f, 0.3f, 0.15f); break;
            }

            w.element = ParseElement(Consume(t, FALSE_POS));
            if (w.kind == WeaponKind.Staff && w.element == Element.None) w.element = Element.Lightning;

            if (Has(t, "топор", "секир", "axe")) { w.axe = true; w.dmg *= 1.15f; w.rate *= 0.9f; }
            if (Has(t, "бита", "биту", "битой", "дубин", "club", "bat")) w.bat = true;
            if (Has(t, "коса", "scythe")) { w.scythe = true; w.dmg *= 1.1f; }
            if (Has(t, "автомат", "винтов", "пулемет", "узи", "rifle", "machine", "smg", "uzi")) { w.rifle = true; w.rate *= 2f; w.dmg *= 0.7f; w.ammo = 30; }
            if (Has(t, "дробов", "дробаш", "shotgun")) { w.pellets = 5; w.dmg *= 0.55f; w.rate *= 0.6f; w.range = 7f; w.ammo = 8; }
            if (Has(t, "гранат", "бомб", "grenade", "bomb")) { w.explode = true; w.dmg = 16; w.ammo = 4; w.rate = 0.7f; }
            if (Has(t, "огромн", "больш", "двуруч", "тяжел", "гигант", "huge", "heavy", "great", "giant")) { w.dmg *= 1.35f; w.rate *= 0.75f; w.size = 1.3f; w.knock *= 1.3f; }
            if (Has(t, "легк", "быстр", "light", "quick", "fast")) { w.rate *= 1.25f; w.dmg *= 0.85f; }
            if (Has(t, "остр", "sharp")) { w.dmg *= 1.1f; w.bleed = true; }
            if (Has(t, "легендар", "эпичн", "божеств", "legendary", "epic", "divine")) w.dmg *= 1.15f;
            if (Has(t, "два ", "двойн", "парн", "dual", "twin")) w.rate *= 1.2f;
            if (Has(t, "маленьк", "мини", "small", "mini", "tiny")) { w.size = 0.8f; w.rate *= 1.1f; w.dmg *= 0.9f; }
            // предел силы оружия — арена любит баланс
            w.dmg = Mathf.Min(w.dmg, 26f);

            Color c;
            if (FindColor(t, out c)) w.color = c;
            else if (w.element != Element.None && w.kind != WeaponKind.Gun) w.color = Color.Lerp(w.color, Info.ElemColor(w.element), 0.6f);
            return w;
        }

        // ================== СЛУЧАЙНЫЙ БОЕЦ ==================
        static readonly string[] RN1 = { "Тёмный", "Огненный", "Ледяной", "Кибер", "Безумный", "Тихий", "Бешеный", "Грозовой", "Ржавый", "Красный", "Ночной", "Последний" };
        static readonly string[] RN2 = { "Ниндзя", "Самурай", "Маг", "Громила", "Ковбой", "Викинг", "Охотник", "Монах", "Робот", "Демон", "Рыцарь", "Призрак" };
        static readonly string[] RTRAIT = { "очень быстрый", "сильный", "стойкий как танк", "ловкий акробат", "огромный", "маленький и шустрый", "хрупкий, но быстрый" };
        static readonly string[] RAB = { "кидает огненные шары", "бьёт молнией", "телепортируется", "делает рывок", "ставит щит", "регенерирует", "делает двойной прыжок", "стреляет ледяными осколками", "бьёт по земле", "становится невидимым", "впадает в ярость", "вампир", "стреляет лазером из глаз", "владеет телекинезом" };
        static readonly string[] RWEAK = { "огонь", "лёд", "молния", "яд", "клинки", "пули", "тьма" };
        static readonly string[] RWEAP = { "Катана", "Огромный топор", "Бензопила", "Пистолет", "Автомат", "Лук", "Сюрикены", "Копьё", "Кувалда", "Ледяной меч", "Огненный посох", "Бита", "" };

        public static FighterDef RandomFighter(System.Random r)
        {
            var d = new FighterDef();
            d.name = RN1[r.Next(RN1.Length)] + " " + RN2[r.Next(RN2.Length)];
            string a1 = RAB[r.Next(RAB.Length)], a2 = RAB[r.Next(RAB.Length)];
            d.description = RTRAIT[r.Next(RTRAIT.Length)] + " " + d.name.ToLower() + ". " + char.ToUpper(a1[0]) + a1.Substring(1) + " и " + a2 + ". Слабость: " + RWEAK[r.Next(RWEAK.Length)] + ".";
            d.weaponDesc = RWEAP[r.Next(RWEAP.Length)];
            d.color = Color.HSVToRGB((float)r.NextDouble(), 0.75f, 0.85f);
            return d;
        }
    }
}
