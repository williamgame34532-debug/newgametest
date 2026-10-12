using UnityEngine;

// Звуковая атмосфера боя: ветер, птицы, далёкий гул
public class Ambience : MonoBehaviour
{
    AudioSource wind;
    float crowT;

    public static Ambience Create(bool night, int map)
    {
        var go = new GameObject("Ambience");
        var a = go.AddComponent<Ambience>();
        a.wind = go.AddComponent<AudioSource>();
        a.wind.clip = map == MapGen.FacilityMapIndex ? null : Sfx.Clip("wind");   // в комплексе ветра нет — там свой гул
        a.wind.loop = true;
        a.wind.spatialBlend = 0f;
        a.wind.volume = (map == 3 || map == 2 ? 0.45f : night ? 0.3f : 0.22f) * Sfx.Volume;
        if (a.wind.clip != null) a.wind.Play();
        a.crowT = Time.time + Random.Range(8f, 20f);
        a.enabled = map != 2 && !night && map != MapGen.FacilityMapIndex;
        return a;
    }

    void Update()
    {
        if (Time.time < crowT) return;
        crowT = Time.time + Random.Range(18f, 45f);
        var cam = Camera.main;
        if (cam == null) return;
        Vector3 p = cam.transform.position + Quaternion.Euler(0, Random.Range(0f, 360f), 0) * Vector3.forward * Random.Range(40f, 90f) + Vector3.up * 15f;
        Sfx.Play("crow", p, 0.35f, Random.Range(0.9f, 1.1f), 140f);
    }
}
