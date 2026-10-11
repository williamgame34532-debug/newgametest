using System.Collections.Generic;
using UnityEngine;

public enum OrderPhase { Landing, Regroup, Briefing, Advance, Assault }

// Командир стороны (ИИ). Игрок — рядовой боец и получает приказы вместе со своим отрядом.
// Порядок: высадка → оборона у точки высадки → брифинг (задачи отрядам) → наступление этапами → штурм цели.
// Цель — захватить SCP-объект (если есть), иначе — зачистить комплекс в центре карты.
public class TeamCommander
{
    public Team team;
    public readonly List<SquadRt> squads = new List<SquadRt>();
    public OrderPhase phase = OrderPhase.Landing;
    public Vector3 basePos, objective;
    public ScpUnit objectiveScp;
    public string objectiveName = "Центр комплекса";
    float phaseT, stageT, firstLanding = -1f;
    int stage;
    public string title;

    public TeamCommander(Team t, Vector3 basePos)
    {
        team = t;
        this.basePos = basePos;
        title = t == Team.Foundation ? "Командир МОГ" : "Командир Повстанцев";
    }

    bool Landed(SquadRt s)
    {
        foreach (var m in s.members) if (m != null && m.alive && m.state != Soldier.State.Combat && m.state != Soldier.State.Dead) return false;
        return true;
    }

    void Say(string text)
    {
        // приказы своей стороны видны игроку; переговоры Хаоса — "перехвачены" реже
        if (team == Team.Foundation) { Battle.Message(title + ": " + text, new Color(0.55f, 0.8f, 1f)); Sfx.Play2D("radio", 0.35f); }
        else if (Random.value < 0.5f) Battle.Message("Перехват (Хаос): " + text, new Color(0.55f, 0.9f, 0.45f));
    }

    void ChooseObjective()
    {
        ScpUnit best = null; float bd = float.MaxValue;
        foreach (var u in Unit.All)
        {
            if (!(u is ScpUnit su) || !su.alive || su.captured || !su.Capturable) continue;
            float d = Vector3.Distance(su.transform.position, Vector3.zero);
            if (d < bd) { bd = d; best = su; }
        }
        // SCP ещё в контейнере — цель контейнер
        if (best == null && Battle.I != null)
            foreach (var c in Battle.I.containers)
                if (c != null && c.spawned.Count == 0 && c.kind != ScpKind.S0492)
                {
                    objectiveScp = null;
                    objective = c.transform.position;
                    objectiveName = DB.Scp(c.kind).name;
                    return;
                }
        objectiveScp = best;
        objective = best != null ? best.transform.position : Vector3.zero;
        objectiveName = best != null ? best.displayName : "Центр комплекса";
    }

    // Подкрепления: вылетают позже, по прибытии командир включает их в текущий этап операции
    void Reinforcements(Vector3 dir)
    {
        foreach (var s in squads)
        {
            if (!s.reinforce) continue;
            if (!s.announced && Time.time >= s.arriveAt)
            {
                s.announced = true;
                Say("Подкрепление " + s.def.name + " вылетело, расчётное время — минута.");
            }
            if (s.orderSet || !Landed(s) || s.Alive == 0) continue;
            s.orderSet = true;
            if (phase == OrderPhase.Landing)
            {
                s.orderPos = s.lz + dir * 16f; s.hold = true;
                s.orderText = "Занять оборону у точки высадки";
                continue;
            }
            // роль — туда, где меньше живых бойцов
            int l = 0, r = 0;
            foreach (var o in squads) if (o != s && o.orderSet && !o.overwatch) { if (o.flank < 0) l += o.Alive; else if (o.flank > 0) r += o.Alive; }
            bool ow = s.def.primary == "svd" || s.def.primary == "dmr";
            s.overwatch = ow;
            s.flank = l <= r ? -1 : 1;
            s.hold = phase == OrderPhase.Regroup || phase == OrderPhase.Briefing;
            s.orderPos = s.lz + dir * 16f;
            s.orderText = "Подкрепление: " + RoleName(s.flank, ow) + " → " + objectiveName;
            s.Leader?.anim.DoSignal(Signal.MoveUp);
            Say(s.def.name + " на земле. Выдвигайтесь на " + RoleName(s.flank, ow) + ", поддержите наступление.");
        }
    }

    public float NextReinforcement(out string name)
    {
        float best = float.MaxValue; name = null;
        foreach (var s in squads) if (s.reinforce && !s.announced && s.arriveAt - Time.time < best) { best = s.arriveAt - Time.time; name = s.def.name; }
        return best;
    }

    static string RoleName(int flank, bool overwatch) => overwatch ? "снайперское прикрытие" : flank < 0 ? "левый фланг" : flank > 0 ? "правый фланг" : "центр";

    // ---------------- доклады о контактах ----------------
    readonly Dictionary<object, float> reported = new Dictionary<object, float>();
    float nextScan, lastReport;

