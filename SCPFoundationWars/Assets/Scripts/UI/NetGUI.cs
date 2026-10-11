using UnityEngine;

// Экран сетевой игры: создать лобби (Steam — для друзей, или по IP), подключиться, выбрать сторону;
// хост выбирает режим: «Песочница» (свои силы, игроки за одну или разные стороны) или «Миссия» (кооператив).
public partial class Game
{
    string joinAddr;
    public bool NetHosting => Net.IsHost && !Net.InGame;

    public void ShowNetLobby()
    {
        if (screen == Scr.Battle) ShowMenu();
        screen = Scr.Net;
    }

    void NetGUI()
    {
        MenuStyles();
        GUI.DrawTexture(new Rect(0, 0, 1300, H), gradTex);
        Shadowed(new Rect(64, 60, 900, 60), "СЕТЕВАЯ ИГРА", h1, new Color(1f, 0.78f, 0.32f));
        Label(new Rect(64, 118, 1100, 26), "Хост ведёт бой (ИИ, SCP, урон); друзья подключаются к нему. Steam — по приглашению, без открытия портов.", small, new Color(0.75f, 0.78f, 0.8f));
        float x = 64, y = 170;
        // ник
        Label(new Rect(x, y, 200, 30), "Ваш позывной:", body, Color.white);
        string nick = GUI.TextField(new Rect(x + 200, y, 300, 32), Net.Nick, 20, field);
        if (nick != Net.Nick && nick.Trim().Length > 0) Net.Nick = nick;
        y += 56;

        if (!Net.Active)
        {
            SteamNet.Init();
            if (MenuButton(new Rect(x, y, 560, 64), "Создать лобби Steam", SteamNet.Ready ? "Друзья заходят по приглашению (Shift+Tab → Пригласить)" : (SteamNet.Error ?? "Steam недоступен"), true))
            { string err = Net.HostGame(true); if (err != null) Net.Status = err; }
            y += 78;
            if (MenuButton(new Rect(x, y, 560, 58), "Создать по IP", "Порт " + UdpTransport.DefaultPort + " (UDP). Подойдёт Radmin VPN / Hamachi / ZeroTier"))
            { string err = Net.HostGame(false); if (err != null) Net.Status = err; }
            y += 76;
            if (joinAddr == null) joinAddr = PlayerPrefs.GetString("joinAddr", "127.0.0.1");
            Label(new Rect(x, y, 200, 30), "Адрес хоста:", body, Color.white);
            joinAddr = GUI.TextField(new Rect(x + 200, y, 300, 32), joinAddr, 64, field);
            if (GUI.Button(new Rect(x + 520, y - 4, 200, 40), "Подключиться", btn))
            {
                PlayerPrefs.SetString("joinAddr", joinAddr);
                string err = Net.JoinGame(joinAddr.Trim());
                if (err != null) Net.Status = err;
            }
            y += 60;
            Label(new Rect(x, y, 1100, 26), "Через Steam: примите приглашение друга в Steam — игра сама войдёт в его лобби.", small, new Color(0.7f, 0.75f, 0.8f));
        }
        else
        {
            Label(new Rect(x, y, 900, 28), (Net.IsHost ? "Вы — хост.  " : "Вы подключены.  ") + Net.T.Describe, body, new Color(0.7f, 0.9f, 0.7f));
            y += 40;
            // режим
            Label(new Rect(x, y, 200, 30), "Режим:", body, Color.white);
            bool sb = Net.Mode == NetMode.Sandbox;
            if (Net.IsHost)
            {
                if (GUI.Button(new Rect(x + 200, y - 4, 240, 40), "Песочница", sb ? toggleOn : toggleOff)) Net.SetMode(NetMode.Sandbox);
                if (GUI.Button(new Rect(x + 450, y - 4, 240, 40), "Миссия (кооператив)", !sb ? toggleOn : toggleOff)) Net.SetMode(NetMode.Mission);
            }
            else Label(new Rect(x + 200, y, 600, 30), sb ? "Песочница" : "Миссия (кооператив)", body, new Color(1f, 0.85f, 0.5f));
            y += 46;
            Label(new Rect(x, y, 1100, 26), sb ? "Каждый выбирает сторону: Фонд или Хаос (можно вместе за одну). Хост собирает силы сторон и их количество."
                                                 : "Все игроки — в одной группе Фонда. Хост выбирает операцию.", small, new Color(0.75f, 0.78f, 0.8f));
            y += 40;
            // игроки
            Label(new Rect(x, y, 400, 30), "ИГРОКИ", new GUIStyle(body) { fontStyle = FontStyle.Bold }, Color.white);
            y += 34;
            foreach (var m in Net.Members)
            {
                bool me = m.peer == Net.MyPeer;
                Rect(new Rect(x, y, 760, 40), new Color(0, 0, 0, me ? 0.45f : 0.3f));
                Rect(new Rect(x, y, 4, 40), m.side == 0 ? Battle.TeamColor(Team.Foundation) : Battle.TeamColor(Team.Chaos));
                Label(new Rect(x + 16, y + 6, 300, 28), m.nick + (m.peer == 0 ? "  (хост)" : "") + (me ? "  — вы" : ""), body, Color.white);
                if (sb)
                {
                    if (me)
                    {
                        if (GUI.Button(new Rect(x + 360, y + 4, 190, 32), "Фонд SCP", m.side == 0 ? toggleOn : toggleOff)) Net.SetSide(0);
                        if (GUI.Button(new Rect(x + 560, y + 4, 190, 32), "Повстанцы Хаоса", m.side == 1 ? toggleOn : toggleOff)) Net.SetSide(1);
                    }
                    else Label(new Rect(x + 360, y + 6, 380, 28), m.side == 0 ? "Фонд SCP" : "Повстанцы Хаоса", body, m.side == 0 ? Battle.TeamColor(Team.Foundation) : Battle.TeamColor(Team.Chaos));
                }
                y += 46;
            }
            y += 10;
            if (Net.IsHost && SteamNet.Ready && Net.T.Describe.StartsWith("Steam"))
            {
                if (GUI.Button(new Rect(x, y, 300, 46), "Пригласить друзей", btn)) SteamNet.InviteFriends();
                y += 56;
            }
            if (Net.IsHost)
            {
                if (GUI.Button(new Rect(x, y, 460, 60), sb ? "СОБРАТЬ СИЛЫ И НАЧАТЬ →" : "ВЫБРАТЬ ОПЕРАЦИЮ →", btnBig))
                {
                    Sfx.Play2D("ui_confirm");
                    if (sb) screen = Scr.Setup; else { Operations.Init(); screen = Scr.Ops; }
                }
            }
            else Label(new Rect(x, y + 14, 700, 30), "Ждём, пока хост начнёт бой…", body, new Color(1f, 0.85f, 0.5f, 0.6f + 0.4f * Mathf.Sin(Time.time * 3f)));
            y += 74;
            if (GUI.Button(new Rect(x, y, 260, 46), "Покинуть лобби", btn)) { Net.Shutdown(); Net.Status = ""; }
        }
        if (!string.IsNullOrEmpty(Net.Status)) Label(new Rect(64, H - 120, 1200, 30), Net.Status, body, new Color(1f, 0.85f, 0.55f));
        if (GUI.Button(new Rect(64, H - 80, 200, 46), "← Назад", btn)) { screen = Scr.Menu; }
    }

