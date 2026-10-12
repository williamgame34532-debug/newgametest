using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// Вступление к операции: передовая база, брифинг командира группы, радиообмен, посадка и перелёт.
// Бой не начинается «с экшена»: сначала люди стоят у вертолёта и слушают задачу.
public partial class Battle
{
    public struct IntroLine { public string who, text; public float dur; public bool radio; public Signal gesture; }

    public bool intro;                 // идёт вступление (игрок на базе)
    public float fade;                 // затемнение экрана 0..1
    public string cardTitle, cardSub;  // титры при переходе
    public float cardT;
    public float stampT = -1f;         // время показа штампа «место / время»
    public string stamp;
    bool skipIntro;

    static float Dur(string t) => Mathf.Clamp(2.4f + t.Length * 0.052f, 3.2f, 8.5f);

    static IntroLine L(string who, string text, bool radio = false, Signal g = Signal.None) => new IntroLine { who = who, text = text, dur = Dur(text), radio = radio, gesture = g };

    static string Clock(int time) => time == 0 ? "11:" + Random.Range(10, 59) : time == 1 ? "18:" + Random.Range(10, 59) : "02:" + Random.Range(10, 59);

    // Сценарий брифинга по составу сил и цели
    public static List<IntroLine> Script(BattleConfig cfg)
    {
        var l = new List<IntroLine>();
        var me = cfg.foundation.Count > 0 ? cfg.foundation[Mathf.Clamp(cfg.playerSquad, 0, cfg.foundation.Count - 1)].def : null;
        string boss = "Командир группы";
        string sqName = me != null ? me.name : "группа";
        l.Add(L("Диспетчер базы", "Всем бортам: запуск двигателей разрешаю. Погода в районе — " + (cfg.time == 2 ? "ночь, видимость ограничена." : cfg.map == 3 ? "мороз, позёмка." : cfg.map == 2 ? "жара, пыль." : "облачно, ветер слабый."), true));
        l.Add(L(boss, "Так, " + sqName + ", подошли ближе. Слушаем внимательно, повторять не буду.", false, Signal.Regroup));
        if (cfg.op != null)
        {
            l.Add(L(boss, "Операция " + OperationDef.Quoted(cfg.op.title) + ". Район — " + cfg.op.place + ".", false, Signal.Point));
            foreach (var s in Split(cfg.op.briefing)) l.Add(L(boss, s, false, Random.value < 0.4f ? Signal.Point : Signal.None));
            foreach (var s in Split(cfg.op.task)) l.Add(L(boss, s, false, Signal.Hold));
        }
        else
        {
            var scps = new List<string>();
            foreach (var s in cfg.scps) scps.Add(s.def.name + (s.count > 1 ? " (" + s.count + ")" : ""));
            var ci = new List<string>();
            foreach (var c in cfg.chaos) ci.Add(c.def.name);
            l.Add(L(boss, "Район — " + MapGen.MapNames[cfg.map] + ". Связь с охраной комплекса потеряна сорок минут назад.", false, Signal.Point));
            if (scps.Count > 0) l.Add(L(boss, "Подтверждён прорыв содержания: " + string.Join(", ", scps) + ". Объекты не уничтожать — ослабить и удержать до команды содержания.", false, Signal.Hold));
            if (ci.Count > 0) l.Add(L(boss, "В районе работают Повстанцы Хаоса: " + string.Join(", ", ci) + ". Им нужно то же, что и нам. Не отдаём.", false, Signal.Point));
            if (scps.Count == 0) l.Add(L(boss, "Задача — выбить противника из комплекса в центре района и удержать его.", false, Signal.MoveUp));
        }
        var others = new List<string>();
        foreach (var f in cfg.foundation) if (f.def != me && !f.placed) others.Add(f.def.name + (f.delay > 0 ? " (позже)" : ""));
        if (others.Count > 0) l.Add(L(boss, "С нами идут: " + string.Join(", ", others) + ". Работаем по командам командира операции.", false, Signal.Hold));
        l.Add(L(boss, "Огонь только по подтверждённым целям. Своих не задеть. Магазины проверить сейчас.", false, Signal.Hold));
        if (others.Count > 0) l.Add(L(others[0].Split(' ')[0], "Готовы к вылету.", true));
        l.Add(L("Штаб операции", "Наблюдение подтверждает активность в районе цели. Вылет по готовности.", true));
        l.Add(L(boss, "Вопросов нет. По машинам!", false, Signal.MoveUp));
        return l;
    }