    static string Bearing(Vector3 from, Vector3 to)
    {
        Vector3 d = to - from; d.y = 0;
        float b = Mathf.Repeat(Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg, 360f);
        string[] card = { "север", "северо-восток", "восток", "юго-восток", "юг", "юго-запад", "запад", "северо-запад" };
        return "азимут " + Mathf.RoundToInt(b).ToString("000") + " (" + card[Mathf.RoundToInt(b / 45f) % 8] + "), " + Mathf.RoundToInt(d.magnitude / 10f) * 10 + " м";
    }

    void Report(string text)
    {
        lastReport = Time.time;
        Say(text);
    }

    // Наблюдатель — любой живой боец стороны на земле с прямой видимостью цели
    Soldier Spotter(Vector3 target, float range)
    {
        Soldier best = null; float bd = range * range;
        foreach (var s in squads)
            foreach (var m in s.members)
            {
                if (m == null || !m.alive || m.inVehicle || m.zombie) continue;
                float d = (m.transform.position - target).sqrMagnitude;
                if (d > bd) continue;
                if (!Combat.Visible(m.EyePos, target)) continue;
                best = m; bd = d;
            }
        return best;
    }

    void Spotting()
    {
        if (Time.time < nextScan) return;
        nextScan = Time.time + 1.2f;
        if (Time.time - lastReport < 6f) return;
        // вертолёты противника
        foreach (var h in Helicopter.Active)
        {
            if (h == null || h.showcase || h.IsWaiting || h.Done || !Battle.Hostile(team, h.team)) continue;
            if (reported.TryGetValue(h, out var t0) && Time.time - t0 < 90f) continue;
            Vector3 hp = h.transform.position + Vector3.up;
            var sp = Spotter(hp, 550f);
            if (sp == null) continue;
            reported[h] = Time.time;
            string who = h.team == Team.SCP ? "транспортник с контейнером" : h.team == Team.Chaos ? "вертолёт Повстанцев" : "вертолёт Фонда";
            Report("Воздух! " + who + ", " + Bearing(sp.transform.position, hp) + ". " + (h.team == Team.SCP ? "Груз — аномальный объект." : "Идёт на высадку!"));
            return;
        }
        // SCP-объекты
        foreach (var u in Unit.All)
        {
            if (!(u is ScpUnit su) || !su.alive || su.captured || !Battle.Hostile(team, su.team)) continue;
            if (reported.TryGetValue(su, out var t0) && Time.time - t0 < 120f) continue;
            var sp = Spotter(su.AimPoint, 220f);
            if (sp == null) continue;
            reported[su] = Time.time;
            Report("Визуальный контакт: " + su.displayName + ", " + Bearing(sp.transform.position, su.transform.position) + "." + (su.kind == ScpKind.S096 ? " Не смотреть на лицо!" : su.kind == ScpKind.S173 ? " Не моргать, держать в поле зрения!" : ""));
            return;
        }
        // группы противника
        if (Battle.I == null) return;
        foreach (var es in Battle.I.squads)
        {
            if (es == null || es.team == team || !Battle.Hostile(team, es.team)) continue;
            Soldier lead = null; int alive = 0;
            foreach (var m in es.members) if (m != null && m.alive && !m.inVehicle) { alive++; if (lead == null) lead = m; }
            if (lead == null) continue;
            if (reported.TryGetValue(es, out var t0) && Time.time - t0 < 75f) continue;
            var sp = Spotter(lead.AimPoint, 260f);
            if (sp == null) continue;
            reported[es] = Time.time;
            string what = es.def.name + (alive > 1 ? ", около " + alive + " чел." : ", одиночка");
            Report("Контакт! " + what + ", " + Bearing(sp.transform.position, lead.transform.position) + ".");
            return;
        }
    }

