using System.Collections.Generic;
using UnityEngine;

// Все справочные данные игры: стороны, оружие, отряды МОГ, отряды Повстанцев Хаоса, SCP-объекты.
public enum Team { Foundation, Chaos, SCP }

public enum WeaponKind { Rifle, SMG, Shotgun, LMG, Sniper, Pistol, Launcher }

public class WeaponDef
{
    public string id, name;
    public WeaponKind kind;
    public float damage, rpm, spread, range = 160f, reload = 2.4f, recoil = 1f, force = 40f;
    public int mag = 30, pellets = 1;
    public bool auto = true;
    public float zoomFov = 45f;          // поле зрения в прицеливании
    public Color body = new Color(0.12f, 0.12f, 0.13f);
    public Color accent = new Color(0.25f, 0.25f, 0.27f);
    public bool suppressor, scope, redDot = true;
    public float length = 0.75f;          // длина ствольной коробки+ствола (для модели)

    public float Interval => 60f / Mathf.Max(1f, rpm);
}

public enum HeadGear { Helmet, HeavyHelmet, GasMask, Balaclava, Hazmat, NightVision, Cap, Cyborg, Bare, DeltaHelmet }

// Внешний вид бойца
public class Look
{
    public Color uniform = new Color(0.15f, 0.17f, 0.22f);
    public Color uniform2 = new Color(0.12f, 0.13f, 0.17f);   // штаны
    public Color armor = new Color(0.1f, 0.11f, 0.13f);
    public Color helmet = new Color(0.1f, 0.11f, 0.13f);
    public Color skin = new Color(0.86f, 0.69f, 0.58f);
    public Color accent = new Color(0.1f, 0.4f, 0.9f);        // нашивки, полосы
    public Color visor = new Color(0.05f, 0.1f, 0.15f, 0.75f);
    public Color gear = new Color(0.08f, 0.08f, 0.08f);       // перчатки, ботинки, ремни
    public HeadGear head = HeadGear.Helmet;
    public bool vest = true, backpack = true, shoulderPads, kneePads = true, heavy, visorGlow;
    public float bulk = 1f;                                    // толщина бойца

    public Look Clone() => (Look)MemberwiseClone();
}

public class SquadDef
{
    public string id, name, nick, desc;
    public Team team;
    public Look look = new Look();
    public string primary, secondary = "com15", special;   // special — гранатомёт и т.п.
    public int count = 8, maxCount = 14, grenades = 2;
    public float hp = 100f, armor = 0.25f, speed = 1f, accuracy = 1f, scale = 1f, courage = 1f;
    public bool fastRope;          // десантируются по канатам
    public bool ignores096;        // Эта-10 — не провоцируют SCP-096
    public bool blinkImmune;       // защищены от SCP-173 (видеосистемы)
    public string label;           // надпись на вертолёте
}

public enum ScpKind { S173, S096, S049, S0492, S106, S939, S682, S457 }

public class ScpDef
{
    public ScpKind kind;
    public string id, name, nick, desc;
    public int count = 1, maxCount = 1;
    public float hp;
}

public static class DB
{
    public static readonly Dictionary<string, WeaponDef> Weapons = new Dictionary<string, WeaponDef>();
    public static readonly List<SquadDef> Foundation = new List<SquadDef>();
    public static readonly List<SquadDef> Chaos = new List<SquadDef>();
    public static readonly List<ScpDef> Scps = new List<ScpDef>();

    static bool inited;

    public static WeaponDef W(string id) { Init(); return id != null && Weapons.TryGetValue(id, out var w) ? w : null; }
    public static ScpDef Scp(ScpKind k) { Init(); foreach (var s in Scps) if (s.kind == k) return s; return null; }

    static void AddW(WeaponDef w) { Weapons[w.id] = w; }

    static Color C(float r, float g, float b, float a = 1f) => new Color(r, g, b, a);

