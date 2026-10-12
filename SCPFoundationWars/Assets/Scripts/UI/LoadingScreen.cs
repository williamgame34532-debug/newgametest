using UnityEngine;

// Экран загрузки в стиле досье Фонда: коридор комплекса, гриф секретности, карточка объекта с классом
// и особыми условиями содержания, протоколы-подсказки и поэтапная полоса загрузки.
public partial class Game
{
    Texture2D loadBg; int loadBgFor = -1; float loadStart;

    static readonly string[] LoadTips =
    {
        "SCP-173 движется, только когда на него никто не смотрит. Держите его в поле зрения и моргайте по очереди.",
        "SCP-096: не смотрите на его лицо — ни вживую, ни через прицел. Увидевший будет найден, где бы он ни был.",
        "Голоса в темноте могут принадлежать SCP-939. Не идите на зов — сверьтесь по рации.",
        "SCP-106 проходит сквозь стены. Слышите смех и видите коррозию — уходите и не давайте ему коснуться.",
        "SCP-049 убивает касанием, а «вылеченные» встают как SCP-049-2. Держите дистанцию.",
        "SCP-682 не убить. Задача — сдержать: огнём остановить таран, затем применить средство содержания.",
        "Особое средство сдерживания носит один боец отряда. Если он пал — подберите средство и завершите дело сами.",
        "Удерживайте R, чтобы проверить магазин. Левый Alt — осмотреться, не сбивая прицела.",
        "В комплексе гермодвери открываются сами, когда к ним подходят. Лифты и спуски — клавиша E.",
        "МОГ Эпсилон-11 «Девятихвостая лиса» — подразделение для работы внутри объектов при нарушении условий содержания.",
        "Повстанцы Хаоса — бывшая ячейка Фонда, ушедшая с его объектами. Им нужны аномалии, а не их содержание.",
        "Тяжёлое оружие тяжелее в руках: дольше вскидывается и сильнее уводит при движении.",
        "Напуганный боец может бежать к соседнему отряду с докладом — после этого тот идёт тише и осторожнее.",
    };

    // Класс объекта и сжатые «особые условия содержания» по материалам Фонда
    static string ScpClass(ScpKind k) => k == ScpKind.S106 || k == ScpKind.S682 || k == ScpKind.S939 ? "KETER" : "EUCLID";
    static string ScpProcedure(ScpKind k)
    {
        switch (k)
        {
            case ScpKind.S173: return "Содержится в запертом контейнере. Входить не менее чем втроём; дверь запирать за собой. Двое сохраняют зрительный контакт, пока третий работает; о моргании предупреждать.";
            case ScpKind.S096: return "Камера — герметичный стальной куб. Визуальный контакт с лицом объекта (в том числе на снимках и видео) недопустим. Посмотревший будет найден и убит.";
            case ScpKind.S049: return "Гуманоид, называющий себя врачом, лечащим «Поветрие». Касание смертельно; «пациенты» поднимаются как SCP-049-2. При контакте — не вступать в разговор.";
            case ScpKind.S0492: return "Реанимированные SCP-049 тела. Агрессивны к живым, медлительны. Уничтожать с дистанции.";
            case ScpKind.S106: return "Проходит сквозь твёрдые тела, оставляя коррозию; уводит жертв в «карманное измерение». Камера — подвешенная многослойная ячейка; для повторной поимки — процедура «Ломатель бёдер».";
            case ScpKind.S939: return "Стая хищников, охотящихся на звук. Подражают голосам своих жертв, чтобы заманить. Персоналу запрещено идти на голоса из тёмных помещений.";
            case ScpKind.S682: return "Крайне враждебная рептилия с почти мгновенной регенерацией. Уничтожение не удаётся; содержать в резервуаре с соляной кислотой, постоянно её разрушающей.";
            default: return "Обращаться согласно протоколу объекта. Нарушение условий содержания — немедленно докладывать.";
        }
    }

