using System.Collections;
using UnityEngine;

// Кинематографичная вставка перелёта: камера снаружи вертолёта (сопровождение), пролёт над камерой,
// общий план района операции с титрами — затем обратно в салон. Enter/Пробел — пропустить.
public static class Cinematic
{
    public static bool Active { get; private set; }
    public static string Caption, SubCaption;
    public static float CaptionT, Fade;
    static bool skip;
    // что вернуть после вставки (даже если её прервали)
    static Camera rCam; static Transform rParent; static Vector3 rLp; static Quaternion rLr; static float rFov, rFar; static PlayerController rPc;
    static float lastTick;

    public static IEnumerator Play(Helicopter heli, PlayerController pc, string place, string sub)
    {
        if (heli == null || pc == null || Game.Cam == null) yield break;
        // ждём, пока борт наберёт высоту и пойдёт по маршруту
        float wait = Time.time + 12f;
        while (heli != null && !heli.Cruising && Time.time < wait) yield return null;
        yield return new WaitForSeconds(2.5f);
        if (heli == null || pc == null || pc.dead || !pc.riding) yield break;

        var cam = Game.Cam;
        rCam = cam; rParent = pc.camHolder != null ? pc.camHolder : cam.transform.parent; rLp = Vector3.zero; rLr = Quaternion.identity;
        rFov = cam.fieldOfView; rFar = cam.farClipPlane; rPc = pc;
        Active = true; skip = false; Caption = null; lastTick = Time.unscaledTime;
        if (pc.fp != null) pc.fp.SetVisible(false);
        PostFX.SetTop(cam);
        cam.transform.SetParent(null, true);
        float far0 = rFar;

        yield return FadeTo(1f, 0.35f);
        // 1. сопровождение: камера летит рядом с бортом и медленно обходит его
        float t0 = Time.time, d = 6.5f;
        Fade = 0f;
        while (Time.time - t0 < d && !Skip())
        {
            if (heli == null) break;
            float k = (Time.time - t0) / d;
            var h = heli.transform;
            float ang = Mathf.Lerp(-150f, -60f, k) * Mathf.Deg2Rad;
            Vector3 off = h.right * Mathf.Sin(ang) * 17f + h.forward * Mathf.Cos(ang) * 17f + Vector3.up * Mathf.Lerp(2f, 5f, k);
            Vector3 p = h.position + off;
            cam.transform.position = Vector3.Lerp(cam.transform.position, p, k < 0.02f ? 1f : 1f - Mathf.Exp(-6f * Time.deltaTime));
            cam.transform.rotation = Quaternion.LookRotation(h.position + h.forward * 4f - cam.transform.position) * Quaternion.Euler(0, 0, Mathf.Sin(Time.time * 0.7f) * 1.5f);
            cam.fieldOfView = 45f;
            yield return null;
        }
        // 2. пролёт: неподвижная камера у земли впереди по курсу, борт проходит над ней
        if (!skip && heli != null)
        {
            yield return FadeTo(1f, 0.25f);
            Vector3 v = heli.velocity; v.y = 0;
            Vector3 fwd = v.sqrMagnitude > 1f ? v.normalized : heli.transform.forward;
            Vector3 side = Vector3.Cross(Vector3.up, fwd);
            Vector3 spot = heli.transform.position + fwd * Mathf.Max(90f, v.magnitude * 3.2f) + side * 22f;
            spot.y = Battle.GroundHeight(spot) + 3.5f;
            cam.transform.position = spot;
            Fade = 0f;
            t0 = Time.time; d = 5.5f;
            while (Time.time - t0 < d && !Skip())
            {
                if (heli == null) break;
                Quaternion want = Quaternion.LookRotation(heli.transform.position - spot);
                cam.transform.rotation = Quaternion.Slerp(cam.transform.rotation, want, Time.time - t0 < 0.05f ? 1f : 1f - Mathf.Exp(-5f * Time.deltaTime));
                cam.fieldOfView = Mathf.Lerp(32f, 50f, (Time.time - t0) / d);
                yield return null;
            }
        }
        // 3. общий план района: медленный облёт цели на высоте, титры
        if (!skip && heli != null)
        {
            yield return FadeTo(1f, 0.3f);
            Vector3 c = heli.LZ;
            c.y = Battle.GroundHeight(c);
            float a0 = Random.Range(0f, 360f);
            Caption = place; SubCaption = sub; CaptionT = Time.time;
            Fade = 0f;
            t0 = Time.time; d = 7.5f;
            cam.farClipPlane = Mathf.Max(far0, 3000f);
            while (Time.time - t0 < d && !Skip())
            {
                float k = (Time.time - t0) / d;
                float a = (a0 + k * 35f) * Mathf.Deg2Rad;
                float r = Mathf.Lerp(190f, 150f, k);
                Vector3 p = c + new Vector3(Mathf.Sin(a) * r, Mathf.Lerp(70f, 55f, k), Mathf.Cos(a) * r);
                cam.transform.position = p;
                cam.transform.rotation = Quaternion.LookRotation(c + Vector3.up * 8f - p);
                cam.fieldOfView = 42f;
                yield return null;
            }
        }
        if (!skip) yield return FadeTo(1f, 0.3f);
        // обратно в салон
        Restore();
        yield return FadeTo(0f, 0.5f);
    }

    // Камера — обратно в голову игрока, оружие и постобработка — на место
    static void Restore()
    {
        Caption = null;
        if (rCam != null)
        {
            rCam.farClipPlane = rFar;
            rCam.fieldOfView = rFov;
            if (rParent != null) { rCam.transform.SetParent(rParent, false); rCam.transform.localPosition = rLp; rCam.transform.localRotation = rLr; }
        }
        if (rPc != null && rPc.fp != null && !rPc.dead) { rPc.fp.SetVisible(true); if (rPc.fp.VmCam != null) PostFX.SetTop(rPc.fp.VmCam); }
        rCam = null; rPc = null;
        Active = false;
    }

    // Вызывается каждый кадр игроком: если вставку оборвали (корутину остановили) — всё вернуть
    public static void Watchdog()
    {
        if (Active && Time.unscaledTime - lastTick > 1f) { Restore(); Fade = 0f; }
    }

    static bool Skip()
    {
        lastTick = Time.unscaledTime;
        if (rPc == null || rPc.dead || !rPc.riding) skip = true;   // высадка/гибель — вставка сразу заканчивается
        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter) || Input.GetKeyDown(KeyCode.Space)) skip = true;
        return skip;
    }

    static IEnumerator FadeTo(float target, float time)
    {
        float s = Fade;
        for (float t = 0; t < 1f; t += Time.deltaTime / time) { lastTick = Time.unscaledTime; Fade = Mathf.Lerp(s, target, t); yield return null; }
        Fade = target;
    }

    public static void Reset() { if (Active) Restore(); Active = false; Caption = null; Fade = 0f; rCam = null; rPc = null; }
}
