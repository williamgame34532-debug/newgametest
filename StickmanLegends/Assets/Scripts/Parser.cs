using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;

namespace StickWars
{
    // Разбор описаний героя и оружия.
    // Текст режется на слова; ключи — основы слов (совпадение с НАЧАЛОМ слова, "$" = слово целиком,
    // пробел = фраза из нескольких слов). Учитываются отрицания ("не", "без"), числа ("здоровье 500",
    // "сила 8/10", "в 2 раза быстрее") и условия смерти ("убить можно только ударом в голову").
    public static class Parser
    {
        // ======================= ТОКЕНЫ =======================
        class Tx
        {
            public List<string> w = new List<string>();
            public List<int> sent = new List<int>();
        }

        static Tx Tokenize(string s)
        {
            var t = new Tx();
            s = (s ?? "").ToLowerInvariant().Replace('ё', 'е');
            int sentence = 0;
            var cur = new System.Text.StringBuilder();
            Action flush = () =>
            {
                if (cur.Length == 0) return;
                string w = cur.ToString();
                float dummy;
                // "x2" / "2x" / "х3" -> "x" + число
                if (w.Length > 1 && (w[0] == 'x' || w[0] == 'х') && IsNum(w.Substring(1), out dummy)) { t.w.Add("x"); t.sent.Add(sentence); t.w.Add(w.Substring(1)); t.sent.Add(sentence); }
                else if (w.Length > 1 && (w[w.Length - 1] == 'x' || w[w.Length - 1] == 'х') && IsNum(w.Substring(0, w.Length - 1), out dummy)) { t.w.Add(w.Substring(0, w.Length - 1)); t.sent.Add(sentence); t.w.Add("x"); t.sent.Add(sentence); }
                else { t.w.Add(w); t.sent.Add(sentence); }
                cur.Length = 0;
            };
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (char.IsLetterOrDigit(c) || (c == '.' && cur.Length > 0 && char.IsDigit(cur[cur.Length - 1]) && i + 1 < s.Length && char.IsDigit(s[i + 1])))
                    cur.Append(c);
                else
                {
                    flush();
                    if (c == '.' || c == '!' || c == '?' || c == ';' || c == '\n') sentence++;
                    else if (c == ',' || c == '—' || c == '-' || c == ':' || c == '/' || c == '%')
                    {
                        t.w.Add(c == '—' ? "-" : c.ToString()); t.sent.Add(sentence);
                    }
                }
            }
            flush();
            return t;
        }

        static bool WordMatch(string tok, string stem)
        {
            if (stem.EndsWith("$")) return tok == stem.Substring(0, stem.Length - 1);
            return tok.StartsWith(stem, StringComparison.Ordinal);
        }

        // совпадение фразы, начиная с токена i; возвращает длину или 0
        static int MatchAt(Tx t, int i, string key)
        {
            var parts = key.Split(' ');
            int k = i;
            foreach (var p in parts)
            {
                if (p.Length == 0) continue;
                if (k >= t.w.Count || !WordMatch(t.w[k], p)) return 0;
                k++;
            }
            return k - i;
        }

        static List<int> FindAll(Tx t, string[] keys, int from = 0, int to = int.MaxValue)
        {
            var r = new List<int>();
            for (int i = from; i < t.w.Count && i < to; i++)
                foreach (var k in keys)
                    if (MatchAt(t, i, k) > 0) { r.Add(i); break; }
            return r;
        }

        static int First(Tx t, string[] keys, int from = 0, int to = int.MaxValue)
        {
            var l = FindAll(t, keys, from, to);
            return l.Count > 0 ? l[0] : -1;
        }

        static readonly string[] NEG = { "не$", "без$", "нет$", "ни$", "нисколько$", "not$", "no$", "without$", "never$", "isn$", "never$" };
        static readonly string[] INT_UP = { "очень$", "оч$", "супер", "мега", "невероятн", "крайне$", "безумно$", "чрезвычайно$", "максимально$", "самый$", "самая$", "very$", "super", "extremely$", "ultra", "insanely$" };
        static readonly string[] INT_DOWN = { "немного$", "слегка$", "чуть$", "чуть-чуть$", "slightly$", "a$" };

        static bool Negated(Tx t, int i)
        {
            for (int k = i - 1; k >= 0 && k >= i - 2; k--)
            {
                if (t.sent[k] != t.sent[i] || t.w[k] == ",") break;
                foreach (var n in NEG) if (WordMatch(t.w[k], n)) return true;
            }
            return false;
        }

        static float Intensity(Tx t, int i)
        {
            for (int k = i - 1; k >= 0 && k >= i - 2; k--)
            {
                if (t.sent[k] != t.sent[i]) break;
                foreach (var n in INT_UP) if (WordMatch(t.w[k], n)) return 1.8f;
                foreach (var n in INT_DOWN) if (WordMatch(t.w[k], n)) return 0.5f;
            }
            return 1f;
        }

