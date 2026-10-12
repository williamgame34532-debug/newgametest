using UnityEngine;

// Дождь: струи вокруг камеры, шум ливня, мокрые поверхности (глобальный _Wetness для рельефа и построек).
// Под землёй и под крышей вертолёта струи не видны, звук глушится.
public class Weather : MonoBehaviour
{
    ParticleSystem rain;
    AudioSource hiss;
    float wet;

    public static Weather Create()
    {
        var go = new GameObject("Weather");
        var w = go.AddComponent<Weather>();
        w.Build();
        return w;
    }

    void Build()
    {
        var pgo = new GameObject("rain");
        pgo.transform.SetParent(transform, false);
        rain = pgo.AddComponent<ParticleSystem>();
        rain.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        var main = rain.main;
        main.loop = true; main.playOnAwake = false;
        main.startLifetime = 1.3f;
        main.startSpeed = new ParticleSystem.MinMaxCurve(17f, 23f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.012f, 0.022f);
        main.startColor = new Color(0.75f, 0.8f, 0.85f, 0.38f);
        main.maxParticles = 9000;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.gravityModifier = 0.4f;
        var em = rain.emission; em.rateOverTime = 5200f;
        var sh = rain.shape; sh.shapeType = ParticleSystemShapeType.Box; sh.scale = new Vector3(44f, 44f, 1f);
        pgo.transform.localRotation = Quaternion.Euler(90f, 0, 0);   // вниз
        var vel = rain.velocityOverLifetime; vel.enabled = true; vel.space = ParticleSystemSimulationSpace.World;
        vel.x = new ParticleSystem.MinMaxCurve(0.9f, 1.6f); vel.y = new ParticleSystem.MinMaxCurve(0f, 0f); vel.z = new ParticleSystem.MinMaxCurve(0.3f, 0.7f);
        var col = rain.collision; col.enabled = true; col.type = ParticleSystemCollisionType.World; col.mode = ParticleSystemCollisionMode.Collision3D;
        col.lifetimeLoss = 1f; col.quality = ParticleSystemCollisionQuality.Low; col.collidesWith = 1 << Layers.World;
        var r = pgo.GetComponent<ParticleSystemRenderer>();
        r.renderMode = ParticleSystemRenderMode.Stretch;
        r.velocityScale = 0.035f; r.lengthScale = 1f;
        var shd = Shader.Find("Legacy Shaders/Particles/Alpha Blended") ?? Shader.Find("Particles/Standard Unlit");
        var m = new Material(shd);
        m.mainTexture = Streak();
        if (m.HasProperty("_TintColor")) m.SetColor("_TintColor", new Color(0.6f, 0.62f, 0.66f, 0.35f));
        r.sharedMaterial = m;
        r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        r.receiveShadows = false;
        rain.Play();
        hiss = gameObject.AddComponent<AudioSource>();
        hiss.clip = Sfx.Clip("rain"); hiss.loop = true; hiss.spatialBlend = 0f; hiss.volume = 0f;
        if (hiss.clip != null) hiss.Play();
    }

    static Texture2D Streak()
    {
        var t = new Texture2D(8, 64, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        for (int y = 0; y < 64; y++)
            for (int x = 0; x < 8; x++)
            {
                float a = Mathf.Clamp01(1f - Mathf.Abs(x - 3.5f) / 3.5f) * Mathf.Sin(y / 63f * Mathf.PI);
                t.SetPixel(x, y, new Color(1, 1, 1, a));
            }
        t.Apply();
        return t;
    }

    void LateUpdate()
    {
        var cam = Game.Cam;
        if (cam == null) return;
        bool under = Facility.Underground(cam.transform.position);
        Vector3 p = cam.transform.position + new Vector3(0, 14f, 0) + Vector3.ProjectOnPlane(cam.transform.forward, Vector3.up) * 10f;
        rain.transform.position = p;
        var em = rain.emission; em.enabled = !under;
        wet = Mathf.MoveTowards(wet, 1f, Time.deltaTime / 20f);
        Shader.SetGlobalFloat("_Wetness", wet);
        if (hiss != null) hiss.volume = Mathf.MoveTowards(hiss.volume, (under ? 0.05f : 0.42f) * Sfx.Volume, Time.deltaTime);
    }

    void OnDestroy() { Shader.SetGlobalFloat("_Wetness", 0f); }
}
