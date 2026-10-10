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
    float phaseT, stageT;
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
        if (team == Team.Foundation) Battle.Message(title + ": " + text, new Color(0.55f, 0.8f, 1f));
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

    static string RoleName(int flank, bool overwatch) => overwatch ? "снайперское прикрытие" : flank < 0 ? "левый фланг" : flank > 0 ? "правый фланг" : "центр";

    public void Tick(float dt)
    {
        squads.RemoveAll(s => s == null);
        phaseT += dt;
        // цель: живой SCP или центр
        if (objectiveScp == null || !objectiveScp.alive || objectiveScp.captured) ChooseObjective();
        else objective = objectiveScp.transform.position;

        Vector3 toObj = objective - basePos; toObj.y = 0;
        float dist = toObj.magnitude;
        Vector3 dir = dist > 0.1f ? toObj / dist : Vector3.forward;
        Vector3 perp = Vector3.Cross(Vector3.up, dir);

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
                bool all = squads.Count > 0;
                foreach (var s in squads) if (!s.orderSet) all = false;
                if (all || phaseT > 80f) { phase = OrderPhase.Regroup; phaseT = 0; Say("Все отряды на земле. Закрепиться, ждать приказа."); }
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
                        bool ow = s.def.primary == "svd" || s.def.primary == "dmr";
                        s.overwatch = ow;
                        s.flank = ow ? (idx % 2 == 0 ? -1 : 1) : n == 1 ? 0 : (idx % 3 == 0 ? 0 : idx % 3 == 1 ? -1 : 1);
                        idx++;
                        parts.Add(s.def.name + " — " + RoleName(s.flank, s.overwatch));
                    }
                    Say("Цель: " + (objectiveScp != null || objectiveName.StartsWith("SCP") ? "захватить " + objectiveName : "зачистить центр комплекса") + ". " + string.Join(", ", parts) + ".");
                    foreach (var s in squads)
                    {
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
                    foreach (var s in squads) { s.hold = false; s.Leader?.anim.DoSignal(Signal.MoveUp); }
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
                    if (s.Alive == 0) continue;
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
    }
}
