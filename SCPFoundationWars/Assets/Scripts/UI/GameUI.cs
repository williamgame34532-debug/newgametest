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
            case Scr.Battle: BattleGUI(); break;
        }
    }

    // ---------------- главное меню ----------------
    void MenuGUI()
    {
        Rect(new Rect(0, 0, 760, H), new Color(0, 0, 0, 0.55f));
        Rect(new Rect(760, 0, 6, H), new Color(0.85f, 0.6f, 0.1f, 0.9f));
        // знак Фонда
        DrawLogo(new Vector2(130, 190), 70);
        Shadowed(new Rect(220, 120, 600, 90), "SCP", title, Color.white);
        Shadowed(new Rect(222, 200, 600, 50), "ВОЙНА ЗА ФОНД", h1, new Color(0.9f, 0.75f, 0.3f));
        Label(new Rect(60, 280, 660, 80), "Собери до пяти отрядов МОГ, выбери Повстанцев Хаоса и SCP-объекты — и высаживайся с вертолёта в бой от первого лица.", body, new Color(0.85f, 0.85f, 0.85f));
        float y = 400;
        if (GUI.Button(new Rect(60, y, 520, 72), "НОВАЯ ОПЕРАЦИЯ", btnBig)) { Sfx.Play2D("ui"); screen = Scr.Setup; }
        y += 92;
        if (lastCfg != null && GUI.Button(new Rect(60, y, 520, 56), "Повторить последнюю", btn)) { Sfx.Play2D("ui"); var c = lastCfg; c.seed = Random.Range(1, 99999); StartBattle(c); }
        if (lastCfg != null) y += 72;
        if (GUI.Button(new Rect(60, y, 520, 56), "Быстрый бой (случайный)", btn)) { Sfx.Play2D("ui"); Randomize(); StartBattle(MakeConfig()); }
        y += 72;
        if (GUI.Button(new Rect(60, y, 520, 56), "Настройки", btn)) { Sfx.Play2D("ui"); settingsReturn = Scr.Menu; screen = Scr.Settings; }
        y += 72;
        if (GUI.Button(new Rect(60, y, 520, 56), "Выход", btn)) Application.Quit();
        Label(new Rect(60, H - 70, 700, 40), "ОБЕСПЕЧИТЬ. УДЕРЖАТЬ. СОХРАНИТЬ.", small, new Color(0.6f, 0.6f, 0.6f));
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
        bx += 260;
        if (GUI.Button(new Rect(bx, by + 26, 140, 44), "Случайно", btn)) Randomize();
        if (GUI.Button(new Rect(bx + 150, by + 26, 140, 44), "Очистить", btn)) { fPick.Clear(); cPick.Clear(); sPick.Clear(); fOrder.Clear(); }

        bool okF = fOrder.Count > 0, okE = cPick.Count > 0 || sPick.Count > 0;
        string why = !okF ? "Выбери хотя бы один отряд Фонда" : !okE ? "Выбери противников: Хаос и/или SCP" : "";
        if (why != "") Label(new Rect(W - 520, by + 80, 480, 30), why, small, new Color(1f, 0.5f, 0.4f));
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
        y += 70;
        Label(new Rect(x, y, 800, 260),
            "Управление:\n" +
            "WASD — движение, Shift — бег, Ctrl/C — присесть, Пробел — прыжок\n" +
            "ЛКМ — огонь, ПКМ — прицел, R — перезарядка, 1/2/3 или колесо — оружие\n" +
            "G — граната, H — аптечка, F — фонарик, T — замедление времени, Esc — пауза\n" +
            "После смерти: 1/ЛКМ — взять под контроль бойца Фонда, 2 — наблюдать\n" +
            "Наблюдатель: WASD/Q/E — полёт, Tab — следить за бойцом, Пробел — свободная камера, 1 — вселиться",
            body, new Color(0.75f, 0.78f, 0.8f));
    }

    // ---------------- бой ----------------
    void BattleGUI()
    {
        var b = Battle.I;
        if (b == null) return;
        var pc = PlayerController.I;
        if (pc != null && !pc.dead) PlayerHUD(pc);
        else if (pc != null && pc.dead) DeathHUD(pc);
        else if (SpectatorCam.Active) SpectatorHUD();

        TeamBar(b);
        Feed(b);
        Messages(b);
        if (b.over && !Paused) Results(b);
        if (Paused) PauseGUI();
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

    void Messages(Battle b)
    {
        float y = 130;
        foreach (var m in b.messages)
        {
            float a = Mathf.Clamp01(5f - (Time.unscaledTime - m.time)) * Mathf.Clamp01((Time.unscaledTime - m.time) * 6f);
            Shadowed(new Rect(0, y, W, 40), m.text, msgSt, new Color(m.color.r, m.color.g, m.color.b, a));
            y += 42;
        }
    }

    void PlayerHUD(PlayerController pc)
    {
        // ранения, подавление, моргание
        if (pc.hurt > 0.01f || pc.unit.hp < pc.unit.maxHp * 0.3f)
        {
            float low = pc.unit.hp < pc.unit.maxHp * 0.3f ? 0.18f + Mathf.Sin(Time.time * 5f) * 0.08f : 0f;
            Vignette(new Color(0.6f, 0f, 0f, Mathf.Clamp01(pc.hurt * 0.55f + low)));
        }
        if (pc.suppress > 0.01f) Vignette(new Color(0f, 0f, 0f, pc.suppress * 0.45f));
        if (pc.Blinking) Rect(new Rect(0, 0, W, H), Color.black);

        var g = pc.Current;
        bool scoped = g != null && g.def.scope && Input.GetMouseButton(1) && !g.reloading;
        if (scoped) ScopeOverlay();
        else if (!pc.riding && !Input.GetMouseButton(1)) Crosshair(pc);

        // маркер попадания
        float hm = Time.time - pc.hitMarkT;
        if (hm < 0.25f)
        {
            Color c = pc.hitKill ? new Color(1f, 0.15f, 0.1f) : pc.hitHead ? new Color(1f, 0.85f, 0.2f) : Color.white;
            c.a = 1f - hm / 0.25f;
            float s = pc.hitKill ? 16 : 11;
            var m = GUI.matrix;
            Vector2 cc = new Vector2(W / 2, H / 2);
            for (int i = 0; i < 4; i++)
            {
                GUIUtility.RotateAroundPivot(45 + i * 90, cc);
                Rect(new Rect(cc.x - 1.5f, cc.y - s - 8, 3, s), c);
                GUI.matrix = m;
            }
        }
        // направления урона
        foreach (var d in pc.dmgDirs)
        {
            float a = 1f - (Time.time - d.y) / 2f;
            var m = GUI.matrix;
            Vector2 cc = new Vector2(W / 2, H / 2);
            GUIUtility.RotateAroundPivot(d.x, cc);
            Rect(new Rect(cc.x - 40, cc.y - 200, 80, 10), new Color(1f, 0.1f, 0.05f, a * 0.8f));
            GUI.matrix = m;
        }

        // здоровье
        float hpK = pc.unit.hp / pc.unit.maxHp;
        Rect(new Rect(30, H - 110, 380, 80), new Color(0, 0, 0, 0.5f));
        Label(new Rect(44, H - 106, 360, 26), pc.squad.name + " " + pc.squad.nick, small, Color.Lerp(pc.squad.look.accent, Color.white, 0.4f));
        Rect(new Rect(44, H - 76, 352, 20), new Color(0.2f, 0.2f, 0.2f, 0.9f));
        Rect(new Rect(44, H - 76, 352 * hpK, 20), Color.Lerp(new Color(0.9f, 0.15f, 0.1f), new Color(0.3f, 0.85f, 0.4f), hpK));
        Label(new Rect(44, H - 78, 352, 24), Mathf.CeilToInt(pc.unit.hp) + " / " + pc.unit.maxHp + "   броня " + Mathf.RoundToInt(pc.unit.armor * 100) + "%", new GUIStyle(small) { alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold }, Color.white);
        Label(new Rect(44, H - 54, 360, 24), "Гранаты [G]: " + pc.grenades + "    Аптечки [H]: " + pc.medkits + "    Убийств: " + pc.unit.kills, small, new Color(0.85f, 0.85f, 0.85f));

        // патроны
        if (g != null)
        {
            Rect(new Rect(W - 420, H - 140, 390, 110), new Color(0, 0, 0, 0.5f));
            Label(new Rect(W - 410, H - 136, 370, 28), g.def.name, h2, Color.white);
            string ammo = g.reloading ? "ПЕРЕЗАРЯДКА" : g.ammo.ToString();
            var st = new GUIStyle(ammoBig) { fontSize = g.reloading ? 30 : 52 };
            Label(new Rect(W - 420, H - 112, 270, 70), ammo, st, g.ammo == 0 && !g.reloading ? new Color(1f, 0.3f, 0.2f) : Color.white);
            Label(new Rect(W - 145, H - 82, 110, 40), "/ " + g.def.mag + (g.reserveMags < 99 ? "  ×" + g.reserveMags : ""), small, new Color(0.75f, 0.75f, 0.75f));
            if (g.reloading) Rect(new Rect(W - 410, H - 40, 370 * g.ReloadProgress, 5), new Color(0.9f, 0.7f, 0.2f));
            float sx = W - 410;
            for (int i = 0; i < 3; i++)
            {
                var gi = pc.GunAt(i);
                if (gi == null) continue;
                bool cur = pc.CurIndex == i;
                Rect(new Rect(sx, H - 180, 120, 34), cur ? new Color(0.85f, 0.6f, 0.1f, 0.9f) : new Color(0, 0, 0, 0.5f));
                Label(new Rect(sx, H - 180, 120, 34), (i + 1) + "  " + Short(gi.def.name), new GUIStyle(small) { alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold }, cur ? Color.black : Color.white);
                sx += 126;
            }
        }
        if (Battle.I != null && Battle.I.has173 && !pc.squad.blinkImmune)
            Label(new Rect(30, H - 150, 600, 30), "◉ SCP-173 на поле: не отводите взгляд, моргание неизбежно", small, new Color(1f, 0.6f, 0.4f));
        if (pc.riding) Shadowed(new Rect(0, H * 0.72f, W, 40), "Вертолёт на подлёте к зоне высадки…", msgSt, new Color(1f, 0.9f, 0.6f));
    }

    static string Short(string s) => s.Length > 10 ? s.Substring(0, 10) : s;

    void Crosshair(PlayerController pc)
    {
        float gap = 8 + pc.spreadNow * 12f;
        Vector2 c = new Vector2(W / 2, H / 2);
        Color col = new Color(1, 1, 1, 0.85f);
        Rect(new Rect(c.x - 1, c.y - gap - 10, 2, 10), col);
        Rect(new Rect(c.x - 1, c.y + gap, 2, 10), col);
        Rect(new Rect(c.x - gap - 10, c.y - 1, 10, 2), col);
        Rect(new Rect(c.x + gap, c.y - 1, 10, 2), col);
        Rect(new Rect(c.x - 1, c.y - 1, 2, 2), col);
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
        float w = 760, h = 420, x = W / 2 - w / 2, y = H / 2 - h / 2 - 40;
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
        float tm = Time.time - b.startTime;
        Label(new Rect(x + 60, yy + 6, w - 120, 30), "Длительность боя: " + string.Format("{0:00}:{1:00}", (int)(tm / 60), (int)(tm % 60)), body, Color.white);
        yy += 60;
        if (GUI.Button(new Rect(x + 40, yy, 220, 54), "Ещё раз", btn)) { var c = MakeConfig(); if (lastCfg != null) { lastCfg.seed = Random.Range(1, 99999); c = lastCfg; } StartBattle(c); }
        if (GUI.Button(new Rect(x + 270, yy, 220, 54), "Изменить отряды", btn)) { ShowMenu(); screen = Scr.Setup; }
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
