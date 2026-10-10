using System.Collections.Generic;
using UnityEngine;

// Точка входа: игра запускается из кода в любой сцене (никаких префабов настраивать не нужно).
public partial class Game : MonoBehaviour
{
    public static Game I;
    public static Camera Cam;
    public static float Sensitivity = 2f, Fov = 75f, Blood = 1f;
    public static int CorpseLimit = 90;
    public static bool Paused;

    public enum Scr { Menu, Setup, Settings, Battle }
    public static Scr screen = Scr.Menu;
    Scr settingsReturn = Scr.Menu;

    // выбор в меню
    readonly Dictionary<string, int> fPick = new Dictionary<string, int>();
    readonly Dictionary<string, int> cPick = new Dictionary<string, int>();
    readonly Dictionary<string, int> sPick = new Dictionary<string, int>();
    readonly List<string> fOrder = new List<string>();   // порядок выбора отрядов Фонда (до 5)
    int mapSel, timeSel;
    bool scpAlly, friendlyFire, playerFps = true;
    string playerSquadId;
    float slowMo = 1f;
    BattleConfig lastCfg;
    readonly List<GameObject> menuActors = new List<GameObject>();
    float menuOrbit;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (I != null) return;
        // убираем камеры и свет пустой сцены — всё создаётся кодом
        foreach (var c in Object.FindObjectsOfType<Camera>()) Destroy(c.gameObject);
        foreach (var l in Object.FindObjectsOfType<Light>()) Destroy(l.gameObject);

        DB.Init();
        Layers.Setup();
        Physics.defaultSolverIterations = 10;
        Physics.defaultSolverVelocityIterations = 4;
        Physics.autoSyncTransforms = false;
        Application.targetFrameRate = 144;
        QualitySettings.vSyncCount = 1;
        QualitySettings.antiAliasing = 4;

        var camGo = new GameObject("Main Camera");
        camGo.tag = "MainCamera";
        Cam = camGo.AddComponent<Camera>();
        Cam.fieldOfView = Fov;
        Cam.nearClipPlane = 0.05f;
        Cam.farClipPlane = 900f;
        Cam.allowHDR = true;
        Cam.allowMSAA = true;
        camGo.AddComponent<AudioListener>();
        DontDestroyOnLoad(camGo);

