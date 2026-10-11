using UnityEngine;

// Предмет содержания «по лору»: его несёт один из бойцов группы Фонда.
// Без него Фонд не может завершить захват ослабленного объекта: носитель подходит вплотную и применяет предмет.
// Если носитель погиб — предмет падает, его подбирает игрок или другой боец Фонда.
public class LoreItemDef
{
    public ScpKind scp;
    public string name, apply, done;
    public int shape;        // 0 — мешок, 1 — динамик, 2 — канистры, 3 — свёрток, 4 — ремни, 5 — кейс
    public float range = 2.5f, time = 3.5f;
    public int charges = 1;  // дротики — несколько
    public bool needSubdued; // 682: сначала измотать огнём
}

public class LoreItem : MonoBehaviour
{
    public static readonly System.Collections.Generic.List<LoreItem> All = new System.Collections.Generic.List<LoreItem>();
    public static LoreItem Active => All.Count > 0 ? All[0] : null;
    public static LoreItem Find(ScpKind k) { foreach (var li in All) if (li != null && li.def.scp == k) return li; return null; }
    public int charges;
    public LoreItemDef def;
    public Unit carrier;
    public bool used;
    public float applyK;          // прогресс применения 0..1 (для интерфейса)
    public ScpUnit applying;
    Transform prop;
    Rigidbody body;

    public static LoreItemDef For(ScpKind k)
    {
        switch (k)
        {
            case ScpKind.S096: return new LoreItemDef { scp = k, name = "Мешок на голову", apply = "Надеваем мешок на голову SCP-096…", done = "Мешок на голове SCP-096. Лицо закрыто.", shape = 0 };
            case ScpKind.S106: return new LoreItemDef { scp = k, name = "Запись «ломателя бёдер» (протокол возврата)", apply = "Включаем запись протокола возврата — приманиваем 106…", done = "SCP-106 приманен и возвращён в камеру.", shape = 1, range = 22f, time = 6f };
            case ScpKind.S682: return new LoreItemDef { scp = k, name = "Канистры с соляной кислотой", apply = "Заливаем объект кислотой…", done = "SCP-682 обездвижен кислотой.", shape = 2, range = 4.5f, time = 4f, needSubdued = true };
            case ScpKind.S173: return new LoreItemDef { scp = k, name = "Брезент и стропы для переноски", apply = "Накрываем статую брезентом, не моргать!", done = "SCP-173 накрыт и связан.", shape = 3, time = 3f };
            case ScpKind.S049: return new LoreItemDef { scp = k, name = "Смирительные ремни", apply = "Фиксируем SCP-049…", done = "SCP-049 зафиксирован.", shape = 4 };
            case ScpKind.S939: return new LoreItemDef { scp = k, name = "Дротики с транквилизатором", apply = "Стреляем дротиком…", done = "SCP-939 усыплён.", shape = 5, range = 18f, time = 1.6f, charges = 14 };
            default: return null;
        }
    }

    public static void Clear() { foreach (var li in All) if (li != null) Destroy(li.gameObject); All.Clear(); }

    public static LoreItem Spawn(LoreItemDef def, Unit carrier)
    {
        if (def == null || carrier == null) return null;
        var go = new GameObject("loreItem");
        var li = go.AddComponent<LoreItem>();
        li.def = def;
        li.charges = def.charges;
        li.prop = BuildProp(def.shape).transform;
        li.prop.SetParent(go.transform, false);
        li.AttachTo(carrier);
        All.Add(li);
        return li;
    }

    static GameObject BuildProp(int shape)
    {
        var p = new GameObject("prop");
        var t = p.transform;
        switch (shape)
        {
            case 0: MeshKit.Ball(t, Vector3.zero, new Vector3(0.28f, 0.34f, 0.18f), new Color(0.32f, 0.28f, 0.2f)); MeshKit.Cyl(t, new Vector3(0, 0.16f, 0), 0.08f, 0.06f, new Color(0.25f, 0.2f, 0.12f)); break;
            case 1: MeshKit.Box(t, Vector3.zero, new Vector3(0.24f, 0.18f, 0.12f), new Color(0.2f, 0.22f, 0.2f)); MeshKit.Cyl(t, new Vector3(0, 0, 0.065f), 0.12f, 0.01f, new Color(0.06f, 0.06f, 0.06f), new Vector3(90, 0, 0)); break;
            case 2: for (int i = -1; i <= 1; i += 2) MeshKit.Box(t, new Vector3(i * 0.07f, 0, 0), new Vector3(0.12f, 0.3f, 0.1f), new Color(0.75f, 0.68f, 0.2f)); break;
            case 3: MeshKit.Cyl(t, Vector3.zero, 0.16f, 0.4f, new Color(0.3f, 0.34f, 0.24f), new Vector3(0, 0, 90)); break;
            case 4: MeshKit.Box(t, Vector3.zero, new Vector3(0.22f, 0.22f, 0.08f), new Color(0.12f, 0.1f, 0.08f)); MeshKit.Box(t, new Vector3(0, 0, 0.045f), new Vector3(0.2f, 0.03f, 0.01f), new Color(0.7f, 0.7f, 0.7f)); break;
            default: MeshKit.Box(t, Vector3.zero, new Vector3(0.3f, 0.2f, 0.09f), new Color(0.75f, 0.75f, 0.72f)); MeshKit.Box(t, new Vector3(0, 0.06f, 0.05f), new Vector3(0.22f, 0.03f, 0.01f), new Color(0.85f, 0.15f, 0.1f)); break;
        }
        MeshKit.CombineParts(t);
        return p;
    }