        static bool IsNum(string s, out float v)
        {
            return float.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out v);
        }

        // ищем число рядом со словом i (в том же предложении)
        static bool NumberNear(Tx t, int i, int len, out float v, out bool outOf10, out bool times)
        {
            v = 0; outOf10 = false; times = false;
            int[] order = { 1, 2, 3, -1, -2, -3 };
            foreach (int off in order)
            {
                int k = off > 0 ? i + len - 1 + off : i + off;
                if (k < 0 || k >= t.w.Count || t.sent[k] != t.sent[i]) continue;
                if (IsNum(t.w[k], out v))
                {
                    if (k + 2 < t.w.Count && (t.w[k + 1] == "/" || t.w[k + 1] == "из") && t.w[k + 2] == "10") outOf10 = true;
                    if (k + 1 < t.w.Count && t.sent[k + 1] == t.sent[k] && (WordMatch(t.w[k + 1], "раз") || t.w[k + 1] == "x" || t.w[k + 1] == "х")) times = true;
                    if (k - 1 >= 0 && t.sent[k - 1] == t.sent[k] && (t.w[k - 1] == "x" || t.w[k - 1] == "х")) times = true;
                    return true;
                }
            }
            return false;
        }

        static int Hash(string s)
        {
            unchecked { int h = 23; foreach (char c in s ?? "") h = h * 31 + c; return h & 0x7fffffff; }
        }

        // ======================= СЛОВАРИ =======================
        static readonly string[] IMMORTAL = { "бессмерт", "неуязвим", "неубиваем", "не может умереть", "не умирает", "невозможно убить", "нельзя убить", "не убить", "нельзя победить", "непобедим", "вечн жив", "immortal", "invincib", "invulnerab", "unkillable", "cannot die", "can't die", "never dies" };

        static readonly string[] HP = { "здоров", "жизн", "хп$", "hp$", "хитпоинт", "health", "life$", "lives$", "очк здоров" };
        static readonly string[] HP_UP = { "живуч", "крепыш", "неубиваемый" };
        static readonly string[] STR = { "сильн", "сила$", "силу$", "силой$", "силы$", "мощн", "мощь", "силач", "мускул", "качок", "качк", "громил", "здоровяк", "strong", "strength", "power", "mighty", "brute" };
        static readonly string[] STR_DN = { "слабак", "слабый$", "слабая$", "дохлый", "weakling" };
        static readonly string[] SPD = { "быстр", "скорост", "стремител", "молниенос", "шустр", "резв", "проворн", "fast", "quick", "speed", "swift" };
        static readonly string[] SPD_DN = { "медлен", "неуклюж", "неповорот", "тормоз", "slow", "clumsy" };
        static readonly string[] DEF = { "стойк", "крепк", "брон", "защит", "толстокож", "танк", "прочн", "выносл", "tank", "tough", "armor", "armour", "durable", "sturdy", "defense", "defence" };
        static readonly string[] DEF_DN = { "хрупк", "хилый", "хилая", "тощ", "стеклян", "frail", "fragile", "skinny" };
        static readonly string[] AGI = { "ловк", "прыг", "прыжк", "акробат", "паркур", "гибк", "ниндзя", "уворот", "увертл", "agile", "acrobat", "jump", "ninja", "parkour", "dodge" };
        static readonly string[] DMG = { "урон", "damage", "атак", "attack" };
        static readonly string[] BIG = { "огромн", "гигант", "великан", "громадн", "большой", "большая", "крупн", "высокий", "высокая", "huge", "giant", "big$", "massive", "tall$" };
        static readonly string[] SMALL = { "маленьк", "крошечн", "мелк", "карлик", "гном", "низкий", "низкая", "tiny", "small", "little", "short$" };
        static readonly string[] HEIGHT = { "рост", "высот", "height", "размер", "size" };

        struct AbKw { public Ability a; public string[] k; public AbKw(Ability a, params string[] k) { this.a = a; this.k = k; } }
        static readonly AbKw[] ABIL =
        {
            new AbKw(Ability.Fireball, "огненн шар", "огненный шар", "фаербол", "файербол", "огнем", "огонь", "огня$", "огни", "пламя", "пламен", "огненн", "пирокин", "поджиг", "fire", "flame", "pyro"),
            new AbKw(Ability.Lightning, "молни", "электр", "гром$", "громом", "громов", "разряд", "грозов", "зевс", "тор$", "lightning", "thunder", "electric", "shock", "zeus"),
            new AbKw(Ability.Teleport, "телепорт", "перемещ", "портал", "исчеза и появ", "blink", "teleport", "portal", "warp"),
            new AbKw(Ability.Dash, "рывок", "рывк", "дэш", "таран", "налет", "врыва", "dash", "charge", "rush"),
            new AbKw(Ability.Shield, "щит", "барьер", "защитн пол", "силов пол", "shield", "barrier", "force field"),
            new AbKw(Ability.Regen, "регенер", "лечит", "лечится", "исцел", "восстанавл", "самолеч", "заживл", "хил$", "хилит", "regen", "heal"),
            new AbKw(Ability.DoubleJump, "двойн прыж", "летает", "летать", "полет", "крыл", "левитир", "парит", "джетпак", "ранец", "double jump", "fly", "flight", "wings", "jetpack", "hover"),
            new AbKw(Ability.IceShard, "ледян", "лед$", "льдом", "льда$", "холод", "мороз", "заморажив", "замороз", "снег", "крио", "ice", "frost", "freez", "cold", "cryo"),
            new AbKw(Ability.GroundSlam, "по земле", "землетряс", "сотряс", "топает", "топот", "ударн волн", "ударная волна", "slam", "quake", "shockwave", "stomp"),
            new AbKw(Ability.Invisibility, "невидим", "стелс", "камуфл", "прозрачн", "призрак", "invisib", "stealth", "cloak", "ghost"),
            new AbKw(Ability.Rage, "ярост", "берсерк", "гнев", "бешен", "звере", "rage", "berserk", "fury", "frenzy"),
            new AbKw(Ability.Vampire, "вампир", "кровосос", "пьет кров", "пьет кровь", "высасыв", "кровопий", "vampir", "lifesteal", "drain"),
            new AbKw(Ability.Laser, "лазер", "луч", "из глаз", "laser", "beam", "eye beam"),
            new AbKw(Ability.Telekinesis, "телекинез", "силой мысли", "поднима врагов", "псионик", "психокинез", "telekines", "psychic", "psionic"),
        };
        static readonly string[] MAGE = { "маг$", "мага$", "магом$", "колдун", "волшеб", "чародей", "ведьм", "wizard", "mage$", "sorcer", "witch" };

        struct AccKw { public Acc a; public string[] k; public AccKw(Acc a, params string[] k) { this.a = a; this.k = k; } }
        static readonly AccKw[] ACC =
        {
            new AccKw(Acc.Headband, "ниндзя", "повязк", "бандан", "ninja", "bandana", "headband"),
            new AccKw(Acc.WizardHat, "колдун", "волшеб", "чародей", "ведьм", "маг$", "колпак", "wizard", "witch", "mage$"),
            new AccKw(Acc.CowboyHat, "ковбо", "шляп", "шериф", "cowboy", "sheriff", "hat$"),
            new AccKw(Acc.Horns, "рога$", "рогат", "рогами", "демон", "дьявол", "черт$", "викинг", "horn", "demon", "devil", "viking"),
            new AccKw(Acc.Crown, "корон", "корол", "царь", "царица", "принц", "император", "king", "queen", "crown", "prince", "emperor"),
            new AccKw(Acc.Halo, "ангел", "нимб", "святой", "святая", "angel", "halo", "saint"),
            new AccKw(Acc.Cape, "плащ", "накидк", "мантия", "мантией", "супергер", "дракул", "cape", "cloak", "superhero", "mantle"),
            new AccKw(Acc.Visor, "кибер", "робот", "киборг", "андроид", "визор", "очки", "cyber", "robot", "cyborg", "android", "visor", "goggles"),
            new AccKw(Acc.Scarf, "шарф", "scarf"),
        };

        struct ColKw { public Color c; public string[] k; public ColKw(Color c, params string[] k) { this.c = c; this.k = k; } }
        static readonly ColKw[] COLORS =
        {
            new ColKw(new Color(0.82f, 0.08f, 0.08f), "красн", "алый", "алая", "алого", "red$", "crimson"),
            new ColKw(new Color(0.1f, 0.25f, 0.85f), "син", "blue$"),
            new ColKw(new Color(0.35f, 0.75f, 0.95f), "голуб", "cyan", "бирюз"),
            new ColKw(new Color(0.15f, 0.65f, 0.2f), "зелен", "green"),
            new ColKw(new Color(0.06f, 0.06f, 0.07f), "черн", "black"),
            new ColKw(new Color(0.95f, 0.95f, 0.95f), "бел", "white"),
            new ColKw(new Color(0.95f, 0.85f, 0.1f), "желт", "yellow"),
            new ColKw(new Color(1f, 0.5f, 0.05f), "оранж", "рыж", "orange"),
            new ColKw(new Color(0.55f, 0.15f, 0.8f), "фиолет", "пурпур", "лилов", "purple", "violet"),
            new ColKw(new Color(1f, 0.45f, 0.7f), "розов", "pink"),
            new ColKw(new Color(0.5f, 0.5f, 0.52f), "сер$", "серый", "серая", "серого", "grey", "gray"),
            new ColKw(new Color(0.9f, 0.72f, 0.2f), "золот", "gold"),
            new ColKw(new Color(0.5f, 0.3f, 0.15f), "коричн", "бурый", "brown"),
        };

        public static bool FindColor(string text, out Color c)
        {
            var t = Tokenize(text);
            int best = -1; c = Color.white;
            foreach (var ck in COLORS)
            {
                foreach (int i in FindAll(t, ck.k))
                {
                    if (Negated(t, i)) continue;
                    if (best < 0 || i < best) { best = i; c = ck.c; }
                    break;
                }
            }
            return best >= 0;
        }

        // признаки удара для условий смерти
        struct FKw { public HF f; public string[] k; public FKw(HF f, params string[] k) { this.f = f; this.k = k; } }
        static readonly FKw[] FEAT =
        {
            new FKw(HF.Head, "голов", "башк", "череп", "мозг", "лоб$", "лицо", "морд", "хедшот", "head", "skull", "brain", "face"),
            new FKw(HF.Back, "спин", "сзади", "со спины", "тыл", "back$", "behind"),
            new FKw(HF.Pierce, "проткн", "пронз", "проколо", "прокол", "колющ", "укол", "копь", "копье", "пика", "пикой", "стрел", "пул", "выстрел", "огнестрел", "сердц", "насквозь", "кол$", "колом", "осинов", "stab", "pierc", "impal", "arrow", "bullet", "shot", "spear", "heart", "stake"),
            new FKw(HF.Blade, "меч", "клинк", "клинок", "лезв", "нож", "разруб", "разрез", "отруб", "обезглав", "катан", "топор", "сабл", "сабель", "кинжал", "blade", "sword", "cut", "slash", "knife", "axe", "behead", "katana"),
            new FKw(HF.Blunt, "дубин", "молот", "тупы", "тупым", "дробящ", "раздав", "размоз", "бита", "битой", "кувалд", "hammer", "club", "blunt", "crush", "smash"),
            new FKw(HF.Unarmed, "кулак", "голыми", "рукопаш", "кулачн", "fist", "punch", "bare hand"),
            new FKw(HF.Fire, "огн", "огон", "пламе", "сжечь", "сжига", "сгорит", "жар", "лава", "солн", "свет$", "светом", "света$", "святой", "святым", "fire", "flame", "burn", "sun", "holy", "light$"),
            new FKw(HF.Ice, "лед", "льд", "холод", "мороз", "замороз", "заморож", "снег", "вод", "ice", "cold", "frost", "freez", "water"),
            new FKw(HF.Lightning, "молни", "электр", "ток$", "током", "разряд", "гроз", "гром$", "громом", "lightning", "electr", "thunder", "shock"),
            new FKw(HF.Poison, "яд", "токс", "отрав", "кислот", "poison", "toxic", "venom", "acid"),
            new FKw(HF.Shadow, "тьм", "тен", "темн", "мрак", "shadow", "dark"),
            new FKw(HF.Explosion, "взрыв", "бомб", "гранат", "динамит", "подорв", "explo", "bomb", "grenade", "dynamite"),
            new FKw(HF.Fall, "падени", "упасть", "об стен", "о стен", "стену", "о землю", "об землю", "разбить", "fall", "wall"),
            new FKw(HF.Magic, "маги", "заклин", "колдовств", "spell", "magic"),
        };

        static readonly string[] WEAK_MARK = { "слабост", "слабое место", "слабое", "слаб к", "слаб перед", "боится", "боится", "уязвим", "weak", "fear", "afraid", "vulnerab", "страшится" };
        static readonly string[] KILL_MARK = { "разруш", "уничтож", "сломать", "destroy", "убить", "убит", "убьет", "убивает", "убиваем", "победить", "одолеть", "умирает", "умрет", "погибает", "погибнет", "умереть", "смерт", "kill", "defeat", "die$", "dies$", "slain" };
        static readonly string[] ONLY = { "только", "лишь", "единствен", "исключительно", "кроме", "only$", "solely", "except" };
        static readonly string[] IMMUNE = { "иммун", "невосприимч", "не берет", "не берут", "не действует", "не действуют", "не страшн", "не боится", "не горит", "огнеупор", "immune", "resist" };

        // =================== РАЗБОР ПРИЗНАКОВ СМЕРТИ ===================
        // разбиваем участок на альтернативы ("или", ",", "и") — внутри альтернативы признаки складываются (И)
        static List<int> ParseAlternatives(Tx t, int from, int to)
        {
            var alts = new List<int>();
            int cur = 0;
            for (int i = from; i < to && i < t.w.Count; i++)
            {
                string w = t.w[i];
                if (w == "," || w == "или" || w == "либо" || w == "or" || w == "и" || w == "and" || w == "-")
                {
                    if (cur != 0) { alts.Add(cur); cur = 0; }
                    continue;
                }
                foreach (var f in FEAT)
                {
                    bool hit = false;
                    foreach (var k in f.k) if (MatchAt(t, i, k) > 0) { hit = true; break; }
                    if (hit)
                    {
                        cur |= (int)f.f;
                        // "обезглавить" = клинок + голова, "сердце" = протыкание
                        if (WordMatch(w, "обезглав") || WordMatch(w, "behead")) cur |= (int)HF.Head;
                        break;
                    }
                }
            }
            if (cur != 0) alts.Add(cur);
            // "голова" и "молния" через "и" в одном выражении скорее И: "проткнуть молнией и в голову" — оставляем как ИЛИ (щедрее)
            return alts;
        }

        static void ParseKillRules(Tx t, FighterBuild b)
        {
            int n = t.w.Count;
            for (int i = 0; i < n; i++)
            {
                bool isWeak = false, isKill = false, isImm = false;
                int len = 0;
                foreach (var k in IMMUNE) { int l = MatchAt(t, i, k); if (l > 0) { isImm = true; len = l; break; } }
                if (!isImm) foreach (var k in WEAK_MARK) { int l = MatchAt(t, i, k); if (l > 0) { isWeak = true; len = l; break; } }
                if (!isImm && !isWeak) foreach (var k in KILL_MARK) { int l = MatchAt(t, i, k); if (l > 0) { isKill = true; len = l; break; } }
                if (!isImm && !isWeak && !isKill) continue;
                bool neg = Negated(t, i);
                if (isWeak && neg) { isWeak = false; isImm = true; } // "не боится огня"
                if (isKill && neg && First(t, ONLY, SentStart(t, i), SentEnd(t, i)) < 0) { i += len - 1; continue; } // "не убить" — уже как бессмертие

                int s0 = SentStart(t, i), s1 = SentEnd(t, i);
                // текст после маркера; если там ничего нет — до маркера (с последней запятой)
                var alts = ParseAlternatives(t, i + len, s1);
                if (alts.Count == 0)
                {
                    int from = s0;
                    for (int k = i - 1; k >= s0; k--) if (t.w[k] == ",") { from = k + 1; break; }
                    alts = ParseAlternatives(t, from, i);
                }
                bool only = isKill || First(t, ONLY, s0, s1) >= 0;
                if (isImm)
                {
                    foreach (var a in alts)
                    {
                        b.immuneMask |= a;
                        b.understood.Add("иммунитет: " + HFInfo.Describe(a));
                    }
                }
                else if (alts.Count > 0)
                {
                    foreach (var a in alts) if (!b.killMasks.Contains(a)) b.killMasks.Add(a);
                    if (only) b.killOnly = true;
                }
                else
                {
                    var words = new List<string>();
                    for (int k = i; k < s1 && words.Count < 8; k++) if (t.w[k] != ",") words.Add(t.w[k]);
                    b.notes.Add("Не понял условие «" + string.Join(" ", words.ToArray()) + "» — назови, чем именно (огонь, голова, проткнуть, в спину...)");
                }
                i = Math.Max(i, s1 - 1);
            }
        }

        static int SentStart(Tx t, int i) { int s = t.sent[i]; int k = i; while (k > 0 && t.sent[k - 1] == s) k--; return k; }
        static int SentEnd(Tx t, int i) { int s = t.sent[i]; int k = i; while (k < t.w.Count && t.sent[k] == s) k++; return k; }

        // ======================= БОЕЦ =======================
        public static FighterBuild BuildFighter(FighterDef d, List<WeaponDef> library)
        {
            var b = new FighterBuild();
            b.name = string.IsNullOrEmpty(d.name) ? "Безымянный" : d.name;
            b.color = d.color;
            b.drawing = d.drawing ?? new List<Stroke>();
            var t = Tokenize(d.description + " . " + d.name);
            var rnd = new System.Random(Hash(d.name + d.description));

            // --- бессмертие
            bool imm = false;
            for (int i = 0; i < t.w.Count; i++)
                foreach (var k in IMMORTAL)
                    if (MatchAt(t, i, k) > 0) { imm = true; break; }
            for (int i = 0; i < t.w.Count; i++)
                if (WordMatch(t.w[i], "бесконечн") || WordMatch(t.w[i], "infinite") || WordMatch(t.w[i], "безгранич"))
                    if (i + 1 < t.w.Count && (WordMatch(t.w[i + 1], "здоров") || WordMatch(t.w[i + 1], "жизн") || WordMatch(t.w[i + 1], "hp") || WordMatch(t.w[i + 1], "health"))) imm = true;

            // --- условия смерти / слабости / иммунитеты
            ParseKillRules(t, b);
            if (b.killOnly) imm = false; // "нельзя убить ничем, кроме огня" — это условие, а не бессмертие

            // --- характеристики (без нормализации: что написал — то и получил, в разумных пределах)
            float str = 1, spd = 1, def = 1, agi = 1, hpMul = 1, size = 1;
            float hpAbs = -1;
            Stat(t, STR, ref str, "сила", b);
            Stat(t, SPD, ref spd, "скорость", b);
            Stat(t, DEF, ref def, "защита", b);
            Stat(t, AGI, ref agi, "ловкость", b);
            Down(t, STR_DN, ref str, "сила", b);
            Down(t, SPD_DN, ref spd, "скорость", b);
            Down(t, DEF_DN, ref def, "защита", b);

            float dmgMul = 1f;
            foreach (int i in FindAll(t, DMG))
            {
                float v; bool o10, times;
                if (NumberNear(t, i, 1, out v, out o10, out times))
                {
                    if (times) dmgMul = Mathf.Clamp(v, 0.3f, 3f);
                    else if (o10 || v <= 10) dmgMul = Mathf.Clamp(v / 5f, 0.3f, 2.5f);
                    else if (v <= 100) dmgMul = Mathf.Clamp(v / 15f, 0.3f, 3f);
                    b.understood.Add("урон x" + dmgMul.ToString("0.0"));
                }
            }

            foreach (int i in FindAll(t, HP))
            {
                float v; bool o10, times;
                int len = 1;
                if (NumberNear(t, i, len, out v, out o10, out times))
                {
                    if (times) hpMul *= Mathf.Clamp(v, 0.2f, 5f);
                    else if (o10) hpAbs = v * 25f;
                    else hpAbs = v;
                }
                else
                {
                        bool many = i > 0 && (WordMatch(t.w[i - 1], "много") || WordMatch(t.w[i - 1], "огромн") || WordMatch(t.w[i - 1], "больш") || WordMatch(t.w[i - 1], "куча") || WordMatch(t.w[i - 1], "lots") || WordMatch(t.w[i - 1], "high"));
                    bool few = i > 0 && (WordMatch(t.w[i - 1], "мало") || WordMatch(t.w[i - 1], "немного") || WordMatch(t.w[i - 1], "low") || WordMatch(t.w[i - 1], "little"));
                    if (many) hpMul *= 1.5f;
                    if (few) hpMul *= 0.6f;
                }
            }
            foreach (int i in FindAll(t, HP_UP)) if (!Negated(t, i)) hpMul *= 1.35f;

            foreach (int i in FindAll(t, BIG)) if (!Negated(t, i)) { size = Mathf.Max(size, 1.3f * (Intensity(t, i) > 1 ? 1.15f : 1f)); }
            foreach (int i in FindAll(t, SMALL)) if (!Negated(t, i)) { size = Mathf.Min(size, 0.78f); }
            foreach (int i in FindAll(t, HEIGHT))
            {
                float v; bool o10, times;
                if (NumberNear(t, i, 1, out v, out o10, out times))
                {
                    if (v > 3 && v < 400) v /= 100f; // сантиметры
                    if (v > 0.3f && v < 10f) { size = Mathf.Clamp(v / 1.8f, 0.6f, 2f); b.understood.Add("рост " + v.ToString("0.0") + " м"); }
                }
            }
            if (size > 1.05f) { str *= 1.15f; def *= 1.15f; spd *= 0.88f; agi *= 0.85f; }
            if (size < 0.95f) { spd *= 1.12f; agi *= 1.15f; }

            b.str = Mathf.Clamp(str, 0.3f, 3f);
            b.spd = Mathf.Clamp(spd, 0.4f, 2.6f);
            b.def = Mathf.Clamp(def, 0.3f, 3f);
            b.agi = Mathf.Clamp(agi, 0.4f, 2.6f);
            b.size = size;
            b.dmgMul = dmgMul;
            float hp = hpAbs > 0 ? hpAbs : 100f * Mathf.Lerp(0.85f, 1.25f, Mathf.InverseLerp(0.5f, 2f, b.def)) * Mathf.Pow(size, 0.8f);
            hp *= hpMul;
            if (hp > 2000) { b.notes.Add("Здоровье " + Mathf.RoundToInt(hp) + " — слишком много, арена урезала до 2000."); hp = 2000; }
            b.hp = Mathf.Max(10f, Mathf.Round(hp));
            if (hpAbs > 0 || hpMul != 1f) b.understood.Add("здоровье " + b.hp);

            // --- стиль боя
            if (Any(t, "бокс", "боксер", "кулак", "boxer", "boxing")) b.style = Style.Boxer;
            else if (Any(t, "карат", "тхэквондо", "тэквондо", "кикбокс", "ногами", "ноги$", "пинк", "kick", "karate", "taekwondo")) b.style = Style.Kicker;
            else if (Any(t, "акробат", "паркур", "ниндзя", "сальто", "флип", "acrobat", "parkour", "ninja", "flip")) b.style = Style.Acrobat;
            else if (Any(t, "громил", "борец", "качок", "здоровяк", "тяжеловес", "brute", "wrestler", "brawler")) b.style = Style.Brute;
            if (b.style != Style.Balanced) b.understood.Add("стиль: " + StyleName(b.style));

            // --- способности (в порядке упоминания, отрицания отбрасываются)
            var found = new List<KeyValuePair<int, Ability>>();
            foreach (var ak in ABIL)
            {
                foreach (int i in FindAll(t, ak.k))
                {
                    if (Negated(t, i)) continue;
                    if (InKillClause(t, i)) continue; // "боится огня" — не способность
                    found.Add(new KeyValuePair<int, Ability>(i, ak.a));
                    break;
                }
            }
            found.Sort((x, y) => x.Key.CompareTo(y.Key));
            foreach (var kv in found) if (!b.abilities.Contains(kv.Value) && b.abilities.Count < 4) b.abilities.Add(kv.Value);
            if (First(t, MAGE) >= 0 && !b.abilities.Contains(Ability.Fireball) && b.abilities.Count < 4) b.abilities.Add(Ability.Fireball);
            if (b.abilities.Count == 0)
            {
                Ability[] pool = { Ability.Dash, Ability.Fireball, Ability.Teleport, Ability.GroundSlam, Ability.Shield, Ability.IceShard, Ability.Lightning };
                b.abilities.Add(pool[rnd.Next(pool.Length)]);
                b.notes.Add("Способности не описаны — арена выдала: " + Info.Name(b.abilities[0]));
            }

            // --- стихия
            int bestE = int.MaxValue;
            foreach (var f in FEAT)
            {
                Element e = f.f == HF.Fire ? Element.Fire : f.f == HF.Ice ? Element.Ice : f.f == HF.Lightning ? Element.Lightning : f.f == HF.Poison ? Element.Poison : f.f == HF.Shadow ? Element.Shadow : Element.None;
                if (e == Element.None) continue;
                foreach (int i in FindAll(t, f.k))
                {
                    if (Negated(t, i) || InKillClause(t, i)) continue;
                    if (i < bestE) { bestE = i; b.affinity = e; }
                    break;
                }
            }
            if (b.affinity == Element.None)
            {
                if (b.HasAb(Ability.Fireball)) b.affinity = Element.Fire;
                else if (b.HasAb(Ability.IceShard)) b.affinity = Element.Ice;
                else if (b.HasAb(Ability.Lightning)) b.affinity = Element.Lightning;
            }

            // --- бессмертие запрещено
            if (imm)
            {
                if (!b.abilities.Contains(Ability.Regen))
                {
                    if (b.abilities.Count >= 4) b.abilities.RemoveAt(3);
                    b.abilities.Insert(0, Ability.Regen);
                }
                b.notes.Insert(0, "БЕССМЕРТИЕ ЗАПРЕЩЕНО правилами арены! Заменено на регенерацию" + (b.killMasks.Count > 0 ? "." : " и слабость."));
            }

            // --- слабость по умолчанию
            if (b.killMasks.Count == 0)
            {
                HF[] pool = { HF.Fire, HF.Ice, HF.Lightning, HF.Poison, HF.Blade, HF.Pierce, HF.Blunt, HF.Shadow, HF.Head };
                HF w;
                int guard = 0;
                do { w = pool[rnd.Next(pool.Length)]; guard++; }
                while (guard < 20 && ((b.affinity != Element.None && w == HFInfo.FromElem(b.affinity)) || ((int)w & b.immuneMask) != 0));
                b.killMasks.Add((int)w);
                b.notes.Add("Слабость не указана — арена назначила: " + HFInfo.Describe((int)w));
            }
            // иммунитет не может перекрывать единственный путь к смерти
            for (int i = 0; i < b.killMasks.Count; i++)
                if ((b.killMasks[i] & b.immuneMask) != 0)
                {
                    b.immuneMask &= ~b.killMasks[i];
                    b.notes.Add("Иммунитет к «" + HFInfo.Describe(b.killMasks[i]) + "» снят: это его слабость.");
                }
            b.understood.Insert(0, (b.killOnly ? "убить можно ТОЛЬКО: " : "слабость (урон x2): ") + string.Join(" или ", MaskNames(b.killMasks)));

            // --- внешность
            foreach (var ac in ACC)
                foreach (int i in FindAll(t, ac.k)) { if (!Negated(t, i) && !b.acc.Contains(ac.a)) b.acc.Add(ac.a); break; }
            if (b.acc.Contains(Acc.WizardHat) && b.acc.Contains(Acc.CowboyHat)) b.acc.Remove(Acc.CowboyHat);
            if (b.acc.Contains(Acc.Crown)) { b.acc.Remove(Acc.WizardHat); b.acc.Remove(Acc.CowboyHat); }

            // --- оружие
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

        static string[] MaskNames(List<int> masks)
        {
            var l = new List<string>();
            foreach (var m in masks) l.Add(HFInfo.Describe(m));
            return l.ToArray();
        }

        public static string StyleName(Style s)
        {
            switch (s)
            {
                case Style.Boxer: return "боксёр (руки)";
                case Style.Kicker: return "кикбоксер (ноги)";
                case Style.Acrobat: return "акробат (сальто, воздух)";
                case Style.Brute: return "громила (тяжёлые удары)";
            }
            return "универсал";
        }

        static bool Any(Tx t, params string[] keys)
        {
            foreach (int i in FindAll(t, keys)) if (!Negated(t, i)) return true;
            return false;
        }

        static bool InKillClause(Tx t, int i)
        {
            int s0 = SentStart(t, i);
            for (int k = i - 1; k >= s0 && k >= i - 6; k--)
            {
                foreach (var m in WEAK_MARK) if (MatchAt(t, k, m) > 0) return true;
                foreach (var m in KILL_MARK) if (MatchAt(t, k, m) > 0) return true;
                foreach (var m in IMMUNE) if (MatchAt(t, k, m) > 0) return true;
                foreach (var m in ONLY) if (MatchAt(t, k, m) > 0) return true;
            }
            int s1 = SentEnd(t, i);
            for (int k = i + 1; k < s1 && k <= i + 3; k++)
            {
                if (t.w[k] == "-" && k + 1 < s1) { foreach (var m in WEAK_MARK) if (MatchAt(t, k + 1, m) > 0) return true; }
                foreach (var m in WEAK_MARK) if (MatchAt(t, k, m) > 0) return true;
                foreach (var m in KILL_MARK) if (MatchAt(t, k, m) > 0) return true;
                foreach (var m in IMMUNE) if (MatchAt(t, k, m) > 0) return true;
            }
            return false;
        }

        static void Stat(Tx t, string[] keys, ref float stat, string name, FighterBuild b)
        {
            bool numeric = false;
            foreach (int i in FindAll(t, keys))
            {
                if (InKillClause(t, i) && name != "сила") continue;
                float v; bool o10, times;
                if (NumberNear(t, i, 1, out v, out o10, out times))
                {
                    if (times) stat *= Mathf.Clamp(v, 0.2f, 3f);
                    else if (o10 || v <= 10) stat = Mathf.Lerp(0.4f, 2.4f, Mathf.Clamp01(v / 10f));
                    else if (v <= 100) stat = Mathf.Lerp(0.4f, 2.4f, v / 100f);
                    numeric = true;
                    b.understood.Add(name + " " + stat.ToString("0.0") + " (число из описания)");
                    continue;
                }
                if (numeric) continue;
                float k = Intensity(t, i);
                if (Negated(t, i)) stat -= 0.3f * k;
                else stat += 0.3f * k;
            }
            if (!numeric && Mathf.Abs(stat - 1f) > 0.05f) b.understood.Add(name + (stat > 1 ? " ↑" : " ↓") + " " + stat.ToString("0.0"));
        }

        static void Down(Tx t, string[] keys, ref float stat, string name, FighterBuild b)
        {
            foreach (int i in FindAll(t, keys))
            {
                if (Negated(t, i)) continue;
                stat -= 0.3f * Intensity(t, i);
                b.understood.Add(name + " ↓");
            }
        }

        // ======================= ОРУЖИЕ =======================
        struct WKw { public WeaponKind k; public string[] w; public WKw(WeaponKind k, params string[] w) { this.k = k; this.w = w; } }
        static readonly WKw[] WKINDS =
        {
            new WKw(WeaponKind.Chainsaw, "бензопил", "пила$", "пилу$", "пилой$", "chainsaw"),
            new WKw(WeaponKind.Gun, "пистол", "револьв", "автомат", "винтов", "дробов", "ружь", "ружье", "бласт", "пулемет", "снайпер", "узи$", "дробаш", "обрез", "миниган", "gun", "pistol", "rifle", "shotgun", "blaster", "revolver", "uzi", "smg", "minigun"),
            new WKw(WeaponKind.Bow, "арбалет", "лук$", "лука$", "луком", "bow$", "crossbow"),
            new WKw(WeaponKind.Thrown, "сюрикен", "метат", "гранат", "бомб", "дротик", "звездочк", "shuriken", "throwing", "grenade", "bomb", "dart"),
            new WKw(WeaponKind.Staff, "посох", "жезл", "палочк", "скипетр", "staff", "wand", "scepter"),
            new WKw(WeaponKind.Spear, "копь", "копье", "алебард", "трезуб", "глеф", "коса$", "косу$", "косой$", "пика", "spear", "lance", "halberd", "trident", "scythe", "glaive"),
            new WKw(WeaponKind.Blunt, "молот", "дубин", "бита$", "биту$", "битой", "булав", "кувалд", "кастет", "лом$", "ломом", "труба", "трубой", "сковород", "палиц", "hammer", "club", "bat$", "mace", "crowbar", "pan$"),
            new WKw(WeaponKind.Blade, "меч", "катан", "нож", "клинок", "клинк", "сабл", "топор", "секир", "кинжал", "мачете", "шпаг", "sword", "katana", "knife", "blade", "axe", "dagger", "machete", "rapier"),
        };

        static Element ElementOf(Tx t)
        {
            int best = int.MaxValue; Element e = Element.None;
            foreach (var f in FEAT)
            {
                Element el = f.f == HF.Fire ? Element.Fire : f.f == HF.Ice ? Element.Ice : f.f == HF.Lightning ? Element.Lightning : f.f == HF.Poison ? Element.Poison : f.f == HF.Shadow ? Element.Shadow : Element.None;
                if (el == Element.None) continue;
                foreach (int i in FindAll(t, f.k)) { if (Negated(t, i)) continue; if (i < best) { best = i; e = el; } break; }
            }
            foreach (int i in FindAll(t, new[] { "пылающ", "горящ", "раскален", "электро", "ледян", "морозн", "ядовит", "проклят" }))
            {
                string w = t.w[i];
                Element el = w.StartsWith("пыла") || w.StartsWith("горящ") || w.StartsWith("раскал") ? Element.Fire : w.StartsWith("электро") ? Element.Lightning : w.StartsWith("ледян") || w.StartsWith("мороз") ? Element.Ice : w.StartsWith("ядов") ? Element.Poison : Element.Shadow;
                if (i < best) { best = i; e = el; }
            }
            return e;
        }

        public static WeaponStats BuildWeapon(WeaponDef d)
        {
            var w = new WeaponStats();
            w.name = string.IsNullOrEmpty(d.name) ? "Оружие" : d.name;
            w.drawing = (d.drawing != null && d.drawing.Count > 0) ? d.drawing : null;
            var t = Tokenize(d.name + " . " + d.description);

            int best = int.MaxValue; w.kind = WeaponKind.Blade;
            foreach (var wk in WKINDS)
                foreach (int i in FindAll(t, wk.w)) { if (i < best) { best = i; w.kind = wk.k; } break; }

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

            w.element = ElementOf(t);
            if (w.kind == WeaponKind.Staff && w.element == Element.None) w.element = Element.Lightning;

            if (Any(t, "топор", "секир", "axe")) { w.axe = true; w.dmg *= 1.15f; w.rate *= 0.9f; }
            if (Any(t, "бита$", "биту$", "битой", "дубин", "club", "bat$")) w.bat = true;
            if (Any(t, "коса$", "косу$", "косой$", "scythe")) { w.scythe = true; w.dmg *= 1.1f; }
            if (Any(t, "автомат", "винтов", "пулемет", "узи$", "миниган", "rifle", "machine", "smg", "uzi", "minigun")) { w.rifle = true; w.rate *= 2f; w.dmg *= 0.7f; w.ammo = 30; }
            if (Any(t, "дробов", "дробаш", "обрез", "shotgun")) { w.pellets = 5; w.dmg *= 0.55f; w.rate *= 0.6f; w.range = 7f; w.ammo = 8; }
            if (Any(t, "гранат", "бомб", "динамит", "grenade", "bomb", "dynamite")) { w.explode = true; w.dmg = 16; w.ammo = 4; w.rate = 0.7f; }
            if (Any(t, "огромн", "больш", "двуруч", "тяжел", "гигант", "huge", "heavy", "great", "giant")) { w.dmg *= 1.35f; w.rate *= 0.75f; w.size = 1.3f; w.knock *= 1.3f; }
            if (Any(t, "легк", "быстр", "light$", "quick", "fast")) { w.rate *= 1.25f; w.dmg *= 0.85f; }
            if (Any(t, "остр", "заточ", "sharp")) { w.dmg *= 1.1f; w.bleed = true; }
            if (Any(t, "легендар", "эпичн", "божеств", "мифическ", "legendary", "epic", "divine", "mythic")) w.dmg *= 1.15f;
            if (Any(t, "два$", "две$", "двойн", "парн", "dual", "twin")) w.rate *= 1.2f;
            if (Any(t, "маленьк", "мини", "small", "mini", "tiny")) { w.size = 0.8f; w.rate *= 1.1f; w.dmg *= 0.9f; }
            foreach (int i in FindAll(t, DMG))
            {
                float v; bool o10, times;
                if (NumberNear(t, i, 1, out v, out o10, out times)) w.dmg = times ? w.dmg * Mathf.Clamp(v, 0.3f, 3f) : Mathf.Clamp(v, 1f, 60f);
            }
            w.dmg = Mathf.Min(w.dmg, 60f);

            Color c;
            if (FindColor(d.name + " " + d.description, out c)) w.color = c;
            else if (w.element != Element.None && w.kind != WeaponKind.Gun) w.color = Color.Lerp(w.color, Info.ElemColor(w.element), 0.6f);
            return w;
        }

        // Оружие, которое гарантированно подходит под условие смерти (арена сбрасывает его, чтобы бой был честным)
        public static WeaponStats KillerWeapon(int mask, string victim)
        {
            HF m = (HF)mask;
            string desc;
            string el = (m & HF.Fire) != 0 ? "огненн" : (m & HF.Ice) != 0 ? "ледян" : (m & HF.Lightning) != 0 ? "электро" : (m & HF.Poison) != 0 ? "ядовит" : (m & HF.Shadow) != 0 ? "проклят" : "";
            if ((m & HF.Explosion) != 0) desc = "гранаты";
            else if ((m & HF.Pierce) != 0) desc = el + (el.Length > 0 ? "ое " : "") + "копьё";
            else if ((m & HF.Blunt) != 0) desc = el + (el.Length > 0 ? "ый " : "") + "молот";
            else if ((m & HF.Blade) != 0 || el.Length > 0) desc = el + (el.Length > 0 ? "ый " : "") + "меч";
            else return null;
            var w = BuildWeapon(new WeaponDef { name = "Гибель: " + victim, description = desc });
            w.name = "Против «" + victim + "»";
            return w;
        }

        // ======================= СЛУЧАЙНЫЙ БОЕЦ =======================
        static readonly string[] RN1 = { "Тёмный", "Огненный", "Ледяной", "Кибер", "Безумный", "Тихий", "Бешеный", "Грозовой", "Ржавый", "Красный", "Ночной", "Последний" };
        static readonly string[] RN2 = { "Ниндзя", "Самурай", "Маг", "Громила", "Ковбой", "Викинг", "Охотник", "Монах", "Робот", "Демон", "Рыцарь", "Призрак" };
        static readonly string[] RTRAIT = { "очень быстрый", "сильный", "стойкий как танк", "ловкий акробат", "огромный", "маленький и шустрый", "хрупкий, но быстрый", "боксёр", "мастер карате" };
        static readonly string[] RAB = { "кидает огненные шары", "бьёт молнией", "телепортируется", "делает рывок", "ставит щит", "регенерирует", "делает двойной прыжок", "стреляет ледяными осколками", "бьёт по земле", "становится невидимым", "впадает в ярость", "вампир", "стреляет лазером из глаз", "владеет телекинезом" };
        static readonly string[] RWEAK = { "Слабость: огонь.", "Боится льда.", "Убить можно только ударом в голову.", "Слабое место — спина.", "Убить можно только проткнув молнией.", "Боится яда.", "Умирает от клинков." };
        static readonly string[] RWEAP = { "Катана", "Огромный топор", "Бензопила", "Пистолет", "Автомат", "Лук", "Сюрикены", "Копьё", "Кувалда", "Ледяной меч", "Огненный посох", "Бита", "" };

        public static FighterDef RandomFighter(System.Random r)
        {
            var d = new FighterDef();
            d.name = RN1[r.Next(RN1.Length)] + " " + RN2[r.Next(RN2.Length)];
            string a1 = RAB[r.Next(RAB.Length)], a2 = RAB[r.Next(RAB.Length)];
            d.description = char.ToUpper(RTRAIT[0][0]) + "";
            string tr = RTRAIT[r.Next(RTRAIT.Length)];
            d.description = char.ToUpper(tr[0]) + tr.Substring(1) + " " + d.name.ToLower() + ". " + char.ToUpper(a1[0]) + a1.Substring(1) + " и " + a2 + ". Здоровье " + (80 + r.Next(9) * 10) + ". " + RWEAK[r.Next(RWEAK.Length)];
            d.weaponDesc = RWEAP[r.Next(RWEAP.Length)];
            d.color = Color.HSVToRGB((float)r.NextDouble(), 0.75f, 0.85f);
            return d;
        }
    }
}
