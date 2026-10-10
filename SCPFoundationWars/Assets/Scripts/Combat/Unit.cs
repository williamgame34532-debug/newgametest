using System.Collections.Generic;
using UnityEngine;

public static class Layers
{
    public const int World = 0;
    public const int Body = 9;       // хитбоксы живых
    public const int Corpse = 10;    // трупы
    public const int Player = 11;    // контроллер игрока
    public const int ViewModel = 12; // оружие в руках игрока
    public const int Vehicle = 13;   // вертолёты, контейнеры

    public const int ShotMask = (1 << World) | (1 << Body) | (1 << Corpse) | (1 << Player) | (1 << Vehicle);
    public const int SightMask = (1 << World) | (1 << Vehicle);

    public static void Setup()
    {
        Physics.IgnoreLayerCollision(Player, Corpse, true);
        Physics.IgnoreLayerCollision(Body, Body, true);
        Physics.IgnoreLayerCollision(Body, Player, false);
        Physics.IgnoreLayerCollision(ViewModel, World, true);
        Physics.IgnoreLayerCollision(ViewModel, Body, true);
        Physics.IgnoreLayerCollision(ViewModel, Corpse, true);
        Physics.IgnoreLayerCollision(ViewModel, Player, true);
        Physics.IgnoreLayerCollision(ViewModel, Vehicle, true);
        Physics.IgnoreLayerCollision(ViewModel, ViewModel, true);
    }
}

public enum DamageType { Bullet, Explosion, Melee, Fire, Corrosion, NeckSnap, Touch, Crush, Fall }

public struct DamageInfo
{
    public float amount;
    public Vector3 point, dir;
    public float force;
    public Unit attacker;
    public Hitbox hitbox;
    public DamageType type;
    public string weapon;
}

// Хитбокс — коллайдер части тела (голова, торс, конечности)
public class Hitbox : MonoBehaviour
{
    public Unit owner;
    public float mul = 1f;
    public bool head;
    public Rigidbody rb;
}

public class Unit : MonoBehaviour
{
    public static readonly List<Unit> All = new List<Unit>();

    public Team team;
    public string displayName = "Боец";
    public float hp = 100, maxHp = 100, armor = 0f;
    public bool alive = true;
    public SquadDef squad;
    public Transform eye;              // откуда смотрит/стреляет
    public Transform chestPoint;       // куда целятся враги
    public bool isPlayer;
    public bool isScp;
    public bool inVehicle;             // сидит в вертолёте — враги не целятся
    public float radius = 0.4f;
    public float threat = 1f;          // насколько опасен (для выбора цели)
    public Unit lastAttacker;
    public float lastHitTime = -10f;
    public float deathTime;
    public int kills;

    public virtual Vector3 AimPoint => chestPoint != null ? chestPoint.position : transform.position + Vector3.up * 1.3f;
    public virtual Vector3 EyePos => eye != null ? eye.position : transform.position + Vector3.up * 1.65f;
    public virtual Vector3 Velocity => Vector3.zero;
    public virtual Vector3 LookDir => transform.forward;
    public virtual bool Targetable => alive && !inVehicle && gameObject.activeInHierarchy;

    protected virtual void OnEnable() { if (!All.Contains(this)) All.Add(this); }
    protected virtual void OnDisable() { All.Remove(this); }

    public bool IsEnemy(Unit o) => o != null && o != this && Battle.Hostile(team, o.team);

    public virtual void TakeDamage(DamageInfo d)
    {
        if (!alive) return;
        float dmg = d.amount;
        if (d.type == DamageType.Bullet || d.type == DamageType.Explosion || d.type == DamageType.Melee)
            dmg *= 1f - armor * (d.hitbox != null && d.hitbox.head ? 0.5f : 1f);
        if (d.attacker != null && !Battle.Hostile(d.attacker.team, team) && d.attacker != this)
            dmg *= Battle.FriendlyFire;
        if (dmg <= 0) return;
        if (PreDamage(ref dmg, d)) return;
        hp -= dmg;
        lastAttacker = d.attacker;
        lastHitTime = Time.time;
        OnHurt(d, dmg);
        if (hp <= 0)
        {
            hp = 0;
            alive = false;
            deathTime = Time.time;
            if (d.attacker != null && d.attacker != this) d.attacker.kills++;
            Battle.ReportKill(d.attacker, this, d);
            Die(d);
        }
    }

    protected virtual void OnHurt(DamageInfo d, float dmg) { }

    // true — урон поглощён (например, ослабленный SCP больше не получает урона)
    protected virtual bool PreDamage(ref float dmg, DamageInfo d) => false;

