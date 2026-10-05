using UnityEngine;

namespace StickWars
{
    // Превращения: в кого угодно. Известные формы получают свой вид и силы, остальные — общую «усиленную» форму.
    public static class Forms
    {
        static bool Has(string w, params string[] keys)
        {
            if (string.IsNullOrEmpty(w)) return false;
            w = w.ToLowerInvariant().Replace('ё', 'е');
            foreach (var k in keys) if (w.StartsWith(k)) return true;
            return false;
        }

        public static bool IsCritter(string f)
        {
            return Has(f, "лягуш", "жаб", "кур", "цыпл", "овц", "овеч", "барaн", "баран", "крол", "заяц", "зайц", "мыш", "крыс", "свин", "поросен", "кот", "кошк", "котен", "собак", "щен", "утк", "утен", "голуб", "пингвин", "улитк", "черепах", "хомяк", "бабоч", "frog", "toad", "chicken", "sheep", "rabbit", "mouse", "rat", "pig", "cat", "dog", "duck", "snail", "turtle");
        }

        // форма из нескольких слов: «металлического воина», «огненного демона» — сначала существительное, потом прилагательное
        public static string Display(string f)
        {
            if (string.IsNullOrEmpty(f)) return "Форма";
            var parts = f.Trim().Split(' ');
            if (parts.Length > 1)
            {
                string noun = Display1(parts[parts.Length - 1]);
                if (noun != Cap1(parts[parts.Length - 1])) return noun;
                string adj = Display1(parts[0]);
                if (adj != Cap1(parts[0])) return adj;
                return noun;
            }
            return Display1(f);
        }

        static string Cap1(string s) { s = s.Trim(); return s.Length > 0 ? char.ToUpper(s[0]) + s.Substring(1) : s; }

        static string Display1(string f)
        {
            if (Has(f, "паук", "spider")) return "Паук";
            if (Has(f, "вампир", "vampire")) return "Вампир";
            if (Has(f, "орк", "гоблин", "тролл", "orc", "goblin", "troll")) return "Орк";
            if (Has(f, "змe", "змея", "змею", "змей", "змеи", "snake", "serpent")) return "Змей";
            if (Has(f, "феникс", "phoenix")) return "Феникс";
            if (Has(f, "слиз", "жиж", "желе", "slime")) return "Слизь";
            if (Has(f, "молни", "электр", "lightning")) return "Молния";
            if (Has(f, "голем", "камен", "golem", "stone")) return "Голем";
            if (Has(f, "кристал", "алмаз", "crystal", "diamond")) return "Кристалл";
            if (Has(f, "металл", "стальн", "желез", "metal", "steel", "iron")) return "Сталь";
            if (Has(f, "огромн", "гигантск", "великан", "huge", "giant")) return "Титан";
            if (Has(f, "невидим", "призрачн", "invisible")) return "Тень";
            if (Has(f, "дракон", "dragon")) return "Дракон";
            if (Has(f, "волк", "оборот", "wolf", "werewolf")) return "Волк";
            if (Has(f, "тигр", "лев", "льв", "медвед", "зверь", "звер", "beast", "tiger", "lion", "bear")) return "Зверь";
            if (Has(f, "гигант", "великан", "титан", "колосс", "голем", "giant", "titan", "golem")) return "Титан";
            if (Has(f, "демон", "дьявол", "бес", "черт", "demon", "devil")) return "Демон";
            if (Has(f, "ангел", "бог", "божеств", "angel", "god")) return "Ангел";
            if (Has(f, "робот", "машин", "мех", "киборг", "андроид", "robot", "mech", "cyborg")) return "Робот";
            if (Has(f, "тень", "тени", "призрак", "дух", "темн", "черн", "мрачн", "ghost", "shadow", "spirit", "dark")) return "Тень";
            if (Has(f, "демонич", "адск")) return "Демон";
            if (Has(f, "божеств", "светл", "свят")) return "Ангел";
            if (Has(f, "огнен", "пылающ")) return "Пламя";
            if (Has(f, "ледян", "морозн")) return "Лёд";
            if (Has(f, "звер", "животн", "дик")) return "Зверь";
            if (Has(f, "скелет", "мертв", "зомби", "лич", "нежит", "skeleton", "zombie", "lich", "undead")) return "Нежить";
            if (Has(f, "огон", "огн", "плам", "феникс", "fire", "flame", "phoenix")) return "Пламя";
            if (Has(f, "лед", "льд", "снеж", "мороз", "ice", "frost", "snow")) return "Лёд";
            if (Has(f, "монстр", "чудовищ", "тварь", "monster", "beast")) return "Чудовище";
            if (Has(f, "лягуш", "жаб", "frog", "toad")) return "Лягушка";
            if (Has(f, "кур", "цыпл", "chicken")) return "Курица";
            if (Has(f, "овц", "овеч", "баран", "sheep")) return "Овца";
            if (Has(f, "свин", "порос", "pig")) return "Свинка";
            if (Has(f, "крол", "заяц", "зайц", "rabbit")) return "Кролик";
            if (Has(f, "мыш", "крыс", "хомяк", "mouse", "rat")) return "Мышь";
            if (string.IsNullOrEmpty(f)) return "Форма";
            string s = f.Trim();
            return char.ToUpper(s[0]) + s.Substring(1);
        }