        var go = new GameObject("Game");
        DontDestroyOnLoad(go);
        I = go.AddComponent<Game>();
        Sfx.Init();
        Fx.Init();
        I.LoadPrefs();
        I.ShowMenu();
    }

    // ---------------- сохранение ----------------
    void LoadPrefs()
    {
        Sensitivity = PlayerPrefs.GetFloat("sens", 2f);
        Fov = PlayerPrefs.GetFloat("fov", 75f);
        Blood = PlayerPrefs.GetFloat("blood", 1f);
        CorpseLimit = PlayerPrefs.GetInt("corpses", 90);
        Sfx.Volume = PlayerPrefs.GetFloat("vol", 0.9f);
        mapSel = PlayerPrefs.GetInt("map", 0);
        timeSel = PlayerPrefs.GetInt("time", 0);
        scpAlly = PlayerPrefs.GetInt("scpAlly", 0) == 1;
        friendlyFire = PlayerPrefs.GetInt("ff", 0) == 1;
        playerFps = PlayerPrefs.GetInt("fps", 1) == 1;
        playerSquadId = PlayerPrefs.GetString("psq", "e11");
        Parse(PlayerPrefs.GetString("fPick", "e11:8;n7:8"), fPick);
        Parse(PlayerPrefs.GetString("cPick", "ci_rifle:8;ci_lmg:6"), cPick);
        Parse(PlayerPrefs.GetString("sPick", ""), sPick);
        fOrder.Clear();
        foreach (var kv in fPick) fOrder.Add(kv.Key);
    }

    void SavePrefs()
    {
        PlayerPrefs.SetFloat("sens", Sensitivity);
        PlayerPrefs.SetFloat("fov", Fov);
        PlayerPrefs.SetFloat("blood", Blood);
        PlayerPrefs.SetInt("corpses", CorpseLimit);
        PlayerPrefs.SetFloat("vol", Sfx.Volume);
        PlayerPrefs.SetInt("map", mapSel);
        PlayerPrefs.SetInt("time", timeSel);
        PlayerPrefs.SetInt("scpAlly", scpAlly ? 1 : 0);
        PlayerPrefs.SetInt("ff", friendlyFire ? 1 : 0);
        PlayerPrefs.SetInt("fps", playerFps ? 1 : 0);
        PlayerPrefs.SetString("psq", playerSquadId ?? "");
        PlayerPrefs.SetString("fPick", Join(fPick));
        PlayerPrefs.SetString("cPick", Join(cPick));
        PlayerPrefs.SetString("sPick", Join(sPick));
        PlayerPrefs.Save();
    }

    static void Parse(string s, Dictionary<string, int> d)
    {
        d.Clear();
        if (string.IsNullOrEmpty(s)) return;
        foreach (var part in s.Split(';'))
        {
            var kv = part.Split(':');
            if (kv.Length == 2 && int.TryParse(kv[1], out int n) && n > 0) d[kv[0]] = n;
        }
    }

    static string Join(Dictionary<string, int> d)
    {
        var parts = new List<string>();
        foreach (var kv in d) parts.Add(kv.Key + ":" + kv.Value);
        return string.Join(";", parts);
    }

    // ---------------- экраны ----------------
    void ShowMenu()
    {
        Battle.End();
        ClearMenuScene();
        screen = Scr.Menu;
        Paused = false;
        Time.timeScale = 1f;
        BuildMenuScene();
    }

    void ClearMenuScene()
    {
        foreach (var a in menuActors) if (a != null) Destroy(a);
        menuActors.Clear();
    }

    // Живая сцена в главном меню: строй бойцов, вертолёт с крутящимся винтом, SCP-173 в тени
    void BuildMenuScene()
    {
        MapGen.Build(0, 1, new List<Vector3> { new Vector3(0, 0, -64f) }, 7);
        float gy = Battle.GroundHeight(new Vector3(0, 0, -64f));
        var heli = Helicopter.Create(Team.Foundation, "MTF E-11", new Color(0.12f, 0.13f, 0.15f), new Color(0.15f, 0.45f, 1f), 8, false);
        heli.transform.position = new Vector3(0, gy + 1.2f, -64f);
        heli.transform.rotation = Quaternion.Euler(0, 200, 0);
        heli.Launch(heli.transform.position, heli.transform.position, heli.transform.position, 99999f);
        heli.transform.position = new Vector3(0, gy + 1.2f, -64f);
        heli.transform.rotation = Quaternion.Euler(0, 200, 0);
        menuActors.Add(heli.gameObject);
        string[] ids = { "a1", "e11", "n7", "b7", "e10", "t5", "l5" };
        for (int i = 0; i < ids.Length; i++)
        {
            SquadDef def = null;
            foreach (var d in DB.Foundation) if (d.id == ids[i]) def = d;
            if (def == null) continue;
            Vector3 p = new Vector3(-6f + i * 2f, 0, -55f + Mathf.Abs(i - 3) * 0.4f);
            p.y = Battle.GroundHeight(p);
            var s = Soldier.Create(def, p, Quaternion.Euler(0, 180 + (i - 3) * 6f, 0), i, false);
            s.inVehicle = true;
            s.state = Soldier.State.Transport;
            menuActors.Add(s.gameObject);
        }
        var scp = Scp173.Create(new Vector3(9f, Battle.GroundHeight(new Vector3(9f, 0, -50f)), -50f), Quaternion.Euler(0, 210, 0));
        scp.Hold(true);
        scp.inVehicle = true;
        menuActors.Add(scp.gameObject);
        Cam.transform.SetParent(null);
        Cam.transform.position = new Vector3(2f, gy + 2.2f, -44f);
        Cam.transform.LookAt(new Vector3(0, gy + 1.4f, -56f));
        Cam.fieldOfView = 55f;
        SpectatorCam.Deactivate();
    }

    public void StartBattle(BattleConfig cfg)
    {
        ClearMenuScene();
        lastCfg = cfg;
        SavePrefs();
        screen = Scr.Battle;
        Paused = false;
        slowMo = 1f;
        Time.timeScale = 1f;
        Battle.Begin(cfg);
    }

    BattleConfig MakeConfig()
    {
        var cfg = new BattleConfig { map = mapSel, time = timeSel, scpAllyChaos = scpAlly, friendlyFire = friendlyFire, playerFps = playerFps, seed = Random.Range(1, 99999) };
        foreach (var id in fOrder)
            foreach (var d in DB.Foundation)
                if (d.id == id && fPick.TryGetValue(id, out int n) && n > 0) cfg.foundation.Add(new SquadPick { def = d, count = n });
        foreach (var d in DB.Chaos) if (cPick.TryGetValue(d.id, out int n) && n > 0) cfg.chaos.Add(new SquadPick { def = d, count = n });
        foreach (var d in DB.Scps) if (sPick.TryGetValue(d.id, out int n) && n > 0) cfg.scps.Add(new ScpPick { def = d, count = n });
        cfg.playerSquad = 0;
        for (int i = 0; i < cfg.foundation.Count; i++) if (cfg.foundation[i].def.id == playerSquadId) cfg.playerSquad = i;
        return cfg;
    }

    void Update()
    {
        if (screen == Scr.Menu)
        {
            menuOrbit += Time.deltaTime;
            float gy = Battle.GroundHeight(new Vector3(0, 0, -56f));
            Vector3 focus = new Vector3(0, gy + 1.3f, -57f);
            Vector3 p = focus + Quaternion.Euler(0, Mathf.Sin(menuOrbit * 0.08f) * 25f, 0) * new Vector3(2.5f, 1.0f, 12.5f);
            Cam.transform.position = Vector3.Lerp(Cam.transform.position, p, Time.deltaTime);
            Cam.transform.rotation = Quaternion.Slerp(Cam.transform.rotation, Quaternion.LookRotation(focus - Cam.transform.position), Time.deltaTime * 2f);
        }
        if (screen != Scr.Battle)
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
            return;
        }
        if (Input.GetKeyDown(KeyCode.Escape)) Paused = !Paused;
        if (!Paused && Input.GetKeyDown(KeyCode.T))
        {
            slowMo = slowMo < 1f ? 1f : 0.3f;
            Battle.Message(slowMo < 1f ? "Замедление времени" : "Нормальная скорость", Color.white);
        }
        Time.timeScale = Paused ? 0f : slowMo;
        Time.fixedDeltaTime = 0.02f * Mathf.Max(0.05f, Time.timeScale);
        var pc = PlayerController.I;
        bool wantLock = !Paused && ((pc != null && !pc.dead) || SpectatorCam.Active);
        if (Battle.I != null && Battle.I.over && (pc == null || pc.dead) && !SpectatorCam.Active) wantLock = false;
        Cursor.lockState = wantLock ? CursorLockMode.Locked : CursorLockMode.None;
        Cursor.visible = !wantLock;

        // после смерти: 1 — взять бойца, 2 — наблюдать
        if (!Paused && pc != null && pc.dead && Time.time - pc.deathTime > 1.5f)
        {
            if (Input.GetKeyDown(KeyCode.Alpha1) || Input.GetKeyDown(KeyCode.Mouse0)) TakeOverAny();
            if (Input.GetKeyDown(KeyCode.Alpha2)) { Spectate(); }
        }
        if (!Paused && SpectatorCam.Active && Input.GetKeyDown(KeyCode.Alpha1)) TakeOverAny();
    }

    void Spectate()
    {
        var pc = PlayerController.I;
        Vector3 pos = Cam.transform.position;
        Quaternion rot = Cam.transform.rotation;
        PlayerController.Remove();
        SpectatorCam.Activate(pos, rot);
    }

    void TakeOverAny()
    {
        Soldier best = null; float bd = float.MaxValue;
        Vector3 from = Cam.transform.position;
        if (SpectatorCam.Active && SpectatorCam.I.follow is Soldier fs && fs.alive && fs.team == Team.Foundation && fs.state == Soldier.State.Combat && !fs.zombie) best = fs;
        if (best == null)
            foreach (var u in Unit.All)
                if (u is Soldier s && s.alive && s.team == Team.Foundation && s.state == Soldier.State.Combat && !s.zombie)
                {
                    float d = (s.transform.position - from).sqrMagnitude;
                    if (d < bd) { bd = d; best = s; }
                }
        if (best == null) { Battle.Message("Нет живых бойцов Фонда", new Color(1f, 0.5f, 0.4f)); return; }
        PlayerController.TakeOver(best);
    }
}