    void AttachTo(Unit u)
    {
        carrier = u;
        if (body != null) { Destroy(body); body = null; var c = GetComponent<Collider>(); if (c != null) Destroy(c); }
        Transform anchor = u.transform;
        Vector3 local = new Vector3(0, 1.25f, -0.28f);
        if (u is Soldier s && s.rig != null) { anchor = s.rig.b[HumanRig.Chest]; local = new Vector3(0, 0.05f, -0.3f); }
        transform.SetParent(anchor, false);
        transform.localPosition = local;
        transform.localRotation = Quaternion.identity;
        gameObject.layer = anchor.gameObject.layer;
        if (u.isPlayer) prop.gameObject.SetActive(false);   // своя ноша за спиной не видна
        else prop.gameObject.SetActive(true);
    }

    void Drop()
    {
        Vector3 p = transform.position;
        transform.SetParent(null, true);
        carrier = null;
        prop.gameObject.SetActive(true);
        gameObject.layer = Layers.Corpse;
        var bc = gameObject.AddComponent<BoxCollider>(); bc.size = new Vector3(0.3f, 0.3f, 0.2f);
        body = gameObject.AddComponent<Rigidbody>(); body.mass = 2f;
        Battle.Message("Носитель погиб: «" + def.name + "» на земле — подберите!", new Color(1f, 0.6f, 0.3f), 5f);
    }

    void Update()
    {
        if (used) return;
        if (carrier != null && (!carrier.alive || (carrier is Soldier cs && cs.zombie))) Drop();
        if (carrier == null)
        {
            // подбирает ближайший живой боец Фонда или игрок
            foreach (var u in Unit.All)
            {
                if (u == null || !u.alive || u.isScp || u.team != Team.Foundation || u.inVehicle) continue;
                if ((u.transform.position - transform.position).sqrMagnitude > 2.2f) continue;
                AttachTo(u);
                Battle.Message((u.isPlayer ? "Вы подобрали" : (u is Soldier s ? s.CallSign : u.displayName) + " подобрал") + ": «" + def.name + "»", new Color(0.7f, 0.9f, 1f), 4f);
                break;
            }
            applyK = 0f; applying = null;
            return;
        }
        // применяем к объекту рядом, если его состояние позволяет (096 — только спокойного, 682 — измотанного)
        ScpUnit near = null; float nd = float.MaxValue;
        foreach (var u in Unit.All)
            if (u is ScpUnit su && Ready(su))
            {
                float d = (su.transform.position - carrier.transform.position).magnitude;
                if (d < def.range && d < nd) { nd = d; near = su; }
            }
        if (near == null) { applyK = Mathf.MoveTowards(applyK, 0f, Time.deltaTime); applying = null; return; }
        if (applying != near) { applying = near; applyK = 0f; Battle.Message(def.apply, new Color(0.8f, 0.9f, 1f), 3.5f); if (def.scp == ScpKind.S106) Sfx.Play("scream", carrier.transform.position, 0.6f, 0.55f, 80f); }
        applyK += Time.deltaTime / def.time;
        if (near.subdued) near.subduedUntil = Mathf.Max(near.subduedUntil, Time.time + 8f);
        if (applyK >= 1f)
        {
            applyK = 0f; applying = null;
            charges--;
            if (def.scp == ScpKind.S939 && Random.value < 0.45f) { Battle.Message("Дротик не взял — ещё один!", new Color(1f, 0.8f, 0.4f), 2.5f); if (charges <= 0) Finish(); return; }
            near.itemApplied = true;
            Battle.Message(def.done + (def.scp == ScpKind.S106 ? "" : " Удерживайте зону для эвакуации."), new Color(0.5f, 1f, 0.6f), 5f);
            Sfx.Play2D("radio", 0.5f);
            if (def.scp == ScpKind.S106) near.Capture(Team.Foundation);   // протокол возврата: сам уходит в камеру
            else near.Neutralize();
            if (def.scp == ScpKind.S096 && near is HumanScp hs && hs.rig != null)
            {
                // мешок остаётся на голове
                var bag = BuildProp(0).transform;
                bag.SetParent(hs.rig.b[HumanRig.Head], false);
                bag.localPosition = new Vector3(0, 0.12f, 0.02f);
                bag.localScale = Vector3.one * 1.25f;
            }
            if (charges <= 0) Finish();
        }
    }

    void Finish() { used = true; prop.gameObject.SetActive(false); }

    bool Ready(ScpUnit su)
    {
        if (su == null || su.kind != def.scp || su.captured || !su.alive || su.itemApplied) return false;
        if (def.needSubdued && !su.subdued) return false;
        if (su is Scp096 s096 && s096.Enraged) return false;   // в ярости к нему не подойти — ждать, пока успокоится
        return true;
    }

    // Куда идти носителю (ИИ): к ослабленному объекту
    public bool Goal(out Vector3 p)
    {
        p = Vector3.zero;
        if (used || carrier == null) return false;
        float best = float.MaxValue;
        foreach (var u in Unit.All)
            if (u is ScpUnit su && Ready(su))
            {
                float d = (su.transform.position - carrier.transform.position).sqrMagnitude;
                if (d < best) { best = d; p = su.transform.position + (carrier.transform.position - su.transform.position).normalized * Mathf.Max(1.4f, def.range * 0.6f); }
            }
        if (best < float.MaxValue) return true;
        // объект ещё не готов (682 не измотан, 096 в ярости) — подходим на безопасное расстояние и ждём
        foreach (var u in Unit.All)
            if (u is ScpUnit su && su.kind == def.scp && su.alive && !su.captured && !su.itemApplied)
            {
                Vector3 away = carrier.transform.position - su.transform.position; away.y = 0;
                if (away.sqrMagnitude < 0.01f) away = Vector3.forward;
                p = su.transform.position + away.normalized * 16f;
                return true;
            }
        return false;
    }
}