    public void Tick(float dt)
    {
        Spotting();
        squads.RemoveAll(s => s == null);
        phaseT += dt;
        // цель: живой SCP или центр
        if (objectiveScp == null || !objectiveScp.alive || objectiveScp.captured) ChooseObjective();
        else objective = objectiveScp.transform.position;

        Vector3 toObj = objective - basePos; toObj.y = 0;
        float dist = toObj.magnitude;
        Vector3 dir = dist > 0.1f ? toObj / dist : Vector3.forward;
        Vector3 perp = Vector3.Cross(Vector3.up, dir);

        Reinforcements(dir);

        switch (phase)
        {
            case OrderPhase.Landing:
                foreach (var s in squads)
                {
                    if (s.orderSet || !Landed(s)) continue;
                    s.orderSet = true;
                    s.orderPos = s.lz + dir * 16f;
                    s.orderText = "Занять оборону у точки высадки";
                    s.hold = true;
                    s.Leader?.anim.DoSignal(Signal.Regroup);
                }
                bool all = false;
                foreach (var s in squads) if (!s.reinforce) all = true;
                foreach (var s in squads) if (!s.orderSet && !s.reinforce) all = false;
                if (firstLanding < 0) foreach (var s in squads) if (s.orderSet && !s.garrison) firstLanding = Time.time;
                if (all || (firstLanding > 0 && Time.time - firstLanding > 75f)) { phase = OrderPhase.Regroup; phaseT = 0; Say("Все отряды на земле. Закрепиться, ждать приказа."); }
                break;

            case OrderPhase.Regroup:
                if (phaseT > 12f)
                {
                    phase = OrderPhase.Briefing; phaseT = 0;
                    // распределяем роли
                    int n = squads.Count, idx = 0;
                    var parts = new List<string>();
                    foreach (var s in squads)
                    {
                        if ((s.reinforce && !s.orderSet) || s.garrison) { s.flank = 0; continue; }
                        bool ow = s.def.primary == "svd" || s.def.primary == "dmr";
                        s.overwatch = ow;
                        s.flank = ow ? (idx % 2 == 0 ? -1 : 1) : n == 1 ? 0 : (idx % 3 == 0 ? 0 : idx % 3 == 1 ? -1 : 1);
                        idx++;
                        parts.Add(s.def.name + " — " + RoleName(s.flank, s.overwatch));
                    }
                    Say("Цель: " + (objectiveScp != null || objectiveName.StartsWith("SCP") ? "захватить " + objectiveName : "зачистить центр комплекса") + ". " + string.Join(", ", parts) + ".");
                    foreach (var s in squads)
                    {
                        if ((s.reinforce && !s.orderSet) || s.garrison) continue;
                        s.orderText = (s.overwatch ? "Прикрывать огнём" : "Готовиться к наступлению: " + RoleName(s.flank, false)) + " → " + objectiveName;
                        s.Leader?.anim.DoSignal(Signal.Hold);
                    }
                }
                break;

            case OrderPhase.Briefing:
                if (phaseT > 7f)
                {
                    phase = OrderPhase.Advance; phaseT = 0; stage = 0; stageT = 0;
                    Say("Вперёд! Наступаем.");
                    foreach (var s in squads) if (!s.garrison) { s.hold = false; s.Leader?.anim.DoSignal(Signal.MoveUp); }
                }
                break;

            case OrderPhase.Advance:
            {
                stageT += dt;
                float[] frac = { 0.45f, 0.75f };
                int ready = 0, alive = 0;
                foreach (var s in squads)
                {
                    float f = s.overwatch ? 0.42f : frac[Mathf.Min(stage, 1)];
                    float lat = s.flank * Mathf.Clamp(dist * 0.18f, 12f, 35f) * (1f - f * 0.5f);
                    s.orderPos = basePos + dir * dist * f + perp * lat;
                    s.orderText = (s.overwatch ? "Прикрытие с позиции, " : "Наступление, " + RoleName(s.flank, false) + ", ") + "этап " + (stage + 1) + " → " + objectiveName;
                    if (s.Alive == 0 || (s.reinforce && !s.orderSet) || s.garrison) continue;
                    alive++;
                    int near = 0, cnt = 0;
                    foreach (var m in s.members) if (m != null && m.alive) { cnt++; if ((m.transform.position - s.orderPos).sqrMagnitude < 400f) near++; }
                    if (cnt == 0 || near >= cnt * 0.5f || s.overwatch) ready++;
                }
                if ((ready >= alive && stageT > 8f) || stageT > 45f)
                {
                    stage++; stageT = 0;
                    if (stage >= 2) { phase = OrderPhase.Assault; phaseT = 0; Say("Штурм! " + (objectiveScp != null ? "Обезвредить и захватить " + objectiveName : "Зачистить " + objectiveName) + "."); }
                    else Say("Этап пройден, продвигаемся дальше.");
                    foreach (var s in squads) s.Leader?.anim.DoSignal(Signal.MoveUp);
                }
                break;
            }

            case OrderPhase.Assault:
                foreach (var s in squads)
                {
                    float r = s.overwatch ? 45f : 10f;
                    s.orderPos = objective - dir * (s.overwatch ? r : 0f) + perp * s.flank * (s.overwatch ? 25f : 9f);
                    s.orderText = s.overwatch ? "Прикрывать штурм " + objectiveName : (objectiveScp != null ? "Захватить " + objectiveName : "Зачистить " + objectiveName);
                }
                break;
        }
        // приказ игрока своему отряду
        foreach (var s in squads)
            if (s.playerCmdUntil > Time.time && PlayerController.I != null && !PlayerController.I.dead)
            {
                s.orderSet = true;
                s.orderPos = s.playerFollow ? PlayerController.I.transform.position - PlayerController.I.transform.forward * 3f : s.playerCmdPos;
                s.hold = !s.playerFollow;
                s.orderText = s.playerFollow ? "Следовать за вами" : "Удерживать указанную позицию";
            }
        // гарнизон держит свой сектор при любой фазе
        foreach (var s in squads)
            if (s.garrison) { s.orderPos = s.lz; s.hold = true; s.orderText = "Удерживать сектор"; }
    }
}
