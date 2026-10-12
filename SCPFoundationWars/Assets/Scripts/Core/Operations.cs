using System.Collections.Generic;
using UnityEngine;

// Режим «Реальные операции Фонда»: сценарии по материалам SCP Wiki (scp-wiki.wikidot.com, CC BY-SA 3.0).
// Тексты брифингов — пересказ документов вики, а не цитаты. Это художественная вселенная.
public class OperationDef
{
    // название в кавычках-ёлочках, если своих кавычек в нём ещё нет
    public static string Quoted(string t) => string.IsNullOrEmpty(t) ? "" : t.Contains("«") ? t : "«" + t + "»";
    public string id, code, title, date, place, source;
    public string briefing;          // что произошло по документам
    public string task;              // задача игрока
    public string win, lose;         // итог для экрана результатов
    public int map, time;
    public bool scpAllyChaos;
    public bool captureEnds = true;  // захват одного объекта завершает операцию
    public string playerSquad;
    public readonly List<SquadPick> foundation = new List<SquadPick>();
    public readonly List<SquadPick> chaos = new List<SquadPick>();
    public readonly List<ScpPick> scps = new List<ScpPick>();

    public BattleConfig ToConfig(bool fps)
    {
        var cfg = new BattleConfig { map = map, time = time, scpAllyChaos = scpAllyChaos, playerFps = fps, seed = Random.Range(1, 99999), op = this, captureEnds = captureEnds };
        cfg.foundation.AddRange(foundation);
        cfg.chaos.AddRange(chaos);
        cfg.scps.AddRange(scps);
        for (int i = 0; i < foundation.Count; i++) if (foundation[i].def.id == playerSquad) cfg.playerSquad = i;
        return cfg;
    }
}

public static class Operations
{
    public static readonly List<OperationDef> All = new List<OperationDef>();

    static SquadDef F(string id) { foreach (var d in DB.Foundation) if (d.id == id) return d; return null; }
    static SquadDef C(string id) { foreach (var d in DB.Chaos) if (d.id == id) return d; return null; }
    static ScpDef S(ScpKind k) => DB.Scp(k);
    static SquadPick P(SquadDef d, int n, float delay = 0f) => new SquadPick { def = d, count = n, delay = delay };
    static SquadPick G(SquadDef d, int n, float x, float z, bool hold = true) => new SquadPick { def = d, count = n, placed = true, pos = new Vector3(x, 0, z), garrison = hold };
    static ScpPick O(ScpKind k, int n, float x, float z) => new ScpPick { def = S(k), count = n, placed = true, pos = new Vector3(x, 0, z) };