        // новая сборка бойца в форме f; critter — превращение врага в беззащитную зверушку
        public static FighterBuild Apply(FighterBuild src, string f, bool critter)
        {
            var b = src.Clone();
            string nm = Display(f);
            b.name = src.name + " (" + nm + ")";
            if (critter || IsCritter(f))
            {
                b.size = 0.45f; b.str = 0.15f; b.spd = 0.9f; b.agi = 0.8f; b.def = 0.6f;
                b.abilities.Clear(); b.weapon = null; b.secondary = null; b.spec = null;
                b.acc.Clear(); b.accCol.Clear(); b.items.Clear(); b.headKind = 0; b.skullArmor = false;
                b.color = nm == "Лягушка" ? new Color(0.3f, 0.75f, 0.25f) : nm == "Свинка" ? new Color(1f, 0.6f, 0.7f) : nm == "Мышь" ? new Color(0.55f, 0.55f, 0.6f) : nm == "Кролик" || nm == "Овца" || nm == "Курица" ? new Color(0.95f, 0.95f, 0.92f) : Color.HSVToRGB(Mathf.Abs(f.GetHashCode() % 360) / 360f, 0.5f, 0.85f);
                if (nm == "Кролик") b.acc.Add(Acc.Horns);
                if (nm == "Курица") { b.acc.Add(Acc.Crown); b.accCol[Acc.Crown] = new Color(0.9f, 0.1f, 0.1f); }
                return b;
            }
            if (!b.acc.Contains(Acc.Eyes)) b.acc.Add(Acc.Eyes);
            switch (nm)
            {
                case "Дракон":
                    b.size = Mathf.Max(b.size, 1f) * 1.55f; b.hp *= 1.5f; b.str *= 1.6f; b.def *= 1.3f;
                    b.color = new Color(0.55f, 0.07f, 0.05f);
                    Add(b, Acc.Wings, new Color(0.35f, 0.04f, 0.04f)); Add(b, Acc.Tail, new Color(0.45f, 0.05f, 0.04f)); Add(b, Acc.Horns, new Color(0.15f, 0.1f, 0.08f));
                    b.accCol[Acc.Eyes] = new Color(1f, 0.85f, 0.1f);
                    Ab(b, Ability.Fireball); Aura(b, 1, new Color(1f, 0.4f, 0.1f)); break;
                case "Волк":
                case "Зверь":
                    b.size *= 1.2f; b.spd *= 1.5f; b.agi *= 1.5f; b.str *= 1.35f; b.style = Style.Acrobat;
                    b.color = nm == "Волк" ? new Color(0.3f, 0.3f, 0.33f) : new Color(0.75f, 0.45f, 0.12f);
                    Add(b, Acc.Tail, b.color); Add(b, Acc.Hair, Draw.Mul(b.color, 0.7f));
                    b.accCol[Acc.Eyes] = new Color(1f, 0.85f, 0.15f);
                    Ab(b, Ability.Dash); break;
                case "Титан":
                    b.size = Mathf.Max(b.size, 1f) * 1.9f; b.str *= 1.9f; b.hp *= 1.8f; b.spd *= 0.75f; b.def *= 1.6f; b.style = Style.Brute;
                    b.color = new Color(0.45f, 0.43f, 0.4f); Ab(b, Ability.GroundSlam); break;
                case "Демон":
                    b.size *= 1.3f; b.str *= 1.5f; b.hp *= 1.3f; b.color = new Color(0.6f, 0.05f, 0.05f);
                    Add(b, Acc.Horns, new Color(0.1f, 0.05f, 0.05f)); Add(b, Acc.Wings, new Color(0.25f, 0.03f, 0.05f)); Add(b, Acc.Tail, new Color(0.5f, 0.04f, 0.04f));
                    Aura(b, 3, new Color(0.4f, 0.05f, 0.1f)); Ab(b, Ability.Fireball); break;
                case "Ангел":
                    b.size *= 1.2f; b.hp *= 1.3f; b.color = new Color(0.95f, 0.93f, 0.85f);
                    Add(b, Acc.Wings, Color.white); Add(b, Acc.Halo, new Color(1f, 0.9f, 0.4f)); Aura(b, 5, new Color(1f, 0.9f, 0.5f)); Ab(b, Ability.Lightning); break;
                case "Робот":
                    b.size *= 1.25f; b.def *= 1.8f; b.str *= 1.3f; b.color = new Color(0.55f, 0.58f, 0.63f);
                    Add(b, Acc.Visor, new Color(1f, 0.2f, 0.2f)); Add(b, Acc.Armor, new Color(0.45f, 0.48f, 0.53f)); Ab(b, Ability.Laser); break;
                case "Тень":
                    b.agi *= 1.6f; b.spd *= 1.3f; b.color = new Color(0.04f, 0.03f, 0.06f);
                    b.accCol[Acc.Eyes] = new Color(0.8f, 0.2f, 1f); Aura(b, 3, new Color(0.3f, 0.05f, 0.5f)); Ab(b, Ability.Invisibility); Ab(b, Ability.Teleport); break;
                case "Паук":
                    b.agi *= 1.7f; b.spd *= 1.4f; b.color = new Color(0.08f, 0.06f, 0.08f); b.style = Style.Acrobat;
                    b.accCol[Acc.Eyes] = new Color(1f, 0.1f, 0.1f); b.eyes2 = true; b.eyeCol2 = new Color(1f, 0.1f, 0.1f);
                    Ab(b, Ability.Telekinesis); b.affinity = Element.Poison; break;
                case "Вампир":
                    b.str *= 1.4f; b.agi *= 1.3f; b.color = new Color(0.12f, 0.05f, 0.08f);
                    Add(b, Acc.Cape, new Color(0.45f, 0.02f, 0.06f)); Add(b, Acc.Wings, new Color(0.15f, 0.03f, 0.06f));
                    b.accCol[Acc.Eyes] = new Color(1f, 0.05f, 0.1f); Ab(b, Ability.Vampire); Ab(b, Ability.Teleport); break;
                case "Орк":
                    b.size *= 1.4f; b.str *= 1.7f; b.hp *= 1.5f; b.spd *= 0.9f; b.style = Style.Brute;
                    b.color = new Color(0.3f, 0.5f, 0.18f); Add(b, Acc.Horns, new Color(0.9f, 0.88f, 0.75f)); Ab(b, Ability.Rage); break;
                case "Змей":
                    b.agi *= 1.5f; b.spd *= 1.3f; b.color = new Color(0.2f, 0.55f, 0.2f);
                    Add(b, Acc.Tail, new Color(0.15f, 0.45f, 0.15f)); b.accCol[Acc.Eyes] = new Color(1f, 0.9f, 0.1f); b.affinity = Element.Poison; break;
                case "Феникс":
                    b.color = new Color(1f, 0.55f, 0.1f); Add(b, Acc.Wings, new Color(1f, 0.4f, 0.05f)); Add(b, Acc.Tail, new Color(1f, 0.6f, 0.1f));
                    Aura(b, 1, new Color(1f, 0.5f, 0.1f)); Ab(b, Ability.Fireball); Ab(b, Ability.Regen); b.affinity = Element.Fire; break;
                case "Слизь":
                    b.size *= 1.2f; b.def *= 1.8f; b.color = new Color(0.4f, 0.9f, 0.3f); Aura(b, 0, new Color(0.5f, 1f, 0.4f)); b.affinity = Element.Poison; break;
                case "Молния":
                    b.spd *= 1.8f; b.agi *= 1.6f; b.color = new Color(1f, 0.95f, 0.5f); Aura(b, 2, new Color(1f, 1f, 0.5f));
                    Ab(b, Ability.Lightning); Ab(b, Ability.Dash); b.affinity = Element.Lightning; break;
                case "Голем":
                    b.size = Mathf.Max(b.size, 1f) * 1.8f; b.def *= 2.2f; b.str *= 1.7f; b.hp *= 1.8f; b.spd *= 0.7f; b.style = Style.Brute;
                    b.color = new Color(0.5f, 0.47f, 0.42f); Add(b, Acc.Runes, new Color(0.4f, 1f, 0.9f)); Ab(b, Ability.GroundSlam); break;
                case "Кристалл":
                    b.def *= 2f; b.color = new Color(0.55f, 0.85f, 1f); b.headKind = 5; b.headCol = new Color(0.6f, 0.9f, 1f); Aura(b, 4, new Color(0.6f, 0.9f, 1f)); Ab(b, Ability.IceShard); break;
                case "Сталь":
                    b.def *= 2.2f; b.str *= 1.3f; b.color = new Color(0.6f, 0.63f, 0.68f);
                    Add(b, Acc.Helmet, new Color(0.55f, 0.58f, 0.63f)); Add(b, Acc.Armor, new Color(0.5f, 0.53f, 0.58f)); Add(b, Acc.Greaves, new Color(0.5f, 0.53f, 0.58f)); break;
                case "Нежить":
                    b.hp *= 1.4f; b.color = new Color(0.9f, 0.88f, 0.8f); b.headKind = 1; b.headCol = new Color(0.93f, 0.9f, 0.82f);
                    b.accCol[Acc.Eyes] = new Color(0.3f, 1f, 0.5f); Ab(b, Ability.Summon); b.summonName = "Скелет"; break;
                case "Пламя":
                    b.str *= 1.4f; b.color = new Color(1f, 0.45f, 0.08f); b.headKind = 2; b.headCol = new Color(1f, 0.5f, 0.1f);
                    Aura(b, 1, new Color(1f, 0.45f, 0.1f)); Ab(b, Ability.Fireball); b.affinity = Element.Fire; break;
                case "Лёд":
                    b.def *= 1.5f; b.color = new Color(0.6f, 0.85f, 1f); Aura(b, 4, new Color(0.6f, 0.9f, 1f)); Ab(b, Ability.IceShard); b.affinity = Element.Ice; break;
                case "Чудовище":
                    b.size *= 1.6f; b.str *= 1.6f; b.hp *= 1.5f; b.color = new Color(0.25f, 0.35f, 0.15f);
                    Add(b, Acc.Horns, new Color(0.2f, 0.15f, 0.1f)); Add(b, Acc.Tail, b.color); b.style = Style.Brute; break;
                default:
                    b.size *= 1.35f; b.str *= 1.4f; b.hp *= 1.3f;
                    b.color = Color.HSVToRGB(Mathf.Abs(f.GetHashCode() % 360) / 360f, 0.6f, 0.6f);
                    Aura(b, 0, Color.Lerp(b.color, Color.white, 0.4f)); break;
            }
            b.size = Mathf.Clamp(b.size, 0.4f, 2.3f);
            return b;
        }

