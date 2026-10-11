using UnityEngine;

// Предмет содержания «по лору»: его несёт один из бойцов группы Фонда.
// Без него Фонд не может завершить захват ослабленного объекта: носитель подходит вплотную и применяет предмет.
// Если носитель погиб — предмет падает, его подбирает игрок или другой боец Фонда.
public class LoreItemDef
{
    public ScpKind scp;
    public string name, apply, done;
    public int shape;   // 0 — мешок, 1 — динамик, 2 — канистры, 3 — свёрток, 4 — ремни, 5 — кейс
}

public class LoreItem : MonoBehaviour
{
    public static LoreItem Active;
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
            case ScpKind.S106: return new LoreItemDef { scp = k, name = "Запись «ломателя бёдер» (протокол возврата)", apply = "Включаем запись протокола возврата…", done = "SCP-106 приманен и сдерживается.", shape = 1 };
            case ScpKind.S682: return new LoreItemDef { scp = k, name = "Канистры с соляной кислотой", apply = "Заливаем объект кислотой…", done = "SCP-682 обездвижен кислотой.", shape = 2 };
            case ScpKind.S173: return new LoreItemDef { scp = k, name = "Брезент и стропы для переноски", apply = "Накрываем статую брезентом, не моргать!", done = "SCP-173 накрыт и связан.", shape = 3 };
            case ScpKind.S049: return new LoreItemDef { scp = k, name = "Смирительные ремни", apply = "Фиксируем SCP-049…", done = "SCP-049 зафиксирован.", shape = 4 };
            case ScpKind.S939: return new LoreItemDef { scp = k, name = "Дротики с транквилизатором", apply = "Вводим транквилизатор…", done = "SCP-939 усыплён.", shape = 5 };
            default: return null;
        }
    }

    public static void Clear() { if (Active != null) Destroy(Active.gameObject); Active = null; }

    public static LoreItem Spawn(LoreItemDef def, Unit carrier)
    {
        Clear();
        if (def == null || carrier == null) return null;
        var go = new GameObject("loreItem");
        var li = go.AddComponent<LoreItem>();
        li.def = def;
        li.prop = BuildProp(def.shape).transform;
        li.prop.SetParent(go.transform, false);
        li.AttachTo(carrier);
        Active = li;
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
        // применяем к ослабленному объекту рядом
        ScpUnit near = null;
        foreach (var u in Unit.All)
            if (u is ScpUnit su && su.kind == def.scp && su.subdued && !su.captured && !su.itemApplied && (su.transform.position - carrier.transform.position).sqrMagnitude < 9f) { near = su; break; }
        if (near == null) { applyK = Mathf.MoveTowards(applyK, 0f, Time.deltaTime); applying = null; return; }
        if (applying != near) { applying = near; applyK = 0f; Battle.Message(def.apply, new Color(0.8f, 0.9f, 1f), 3.5f); }
        applyK += Time.deltaTime / 3.5f;
        near.subduedUntil = Mathf.Max(near.subduedUntil, Time.time + 8f);
        if (applyK >= 1f)
        {
            used = true;
            near.itemApplied = true;
            Battle.Message(def.done + " Удерживайте зону для эвакуации.", new Color(0.5f, 1f, 0.6f), 5f);
            Sfx.Play2D("radio", 0.5f);
            // мешок остаётся на голове 096; остальное уходит в дело
            if (def.scp == ScpKind.S096 && near is HumanScp hs && hs.rig != null)
            {
                transform.SetParent(hs.rig.b[HumanRig.Head], false);
                transform.localPosition = new Vector3(0, 0.12f, 0.02f);
                transform.localRotation = Quaternion.identity;
                transform.localScale = Vector3.one * 1.25f;
                prop.gameObject.SetActive(true);
            }
            else prop.gameObject.SetActive(false);
        }
    }

    // Куда идти носителю (ИИ): к ослабленному объекту
    public bool Goal(out Vector3 p)
    {
        p = Vector3.zero;
        if (used || carrier == null) return false;
        foreach (var u in Unit.All)
            if (u is ScpUnit su && su.kind == def.scp && su.subdued && !su.captured && !su.itemApplied) { p = su.transform.position; return true; }
        return false;
    }
}