    public static void Init()
    {
        if (All.Count > 0) return;
        DB.Init();

        // ---------- 1. Инцидент 096-1-А ----------
        var zulu = F("e11").Variant("zulu9a", "Зулу 9-А", "«Охотники на скромника»", "ZULU 9-A");
        zulu.desc = "Группа изъятия. Винтовки и одноразовые гранатомёты AT-4."; zulu.special = "at4";
        zulu.look.uniform = new Color(0.78f, 0.8f, 0.82f); zulu.look.uniform2 = new Color(0.7f, 0.72f, 0.74f);
        zulu.look.armor = new Color(0.62f, 0.64f, 0.66f); zulu.look.helmet = new Color(0.75f, 0.77f, 0.79f);
        zulu.look.accent = new Color(0.2f, 0.6f, 0.95f); zulu.ignores096 = false;
        var zuluB = zulu.Variant("zulu9b", "Зулу 9-Б", "«Вторая вертушка»", "ZULU 9-B");
        var op = new OperationDef
        {
            id = "096", code = "ИНЦИДЕНТ 096-1-А", title = "Изъятие SCP-096", date = "дата засекречена", place = "заснеженная глушь, удалённый район",
            source = "SCP Wiki: SCP-096, «Инцидент изъятия 096-1-А»",
            briefing = "По документам Фонда, объект нашли в труднодоступном районе в сильный мороз. Для изъятия отправили две группы на двух вертолётах — Зулу 9-А и 9-Б. Приказ был простым: «мешок на голову — и на борт». Во время операции кто-то из группы увидел лицо объекта. Бойцы пытались остановить его, в том числе из AT-4, но это не помогло.",
            task = "Ты в группе 9-А. Не смотри объекту в лицо. Измотай SCP-096 огнём, пока он не обессилеет, и удерживай зону рядом с ним — это и есть «мешок на голову». Группа 9-Б прибудет второй вертушкой.",
            win = "Объект изъят и надет мешок. В отличие от документов, все выжившие вернулись на базу.",
            lose = "Как и в документах: кто-то посмотрел. Группа уничтожена.",
            map = 3, time = 1, playerSquad = "zulu9a"
        };
        op.foundation.Add(P(zulu, 8));
        op.foundation.Add(P(zuluB, 8, 60f));
        op.scps.Add(O(ScpKind.S096, 1, 0, 20));
        All.Add(op);

        // ---------- 2. «Тихая ночь», Зона-06, 1991 ----------
        var guard06 = F("guard").Variant("guard06", "Охрана Зоны-06", "«Био-изолятор»", "SITE-06");
        op = new OperationDef
        {
            id = "939", code = "ПРОРЫВ «ТИХАЯ НОЧЬ»", title = "Девять SCP-939 на свободе", date = "20.09.1991", place = "Биоизоляционная Зона-06, лес",
            source = "SCP Wiki: SCP-939 — дополнение о прорыве 1991 года, отчёт МОГ Ню-7",
            briefing = "По материалам вики, ночью 20 сентября 1991 года на Биоизоляционной Зоне-06 из камер вырвались девять особей SCP-939. Жителей ближайшего посёлка вывели, объяснив это «надвигающимся штормом». На поиск и возврат отправили группы, в отчёте упоминается МОГ Ню-7. Особи охотятся в темноте и подманивают людей, подражая их голосам.",
            task = "Ночь, лес. Охрана Зоны-06 держит комплекс. Ню-7 и Эпсилон-11 должны найти и нейтрализовать всю стаю: ослабленную особь можно захватить, остальных — уничтожить.",
            win = "Все девять особей обезврежены. Для посёлка это был «шторм».",
            lose = "Стая ушла в лес. Посёлок пришлось эвакуировать насовсем.",
            map = 1, time = 2, captureEnds = false, playerSquad = "n7"
        };
        op.foundation.Add(G(guard06, 8, 0, -30));
        op.foundation.Add(P(F("n7"), 8));
        op.foundation.Add(P(F("e11"), 8, 60f));
        op.scps.Add(O(ScpKind.S939, 5, -30, 30));
        op.scps.Add(O(ScpKind.S939, 4, 35, 45));
        All.Add(op);

        // ---------- 3. Прорыв SCP-682 ----------
        op = new OperationDef
        {
            id = "682", code = "ПРОРЫВ SCP-682", title = "«Все доступные МОГ»", date = "одна из 17 попыток прорыва", place = "Зона-██, пустыня",
            source = "SCP Wiki: SCP-682 — особые условия содержания",
            briefing = "Документ объекта велит при прорыве SCP-682 бросать на возврат все доступные МОГ, и ни одна группа не должна быть меньше семи человек. Объект пытался вырваться 17 раз, шесть раз успешно. Он регенерирует, приспосабливается к любому оружию и ненавидит всё живое.",
            task = "Пять групп, в каждой не меньше семи бойцов, подходят волнами. Сбивай регенерацию массированным огнём, а когда объект ослабеет — окружи его и удержи до прибытия команды содержания.",
            win = "SCP-682 возвращён в кислотную камеру. Седьмая успешная попытка не состоялась.",
            lose = "Это седьмой успешный прорыв. Объект ушёл в пустыню.",
            map = 2, time = 0, playerSquad = "n7"
        };
        op.foundation.Add(P(F("n7"), 8));
        op.foundation.Add(P(F("e11"), 8));
        op.foundation.Add(P(F("b7"), 7, 60f));
        op.foundation.Add(P(F("l5"), 7, 60f));
        op.foundation.Add(P(F("a1"), 7, 120f));
        op.scps.Add(O(ScpKind.S682, 1, 0, 25));
        All.Add(op);

        // ---------- 4. Инцидент SCP-049, Зона-19, 2017 ----------
        var guard19 = F("guard").Variant("guard19", "Охрана Зоны-19", "«Сектор содержания»", "SITE-19");
        op = new OperationDef
        {
            id = "049", code = "ИНЦИДЕНТ 049 / 16.04.2017", title = "«Лекарство» доктора", date = "16.04.2017", place = "Зона-19, зона тяжёлого содержания",
            source = "SCP Wiki: SCP-049 — журнал инцидентов",
            briefing = "По журналу инцидентов, 16 апреля 2017 года в Зоне-19 SCP-049 убил сотрудника, и тот поднялся как SCP-049-2. Объект искренне считает, что «лечит» людей от «Поветрия», а каждый погибший рядом с ним становится его новым пациентом.",
            task = "Охрана Зоны-19 удерживает сектор. Бета-7 в химзащите заходит первой, Эпсилон-11 идёт следом. Зачисти SCP-049-2 и захвати самого доктора. Чем больше погибших, тем больше у него «пациентов».",
            win = "SCP-049 возвращён в камеру. Пострадавших кремировали.",
            lose = "Доктор «вылечил» весь сектор.",
            map = 4, time = 1, playerSquad = "b7"
        };
        op.foundation.Add(G(guard19, 8, 0, -35));
        op.foundation.Add(P(F("b7"), 8));
        op.foundation.Add(P(F("e11"), 8, 60f));
        op.scps.Add(O(ScpKind.S049, 1, 0, 30));
        op.scps.Add(O(ScpKind.S0492, 7, 10, 22));
        All.Add(op);

        // ---------- 5. Прорыв SCP-106 и Протокол возврата ----------
        var dclass = C("ci_classd").Variant("classd_esc", "Сбежавший Класс-D", "Воспользовались прорывом", "");
        dclass.desc = "Сотрудники Класса-D, которые сбежали во время прорыва и разобрали оружие охраны.";
        op = new OperationDef
        {
            id = "106", code = "ПРОТОКОЛ ВОЗВРАТА 106", title = "Старик вышел из камеры", date = "дата засекречена", place = "Зона-19, подземный комплекс",
            source = "SCP Wiki: SCP-106 — условия содержания и процедура возврата",
            briefing = "По документам, SCP-106 проходит сквозь любые материалы, разъедает всё, к чему прикасается, и утаскивает жертв в своё «карманное измерение». Камеру с ним держат на постоянном контроле. При прорыве запускается особая процедура возврата: объект выманивают и загоняют обратно. Сотрудники Класса-D пользуются хаосом, чтобы сбежать.",
            task = "Эпсилон-11 и охрана Зоны должны остановить сбежавший Класс-D и не дать SCP-106 уйти. Измотай объект огнём и удерживай его до прибытия группы возврата.",
            win = "Протокол возврата выполнен. Беглецы задержаны.",
            lose = "Старик ушёл сквозь стены, а Класс-D разбежался по лесу.",
            map = 4, time = 2, captureEnds = true, playerSquad = "e11"
        };
        op.foundation.Add(G(guard19, 6, 0, -40));
        op.foundation.Add(P(F("e11"), 8));
        op.foundation.Add(P(F("n7"), 6, 120f));
        op.chaos.Add(G(dclass, 14, 15, 40, false));
        op.scps.Add(O(ScpKind.S106, 1, -10, 25));
        All.Add(op);

        // ---------- 6. Рейд Повстанцев Хаоса ----------
        op = new OperationDef
        {
            id = "ci", code = "РЕЙД ПОВСТАНЦЕВ ХАОСА", title = "Кража SCP-173", date = "дата засекречена", place = "Зона-19, поверхность",
            source = "SCP Wiki: Повстанцы Хаоса (группа интересов), SCP-173",
            briefing = "По материалам вики, Повстанцы Хаоса — отколовшаяся часть Фонда. Они нападают на Зоны и крадут аномальные объекты, чтобы использовать их как оружие. В этом сценарии их цель — SCP-173, которого в момент атаки перевозят. Объект двигается, только когда на него никто не смотрит.",
            task = "Альфа-1 и Эпсилон-11 должны отбить рейд. Не дай Повстанцам захватить SCP-173 и сам удержи объект. Моргают все, поэтому держите его в поле зрения вдвоём.",
            win = "Рейд отбит, SCP-173 остался у Фонда.",
            lose = "Повстанцы увезли SCP-173.",
            map = 0, time = 0, playerSquad = "e11"
        };
        op.foundation.Add(G(F("guard"), 8, 0, -30));
        op.foundation.Add(P(F("e11"), 8));
        op.foundation.Add(P(F("a1"), 6, 60f));
        op.chaos.Add(P(C("ci_delta"), 5));
        op.chaos.Add(P(C("ci_rifle"), 8));
        op.chaos.Add(P(C("ci_rpg"), 4, 60f));
        op.scps.Add(O(ScpKind.S173, 1, 0, 5));
        All.Add(op);
    }
}