    // Эффект попадания пули (кровь, искры по бетону и т.п.)
    public virtual void HitFx(Vector3 point, Vector3 normal, Vector3 dir, Hitbox hb)
    {
        Fx.Blood(point, dir, hb != null && hb.head ? 1.4f : 1f, hb != null ? hb.transform : null);
        if (Random.value < 0.5f) Sfx.Play("flesh", point, 0.45f, Random.Range(0.85f, 1.15f), 25f);
    }

    // Попадание в труп — толкаем тело
    public virtual void CorpseHit(Hitbox hb, Vector3 point, Vector3 impulse)
    {
        if (hb.rb != null && !hb.rb.isKinematic) hb.rb.AddForceAtPosition(impulse * 0.08f, point, ForceMode.Impulse);
    }
    protected virtual void Die(DamageInfo d) { }

    // Ручное убийство (например, после боя)
    public void Kill(DamageType t = DamageType.Melee)
    {
        TakeDamage(new DamageInfo { amount = 99999, type = t, point = AimPoint, dir = Vector3.down });
    }
}

// Физические утилиты боя
public static class Combat
{
    static readonly RaycastHit[] hits = new RaycastHit[48];
    static readonly Collider[] overlaps = new Collider[256];

    public static Unit OwnerOf(Collider c)
    {
        if (c == null) return null;
        var hb = c.GetComponent<Hitbox>();
        if (hb != null) return hb.owner;
        return c.GetComponentInParent<Unit>();
    }

    // Луч, игнорирующий стрелка (и его хитбоксы)
    public static bool Ray(Vector3 origin, Vector3 dir, float dist, Unit ignore, out RaycastHit result, int mask = Layers.ShotMask)
    {
        int n = Physics.RaycastNonAlloc(origin, dir, hits, dist, mask, QueryTriggerInteraction.Ignore);
        float best = float.MaxValue;
        result = default(RaycastHit);
        bool found = false;
        for (int i = 0; i < n; i++)
        {
            var h = hits[i];
            if (h.distance >= best) continue;
            if (ignore != null)
            {
                var hb = h.collider.GetComponent<Hitbox>();
                if (hb != null && hb.owner == ignore) continue;
                if (h.collider.transform.IsChildOf(ignore.transform)) continue;
            }
            best = h.distance;
            result = h;
            found = true;
        }
        return found;
    }

    // Видимость точки (только мир и техника загораживают)
    public static bool Visible(Vector3 from, Vector3 to)
    {
        Vector3 d = to - from;
        float dist = d.magnitude;
        if (dist < 0.01f) return true;
        return !Physics.Raycast(from, d / dist, dist - 0.2f, Layers.SightMask, QueryTriggerInteraction.Ignore);
    }

    public static void Explode(Vector3 pos, float radius, float damage, Unit attacker, string weapon = "Взрыв", float force = 900f)
    {
        Fx.Explosion(pos, radius * 0.6f);
        Sfx.Play("explosion", pos, 1f, Random.Range(0.85f, 1.1f), 260f);
        // урон живым
        var done = new HashSet<Unit>();
        foreach (var u in Unit.All.ToArray())
        {
            if (u == null || !u.alive) continue;
            float d = Vector3.Distance(u.AimPoint, pos);
            if (d > radius) continue;
            if (!Combat.Visible(pos + Vector3.up * 0.3f, u.AimPoint) && d > radius * 0.35f) continue;
            float k = 1f - d / radius;
            done.Add(u);
            u.TakeDamage(new DamageInfo { amount = damage * (0.25f + 0.75f * k * k), point = u.AimPoint, dir = (u.AimPoint - pos).normalized, force = force * k, attacker = attacker, type = DamageType.Explosion, weapon = weapon });
        }
        // разлёт тел и предметов
        int n = Physics.OverlapSphereNonAlloc(pos, radius * 1.3f, overlaps, ~0, QueryTriggerInteraction.Ignore);
        for (int i = 0; i < n; i++)
        {
            var rb = overlaps[i].attachedRigidbody;
            if (rb == null || rb.isKinematic) continue;
            rb.AddExplosionForce(force * 0.12f * rb.mass, pos, radius * 1.3f, 1.2f, ForceMode.Impulse);
        }
        foreach (var heli in Helicopter.Active.ToArray())
        {
            if (heli == null) continue;
            float d = Vector3.Distance(heli.transform.position, pos);
            if (d < radius + 3f) heli.Damage(damage * (1f - d / (radius + 3f)) * 1.5f, attacker);
        }
    }

    public static int OverlapUnits(Vector3 pos, float radius, List<Unit> result)
    {
        result.Clear();
        foreach (var u in Unit.All)
            if (u != null && u.alive && (u.transform.position - pos).sqrMagnitude < radius * radius) result.Add(u);
        return result.Count;
    }
}
