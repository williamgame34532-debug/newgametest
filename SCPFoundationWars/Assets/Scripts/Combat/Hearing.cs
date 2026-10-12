using UnityEngine;

// Слух бойцов: выстрелы, взрывы, бег и шаги. Противник, услышавший шум, оборачивается на звук,
// докладывает направление и (если не держит позицию) осторожно идёт проверить.
public static class Hearing
{
    public static void Emit(Vector3 pos, float radius, Unit src)
    {
        if (Net.IsClient && Net.InGame) return;   // слух считает хост
        float r2 = radius * radius;
        foreach (var u in Unit.All)
        {
            if (!(u is Soldier s) || !s.alive || s.netPuppet || s.remoteHuman || s.zombie) continue;
            if (src != null && (s == src || s.team == src.team)) continue;
            float d2 = (s.transform.position - pos).sqrMagnitude;
            if (d2 > r2) continue;
            // стены и холмы глушат: за препятствием слышно вдвое хуже
            if (d2 > r2 * 0.25f && !Combat.Visible(s.EyePos, pos + Vector3.up)) continue;
            s.Hear(pos, Mathf.Sqrt(d2), src);
        }
    }

    // Громкость оружия: сколько метров слышно выстрел
    public static float GunRadius(WeaponDef d)
    {
        if (d == null) return 150f;
        if (d.suppressor) return 30f;
        switch (d.kind)
        {
            case WeaponKind.Sniper: return 420f;
            case WeaponKind.LMG: return 320f;
            case WeaponKind.Launcher: return 380f;
            case WeaponKind.Shotgun: return 260f;
            case WeaponKind.Pistol: return 160f;
            case WeaponKind.SMG: return 190f;
            default: return 260f;
        }
    }
}
