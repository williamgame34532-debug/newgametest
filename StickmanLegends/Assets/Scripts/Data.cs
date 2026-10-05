using System;
using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public enum Element { None, Fire, Ice, Lightning, Poison, Shadow }
    public enum WeaponKind { Fists, Blade, Blunt, Spear, Gun, Bow, Thrown, Chainsaw, Staff }
    public enum DmgType { Blunt, Blade, Pierce, Fire, Ice, Lightning, Poison, Shadow }
    public enum Ability { Fireball, Lightning, Teleport, Dash, Shield, Regen, DoubleJump, IceShard, GroundSlam, Invisibility, Rage, Vampire, Laser, Telekinesis, Summon, Custom, Custom2, Custom3, Custom4 }
    public enum Acc { Headband, WizardHat, CowboyHat, Horns, Crown, Halo, Cape, Visor, Scarf, Helmet, Armor, Mask, Hood, Hair, Beard, Eyes, Wings, Tail, Belt, Gloves, Boots, ShoulderPads, Aura, Shirt, Pants, Robe, Coat, Tie, Runes, Sheath, Cap, Glasses, Necklace, Backpack, ShieldProp, Scar, Bandages, Chains, Skull, Greaves, Bracers }

    [Serializable]
    public class Stroke
    {
        public List<Vector2> pts = new List<Vector2>();
        public Color color = Color.black;
        public float width = 0.05f;
    }

    // То, что игрок описал/нарисовал (сохраняется)
    [Serializable]
    public class FighterDef
    {
        public string name = "Боец";
        public string description = "";
        public string weaponDesc = "";
        // отдельные поля описания
        public string appearance = "";   // внешность, одежда, аура
        public string abilitiesText = ""; // способности — каждая с новой строки
        public string stats = "";        // здоровье, урон, скорость...
        public string weakness = "";     // слабость / как убить
        public Color color = new Color(0.8f, 0.1f, 0.1f);
        public List<Stroke> drawing = new List<Stroke>();

        public FighterDef Clone() { return JsonUtility.FromJson<FighterDef>(JsonUtility.ToJson(this)); }
    }

    [Serializable]
    public class WeaponDef
    {
        public string name = "Оружие";
        public string description = "";
        public List<Stroke> drawing = new List<Stroke>();

        public WeaponDef Clone() { return JsonUtility.FromJson<WeaponDef>(JsonUtility.ToJson(this)); }
    }

    [Serializable]
    public class Settings
    {
        public bool musicOn = true;
        public float musicVol = 0.6f;
        public float sfxVol = 0.8f;
        public string musicUrl = "";
        public bool useCustomMusic = false;
        public string survivalMusicUrl = "";  // своя музыка для «Один против всех»
        public bool useCustomSurvival = false;
        public float blood = 1f;          // 0 = без крови, 2 = море крови
        public bool shake = true;
        public bool slowmo = true;
        public bool damageNumbers = true;
        public bool keepBloodOnStop = true;
        public bool overheadBars = true;
        public bool styleShift = true;   // рисовка меняется по ходу дуэли
        public bool tempoRamp = true;    // темп боя растёт
        public bool recordVideo = false; // записывать видео каждого боя
        public bool classicStick = true; // (старое) классический стикман
        public bool cine3d = true;
        public bool always3d = true;
        public bool survivalIntro = true; // катсцена перед «Один против всех»     // постоянный 3D-вид камеры
        public bool grim = true;         // мрачная атмосфера: виньетка, пепел, тёмная цветокоррекция
        public bool screenBlood = true;  // брызги крови на экран       // 3D-переходы камеры в эпичные моменты
        public int stickLook = 0;        // 0 — Dojo (толстые силуэты), 1 — классический (контур, суставы), 2 — простой
    }

    [Serializable]
    public class SaveData
    {
        public int version = 1;
        public List<FighterDef> red = new List<FighterDef>();
        public List<FighterDef> blue = new List<FighterDef>();
        public List<WeaponDef> weapons = new List<WeaponDef>();
        public bool twoPlayers = false;
        public bool survival = false;   // режим «Один против всех»
        public int survivalBest = 0;
        public bool p1Control = false;
        public bool p2Control = false;
        public bool drops = true;
        public float dropInterval = 9f;
        public int theme = 0;
        public Settings settings = new Settings();
    }

    // ---------- Сгенерированные (runtime) данные ----------

    public class WeaponStats
    {
        public string name;
        public WeaponKind kind = WeaponKind.Fists;
        public Element element = Element.None;
        public float dmg = 10, range = 1.5f, rate = 1f, size = 1f, knock = 1f;
        public int ammo = 0;
        public int pellets = 1;
        public bool bleed, axe, bat, rifle, explode, scythe, killer, homing, alwaysHead, knives, summon, katana, glowBlade;
        public bool cleave, dismember, dark;
        public bool retract;                   // клинки из тела: выдвигаются при атаке и прячутся в покое   // «пронзает всех», «отрезает части», тёмное лезвие
        public AbilitySpec onHit;              // что делает при попадании: окаменение, заморозка, поджог...
        public List<string> traits = new List<string>();
        public string customTag, summonName;
        public Color color = Color.gray;
        public List<Stroke> drawing;

        public bool Ranged { get { return kind == WeaponKind.Gun || kind == WeaponKind.Bow || kind == WeaponKind.Thrown; } }
        public DmgType Type
        {
            get
            {
                switch (kind)
                {
                    case WeaponKind.Blade: case WeaponKind.Chainsaw: case WeaponKind.Thrown: return DmgType.Blade;
                    case WeaponKind.Spear: return scythe ? DmgType.Blade : DmgType.Pierce;
                    case WeaponKind.Gun: case WeaponKind.Bow: return DmgType.Pierce;
                    default: return DmgType.Blunt;
                }
            }
        }
        public WeaponStats Copy() { return (WeaponStats)MemberwiseClone(); }
    }

    // предмет из описания, которого нет в словаре: рисуется в своём месте тела
    public class CustomItem
    {
        public string name;
        public int slot; // 0 голова, 1 лицо, 2 шея/грудь, 3 спина, 4 рука, 5 пояс
        public Color color;
    }

    // Умение, собранное из описания: форма (вокруг себя, луч, с неба...), стихия, цвет и эффект
    public class AbilitySpec
    {
        public const int Bolt = 0, Nova = 1, Beam = 2, Sky = 3, Wave = 4, Self = 5;
        public const int None = 0, Petrify = 1, Freeze = 2, Burn = 3, Knock = 4, Pull = 5, Heal = 6, Poison = 7, Lift = 8, Stun = 9, Drain = 10, Explode = 11,
            Transform = 12, Polymorph = 13, Control = 14, TimeSlow = 15, BlackHole = 16, Clone = 17;
        public int shape;
        public Element elem = Element.None;
        public Color col = new Color(0.6f, 0.3f, 1f);
        public bool dark, lethal;
        public int effect;
        public float power = 1f;
        public string name, tag;
        public string form;   // в кого превращается / превращает
        public bool sphere, fromEyes, fan;
        public int proj = -1, count = 1;
        public int effect2;   // эффект вихря / чёрной дыры («торнадо, которые замораживают»)   // вид снаряда (Projectile.Kind) и сколько их за раз // превращается в сферу и взрывается / лучи из глаз / веер клинков из тела
        public StageMods stage;            // своя «стадия»: злая форма, режим ярости...
        public bool goo;      // жижа / слизь
        public static string EffectName(int e)
        {
            switch (e)
            {
                case Petrify: return "превращает в статую";
                case Freeze: return "замораживает";
                case Burn: return "поджигает";
                case Knock: return "отбрасывает";
                case Pull: return "притягивает";
                case Heal: return "лечит";
                case Poison: return "отравляет";
                case Lift: return "поднимает в воздух";
                case Stun: return "оглушает";
                case Drain: return "высасывает жизнь";
                case Explode: return "взрывает";
                case Transform: return "превращается";
                case Polymorph: return "превращает врагов";
                case Control: return "берёт врагов под контроль";
                case TimeSlow: return "замедляет время";
                case BlackHole: return "чёрная дыра затягивает";
                case Clone: return "создаёт клонов";
            }
            return "урон";
        }
        public static string ShapeName(int s)
        {
            switch (s) { case Nova: return "вокруг себя"; case Beam: return "лучом"; case Sky: return "с неба"; case Wave: return "волной по земле"; case Self: return "на себя"; }
            return "снарядом";
        }
    }

    // что меняется в стадии: «злая стадия — появляется плащ, чёрные глаза, бьёт в 3 раза быстрее»
    public class StageMods
    {
        public string name;
        public List<Acc> acc = new List<Acc>();
        public Dictionary<Acc, Color> accCol = new Dictionary<Acc, Color>();
        public float spd = 1f, str = 1f, atk = 1f, size = 1f, def = 1f;
        public int auraKind = -1, headKind;
        public bool eyes2; public Color eyeCol2;
        public List<string> text = new List<string>();
    }

    public class FighterBuild
    {
        public float atkSpeed = 1f;       // скорость атак («бьёт в 3 раза быстрее»)
        public float cdMul = 1f;          // множитель перезарядки умений (усилители)
        public List<AbilitySpec> specs = new List<AbilitySpec>(); // свои умения героя из описания (до 4)
        public AbilitySpec spec { get { return specs.Count > 0 ? specs[0] : null; } set { specs.Clear(); if (value != null) specs.Add(value); } }
        public static bool IsCustom(Ability a) { return a == Ability.Custom || a == Ability.Custom2 || a == Ability.Custom3 || a == Ability.Custom4; }
        public static Ability CustomSlot(int i) { return i == 0 ? Ability.Custom : i == 1 ? Ability.Custom2 : i == 2 ? Ability.Custom3 : Ability.Custom4; }
        // умений может быть до 99: первые три — на своих клавишах, четвёртая клавиша по очереди перебирает остальные
        public int rot;
        public AbilitySpec SpecOf(Ability a)
        {
            int i = a == Ability.Custom ? 0 : a == Ability.Custom2 ? 1 : a == Ability.Custom3 ? 2 : a == Ability.Custom4 ? 3 : -1;
            if (i == 3 && specs.Count > 4) i = 3 + rot % (specs.Count - 3);
            return i >= 0 && i < specs.Count ? specs[i] : null;
        }
        public void Advance(Ability a) { if (a == Ability.Custom4 && specs.Count > 4) rot++; }
        public string AbilityName(Ability a)
        {
            var sp = SpecOf(a);
            if (sp != null && sp.name != null) return sp.name;
            if (a == Ability.Custom && customAbility != null) return customAbility;
            return Info.Name(a).Replace(" (пассив)", "");
        }
        public int headKind;              // 0 голова, 1 череп, 2 огонь, 3 тыква, 4 экран, 5 кристалл, 6 предмет
        public string headName;
        public Color headCol = Color.white;
        public bool skullArmor;           // броня с черепами
        public bool eyes2; public Color eyeCol2; // разноцветные глаза
        public float morphDur;            // для временной формы
        public FighterBuild Clone()
        {
            var c = (FighterBuild)MemberwiseClone();
            c.abilities = new List<Ability>(abilities); c.killMasks = new List<int>(killMasks);
            c.understood = new List<string>(understood); c.notes = new List<string>(notes);
            c.acc = new List<Acc>(acc); c.accCol = new Dictionary<Acc, Color>(accCol);
            c.items = new List<CustomItem>(items);
            c.specs = new List<AbilitySpec>(specs);
            return c;
        }
        public string name;
        public Color color;
        public float hp = 100, str = 1, spd = 1, def = 1, agi = 1, size = 1;
        public List<Ability> abilities = new List<Ability>();
        // Условия смерти: список альтернатив (ИЛИ), каждая — маска признаков удара (И)
        public List<int> killMasks = new List<int>();
        public bool killOnly;          // true = умирает ТОЛЬКО от этих ударов
        public int resistMask, immuneMask;
        public float dmgMul = 1f;
        public Style style = Style.Balanced;
        public List<string> understood = new List<string>();
        public Element affinity = Element.None;
        public string customWeak, customWeakWord;      // новая, придуманная игроком слабость («соль», «музыка»...)
        public string customAbility, customAbilityTag; // новое умение из описания
        public string summonName = "Помощник";
        public int auraKind;
        public List<CustomItem> items = new List<CustomItem>(); // любые другие предметы из описания
        // auraKind: 0 энергия, 1 огонь, 2 молния, 3 тьма, 4 лёд, 5 божественная (золотая)
        public string WeakText
        {
            get
            {
                if (killMasks.Count == 0) return "—";
                var parts = new List<string>();
                foreach (var m in killMasks) parts.Add(HFInfo.Describe(m).Replace("особое", "«" + (customWeakWord ?? "?") + "»"));
                return (killOnly ? "ТОЛЬКО " : "") + string.Join(" или ", parts.ToArray());
            }
        }
        public bool Needs(HF f) { foreach (var m in killMasks) if ((m & (int)f) != 0) return true; return false; }
        public List<Acc> acc = new List<Acc>();
        public List<string> notes = new List<string>();
        public WeaponStats weapon;
        public WeaponStats secondary;   // метательное/дальнобойное из описания (ножи, пистолет...)
        public Dictionary<Acc, Color> accCol = new Dictionary<Acc, Color>();
        public bool knightHelm;
        public List<Stroke> drawing = new List<Stroke>();
        public bool HasAb(Ability a) { return abilities.Contains(a); }
    }

    public static class Info
    {
        public static string Name(Ability a)
        {
            switch (a)
            {
                case Ability.Fireball: return "Огненный шар";
                case Ability.Lightning: return "Удар молнии";
                case Ability.Teleport: return "Телепорт за спину";
                case Ability.Dash: return "Рывок";
                case Ability.Shield: return "Щит";
                case Ability.Regen: return "Регенерация (пассив)";
                case Ability.DoubleJump: return "Двойной прыжок (пассив)";
                case Ability.IceShard: return "Ледяные осколки";
                case Ability.GroundSlam: return "Удар по земле";
                case Ability.Invisibility: return "Невидимость";
                case Ability.Rage: return "Ярость (пассив)";
                case Ability.Vampire: return "Вампиризм (пассив)";
                case Ability.Laser: return "Лазер из глаз";
                case Ability.Telekinesis: return "Телекинез";
                case Ability.Summon: return "Призыв помощников";
                case Ability.Custom: case Ability.Custom2: case Ability.Custom3: case Ability.Custom4: return "Особое умение";
            }
            return a.ToString();
        }

        public static float Cooldown(Ability a)
        {
            switch (a)
            {
                case Ability.Fireball: return 3.5f;
                case Ability.Lightning: return 6f;
                case Ability.Teleport: return 5f;
                case Ability.Dash: return 4f;
                case Ability.Shield: return 9f;
                case Ability.IceShard: return 4f;
                case Ability.GroundSlam: return 6f;
                case Ability.Invisibility: return 11f;
                case Ability.Laser: return 8f;
                case Ability.Telekinesis: return 9f;
                case Ability.Summon: return 14f;
                case Ability.Custom: return 5f;
                case Ability.Custom2: case Ability.Custom3: case Ability.Custom4: return 6f;
            }
            return 999f;
        }

        public static bool Passive(Ability a)
        {
            return a == Ability.Regen || a == Ability.DoubleJump || a == Ability.Rage || a == Ability.Vampire;
        }

        public static string Name(DmgType t)
        {
            switch (t)
            {
                case DmgType.Blunt: return "Тупые удары";
                case DmgType.Blade: return "Клинки";
                case DmgType.Pierce: return "Пули и стрелы";
                case DmgType.Fire: return "Огонь";
                case DmgType.Ice: return "Лёд";
                case DmgType.Lightning: return "Молния";
                case DmgType.Poison: return "Яд";
                case DmgType.Shadow: return "Тьма";
            }
            return t.ToString();
        }

        public static string Name(WeaponKind k)
        {
            switch (k)
            {
                case WeaponKind.Fists: return "Кулаки";
                case WeaponKind.Blade: return "Клинок";
                case WeaponKind.Blunt: return "Дробящее";
                case WeaponKind.Spear: return "Древковое";
                case WeaponKind.Gun: return "Огнестрел";
                case WeaponKind.Bow: return "Лук";
                case WeaponKind.Thrown: return "Метательное";
                case WeaponKind.Chainsaw: return "Бензопила";
                case WeaponKind.Staff: return "Магический посох";
            }
            return k.ToString();
        }

        public static string Name(Element e)
        {
            switch (e)
            {
                case Element.Fire: return "огонь";
                case Element.Ice: return "лёд";
                case Element.Lightning: return "молния";
                case Element.Poison: return "яд";
                case Element.Shadow: return "тьма";
            }
            return "—";
        }

        public static DmgType ToType(Element e)
        {
            switch (e)
            {
                case Element.Fire: return DmgType.Fire;
                case Element.Ice: return DmgType.Ice;
                case Element.Lightning: return DmgType.Lightning;
                case Element.Poison: return DmgType.Poison;
                case Element.Shadow: return DmgType.Shadow;
            }
            return DmgType.Blunt;
        }

        public static Color ElemColor(Element e)
        {
            switch (e)
            {
                case Element.Fire: return new Color(1f, 0.5f, 0.1f);
                case Element.Ice: return new Color(0.5f, 0.9f, 1f);
                case Element.Lightning: return new Color(1f, 0.95f, 0.35f);
                case Element.Poison: return new Color(0.4f, 0.95f, 0.25f);
                case Element.Shadow: return new Color(0.6f, 0.2f, 0.9f);
            }
            return new Color(0.8f, 0.82f, 0.86f);
        }
    }

    public enum Style { Balanced, Boxer, Kicker, Acrobat, Brute }

    [Flags]
    public enum HF
    {
        None = 0, Blunt = 1 << 0, Blade = 1 << 1, Pierce = 1 << 2, Fire = 1 << 3, Ice = 1 << 4, Lightning = 1 << 5,
        Poison = 1 << 6, Shadow = 1 << 7, Head = 1 << 8, Back = 1 << 9, Explosion = 1 << 10, Fall = 1 << 11, Magic = 1 << 12, Unarmed = 1 << 13, Custom = 1 << 14
    }

    public static class HFInfo
    {
        public static HF FromType(DmgType t)
        {
            switch (t)
            {
                case DmgType.Blunt: return HF.Blunt;
                case DmgType.Blade: return HF.Blade;
                case DmgType.Pierce: return HF.Pierce;
                case DmgType.Fire: return HF.Fire;
                case DmgType.Ice: return HF.Ice;
                case DmgType.Lightning: return HF.Lightning;
                case DmgType.Poison: return HF.Poison;
                default: return HF.Shadow;
            }
        }

        public static HF FromElem(Element e)
        {
            switch (e)
            {
                case Element.Fire: return HF.Fire;
                case Element.Ice: return HF.Ice;
                case Element.Lightning: return HF.Lightning;
                case Element.Poison: return HF.Poison;
                case Element.Shadow: return HF.Shadow;
            }
            return HF.None;
        }

        static readonly KeyValuePair<HF, string>[] NAMES =
        {
            new KeyValuePair<HF, string>(HF.Head, "удар в голову"),
            new KeyValuePair<HF, string>(HF.Back, "удар в спину"),
            new KeyValuePair<HF, string>(HF.Pierce, "протыкание"),
            new KeyValuePair<HF, string>(HF.Blade, "клинки"),
            new KeyValuePair<HF, string>(HF.Blunt, "дробящие удары"),
            new KeyValuePair<HF, string>(HF.Unarmed, "голые руки"),
            new KeyValuePair<HF, string>(HF.Fire, "огонь"),
            new KeyValuePair<HF, string>(HF.Ice, "лёд"),
            new KeyValuePair<HF, string>(HF.Lightning, "молния"),
            new KeyValuePair<HF, string>(HF.Poison, "яд"),
            new KeyValuePair<HF, string>(HF.Shadow, "тьма"),
            new KeyValuePair<HF, string>(HF.Explosion, "взрывы"),
            new KeyValuePair<HF, string>(HF.Fall, "удар об стену/землю"),
            new KeyValuePair<HF, string>(HF.Magic, "магия"),
            new KeyValuePair<HF, string>(HF.Custom, "особое"),
        };

        public static string Describe(int mask)
        {
            var l = new List<string>();
            foreach (var kv in NAMES) if ((mask & (int)kv.Key) != 0) l.Add(kv.Value);
            return l.Count == 0 ? "?" : string.Join(" + ", l.ToArray());
        }
    }

    public class HitInfo
    {
        public float dmg;
        public DmgType type;
        public Element elem;
        public Vector2 dir = Vector2.right;
        public Vector2 point;
        public float knock = 4f;
        public float stun = 0.15f;
        public Fighter attacker;
        public bool headshot;
        public bool heavy;
        public bool noFlinch;
        public int effect;             // эффект умения/оружия (AbilitySpec.effect)
        public bool effLethal, dismember, blast; // blast — волна отчаяния (не вызывает ответное умение)
        public Color effCol = Color.white;
        public string effForm;
        public HF extra;               // голова/спина/взрыв/падение/магия/без оружия
        public bool launcher, slam, knockdown;
        public float lift;
        public string customTag;
        public HitInfo Copy() { return (HitInfo)MemberwiseClone(); }
    }
}
