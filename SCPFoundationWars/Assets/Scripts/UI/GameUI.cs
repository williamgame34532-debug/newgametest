using System.Collections.Generic;
using UnityEngine;

// Интерфейс (IMGUI): главное меню, выбор отрядов, настройки, HUD, пауза, итоги
public partial class Game
{
    GUIStyle title, h1, h2, body, small, btn, btnBig, card, cardSel, panel, center, ammoBig, feedSt, msgSt, toggleOn, toggleOff, tagSt;
    Texture2D white;
    Vector2 scrollF, scrollC, scrollS;
    float W, H;

    static Texture2D Solid(Color c) { var t = new Texture2D(1, 1); t.SetPixel(0, 0, c); t.Apply(); return t; }

    void Styles()
    {
        if (title != null) return;
        white = Solid(Color.white);
        var dark = Solid(new Color(0.06f, 0.07f, 0.08f, 0.92f));
        var cardBg = Solid(new Color(0.1f, 0.11f, 0.13f, 0.95f));
        var cardSelBg = Solid(new Color(0.16f, 0.2f, 0.25f, 0.97f));
        var btnBg = Solid(new Color(0.18f, 0.19f, 0.2f, 1f));
        var btnHover = Solid(new Color(0.3f, 0.32f, 0.34f, 1f));
        var btnAct = Solid(new Color(0.85f, 0.6f, 0.1f, 1f));
        title = new GUIStyle { fontSize = 78, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleLeft };
        title.normal.textColor = new Color(0.95f, 0.95f, 0.95f);
        h1 = new GUIStyle { fontSize = 34, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleLeft };
        h1.normal.textColor = Color.white;
        h2 = new GUIStyle { fontSize = 22, fontStyle = FontStyle.Bold, alignment = TextAnchor.UpperLeft, wordWrap = false };
        h2.normal.textColor = Color.white;
        body = new GUIStyle { fontSize = 17, wordWrap = true, alignment = TextAnchor.UpperLeft };
        body.normal.textColor = new Color(0.82f, 0.84f, 0.86f);
        small = new GUIStyle(body) { fontSize = 15 };
        small.normal.textColor = new Color(0.65f, 0.68f, 0.7f);
        center = new GUIStyle(body) { alignment = TextAnchor.MiddleCenter, fontSize = 20 };
        btn = new GUIStyle { fontSize = 20, alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold };
        btn.normal.background = btnBg; btn.hover.background = btnHover; btn.active.background = btnAct;
        btn.normal.textColor = Color.white; btn.hover.textColor = Color.white; btn.active.textColor = Color.black;
        btnBig = new GUIStyle(btn) { fontSize = 30 };
        btnBig.normal.background = Solid(new Color(0.75f, 0.12f, 0.08f)); btnBig.hover.background = Solid(new Color(0.9f, 0.2f, 0.12f));
        card = new GUIStyle { padding = new RectOffset(12, 12, 10, 10) };
        card.normal.background = cardBg;
        cardSel = new GUIStyle(card); cardSel.normal.background = cardSelBg;
        panel = new GUIStyle(); panel.normal.background = dark;
        ammoBig = new GUIStyle { fontSize = 52, fontStyle = FontStyle.Bold, alignment = TextAnchor.LowerRight };
        ammoBig.normal.textColor = Color.white;
        feedSt = new GUIStyle { fontSize = 17, alignment = TextAnchor.MiddleRight, fontStyle = FontStyle.Bold };
        msgSt = new GUIStyle { fontSize = 26, alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold };
        toggleOn = new GUIStyle(btn) { fontSize = 17 }; toggleOn.normal.background = Solid(new Color(0.2f, 0.45f, 0.75f)); toggleOn.hover.background = Solid(new Color(0.25f, 0.52f, 0.85f));
        toggleOff = new GUIStyle(btn) { fontSize = 17 };
        tagSt = new GUIStyle { fontSize = 14, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleCenter };
        tagSt.normal.textColor = Color.black;
        // шрифты (Google Fonts, OFL): заголовки — Russo One, текст — Oswald
        fontTitle = Resources.Load<Font>("Branding/RussoOne");
        fontHud = Resources.Load<Font>("Branding/Oswald");
        foreach (var st in new[] { title, h1, btnBig }) if (fontTitle != null) { st.font = fontTitle; st.fontStyle = FontStyle.Normal; }
        foreach (var st in new[] { h2, body, small, center, btn, ammoBig, feedSt, msgSt, toggleOn, toggleOff, tagSt }) if (fontHud != null) st.font = fontHud;
        if (fontHud != null) GUI.skin.font = fontHud;
    }

    void Rect(Rect r, Color c) { var old = GUI.color; GUI.color = c; GUI.DrawTexture(r, white); GUI.color = old; }

    void Label(Rect r, string s, GUIStyle st, Color c)
    {
        var old = st.normal.textColor;
        st.normal.textColor = c;
        GUI.Label(r, s, st);
        st.normal.textColor = old;
    }

    void Shadowed(Rect r, string s, GUIStyle st, Color c)
    {
        Label(new Rect(r.x + 2, r.y + 2, r.width, r.height), s, st, new Color(0, 0, 0, 0.8f * c.a));
        Label(r, s, st, c);
    }

