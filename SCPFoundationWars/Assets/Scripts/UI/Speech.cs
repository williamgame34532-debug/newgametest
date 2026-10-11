using System.Collections.Generic;
using UnityEngine;

// Реплики над головой: брифинги других групп на базе, переговоры в бою, команды.
// Видны рядом (до ~45 м) и если говорящий в кадре; голос — запись, если есть, иначе только текст.
public static class Speech
{
    class Line { public Transform who; public string name, text; public float t0, dur; public Color col; }
    static readonly List<Line> lines = new List<Line>();
    static GUIStyle nameSt, textSt;
    static Texture2D white;

    public static float Range = 45f;

    public static void Say(Transform who, string name, string text, float dur = -1f, Color? col = null, string voice = null)
    {
        if (who == null || string.IsNullOrEmpty(text)) return;
        if (dur <= 0) dur = Mathf.Clamp(1.8f + text.Length * 0.055f, 2.2f, 7.5f);
        lines.RemoveAll(l => l.who == who);
        lines.Add(new Line { who = who, name = name, text = text, t0 = Time.time, dur = dur, col = col ?? new Color(0.92f, 0.94f, 0.96f) });
        if (!string.IsNullOrEmpty(voice) && Sfx.Clip(voice) != null) Sfx.Play(voice, who.position + Vector3.up * 1.6f, 0.9f, Random.Range(0.94f, 1.06f), 60f);
    }

    public static void Clear() => lines.Clear();

    public static void Draw(float scale)
    {
        if (lines.Count == 0) return;
        var cam = Game.Cam;
        if (cam == null) return;
        if (nameSt == null)
        {
            white = Texture2D.whiteTexture;
            nameSt = new GUIStyle(GUI.skin.label) { fontSize = 11, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleLeft, wordWrap = false };
            textSt = new GUIStyle(GUI.skin.label) { fontSize = 14, alignment = TextAnchor.UpperLeft, wordWrap = true };
        }
        lines.RemoveAll(l => l.who == null || Time.time - l.t0 > l.dur);
        var old = GUI.color;
        foreach (var l in lines)
        {
            Vector3 head = l.who.position + Vector3.up * 2.05f;
            float dist = Vector3.Distance(cam.transform.position, head);
            if (dist > Range) continue;
            Vector3 sp = cam.WorldToScreenPoint(head);
            if (sp.z <= 0.2f) continue;
            // не сквозь стены
            if (Physics.Linecast(cam.transform.position, head, 1 << Layers.World, QueryTriggerInteraction.Ignore)) continue;
            float age = Time.time - l.t0;
            float a = Mathf.Clamp01(age / 0.15f) * Mathf.Clamp01((l.dur - age) / 0.4f) * Mathf.Clamp01((Range - dist) / 10f);
            float x = sp.x / scale, y = (Screen.height - sp.y) / scale;
            float w = Mathf.Clamp(textSt.CalcSize(new GUIContent(l.text)).x + 28f, 110f, 330f);
            float h = textSt.CalcHeight(new GUIContent(l.text), w - 20);
            float pop = 1f - Mathf.Clamp01(age / 0.18f);
            y -= h + 30f + pop * 8f;
            float H2 = h + 26;
            // карточка: тёмная, цветная полоса слева, хвостик к голове
            GUI.color = new Color(0.02f, 0.03f, 0.04f, 0.68f * a);
            GUI.DrawTexture(new Rect(x - w / 2, y - 6, w, H2), white);
            GUI.DrawTexture(new Rect(x - 4, y - 6 + H2, 8, 4), white);
            GUI.DrawTexture(new Rect(x - 2, y - 2 + H2, 4, 4), white);
            GUI.color = new Color(l.col.r, l.col.g, l.col.b, a);
            GUI.DrawTexture(new Rect(x - w / 2, y - 6, 3, H2), white);
            GUI.Label(new Rect(x - w / 2 + 10, y - 4, w - 20, 16), l.name.ToUpper(), nameSt);
            GUI.color = new Color(1, 1, 1, a);
            GUI.Label(new Rect(x - w / 2 + 10, y + 13, w - 20, h), l.text, textSt);
        }
        GUI.color = old;
    }
}
