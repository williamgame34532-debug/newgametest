using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Весь интерфейс на IMGUI — не требует ни префабов, ни Canvas.
    public partial class Game
    {
        const float VH = 1080f;
        float sc, VW;
        UIPalette P;
        int paletteFor = -1;
        GUIStyle stText, stField, stArea;
        Texture2D texField, texFieldFocus;

        // редакторы
        FighterDef editDef;
        int editTeam, editIndex;
        WeaponDef editWeapon;
        int editWeaponIndex;
        FighterBuild editBuild;
        WeaponStats editWeaponBuild;
        bool editDirty;
        float editChangeT;
        string lastName, lastDesc, lastWeap;
        Stroke curStroke;
        Color penColor = Color.black;
        float penWidth = 0.12f;
        Vector2 scrollRed, scrollBlue, scrollW;
        int presetCursor;

        static readonly Color[] SWATCH =
        {
            new Color(0.82f, 0.08f, 0.08f), new Color(0.1f, 0.25f, 0.85f), new Color(0.06f, 0.06f, 0.07f), new Color(0.95f, 0.95f, 0.95f),
            new Color(0.15f, 0.65f, 0.2f), new Color(0.95f, 0.85f, 0.1f), new Color(1f, 0.5f, 0.05f), new Color(0.55f, 0.15f, 0.8f),
            new Color(1f, 0.45f, 0.7f), new Color(0.35f, 0.75f, 0.95f), new Color(0.5f, 0.5f, 0.52f), new Color(0.9f, 0.72f, 0.2f),
        };

        static readonly Color[] PENS =
        {
            Color.black, Color.white, new Color(0.85f, 0.1f, 0.1f), new Color(1f, 0.8f, 0.15f), new Color(0.15f, 0.4f, 0.95f), new Color(0.2f, 0.75f, 0.25f), new Color(0.6f, 0.2f, 0.85f), new Color(0.5f, 0.3f, 0.15f),
        };

        // ===================== БАЗОВЫЕ ЭЛЕМЕНТЫ =====================
        void Styles()
        {
            if (stText == null)
            {
                stText = new GUIStyle(GUI.skin.label);
                stText.richText = false;
                stText.clipping = TextClipping.Overflow;
            }
            if (paletteFor != data.theme || stField == null)
            {
                paletteFor = data.theme;
                P = Theme.Palette(data.theme);
                bool darkPanel = P.panel.grayscale < 0.5f;
                Color fb = darkPanel ? new Color(0.02f, 0.02f, 0.03f, 0.9f) : new Color(1f, 1f, 1f, 1f);
                Color ff = darkPanel ? new Color(0.08f, 0.06f, 0.1f, 1f) : new Color(1f, 0.98f, 0.92f, 1f);
                texField = Solid(fb);
                texFieldFocus = Solid(ff);
                stField = new GUIStyle(GUI.skin.textField);
                stField.fontSize = 26;
                stField.padding = new RectOffset(12, 12, 8, 8);
                stField.normal.background = texField; stField.hover.background = texField;
                stField.focused.background = texFieldFocus; stField.active.background = texFieldFocus;
                stField.normal.textColor = P.text; stField.hover.textColor = P.text; stField.focused.textColor = P.text; stField.active.textColor = P.text;
                stField.border = new RectOffset(0, 0, 0, 0);
                stArea = new GUIStyle(stField);
                stArea.wordWrap = true;
                stArea.fontSize = 24;
                stArea.alignment = TextAnchor.UpperLeft;
            }
            GUI.skin.settings.cursorColor = P.text;
            GUI.skin.settings.selectionColor = Draw.A(P.accent, 0.4f);
        }

        static Texture2D Solid(Color c)
        {
            var t = new Texture2D(2, 2);
            t.SetPixels(new[] { c, c, c, c });
            t.Apply();
            return t;
        }

        void Box(Rect r, Color c, float rad = 12f)
        {
            if (Event.current.type != EventType.Repaint) return;
            GUI.DrawTexture(r, Texture2D.whiteTexture, ScaleMode.StretchToFill, true, 0, c, 0, rad);
        }

        void Border(Rect r, Color c, float w = 2f, float rad = 12f)
        {
            if (Event.current.type != EventType.Repaint) return;
            GUI.DrawTexture(r, Texture2D.whiteTexture, ScaleMode.StretchToFill, true, 0, c, w, rad);
        }

        void Panel(Rect r)
        {
            Box(r, P.panel, 16);
            Border(r, Draw.A(P.panelEdge, 0.7f), 3, 16);
        }

        void Txt(Rect r, string s, int size, Color c, TextAnchor a = TextAnchor.MiddleLeft, bool bold = false, bool wrap = false)
        {
            stText.fontSize = size;
            stText.normal.textColor = c;
            stText.alignment = a;
            stText.fontStyle = bold ? FontStyle.Bold : FontStyle.Normal;
            stText.wordWrap = wrap;
            GUI.Label(r, s, stText);
        }

        void Shadow(Rect r, string s, int size, Color c, Color sh, TextAnchor a, float off)
        {
            Txt(new Rect(r.x + off, r.y + off, r.width, r.height), s, size, sh, a, true);
            Txt(r, s, size, c, a, true);
        }

        void Outline(Rect r, string s, int size, Color c, Color o, TextAnchor a, float w = 3f)
        {
            for (int i = 0; i < 8; i++)
            {
                float ang = i * Mathf.PI / 4f;
                Txt(new Rect(r.x + Mathf.Cos(ang) * w, r.y + Mathf.Sin(ang) * w, r.width, r.height), s, size, o, a, true);
            }
            Txt(r, s, size, c, a, true);
        }

        bool Btn(Rect r, string label, int size = 28, bool accent = false, bool active = false)
        {
            bool hover = r.Contains(Event.current.mousePosition);
            Color bg = accent ? P.accent : (active ? Color.Lerp(P.btn, P.accent, 0.55f) : P.btn);
            if (hover) bg = accent ? Color.Lerp(P.accent, Color.white, 0.2f) : (active ? Color.Lerp(P.btnHover, P.accent, 0.5f) : P.btnHover);
            Box(r, bg, 10);
            Border(r, accent ? Draw.A(Color.white, 0.6f) : Draw.A(P.panelEdge, hover ? 1f : 0.55f), 2, 10);
            Color tc = (accent || active) ? Color.white : P.btnText;
            Txt(r, label, size, tc, TextAnchor.MiddleCenter, true);
            bool click = GUI.Button(r, GUIContent.none, GUIStyle.none);
            if (click) audio.Sfx("click", 0.5f, 0f);
            return click;
        }

        bool Toggle(Rect r, string label, bool v, int size = 24)
        {
            Rect b = new Rect(r.x, r.y + (r.height - 34) / 2, 64, 34);
            Box(b, v ? P.accent : Draw.A(P.sub, 0.4f), 17);
            Rect knob = new Rect(v ? b.xMax - 30 : b.x + 4, b.y + 4, 26, 26);
            Box(knob, Color.white, 13);
            Txt(new Rect(r.x + 78, r.y, r.width - 78, r.height), label, size, P.text);
            if (GUI.Button(r, GUIContent.none, GUIStyle.none)) { audio.Sfx("click", 0.5f, 0f); return !v; }
            return v;
        }

        float Slider(Rect r, string label, float v, float min, float max, string valueText)
        {
            Txt(new Rect(r.x, r.y, r.width, 30), label, 24, P.text);
            Txt(new Rect(r.x, r.y, r.width, 30), valueText, 24, P.sub, TextAnchor.MiddleRight);
            Rect bar = new Rect(r.x, r.y + 40, r.width, 22);
            Box(bar, Draw.A(P.sub, 0.3f), 11);
            float k = Mathf.InverseLerp(min, max, v);
            Box(new Rect(bar.x, bar.y, Mathf.Max(22, bar.width * k), bar.height), P.accent, 11);
            Box(new Rect(bar.x + bar.width * k - 14, bar.y - 5, 32, 32), Color.white, 16);
            var e = Event.current;
            Rect hit = new Rect(bar.x - 10, bar.y - 12, bar.width + 20, bar.height + 24);
            int id = GUIUtility.GetControlID(FocusType.Passive);
            switch (e.GetTypeForControl(id))
            {
                case EventType.MouseDown:
                    if (hit.Contains(e.mousePosition))
                    {
                        GUIUtility.hotControl = id;
                        v = Mathf.Lerp(min, max, Mathf.Clamp01((e.mousePosition.x - bar.x) / bar.width));
                        e.Use();
                    }
                    break;
                case EventType.MouseDrag:
                    if (GUIUtility.hotControl == id)
                    {
                        v = Mathf.Lerp(min, max, Mathf.Clamp01((e.mousePosition.x - bar.x) / bar.width));
                        e.Use();
                    }
                    break;
                case EventType.MouseUp:
                    if (GUIUtility.hotControl == id) { GUIUtility.hotControl = 0; e.Use(); }
                    break;
            }
            return v;
        }

        void StatBar(Rect r, string label, float v01, Color c, string val)
        {
            Txt(new Rect(r.x, r.y, 150, r.height), label, 22, P.text);
            Rect bar = new Rect(r.x + 150, r.y + r.height * 0.3f, r.width - 230, r.height * 0.4f);
            Box(bar, Draw.A(P.sub, 0.25f), 6);
            Box(new Rect(bar.x, bar.y, Mathf.Max(8, bar.width * Mathf.Clamp01(v01)), bar.height), c, 6);
            Txt(new Rect(r.xMax - 70, r.y, 70, r.height), val, 22, P.sub, TextAnchor.MiddleRight);
        }

        Vector2 W2G(Vector2 w)
        {
            Vector3 sp = cam.WorldToScreenPoint(new Vector3(w.x, w.y, 0));
            return new Vector2(sp.x / sc, (Screen.height - sp.y) / sc);
        }

        // ===================== ГЛАВНЫЙ ВЫЗОВ =====================
        void OnGUI()
        {
            var e = Event.current;
            if (e.type == EventType.KeyDown && e.keyCode != KeyCode.None)
            {
                bool first = !held.Contains(e.keyCode);
                if (first) { held.Add(e.keyCode); pressed.Add(e.keyCode); }
                if (e.keyCode == KeyCode.Escape && first)
                {
                    if (scr == Scr.Battle) Pause();
                    else if (scr == Scr.Pause) Resume();
                    else if (scr == Scr.Settings) scr = settingsBack;
                    else if (scr == Scr.Help) scr = Scr.Main;
                }
            }
            if (e.type == EventType.KeyUp) held.Remove(e.keyCode);

            sc = Screen.height / VH;
            VW = Screen.width / sc;
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(sc, sc, 1f));
            Styles();

            if (battle.mode != Battle.Mode.Showroom) WorldOverlay();

            switch (scr)
            {
                case Scr.Main: MainMenu(); break;
                case Scr.Teams: Teams(); break;
                case Scr.EditFighter: EditFighter(); break;
                case Scr.EditWeapon: EditWeaponScreen(); break;
                case Scr.Settings: SettingsScreen(); break;
                case Scr.Battle: Hud(); break;
                case Scr.Pause: Hud(); PauseMenu(); break;
                case Scr.Help: Help(); break;
            }
        }

        void Update()
        {
            if ((scr == Scr.EditFighter || scr == Scr.EditWeapon) && editDirty && Time.unscaledTime - editChangeT > 0.45f)
            {
                editDirty = false;
                RebuildShowroom();
            }
        }

        // всплывающие цифры урона, надписи, полоски над головами
        void WorldOverlay()
        {
            if (scr == Scr.Battle || scr == Scr.Pause)
            {
                if (S.overheadBars)
                    foreach (var f in battle.fighters)
                    {
                        if (f.dead || (f.Invisible && !f.human)) continue;
                        Vector2 g = W2G(f.HeadPos + Vector2.up * (0.55f * f.Size + 0.25f));
                        Rect bar = new Rect(g.x - 40, g.y, 80, 9);
                        Box(new Rect(bar.x - 2, bar.y - 2, bar.width + 4, bar.height + 4), new Color(0, 0, 0, 0.55f), 4);
                        Box(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(f.hp / f.maxHp), bar.height), f.team == 0 ? new Color(0.95f, 0.25f, 0.2f) : new Color(0.3f, 0.55f, 1f), 3);
                        string nm = f.human ? (f.pindex == 0 ? "P1 " : "P2 ") + f.B.name : f.B.name;
                        Outline(new Rect(g.x - 150, g.y - 30, 300, 26), nm, 18, Color.white, new Color(0, 0, 0, 0.8f), TextAnchor.MiddleCenter, 1.5f);
                    }
            }
            foreach (var p in battle.popups)
            {
                Vector2 g = W2G(p.pos);
                float k = p.t / p.life;
                float pop = k < 0.12f ? Mathf.Lerp(1.6f, 1f, k / 0.12f) : 1f;
                int size = (int)(40 * p.size * pop * (scr == Scr.Battle || scr == Scr.Pause ? 1f : 0.8f));
                Color c = p.col; c.a = 1f - Mathf.Clamp01((k - 0.6f) / 0.4f);
                Outline(new Rect(g.x - 300, g.y - 40, 600, 80), p.text, size, c, new Color(0, 0, 0, c.a * 0.85f), TextAnchor.MiddleCenter, 2.5f);
            }
        }

        // ===================== ГЛАВНОЕ МЕНЮ =====================
        void MainMenu()
        {
            float t = Time.unscaledTime;
            // затемнение слева для читаемости
            Box(new Rect(0, 0, 820, VH), Draw.A(P.panel, 0.55f), 0);

            float bob = Mathf.Sin(t * 1.6f) * 6f;
            Rect tr = new Rect(70, 70 + bob, 900, 150);
            if (data.theme == 4)
            {
                for (int i = 0; i < 3; i++) Txt(new Rect(tr.x + Random.Range(-2f, 2f), tr.y, tr.width, tr.height), "STICKMAN", 140, Draw.A(P.titleShadow, 0.35f), TextAnchor.MiddleLeft, true);
            }
            Shadow(tr, "STICKMAN", 140, P.title, P.titleShadow, TextAnchor.MiddleLeft, 7f);
            Shadow(new Rect(78, 210 + bob, 900, 70), "ЛЕГЕНДЫ АРЕНЫ", 58, P.accent, Draw.A(Color.black, 0.5f), TextAnchor.MiddleLeft, 3f);
            Txt(new Rect(82, 280, 720, 40), "Опиши героя — арена оживит его. Бессмертных не бывает.", 24, P.sub, TextAnchor.MiddleLeft, false);

            // режим
            Txt(new Rect(80, 360, 400, 40), "РЕЖИМ", 26, P.sub, TextAnchor.MiddleLeft, true);
            if (Btn(new Rect(80, 405, 300, 64), "1 ИГРОК", 28, false, !data.twoPlayers)) { data.twoPlayers = false; Save(); }
            if (Btn(new Rect(400, 405, 300, 64), "2 ИГРОКА", 28, false, data.twoPlayers)) { data.twoPlayers = true; data.p1Control = true; data.p2Control = true; Save(); }
            Txt(new Rect(80, 475, 700, 60), data.twoPlayers ? "Каждый создаёт бойцов за свою сторону и может управлять лидером на одной клавиатуре." : "Ты описываешь обе команды и смотришь эпичный бой (или управляешь красным лидером).", 21, P.sub, TextAnchor.UpperLeft, false, true);

            // стиль
            Txt(new Rect(80, 560, 400, 40), "СТИЛЬ АРЕНЫ", 26, P.sub, TextAnchor.MiddleLeft, true);
            for (int i = 0; i < Theme.Count; i++)
            {
                int row = i / 3, col = i % 3;
                if (Btn(new Rect(80 + col * 215, 605 + row * 72, 200, 60), Theme.Names[i], 22, false, data.theme == i)) { SetTheme(i); StartDemo(); }
            }

            Txt(new Rect(80, VH - 90, 740, 40), "Счёт сессии:  КРАСНЫЕ " + battle.wins[0] + " : " + battle.wins[1] + " СИНИЕ", 24, P.text, TextAnchor.MiddleLeft, true);
            Txt(new Rect(80, VH - 55, 740, 40), "Esc — пауза в бою", 20, P.sub);

            // кнопки справа
            float bx = VW - 480, by = 300, bw = 400;
            float pulse = 1f + Mathf.Sin(t * 4f) * 0.03f;
            Rect fight = new Rect(bx - bw * (pulse - 1f) / 2, by - 4, bw * pulse, 96 * pulse);
            if (Btn(fight, "В БОЙ!", 44, true)) StartBattle();
            if (Btn(new Rect(bx, by + 120, bw, 76), "БОЙЦЫ И ОРУЖИЕ", 30)) scr = Scr.Teams;
            if (Btn(new Rect(bx, by + 210, bw, 76), "НАСТРОЙКИ", 30)) { settingsBack = Scr.Main; scr = Scr.Settings; }
            if (Btn(new Rect(bx, by + 300, bw, 76), "КАК ИГРАТЬ", 30)) scr = Scr.Help;
            if (Btn(new Rect(bx, by + 390, bw, 76), "ВЫХОД", 30))
            {
                Save();
#if UNITY_EDITOR
                UnityEditor.EditorApplication.isPlaying = false;
#else
                Application.Quit();
#endif
            }

            // текущие составы
            Rect info = new Rect(bx, by + 500, bw, 150);
            Panel(info);
            Txt(new Rect(info.x + 20, info.y + 12, info.width - 40, 34), "КРАСНЫЕ: " + data.red.Count + " бойц.", 24, new Color(0.95f, 0.3f, 0.25f), TextAnchor.MiddleLeft, true);
            Txt(new Rect(info.x + 20, info.y + 48, info.width - 40, 34), "СИНИЕ: " + data.blue.Count + " бойц.", 24, new Color(0.35f, 0.6f, 1f), TextAnchor.MiddleLeft, true);
            Txt(new Rect(info.x + 20, info.y + 84, info.width - 40, 50), "Оружия в арсенале: " + data.weapons.Count + (data.drops ? " (падает с неба)" : ""), 21, P.sub, TextAnchor.UpperLeft, false, true);
        }

        // ===================== КОМАНДЫ =====================
        void Teams()
        {
            Box(new Rect(0, 0, VW, VH), Draw.A(P.panel, 0.35f), 0);
            Shadow(new Rect(0, 20, VW, 80), "БОЙЦЫ И ОРУЖИЕ", 60, P.title, P.titleShadow, TextAnchor.MiddleCenter, 4f);
            float gap = 30f;
            float colW = (VW - gap * 4) / 3f;
            float top = 120, h = VH - 260;
            TeamColumn(new Rect(gap, top, colW, h), 0, data.red, ref scrollRed);
            Armory(new Rect(gap * 2 + colW, top, colW, h));
            TeamColumn(new Rect(gap * 3 + colW * 2, top, colW, h), 1, data.blue, ref scrollBlue);

            float by = VH - 115;
            if (Btn(new Rect(gap, by, 260, 80), "< НАЗАД", 30)) { Save(); scr = Scr.Main; }
            for (int i = 0; i < Theme.Count; i++)
                if (Btn(new Rect(gap + 290 + i * 175, by + 10, 165, 60), Theme.Names[i], 19, false, data.theme == i)) { SetTheme(i); StartDemo(); }
            if (Btn(new Rect(VW - gap - 380, by, 380, 80), "К БОЮ!", 40, true)) StartBattle();
        }

        void TeamColumn(Rect r, int team, List<FighterDef> list, ref Vector2 scroll)
        {
            Panel(r);
            Color tc = team == 0 ? new Color(0.95f, 0.25f, 0.2f) : new Color(0.3f, 0.55f, 1f);
            string who = data.twoPlayers ? (team == 0 ? "  — ИГРОК 1" : "  — ИГРОК 2") : "";
            Txt(new Rect(r.x + 24, r.y + 14, r.width - 48, 50), (team == 0 ? "КРАСНЫЕ" : "СИНИЕ") + who, 36, tc, TextAnchor.MiddleLeft, true);
            Txt(new Rect(r.x + 24, r.y + 60, r.width - 48, 30), list.Count + " / 4 бойца", 21, P.sub);

            float y = r.y + 100;
            for (int i = 0; i < list.Count; i++)
            {
                var d = list[i];
                Rect row = new Rect(r.x + 18, y, r.width - 36, 112);
                Box(row, Draw.A(P.btn, 0.8f), 12);
                Border(row, Draw.A(tc, 0.6f), 2, 12);
                Box(new Rect(row.x + 14, row.y + 16, 36, 36), d.color, 18);
                Border(new Rect(row.x + 14, row.y + 16, 36, 36), Draw.A(P.text, 0.5f), 2, 18);
                Txt(new Rect(row.x + 62, row.y + 8, row.width - 250, 40), d.name, 26, P.text, TextAnchor.MiddleLeft, true);
                var b = Parser.BuildFighter(d, data.weapons);
                string ab = "";
                foreach (var a in b.abilities) ab += (ab.Length > 0 ? ", " : "") + Info.Name(a).Replace(" (пассив)", "");
                Txt(new Rect(row.x + 62, row.y + 46, row.width - 80, 28), ab, 18, P.sub);
                Txt(new Rect(row.x + 62, row.y + 74, row.width - 80, 28), (b.weapon != null ? b.weapon.name : "Кулаки") + "  •  слабость: " + Info.Name(b.weakness), 18, P.sub);
                if (Btn(new Rect(row.xMax - 180, row.y + 14, 110, 44), "Изменить", 19)) OpenFighterEditor(team, i);
                if (Btn(new Rect(row.xMax - 60, row.y + 14, 46, 44), "X", 22)) { list.RemoveAt(i); Save(); break; }
                y += 122;
            }
            if (list.Count < 4)
            {
                if (Btn(new Rect(r.x + 18, y, r.width - 36, 64), "+ СОЗДАТЬ БОЙЦА", 26, true)) OpenFighterEditor(team, -1);
                y += 74;
                float hw = (r.width - 46) / 2f;
                if (Btn(new Rect(r.x + 18, y, hw, 54), "+ Случайный", 21))
                {
                    var d = Parser.RandomFighter(rng);
                    list.Add(d); Save();
                }
                if (Btn(new Rect(r.x + 28 + hw, y, hw, 54), "+ Из готовых", 21))
                {
                    var pre = Presets.Fighters();
                    list.Add(pre[presetCursor % pre.Count]);
                    presetCursor++;
                    Save();
                }
            }
            // управление
            float cy = r.yMax - 70;
            if (team == 0)
                data.p1Control = Toggle(new Rect(r.x + 24, cy, r.width - 48, 50), "Управлять лидером (WASD, F G, R T Y)", data.p1Control, 20);
            else if (data.twoPlayers)
                data.p2Control = Toggle(new Rect(r.x + 24, cy, r.width - 48, 50), "Управлять лидером (стрелки, K L, I O P)", data.p2Control, 20);
            else
                Txt(new Rect(r.x + 24, cy, r.width - 48, 50), "Синими управляет ИИ арены", 20, P.sub);
        }

        void Armory(Rect r)
        {
            Panel(r);
            Txt(new Rect(r.x + 24, r.y + 14, r.width - 48, 50), "АРСЕНАЛ", 36, P.text, TextAnchor.MiddleLeft, true);
            Txt(new Rect(r.x + 24, r.y + 60, r.width - 48, 30), "Это оружие сбрасывается на арену с парашютом", 20, P.sub);
            Rect view = new Rect(r.x + 10, r.y + 100, r.width - 20, r.height - 330);
            float ih = data.weapons.Count * 82f;
            Rect inner = new Rect(0, 0, view.width - 24, Mathf.Max(ih, view.height));
            scrollW = GUI.BeginScrollView(view, scrollW, inner, false, false, GUIStyle.none, GUI.skin.verticalScrollbar);
            for (int i = 0; i < data.weapons.Count; i++)
            {
                var w = data.weapons[i];
                var ws = Parser.BuildWeapon(w);
                Rect row = new Rect(8, i * 82f, inner.width - 16, 74);
                Box(row, Draw.A(P.btn, 0.8f), 10);
                Box(new Rect(row.x + 12, row.y + 22, 30, 30), ws.color, 6);
                Txt(new Rect(row.x + 54, row.y + 4, row.width - 200, 36), w.name, 24, P.text, TextAnchor.MiddleLeft, true);
                Txt(new Rect(row.x + 54, row.y + 38, row.width - 200, 30), Info.Name(ws.kind) + (ws.element != Element.None ? " • " + Info.Name(ws.element) : "") + " • урон " + Mathf.RoundToInt(ws.dmg), 18, P.sub);
                if (Btn(new Rect(row.xMax - 168, row.y + 14, 104, 46), "Изменить", 18)) OpenWeaponEditor(i);
                if (Btn(new Rect(row.xMax - 56, row.y + 14, 46, 46), "X", 20)) { data.weapons.RemoveAt(i); Save(); break; }
            }
            GUI.EndScrollView();
            float y = r.yMax - 220;
            if (Btn(new Rect(r.x + 18, y, r.width - 36, 64), "+ ОПИСАТЬ ОРУЖИЕ", 26, true)) OpenWeaponEditor(-1);
            data.drops = Toggle(new Rect(r.x + 24, y + 76, r.width - 48, 50), "Сбрасывать оружие с неба", data.drops, 22);
            data.dropInterval = Slider(new Rect(r.x + 24, y + 130, r.width - 48, 70), "Частота сброса", data.dropInterval, 4f, 20f, "раз в " + Mathf.RoundToInt(data.dropInterval) + " сек");
        }

        // ===================== РЕДАКТОР БОЙЦА =====================
        void OpenFighterEditor(int team, int index)
        {
            editTeam = team; editIndex = index;
            var list = team == 0 ? data.red : data.blue;
            if (index >= 0 && index < list.Count) editDef = list[index].Clone();
            else
            {
                editDef = new FighterDef();
                editDef.name = team == 0 ? "Красный боец" : "Синий боец";
                editDef.color = team == 0 ? SWATCH[0] : SWATCH[1];
                editDef.description = "";
            }
            if (editDef.drawing == null) editDef.drawing = new List<Stroke>();
            lastName = editDef.name; lastDesc = editDef.description; lastWeap = editDef.weaponDesc;
            scr = Scr.EditFighter;
            RebuildShowroom();
        }

        void OpenWeaponEditor(int index)
        {
            editWeaponIndex = index;
            editWeapon = index >= 0 && index < data.weapons.Count ? data.weapons[index].Clone() : new WeaponDef { name = "Новое оружие", description = "" };
            if (editWeapon.drawing == null) editWeapon.drawing = new List<Stroke>();
            lastName = editWeapon.name; lastDesc = editWeapon.description;
            scr = Scr.EditWeapon;
            RebuildShowroom();
        }

        void RebuildShowroom()
        {
            FighterBuild b;
            if (scr == Scr.EditWeapon)
            {
                editWeaponBuild = Parser.BuildWeapon(editWeapon);
                b = Parser.BuildFighter(new FighterDef { name = "Испытатель", description = "", color = data.theme == 4 ? new Color(0.1f, 0.85f, 1f) : new Color(0.15f, 0.15f, 0.17f) }, null);
                b.abilities.Clear();
                b.notes.Clear();
                b.weapon = editWeaponBuild;
            }
            else
            {
                b = Parser.BuildFighter(editDef, data.weapons);
                editBuild = b;
            }
            battle.Setup(Battle.Mode.Showroom, new List<FighterBuild> { b }, null, null, false, 9f, false, false, false);
            audio.PlayMusic(false);
        }

        void MarkDirty() { editDirty = true; editChangeT = Time.unscaledTime; }

        void EditFighter()
        {
            float pw = Mathf.Min(1040f, VW * 0.58f);
            Rect r = new Rect(24, 24, pw, VH - 48);
            Panel(r);
            Color tc = editTeam == 0 ? new Color(0.95f, 0.25f, 0.2f) : new Color(0.3f, 0.55f, 1f);
            string hdr = (data.twoPlayers ? (editTeam == 0 ? "ИГРОК 1: " : "ИГРОК 2: ") : "") + "БОЕЦ ЗА " + (editTeam == 0 ? "КРАСНЫХ" : "СИНИХ");
            Txt(new Rect(r.x + 28, r.y + 14, r.width - 56, 50), hdr, 34, tc, TextAnchor.MiddleLeft, true);

            float x = r.x + 28, w = r.width - 56, y = r.y + 72;
            Txt(new Rect(x, y, 200, 40), "Имя", 24, P.sub, TextAnchor.MiddleLeft, true);
            editDef.name = GUI.TextField(new Rect(x + 120, y, w - 120, 46), editDef.name ?? "", 40, stField);
            y += 58;

            Txt(new Rect(x, y, 200, 40), "Цвет", 24, P.sub, TextAnchor.MiddleLeft, true);
            for (int i = 0; i < SWATCH.Length; i++)
            {
                Rect sw = new Rect(x + 120 + i * 52, y + 2, 42, 42);
                Box(sw, SWATCH[i], 21);
                bool sel = (SWATCH[i] - editDef.color).maxColorComponent < 0.02f && (editDef.color - SWATCH[i]).maxColorComponent < 0.02f;
                Border(sw, sel ? P.accent : Draw.A(P.text, 0.35f), sel ? 4 : 2, 21);
                if (GUI.Button(sw, GUIContent.none, GUIStyle.none)) { editDef.color = SWATCH[i]; MarkDirty(); }
            }
            y += 58;

            Txt(new Rect(x, y, w, 34), "Опиши героя: внешность, способности, характер, слабость", 23, P.sub, TextAnchor.MiddleLeft, true);
            y += 38;
            editDef.description = GUI.TextArea(new Rect(x, y, w, 136), editDef.description ?? "", 600, stArea);
            y += 142;
            Txt(new Rect(x, y, w, 52), "Пример: «Очень быстрый ниндзя в повязке, телепортируется и кидает огненные шары. Боится льда». Бессмертие запрещено — у каждого есть слабость.", 18, P.sub, TextAnchor.UpperLeft, false, true);
            y += 56;

            Txt(new Rect(x, y, 200, 40), "Оружие", 24, P.sub, TextAnchor.MiddleLeft, true);
            editDef.weaponDesc = GUI.TextField(new Rect(x + 120, y, w - 120, 46), editDef.weaponDesc ?? "", 80, stField);
            y += 52;
            float cx = x + 120;
            if (Btn(new Rect(cx, y, 150, 36), "Без оружия", 17, false, string.IsNullOrEmpty(editDef.weaponDesc))) { editDef.weaponDesc = ""; MarkDirty(); }
            cx += 158;
            for (int i = 0; i < data.weapons.Count && cx < x + w - 120; i++)
            {
                string n = data.weapons[i].name;
                float bw = Mathf.Clamp(n.Length * 11f + 30f, 100f, 220f);
                if (cx + bw > x + w) break;
                if (Btn(new Rect(cx, y, bw, 36), n, 17, false, editDef.weaponDesc == n)) { editDef.weaponDesc = n; MarkDirty(); }
                cx += bw + 8;
            }
            y += 50;

            // планшет для рисования + характеристики
            float by = r.yMax - 92;
            float padS = Mathf.Clamp(by - 10f - 80f - 34f - y, 200f, 320f);
            float padW = Mathf.Max(padS, 300f);
            Txt(new Rect(x, y, padW + 40, 30), "Нарисуй на голове (шляпа, маска...)", 19, P.sub, TextAnchor.MiddleLeft, true);
            Rect pad = new Rect(x, y + 34, padS, padS);
            bool ch = false;
            DrawPad(pad, editDef.drawing, 0, ref ch);
            if (ch) MarkDirty();
            PadTools(new Rect(x, pad.yMax + 8, padW, 80), editDef.drawing);

            Rect stats = new Rect(x + padW + 24, y, w - padW - 24, by - 10f - y);
            FighterStats(stats, editBuild);

            // кнопки
            float bw3 = (w - 30) / 3f;
            if (Btn(new Rect(x, by, bw3, 70), "СЛУЧАЙНЫЙ", 24))
            {
                var d = Parser.RandomFighter(rng);
                editDef.name = d.name; editDef.description = d.description; editDef.weaponDesc = d.weaponDesc; editDef.color = d.color;
                MarkDirty();
            }
            if (Btn(new Rect(x + bw3 + 15, by, bw3, 70), "ОТМЕНА", 26)) { scr = Scr.Teams; StartDemo(); }
            if (Btn(new Rect(x + (bw3 + 15) * 2, by, bw3, 70), "СОХРАНИТЬ", 28, true))
            {
                var list = editTeam == 0 ? data.red : data.blue;
                if (editIndex >= 0 && editIndex < list.Count) list[editIndex] = editDef;
                else if (list.Count < 4) list.Add(editDef);
                Save();
                scr = Scr.Teams;
                StartDemo();
                return;
            }

            if (editDef.name != lastName || editDef.description != lastDesc || editDef.weaponDesc != lastWeap)
            {
                // цвет из описания, если он там упомянут впервые
                Color dc;
                Color prevC;
                if (editDef.description != lastDesc && Parser.FindColor(editDef.description, out dc) && !Parser.FindColor(lastDesc ?? "", out prevC)) editDef.color = dc;
                lastName = editDef.name; lastDesc = editDef.description; lastWeap = editDef.weaponDesc;
                MarkDirty();
            }

            // подпись под витриной
            float rx = r.xMax + 20;
            Rect nameR = new Rect(rx, VH - 170, VW - rx - 20, 70);
            Outline(nameR, editDef.name, 48, editDef.color.grayscale < 0.12f ? new Color(0.9f, 0.9f, 0.9f) : editDef.color, new Color(0, 0, 0, 0.7f), TextAnchor.MiddleCenter, 3f);
            Txt(new Rect(rx, VH - 100, VW - rx - 20, 40), editDirty ? "генерация..." : "персонаж показывает приёмы", 22, P.sub, TextAnchor.MiddleCenter);
        }

        void FighterStats(Rect r, FighterBuild b)
        {
            Box(r, Draw.A(P.btn, 0.6f), 12);
            if (b == null) return;
            float x = r.x + 18, w = r.width - 36, y = r.y + 12;
            Txt(new Rect(x, y, w, 34), "СГЕНЕРИРОВАНО АРЕНОЙ", 22, P.accent, TextAnchor.MiddleLeft, true);
            y += 38;
            foreach (var n in b.notes)
                if (n.StartsWith("БЕССМЕРТИЕ"))
                {
                    Box(new Rect(x - 6, y - 2, w + 12, 50), new Color(0.8f, 0.1f, 0.08f, 0.9f), 8);
                    Txt(new Rect(x, y, w, 46), n, 16, Color.white, TextAnchor.MiddleLeft, true, true);
                    y += 54;
                }
            StatBar(new Rect(x, y, w, 28), "Здоровье", b.hp / 140f, new Color(0.3f, 0.85f, 0.35f), Mathf.RoundToInt(b.hp).ToString()); y += 29;
            StatBar(new Rect(x, y, w, 28), "Сила", b.str / 1.9f, new Color(0.95f, 0.35f, 0.25f), b.str.ToString("0.0")); y += 29;
            StatBar(new Rect(x, y, w, 28), "Скорость", b.spd / 1.9f, new Color(0.95f, 0.8f, 0.2f), b.spd.ToString("0.0")); y += 29;
            StatBar(new Rect(x, y, w, 28), "Защита", b.def / 1.9f, new Color(0.35f, 0.6f, 1f), b.def.ToString("0.0")); y += 29;
            StatBar(new Rect(x, y, w, 28), "Ловкость", b.agi / 1.9f, new Color(0.7f, 0.4f, 1f), b.agi.ToString("0.0")); y += 34;
            Txt(new Rect(x, y, w, 28), "Способности:", 20, P.text, TextAnchor.MiddleLeft, true); y += 28;
            foreach (var a in b.abilities) { Txt(new Rect(x + 14, y, w - 14, 26), "• " + Info.Name(a), 19, P.text); y += 25; }
            y += 4;
            Txt(new Rect(x, y, w, 28), "Слабость: " + Info.Name(b.weakness) + " (урон x2)", 20, new Color(1f, 0.6f, 0.15f), TextAnchor.MiddleLeft, true); y += 30;
            string wpn = b.weapon != null ? b.weapon.name + " (" + Info.Name(b.weapon.kind) + (b.weapon.element != Element.None ? ", " + Info.Name(b.weapon.element) : "") + ")" : "Кулаки";
            Txt(new Rect(x, y, w, 28), "Оружие: " + wpn, 19, P.text); y += 28;
            if (b.size != 1f) { Txt(new Rect(x, y, w, 26), b.size > 1f ? "Размер: великан" : "Размер: малыш", 19, P.sub); y += 26; }
            foreach (var n in b.notes)
            {
                if (n.StartsWith("БЕССМЕРТИЕ")) continue;
                if (y > r.yMax - 44) break;
                Txt(new Rect(x, y, w, 44), n, 16, P.sub, TextAnchor.UpperLeft, false, true);
                y += 40;
            }
        }

        // ===================== РЕДАКТОР ОРУЖИЯ =====================
        void EditWeaponScreen()
        {
            float pw = Mathf.Min(1040f, VW * 0.58f);
            Rect r = new Rect(24, 24, pw, VH - 48);
            Panel(r);
            Txt(new Rect(r.x + 28, r.y + 14, r.width - 56, 50), "ОПИСАНИЕ ОРУЖИЯ", 34, P.accent, TextAnchor.MiddleLeft, true);
            float x = r.x + 28, w = r.width - 56, y = r.y + 76;
            Txt(new Rect(x, y, 200, 40), "Название", 24, P.sub, TextAnchor.MiddleLeft, true);
            editWeapon.name = GUI.TextField(new Rect(x + 150, y, w - 150, 46), editWeapon.name ?? "", 40, stField);
            y += 62;
            Txt(new Rect(x, y, w, 34), "Опиши: что это, из чего, какая стихия", 23, P.sub, TextAnchor.MiddleLeft, true);
            y += 38;
            editWeapon.description = GUI.TextArea(new Rect(x, y, w, 130), editWeapon.description ?? "", 300, stArea);
            y += 136;
            Txt(new Rect(x, y, w, 52), "Примеры: «огромный огненный топор», «ледяной лук», «автомат», «ядовитые сюрикены», «бензопила», «посох молний», «гранаты».", 18, P.sub, TextAnchor.UpperLeft, false, true);
            y += 60;

            float wby = r.yMax - 92;
            float padS = Mathf.Clamp(wby - 10f - 80f - 34f - y, 200f, 340f);
            float padW = Mathf.Max(padS, 300f);
            Txt(new Rect(x, y, padW + 60, 30), "Нарисуй своё оружие (необязательно)", 19, P.sub, TextAnchor.MiddleLeft, true);
            Rect pad = new Rect(x, y + 34, padS, padS);
            bool ch = false;
            DrawPad(pad, editWeapon.drawing, 1, ref ch);
            if (ch) MarkDirty();
            PadTools(new Rect(x, pad.yMax + 8, padW, 80), editWeapon.drawing);

            Rect st = new Rect(x + padW + 24, y, w - padW - 24, wby - 10f - y);
            Box(st, Draw.A(P.btn, 0.6f), 12);
            var ws = editWeaponBuild;
            if (ws != null)
            {
                float sx = st.x + 18, sw = st.width - 36, sy = st.y + 12;
                Txt(new Rect(sx, sy, sw, 34), "СГЕНЕРИРОВАНО АРЕНОЙ", 22, P.accent, TextAnchor.MiddleLeft, true); sy += 44;
                Txt(new Rect(sx, sy, sw, 30), "Тип: " + Info.Name(ws.kind), 21, P.text, TextAnchor.MiddleLeft, true); sy += 34;
                Txt(new Rect(sx, sy, sw, 30), "Стихия: " + Info.Name(ws.element), 21, ws.element != Element.None ? Info.ElemColor(ws.element) * 0.85f + new Color(0, 0, 0, 1) : P.text); sy += 38;
                StatBar(new Rect(sx, sy, sw, 30), "Урон", ws.dmg / 26f, new Color(0.95f, 0.35f, 0.25f), Mathf.RoundToInt(ws.dmg).ToString()); sy += 34;
                StatBar(new Rect(sx, sy, sw, 30), "Скорость", ws.rate / 2.2f, new Color(0.95f, 0.8f, 0.2f), ws.rate.ToString("0.0")); sy += 34;
                StatBar(new Rect(sx, sy, sw, 30), "Дальность", Mathf.Min(1f, ws.range / 14f), new Color(0.35f, 0.6f, 1f), ws.range.ToString("0.0")); sy += 40;
                if (ws.ammo > 0) { Txt(new Rect(sx, sy, sw, 28), "Боезапас: " + ws.ammo + (ws.pellets > 1 ? " (дробь x" + ws.pellets + ")" : ""), 20, P.text); sy += 30; }
                if (ws.bleed) { Txt(new Rect(sx, sy, sw, 28), "• вызывает кровотечение", 19, new Color(0.85f, 0.15f, 0.15f)); sy += 28; }
                if (ws.explode) { Txt(new Rect(sx, sy, sw, 28), "• взрывается", 19, new Color(1f, 0.55f, 0.15f)); sy += 28; }
                if (ws.size > 1.05f) { Txt(new Rect(sx, sy, sw, 28), "• тяжёлое: медленнее, но больнее", 19, P.sub); sy += 28; }
                Txt(new Rect(sx, sy + 10, sw, 80), "Максимальный урон ограничен — арена любит честные бои.", 17, P.sub, TextAnchor.UpperLeft, false, true);
            }

            float by = r.yMax - 92;
            float bw2 = (w - 15) / 2f;
            if (Btn(new Rect(x, by, bw2, 70), "ОТМЕНА", 26)) { scr = Scr.Teams; StartDemo(); }
            if (Btn(new Rect(x + bw2 + 15, by, bw2, 70), "СОХРАНИТЬ", 28, true))
            {
                if (editWeaponIndex >= 0 && editWeaponIndex < data.weapons.Count) data.weapons[editWeaponIndex] = editWeapon;
                else data.weapons.Add(editWeapon);
                Save();
                scr = Scr.Teams;
                StartDemo();
                return;
            }
            if (editWeapon.name != lastName || editWeapon.description != lastDesc)
            {
                lastName = editWeapon.name; lastDesc = editWeapon.description;
                MarkDirty();
            }
            float rx = r.xMax + 20;
            Outline(new Rect(rx, VH - 170, VW - rx - 20, 70), editWeapon.name, 46, Color.white, new Color(0, 0, 0, 0.7f), TextAnchor.MiddleCenter, 3f);
        }

        // ===================== ПЛАНШЕТ ДЛЯ РИСОВАНИЯ =====================
        static Vector2 ToPad(Rect r, Vector2 m) { return new Vector2((m.x - r.center.x) / (r.width * 0.5f), -(m.y - r.center.y) / (r.height * 0.5f)); }
        static Vector2 FromPad(Rect r, Vector2 p) { return new Vector2(r.center.x + p.x * r.width * 0.5f, r.center.y - p.y * r.height * 0.5f); }

        void DrawPad(Rect r, List<Stroke> strokes, int guide, ref bool changed)
        {
            var e = Event.current;
            Box(r, new Color(1f, 1f, 1f, 0.97f), 10);
            Border(r, Draw.A(P.panelEdge, 0.8f), 2, 10);
            if (e.type == EventType.MouseDown && e.button == 0 && r.Contains(e.mousePosition))
            {
                curStroke = new Stroke { color = penColor, width = penWidth };
                curStroke.pts.Add(ToPad(r, e.mousePosition));
                strokes.Add(curStroke);
                e.Use();
            }
            else if (e.type == EventType.MouseDrag && curStroke != null)
            {
                Vector2 p = ToPad(r, e.mousePosition);
                p.x = Mathf.Clamp(p.x, -1f, 1f); p.y = Mathf.Clamp(p.y, -1f, 1f);
                if (Vector2.Distance(p, curStroke.pts[curStroke.pts.Count - 1]) > 0.02f) curStroke.pts.Add(p);
                if (curStroke.pts.Count > 200) curStroke = null;
                changed = true;
                e.Use();
            }
            else if (e.rawType == EventType.MouseUp && curStroke != null)
            {
                if (curStroke.pts.Count == 1) curStroke.pts.Add(curStroke.pts[0] + new Vector2(0.01f, 0f));
                curStroke = null;
                changed = true;
            }

            if (e.type != EventType.Repaint) return;
            Draw.GLBegin();
            float half = r.width * 0.5f;
            Color gc = new Color(0.6f, 0.6f, 0.65f, 0.6f);
            if (guide == 0)
            {
                // контур головы и тела-подсказки
                Vector2 c = FromPad(r, Vector2.zero);
                Draw.GLDisc(c, 0.4f * half, new Color(0.85f, 0.85f, 0.88f, 0.8f), 32);
                Draw.GLLine(FromPad(r, new Vector2(0, -0.4f)), FromPad(r, new Vector2(0, -1f)), 0.27f * half, new Color(0.85f, 0.85f, 0.88f, 0.8f));
                Draw.GLRing(c, 0.4f * half, 2f, gc, 40);
                Draw.GLLine(FromPad(r, new Vector2(0.25f, 0.05f)), FromPad(r, new Vector2(0.55f, 0.05f)), 2f, gc);
                Draw.GLDisc(FromPad(r, new Vector2(0.62f, 0.05f)), 5f, gc, 10);
            }
            else
            {
                // рука держит оружие слева, лезвие уходит вправо
                Vector2 hand = FromPad(r, new Vector2(-0.71f, 0f));
                Draw.GLLine(FromPad(r, new Vector2(-1f, -0.35f)), hand, 0.25f * half, new Color(0.85f, 0.85f, 0.88f, 0.8f));
                Draw.GLDisc(hand, 0.13f * half, new Color(0.75f, 0.75f, 0.8f, 0.9f), 20);
                Draw.GLLine(FromPad(r, new Vector2(-0.71f, 0f)), FromPad(r, new Vector2(1f, 0f)), 1.5f, gc);
            }
            foreach (var st in strokes)
            {
                float w = Mathf.Max(2f, st.width * half);
                for (int i = 0; i < st.pts.Count; i++)
                {
                    Vector2 a = FromPad(r, st.pts[i]);
                    Draw.GLDisc(a, w * 0.5f, st.color, 10);
                    if (i > 0) Draw.GLLine(FromPad(r, st.pts[i - 1]), a, w, st.color);
                }
            }
            Draw.GLEnd();
        }

        void PadTools(Rect r, List<Stroke> strokes)
        {
            float s = 34f;
            for (int i = 0; i < PENS.Length; i++)
            {
                Rect pr = new Rect(r.x + i * (s + 6), r.y, s, s);
                Box(pr, PENS[i], s / 2);
                bool sel = penColor == PENS[i];
                Border(pr, sel ? P.accent : Draw.A(P.text, 0.4f), sel ? 4 : 2, s / 2);
                if (GUI.Button(pr, GUIContent.none, GUIStyle.none)) penColor = PENS[i];
            }
            float y = r.y + s + 6;
            float[] widths = { 0.06f, 0.12f, 0.24f };
            string[] wn = { "тонко", "средне", "толсто" };
            float bw = (Mathf.Max(r.width, 300f) - 16f) / 5f;
            for (int i = 0; i < 3; i++)
                if (Btn(new Rect(r.x + i * (bw + 4), y, bw, 34), wn[i], 14, false, Mathf.Abs(penWidth - widths[i]) < 0.001f)) penWidth = widths[i];
            if (Btn(new Rect(r.x + 3 * (bw + 4), y, bw, 34), "назад", 14)) { if (strokes.Count > 0) { strokes.RemoveAt(strokes.Count - 1); MarkDirty(); } }
            if (Btn(new Rect(r.x + 4 * (bw + 4), y, bw, 34), "стереть", 14)) { strokes.Clear(); MarkDirty(); }
        }

        // ===================== НАСТРОЙКИ =====================
        void SettingsScreen()
        {
            Box(new Rect(0, 0, VW, VH), Draw.A(Color.black, 0.35f), 0);
            float w = 980, h = 1000;
            Rect r = new Rect((VW - w) / 2, (VH - h) / 2, w, h);
            Panel(r);
            Txt(new Rect(r.x, r.y + 14, r.width, 60), "НАСТРОЙКИ", 46, P.text, TextAnchor.MiddleCenter, true);
            float x = r.x + 50, cw = r.width - 100, y = r.y + 90;

            S.musicOn = Toggle(new Rect(x, y, cw, 50), "Музыка", S.musicOn, 26); y += 60;
            S.musicVol = Slider(new Rect(x, y, cw, 70), "Громкость музыки", S.musicVol, 0f, 1f, Mathf.RoundToInt(S.musicVol * 100) + "%"); y += 78;
            S.sfxVol = Slider(new Rect(x, y, cw, 70), "Громкость звуков", S.sfxVol, 0f, 1f, Mathf.RoundToInt(S.sfxVol * 100) + "%"); y += 84;

            Txt(new Rect(x, y, cw, 34), "Своя музыка: прямая ссылка на .mp3 / .ogg / .wav или путь к файлу", 22, P.text, TextAnchor.MiddleLeft, true); y += 40;
            S.musicUrl = GUI.TextField(new Rect(x, y, cw - 200, 50), S.musicUrl ?? "", 500, stField);
            if (Btn(new Rect(x + cw - 186, y, 186, 50), audio.loadingUrl ? "..." : "ЗАГРУЗИТЬ", 22, true) && !audio.loadingUrl) { audio.LoadUrl(S.musicUrl); Save(); }
            y += 56;
            Txt(new Rect(x, y, cw, 30), string.IsNullOrEmpty(audio.urlStatus) ? "Встроенный эпичный саундтрек генерируется прямо в игре." : audio.urlStatus, 19, P.sub); y += 34;
            if (audio.HasCustom)
            {
                bool before = S.useCustomMusic;
                S.useCustomMusic = Toggle(new Rect(x, y, cw, 46), "Играть свою музыку вместо встроенной", S.useCustomMusic, 22);
                if (before != S.useCustomMusic) audio.RefreshMusic();
                y += 52;
            }
            else y += 10;

            string bl = S.blood < 0.05f ? "без крови" : S.blood < 0.6f ? "немного" : S.blood < 1.4f ? "норма" : "МОРЕ КРОВИ";
            S.blood = Slider(new Rect(x, y, cw, 70), "Кровь", S.blood, 0f, 2f, bl); y += 84;
            float half = (cw - 20) / 2f;
            S.shake = Toggle(new Rect(x, y, half, 48), "Тряска камеры", S.shake, 22);
            S.slowmo = Toggle(new Rect(x + half + 20, y, half, 48), "Замедление (slow-mo)", S.slowmo, 22); y += 56;
            S.damageNumbers = Toggle(new Rect(x, y, half, 48), "Цифры урона", S.damageNumbers, 22);
            S.overheadBars = Toggle(new Rect(x + half + 20, y, half, 48), "Полоски HP над головой", S.overheadBars, 22); y += 56;
            S.keepBloodOnStop = Toggle(new Rect(x, y, cw, 48), "Оставлять кровь, когда бой останавливают и бойцы возвращаются", S.keepBloodOnStop, 22); y += 60;

            if (Btn(new Rect(r.x + (r.width - 360) / 2, r.yMax - 100, 360, 74), "ГОТОВО", 32, true)) { Save(); scr = settingsBack; }
        }

        // ===================== КАК ИГРАТЬ =====================
        void Help()
        {
            Box(new Rect(0, 0, VW, VH), Draw.A(Color.black, 0.35f), 0);
            float w = Mathf.Min(1500, VW - 80), h = 960;
            Rect r = new Rect((VW - w) / 2, (VH - h) / 2, w, h);
            Panel(r);
            Txt(new Rect(r.x, r.y + 14, r.width, 60), "КАК ИГРАТЬ", 46, P.text, TextAnchor.MiddleCenter, true);
            string left =
                "1. Открой «Бойцы и оружие» и создай героев (до 4 за сторону).\n" +
                "2. Опиши героя словами: «огромный рогатый демон, очень сильный, бьёт по земле и кидает огненные шары, боится льда». Арена сама сгенерирует внешность, характеристики и способности.\n" +
                "3. Нарисуй ему что-нибудь на голове в планшете — рисунок появится на бойце.\n" +
                "4. Укажи оружие словами («ледяное копьё», «бензопила», «дробовик»…) или опиши новое в арсенале — оно будет падать с неба.\n" +
                "5. Бессмертия нет: у каждого есть слабость, урон по ней удваивается и выключает регенерацию.\n" +
                "6. Выбери стиль арены и жми «В БОЙ!». Esc — пауза: можно остановить бой и вернуть всех на исходные.";
            Txt(new Rect(r.x + 50, r.y + 100, w * 0.55f - 60, h - 220), left, 23, P.text, TextAnchor.UpperLeft, false, true);
            string right =
                "УПРАВЛЕНИЕ (если включено)\n\n" +
                "Игрок 1 (красные):\n  A / D — бег,  W — прыжок,  S — блок\n  F — удар/оружие,  G — пинок\n  R, T, Y — способности\n\n" +
                "Игрок 2 (синие):\n  ← / → — бег,  ↑ — прыжок,  ↓ — блок\n  K — удар/оружие,  L — пинок\n  I, O, P — способности\n\n" +
                "Подбор оружия — просто пробеги по нему.\nОстальные бойцы сражаются сами.";
            Txt(new Rect(r.x + w * 0.55f + 10, r.y + 100, w * 0.45f - 60, h - 220), right, 23, P.text, TextAnchor.UpperLeft, false, true);
            if (Btn(new Rect(r.x + (r.width - 360) / 2, r.yMax - 100, 360, 74), "ПОНЯТНО", 32, true)) scr = Scr.Main;
        }

        // ===================== HUD =====================
        void Hud()
        {
            var b = battle;
            // счёт
            Rect score = new Rect(VW / 2 - 200, 14, 400, 64);
            Box(score, Draw.A(P.panel, 0.75f), 14);
            Txt(new Rect(score.x, score.y, 170, 64), b.wins[0].ToString(), 44, new Color(0.95f, 0.3f, 0.25f), TextAnchor.MiddleRight, true);
            Txt(score, ":", 44, P.text, TextAnchor.MiddleCenter, true);
            Txt(new Rect(score.x + 230, score.y, 170, 64), b.wins[1].ToString(), 44, new Color(0.35f, 0.6f, 1f), TextAnchor.MiddleLeft, true);
            if (scr == Scr.Battle && Btn(new Rect(VW / 2 - 32, 86, 64, 48), "II", 24)) Pause();

            int ri = 0, bi = 0;
            foreach (var f in b.fighters)
            {
                if (f.team == 0) TeamBar(new Rect(20, 16 + ri++ * 74, 520, 66), f, false);
                else TeamBar(new Rect(VW - 540, 16 + bi++ * 74, 520, 66), f, true);
            }

            // интро
            if (b.phase == Battle.Phase.Intro)
            {
                float k = b.phaseT / Battle.IntroTime;
                string rn = b.fighters.Count > 0 ? TeamName(0) : "";
                string bn = TeamName(1);
                float slide = Mathf.Clamp01(k * 3f);
                Outline(new Rect(-VW * (1 - slide) * 0.5f, VH * 0.35f, VW / 2 - 80, 100), rn, 52, new Color(1f, 0.35f, 0.3f), Color.black, TextAnchor.MiddleRight, 3f);
                Outline(new Rect(VW / 2 + 80 + VW * (1 - slide) * 0.5f, VH * 0.35f, VW / 2 - 80, 100), bn, 52, new Color(0.4f, 0.65f, 1f), Color.black, TextAnchor.MiddleLeft, 3f);
                Outline(new Rect(0, VH * 0.35f, VW, 100), "VS", (int)(80 + Mathf.Sin(Time.unscaledTime * 10f) * 6f), Color.white, Color.black, TextAnchor.MiddleCenter, 4f);
            }

            // крупные объявления
            if (b.announceT > 0 && !string.IsNullOrEmpty(b.announce))
            {
                float age = Mathf.Max(0f, b.announceMax - b.announceT);
                float pop = age < 0.15f ? Mathf.Lerp(2.2f, 1f, age / 0.15f) : 1f;
                int size = (int)(110 * pop);
                Outline(new Rect(0, VH * 0.18f, VW, 180), b.announce, size, b.announceCol, Color.black, TextAnchor.MiddleCenter, 5f);
            }

            // победа
            if (b.phase == Battle.Phase.Victory && b.mode == Battle.Mode.Fight && b.phaseT > 1.4f && scr == Scr.Battle)
            {
                Fighter mvp = null;
                foreach (var f in b.fighters) if (mvp == null || f.dmgDealt > mvp.dmgDealt) mvp = f;
                Rect pr = new Rect(VW / 2 - 330, VH * 0.48f, 660, 380);
                Panel(pr);
                if (mvp != null)
                {
                    Txt(new Rect(pr.x, pr.y + 16, pr.width, 40), "MVP: " + mvp.B.name, 32, P.accent, TextAnchor.MiddleCenter, true);
                    Txt(new Rect(pr.x, pr.y + 56, pr.width, 30), "урон: " + Mathf.RoundToInt(mvp.dmgDealt) + "   убийств: " + mvp.kills, 22, P.sub, TextAnchor.MiddleCenter);
                }
                if (Btn(new Rect(pr.x + 40, pr.y + 110, pr.width - 80, 70), "РЕВАНШ", 32, true)) RestartClean();
                if (Btn(new Rect(pr.x + 40, pr.y + 195, pr.width - 80, 70), "ИЗМЕНИТЬ КОМАНДЫ", 28)) ToMenu(Scr.Teams);
                if (Btn(new Rect(pr.x + 40, pr.y + 280, pr.width - 80, 70), "ГЛАВНОЕ МЕНЮ", 28)) ToMenu(Scr.Main);
            }

            // подсказки управления
            if (scr == Scr.Battle && b.phase != Battle.Phase.Victory)
            {
                foreach (var f in b.fighters)
                {
                    if (!f.human || f.dead) continue;
                    string keys = f.pindex == 0 ? "A D бег • W прыжок • S блок • F удар • G пинок • R T Y умения" : "← → бег • ↑ прыжок • ↓ блок • K удар • L пинок • I O P умения";
                    Rect hr = f.pindex == 0 ? new Rect(20, VH - 50, 800, 36) : new Rect(VW - 820, VH - 50, 800, 36);
                    Outline(hr, keys, 19, Color.white, new Color(0, 0, 0, 0.7f), f.pindex == 0 ? TextAnchor.MiddleLeft : TextAnchor.MiddleRight, 1.5f);
                }
                Txt(new Rect(0, VH - 40, VW, 30), "Esc — пауза", 18, Draw.A(P.sub, 0.8f), TextAnchor.MiddleCenter);
            }
        }

        string TeamName(int team)
        {
            string s = "";
            int n = 0;
            foreach (var f in battle.fighters)
            {
                if (f.team != team) continue;
                if (n < 2) s += (s.Length > 0 ? " & " : "") + f.B.name;
                n++;
            }
            if (n > 2) s += " +" + (n - 2);
            return s;
        }

        void TeamBar(Rect r, Fighter f, bool right)
        {
            Color tc = f.team == 0 ? new Color(0.95f, 0.28f, 0.22f) : new Color(0.33f, 0.58f, 1f);
            Box(r, Draw.A(P.panel, f.dead ? 0.45f : 0.78f), 10);
            Rect sw = right ? new Rect(r.xMax - 46, r.y + 12, 34, 34) : new Rect(r.x + 12, r.y + 12, 34, 34);
            Box(sw, f.B.color, 17);
            Border(sw, Draw.A(P.text, 0.5f), 2, 17);
            float tx = right ? r.x + 12 : r.x + 56;
            string nm = (f.human ? (f.pindex == 0 ? "[P1] " : "[P2] ") : "") + f.B.name + (f.dead ? "  — ПАЛ" : "");
            Txt(new Rect(tx, r.y + 2, r.width - 70, 30), nm, 21, f.dead ? P.sub : P.text, right ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft, true);
            Rect bar = new Rect(tx, r.y + 36, r.width - 70, 18);
            Box(bar, new Color(0, 0, 0, 0.45f), 6);
            float k = Mathf.Clamp01(f.hp / f.maxHp);
            Rect fill = right ? new Rect(bar.xMax - bar.width * k, bar.y, bar.width * k, bar.height) : new Rect(bar.x, bar.y, bar.width * k, bar.height);
            if (k > 0) Box(fill, k < 0.3f ? Color.Lerp(tc, Color.white, Mathf.PingPong(Time.unscaledTime * 3f, 0.5f)) : tc, 6);
            // иконки статусов и перезарядки умений
            int idx = 0;
            foreach (var a in f.ActiveAbilities())
            {
                float c = f.CooldownOf(a) / Info.Cooldown(a);
                Rect ir = right ? new Rect(bar.x + idx * 22, r.y + 8, 18, 18) : new Rect(bar.xMax - 18 - idx * 22, r.y + 8, 18, 18);
                Box(ir, c <= 0 ? new Color(1f, 0.85f, 0.2f) : new Color(0.4f, 0.4f, 0.4f, 0.8f), 9);
                idx++;
            }
            string st = "";
            if (f.burnT > 0) st += "горит ";
            if (f.poisonT > 0) st += "яд ";
            if (f.bleedT > 0) st += "кровоточит ";
            if (f.slowT > 0) st += "заморожен ";
            if (f.shieldT > 0) st += "щит ";
            if (f.RageOn) st += "ЯРОСТЬ ";
            if (f.weapon != null) st += "[" + f.weapon.name + (f.weapon.Ranged ? " " + f.ammo : "") + "]";
            if (st.Length > 0) Txt(new Rect(tx, r.y + 52, r.width - 70, 16), st, 14, P.sub, right ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft);
        }

        // ===================== ПАУЗА =====================
        void PauseMenu()
        {
            Box(new Rect(0, 0, VW, VH), new Color(0, 0, 0, 0.5f), 0);
            float w = 640, h = 640;
            Rect r = new Rect((VW - w) / 2, (VH - h) / 2, w, h);
            Panel(r);
            Txt(new Rect(r.x, r.y + 16, r.width, 64), "ПАУЗА", 54, P.text, TextAnchor.MiddleCenter, true);
            float x = r.x + 50, bw = w - 100, y = r.y + 100;
            if (Btn(new Rect(x, y, bw, 70), "ПРОДОЛЖИТЬ", 30, true)) Resume(); y += 82;
            if (Btn(new Rect(x, y, bw, 70), "ОСТАНОВИТЬ БОЙ — НА ИСХОДНЫЕ", 24)) StopToStart(); y += 82;
            if (Btn(new Rect(x, y, bw, 70), "НАЧАТЬ ЗАНОВО (ЧИСТАЯ АРЕНА)", 24)) RestartClean(); y += 82;
            if (Btn(new Rect(x, y, bw, 70), "НАСТРОЙКИ", 28)) { settingsBack = Scr.Pause; scr = Scr.Settings; } y += 82;
            if (Btn(new Rect(x, y, bw, 70), "ИЗМЕНИТЬ КОМАНДЫ", 28)) ToMenu(Scr.Teams); y += 82;
            if (Btn(new Rect(x, y, bw, 70), "ГЛАВНОЕ МЕНЮ", 28)) ToMenu(Scr.Main);
        }
    }
}