    public static void Init()
    {
        if (inited) return;
        inited = true;

        // ---------- ОРУЖИЕ ----------
        AddW(new WeaponDef { id = "e11", name = "MTF-E11-SR", kind = WeaponKind.Rifle, damage = 27, rpm = 660, spread = 1.1f, mag = 40, reload = 2.5f, recoil = 1f, length = 0.78f, body = C(0.13f, 0.14f, 0.16f), accent = C(0.2f, 0.32f, 0.5f) });
        AddW(new WeaponDef { id = "p90", name = "FN P90", kind = WeaponKind.SMG, damage = 19, rpm = 900, spread = 1.9f, mag = 50, reload = 2.6f, recoil = 0.6f, range = 110, length = 0.52f, body = C(0.08f, 0.08f, 0.08f), accent = C(0.4f, 0.05f, 0.05f) });
        AddW(new WeaponDef { id = "crossvec", name = "Crossvec", kind = WeaponKind.SMG, damage = 21, rpm = 960, spread = 1.7f, mag = 40, reload = 2.2f, recoil = 0.65f, range = 110, length = 0.55f, suppressor = true, body = C(0.15f, 0.17f, 0.14f) });
        AddW(new WeaponDef { id = "fsp9", name = "FSP-9", kind = WeaponKind.SMG, damage = 18, rpm = 800, spread = 2.2f, mag = 30, reload = 2.1f, recoil = 0.6f, range = 90, length = 0.5f, redDot = false });
        AddW(new WeaponDef { id = "frmg", name = "FR-MG-0", kind = WeaponKind.LMG, damage = 29, rpm = 760, spread = 2.4f, mag = 100, reload = 4.6f, recoil = 1.25f, length = 0.95f, body = C(0.16f, 0.17f, 0.15f) });
        AddW(new WeaponDef { id = "dmr", name = "MTF-DMR", kind = WeaponKind.Sniper, damage = 70, rpm = 160, spread = 0.25f, mag = 15, reload = 2.8f, recoil = 2f, auto = false, range = 260, scope = true, redDot = false, zoomFov = 22, length = 0.95f, body = C(0.2f, 0.2f, 0.19f) });
        AddW(new WeaponDef { id = "com15", name = "COM-15", kind = WeaponKind.Pistol, damage = 24, rpm = 340, spread = 1.6f, mag = 12, reload = 1.6f, recoil = 1.2f, auto = false, range = 80, length = 0.22f, redDot = false });
        AddW(new WeaponDef { id = "m870", name = "Дробовик M870", kind = WeaponKind.Shotgun, damage = 13, pellets = 9, rpm = 75, spread = 4.5f, mag = 8, reload = 3.4f, recoil = 2.6f, auto = false, range = 55, length = 0.85f, redDot = false, body = C(0.1f, 0.1f, 0.1f), accent = C(0.35f, 0.22f, 0.12f) });
        AddW(new WeaponDef { id = "gl", name = "Гранатомёт MGL", kind = WeaponKind.Launcher, damage = 140, rpm = 70, spread = 1f, mag = 6, reload = 4f, recoil = 2f, auto = false, range = 120, length = 0.6f, redDot = true, body = C(0.2f, 0.22f, 0.18f) });
        AddW(new WeaponDef { id = "ak", name = "АК-15", kind = WeaponKind.Rifle, damage = 31, rpm = 600, spread = 1.7f, mag = 30, reload = 2.6f, recoil = 1.3f, length = 0.8f, redDot = false, body = C(0.1f, 0.1f, 0.1f), accent = C(0.38f, 0.22f, 0.1f) });
        AddW(new WeaponDef { id = "logicer", name = "Logicer", kind = WeaponKind.LMG, damage = 30, rpm = 720, spread = 2.6f, mag = 100, reload = 4.8f, recoil = 1.3f, length = 0.98f, redDot = false, body = C(0.13f, 0.13f, 0.12f), accent = C(0.3f, 0.28f, 0.2f) });
        AddW(new WeaponDef { id = "svd", name = "СВД", kind = WeaponKind.Sniper, damage = 115, rpm = 50, spread = 0.12f, mag = 10, reload = 3f, recoil = 3f, auto = false, range = 300, scope = true, redDot = false, zoomFov = 16, length = 1.1f, body = C(0.1f, 0.1f, 0.1f), accent = C(0.35f, 0.2f, 0.1f) });
        AddW(new WeaponDef { id = "saiga", name = "Сайга-12", kind = WeaponKind.Shotgun, damage = 12, pellets = 9, rpm = 190, spread = 5f, mag = 10, reload = 3f, recoil = 2.3f, auto = false, range = 50, length = 0.8f, redDot = false });
        AddW(new WeaponDef { id = "rpg", name = "РПГ-7", kind = WeaponKind.Launcher, damage = 260, rpm = 20, spread = 0.8f, mag = 1, reload = 3.6f, recoil = 3f, auto = false, range = 220, redDot = false, length = 1f, body = C(0.22f, 0.25f, 0.16f), accent = C(0.35f, 0.22f, 0.1f) });
        AddW(new WeaponDef { id = "pm", name = "Пистолет", kind = WeaponKind.Pistol, damage = 20, rpm = 300, spread = 2.4f, mag = 8, reload = 1.6f, recoil = 1.2f, auto = false, range = 60, length = 0.2f, redDot = false });
        AddW(new WeaponDef { id = "vector", name = "Vector .45", kind = WeaponKind.SMG, damage = 22, rpm = 1100, spread = 1.6f, mag = 33, reload = 2f, recoil = 0.7f, range = 100, length = 0.55f, body = C(0.06f, 0.06f, 0.06f), accent = C(0.5f, 0.05f, 0.05f) });

        // ---------- ФОНД: Мобильные Оперативные Группы ----------
        Foundation.Add(new SquadDef
        {
            id = "e11", name = "Эпсилон-11", nick = "«Девятихвостая лиса»", team = Team.Foundation, label = "MTF E-11",
            desc = "Основная группа внутреннего реагирования. Сбалансированы, отлично стреляют, винтовки E11-SR.",
            primary = "e11", count = 8, hp = 110, armor = 0.3f, accuracy = 1.1f, grenades = 2,
            look = new Look { uniform = C(0.13f, 0.15f, 0.22f), uniform2 = C(0.1f, 0.11f, 0.16f), armor = C(0.09f, 0.1f, 0.13f), helmet = C(0.08f, 0.09f, 0.12f), accent = C(0.15f, 0.45f, 1f), visor = C(0.1f, 0.3f, 0.5f, 0.7f), visorGlow = true, head = HeadGear.Helmet, shoulderPads = true }
        });
        Foundation.Add(new SquadDef
        {
            id = "a1", name = "Альфа-1", nick = "«Красная правая рука»", team = Team.Foundation, label = "MTF A-1",
            desc = "Личная гвардия Совета O5. Элита: много здоровья, тяжёлая броня, P90 и пистолеты.",
            primary = "p90", count = 6, maxCount = 10, hp = 150, armor = 0.5f, accuracy = 1.35f, speed = 1.05f, courage = 1.5f, grenades = 3,
            look = new Look { uniform = C(0.06f, 0.06f, 0.07f), uniform2 = C(0.05f, 0.05f, 0.06f), armor = C(0.08f, 0.08f, 0.09f), helmet = C(0.05f, 0.05f, 0.06f), accent = C(0.85f, 0.05f, 0.05f), visor = C(0.6f, 0.05f, 0.05f, 0.75f), visorGlow = true, head = HeadGear.Helmet, shoulderPads = true, heavy = true }
        });
        Foundation.Add(new SquadDef
        {
            id = "n7", name = "Ню-7", nick = "«Молот опускается»", team = Team.Foundation, label = "MTF NU-7",
            desc = "Армейская группа для крупных угроз. Тяжёлые шлемы, пулемёты FR-MG-0, медленные, но очень живучие.",
            primary = "frmg", count = 8, hp = 165, armor = 0.55f, speed = 0.88f, scale = 1.06f, accuracy = 0.95f, courage = 1.4f, grenades = 2,
            look = new Look { uniform = C(0.27f, 0.29f, 0.24f), uniform2 = C(0.22f, 0.24f, 0.2f), armor = C(0.32f, 0.33f, 0.3f), helmet = C(0.3f, 0.31f, 0.28f), accent = C(0.95f, 0.75f, 0.1f), visor = C(0.05f, 0.05f, 0.05f, 0.85f), head = HeadGear.HeavyHelmet, shoulderPads = true, heavy = true, bulk = 1.15f }
        });
        Foundation.Add(new SquadDef
        {
            id = "b7", name = "Бета-7", nick = "«Безумные шляпники»", team = Team.Foundation, label = "MTF B-7",
            desc = "Химзащита и противогазы. Дробовики и гранатомёты MGL — зачищают толпы и биологические угрозы.",
            primary = "m870", special = "gl", count = 8, hp = 115, armor = 0.3f, accuracy = 0.9f, grenades = 3,
            look = new Look { uniform = C(0.85f, 0.45f, 0.08f), uniform2 = C(0.8f, 0.42f, 0.08f), armor = C(0.15f, 0.15f, 0.14f), helmet = C(0.85f, 0.45f, 0.08f), accent = C(0.1f, 0.1f, 0.1f), visor = C(0.6f, 0.75f, 0.8f, 0.5f), head = HeadGear.Hazmat, backpack = true, bulk = 1.1f }
        });
        Foundation.Add(new SquadDef
        {
            id = "e10", name = "Эта-10", nick = "«Не вижу зла»", team = Team.Foundation, label = "MTF ETA-10",
            desc = "Видят мир через камеры ПНВ — не провоцируют SCP-096 и защищены от SCP-173. Бесшумные Crossvec.",
            primary = "crossvec", count = 8, hp = 100, armor = 0.25f, speed = 1.08f, accuracy = 1.05f, ignores096 = true, blinkImmune = true, grenades = 2,
            look = new Look { uniform = C(0.16f, 0.2f, 0.15f), uniform2 = C(0.13f, 0.16f, 0.12f), armor = C(0.12f, 0.15f, 0.11f), helmet = C(0.12f, 0.15f, 0.11f), accent = C(0.2f, 1f, 0.3f), visor = C(0.1f, 0.9f, 0.2f, 0.9f), visorGlow = true, head = HeadGear.NightVision }
        });
        Foundation.Add(new SquadDef
        {
            id = "t5", name = "Тау-5", nick = "«Сансара»", team = Team.Foundation, label = "MTF TAU-5",
            desc = "Киберсолдаты-клоны в белой броне. Мало, но каждый стоит взвода: огромная живучесть и меткость.",
            primary = "e11", count = 4, maxCount = 8, hp = 260, armor = 0.6f, speed = 1.1f, accuracy = 1.5f, scale = 1.04f, courage = 3f, grenades = 3,
            look = new Look { uniform = C(0.85f, 0.87f, 0.9f), uniform2 = C(0.75f, 0.77f, 0.8f), armor = C(0.93f, 0.94f, 0.96f), helmet = C(0.95f, 0.96f, 0.98f), accent = C(0.1f, 0.85f, 1f), visor = C(0.1f, 0.8f, 1f, 0.85f), visorGlow = true, head = HeadGear.Cyborg, shoulderPads = true, heavy = true }
        });
        Foundation.Add(new SquadDef
        {
            id = "l5", name = "Лямбда-5", nick = "«Белые кролики»", team = Team.Foundation, label = "MTF L-5",
            desc = "Разведка и снайперы. Марксманские винтовки с оптикой, бьют издалека.",
            primary = "dmr", count = 6, hp = 95, armor = 0.15f, speed = 1.05f, accuracy = 1.5f, grenades = 1,
            look = new Look { uniform = C(0.62f, 0.6f, 0.55f), uniform2 = C(0.5f, 0.48f, 0.43f), armor = C(0.45f, 0.43f, 0.38f), helmet = C(0.55f, 0.53f, 0.48f), accent = C(1f, 1f, 1f), head = HeadGear.Cap, vest = true, backpack = false }
        });
        Foundation.Add(new SquadDef
        {
            id = "guard", name = "Охрана Зоны", nick = "«Служба безопасности»", team = Team.Foundation, label = "SECURITY",
            desc = "Обычная охрана комплекса. Дёшево и много: FSP-9 и пистолеты, лёгкая броня.",
            primary = "fsp9", count = 12, maxCount = 20, hp = 90, armor = 0.15f, accuracy = 0.8f, courage = 0.7f, grenades = 1,
            look = new Look { uniform = C(0.22f, 0.23f, 0.25f), uniform2 = C(0.18f, 0.19f, 0.2f), armor = C(0.1f, 0.1f, 0.1f), helmet = C(0.12f, 0.12f, 0.12f), accent = C(0.95f, 0.8f, 0.2f), visor = C(0.05f, 0.05f, 0.05f, 0.6f), head = HeadGear.Helmet, backpack = false, kneePads = false }
        });

        // ---------- ПОВСТАНЦЫ ХАОСА ----------
        Chaos.Add(new SquadDef
        {
            id = "ci_rifle", name = "Штурмовики ХИ", nick = "Основная ударная сила", team = Team.Chaos, label = "CI",
            desc = "Балаклавы, АК-15, высокая агрессия. Десантируются по канатам.",
            primary = "ak", secondary = "pm", count = 8, hp = 105, armor = 0.25f, accuracy = 1f, fastRope = true, grenades = 2,
            look = new Look { uniform = C(0.27f, 0.29f, 0.19f), uniform2 = C(0.2f, 0.22f, 0.15f), armor = C(0.18f, 0.19f, 0.13f), helmet = C(0.08f, 0.08f, 0.08f), accent = C(0.15f, 0.55f, 0.15f), head = HeadGear.Balaclava, skin = C(0.75f, 0.58f, 0.46f) }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_lmg", name = "Пулемётчики ХИ", nick = "Подавление огнём", team = Team.Chaos, label = "CI",
            desc = "Logicer на 100 патронов. Держат линию и прижимают врага к земле.",
            primary = "logicer", secondary = "pm", count = 6, hp = 130, armor = 0.4f, speed = 0.9f, accuracy = 0.9f, scale = 1.04f, fastRope = true,
            look = new Look { uniform = C(0.24f, 0.25f, 0.18f), uniform2 = C(0.19f, 0.2f, 0.14f), armor = C(0.12f, 0.13f, 0.09f), helmet = C(0.2f, 0.21f, 0.15f), accent = C(0.15f, 0.55f, 0.15f), head = HeadGear.Helmet, visor = C(0.05f, 0.05f, 0.05f, 0.8f), heavy = true, bulk = 1.12f }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_breach", name = "Брейчеры ХИ", nick = "Ближний бой", team = Team.Chaos, label = "CI",
            desc = "Сайга-12 и противогазы. Быстро сокращают дистанцию и разрывают в упор.",
            primary = "saiga", secondary = "pm", count = 6, hp = 120, armor = 0.35f, speed = 1.12f, accuracy = 0.9f, courage = 1.5f, fastRope = true, grenades = 3,
            look = new Look { uniform = C(0.12f, 0.13f, 0.1f), uniform2 = C(0.1f, 0.1f, 0.08f), armor = C(0.25f, 0.27f, 0.18f), helmet = C(0.12f, 0.12f, 0.1f), accent = C(0.15f, 0.55f, 0.15f), visor = C(0.4f, 0.5f, 0.3f, 0.6f), head = HeadGear.GasMask }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_sniper", name = "Снайперы ХИ", nick = "Охотники", team = Team.Chaos, label = "CI",
            desc = "СВД с оптикой. Выбивают офицеров и пулемётчиков на дальней дистанции.",
            primary = "svd", secondary = "pm", count = 4, hp = 90, armor = 0.1f, accuracy = 1.5f, fastRope = true, grenades = 1,
            look = new Look { uniform = C(0.33f, 0.31f, 0.22f), uniform2 = C(0.28f, 0.26f, 0.18f), armor = C(0.25f, 0.24f, 0.16f), helmet = C(0.3f, 0.29f, 0.2f), accent = C(0.15f, 0.55f, 0.15f), head = HeadGear.Cap, backpack = true, skin = C(0.8f, 0.62f, 0.5f) }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_rpg", name = "Гранатомётчики ХИ", nick = "Противовоздушная угроза", team = Team.Chaos, label = "CI",
            desc = "РПГ-7. Сбивают вертолёты Фонда и разносят укрытия. Тела разлетаются.",
            primary = "ak", special = "rpg", secondary = "pm", count = 4, hp = 105, armor = 0.25f, accuracy = 0.95f, fastRope = true, grenades = 2,
            look = new Look { uniform = C(0.27f, 0.29f, 0.19f), uniform2 = C(0.2f, 0.22f, 0.15f), armor = C(0.18f, 0.19f, 0.13f), helmet = C(0.08f, 0.08f, 0.08f), accent = C(0.15f, 0.55f, 0.15f), head = HeadGear.Balaclava, backpack = true }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_delta", name = "Командование «Дельта»", nick = "Элита Хаоса", team = Team.Chaos, label = "CI DELTA",
            desc = "Лучшие оперативники Повстанцев: красные визоры, Vector .45, тяжёлая броня.",
            primary = "vector", secondary = "pm", count = 4, maxCount = 8, hp = 170, armor = 0.5f, speed = 1.08f, accuracy = 1.4f, courage = 2f, fastRope = true, grenades = 3,
            look = new Look { uniform = C(0.07f, 0.08f, 0.06f), uniform2 = C(0.06f, 0.06f, 0.05f), armor = C(0.1f, 0.11f, 0.08f), helmet = C(0.08f, 0.09f, 0.07f), accent = C(0.9f, 0.1f, 0.05f), visor = C(1f, 0.1f, 0.05f, 0.85f), visorGlow = true, head = HeadGear.DeltaHelmet, shoulderPads = true, heavy = true }
        });
        Chaos.Add(new SquadDef
        {
            id = "ci_classd", name = "Освобождённый Класс-D", nick = "Пушечное мясо", team = Team.Chaos, label = "CI",
            desc = "Вооружённые Повстанцами бывшие заключённые. Оранжевые робы, пистолеты, никакой брони — зато толпа.",
            primary = "pm", secondary = null, count = 14, maxCount = 24, hp = 80, armor = 0f, accuracy = 0.6f, courage = 0.6f, fastRope = false, grenades = 0,
            look = new Look { uniform = C(0.95f, 0.45f, 0.1f), uniform2 = C(0.92f, 0.43f, 0.09f), armor = C(0.95f, 0.45f, 0.1f), accent = C(0.1f, 0.1f, 0.1f), head = HeadGear.Bare, vest = false, backpack = false, kneePads = false }
        });

        // ---------- SCP ----------
        Scps.Add(new ScpDef { kind = ScpKind.S173, id = "173", name = "SCP-173", nick = "«Скульптура»", count = 1, maxCount = 2, hp = 2600, desc = "Двигается, только когда на него никто не смотрит. Ломает шею мгновенно. Не моргайте." });
        Scps.Add(new ScpDef { kind = ScpKind.S096, id = "096", name = "SCP-096", nick = "«Скромник»", count = 1, maxCount = 2, hp = 3600, desc = "Безобиден, пока никто не увидел его лицо. Потом — крик и неудержимая ярость против каждого, кто посмотрел." });
        Scps.Add(new ScpDef { kind = ScpKind.S049, id = "049", name = "SCP-049", nick = "«Чумной доктор»", count = 1, maxCount = 3, hp = 1900, desc = "Убивает касанием и «лечит» мёртвых — они встают как SCP-049-2 и идут за ним." });
        Scps.Add(new ScpDef { kind = ScpKind.S0492, id = "0492", name = "SCP-049-2", nick = "Зомби", count = 6, maxCount = 20, hp = 170, desc = "Оживлённые трупы. Медленные, упорные, рвут руками." });
        Scps.Add(new ScpDef { kind = ScpKind.S106, id = "106", name = "SCP-106", nick = "«Старик»", count = 1, maxCount = 2, hp = 2300, desc = "Проходит сквозь стены и землю, разъедает плоть, утаскивает жертв в своё измерение." });
        Scps.Add(new ScpDef { kind = ScpKind.S939, id = "939", name = "SCP-939", nick = "«Многоголосый»", count = 4, maxCount = 10, hp = 480, desc = "Стая слепых хищников. Быстрые, прыгают на жертву, страшная пасть." });
        Scps.Add(new ScpDef { kind = ScpKind.S682, id = "682", name = "SCP-682", nick = "«Неуязвимая рептилия»", count = 1, maxCount = 1, hp = 12000, desc = "Огромный регенерирующий ящер. Таранит строй, раскидывая тела. Ненавидит всё живое." });
        Scps.Add(new ScpDef { kind = ScpKind.S457, id = "457", name = "SCP-457", nick = "«Горящий человек»", count = 1, maxCount = 3, hp = 1600, desc = "Живое пламя. Жжёт всё вокруг, поджигает тела. Пули ему почти не вредят." });
    }

    public static string KindName(WeaponKind k)
    {
        switch (k)
        {
            case WeaponKind.Rifle: return "штурмовая винтовка";
            case WeaponKind.SMG: return "пистолет-пулемёт";
            case WeaponKind.Shotgun: return "дробовик";
            case WeaponKind.LMG: return "пулемёт";
            case WeaponKind.Sniper: return "снайперская винтовка";
            case WeaponKind.Pistol: return "пистолет";
            default: return "гранатомёт";
        }
    }
}