    void OnGUI()
    {
        Styles();
        float sc = Screen.height / 1080f;
        GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1));
        W = Screen.width / sc; H = 1080f;
        switch (screen)
        {
            case Scr.Menu: MenuGUI(); break;
            case Scr.Setup: SetupGUI(); break;
            case Scr.Settings: SettingsGUI(); break;
            case Scr.Ops: OpsGUI(); break;
            case Scr.Battle: BattleGUI(); break;
        }
    }

    // ---------------- главное меню ----------------
    Texture2D logoTex, gradTex;
    GUIStyle menuBtn, menuBtnSub;

    void MenuStyles()
    {
        if (menuBtn != null) return;
        logoTex = Resources.Load<Texture2D>("Branding/Logo");
        gradTex = new Texture2D(256, 1, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        for (int i = 0; i < 256; i++) gradTex.SetPixel(i, 0, new Color(0.02f, 0.025f, 0.03f, Mathf.Lerp(0.92f, 0f, Mathf.SmoothStep(0, 1, i / 255f))));
        gradTex.Apply();
        menuBtn = new GUIStyle { fontSize = 30, font = fontTitle, alignment = TextAnchor.MiddleLeft, padding = new RectOffset(28, 10, 0, 0) };
        menuBtn.normal.textColor = new Color(0.86f, 0.87f, 0.84f);
        menuBtn.hover.textColor = Color.white;
        menuBtnSub = new GUIStyle(menuBtn) { fontSize = 22, font = fontHud };
    }

    // Кнопка меню: тонкая подложка, при наведении — акцентная полоса слева и подсветка
    bool MenuButton(Rect r, string text, string hint, bool big = false)
    {
        bool hover = r.Contains(Event.current.mousePosition);
        Rect(r, new Color(1, 1, 1, hover ? 0.08f : 0.025f));
        Rect(new Rect(r.x, r.y, hover ? 6 : 2, r.height), hover ? new Color(1f, 0.72f, 0.2f) : new Color(1, 1, 1, 0.25f));
        bool click = GUI.Button(r, text, big ? menuBtn : menuBtnSub);
        if (hover && hint != null) Label(new Rect(r.xMax + 24, r.y, 520, r.height), hint, new GUIStyle(small) { alignment = TextAnchor.MiddleLeft }, new Color(0.75f, 0.77f, 0.75f, 0.9f));
        if (click) Sfx.Play2D("ui");
        return click;
    }

    void MenuGUI()
    {
        MenuStyles();
        GUI.DrawTexture(new Rect(0, 0, 1100, H), gradTex);
        // гриф и логотип
        if (logoTex != null) GUI.DrawTexture(new Rect(64, 70, 150, 150), logoTex, ScaleMode.ScaleToFit);
        else DrawLogo(new Vector2(140, 145), 64);
        Shadowed(new Rect(236, 78, 700, 90), "SCP", new GUIStyle(title) { fontSize = 84 }, Color.white);
        Shadowed(new Rect(240, 160, 700, 50), "ВОЙНА ЗА ФОНД", h1, new Color(1f, 0.78f, 0.32f));
        Rect(new Rect(64, 240, 520, 1), new Color(1, 1, 1, 0.25f));
        Label(new Rect(64, 250, 900, 30), "СЕКРЕТНО  ·  УРОВЕНЬ ДОПУСКА 3  ·  ТОЛЬКО ДЛЯ ПЕРСОНАЛА МОГ", new GUIStyle(small) { fontSize = 14 }, new Color(1f, 0.4f, 0.3f, 0.85f));
        float y = 330;
        if (MenuButton(new Rect(64, y, 560, 70), "НОВАЯ ОПЕРАЦИЯ", "Собрать отряды МОГ, выбрать противника и место", true)) screen = Scr.Setup;
        y += 84;
        if (MenuButton(new Rect(64, y, 560, 58), "Реальные операции Фонда", "Шесть сценариев по документам Фонда")) { Operations.Init(); screen = Scr.Ops; }
        y += 68;
        if (lastCfg != null) { if (MenuButton(new Rect(64, y, 560, 58), "Повторить последнюю", "Тот же состав, новая карта")) { var c = lastCfg; c.seed = Random.Range(1, 99999); StartBattle(c); } y += 68; }
        if (MenuButton(new Rect(64, y, 560, 58), "Быстрый бой", "Случайные отряды, противник и место")) { Randomize(); StartBattle(MakeConfig()); }
        y += 68;
        if (MenuButton(new Rect(64, y, 560, 58), "Настройки", "Графика, звук, управление")) { settingsReturn = Scr.Menu; screen = Scr.Settings; }
        y += 68;
        if (MenuButton(new Rect(64, y, 560, 58), "Выход", null)) Application.Quit();
        Label(new Rect(64, H - 70, 900, 30), "ОБЕСПЕЧИТЬ. УДЕРЖАТЬ. СОХРАНИТЬ.", new GUIStyle(small) { fontSize = 16, font = fontTitle }, new Color(0.7f, 0.7f, 0.68f, 0.8f));
        Label(new Rect(W - 420, H - 46, 380, 24), "v3 · Unity 6", new GUIStyle(small) { alignment = TextAnchor.MiddleRight, fontSize = 13 }, new Color(1, 1, 1, 0.35f));
    }

    void DrawLogo(Vector2 c, float r)
    {
        // упрощённый знак Фонда: кольцо и три стрелки
        for (int i = 0; i < 48; i++)
        {
            float a = i / 48f * Mathf.PI * 2f;
            Rect(new Rect(c.x + Mathf.Cos(a) * r - 5, c.y + Mathf.Sin(a) * r - 5, 10, 10), Color.white);
            Rect(new Rect(c.x + Mathf.Cos(a) * r * 0.45f - 3, c.y + Mathf.Sin(a) * r * 0.45f - 3, 6, 6), Color.white);
        }
        for (int k = 0; k < 3; k++)
        {
            float a = (k / 3f) * Mathf.PI * 2f - Mathf.PI / 2f;
            for (int j = 0; j < 8; j++)
            {
                float rr = r * (0.5f + j * 0.08f);
                Rect(new Rect(c.x + Mathf.Cos(a) * rr - 4, c.y + Mathf.Sin(a) * rr - 4, 8, 8), Color.white);
            }
        }
    }

    // ---------------- выбор отрядов ----------------
    void Randomize()
    {
        fPick.Clear(); cPick.Clear(); sPick.Clear(); fOrder.Clear();
        var f = new List<SquadDef>(DB.Foundation);
        int nf = Random.Range(2, 6);
        for (int i = 0; i < nf && f.Count > 0; i++) { var d = f[Random.Range(0, f.Count)]; f.Remove(d); fPick[d.id] = d.count; fOrder.Add(d.id); }
        var c = new List<SquadDef>(DB.Chaos);
        int nc = Random.Range(1, 5);
        for (int i = 0; i < nc && c.Count > 0; i++) { var d = c[Random.Range(0, c.Count)]; c.Remove(d); cPick[d.id] = d.count; }
        var s = new List<ScpDef>(DB.Scps);
        int ns = Random.Range(0, 3);
        for (int i = 0; i < ns && s.Count > 0; i++) { var d = s[Random.Range(0, s.Count)]; s.Remove(d); sPick[d.id] = d.count; }
        if (cPick.Count == 0 && sPick.Count == 0) cPick["ci_rifle"] = 8;
        mapSel = Random.Range(0, MapGen.MapNames.Length);
        timeSel = Random.Range(0, MapGen.TimeNames.Length);
        playerSquadId = fOrder.Count > 0 ? fOrder[0] : null;
    }

    int Total(Dictionary<string, int> d) { int n = 0; foreach (var kv in d) n += kv.Value; return n; }

    void SetupGUI()
    {
        Rect(new Rect(0, 0, W, H), new Color(0.03f, 0.035f, 0.04f, 0.88f));
        Shadowed(new Rect(40, 18, 1200, 56), "ФОРМИРОВАНИЕ ОПЕРАЦИИ", h1, Color.white);
        Label(new Rect(42, 66, 1400, 30), "Выбери отряды Фонда (до 5), противников и SCP-объекты. Каждый отряд прилетит на своём вертолёте.", small, new Color(0.7f, 0.7f, 0.7f));

        float colW = (W - 120) / 3f;
        float top = 110, bottom = H - 150;
        // ---- Фонд
        float x = 40;
        Rect(new Rect(x, top, colW, 46), new Color(0.12f, 0.3f, 0.55f, 0.95f));
        Label(new Rect(x + 14, top, colW, 46), "ФОНД SCP — МОГ   (" + fOrder.Count + "/5 отрядов, " + Total(fPick) + " бойцов)", h2, Color.white);
        GUILayout.BeginArea(new Rect(x, top + 52, colW, bottom - top - 52));
        scrollF = GUILayout.BeginScrollView(scrollF);
        foreach (var d in DB.Foundation) SquadCard(d, fPick, colW - 30, true);
        GUILayout.EndScrollView();
        GUILayout.EndArea();
        // ---- Хаос
        x += colW + 20;
        Rect(new Rect(x, top, colW, 46), new Color(0.18f, 0.32f, 0.12f, 0.95f));
        Label(new Rect(x + 14, top, colW, 46), "ПОВСТАНЦЫ ХАОСА   (" + cPick.Count + " отр., " + Total(cPick) + " бойцов)", h2, Color.white);
        GUILayout.BeginArea(new Rect(x, top + 52, colW, bottom - top - 52));
        scrollC = GUILayout.BeginScrollView(scrollC);
        foreach (var d in DB.Chaos) SquadCard(d, cPick, colW - 30, false);
        GUILayout.EndScrollView();
        GUILayout.EndArea();
        // ---- SCP
        x += colW + 20;
        Rect(new Rect(x, top, colW, 46), new Color(0.45f, 0.08f, 0.06f, 0.95f));
        Label(new Rect(x + 14, top, colW, 46), "SCP-ОБЪЕКТЫ   (" + (scpAlly ? "на стороне Хаоса" : "атакуют всех") + ")", h2, Color.white);
        GUILayout.BeginArea(new Rect(x, top + 52, colW, bottom - top - 52));
        scrollS = GUILayout.BeginScrollView(scrollS);
        foreach (var d in DB.Scps) ScpCard(d, colW - 30);
        GUILayout.EndScrollView();
        GUILayout.EndArea();

        // ---- нижняя панель
        float by = H - 135;
        Rect(new Rect(0, by - 8, W, 143), new Color(0, 0, 0, 0.6f));
        float bx = 40;
        Label(new Rect(bx, by, 300, 26), "Карта", small, Color.gray);
        if (GUI.Button(new Rect(bx, by + 26, 40, 44), "<", btn)) mapSel = (mapSel + MapGen.MapNames.Length - 1) % MapGen.MapNames.Length;
        Label(new Rect(bx + 44, by + 26, 272, 44), MapGen.MapNames[mapSel], center, Color.white);
        if (GUI.Button(new Rect(bx + 320, by + 26, 40, 44), ">", btn)) mapSel = (mapSel + 1) % MapGen.MapNames.Length;
        bx += 380;
        Label(new Rect(bx, by, 200, 26), "Время суток", small, Color.gray);
        if (GUI.Button(new Rect(bx, by + 26, 40, 44), "<", btn)) timeSel = (timeSel + 2) % 3;
        Label(new Rect(bx + 44, by + 26, 122, 44), MapGen.TimeNames[timeSel], center, Color.white);
        if (GUI.Button(new Rect(bx + 170, by + 26, 40, 44), ">", btn)) timeSel = (timeSel + 1) % 3;
        bx += 230;
        if (GUI.Button(new Rect(bx, by + 26, 250, 44), scpAlly ? "SCP: союзники Хаоса" : "SCP: атакуют всех", scpAlly ? toggleOn : toggleOff)) scpAlly = !scpAlly;
        bx += 260;
        if (GUI.Button(new Rect(bx, by + 26, 210, 44), friendlyFire ? "Огонь по своим: ВКЛ" : "Огонь по своим: ВЫКЛ", friendlyFire ? toggleOn : toggleOff)) friendlyFire = !friendlyFire;
        bx += 220;
        if (GUI.Button(new Rect(bx, by + 26, 250, 44), playerFps ? "Режим: от первого лица" : "Режим: наблюдатель", playerFps ? toggleOn : toggleOff)) playerFps = !playerFps;
        // вторая строка — не пересекается с кнопкой "В БОЙ!"
        if (GUI.Button(new Rect(W - 720, by + 82, 150, 40), "Случайно", btn)) Randomize();
        if (GUI.Button(new Rect(W - 560, by + 82, 150, 40), "Очистить", btn)) { fPick.Clear(); cPick.Clear(); sPick.Clear(); fOrder.Clear(); }

        bool okF = fOrder.Count > 0, okE = cPick.Count > 0 || sPick.Count > 0;
        string why = !okF ? "Выбери хотя бы один отряд Фонда" : !okE ? "Выбери противников: Хаос и/или SCP" : "";
        if (why != "") Label(new Rect(W - 520, by - 40, 480, 30), why, small, new Color(1f, 0.5f, 0.4f));
        GUI.enabled = okF && okE;
        if (GUI.Button(new Rect(W - 380, by + 18, 340, 60), "В БОЙ!", btnBig)) { Sfx.Play2D("ui"); StartBattle(MakeConfig()); }
        GUI.enabled = true;
        if (GUI.Button(new Rect(40, by + 82, 160, 40), "← Назад", btn)) { SavePrefs(); screen = Scr.Menu; }
        if (playerFps && fOrder.Count > 0)
        {
            string pn = "";
            foreach (var d in DB.Foundation) if (d.id == playerSquadId) pn = d.name;
            if (pn == "") { playerSquadId = fOrder[0]; }
            Label(new Rect(220, by + 88, 900, 30), "Ты летишь в отряде: " + pn + "  (нажми «Я здесь» на карточке, чтобы сменить)", small, new Color(0.6f, 0.8f, 1f));
        }
    }

    void SquadCard(SquadDef d, Dictionary<string, int> pick, float w, bool foundation)
    {
        bool sel = pick.TryGetValue(d.id, out int n) && n > 0;
        GUILayout.BeginVertical(sel ? cardSel : card, GUILayout.Width(w));
        GUILayout.BeginHorizontal();
        var wd = DB.W(d.primary);
        string extra = d.special != null ? " + " + DB.W(d.special).name : "";
        GUILayout.Label(d.name + "  " + d.nick, h2);
        GUILayout.FlexibleSpace();
        if (GUILayout.Button(sel ? "✓ В ОПЕРАЦИИ" : "+ ДОБАВИТЬ", sel ? toggleOn : toggleOff, GUILayout.Width(170), GUILayout.Height(34)))
        {
            Sfx.Play2D("ui");
            if (sel) { pick.Remove(d.id); fOrder.Remove(d.id); }
            else if (!foundation || fOrder.Count < 5) { pick[d.id] = d.count; if (foundation) fOrder.Add(d.id); }
            else Sfx.Play2D("click");
        }
        GUILayout.EndHorizontal();
        // полоса цвета отряда
        var r = GUILayoutUtility.GetRect(w - 24, 4);
        Rect(r, d.look.accent);
        GUILayout.Label(d.desc, small);
        GUILayout.Label("Оружие: " + wd.name + extra + "   •   HP " + d.hp + "   •   броня " + Mathf.RoundToInt(d.armor * 100) + "%   •   " + (d.fastRope ? "спуск по канатам" : "высадка с посадкой"), small);
        if (sel)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label("Бойцов:", body, GUILayout.Width(80));
            if (GUILayout.Button("−", btn, GUILayout.Width(40), GUILayout.Height(30))) pick[d.id] = Mathf.Max(1, n - 1);
            GUILayout.Label(" " + pick[d.id] + " ", h2, GUILayout.Width(44));
            if (GUILayout.Button("+", btn, GUILayout.Width(40), GUILayout.Height(30))) pick[d.id] = Mathf.Min(d.maxCount, n + 1);
            GUILayout.FlexibleSpace();
            arrive.TryGetValue(d.id, out int ar);
            if (GUILayout.Button(ar == 0 ? "Прибытие: сразу" : "Прибытие: +" + ar + " мин", ar == 0 ? toggleOff : toggleOn, GUILayout.Width(190), GUILayout.Height(30)))
            { Sfx.Play2D("ui"); arrive[d.id] = (ar + 1) % 4; }
            if (foundation && playerFps)
            {
                bool me = playerSquadId == d.id;
                if (GUILayout.Button(me ? "★ Я ЗДЕСЬ" : "Я здесь", me ? toggleOn : toggleOff, GUILayout.Width(140), GUILayout.Height(30))) playerSquadId = d.id;
            }
            GUILayout.EndHorizontal();
        }
        GUILayout.EndVertical();
        GUILayout.Space(8);
    }

    void ScpCard(ScpDef d, float w)
    {
        bool sel = sPick.TryGetValue(d.id, out int n) && n > 0;
        GUILayout.BeginVertical(sel ? cardSel : card, GUILayout.Width(w));
        GUILayout.BeginHorizontal();
        GUILayout.Label(d.name + "  " + d.nick, h2);
        GUILayout.FlexibleSpace();
        if (GUILayout.Button(sel ? "✓ ВЫПУСТИТЬ" : "+ ДОБАВИТЬ", sel ? toggleOn : toggleOff, GUILayout.Width(170), GUILayout.Height(34)))
        {
            Sfx.Play2D("ui");
            if (sel) sPick.Remove(d.id); else sPick[d.id] = d.count;
        }
        GUILayout.EndHorizontal();
        var r = GUILayoutUtility.GetRect(w - 24, 4);
        Rect(r, new Color(0.8f, 0.15f, 0.1f));
        GUILayout.Label(d.desc, small);
        GUILayout.Label("Прочность: " + d.hp + " HP   •   доставка: контейнер на тросе вертолёта", small);
        if (sel && d.maxCount > 1)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label("Количество:", body, GUILayout.Width(110));
            if (GUILayout.Button("−", btn, GUILayout.Width(40), GUILayout.Height(30))) sPick[d.id] = Mathf.Max(1, n - 1);
            GUILayout.Label(" " + sPick[d.id] + " ", h2, GUILayout.Width(44));
            if (GUILayout.Button("+", btn, GUILayout.Width(40), GUILayout.Height(30))) sPick[d.id] = Mathf.Min(d.maxCount, n + 1);
            GUILayout.EndHorizontal();
        }
        GUILayout.EndVertical();
        GUILayout.Space(8);
    }

    // ---------------- реальные операции ----------------
    int opSel;
    Vector2 opScroll;

    string ForceLine(SquadPick p)
    {
        string s = "• " + p.def.name + " — " + p.count + " бойц.";
        if (p.placed) s += p.garrison ? ", уже на позиции" : ", уже на месте";
        else s += p.delay > 0 ? ", вылет через " + Mathf.RoundToInt(p.delay / 60f) + " мин" : ", вылет сразу";
        if (p.def.special != null) s += ", " + DB.W(p.def.special).name;
        return s;
    }

    void OpsGUI()
    {
        Operations.Init();
        var ops = Operations.All;
        opSel = Mathf.Clamp(opSel, 0, ops.Count - 1);
        Rect(new Rect(0, 0, W, H), new Color(0.03f, 0.035f, 0.04f, 0.9f));
        Shadowed(new Rect(40, 18, 1200, 56), "РЕАЛЬНЫЕ ОПЕРАЦИИ ФОНДА", h1, Color.white);
        Label(new Rect(42, 66, 1600, 30), "Сценарии по документам SCP Wiki: состав сил, место и обстоятельства взяты из статей об объектах (это художественная вселенная).", small, new Color(0.7f, 0.7f, 0.7f));
        // список
        float lx = 40, ly = 110, lw = 460;
        for (int i = 0; i < ops.Count; i++)
        {
            var o = ops[i];
            var r = new Rect(lx, ly + i * 112, lw, 102);
            bool sel = i == opSel;
            Rect(r, sel ? new Color(0.16f, 0.2f, 0.25f, 0.97f) : new Color(0.1f, 0.11f, 0.13f, 0.95f));
            Rect(new Rect(r.x, r.y, 6, r.height), sel ? new Color(0.85f, 0.6f, 0.1f) : new Color(0.3f, 0.3f, 0.3f));
            Label(new Rect(r.x + 20, r.y + 10, lw - 30, 26), o.code, small, new Color(0.85f, 0.6f, 0.1f));
            Label(new Rect(r.x + 20, r.y + 34, lw - 30, 32), o.title, h2, Color.white);
            Label(new Rect(r.x + 20, r.y + 68, lw - 30, 26), o.date + "  •  " + MapGen.TimeNames[o.time], small, new Color(0.65f, 0.68f, 0.7f));
            if (GUI.Button(r, GUIContent.none, GUIStyle.none) && !sel) { opSel = i; Sfx.Play2D("ui"); opScroll = Vector2.zero; }
        }
        // досье
        var op = ops[opSel];
        float dx = lx + lw + 30, dw = W - dx - 40, dy = 110, dh = H - 260;
        Rect(new Rect(dx, dy, dw, dh), new Color(0.06f, 0.07f, 0.08f, 0.95f));
        Rect(new Rect(dx, dy, dw, 4), new Color(0.85f, 0.6f, 0.1f));
        GUILayout.BeginArea(new Rect(dx + 30, dy + 20, dw - 60, dh - 30));
        opScroll = GUILayout.BeginScrollView(opScroll);
        var big = new GUIStyle(h1) { wordWrap = true };
        var sec = new GUIStyle(h2); sec.normal.textColor = new Color(0.85f, 0.6f, 0.1f);
        GUILayout.Label("ДОСЬЕ: " + op.code, sec);
        GUILayout.Label(op.title, big);
        GUILayout.Label("Дата: " + op.date + "     Место: " + op.place + "     Карта: " + MapGen.MapNames[op.map] + ", " + MapGen.TimeNames[op.time].ToLower(), small);
        GUILayout.Space(14);
        GUILayout.Label("ЧТО ИЗВЕСТНО", sec);
        GUILayout.Label(op.briefing, body);
        GUILayout.Space(10);
        GUILayout.Label("ЗАДАЧА", sec);
        GUILayout.Label(op.task, body);
        GUILayout.Space(10);
        GUILayout.Label("СИЛЫ ФОНДА", sec);
        foreach (var p in op.foundation) GUILayout.Label(ForceLine(p) + (p.def.id == op.playerSquad ? "   ★ ты здесь" : ""), body);
        GUILayout.Space(6);
        GUILayout.Label("ПРОТИВНИК", sec);
        foreach (var p in op.chaos) GUILayout.Label(ForceLine(p), body);
        foreach (var s in op.scps) GUILayout.Label("• " + s.def.name + " " + s.def.nick + (s.count > 1 ? " × " + s.count : "") + " — уже на свободе", body);
        GUILayout.Label(op.captureEnds ? "Условие: захватить объект (ослабить и удержать зону рядом с ним)." : "Условие: обезвредить всех: уничтожить или захватить каждого.", small);
        GUILayout.Space(10);
        GUILayout.Label("Источник: " + op.source + ". Текст пересказан, лицензия CC BY-SA 3.0.", small);
        GUILayout.EndScrollView();
        GUILayout.EndArea();

        float by = H - 130;
        Rect(new Rect(0, by - 8, W, 138), new Color(0, 0, 0, 0.6f));
        if (GUI.Button(new Rect(40, by + 30, 160, 50), "← Назад", btn)) { Sfx.Play2D("ui"); screen = Scr.Menu; }
        if (GUI.Button(new Rect(230, by + 30, 300, 50), playerFps ? "Режим: от первого лица" : "Режим: наблюдатель", playerFps ? toggleOn : toggleOff)) playerFps = !playerFps;
        if (GUI.Button(new Rect(W - 460, by + 20, 420, 66), "НАЧАТЬ ОПЕРАЦИЮ", btnBig)) { Sfx.Play2D("ui_confirm"); StartBattle(op.ToConfig(playerFps)); }
    }

    // ---------------- настройки ----------------
    void SettingsGUI()
    {
        Rect(new Rect(0, 0, W, H), new Color(0.03f, 0.035f, 0.04f, 0.85f));
        float x = W / 2 - 400, y = 140;
        Shadowed(new Rect(x, 50, 800, 60), "НАСТРОЙКИ", h1, Color.white);
        SettingsBody(x, y);
        if (GUI.Button(new Rect(x, H - 160, 300, 56), "Готово", btn)) { SavePrefs(); screen = settingsReturn; }
    }

    void SettingsBody(float x, float y)
    {
        Label(new Rect(x, y, 400, 30), "Чувствительность мыши: " + Sensitivity.ToString("0.0"), body, Color.white);
        Sensitivity = GUI.HorizontalSlider(new Rect(x + 420, y + 8, 380, 20), Sensitivity, 0.3f, 6f);
        y += 56;
        Label(new Rect(x, y, 400, 30), "Поле зрения (FOV): " + Mathf.RoundToInt(Fov), body, Color.white);
        Fov = GUI.HorizontalSlider(new Rect(x + 420, y + 8, 380, 20), Fov, 60f, 100f);
        y += 56;
        Label(new Rect(x, y, 400, 30), "Громкость: " + Mathf.RoundToInt(Sfx.Volume * 100) + "%", body, Color.white);
        Sfx.Volume = GUI.HorizontalSlider(new Rect(x + 420, y + 8, 380, 20), Sfx.Volume, 0f, 1f);
        y += 56;
        string[] bl = { "Без крови", "Немного", "Нормально", "Много" };
        int bi = Blood <= 0.01f ? 0 : Blood < 0.8f ? 1 : Blood < 1.5f ? 2 : 3;
        Label(new Rect(x, y, 400, 30), "Кровь: " + bl[bi], body, Color.white);
        int nb = Mathf.RoundToInt(GUI.HorizontalSlider(new Rect(x + 420, y + 8, 380, 20), bi, 0, 3));
        Blood = nb == 0 ? 0 : nb == 1 ? 0.5f : nb == 2 ? 1f : 2f;
        Fx.BloodLevel = Blood;
        y += 56;
        Label(new Rect(x, y, 400, 30), "Лимит трупов на карте: " + CorpseLimit, body, Color.white);
        CorpseLimit = Mathf.RoundToInt(GUI.HorizontalSlider(new Rect(x + 420, y + 8, 380, 20), CorpseLimit, 20, 250) / 10f) * 10;
        Ragdoll.MaxCorpses = CorpseLimit;
        y += 50;
        if (GUI.Button(new Rect(x, y, 380, 40), Intro ? "Брифинг на базе перед вылетом: ВКЛ" : "Брифинг на базе перед вылетом: ВЫКЛ", Intro ? toggleOn : toggleOff)) Intro = !Intro;
        if (GUI.Button(new Rect(x + 400, y, 380, 40), PostFX.Enabled ? "Кинематографичная картинка: ВКЛ" : "Кинематографичная картинка: ВЫКЛ", PostFX.Enabled ? toggleOn : toggleOff)) PostFX.Enabled = !PostFX.Enabled;
        y += 60;
        Label(new Rect(x, y, 900, 340),
            "Управление:\n" +
            "WASD — движение, Shift — бег, Ctrl/C — присесть (на бегу — подкат), Z — лечь, Пробел — прыжок / перелезть\n" +
            "Q/E — выглянуть из-за укрытия, B — переводчик огня (авто/одиночный), Alt — свободный обзор\n" +
            "Shift в прицеле — задержать дыхание (меньше раскачки), бег расходует выносливость\n" +
            "ЛКМ — огонь, ПКМ — прицел, R — перезарядка (зажать — проверить магазин), 1/2/3 или колесо — оружие\n" +
            "G — граната, H — аптечка, F — фонарик, V — удар прикладом, I — осмотреть оружие\n" +
            "Отряду: X — занять точку под прицелом, Y — за мной, U — вернуться к приказам командира\nT — замедление времени, Esc — пауза\n" +
            "После смерти: 1/ЛКМ — взять под контроль бойца Фонда, 2 — наблюдать\n" +
            "Наблюдатель: WASD/Q/E — полёт, Tab — следить за бойцом, Пробел — свободная камера, 1 — вселиться",
            body, new Color(0.75f, 0.78f, 0.8f));
    }

    // ---------------- бой ----------------
    void BattleGUI()
    {
        var b = Battle.I;
        if (b == null) return;
        if (b.loading)
        {
            Rect(new Rect(0, 0, W, H), new Color(0.03f, 0.035f, 0.04f, 1f));
            DrawLogo(new Vector2(W / 2, H / 2 - 120), 60);
            Shadowed(new Rect(0, H / 2 - 20, W, 50), "ПОДГОТОВКА ОПЕРАЦИИ…", h1 == null ? msgSt : new GUIStyle(h1) { alignment = TextAnchor.MiddleCenter }, Color.white);
            Label(new Rect(0, H / 2 + 30, W, 30), "Разведка местности, прокладка маршрутов для отрядов — " + Mathf.RoundToInt(b.loadProgress * 100) + "%", center, new Color(0.7f, 0.7f, 0.7f));
            Rect(new Rect(W / 2 - 300, H / 2 + 72, 600, 8), new Color(0.2f, 0.2f, 0.2f));
            Rect(new Rect(W / 2 - 300, H / 2 + 72, 600 * b.loadProgress, 8), new Color(0.85f, 0.6f, 0.1f));
            return;
        }
        if (b.cmdF != null)
        {
            float t = b.cmdF.NextReinforcement(out string rn);
            if (rn != null && t < 600f)
                Shadowed(new Rect(W / 2 - 300, 104, 600, 26), "Подкрепление " + rn + ": вылет через " + Mathf.FloorToInt(t / 60) + ":" + Mathf.FloorToInt(t % 60).ToString("00"), new GUIStyle(small) { alignment = TextAnchor.MiddleCenter }, new Color(0.6f, 0.8f, 1f));
        }
        if (b.PlayerCanLaunch && !b.intro)
        {
            Shadowed(new Rect(W / 2 - 300, 128, 600, 24), "[Enter] или Esc → «Вылететь сейчас» — не ждать вылета", new GUIStyle(small) { alignment = TextAnchor.MiddleCenter, fontSize = 14 }, new Color(1f, 0.85f, 0.5f));
        }
        Speech.Draw(Screen.height / 1080f);
        var pc = PlayerController.I;
        if (pc != null && !pc.dead) PlayerHUD(pc);
        else if (pc != null && pc.dead) DeathHUD(pc);
        else if (SpectatorCam.Active) SpectatorHUD();

        bool playing = pc != null && !pc.dead;
        if (!playing) { TeamBar(b); Feed(b); }
        Orders(b, pc);
        Messages(b);
        IntroOverlay(b);
        if (b.over && !Paused) Results(b);
        if (Paused) PauseGUI();
    }

    // Вступление: штамп места и времени, подсказка, затемнение с титрами операции
    void IntroOverlay(Battle b)
    {
        HudStyles();
        if (b.stamp != null && b.stampT > 0)
        {
            float age = Time.time - b.stampT;
            if (age < 9f)
            {
                float a = Mathf.Clamp01(age - 1.2f) * Mathf.Clamp01(9f - age);
                int chars = Mathf.Clamp(Mathf.FloorToInt((age - 1.2f) * 40f), 0, b.stamp.Length);
                Shadowed(new Rect(42, 92, 1400, 30), b.stamp.Substring(0, chars) + (chars < b.stamp.Length && Mathf.Repeat(age, 0.4f) < 0.2f ? "▌" : ""), hudM, new Color(0.95f, 0.95f, 0.9f, a));
            }
        }
        if (b.intro && b.fade < 0.5f)
            Label(new Rect(W - 440, 24, 400, 24), "[Enter] — пропустить брифинг и вылететь", new GUIStyle(hudS) { alignment = TextAnchor.MiddleRight, fontSize = 14 }, new Color(1, 1, 1, 0.45f));
        if (b.fade <= 0.001f && b.cardTitle != null)
        {
            // титры поверх сцены на взлёте: кинематографичные полосы
            float age = Time.time - b.cardT, a = Mathf.Clamp01(age / 0.8f) * Mathf.Clamp01((4.5f - age) / 0.8f);
            Rect(new Rect(0, 0, W, 90 * a), new Color(0, 0, 0, 0.85f));
            Rect(new Rect(0, H - 90 * a, W, 90 * a), new Color(0, 0, 0, 0.85f));
            Shadowed(new Rect(0, H / 2 - 50, W, 60), b.cardTitle, new GUIStyle(h1) { alignment = TextAnchor.MiddleCenter, fontSize = 46 }, new Color(1f, 1f, 1f, a));
            Rect(new Rect(W / 2 - 160, H / 2 + 16, 320, 2), new Color(1f, 0.78f, 0.3f, a));
            Label(new Rect(0, H / 2 + 26, W, 30), b.cardSub, new GUIStyle(hudM) { alignment = TextAnchor.MiddleCenter }, new Color(0.85f, 0.85f, 0.8f, a));
        }
        if (b.fade > 0.001f)
        {
            Rect(new Rect(0, 0, W, H), new Color(0, 0, 0, b.fade));
            if (b.cardTitle != null)
            {
                Shadowed(new Rect(0, H / 2 - 50, W, 60), b.cardTitle, new GUIStyle(h1) { alignment = TextAnchor.MiddleCenter, fontSize = 46 }, new Color(1f, 1f, 1f, b.fade));
                Rect(new Rect(W / 2 - 160, H / 2 + 16, 320, 2), new Color(1f, 0.78f, 0.3f, b.fade));
                Label(new Rect(0, H / 2 + 26, W, 30), b.cardSub, new GUIStyle(hudM) { alignment = TextAnchor.MiddleCenter }, new Color(0.85f, 0.85f, 0.8f, b.fade));
            }
        }
    }

    void TeamBar(Battle b)
    {
        int f = b.AliveCount(Team.Foundation), c = b.AliveCount(Team.Chaos), s = b.AliveCount(Team.SCP);
        float w = 560, x = W / 2 - w / 2;
        Rect(new Rect(x, 10, w, 46), new Color(0, 0, 0, 0.55f));
        Label(new Rect(x, 10, w / 3, 46), "ФОНД  " + f, center, Battle.TeamColor(Team.Foundation));
        Label(new Rect(x + w / 3, 10, w / 3, 46), "ХАОС  " + c, center, Battle.TeamColor(Team.Chaos));
        Label(new Rect(x + 2 * w / 3, 10, w / 3, 46), "SCP  " + s, center, Battle.TeamColor(Team.SCP));
        float tm = Time.time - b.startTime;
        Label(new Rect(x, 56, w, 24), string.Format("{0:00}:{1:00}", (int)(tm / 60), (int)(tm % 60)) + (Time.timeScale < 0.99f && !Paused ? "   ◷ ЗАМЕДЛЕНИЕ" : ""), new GUIStyle(small) { alignment = TextAnchor.MiddleCenter }, new Color(0.8f, 0.8f, 0.8f));
    }

    // Приказ отряда игрока, маркер цели и захват SCP
    void Orders(Battle b, PlayerController pc)
    {
        Team team = Team.Foundation;
        SquadRt sq = pc != null && !pc.dead ? b.SquadOf(pc.squad) : null;
        if (sq != null)
        {
            HudStyles();
            Rect(new Rect(30, 26, 3, 44), new Color(1f, 0.78f, 0.3f, 0.8f));
            Label(new Rect(42, 24, 620, 20), "ЗАДАЧА ОТРЯДА", new GUIStyle(hudS) { fontSize = 13 }, new Color(1f, 0.78f, 0.3f, 0.85f));
            Label(new Rect(42, 44, 620, 28), b.intro ? "Брифинг на передовой базе — слушать командира группы" : sq.orderText, hudM, new Color(0.95f, 0.95f, 0.92f, 0.9f));
        }
        // маркер цели
        if ((pc != null && !pc.dead) || SpectatorCam.Active)
            if (b.Objective(team, out var pos, out var name))
            {
                Vector3 wp = pos + Vector3.up * 2.5f;
                Vector3 sp = Cam.WorldToScreenPoint(wp);
                float sc = Screen.height / 1080f;
                bool behind = sp.z < 0;
                Vector2 p = new Vector2(sp.x / sc, H - sp.y / sc);
                if (behind) p = new Vector2(W - p.x, H - 40);
                p.x = Mathf.Clamp(p.x, 40, W - 40); p.y = Mathf.Clamp(p.y, 90, H - 60);
                float dist = Vector3.Distance(Cam.transform.position, pos);
                // маркер тает, когда смотришь прямо на него или целишься
                float centered = Vector2.Distance(p, new Vector2(W / 2, H / 2));
                float ma = Mathf.Lerp(0.25f, 0.85f, Mathf.InverseLerp(60f, 220f, centered)) * (Input.GetMouseButton(1) ? 0.35f : 1f);
                var m = GUI.matrix;
                RotateLocal(45, p);
                Color oc = new Color(1f, 0.78f, 0.3f, ma);
                Rect(new Rect(p.x - 6, p.y - 6, 12, 2), oc); Rect(new Rect(p.x - 6, p.y + 4, 12, 2), oc);
                Rect(new Rect(p.x - 6, p.y - 6, 2, 12), oc); Rect(new Rect(p.x + 4, p.y - 6, 2, 12), oc);
                GUI.matrix = m;
                HudStyles();
                Shadowed(new Rect(p.x - 150, p.y + 10, 300, 20), name.ToUpper() + "  ·  " + Mathf.RoundToInt(dist) + " м", new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter, fontSize = 13 }, oc);
            }
        // захват ослабленного SCP
        var ct = b.captureTarget;
        if (ct != null)
        {
            float x = W / 2 - 260, y = 134;
            Rect(new Rect(x, y, 520, 64), new Color(0, 0, 0, 0.6f));
            Label(new Rect(x, y + 2, 520, 24), "ЗАХВАТ " + ct.displayName + "  (держите зону 10 м вокруг объекта)", new GUIStyle(small) { alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold }, new Color(1f, 0.85f, 0.4f));
            Rect(new Rect(x + 10, y + 30, 500, 10), new Color(0.15f, 0.15f, 0.15f));
            Rect(new Rect(x + 10, y + 30, 500 * Mathf.Clamp01(ct.capture[0]), 10), Battle.TeamColor(Team.Foundation));
            Rect(new Rect(x + 10, y + 46, 500, 10), new Color(0.15f, 0.15f, 0.15f));
            Rect(new Rect(x + 10, y + 46, 500 * Mathf.Clamp01(ct.capture[1]), 10), Battle.TeamColor(Team.Chaos));
            var li = LoreItem.Find(ct.kind);
            if (li != null && !ct.itemApplied)
            {
                string who = li.carrier == null ? "лежит на земле — подберите" : li.carrier.isPlayer ? "у вас — подойдите вплотную" : "несёт " + (li.carrier is Soldier cs ? cs.CallSign : li.carrier.displayName);
                Rect(new Rect(x, y + 66, 520, 28), new Color(0, 0, 0, 0.6f));
                Label(new Rect(x, y + 68, 520, 24), "Нужен предмет: «" + li.def.name + "» (" + who + ")" + (li.applyK > 0.01f ? "  " + Mathf.RoundToInt(li.applyK * 100) + "%" : ""), new GUIStyle(small) { alignment = TextAnchor.MiddleCenter }, new Color(0.75f, 0.9f, 1f));
            }
        }
    }

    // Поворот вокруг точки в координатах уже масштабированного интерфейса
    // (GUIUtility.RotateAroundPivot берёт точку в пикселях экрана — при масштабе значок уезжал)
    static void RotateLocal(float angle, Vector2 p)
    {
        GUI.matrix = GUI.matrix * Matrix4x4.TRS(p, Quaternion.Euler(0, 0, angle), Vector3.one) * Matrix4x4.Translate(-p);
    }

    void Feed(Battle b)
    {
        float y = 70;
        foreach (var e in b.feed)
        {
            float a = Mathf.Clamp01(8f - (Time.unscaledTime - e.time));
            var sz = feedSt.CalcSize(new GUIContent(e.text));
            Rect(new Rect(W - sz.x - 40, y, sz.x + 20, 30), new Color(e.player ? 0.4f : 0f, 0, 0, 0.5f * a));
            Label(new Rect(W - sz.x - 30, y, sz.x, 30), e.text, feedSt, new Color(e.color.r, e.color.g, e.color.b, a));
            y += 34;
        }
    }

    // Переговоры и события — субтитрами внизу, как радиообмен
    void Messages(Battle b)
    {
        HudStyles();
        float y = H - 250;
        for (int i = b.messages.Count - 1; i >= 0 && i >= b.messages.Count - 4; i--)
        {
            var m = b.messages[i];
            float age = Time.unscaledTime - m.time;
            float a = Mathf.Clamp01(m.life - age) * Mathf.Clamp01(age * 6f);
            string text = m.text;
            string who = null;
            int c = text.IndexOf(": ");
            if (c > 0 && c < 40) { who = text.Substring(0, c); text = text.Substring(c + 2); }
            var size = hudSub.CalcHeight(new GUIContent(text), 900);
            float w = 960, x = W / 2 - w / 2;
            Rect(new Rect(x, y - size - 6, w, size + (who != null ? 30 : 10)), new Color(0, 0, 0, 0.42f * a));
            if (who != null)
            {
                Label(new Rect(x + 10, y - size - 4, w - 20, 22), "◉ " + who.ToUpper(), new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter, fontSize = 14 }, new Color(m.color.r, m.color.g, m.color.b, a));
                Label(new Rect(x + 30, y - size + 16, w - 60, size), text, hudSub, new Color(1, 1, 1, a));
            }
            else Label(new Rect(x + 30, y - size - 2, w - 60, size), text, hudSub, new Color(m.color.r, m.color.g, m.color.b, a));
            y -= size + (who != null ? 40 : 20);
        }
    }

    // ---------------- HUD (реалистичный: без цифр патронов, без маркеров попаданий) ----------------
    GUIStyle hudS, hudM, hudL, hudXL, hudSub;
    Font fontHud, fontTitle;

    void HudStyles()
    {
        if (hudS != null) return;
        hudS = new GUIStyle { fontSize = 15, font = fontHud, alignment = TextAnchor.MiddleLeft };
        hudS.normal.textColor = Color.white;
        hudM = new GUIStyle(hudS) { fontSize = 19 };
        hudL = new GUIStyle(hudS) { fontSize = 26 };
        hudXL = new GUIStyle(hudS) { fontSize = 44, alignment = TextAnchor.MiddleCenter };
        hudSub = new GUIStyle(hudS) { fontSize = 21, alignment = TextAnchor.MiddleCenter, wordWrap = true };
    }

    static readonly Color HudWhite = new Color(0.92f, 0.94f, 0.9f, 0.92f), HudDim = new Color(0.75f, 0.78f, 0.74f, 0.6f), HudAmber = new Color(1f, 0.78f, 0.3f, 0.95f), HudRed = new Color(1f, 0.3f, 0.22f, 0.95f);

    void PlayerHUD(PlayerController pc)
    {
        HudStyles();
        // ранения, подавление, моргание
        float hpK = pc.unit.hp / pc.unit.maxHp;
        if (pc.hurt > 0.01f || hpK < 0.35f)
        {
            float low = hpK < 0.35f ? 0.22f + Mathf.Sin(Time.time * 4f) * 0.08f : 0f;
            Vignette(new Color(0.45f, 0f, 0f, Mathf.Clamp01(pc.hurt * 0.6f + low)));
        }
        if (pc.suppress > 0.01f) Vignette(new Color(0f, 0f, 0f, pc.suppress * 0.55f));
        // кровь на экране: стекает и подсыхает за несколько секунд
        pc.screenBlood.RemoveAll(v => Time.time - v.w > 5f);
        foreach (var sb in pc.screenBlood)
        {
            float age = Time.time - sb.w;
            float a = Mathf.Clamp01(1f - age / 5f) * 0.85f;
            float sz = sb.z * H;
            var old = GUI.color;
            GUI.color = new Color(0.55f, 0.03f, 0.02f, a);
            var tx = Mats.SplatterTex(Mathf.FloorToInt(sb.x * 97f));
            GUI.DrawTexture(new Rect(sb.x * W - sz / 2, sb.y * H - sz / 2 + age * 12f, sz, sz), tx);
            GUI.color = old;
        }
        if (pc.Blinking) Rect(new Rect(0, 0, W, H), Color.black);

        var g = pc.Current;
        bool scoped = g != null && g.def.scope && Input.GetMouseButton(1) && !g.reloading;
        if (scoped) ScopeOverlay();
        else if (!pc.riding && !Input.GetMouseButton(1) && pc.fp != null && pc.fp.MagCheckW < 0.05f) Crosshair(pc);

        // направления урона — тусклые дуги
        foreach (var d in pc.dmgDirs)
        {
            float a = 1f - (Time.time - d.y) / 2f;
            var m = GUI.matrix;
            Vector2 cc = new Vector2(W / 2, H / 2);
            RotateLocal(d.x, cc);
            for (int i = -3; i <= 3; i++) Rect(new Rect(cc.x + i * 14 - 6, cc.y - 230 + Mathf.Abs(i) * Mathf.Abs(i) * 2.2f, 12, 5), new Color(0.85f, 0.1f, 0.05f, a * 0.6f * (1f - Mathf.Abs(i) / 4f)));
            GUI.matrix = m;
        }

        if (!pc.riding && !pc.safe) Compass(pc);
        // выносливость и дыхание — тонкие полосы внизу по центру, только когда не полные
        float st = pc.stamina, br = pc.breath;
        if (st < 0.99f || br < 0.99f)
        {
            float bw = 220f, bx = W / 2 - bw / 2, by = H - 46;
            Rect(new Rect(bx, by, bw, 4), new Color(0, 0, 0, 0.45f));
            Rect(new Rect(bx, by, bw * st, 4), st < 0.25f ? new Color(0.95f, 0.45f, 0.3f, 0.85f) : new Color(0.85f, 0.85f, 0.8f, 0.7f));
            if (br < 0.99f)
            {
                Rect(new Rect(bx + 30, by + 7, bw - 60, 3), new Color(0, 0, 0, 0.45f));
                Rect(new Rect(bx + 30, by + 7, (bw - 60) * br, 3), new Color(0.55f, 0.8f, 1f, 0.75f));
            }
        }
        SquadRoster(pc, hpK);
        WeaponPanel(pc, g);
        MagCheckLabel(pc, g);

        if (Scp096.PlayerExposure > 0.05f)
        {
            float e = Scp096.PlayerExposure;
            Shadowed(new Rect(0, H * 0.64f, W, 34), "НЕ СМОТРИ НА ЕГО ЛИЦО", hudSub, new Color(1f, 0.25f, 0.2f, 0.5f + 0.5f * Mathf.Sin(Time.time * 12f)));
            Rect(new Rect(W / 2 - 120, H * 0.64f + 38, 240, 3), new Color(0, 0, 0, 0.5f));
            Rect(new Rect(W / 2 - 120, H * 0.64f + 38, 240 * e, 3), new Color(1f, 0.2f, 0.15f));
        }
    }

    // Компас как в современных шутерах: шкала, стороны света, цель
    void Compass(PlayerController pc)
    {
        float cw = 640, cx = W / 2, y = 22;
        float yaw = Cam.transform.eulerAngles.y;
        float pxPerDeg = cw / 110f;
        Rect(new Rect(cx - cw / 2, y + 26, cw, 1), new Color(1, 1, 1, 0.18f));
        string[] card = { "С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ" };
        for (int d = 0; d < 360; d += 5)
        {
            float delta = Mathf.DeltaAngle(yaw, d);
            if (Mathf.Abs(delta) > 55f) continue;
            float x = cx + delta * pxPerDeg;
            float fade = 1f - Mathf.Abs(delta) / 55f;
            bool major = d % 45 == 0, mid = d % 15 == 0;
            Rect(new Rect(x - 0.5f, y + (major ? 14 : mid ? 18 : 21), 1, major ? 12 : mid ? 8 : 5), new Color(1, 1, 1, 0.7f * fade));
            if (major) Label(new Rect(x - 30, y - 8, 60, 24), card[d / 45], new GUIStyle(hudM) { alignment = TextAnchor.MiddleCenter }, new Color(1, 1, 1, 0.95f * fade));
            else if (mid) Label(new Rect(x - 30, y - 4, 60, 20), d.ToString(), new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter, fontSize = 12 }, new Color(1, 1, 1, 0.5f * fade));
        }
        // текущий курс
        Rect(new Rect(cx - 1, y + 28, 2, 8), HudAmber);
        Label(new Rect(cx - 40, y + 34, 80, 22), Mathf.RoundToInt(Mathf.Repeat(yaw, 360f)).ToString("000"), new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter }, HudWhite);
        // цель операции на компасе
        var b = Battle.I;
        if (b != null && b.Objective(Team.Foundation, out var pos, out var name))
        {
            Vector3 to = pos - Cam.transform.position; to.y = 0;
            float bearing = Mathf.Atan2(to.x, to.z) * Mathf.Rad2Deg;
            float delta = Mathf.Clamp(Mathf.DeltaAngle(yaw, bearing), -55f, 55f);
            float x = cx + delta * pxPerDeg;
            var m = GUI.matrix;
            RotateLocal(45, new Vector2(x, y + 20));
            Rect(new Rect(x - 5, y + 15, 10, 10), HudAmber);
            GUI.matrix = m;
            Label(new Rect(x - 60, y + 50, 120, 20), Mathf.RoundToInt(to.magnitude) + " м", new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter, fontSize = 13 }, HudAmber);
        }
        // свои отряды — синие засечки
        foreach (var u in Unit.All)
        {
            if (!(u is Soldier so) || !so.alive || so.team != Team.Foundation || so.isPlayer || so.squadRt == null || so.squadRt.Leader != so) continue;
            Vector3 to = so.transform.position - Cam.transform.position; to.y = 0;
            if (to.magnitude < 8f) continue;
            float delta = Mathf.DeltaAngle(yaw, Mathf.Atan2(to.x, to.z) * Mathf.Rad2Deg);
            if (Mathf.Abs(delta) > 55f) continue;
            Rect(new Rect(cx + delta * pxPerDeg - 2, y + 22, 4, 4), new Color(0.4f, 0.7f, 1f, 0.8f));
        }
    }

    // Состав отряда (как в тактических шутерах): позывные и состояние, своё состояние без цифр
    void SquadRoster(PlayerController pc, float hpK)
    {
        float x = 34, y = H - 60;
        var b = Battle.I;
        SquadRt sq = b != null ? b.SquadOf(pc.squad) : null;
        // своё состояние
        string st = hpK > 0.75f ? "В НОРМЕ" : hpK > 0.45f ? "РАНЕН" : hpK > 0.2f ? "ТЯЖЕЛО РАНЕН" : "КРИТИЧЕСКОЕ";
        Color sc = hpK > 0.75f ? HudWhite : hpK > 0.45f ? HudAmber : HudRed;
        Label(new Rect(x, y, 300, 26), "ВЫ  ·  " + st + (pc.crouching ? "  ·  ПРИСЕД" : ""), hudM, sc);
        // тонкая сегментированная полоса
        for (int i = 0; i < 10; i++)
        {
            float k = Mathf.Clamp01(hpK * 10f - i);
            Rect(new Rect(x + i * 25, y + 28, 22, 4), new Color(1, 1, 1, 0.15f));
            if (k > 0) Rect(new Rect(x + i * 25, y + 28, 22 * k, 4), sc);
        }
        if (sq == null) return;
        y -= 34;
        int shown = 0;
        for (int i = sq.members.Count - 1; i >= 0 && shown < 9; i--)
        {
            var m = sq.members[i];
            if (m == null) continue;
            shown++;
            bool alive = m.alive && !m.zombie;
            float k = alive ? m.hp / m.maxHp : 0f;
            Color c = !alive ? new Color(0.5f, 0.5f, 0.5f, 0.45f) : k > 0.6f ? new Color(0.55f, 0.85f, 0.55f, 0.85f) : k > 0.3f ? HudAmber : HudRed;
            Rect(new Rect(x, y + 9, 8, 8), c);
            string call = sq.def.name.Split(' ')[0].Split('-')[0] + "-" + (m.index + 1) + (m == sq.Leader ? "  (командир)" : "");
            Label(new Rect(x + 16, y, 300, 26), call + (alive ? "" : "  — погиб"), hudS, alive ? HudDim : new Color(0.6f, 0.6f, 0.6f, 0.4f));
            y -= 24;
        }
        Label(new Rect(x, y - 2, 400, 26), sq.def.name.ToUpper() + "  " + sq.def.nick, hudS, Color.Lerp(sq.def.look.accent, Color.white, 0.5f));
    }

    // Оружие: название, режим огня, запасные магазины (без счётчика патронов)
    void WeaponPanel(PlayerController pc, Gun g)
    {
        if (g == null) return;
        float r = W - 34, y = H - 60;
        var right = new GUIStyle(hudL) { alignment = TextAnchor.MiddleRight };
        Label(new Rect(r - 500, y - 30, 500, 34), g.def.name.ToUpper(), right, HudWhite);
        string mode = g.def.rocket ? "ОДИНОЧН. · ВЫСТРЕЛ" : g.def.kind == WeaponKind.Shotgun ? "ПОМПА" : g.def.auto && !g.semi ? "АВТО" : "ОДИНОЧН.";
        if (g.reloading) mode = "ПЕРЕЗАРЯДКА";
        else if (g.ammo == 0) mode = "ПУСТО";
        Label(new Rect(r - 500, y + 2, 500, 22), mode, new GUIStyle(hudS) { alignment = TextAnchor.MiddleRight }, g.ammo == 0 && !g.reloading ? HudRed : HudDim);
        // магазины в подсумках: силуэты, неполные — частично
        float mx = r;
        if (g.mags != null)
            for (int i = g.mags.Count - 1; i >= 0; i--)
            {
                mx -= 12;
                float k = g.mags[i] / (float)g.def.mag;
                Rect(new Rect(mx, y + 28, 8, 20), new Color(1, 1, 1, 0.15f));
                Rect(new Rect(mx, y + 28 + 20 * (1 - k), 8, 20 * k), HudWhite);
            }
        else
        {
            string res = g.def.kind == WeaponKind.Shotgun ? "патронов в запасе: " + (g.reserveMags < 99 ? (g.reserveMags * g.def.mag).ToString() : "∞") : "запас: " + g.reserveMags;
            Label(new Rect(r - 300, y + 26, 300, 22), res, new GUIStyle(hudS) { alignment = TextAnchor.MiddleRight }, HudDim);
            mx = r - 300;
        }
        // гранаты и аптечки
        Label(new Rect(r - 520, y + 26, 300, 22), "ГРАНАТЫ " + pc.grenades + "   ·   АПТЕЧКИ " + pc.medkits, new GUIStyle(hudS) { alignment = TextAnchor.MiddleRight, fontSize = 13 }, HudDim);
        // слоты оружия
        float sx = r;
        for (int i = 2; i >= 0; i--)
        {
            var gi = pc.GunAt(i);
            if (gi == null) continue;
            bool cur = pc.CurIndex == i;
            string n = (i + 1) + " " + Short(gi.def.name);
            var sst = new GUIStyle(hudS) { alignment = TextAnchor.MiddleRight, fontSize = 13 };
            float w = sst.CalcSize(new GUIContent(n)).x + 12;
            sx -= w;
            Label(new Rect(sx, y - 56, w, 20), n, sst, cur ? HudAmber : new Color(1, 1, 1, 0.35f));
        }
    }

    // Проверка магазина: подпись у вынутого магазина
    void MagCheckLabel(PlayerController pc, Gun g)
    {
        if (pc.fp == null || g == null || pc.fp.MagCheckW < 0.85f) return;
        float sc = Screen.height / 1080f;
        Vector2 p = pc.fp.MagLabelScreen / sc;
        p.x = Mathf.Clamp(p.x, 120, W - 120); p.y = Mathf.Clamp(p.y, 120, H - 160);
        float a = Mathf.InverseLerp(0.85f, 1f, pc.fp.MagCheckW);
        string n = g.ammo.ToString();
        string sub = g.Shells ? "патронов в трубке" : g.ammo == 0 ? "магазин пуст" : g.ammo == g.def.mag ? "полный магазин" : "патронов в магазине";
        Rect(new Rect(p.x + 40, p.y - 34, 2, 68), new Color(1, 1, 1, 0.5f * a));
        Shadowed(new Rect(p.x + 52, p.y - 40, 200, 56), n, new GUIStyle(hudXL) { alignment = TextAnchor.MiddleLeft }, new Color(1, 1, 1, a));
        Shadowed(new Rect(p.x + 54, p.y + 10, 260, 24), sub + (g.Shells ? "" : "  · ещё " + (g.mags != null ? g.mags.Count : g.reserveMags) + " маг."), hudS, new Color(0.85f, 0.88f, 0.85f, a));
    }

    static string Short(string s) => s.Length > 10 ? s.Substring(0, 10) : s;

    // Без большого перекрестия: еле заметная точка, тает в движении — целиться нужно прицелом
    void Crosshair(PlayerController pc)
    {
        float a = Mathf.Clamp01(0.55f - pc.spreadNow * 0.6f);
        if (a <= 0.02f) return;
        Vector2 c = new Vector2(W / 2, H / 2);
        Rect(new Rect(c.x - 2, c.y - 2, 4, 4), new Color(0, 0, 0, a * 0.5f));
        Rect(new Rect(c.x - 1, c.y - 1, 2, 2), new Color(1, 1, 1, a));
    }

    void ScopeOverlay()
    {
        float r = H * 0.46f;
        Vector2 c = new Vector2(W / 2, H / 2);
        Rect(new Rect(0, 0, c.x - r, H), Color.black);
        Rect(new Rect(c.x + r, 0, W - c.x - r, H), Color.black);
        // скруглённые края прицела
        for (int i = 0; i < 90; i++)
        {
            float y0 = -r + i * (2 * r / 90f);
            float half = Mathf.Sqrt(Mathf.Max(0, r * r - y0 * y0));
            Rect(new Rect(c.x - r, c.y + y0, r - half, 2 * r / 90f + 1), Color.black);
            Rect(new Rect(c.x + half, c.y + y0, r - half, 2 * r / 90f + 1), Color.black);
        }
        Rect(new Rect(c.x - r, c.y - 1, 2 * r, 2), new Color(0, 0, 0, 0.9f));
        Rect(new Rect(c.x - 1, c.y - r, 2, 2 * r), new Color(0, 0, 0, 0.9f));
        Rect(new Rect(c.x - 2, c.y - 2, 4, 4), new Color(1f, 0.1f, 0.1f));
        for (int i = 1; i <= 4; i++) Rect(new Rect(c.x - 8, c.y + i * 30, 16, 2), new Color(0, 0, 0, 0.9f));
    }

    void Vignette(Color c)
    {
        float b = 160;
        for (int i = 0; i < 8; i++)
        {
            float a = c.a * (1f - i / 8f);
            float o = i * b / 8f;
            Color cc = new Color(c.r, c.g, c.b, a * 0.35f);
            Rect(new Rect(0, 0, W, o + 20), cc);
            Rect(new Rect(0, H - o - 20, W, o + 20), cc);
            Rect(new Rect(0, 0, o + 20, H), cc);
            Rect(new Rect(W - o - 20, 0, o + 20, H), cc);
        }
    }

    void DeathHUD(PlayerController pc)
    {
        float t = Time.time - pc.deathTime;
        Rect(new Rect(0, 0, W, H), new Color(0.3f, 0, 0, Mathf.Clamp01(0.5f - t * 0.1f)));
        Shadowed(new Rect(0, H * 0.3f, W, 80), "ВЫ ПОГИБЛИ", new GUIStyle(title) { alignment = TextAnchor.MiddleCenter, fontSize = 70 }, new Color(1f, 0.25f, 0.2f));
        var killer = pc.unit.lastAttacker;
        if (killer != null) Label(new Rect(0, H * 0.3f + 80, W, 40), "Убийца: " + killer.displayName, center, new Color(0.9f, 0.9f, 0.9f));
        if (t > 1.5f)
        {
            int alive = 0;
            foreach (var u in Unit.All) if (u is Soldier s && s.alive && s.team == Team.Foundation && !s.zombie && s.state == Soldier.State.Combat) alive++;
            Shadowed(new Rect(0, H * 0.62f, W, 40), alive > 0 ? "[1] или ЛКМ — взять под контроль бойца Фонда (живых: " + alive + ")" : "Живых бойцов Фонда не осталось", msgSt, Color.white);
            Shadowed(new Rect(0, H * 0.62f + 46, W, 40), "[2] — наблюдать за боем      [Esc] — меню", msgSt, new Color(0.8f, 0.8f, 0.8f));
        }
    }

    void SpectatorHUD()
    {
        var sp = SpectatorCam.I;
        Rect(new Rect(20, H - 60, 1200, 40), new Color(0, 0, 0, 0.45f));
        Label(new Rect(34, H - 56, 1180, 34), "НАБЛЮДАТЕЛЬ   WASD/Q/E — полёт (Shift — быстро)   Tab — следить за бойцом   Пробел — свободно   1 — вселиться в бойца Фонда   T — замедление", small, Color.white);
        if (sp != null && sp.follow != null)
        {
            var u = sp.follow;
            Shadowed(new Rect(0, H - 130, W, 40), u.displayName + (u.squad != null ? " " + u.squad.nick : "") + "   " + (u.alive ? Mathf.CeilToInt(u.hp) + " HP" : "погиб") + "   убийств: " + u.kills, msgSt, Battle.TeamColor(u.team));
        }
    }

    void Results(Battle b)
    {
        float w = 760, h = b.debrief != null ? 464 : 420, x = W / 2 - w / 2, y = H / 2 - h / 2 - 40;
        if (!Paused && PlayerController.I != null && !PlayerController.I.dead)
        {
            // во время игры победа показывается баннером, не мешая
            Shadowed(new Rect(0, 200, W, 80), b.winnerText, new GUIStyle(title) { alignment = TextAnchor.MiddleCenter, fontSize = 60 }, b.winnerColor);
            Label(new Rect(0, 270, W, 30), "Esc — меню операции", center, Color.white);
            return;
        }
        Rect(new Rect(x, y, w, h), new Color(0.02f, 0.02f, 0.03f, 0.88f));
        Rect(new Rect(x, y, w, 6), b.winnerColor);
        Shadowed(new Rect(x, y + 20, w, 80), b.winnerText, new GUIStyle(title) { alignment = TextAnchor.MiddleCenter, fontSize = 54 }, b.winnerColor);
        float yy = y + 120;
        for (int i = 0; i < 3; i++)
        {
            Team t = (Team)i;
            Label(new Rect(x + 60, yy, w - 120, 32), Battle.TeamName(t) + ":  уничтожено врагов " + b.teamKills[i] + "   потери " + b.teamLosses[i] + "   в строю " + b.AliveCount(t), body, Battle.TeamColor(t));
            yy += 36;
        }
        if (b.debrief != null)
        {
            Label(new Rect(x + 60, yy + 2, w - 120, 50), b.debrief, small, new Color(0.9f, 0.85f, 0.7f));
            yy += 44;
        }
        float tm = Time.time - b.startTime;
        Label(new Rect(x + 60, yy + 6, w - 120, 30), "Длительность боя: " + string.Format("{0:00}:{1:00}", (int)(tm / 60), (int)(tm % 60)), body, Color.white);
        yy += 60;
        if (GUI.Button(new Rect(x + 40, yy, 220, 54), "Ещё раз", btn)) { var c = MakeConfig(); if (lastCfg != null) { lastCfg.seed = Random.Range(1, 99999); c = lastCfg; } StartBattle(c); }
        if (GUI.Button(new Rect(x + 270, yy, 220, 54), b.debrief != null ? "Другая операция" : "Изменить отряды", btn)) { ShowMenu(); screen = b.debrief != null ? Scr.Ops : Scr.Setup; }
        if (GUI.Button(new Rect(x + 500, yy, 220, 54), "Главное меню", btn)) ShowMenu();
        if (GUI.Button(new Rect(x + 270, yy + 64, 220, 44), "Наблюдать", btn)) { Paused = false; if (PlayerController.I != null) Spectate(); else if (!SpectatorCam.Active) SpectatorCam.Activate(Cam.transform.position, Cam.transform.rotation); }
    }

    void PauseGUI()
    {
        Rect(new Rect(0, 0, W, H), new Color(0, 0, 0, 0.6f));
        float x = W / 2 - 420;
        Shadowed(new Rect(x, 60, 840, 60), "ПАУЗА", h1, Color.white);
        float y = 140;
        if (GUI.Button(new Rect(x, y, 300, 54), "Продолжить", btn)) Paused = false; y += 64;
        if (Battle.I != null && Battle.I.PlayerCanLaunch)
        {
            if (GUI.Button(new Rect(x, y, 300, 54), "Вылететь сейчас", btn)) { Battle.I.LaunchPlayerNow(); Paused = false; }
            y += 64;
        }
        if (GUI.Button(new Rect(x, y, 300, 54), "Начать заново", btn)) { var c = lastCfg; if (c != null) { c.seed = Random.Range(1, 99999); StartBattle(c); } }
        y += 64;
        if (GUI.Button(new Rect(x, y, 300, 54), "Изменить отряды", btn)) { ShowMenu(); screen = Scr.Setup; }
        y += 64;
        if (GUI.Button(new Rect(x, y, 300, 54), "Главное меню", btn)) ShowMenu();
        y += 64;
        if (GUI.Button(new Rect(x, y, 300, 54), "Выход из игры", btn)) Application.Quit();
        SettingsBody(x + 340, 140);
    }
}
