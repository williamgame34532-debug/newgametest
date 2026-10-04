using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Точка входа: создаётся автоматически при запуске любой сцены.
    public partial class Game : MonoBehaviour
    {
        public static Game I;
        const string SAVE_KEY = "stickman_legends_save_v1";

        public SaveData data;
        public Settings S { get { return data.settings; } }
        public Audio audio;
        public Battle battle;
        Camera cam;

        public enum Scr { Main, Teams, EditFighter, EditWeapon, Settings, Battle, Pause, Help, Replay }
        public Scr scr = Scr.Main;
        Scr settingsBack = Scr.Main;

        readonly HashSet<KeyCode> held = new HashSet<KeyCode>();
        readonly HashSet<KeyCode> pressed = new HashSet<KeyCode>();
        readonly System.Random rng = new System.Random();

        public bool Held(KeyCode k) { return held.Contains(k); }
        public bool Pressed(KeyCode k) { return pressed.Contains(k); }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (I != null) return;
            var go = new GameObject("StickmanLegends");
            DontDestroyOnLoad(go);
            go.AddComponent<Game>();
        }

        void Awake()
        {
            if (I != null && I != this) { Destroy(gameObject); return; }
            I = this;
            Application.targetFrameRate = 60;
            Load();

            cam = Camera.main;
            if (cam == null)
            {
                var cgo = new GameObject("Main Camera");
                cgo.tag = "MainCamera";
                cam = cgo.AddComponent<Camera>();
            }
            if (cam.GetComponent<AudioListener>() == null) cam.gameObject.AddComponent<AudioListener>();
            DontDestroyOnLoad(cam.gameObject);

            audio = gameObject.AddComponent<Audio>();
            gameObject.AddComponent<VideoRecorder>();
            var bgo = new GameObject("Battle");
            bgo.transform.SetParent(transform, false);
            battle = bgo.AddComponent<Battle>();
            battle.Init(cam, audio);
            battle.SetTheme(data.theme);
            if (!string.IsNullOrEmpty(S.musicUrl) && S.useCustomMusic) audio.LoadUrl(S.musicUrl);
            StartDemo();
        }

        void LateUpdate() { pressed.Clear(); }

        void OnApplicationFocus(bool f) { if (!f) held.Clear(); }

        // ===================== СОХРАНЕНИЕ =====================
        public void Save()
        {
            PlayerPrefs.SetString(SAVE_KEY, JsonUtility.ToJson(data));
            PlayerPrefs.Save();
        }

        void Load()
        {
            data = null;
            if (PlayerPrefs.HasKey(SAVE_KEY))
            {
                try { data = JsonUtility.FromJson<SaveData>(PlayerPrefs.GetString(SAVE_KEY)); } catch { data = null; }
            }
            if (data == null)
            {
                data = new SaveData();
                data.red.Add(Presets.Fighters()[0]);
                data.blue.Add(Presets.Fighters()[1]);
                data.weapons.AddRange(Presets.Weapons());
            }
            if (data.settings == null) data.settings = new Settings();
            if (data.red == null) data.red = new List<FighterDef>();
            if (data.blue == null) data.blue = new List<FighterDef>();
            if (data.weapons == null) data.weapons = new List<WeaponDef>();
            data.theme = Mathf.Clamp(data.theme, 0, Theme.Count - 1);
        }

        // ===================== РЕЖИМЫ =====================
        public void SetTheme(int id)
        {
            data.theme = id;
            battle.SetTheme(id);
            Save();
        }

        List<WeaponStats> DropPool()
        {
            var l = new List<WeaponStats>();
            foreach (var w in data.weapons) l.Add(Parser.BuildWeapon(w));
            if (l.Count == 0) foreach (var w in Presets.Weapons()) l.Add(Parser.BuildWeapon(w));
            return l;
        }

        public void StartDemo()
        {
            var pre = Presets.Fighters();
            int n = rng.Next(100) < 55 ? 1 : 2;
            var red = new List<FighterBuild>();
            var blue = new List<FighterBuild>();
            var used = new HashSet<int>();
            for (int i = 0; i < n * 2; i++)
            {
                int k;
                do { k = rng.Next(pre.Count); } while (used.Contains(k) && used.Count < pre.Count);
                used.Add(k);
                var d = pre[k];
                if (i % 2 == 0) red.Add(Parser.BuildFighter(d, data.weapons)); else blue.Add(Parser.BuildFighter(d, data.weapons));
            }
            battle.Setup(Battle.Mode.Demo, red, blue, DropPool(), true, 6f, false, false, false);
            audio.PlayMusic(false);
        }

        public void NextDemo()
        {
            if (scr == Scr.Main || scr == Scr.Teams || scr == Scr.Settings || scr == Scr.Help) StartDemo();
        }

        public void StartBattle()
        {
            if (data.survival) { StartSurvival(); return; }
            if (data.red.Count == 0) data.red.Add(Parser.RandomFighter(rng));
            if (data.blue.Count == 0) data.blue.Add(Parser.RandomFighter(rng));
            var red = new List<FighterBuild>();
            var blue = new List<FighterBuild>();
            foreach (var d in data.red) red.Add(Parser.BuildFighter(d, data.weapons));
            foreach (var d in data.blue) blue.Add(Parser.BuildFighter(d, data.weapons));
            bool p1 = data.p1Control;
            bool p2 = data.twoPlayers && data.p2Control;
            if (VideoRecorder.I != null && VideoRecorder.I.Active) VideoRecorder.I.End();
            battle.Setup(Battle.Mode.Fight, red, blue, DropPool(), data.drops, data.dropInterval, p1, p2, false);
            scr = Scr.Battle;
            audio.PlayMusic(true);
            if (S.recordVideo && VideoRecorder.I != null) VideoRecorder.I.Begin(false, "fight");
            Save();
        }

        // «Один против всех»: герой — первый красный боец
        public void StartSurvival()
        {
            if (data.red.Count == 0) data.red.Add(Parser.RandomFighter(rng));
            var hero = Parser.BuildFighter(data.red[0], data.weapons);
            if (VideoRecorder.I != null && VideoRecorder.I.Active) VideoRecorder.I.End();
            battle.Setup(Battle.Mode.Survival, new List<FighterBuild> { hero }, new List<FighterBuild>(), DropPool(), data.drops, data.dropInterval * 1.6f, data.p1Control, false, false);
            scr = Scr.Battle;
            audio.PlayMusic(true);
            if (S.recordVideo && VideoRecorder.I != null) VideoRecorder.I.Begin(false, "survival");
            Save();
        }

        public void Pause()
        {
            if (scr != Scr.Battle) return;
            battle.paused = true;
            scr = Scr.Pause;
            audio.Sfx("click", 0.6f, 0f);
        }

        public void Resume()
        {
            battle.paused = false;
            scr = Scr.Battle;
        }

        public void StopToStart()
        {
            battle.Restart(S.keepBloodOnStop);
            battle.paused = false;
            scr = Scr.Battle;
        }

        public void RestartClean()
        {
            if (VideoRecorder.I != null && VideoRecorder.I.Active) VideoRecorder.I.End();
            battle.Restart(false);
            battle.paused = false;
            scr = Scr.Battle;
        }

        public void ToMenu(Scr s)
        {
            if (VideoRecorder.I != null && VideoRecorder.I.Active) VideoRecorder.I.End();
            battle.paused = false;
            scr = s;
            StartDemo();
        }

        // ===================== ПРЕСЕТЫ =====================
        public static class Presets
        {
            static FighterDef F(string name, Color c, string desc, string weapon)
            {
                return new FighterDef { name = name, color = c, description = desc, weaponDesc = weapon };
            }

            public static List<FighterDef> Fighters()
            {
                return new List<FighterDef>
                {
                    F("Красный Ниндзя", new Color(0.82f, 0.08f, 0.08f), "Очень быстрый и ловкий ниндзя в повязке. Телепортируется за спину врага и делает рывок. Слабость: огонь.", "Острая катана"),
                    F("Синий Самурай", new Color(0.1f, 0.25f, 0.85f), "Сильный и стойкий самурай, мастер карате. Ставит щит и бьёт по земле. Убить его можно только ударом в голову.", "Тяжёлый двуручный меч"),
                    F("Огненный Маг", new Color(0.95f, 0.45f, 0.05f), "Маг в шляпе волшебника. Кидает огненные шары и бьёт молнией. Хрупкий. Боится льда.", "Огненный посох"),
                    F("Кибер-Громила", new Color(0.35f, 0.38f, 0.42f), "Огромный киборг-громила, здоровье 250, очень сильный. Бьёт по земле, регенерирует. Пули и клинки не берут. Победить можно только проткнув молнией.", "Кибер-молот"),
                    F("Тень", new Color(0.06f, 0.06f, 0.07f), "Чёрный убийца-тень, акробат. Невидимость, вампир, двойной прыжок. Убить можно только ударом в спину или светом.", "Два кинжала"),
                    F("Ковбой Джо", new Color(0.6f, 0.4f, 0.2f), "Ковбой в шляпе, быстрый стрелок. Делает рывок. Слабость: яд.", "Револьвер"),
                    F("Ледяная Королева", new Color(0.92f, 0.95f, 1f), "Королева в короне. Ледяные осколки, щит, телекинез. Слабость: огонь.", ""),
                    F("Берсерк", new Color(0.55f, 0.3f, 0.15f), "Огромный викинг с рогами. Ярость, бьёт по земле. Слабость: яд.", "Огромный топор"),
                    F("Робот R-9", new Color(0.15f, 0.65f, 0.2f), "Зелёный робот с лазером из глаз. Бессмертный.", "Бластер"),
                    F("Падший Ангел", new Color(0.95f, 0.95f, 0.95f), "Ангел с нимбом и плащом. Летает, исцеляется, бьёт молнией. Слабость: тьма.", "Копьё света"),
                    F("Мясник", new Color(0.5f, 0.05f, 0.05f), "Большой и медленный маньяк. Вампир, ярость. Боится пуль.", "Бензопила"),
                    F("Лучница", new Color(0.2f, 0.55f, 0.25f), "Ловкая лучница в плаще. Двойной прыжок, невидимость. Слабость: клинки.", "Лук"),
                };
            }

            static WeaponDef W(string name, string desc) { return new WeaponDef { name = name, description = desc }; }

            public static List<WeaponDef> Weapons()
            {
                return new List<WeaponDef>
                {
                    W("Бензопила", "Ревущая бензопила, кровь во все стороны"),
                    W("Лук охотника", "Лук с острыми стрелами"),
                    W("Пылающий меч", "Огненный меч, поджигает врагов"),
                    W("Сюрикены", "Метательные звёздочки ниндзя"),
                    W("Ледяное копьё", "Длинное копьё изо льда, замедляет"),
                    W("Кувалда", "Огромная тяжёлая кувалда"),
                    W("Автомат", "Автомат с длинной очередью"),
                    W("Электро-катана", "Лёгкая катана с молнией"),
                    W("Гранаты", "Гранаты, взрываются"),
                    W("Дробовик", "Дробовик, мощный в упор"),
                };
            }
        }
    }
}