    static IEnumerable<string> Split(string text)
    {
        foreach (var raw in text.Split(new[] { ". " }, System.StringSplitOptions.RemoveEmptyEntries))
        {
            string s = raw.Trim();
            if (s.Length == 0) continue;
            if (!s.EndsWith(".") && !s.EndsWith("!") && !s.EndsWith("?") && !s.EndsWith("»")) s += ".";
            yield return s;
        }
    }

    public static float IntroLength(List<IntroLine> lines)
    {
        float t = 3f;
        foreach (var x in lines) t += x.dur;
        return t + 3f;
    }

    // ---------------- сама сцена ----------------
    IEnumerator IntroRoutine(Helicopter heli, SquadRt sq, PlayerController pc, List<IntroLine> lines)
    {
        intro = true;
        skipIntro = false;
        var cfg = Cfg;
        var fob = this.fob;
        if (fob == null) { intro = false; yield break; }
        heli.rotorVolume = 0.45f;
        // офицер за столом с картой, группа полукругом, игрок в центре
        Vector3 table = fob.brief + new Vector3(0, 0, 1.4f);
        var mates = new List<Soldier>();
        foreach (var m in sq.members) if (m != null && m.alive && !m.remoteHuman) mates.Add(m);
        Soldier officer = mates.Count > 0 ? mates[0] : null;
        if (officer != null) StandSoldier(officer, table + new Vector3(0.2f, 0, 1.15f), 180f);
        int n = mates.Count - 1;
        for (int i = 1; i < mates.Count; i++)
        {
            float a = Mathf.Lerp(-75f, 75f, n <= 1 ? 0.5f : (i - 1) / (float)(n - 1)) * Mathf.Deg2Rad;
            if (Mathf.Abs(a) < 0.25f) a += a >= 0 ? 0.35f : -0.35f;   // центр — место игрока
            Vector3 p = table + new Vector3(Mathf.Sin(a) * 3.2f, 0, -Mathf.Cos(a) * 3.2f);
            Vector3 look = table - p;
            StandSoldier(mates[i], p, Mathf.Atan2(look.x, look.z) * Mathf.Rad2Deg + Random.Range(-10f, 10f));
        }
        // живые игроки стоят рядом, а не в одной точке
        int myIdx = LocalHumanIndex(out int humansHere);
        pc.StandAt(table + new Vector3((myIdx - (humansHere - 1) * 0.5f) * 1.3f, 0, -3.3f), 0f);

        stamp = "ПЕРЕДОВАЯ БАЗА «КЕДР»   ·   " + Clock(cfg.time) + "   ·   " + (cfg.op != null ? cfg.op.place : MapGen.MapNames[cfg.map]);
        stampT = Time.time;
        fade = 1f;
        for (float t = 0; t < 1f; t += Time.deltaTime / 1.6f) { fade = 1f - t; yield return null; }
        fade = 0f;
        yield return new WaitForSeconds(1.5f);

        // брифинг
        foreach (var line in lines)
        {
            if (skipIntro) break;
            Message(line.who + ": " + line.text, line.radio ? new Color(0.7f, 0.85f, 0.7f) : new Color(1f, 0.85f, 0.55f), line.dur + 0.4f);
            if (line.radio) Sfx.Play2D("radio", 0.35f);
            else if (officer != null) Speech.Say(officer.transform, line.who, line.text, line.dur + 0.3f, new Color(1f, 0.85f, 0.55f), Random.value < 0.5f ? "vo_talk" : null);
            // командир говорит спокойно; сигналы рукой — только там, где они к месту
            if (officer != null && !line.radio)
            {
                var g = line.gesture == Signal.Point || line.gesture == Signal.MoveUp ? line.gesture : Random.value < 0.6f ? Signal.Talk : Signal.None;
                if (g != Signal.None) officer.anim.DoSignal(g);
            }
            float until = Time.time + line.dur;
            while (Time.time < until && !skipIntro) yield return null;
        }
        // подкрепление: ждём своего вылета на базе, слушая эфир
        float nextChat = Time.time + 6f;
        string[] chatter =
        {
            "Штаб операции: Первая волна на подлёте к району.",
            "Наблюдение: Вижу вспышки выстрелов у комплекса.",
            "Диспетчер базы: Резервная группа, ждать команды.",
            "Штаб операции: Есть контакт. Резерв — готовность две минуты.",
            "Наблюдение: Движение на северном направлении, количество не установлено.",
        };
        int ci = 0;
        while (Time.time < heli.LaunchTime - 1f && !skipIntro)
        {
            if (Time.time > nextChat) { Message(chatter[ci++ % chatter.Length], new Color(0.7f, 0.85f, 0.7f), 6f); Sfx.Play2D("radio", 0.3f); nextChat = Time.time + Random.Range(9f, 15f); }
            yield return null;
        }

        // посадка: группа идёт к борту и рассаживается, игрок — вместе со всеми
        heli.rotorVolume = 1f;
        heli.LaunchNow();
        int seat = Mathf.Max(1, humansHere);
        float stagger = 0.3f;
        foreach (var m in mates)
            if (m != null && m.alive) { StartCoroutine(m.Board(heli, heli.seats[seat++ % heli.seats.Count], stagger)); stagger += Random.Range(0.35f, 0.7f); }
        Message(sq.def.name + ": По машинам! Пошли, пошли!", new Color(1f, 0.85f, 0.55f), 3f);
        yield return StartCoroutine(pc.BoardRoutine(heli, heli.seats[myIdx % heli.seats.Count]));
        // титры — уже в салоне, на взлёте
        cardTitle = cfg.op != null ? cfg.op.code : "ОПЕРАЦИЯ ФОНДА";
        cardSub = (cfg.op != null ? cfg.op.place : MapGen.MapNames[cfg.map]) + "   ·   " + sq.def.name + " " + sq.def.nick;
        cardT = Time.time;
        intro = false;
        StartCoroutine(Cinematic.Play(heli, pc, (cfg.op != null ? cfg.op.place : MapGen.MapNames[cfg.map]).ToUpper(), Clock(cfg.time) + "   ·   " + (cfg.op != null ? cfg.op.title : "район операции")));
        yield return new WaitForSeconds(4.5f);
        cardTitle = null;
    }

