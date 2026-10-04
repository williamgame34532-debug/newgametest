using System;
using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    public enum Element { None, Fire, Ice, Lightning, Poison, Shadow }
    public enum WeaponKind { Fists, Blade, Blunt, Spear, Gun, Bow, Thrown, Chainsaw, Staff }
    public enum DmgType { Blunt, Blade, Pierce, Fire, Ice, Lightning, Poison, Shadow }
    public enum Ability { Fireball, Lightning, Teleport, Dash, Shield, Regen, DoubleJump, IceShard, GroundSlam, Invisibility, Rage, Vampire, Laser, Telekinesis }
    public enum Acc { Headband, WizardHat, CowboyHat, Horns, Crown, Halo, Cape, Visor, Scarf }

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
        public float blood = 1f;          // 0 = без крови, 2 = море крови
        public bool shake = true;
        public bool slowmo = true;
        public bool damageNumbers = true;
        public bool keepBloodOnStop = true;
        public bool overheadBars = true;
    }

    [Serializable]
    public class SaveData
    {
        public int version = 1;
        public List<FighterDef> red = new List<FighterDef>();
        public List<FighterDef> blue = new List<FighterDef>();
        public List<WeaponDef> weapons = new List<WeaponDef>();
        public bool twoPlayers = false;
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
        public bool bleed, axe, bat, rifle, explode, scythe;
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

    public class FighterBuild
    {
        public string name;
        public Color color;
        public float hp = 100, str = 1, spd = 1, def = 1, agi = 1, size = 1;
        public List<Ability> abilities = new List<Ability>();
        public DmgType weakness = DmgType.Fire;
        public Element affinity = Element.None;
        public List<Acc> acc = new List<Acc>();
        public List<string> notes = new List<string>();
        public WeaponStats weapon;
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
        public HitInfo Copy() { return (HitInfo)MemberwiseClone(); }
    }
}