        // своя стадия из описания: плащ, глаза, скорость ударов, сила...
        public static FighterBuild ApplyStage(FighterBuild src, StageMods m)
        {
            var b = src.Clone();
            b.name = src.name + " (" + m.name + ")";
            foreach (var a in m.acc) if (!b.acc.Contains(a)) b.acc.Add(a);
            foreach (var kv in m.accCol) b.accCol[kv.Key] = kv.Value;
            if (m.auraKind >= 0) b.auraKind = m.auraKind;
            if (m.headKind != 0) b.headKind = m.headKind;
            if (m.eyes2) { b.eyes2 = true; b.eyeCol2 = m.eyeCol2; }
            b.spd *= Mathf.Clamp(m.spd, 0.5f, 2f); b.str *= Mathf.Clamp(m.str, 0.5f, 3f); b.def *= Mathf.Clamp(m.def, 0.5f, 3f);
            b.atkSpeed = Mathf.Clamp(b.atkSpeed * m.atk, 0.5f, 4f);
            b.size = Mathf.Clamp(b.size * m.size, 0.5f, 2.3f);
            // стадия — всегда мощнее: если ничего не сказано про силу, чуть сильнее и с аурой
            if (m.str <= 1f && m.atk <= 1f) b.str *= 1.25f;
            if (!b.acc.Contains(Acc.Aura)) { b.acc.Add(Acc.Aura); b.accCol[Acc.Aura] = new Color(0.6f, 0.05f, 0.1f); b.auraKind = 3; }
            if (!b.acc.Contains(Acc.Eyes)) b.acc.Add(Acc.Eyes);
            // стадия не включается повторно внутри себя
            b.specs = new System.Collections.Generic.List<AbilitySpec>(src.specs);
            return b;
        }

        static void Add(FighterBuild b, Acc a, Color c) { if (!b.acc.Contains(a)) b.acc.Add(a); b.accCol[a] = c; }
        static void Aura(FighterBuild b, int kind, Color c) { Add(b, Acc.Aura, c); b.auraKind = kind; }
        static void Ab(FighterBuild b, Ability a) { if (!b.abilities.Contains(a)) { if (b.abilities.Count >= 4) b.abilities.RemoveAt(b.abilities.Count - 1); b.abilities.Add(a); } }
    }
}