    // Другие группы на базе: свой круг у борта (командир объясняет задачу), к вылету — посадка
    IEnumerator SquadAtFob(Helicopter heli, SquadRt sq)
    {
        var mates = new List<Soldier>();
        foreach (var m in sq.members) if (m != null && m.alive) mates.Add(m);
        if (mates.Count == 0) yield break;
        Vector3 spot = heli.transform.TransformPoint(new Vector3(-8f, -1.2f, -3f));
        spot.y = Battle.GroundHeight(spot);
        StandSoldier(mates[0], spot + heli.transform.forward * 1.2f, heli.transform.eulerAngles.y + 180f);
        int n = mates.Count - 1;
        for (int i = 1; i < mates.Count; i++)
        {
            float a = Mathf.Lerp(-70f, 70f, n <= 1 ? 0.5f : (i - 1) / (float)(n - 1)) * Mathf.Deg2Rad;
            Vector3 f = -heli.transform.forward, r = heli.transform.right;
            Vector3 p = spot + (f * Mathf.Cos(a) + r * Mathf.Sin(a)) * 2.6f;
            p.y = Battle.GroundHeight(p);
            Vector3 look = (spot + heli.transform.forward * 1.2f) - p;
            StandSoldier(mates[i], p, Mathf.Atan2(look.x, look.z) * Mathf.Rad2Deg + Random.Range(-8f, 8f));
        }
        // командир группы проводит свой брифинг — его слышно и видно, если подойти
        var lines = SquadBrief(sq);
        int li = 0;
        float gest = Time.time + 2f, nextLine = Time.time + Random.Range(2f, 5f);
        while (Time.time < heli.LaunchTime - 22f)
        {
            var boss = mates[0];
            if (boss == null || !boss.alive) break;
            if (Time.time > nextLine)
            {
                string text = lines[li % lines.Count]; li++;
                float d = Mathf.Clamp(2.2f + text.Length * 0.05f, 3f, 7.5f);
                Speech.Say(boss.transform, sq.def.name.Split(' ')[0] + " — командир", text, d, new Color(1f, 0.85f, 0.55f), Random.value < 0.5f ? "vo_talk" : null);
                boss.anim.DoSignal(Random.value < 0.7f ? Signal.Talk : Signal.Point);
                // бойцы иногда отвечают
                if (Random.value < 0.35f && mates.Count > 2)
                {
                    var m = mates[Random.Range(1, mates.Count)];
                    if (m != null && m.alive) StartCoroutine(Reply(m, d * 0.9f));
                }
                nextLine = Time.time + d + Random.Range(0.6f, 1.6f);
                if (li >= lines.Count) nextLine += 12f;
            }
            if (Time.time > gest)
            {
                gest = Time.time + Random.Range(3f, 6f);
                mates[0].anim.DoSignal(Random.value < 0.8f ? Signal.Talk : Signal.Point);
            }
            yield return null;
        }
        if (mates[0] != null && mates[0].alive) Speech.Say(mates[0].transform, sq.def.name.Split(' ')[0] + " — командир", "По машинам! Пошли, пошли!", 3f, new Color(1f, 0.85f, 0.55f), "vo_move");
        int seat = 0;
        float stagger = 0f;
        foreach (var m in mates)
            if (m != null && m.alive) { StartCoroutine(m.Board(heli, heli.seats[seat++ % heli.seats.Count], stagger)); stagger += Random.Range(0.4f, 0.8f); }
    }

