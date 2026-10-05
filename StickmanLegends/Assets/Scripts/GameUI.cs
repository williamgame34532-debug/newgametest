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
        Vector2 descScroll;
        float editChangeT;
        string lastName, lastDesc, lastWeap;
        string editUrl = "", urlLoadStatus = "";
        bool urlLoading;
        // кэш разбора: раньше список бойцов разбирал все описания на каждой перерисовке — отсюда лаги
        readonly Dictionary<string, FighterBuild> buildCache = new Dictionary<string, FighterBuild>();
        FighterBuild CachedBuild(FighterDef d)
        {
            string key = (d.name ?? "") + "\u0001" + (d.description ?? "") + "\u0001" + (d.weaponDesc ?? "") + "\u0001" + d.color + "\u0001" + (d.drawing != null ? d.drawing.Count : 0) + "\u0001" + data.weapons.Count;
            FighterBuild b;
            if (buildCache.TryGetValue(key, out b)) return b;
            if (buildCache.Count > 64) buildCache.Clear();
            b = Parser.BuildFighter(d, data.weapons);
            buildCache[key] = b;
            return b;
        }

        // описание персонажа с сайта: скачиваем страницу, вычищаем HTML, берём текст
        System.Collections.IEnumerator LoadDescriptionFromUrl(string url)
        {
            urlLoading = true; urlLoadStatus = "Загрузка страницы...";
            url = url.Trim();
            if (!url.StartsWith("http")) url = "https://" + url;
            using (var req = UnityEngine.Networking.UnityWebRequest.Get(url))
            {
                req.timeout = 20;
                yield return req.SendWebRequest();
                if (req.result != UnityEngine.Networking.UnityWebRequest.Result.Success)
                {
                    urlLoadStatus = "Не удалось загрузить: " + req.error;
                    urlLoading = false;
                    yield break;
                }
                string title;
                string text = WebText.Extract(req.downloadHandler.text, out title);
                if (string.IsNullOrEmpty(text)) { urlLoadStatus = "На странице не найден текст"; urlLoading = false; yield break; }
                if (text.Length > DescLimit) text = text.Substring(0, DescLimit);
                editDef.description = text;
                if (!string.IsNullOrEmpty(title) && (string.IsNullOrEmpty(editDef.name) || editDef.name == "Боец")) editDef.name = title.Length > 40 ? title.Substring(0, 40) : title;
                urlLoadStatus = "Загружено " + text.Length + " символов — арена разбирает описание";
                MarkDirty();
            }
            urlLoading = false;
        }
        const int DescLimit = 12000;
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
                    else if (scr == Scr.Replay) { battle.StopReplay(); scr = Scr.Battle; }
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
                case Scr.Replay: ReplayScreen(); break;
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
        Texture2D vignette;
        float letterbox;

        Texture2D Vignette()
        {
            if (vignette != null) return vignette;
            int n = 128;
            vignette = new Texture2D(n, n, TextureFormat.RGBA32, false);
            vignette.wrapMode = TextureWrapMode.Clamp;
            var px = new Color[n * n];
            for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float dx = (x + 0.5f) / n * 2f - 1f, dy = (y + 0.5f) / n * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx * 0.8f + dy * dy);
                    float a = Mathf.Clamp01((d - 0.55f) / 0.6f);
                    px[y * n + x] = new Color(0, 0, 0, a * a);
                }
            vignette.SetPixels(px);
            vignette.Apply();
            return vignette;
        }

        // кляксы крови для брызг на экран: неровное пятно + капли-спутники
        Texture2D[] splatTex;
        Texture2D SplatTex(int seed)
        {
            if (splatTex == null) splatTex = new Texture2D[4];
            int id = Mathf.Abs(seed) % 4;
            if (splatTex[id] != null) return splatTex[id];
            int n = 128;
            var t = new Texture2D(n, n, TextureFormat.RGBA32, false);
            t.wrapMode = TextureWrapMode.Clamp;
            var rnd = new System.Random(id * 7919 + 13);
            var blobs = new List<Vector3>();
            blobs.Add(new Vector3(0.5f, 0.5f, 0.2f));
            for (int i = 0; i < 9; i++) { float a = (float)rnd.NextDouble() * 6.28f, d = 0.08f + (float)rnd.NextDouble() * 0.12f; blobs.Add(new Vector3(0.5f + Mathf.Cos(a) * d, 0.5f + Mathf.Sin(a) * d, 0.06f + (float)rnd.NextDouble() * 0.07f)); }
            for (int i = 0; i < 14; i++) { float a = (float)rnd.NextDouble() * 6.28f, d = 0.25f + (float)rnd.NextDouble() * 0.2f; blobs.Add(new Vector3(0.5f + Mathf.Cos(a) * d, 0.5f + Mathf.Sin(a) * d, 0.012f + (float)rnd.NextDouble() * 0.025f)); }
            // потёк вниз
            for (int i = 0; i < 10; i++) blobs.Add(new Vector3(0.5f + (float)rnd.NextDouble() * 0.04f - 0.02f, 0.45f - i * 0.035f, 0.035f - i * 0.002f));
            var px = new Color[n * n];
            for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float fx = (x + 0.5f) / n, fy = (y + 0.5f) / n, a = 0f;
                    foreach (var b in blobs) { float d = Mathf.Sqrt((fx - b.x) * (fx - b.x) + (fy - b.y) * (fy - b.y)); a = Mathf.Max(a, Mathf.Clamp01((b.z - d) / 0.012f)); }
                    // тёмная кромка и влажный центр
                    float edge = 1f - Mathf.Clamp01(Mathf.Sqrt((fx - 0.5f) * (fx - 0.5f) + (fy - 0.5f) * (fy - 0.5f)) / 0.3f);
                    float v = Mathf.Lerp(0.55f, 1f, edge);
                    px[y * n + x] = new Color(v, v, v, a);
                }
            t.SetPixels(px); t.Apply();
            splatTex[id] = t;
            return t;
        }

        // поверх мира: виньетка, кинематографичные полосы, вспышка удара, полоски HP, всплывающие надписи
        void WorldOverlay()
        {
            bool fight = scr == Scr.Battle || scr == Scr.Pause;
            bool replay = scr == Scr.Replay;
            if (Event.current.type == EventType.Repaint)
            {
                float va = data.theme == 0 ? 0.25f : data.theme == 4 || data.theme >= 11 ? 0.75f : 0.5f;
                GUI.DrawTexture(new Rect(0, 0, VW, VH), Vignette(), ScaleMode.StretchToFill, true, 0, new Color(data.theme == 0 ? 0.35f : 0f, data.theme == 0 ? 0.25f : 0f, data.theme == 0 ? 0.1f : 0f, va), 0, 0);
                if (S.grim && (fight || replay))
                {
                    // мрачная атмосфера: тяжёлая багрово-чёрная виньетка и лёгкое затемнение кадра
                    GUI.DrawTexture(new Rect(-VW * 0.08f, -VH * 0.08f, VW * 1.16f, VH * 1.16f), Vignette(), ScaleMode.StretchToFill, true, 0, new Color(0.12f, 0f, 0.01f, 0.85f), 0, 0);
                    Box(new Rect(0, 0, VW, VH), new Color(0.03f, 0f, 0.02f, 0.12f), 0);
                    // пульс при низком здоровье управляемого бойца (или героя выживания)
                    float low = 0f;
                    foreach (var f in battle.fighters) if ((f.human || battle.mode == Battle.Mode.Survival && f == battle.hero) && !f.dead) low = Mathf.Max(low, 1f - Mathf.Clamp01(f.hp / (f.maxHp * 0.3f)));
                    if (low > 0f)
                        GUI.DrawTexture(new Rect(0, 0, VW, VH), Vignette(), ScaleMode.StretchToFill, true, 0, new Color(0.6f, 0f, 0.02f, low * (0.45f + Mathf.Sin(Time.unscaledTime * 7f) * 0.25f)), 0, 0);
                }
            }
            if ((fight || replay) && Event.current.type == EventType.Repaint)
            {
                Particles.TickSplats(Time.unscaledDeltaTime);
                foreach (var sp in Particles.ScreenSplats)
                {
                    float k = Mathf.Clamp01(sp.t / sp.max);
                    float sz = sp.r * VW * (1.15f - k * 0.15f);
                    Color c = sp.c; c.a *= Mathf.Clamp01(k * 2.5f);
                    GUI.DrawTexture(new Rect(sp.p.x * VW - sz / 2, (1f - sp.p.y) * VH - sz / 2, sz, sz), SplatTex(sp.seed), ScaleMode.StretchToFill, true, 0, c, 0, 0);
                }
            }
            float want = fight ? Mathf.Clamp01(battle.SlowAmount / 0.6f) : 0f;
            if (fight && battle.phase == Battle.Phase.Intro && battle.mode == Battle.Mode.Fight) want = 1f;
            if (replay) want = 1f;
            letterbox = Mathf.MoveTowards(letterbox, want, Time.unscaledDeltaTime * 3f);
            if (letterbox > 0.01f)
            {
                float h = 95f * letterbox;
                Box(new Rect(0, 0, VW, h), Color.black, 0);
                Box(new Rect(0, VH - h, VW, h), Color.black, 0);
            }
            if (battle.curStyle == 11 && Event.current.type == EventType.Repaint)
            {
                // «старое кино»: мерцание, зерно, царапины
                Box(new Rect(0, 0, VW, VH), new Color(0.3f, 0.22f, 0.1f, 0.12f + Random.value * 0.06f), 0);
                for (int i = 0; i < 160; i++) { float x = Random.value * VW, y = Random.value * VH; Box(new Rect(x, y, 2, 2), new Color(0, 0, 0, 0.35f), 0); }
                for (int i = 0; i < 3; i++) if (Random.value < 0.5f) { float x = Random.value * VW; Box(new Rect(x, 0, 1.5f, VH), new Color(0.1f, 0.08f, 0.05f, 0.3f), 0); }
            }
            if (battle.curStyle == 10 && Event.current.type == EventType.Repaint)
                for (int y = 0; y < VH; y += 6) Box(new Rect(0, y, VW, 1.5f), new Color(0, 0, 0, 0.18f), 0);
            if (battle.flashT > 0f)
            {
                Color fc = battle.flashCol; fc.a *= Mathf.Clamp01(battle.flashT / 0.06f);
                Box(new Rect(0, 0, VW, VH), fc, 0);
            }

            if (fight && S.overheadBars)
                foreach (var f in battle.fighters)
                {
                    if (f.dead || (f.Invisible && !f.human)) continue;
                    if (battle.mode == Battle.Mode.Survival && f != battle.hero && !f.boss && f.hp >= f.maxHp) continue;
                    Vector2 g = W2G(f.HeadPos + Vector2.up * (0.55f * f.Size + 0.25f));
                    Rect bar = new Rect(g.x - 42, g.y, 84, 9);
                    Color tc = f.team == 0 ? new Color(0.95f, 0.25f, 0.2f) : new Color(0.3f, 0.55f, 1f);
                    Box(new Rect(bar.x - 2, bar.y - 2, bar.width + 4, bar.height + 4), new Color(0, 0, 0, 0.6f), 4);
                    Box(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(f.hpTrail / f.maxHp), bar.height), new Color(1f, 0.95f, 0.8f, 0.9f), 3);
                    Box(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(f.hp / f.maxHp), bar.height), tc, 3);
                    string nm = f.human ? (f.pindex == 0 ? "P1 " : "P2 ") + f.B.name : f.B.name;
                    Outline(new Rect(g.x - 150, g.y - 30, 300, 26), nm, 18, Color.white, new Color(0, 0, 0, 0.8f), TextAnchor.MiddleCenter, 1.5f);
                    if (f.body == Fighter.BodyS.Down) Outline(new Rect(g.x - 100, g.y + 12, 200, 24), "НОКДАУН", 16, new Color(1f, 0.8f, 0.3f), Color.black, TextAnchor.MiddleCenter, 1.5f);
                }
            foreach (var p in battle.popups)
            {
                Vector2 g = W2G(p.pos);
                float k = p.t / p.life;
                float pop = k < 0.1f ? Mathf.Lerp(1.8f, 1f, k / 0.1f) : 1f;
                int size = (int)(42 * p.size * pop * (fight ? 1f : 0.8f));
                Color c = p.col; c.a = 1f - Mathf.Clamp01((k - 0.6f) / 0.4f);
                Outline(new Rect(g.x - 300, g.y - 40, 600, 80), p.text, size, c, new Color(0, 0, 0, c.a * 0.9f), TextAnchor.MiddleCenter, 3f);
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
            if (Btn(new Rect(80, 405, 190, 64), "1 ИГРОК", 24, false, !data.twoPlayers && !data.survival)) { data.twoPlayers = false; data.survival = false; Save(); }
            if (Btn(new Rect(282, 405, 190, 64), "2 ИГРОКА", 24, false, data.twoPlayers && !data.survival)) { data.twoPlayers = true; data.survival = false; data.p1Control = true; data.p2Control = true; Save(); }
            if (Btn(new Rect(484, 405, 300, 64), "ОДИН ПРОТИВ ВСЕХ", 24, false, data.survival)) { data.survival = true; data.twoPlayers = false; Save(); }
            string modeTxt = data.survival
                ? "Твой герой (первый красный боец) против бесконечных волн стикменов со всех сторон. Передышки лечат. Рекорд: волна " + data.survivalBest + "."
                : data.twoPlayers ? "Каждый создаёт бойцов за свою сторону и может управлять лидером на одной клавиатуре." : "Ты описываешь обе команды и смотришь эпичный бой (или управляешь красным лидером).";
            Txt(new Rect(80, 475, 720, 60), modeTxt, 21, P.sub, TextAnchor.UpperLeft, false, true);

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
            if (Btn(fight, data.survival ? "В РЕЗНЮ!" : "В БОЙ!", 44, true)) StartBattle();
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
            if (Btn(new Rect(gap + 290, by + 10, 60, 60), "<", 26)) { SetTheme((data.theme + Theme.Count - 1) % Theme.Count); StartDemo(); }
            Box(new Rect(gap + 356, by + 10, 300, 60), Draw.A(P.btn, 0.9f), 10);
            Txt(new Rect(gap + 356, by + 10, 300, 60), "Арена: " + Theme.Names[data.theme], 22, P.btnText, TextAnchor.MiddleCenter, true);
            if (Btn(new Rect(gap + 662, by + 10, 60, 60), ">", 26)) { SetTheme((data.theme + 1) % Theme.Count); StartDemo(); }
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
                var b = CachedBuild(d);
                string ab = "";
                foreach (var a in b.abilities) ab += (ab.Length > 0 ? ", " : "") + Info.Name(a).Replace(" (пассив)", "");
                Txt(new Rect(row.x + 62, row.y + 46, row.width - 80, 28), ab, 18, P.sub);
                Txt(new Rect(row.x + 62, row.y + 74, row.width - 80, 28), (b.weapon != null ? b.weapon.name : "Кулаки") + "  •  смерть: " + b.WeakText.ToLower(), 18, P.sub);
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
                b = CachedBuild(editDef);
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

            Txt(new Rect(x, y, w - 200, 34), "Опиши героя: внешность, способности, превращения, слабость", 23, P.sub, TextAnchor.MiddleLeft, true);
            Txt(new Rect(x + w - 200, y, 200, 34), (editDef.description ?? "").Length + " / " + DescLimit, 17, P.sub, TextAnchor.MiddleRight);
            y += 38;
            descScroll = GUI.BeginScrollView(new Rect(x, y, w, 136), descScroll, new Rect(0, 0, w - 20, Mathf.Max(136f, stArea.CalcHeight(new GUIContent(editDef.description ?? ""), w - 20))));
            editDef.description = GUI.TextArea(new Rect(0, 0, w - 20, Mathf.Max(136f, stArea.CalcHeight(new GUIContent(editDef.description ?? ""), w - 20))), editDef.description ?? "", DescLimit, stArea);
            GUI.EndScrollView();
            y += 142;
            // ссылка на страницу с описанием персонажа
            Txt(new Rect(x, y + 2, 120, 40), "Сайт", 20, P.sub, TextAnchor.MiddleLeft, true);
            editUrl = GUI.TextField(new Rect(x + 80, y, w - 300, 40), editUrl ?? "", 500, stField);
            if (Btn(new Rect(x + w - 210, y, 210, 40), urlLoading ? "загрузка..." : "Взять описание", 17) && !urlLoading && !string.IsNullOrEmpty(editUrl)) StartCoroutine(LoadDescriptionFromUrl(editUrl));
            y += 44;
            Txt(new Rect(x, y, w, 26), string.IsNullOrEmpty(urlLoadStatus) ? "Можно вставить готовый текст или ссылку на страницу персонажа. Бессмертие отключается, слабость ищется в тексте." : urlLoadStatus, 16, P.sub, TextAnchor.UpperLeft, false, true);
            y += 28;

            Txt(new Rect(x, y, 200, 40), "Оружие", 24, P.sub, TextAnchor.MiddleLeft, true);
            editDef.weaponDesc = GUI.TextField(new Rect(x + 120, y, w - 120, 46), editDef.weaponDesc ?? "", 600, stField);
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
            Txt(new Rect(x, y, w, 44), (b.killOnly ? "Убить можно ТОЛЬКО: " : "Слабость (урон x2): ") + b.WeakText.Replace("ТОЛЬКО ", ""), 19, new Color(1f, 0.55f, 0.15f), TextAnchor.UpperLeft, true, true); y += 46;
            if (b.immuneMask != 0) { Txt(new Rect(x, y, w, 26), "Иммунитет: " + HFInfo.Describe(b.immuneMask), 18, new Color(0.5f, 0.75f, 1f), TextAnchor.MiddleLeft, true); y += 26; }
            if (b.style != Style.Balanced) { Txt(new Rect(x, y, w, 26), "Стиль: " + Parser.StyleName(b.style), 18, P.text); y += 26; }
            if (b.understood.Count > 0)
            {
                string u = "";
                for (int i = 1; i < b.understood.Count; i++) u += (u.Length > 0 ? ", " : "") + b.understood[i];
                if (u.Length > 0) { Txt(new Rect(x, y, w, 46), "Понял: " + u, 16, new Color(0.3f, 0.75f, 0.35f), TextAnchor.UpperLeft, false, true); y += 44; }
            }
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
            editWeapon.description = GUI.TextArea(new Rect(x, y, w, 130), editWeapon.description ?? "", 4000, stArea);
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
            float w = 1000, h = 1076;
            Rect r = new Rect((VW - w) / 2, (VH - h) / 2, w, h);
            Panel(r);
            Txt(new Rect(r.x, r.y + 14, r.width, 60), "НАСТРОЙКИ", 46, P.text, TextAnchor.MiddleCenter, true);
            float x = r.x + 50, cw = r.width - 100, y = r.y + 90;

            S.musicOn = Toggle(new Rect(x, y, cw, 50), "Музыка", S.musicOn, 26); y += 60;
            float hv = (cw - 30) / 2f;
            S.musicVol = Slider(new Rect(x, y, hv, 70), "Музыка", S.musicVol, 0f, 1f, Mathf.RoundToInt(S.musicVol * 100) + "%");
            S.sfxVol = Slider(new Rect(x + hv + 30, y, hv, 70), "Звуки", S.sfxVol, 0f, 1f, Mathf.RoundToInt(S.sfxVol * 100) + "%"); y += 80;

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
            // своя музыка для «Один против всех»
            Txt(new Rect(x, y, 330, 44), "«Один против всех»:", 19, P.text, TextAnchor.MiddleLeft, true);
            S.survivalMusicUrl = GUI.TextField(new Rect(x + 330, y, cw - 330 - 200, 44), S.survivalMusicUrl ?? "", 500, stField);
            if (Btn(new Rect(x + cw - 186, y, 186, 44), audio.loadingUrl ? "..." : "ЗАГРУЗИТЬ", 19) && !audio.loadingUrl) { audio.LoadUrl(S.survivalMusicUrl, 1); Save(); }
            y += 48;
            if (audio.HasCustomSurvival)
            {
                bool b0 = S.useCustomSurvival;
                S.useCustomSurvival = Toggle(new Rect(x, y, cw, 40), "Своя музыка в режиме выживания  " + audio.urlStatus2, S.useCustomSurvival, 18);
                if (b0 != S.useCustomSurvival) audio.RefreshMusic();
                y += 44;
            }
            else { Txt(new Rect(x, y, cw, 26), string.IsNullOrEmpty(audio.urlStatus2) ? "Без ссылки играет встроенный тяжёлый трек выживания." : audio.urlStatus2, 17, P.sub); y += 30; }

            string bl = S.blood < 0.05f ? "без крови" : S.blood < 0.6f ? "немного" : S.blood < 1.4f ? "норма" : "МОРЕ КРОВИ";
            S.blood = Slider(new Rect(x, y, cw, 70), "Кровь", S.blood, 0f, 2f, bl); y += 84;
            float half = (cw - 20) / 2f;
            S.shake = Toggle(new Rect(x, y, half, 48), "Тряска камеры", S.shake, 22);
            S.slowmo = Toggle(new Rect(x + half + 20, y, half, 48), "Замедление (slow-mo)", S.slowmo, 22); y += 56;
            S.damageNumbers = Toggle(new Rect(x, y, half, 48), "Цифры урона", S.damageNumbers, 22);
            S.overheadBars = Toggle(new Rect(x + half + 20, y, half, 48), "Полоски HP над головой", S.overheadBars, 22); y += 56;
            S.styleShift = Toggle(new Rect(x, y, half, 48), "Рисовка меняется в бою", S.styleShift, 22);
            S.tempoRamp = Toggle(new Rect(x + half + 20, y, half, 48), "Темп боя растёт", S.tempoRamp, 22); y += 56;
            Txt(new Rect(x, y, 260, 44), "Вид бойцов:", 22, P.text, TextAnchor.MiddleLeft, true);
            string[] looks = { "Dojo (силуэты)", "Классика (контур)", "Простой" };
            for (int i = 0; i < 3; i++) if (Btn(new Rect(x + 170 + i * 200, y, 190, 44), looks[i], 18, false, S.stickLook == i)) S.stickLook = i;
            y += 50;
            float third = (cw - 40) / 3f;
            S.always3d = Toggle(new Rect(x, y, third, 44), "Постоянный 3D-вид", S.always3d, 19);
            S.cine3d = Toggle(new Rect(x + third + 20, y, third, 44), "3D-облёты", S.cine3d, 19);
            S.grim = Toggle(new Rect(x + (third + 20) * 2, y, third, 44), "Мрачная атмосфера", S.grim, 19); y += 50;
            S.recordVideo = Toggle(new Rect(x, y, half, 48), "Записывать видео каждого боя", S.recordVideo, 22);
            if (Btn(new Rect(x + half + 20, y + 2, 260, 44), "Папка с видео", 20) && VideoRecorder.I != null)
            {
                VideoRecorder.I.lastDir = System.IO.Path.Combine(Application.persistentDataPath, "Duels");
                try { System.IO.Directory.CreateDirectory(VideoRecorder.I.lastDir); } catch { }
                VideoRecorder.I.OpenFolder();
            }
            y += 56;
            S.screenBlood = Toggle(new Rect(x, y, half, 48), "Брызги крови на экран", S.screenBlood, 22);
            S.keepBloodOnStop = Toggle(new Rect(x + half + 20, y, half, 48), "Кровь остаётся после «стоп»", S.keepBloodOnStop, 22); y += 60;

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
                "1. «Бойцы и оружие» → создай героев (до 4 за сторону).\n" +
                "2. Опиши героя как угодно — арена понимает:\n" +
                "   • числа: «здоровье 500», «сила 9/10», «в 2 раза быстрее», «урон x2», «рост 2.5 метра»;\n" +
                "   • отрицания: «не умеет летать», «не боится огня» (= иммунитет);\n" +
                "   • условия смерти: «убить можно только ударом в голову», «победить только проткнув молнией», «боится льда или яда», «слабое место — спина»;\n" +
                "   • стиль: боксёр, каратист/кикбоксер, акробат/ниндзя, громила.\n" +
                "3. Внизу редактора видно, что арена «поняла». Бессмертия нет — если герой умирает только от чего-то особенного, арена сбросит подходящее оружие, а через 100 сек начнётся внезапная смерть.\n" +
                "4. Всё, что герой носит или держит, появляется на нём: шлем, очки, шрам, амулет, рюкзак, щит, цепи, бинты — и даже предметы, которых арена не знает («держит фонарь», «носит серьгу»).\n" +
                "5. «Один против всех»: опиши одного героя — на него пойдут волны стикменов, всё сильнее и сильнее. Между волнами — передышка и лечение. Esc — пауза.";
            Txt(new Rect(r.x + 50, r.y + 100, w * 0.56f - 60, h - 220), left, 21, P.text, TextAnchor.UpperLeft, false, true);
            string right =
                "УПРАВЛЕНИЕ (если включено)\n\n" +
                "Игрок 1 (красные):\n  A / D — бег,  W — прыжок,  S — блок\n  S + A/D — перекат (неуязвимость)\n  F — удары руками/оружием, жми ещё — комбо\n  W + F — апперкот (подброс)\n  G — пинки,  S + G — подсечка\n  G на бегу — удар в прыжке\n  G в воздухе — удар вниз\n  E — метнуть второе оружие (ножи и т.п.)\n  Q — захват и бросок\n  A/D дважды — рывок\n  блок в момент удара — парирование и контратака\n  R, T, Y — способности\n\n" +
                "Игрок 2 (синие): стрелки, ↓ — блок,\n  K — удар, L — пинок, J — захват,\n  U — метнуть, I O P — умения\n\n" +
                "Удар в спину, в голову и по лежачему считаются отдельно — это важно для условий смерти.";
            Txt(new Rect(r.x + w * 0.56f + 10, r.y + 100, w * 0.44f - 60, h - 220), right, 20, P.text, TextAnchor.UpperLeft, false, true);
            if (Btn(new Rect(r.x + (r.width - 360) / 2, r.yMax - 100, 360, 74), "ПОНЯТНО", 32, true)) scr = Scr.Main;
        }

        // ===================== HUD =====================
        void Hud()
        {
            var b = battle;
            float t = Time.unscaledTime;
            // таймер и счёт по центру
            if (b.mode == Battle.Mode.Survival) { SurvivalHud(); return; }
            Rect mid = new Rect(VW / 2 - 110, 10, 220, 92);
            Box(mid, new Color(0, 0, 0, 0.72f), 14);
            Border(mid, Draw.A(P.accent, 0.8f), 2, 14);
            int sec = Mathf.FloorToInt(b.fightTime);
            Txt(new Rect(mid.x, mid.y + 2, mid.width, 50), (sec / 60) + ":" + (sec % 60).ToString("00"), 42, b.suddenDeath ? new Color(1f, 0.3f, 0.25f) : Color.white, TextAnchor.MiddleCenter, true);
            Txt(new Rect(mid.x, mid.y + 50, mid.width / 2 - 14, 36), b.wins[0].ToString(), 30, new Color(1f, 0.35f, 0.3f), TextAnchor.MiddleRight, true);
            Txt(new Rect(mid.x, mid.y + 50, mid.width, 36), "—", 24, new Color(0.8f, 0.8f, 0.8f), TextAnchor.MiddleCenter, true);
            Txt(new Rect(mid.x + mid.width / 2 + 14, mid.y + 50, mid.width / 2 - 14, 36), b.wins[1].ToString(), 30, new Color(0.4f, 0.65f, 1f), TextAnchor.MiddleLeft, true);
            if (b.suddenDeath) Outline(new Rect(mid.x - 100, mid.yMax + 2, mid.width + 200, 28), "ВНЕЗАПНАЯ СМЕРТЬ", 20, new Color(1f, 0.3f, 0.25f), Color.black, TextAnchor.MiddleCenter, 2f);
            if (scr == Scr.Battle && Btn(new Rect(VW / 2 - 28, mid.yMax + (b.suddenDeath ? 34 : 8), 56, 42), "II", 22)) Pause();
            if (VideoRecorder.I != null && VideoRecorder.I.Active && Mathf.Repeat(t, 1f) < 0.65f)
                Outline(new Rect(mid.xMax + 16, mid.y + 4, 200, 40), "● REC", 26, new Color(1f, 0.2f, 0.2f), Color.black, TextAnchor.MiddleLeft, 2f);

            float barW = Mathf.Min(680f, VW / 2 - 150f);
            int ri = 0, bi = 0;
            foreach (var f in b.fighters)
            {
                if (f.minion) continue;
                bool right = f.team == 1;
                int idx = right ? bi++ : ri++;
                bool lead = idx == 0;
                float h = lead ? 92f : 50f;
                float y = lead ? 12f : 12f + 100f + (idx - 1) * 56f;
                float w = lead ? barW : barW * 0.72f;
                Rect r = right ? new Rect(VW - 16 - w, y, w, h) : new Rect(16, y, w, h);
                TeamBar(r, f, right, lead);
            }

            // счётчики комбо
            foreach (var f in b.fighters)
            {
                if (f.combo < 2 || f.dead) continue;
                bool right = f.team == 1;
                float pop = 1f + Mathf.Max(0f, 1.2f - f.comboT) * 0f + Mathf.Clamp01((f.comboT - 1.05f) / 0.15f) * 0.4f;
                Rect cr = right ? new Rect(VW - 360, VH * 0.36f, 330, 120) : new Rect(30, VH * 0.36f, 330, 120);
                Color cc = f.team == 0 ? new Color(1f, 0.4f, 0.3f) : new Color(0.45f, 0.7f, 1f);
                Outline(new Rect(cr.x, cr.y, cr.width, 90), f.combo.ToString(), (int)(96 * pop), cc, Color.black, right ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft, 4f);
                Outline(new Rect(cr.x, cr.y + 82, cr.width, 34), "HITS  " + ComboWord(f.combo), 26, Color.white, Color.black, right ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft, 2.5f);
            }

            // интро
            if (b.phase == Battle.Phase.Intro && b.mode == Battle.Mode.Fight)
            {
                float k = b.phaseT / Battle.IntroTime;
                float slide = 1f - Mathf.Pow(1f - Mathf.Clamp01(k * 2.5f), 3f);
                Box(new Rect(0, VH * 0.33f, VW, 130), new Color(0, 0, 0, 0.55f * slide), 0);
                Box(new Rect(-VW * (1 - slide), VH * 0.33f, VW / 2, 6), new Color(1f, 0.3f, 0.25f), 0);
                Box(new Rect(VW / 2 + VW * (1 - slide), VH * 0.33f + 124, VW / 2, 6), new Color(0.35f, 0.6f, 1f), 0);
                Outline(new Rect(-VW * (1 - slide) * 0.5f, VH * 0.33f + 15, VW / 2 - 90, 100), TeamName(0), 50, new Color(1f, 0.4f, 0.35f), Color.black, TextAnchor.MiddleRight, 3f);
                Outline(new Rect(VW / 2 + 90 + VW * (1 - slide) * 0.5f, VH * 0.33f + 15, VW / 2 - 90, 100), TeamName(1), 50, new Color(0.45f, 0.7f, 1f), Color.black, TextAnchor.MiddleLeft, 3f);
                Outline(new Rect(0, VH * 0.33f + 15, VW, 100), "VS", (int)(90 + Mathf.Sin(t * 12f) * 6f), Color.white, P.accent, TextAnchor.MiddleCenter, 4f);
            }

            // крупные объявления с полосой
            if (b.announceT > 0 && !string.IsNullOrEmpty(b.announce))
            {
                float age = Mathf.Max(0f, b.announceMax - b.announceT);
                float pop = age < 0.15f ? Mathf.Lerp(2.4f, 1f, age / 0.15f) : 1f;
                float band = Mathf.Clamp01(age / 0.12f);
                float fade = Mathf.Clamp01(b.announceT / 0.25f);
                Box(new Rect(0, VH * 0.17f, VW * band, 170), new Color(0, 0, 0, 0.6f * fade), 0);
                Box(new Rect(VW * (1 - band), VH * 0.17f + 166, VW, 4), Draw.A(b.announceCol, fade), 0);
                Outline(new Rect(0, VH * 0.17f - 5, VW, 180), b.announce, (int)(110 * pop), Draw.A(b.announceCol, fade), new Color(0, 0, 0, fade), TextAnchor.MiddleCenter, 5f);
            }

            // победа
            if (b.phase == Battle.Phase.Victory && b.mode == Battle.Mode.Fight && b.phaseT > 1.4f && scr == Scr.Battle)
            {
                Fighter mvp = null;
                foreach (var f in b.fighters) if (mvp == null || f.dmgDealt > mvp.dmgDealt) mvp = f;
                Rect pr = new Rect(VW / 2 - 340, VH * 0.36f, 680, 560);
                Panel(pr);
                if (mvp != null)
                {
                    Box(new Rect(pr.x + 30, pr.y + 22, 60, 60), mvp.B.color, 30);
                    Border(new Rect(pr.x + 30, pr.y + 22, 60, 60), P.text, 3, 30);
                    Txt(new Rect(pr.x + 110, pr.y + 16, pr.width - 130, 44), "MVP: " + mvp.B.name, 34, P.accent, TextAnchor.MiddleLeft, true);
                    Txt(new Rect(pr.x + 110, pr.y + 58, pr.width - 130, 30), "урон " + Mathf.RoundToInt(mvp.dmgDealt) + "   •   убийств " + mvp.kills + "   •   лучшее комбо " + mvp.maxCombo, 21, P.sub);
                }
                if (Btn(new Rect(pr.x + 40, pr.y + 115, pr.width - 80, 76), "РЕВАНШ", 34, true)) RestartClean();
                if (b.HasRecording)
                {
                    float hw = (pr.width - 90) / 2f;
                    if (Btn(new Rect(pr.x + 40, pr.y + 205, hw, 70), "ФИЛЬМ БИТВЫ", 26, false, true)) { b.StartReplay(); scr = Scr.Replay; audio.PlayMusic(true); }
                    if (Btn(new Rect(pr.x + 50 + hw, pr.y + 205, hw, 70), "СОХРАНИТЬ ВИДЕО", 22)) { b.StartCapture(); scr = Scr.Replay; audio.PlayMusic(true); }
                }
                string vs = VideoRecorder.I != null && !VideoRecorder.I.Active ? VideoRecorder.I.status : b.capStatus;
                if (!string.IsNullOrEmpty(vs))
                {
                    Txt(new Rect(pr.x + 30, pr.y + 280, pr.width - 200, 64), vs, 15, P.sub, TextAnchor.UpperLeft, false, true);
                    if (VideoRecorder.I != null && !string.IsNullOrEmpty(VideoRecorder.I.lastDir) && Btn(new Rect(pr.xMax - 160, pr.y + 284, 130, 50), "Папка", 18)) VideoRecorder.I.OpenFolder();
                }
                if (Btn(new Rect(pr.x + 40, pr.y + 350, pr.width - 80, 70), "ИЗМЕНИТЬ КОМАНДЫ", 28)) ToMenu(Scr.Teams);
                if (Btn(new Rect(pr.x + 40, pr.y + 435, pr.width - 80, 70), "ГЛАВНОЕ МЕНЮ", 28)) ToMenu(Scr.Main);
            }

            // подсказки управления
            ControlHints();
        }

        // HUD режима «Один против всех»
        void SurvivalHud()
        {
            var b = battle;
            float t = Time.unscaledTime;
            Rect mid = new Rect(VW / 2 - 190, 10, 380, 110);
            Box(mid, new Color(0, 0, 0, 0.75f), 14);
            Border(mid, new Color(0.9f, 0.1f, 0.08f, 0.9f), 2, 14);
            Txt(new Rect(mid.x, mid.y + 2, mid.width, 54), "ВОЛНА " + Mathf.Max(1, b.wave), 44, new Color(1f, 0.85f, 0.4f), TextAnchor.MiddleCenter, true);
            int sec = Mathf.FloorToInt(b.fightTime);
            Txt(new Rect(mid.x + 14, mid.y + 58, mid.width / 2, 44), "☠ " + b.survKills, 30, new Color(1f, 0.35f, 0.3f), TextAnchor.MiddleLeft, true);
            Txt(new Rect(mid.x, mid.y + 58, mid.width - 14, 44), (sec / 60) + ":" + (sec % 60).ToString("00"), 28, Color.white, TextAnchor.MiddleRight, true);
            if (scr == Scr.Battle && Btn(new Rect(VW / 2 - 28, mid.yMax + 8, 56, 42), "II", 22)) Pause();
            if (VideoRecorder.I != null && VideoRecorder.I.Active && Mathf.Repeat(t, 1f) < 0.65f)
                Outline(new Rect(mid.xMax + 16, mid.y + 4, 200, 40), "● REC", 26, new Color(1f, 0.2f, 0.2f), Color.black, TextAnchor.MiddleLeft, 2f);
            // герой
            if (b.hero != null)
                TeamBar(new Rect(16, 12, Mathf.Min(680f, VW / 2 - 220f), 92), b.hero, false, true);
            // враги
            Rect er = new Rect(VW - 376, 12, 360, 92);
            Box(er, new Color(0, 0, 0, 0.62f), 12);
            Box(new Rect(er.xMax - 6, er.y, 6, er.height), new Color(0.9f, 0.1f, 0.08f), 3);
            Txt(new Rect(er.x + 18, er.y + 6, er.width - 40, 40), b.intermission ? "ПЕРЕДЫШКА" : "ВРАГОВ ОСТАЛОСЬ", 22, new Color(0.85f, 0.8f, 0.8f), TextAnchor.MiddleRight, true);
            string big = b.intermission ? Mathf.CeilToInt(Mathf.Max(0f, b.interT)).ToString() : b.EnemiesLeft.ToString();
            Outline(new Rect(er.x + 18, er.y + 40, er.width - 40, 50), big, 40, b.intermission ? new Color(0.5f, 1f, 0.55f) : new Color(1f, 0.3f, 0.25f), Color.black, TextAnchor.MiddleRight, 2f);
            if (b.bossAlive && Mathf.Repeat(t, 0.8f) < 0.55f)
                Outline(new Rect(VW / 2 - 300, mid.yMax + 54, 600, 40), "⚠ БОСС НА АРЕНЕ ⚠", 28, new Color(1f, 0.15f, 0.1f), Color.black, TextAnchor.MiddleCenter, 2f);
            if (b.intermission)
                Outline(new Rect(0, VH * 0.62f, VW, 50), "здоровье восполняется... следующая волна через " + Mathf.CeilToInt(Mathf.Max(0f, b.interT)), 28, new Color(0.6f, 1f, 0.65f), Color.black, TextAnchor.MiddleCenter, 2f);

            // комбо героя
            var h = b.hero;
            if (h != null && h.combo >= 2 && !h.dead)
            {
                float pop = 1f + Mathf.Clamp01((h.comboT - 1.05f) / 0.15f) * 0.4f;
                Rect cr = new Rect(30, VH * 0.36f, 330, 120);
                Outline(new Rect(cr.x, cr.y, cr.width, 90), h.combo.ToString(), (int)(96 * pop), new Color(1f, 0.4f, 0.3f), Color.black, TextAnchor.MiddleLeft, 4f);
                Outline(new Rect(cr.x, cr.y + 82, cr.width, 34), "HITS  " + ComboWord(h.combo), 26, Color.white, Color.black, TextAnchor.MiddleLeft, 2.5f);
            }

            // объявления
            if (b.announceT > 0 && !string.IsNullOrEmpty(b.announce))
            {
                float age = Mathf.Max(0f, b.announceMax - b.announceT);
                float pop = age < 0.15f ? Mathf.Lerp(2.4f, 1f, age / 0.15f) : 1f;
                float band = Mathf.Clamp01(age / 0.12f);
                float fade = Mathf.Clamp01(b.announceT / 0.25f);
                Box(new Rect(0, VH * 0.17f, VW * band, 170), new Color(0, 0, 0, 0.6f * fade), 0);
                Box(new Rect(VW * (1 - band), VH * 0.17f + 166, VW, 4), Draw.A(b.announceCol, fade), 0);
                Outline(new Rect(0, VH * 0.17f - 5, VW, 180), b.announce, (int)(96 * pop), Draw.A(b.announceCol, fade), new Color(0, 0, 0, fade), TextAnchor.MiddleCenter, 5f);
            }

            // поражение
            if (b.phase == Battle.Phase.Victory && b.phaseT > 1.6f && scr == Scr.Battle)
            {
                Rect pr = new Rect(VW / 2 - 340, VH * 0.36f, 680, 470);
                Panel(pr);
                Txt(new Rect(pr.x + 30, pr.y + 18, pr.width - 60, 50), (b.hero != null ? b.hero.B.name : "Герой") + " пал", 38, P.accent, TextAnchor.MiddleCenter, true);
                Txt(new Rect(pr.x + 30, pr.y + 70, pr.width - 60, 36), "волна " + b.wave + "   •   убито " + b.survKills + "   •   " + (Mathf.FloorToInt(b.fightTime) / 60) + ":" + (Mathf.FloorToInt(b.fightTime) % 60).ToString("00") + "   •   рекорд: волна " + data.survivalBest, 22, P.sub, TextAnchor.MiddleCenter);
                if (Btn(new Rect(pr.x + 40, pr.y + 125, pr.width - 80, 76), "ЕЩЁ РАЗ", 34, true)) RestartClean();
                string vs = VideoRecorder.I != null && !VideoRecorder.I.Active ? VideoRecorder.I.status : "";
                if (!string.IsNullOrEmpty(vs))
                {
                    Txt(new Rect(pr.x + 30, pr.y + 210, pr.width - 200, 60), vs, 15, P.sub, TextAnchor.UpperLeft, false, true);
                    if (VideoRecorder.I != null && !string.IsNullOrEmpty(VideoRecorder.I.lastDir) && Btn(new Rect(pr.xMax - 160, pr.y + 214, 130, 50), "Папка", 18)) VideoRecorder.I.OpenFolder();
                }
                if (Btn(new Rect(pr.x + 40, pr.y + 280, pr.width - 80, 70), "ИЗМЕНИТЬ ГЕРОЯ", 28)) ToMenu(Scr.Teams);
                if (Btn(new Rect(pr.x + 40, pr.y + 365, pr.width - 80, 70), "ГЛАВНОЕ МЕНЮ", 28)) ToMenu(Scr.Main);
            }
            ControlHints();
        }

        void ControlHints()
        {
            var b = battle;
            if (scr != Scr.Battle || b.phase == Battle.Phase.Victory) return;
            foreach (var f in b.fighters)
            {
                if (!f.human || f.dead) continue;
                string keys = f.pindex == 0 ? "A D бег (2× рывок) • W прыжок • S блок/парир. • F удар • G пинок • Q захват • E метнуть • R T Y умения" : "← → бег (2× рывок) • ↑ прыжок • ↓ блок • K удар • L пинок • J захват • U метнуть • I O P умения";
                Rect hr = f.pindex == 0 ? new Rect(20, VH - 46 - letterbox * 95f, 1000, 34) : new Rect(VW - 1020, VH - 46 - letterbox * 95f, 1000, 34);
                Outline(hr, keys, 18, Color.white, new Color(0, 0, 0, 0.75f), f.pindex == 0 ? TextAnchor.MiddleLeft : TextAnchor.MiddleRight, 1.5f);
            }
        }

        // Экран фильма битвы
        void ReplayScreen()
        {
            var b = battle;
            float t = Time.unscaledTime;
            if (b.announceT > 0 && !string.IsNullOrEmpty(b.announce))
            {
                float age = Mathf.Max(0f, b.announceMax - b.announceT);
                float pop = age < 0.15f ? Mathf.Lerp(2f, 1f, age / 0.15f) : 1f;
                Outline(new Rect(0, VH * 0.2f, VW, 160), b.announce, (int)(96 * pop), b.announceCol, Color.black, TextAnchor.MiddleCenter, 5f);
            }
            if (b.capturing) return; // в сохраняемых кадрах — только картинка
            if (Mathf.Repeat(t, 1f) < 0.6f) Outline(new Rect(40, 18, 400, 60), "● ПОВТОР", 34, new Color(1f, 0.2f, 0.2f), Color.black, TextAnchor.MiddleLeft, 2f);
            Outline(new Rect(VW - 640, 18, 600, 60), "рисовка: " + Battle.StyleNames[b.curStyle] + "   скорость x" + b.replaySpeed.ToString("0.00"), 24, Color.white, Color.black, TextAnchor.MiddleRight, 2f);
            Rect bar = new Rect(60, VH - 60, VW - 120, 12);
            Box(bar, new Color(1, 1, 1, 0.25f), 6);
            Box(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(b.replayT / Mathf.Max(0.01f, b.RecLength)), bar.height), P.accent, 6);
            float by = VH - 170;
            if (Btn(new Rect(VW / 2 - 470, by, 300, 64), b.replayDone ? "ЕЩЁ РАЗ" : "СНАЧАЛА", 24)) b.StartReplay();
            if (Btn(new Rect(VW / 2 - 150, by, 300, 64), b.paused ? "▶ ДАЛЬШЕ" : "II ПАУЗА", 24)) b.paused = !b.paused;
            if (Btn(new Rect(VW / 2 + 170, by, 300, 64), "ВЫЙТИ", 24, true)) { b.StopReplay(); scr = Scr.Battle; }
        }

        static string ComboWord(int n)
        {
            if (n >= 12) return "НЕВЕРОЯТНО!";
            if (n >= 8) return "БЕЗУМИЕ!";
            if (n >= 5) return "ОТЛИЧНО!";
            if (n >= 3) return "ХОРОШО";
            return "";
        }

        string TeamName(int team)
        {
            string s = "";
            int n = 0;
            foreach (var f in battle.fighters)
            {
                if (f.team != team || f.minion) continue;
                if (n < 2) s += (s.Length > 0 ? " & " : "") + f.B.name;
                n++;
            }
            if (n > 2) s += " +" + (n - 2);
            return s;
        }

        // Полоса бойца в стиле файтингов: портрет, имя, HP со «следом» урона, умения, условие смерти
        void TeamBar(Rect r, Fighter f, bool right, bool lead)
        {
            Color tc = f.team == 0 ? new Color(0.95f, 0.28f, 0.22f) : new Color(0.33f, 0.58f, 1f);
            float a = f.dead ? 0.5f : 1f;
            Box(r, new Color(0, 0, 0, 0.62f * a), 12);
            Box(right ? new Rect(r.xMax - 6, r.y, 6, r.height) : new Rect(r.x, r.y, 6, r.height), Draw.A(tc, a), 3);
            float ps = lead ? r.height - 16 : r.height - 12;
            Rect por = right ? new Rect(r.xMax - ps - 14, r.y + (r.height - ps) / 2, ps, ps) : new Rect(r.x + 14, r.y + (r.height - ps) / 2, ps, ps);
            Box(por, new Color(0.12f, 0.12f, 0.14f, a), ps / 2);
            Rect head = new Rect(por.x + ps * 0.22f, por.y + ps * 0.16f, ps * 0.56f, ps * 0.56f);
            Box(head, f.dead ? new Color(0.35f, 0.35f, 0.35f) : f.B.color, ps * 0.28f);
            Box(new Rect(por.center.x - ps * 0.07f, head.yMax - 2, ps * 0.14f, ps * 0.22f), f.dead ? new Color(0.35f, 0.35f, 0.35f) : f.B.color, 3);
            Border(por, Draw.A(tc, 0.9f * a), 3, ps / 2);
            if (f.dead) Outline(por, "X", (int)(ps * 0.7f), new Color(1f, 0.2f, 0.2f), Color.black, TextAnchor.MiddleCenter, 2f);

            float x0 = right ? r.x + 14 : por.xMax + 12;
            float x1 = right ? por.x - 12 : r.xMax - 14;
            float w = x1 - x0;
            string nm = (f.human ? (f.pindex == 0 ? "P1 • " : "P2 • ") : "") + f.B.name;
            TextAnchor an = right ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft;
            Txt(new Rect(x0, r.y + 2, w, lead ? 30 : 22), nm, lead ? 23 : 17, f.dead ? new Color(0.6f, 0.6f, 0.6f) : Color.white, an, true);
            float bh = lead ? 22f : 12f;
            Rect bar = new Rect(x0, r.y + (lead ? 34 : 25), w, bh);
            Box(bar, new Color(0.15f, 0.15f, 0.15f, 0.9f), 5);
            float k = Mathf.Clamp01(f.hp / f.maxHp), kt = Mathf.Clamp01(f.hpTrail / f.maxHp);
            Rect trail = right ? new Rect(bar.xMax - bar.width * kt, bar.y, bar.width * kt, bh) : new Rect(bar.x, bar.y, bar.width * kt, bh);
            if (kt > 0) Box(trail, new Color(1f, 0.92f, 0.7f, 0.95f), 5);
            Rect fill = right ? new Rect(bar.xMax - bar.width * k, bar.y, bar.width * k, bh) : new Rect(bar.x, bar.y, bar.width * k, bh);
            Color fc = k < 0.25f ? Color.Lerp(tc, Color.white, Mathf.PingPong(Time.unscaledTime * 4f, 0.6f)) : tc;
            if (k > 0) { Box(fill, fc, 5); Box(new Rect(fill.x, fill.y, fill.width, bh * 0.35f), new Color(1, 1, 1, 0.25f), 4); }
            if (lead) Txt(bar, Mathf.CeilToInt(f.hp) + " / " + Mathf.RoundToInt(f.maxHp), 15, Color.white, TextAnchor.MiddleCenter, true);

            if (!lead) return;
            // умения (перезарядка) и статусы
            float iy = bar.yMax + 6;
            int idx = 0;
            foreach (var ab in f.ActiveAbilities())
            {
                float c = f.CooldownOf(ab) / Info.Cooldown(ab);
                Rect ir = right ? new Rect(bar.xMax - 20 - idx * 26, iy, 20, 20) : new Rect(bar.x + idx * 26, iy, 20, 20);
                Box(ir, new Color(0.25f, 0.25f, 0.25f, 0.9f), 10);
                if (c <= 0) Box(ir, new Color(1f, 0.85f, 0.2f), 10);
                else Box(new Rect(ir.x, ir.y + ir.height * c, ir.width, ir.height * (1 - c)), new Color(1f, 0.85f, 0.2f, 0.6f), 6);
                idx++;
            }
            string st = "";
            if (f.burnT > 0) st += "горит ";
            if (f.poisonT > 0) st += "яд ";
            if (f.bleedT > 0) st += "кровь ";
            if (f.slowT > 0) st += "лёд ";
            if (f.shieldT > 0) st += "щит ";
            if (f.RageOn) st += "ЯРОСТЬ ";
            if (f.weapon != null) st += "[" + f.weapon.name + (f.weapon.Ranged ? " " + f.ammo : "") + "] ";
            if (f.sec != null) st += "[" + f.sec.name + " " + f.secAmmo + "] ";
            st += "смерть: " + f.B.WeakText.ToLower();
            float sx = idx * 26 + 8;
            Rect sr = right ? new Rect(bar.x, iy - 1, bar.width - sx, 22) : new Rect(bar.x + sx, iy - 1, bar.width - sx, 22);
            Txt(sr, st, 15, new Color(0.85f, 0.85f, 0.85f), an);
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