    void LoadingGUI(Battle b)
    {
        var cfg = Battle.Cfg;
        int want = cfg != null ? (cfg.seed % 3) + 1 : 1;
        if (loadBg == null || loadBgFor != want) { loadBg = Resources.Load<Texture2D>("Branding/Loading_" + want); loadBgFor = want; loadStart = Time.unscaledTime; }
        float t = Time.unscaledTime - loadStart;
        Rect(new Rect(0, 0, W, H), new Color(0.015f, 0.016f, 0.02f, 1f));
        if (loadBg != null)
        {
            // медленный «наезд» камеры по коридору
            float z = 1f + Mathf.Min(t, 40f) * 0.004f;
            float bw = Mathf.Max(W, H * 16f / 9f) * z, bh = bw * 9f / 16f;
            GUI.DrawTexture(new Rect((W - bw) * 0.5f, (H - bh) * 0.5f, bw, bh), loadBg, ScaleMode.StretchToFill);
        }
        // затемнение слева под текст + развёртка
        MenuStyles();
        GUI.DrawTexture(new Rect(0, 0, 1250, H), gradTex);
        for (int y = ((int)(t * 40f)) % 4; y < H; y += 4) Rect(new Rect(0, y, W, 1), new Color(0, 0, 0, 0.12f));

        // гриф
        if (logoTex != null) GUI.DrawTexture(new Rect(64, 56, 92, 92), logoTex, ScaleMode.ScaleToFit); else DrawLogo(new Vector2(110, 102), 40);
        Label(new Rect(172, 60, 900, 28), "ФОНД SCP  ·  ЗАЩИЩЁННЫЙ КАНАЛ  ·  ТЕРМИНАЛ МОГ", new GUIStyle(small) { fontSize = 15 }, new Color(0.75f, 0.78f, 0.8f, 0.9f));
        Label(new Rect(172, 86, 900, 24), "ОБЕЗОПАСИТЬ. УДЕРЖАТЬ. СОХРАНИТЬ.", new GUIStyle(small) { fontSize = 14, font = fontTitle }, new Color(1f, 0.78f, 0.32f, 0.85f));
        Label(new Rect(172, 112, 900, 24), "СЕКРЕТНО  ·  УРОВЕНЬ ДОПУСКА 3", new GUIStyle(small) { fontSize = 14 }, new Color(1f, 0.35f, 0.28f, 0.6f + 0.4f * Mathf.Abs(Mathf.Sin(t * 1.7f))));

        // заголовок операции
        string head = cfg != null && cfg.op != null ? cfg.op.code + " — «" + cfg.op.title + "»" : "ОПЕРАЦИЯ";
        string place = cfg != null ? (cfg.op != null ? cfg.op.place : MapGen.MapNames[Mathf.Clamp(cfg.map, 0, MapGen.MapNames.Length - 1)]) : "";
        string when = cfg != null ? MapGen.TimeNames[Mathf.Clamp(cfg.time, 0, 2)] : "";
        Shadowed(new Rect(64, 190, 1150, 64), head.ToUpper(), new GUIStyle(h1) { fontSize = 46, alignment = TextAnchor.MiddleLeft }, Color.white);
        Label(new Rect(66, 252, 1100, 30), place + "   ·   " + when + (cfg != null && cfg.humans != null ? "   ·   сетевая игра, игроков: " + cfg.humans.Count : ""), body, new Color(0.8f, 0.82f, 0.82f));
        Rect(new Rect(64, 292, 640, 2), new Color(1f, 0.72f, 0.2f, 0.8f));

        // досье объекта (по очереди — все объекты операции)
        float y0 = 320;
        if (cfg != null && cfg.scps.Count > 0)
        {
            var sp = cfg.scps[((int)(t / 7f)) % cfg.scps.Count];
            var d = sp.def;
            Rect(new Rect(64, y0, 720, 250), new Color(0.02f, 0.02f, 0.025f, 0.72f));
            Rect(new Rect(64, y0, 4, 250), ScpClass(d.kind) == "KETER" ? new Color(0.9f, 0.15f, 0.12f) : new Color(1f, 0.72f, 0.2f));
            Label(new Rect(86, y0 + 12, 400, 22), "ДОСЬЕ ОБЪЕКТА", new GUIStyle(small) { fontSize = 13 }, new Color(0.7f, 0.72f, 0.74f));
            Shadowed(new Rect(86, y0 + 34, 520, 46), d.name + (sp.count > 1 ? "  ×" + sp.count : ""), new GUIStyle(h1) { fontSize = 34, alignment = TextAnchor.MiddleLeft }, Color.white);
            Label(new Rect(86, y0 + 78, 520, 26), d.nick, body, new Color(0.85f, 0.85f, 0.8f));
            // штамп класса
            var cls = ScpClass(d.kind);
            Color cc = cls == "KETER" ? new Color(0.95f, 0.2f, 0.15f) : new Color(1f, 0.75f, 0.2f);
            var old = GUI.matrix;
            GUIUtility.RotateAroundPivot(-8f, new Vector2(700, y0 + 60));
            Rect(new Rect(612, y0 + 40, 176, 44), new Color(cc.r, cc.g, cc.b, 0.12f));
            Rect(new Rect(612, y0 + 40, 176, 2), cc); Rect(new Rect(612, y0 + 82, 176, 2), cc);
            Rect(new Rect(612, y0 + 40, 2, 44), cc); Rect(new Rect(786, y0 + 40, 2, 44), cc);
            Label(new Rect(612, y0 + 40, 176, 44), cls, new GUIStyle(h1) { fontSize = 26, alignment = TextAnchor.MiddleCenter }, cc);
            GUI.matrix = old;
            Label(new Rect(86, y0 + 112, 680, 22), "ОСОБЫЕ УСЛОВИЯ СОДЕРЖАНИЯ", new GUIStyle(small) { fontSize = 13 }, new Color(1f, 0.72f, 0.2f, 0.9f));
            Label(new Rect(86, y0 + 136, 680, 110), ScpProcedure(d.kind), new GUIStyle(body) { wordWrap = true, fontSize = 18 }, new Color(0.86f, 0.87f, 0.86f));
            y0 += 270;
        }

        // протокол (подсказка дня)
        string tip = LoadTips[((int)(t / 6f) + (cfg != null ? cfg.seed : 0)) % LoadTips.Length];
        Label(new Rect(64, y0, 400, 22), "ПРОТОКОЛ", new GUIStyle(small) { fontSize = 13 }, new Color(0.6f, 0.78f, 1f, 0.9f));
        Label(new Rect(64, y0 + 24, 720, 80), tip, new GUIStyle(body) { wordWrap = true, fontSize = 18 }, new Color(0.82f, 0.84f, 0.86f));

        // этапы загрузки
        string stage; float prog;
        if (MapGen.Root == null) { stage = "Развёртывание района операции"; prog = 0.05f; }
        else if (b.loadProgress < 1f) { stage = "Прокладка маршрутов для отрядов"; prog = 0.15f + 0.8f * b.loadProgress; }
        else if (Net.InGame) { stage = "Ожидание остальных игроков"; prog = 0.97f; }
        else { stage = "Связь с командованием"; prog = 0.99f; }
        float bx = 64, by = H - 120, bwid = W - 128;
        // жёлто-чёрная лента
        for (float sx = 0; sx < W; sx += 36) { var o2 = GUI.matrix; GUIUtility.RotateAroundPivot(35f, new Vector2(sx, H - 10)); Rect(new Rect(sx, H - 22, 18, 40), new Color(0.85f, 0.62f, 0.08f, 0.85f)); GUI.matrix = o2; }
        Rect(new Rect(0, H - 22, W, 22), new Color(0, 0, 0, 0.35f));
        Label(new Rect(bx, by - 34, 900, 28), stage.ToUpper() + new string('.', 1 + (int)(t * 2f) % 3), new GUIStyle(body) { fontSize = 18 }, Color.white);
        Label(new Rect(bx + bwid - 200, by - 34, 200, 28), Mathf.RoundToInt(prog * 100) + "%", new GUIStyle(body) { alignment = TextAnchor.MiddleRight, fontSize = 18 }, new Color(1f, 0.78f, 0.32f));
        Rect(new Rect(bx, by, bwid, 6), new Color(1, 1, 1, 0.12f));
        Rect(new Rect(bx, by, bwid * prog, 6), new Color(1f, 0.72f, 0.2f));
        // бегущий блик по полосе
        float glow = (t * 0.6f) % 1f;
        Rect(new Rect(bx + bwid * prog * glow - 30, by, 60, 6), new Color(1f, 0.95f, 0.7f, 0.5f));
    }
}