    static readonly string[] replies = { "Понял.", "Принято.", "Есть.", "Ясно, командир.", "Сколько их там?", "А если объект уже вышел?", "Работаем." };
    IEnumerator Reply(Soldier m, float delay)
    {
        yield return new WaitForSeconds(delay);
        if (m != null && m.alive) Speech.Say(m.transform, m.CallSign, replies[Random.Range(0, replies.Length)], 2.4f, new Color(0.8f, 0.88f, 0.95f));
    }

    // Брифинг чужой группы: задача по её роли и обстановке
    List<string> SquadBrief(SquadRt sq)
    {
        var cfg = Cfg;
        var l = new List<string>();
        string n = sq.def.name;
        l.Add("Так, " + n + ", слушаем. Вылетаем вторыми, высадка по команде штаба.");
        if (cfg.op != null) l.Add("Операция " + OperationDef.Quoted(cfg.op.title) + ". Наша задача — поддержать первую группу и закрыть подходы.");
        else l.Add("Район — " + MapGen.MapNames[cfg.map] + ". Комплекс в центре, связь с охраной потеряна.");
        if (cfg.scps.Count > 0) l.Add("Подтверждён прорыв: " + cfg.scps[0].def.name + ". В объект без команды не стрелять — только сдерживаем.");
        if (cfg.chaos.Count > 0) l.Add("Хаос уже на месте. Работают группами, с тяжёлым вооружением. Не геройствуем.");
        l.Add("После высадки — веером, двойками. Связь на втором канале.");
        l.Add("Раненых не бросаем. Медик — за мной. Вопросы?");
        return l;
    }

    // номер своего игрока среди живых игроков его отряда (место в строю и в вертолёте)
    int LocalHumanIndex(out int count)
    {
        count = 1;
        var hs = Cfg.humans;
        if (hs == null) return 0;
        NetHuman me = null; foreach (var h in hs) if (h.peer == Net.MyPeer) me = h;
        if (me == null) return 0;
        int idx = 0; count = 0;
        foreach (var h in hs)
            if (h.team == me.team && h.squad == me.squad) { if (h == me) idx = count; count++; }
        return idx;
    }

    static void StandSoldier(Soldier s, Vector3 p, float yaw)
    {
        s.transform.SetParent(null, true);
        s.transform.position = p;
        s.transform.rotation = Quaternion.Euler(0, yaw, 0);
        s.anim.seated = false;
        s.inVehicle = true;
        s.state = Soldier.State.Transport;
        s.anim.Snap();
    }

    void IntroInput()
    {
        if (!intro || fade > 0.5f || (Net.IsClient && Net.InGame)) return;
        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)) skipIntro = true;
    }

    void LaunchInput()
    {
        if (intro || Game.Paused || (Net.IsClient && Net.InGame)) return;
        if ((Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)) && PlayerCanLaunch) LaunchPlayerNow();
    }
}