    // Старт из экрана сборки сил / операций: в сетевом лобби — у всех
    void Launch(BattleConfig cfg)
    {
        if (Net.IsHost && !Net.InGame) { lastCfg = cfg; Net.HostStart(cfg); return; }
        StartBattle(cfg);
    }

    // Позывные живых игроков над головой
    void NickLabels()
    {
        var cam = Cam;
        if (cam == null || !Net.InGame) return;
        HudStyles();
        float sc = Screen.height / 1080f;
        foreach (var u in Unit.All)
        {
            if (!(u is Soldier s) || !s.remoteHuman || !s.alive) continue;
            Vector3 head = s.transform.position + Vector3.up * 2.2f;
            float d = Vector3.Distance(cam.transform.position, head);
            if (d > 250f) continue;
            Vector3 sp = cam.WorldToScreenPoint(head);
            if (sp.z < 0.3f) continue;
            float a = Mathf.Clamp01((250f - d) / 40f);
            Color c = Battle.TeamColor(s.team); c.a = a;
            var st = new GUIStyle(hudS) { alignment = TextAnchor.MiddleCenter, fontSize = 15, fontStyle = FontStyle.Bold };
            Vector2 p = new Vector2(sp.x / sc, (Screen.height - sp.y) / sc);
            Shadowed(new Rect(p.x - 150, p.y - 26, 300, 22), s.nick, st, c);
            Rect(new Rect(p.x - 20, p.y - 3, 40, 3), new Color(0, 0, 0, 0.5f * a));
            Rect(new Rect(p.x - 20, p.y - 3, 40 * Mathf.Clamp01(s.hp / s.maxHp), 3), c);
        }
    }

    void NetEndButtons(float x, float y)
    {
        if (GUI.Button(new Rect(x, y, 300, 54), "В лобби", btn)) { Net.InGame = false; ShowMenu(); screen = Scr.Net; }
        if (GUI.Button(new Rect(x + 320, y, 300, 54), "Покинуть сетевую игру", btn)) { Net.Shutdown(); ShowMenu(); }
    }
}
