using UnityEngine;

// Эффекты мира на камере сцены (до камеры оружия): затенение окружения (SSAO) и солнечные лучи сквозь листву и дымку.
[RequireComponent(typeof(Camera))]
public class WorldFX : MonoBehaviour
{
    public static bool Enabled = true;
    static Material mat;
    static Texture2D dummy;
    Camera cam;
    public float aoRadius = 0.55f, aoStrength = 0.75f, aoFar = 90f, shafts = 0.55f;
    public static bool MotionBlur = true, Dof = true, Atmos = true;
    Matrix4x4 prevVP; bool hasPrev; bool savedFog; bool fogHidden;
    float focus = 50f;

    // туман Unity выключаем на время кадра сцены — его заменяет воздушная перспектива в постобработке
    // Лампы, которые светятся в воздухе (и отбрасывают тени, если рядом) — регистрируются при постройке
    public static readonly System.Collections.Generic.List<Light> Lamps = new System.Collections.Generic.List<Light>();
    readonly Vector4[] lp = new Vector4[4], lc = new Vector4[4];
    readonly Light[] best = new Light[4]; readonly float[] bestD = new float[4];
    readonly System.Collections.Generic.List<Light> shadowed = new System.Collections.Generic.List<Light>();
    float shadowT;
    void PickLamps(Vector3 cp, bool on)
    {
        for (int k = 0; k < 4; k++) { best[k] = null; bestD[k] = 1e9f; }
        if (on)
        {
            for (int i = Lamps.Count - 1; i >= 0; i--)
            {
                var l = Lamps[i];
                if (l == null) { Lamps.RemoveAt(i); continue; }
                if (!l.enabled || !l.gameObject.activeInHierarchy || l.intensity < 0.05f) continue;
                float d = (l.transform.position - cp).sqrMagnitude;
                if (d > 40f * 40f) continue;
                for (int k = 0; k < 4; k++)
                    if (d < bestD[k]) { for (int m = 3; m > k; m--) { best[m] = best[m - 1]; bestD[m] = bestD[m - 1]; } best[k] = l; bestD[k] = d; break; }
            }
        }
        float dens = MapGen.FacilityMap || Facility.Underground(cp) ? 0.022f : 0.012f;
        for (int k = 0; k < 4; k++)
        {
            var l = best[k];
            if (l == null) { lp[k] = Vector4.zero; lc[k] = Vector4.zero; continue; }
            Vector3 p = l.transform.position;
            lp[k] = new Vector4(p.x, p.y, p.z, l.range);
            Color c = l.color * l.intensity * dens;
            lc[k] = new Vector4(c.r, c.g, c.b, 1);
        }
        mat.SetVectorArray("_LampP", lp);
        mat.SetVectorArray("_LampC", lc);
        // тени — у двух ближайших ламп (дорого, поэтому только рядом)
        if (Time.unscaledTime > shadowT)
        {
            shadowT = Time.unscaledTime + 0.4f;
            foreach (var l in shadowed) if (l != null) l.shadows = LightShadows.None;
            shadowed.Clear();
            for (int k = 0; k < 2; k++)
                if (best[k] != null && bestD[k] < 22f * 22f && best[k].type != LightType.Directional)
                {
                    best[k].shadows = LightShadows.Soft; best[k].shadowStrength = 0.85f; best[k].shadowNormalBias = 0.6f;
                    shadowed.Add(best[k]);
                }
        }
    }

    void OnPreCull()
    {
        fogHidden = false;
        if (!Enabled || !PostFX.Enabled || !Atmos) return;
        savedFog = RenderSettings.fog;
        RenderSettings.fog = false;
        fogHidden = true;
    }
    void OnPostRender() { if (fogHidden) { RenderSettings.fog = savedFog; fogHidden = false; } }

    public static void Attach(Camera c)
    {
        if (c == null || c.GetComponent<WorldFX>() != null) return;
        c.gameObject.AddComponent<WorldFX>();
    }

    void OnEnable()
    {
        cam = GetComponent<Camera>();
        cam.depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (!Enabled || !PostFX.Enabled) { Graphics.Blit(src, dst); return; }
        if (mat == null)
        {
            var sh = Shader.Find("SCP/WorldFX");
            if (sh == null || !sh.isSupported) { Graphics.Blit(src, dst); return; }
            mat = new Material(sh) { hideFlags = HideFlags.HideAndDontSave };
        }
        if (dummy == null) { dummy = new Texture2D(4, 4, TextureFormat.RGBA32, false); dummy.hideFlags = HideFlags.HideAndDontSave; }

        float tanY = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);
        mat.SetVector("_TanHalf", new Vector4(tanY * cam.aspect, tanY, 0, 0));
        bool night = MapGen.Night;
        mat.SetVector("_Params", new Vector4(aoRadius, night ? aoStrength * 0.6f : aoStrength, aoFar, 0.03f));

        int w = src.width / 2, h = src.height / 2;
        var aoFmt = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.R8) ? RenderTextureFormat.R8 : RenderTextureFormat.Default;
        var ao = RenderTexture.GetTemporary(w, h, 0, aoFmt);
        var ao2 = RenderTexture.GetTemporary(w, h, 0, aoFmt);
        ao.filterMode = ao2.filterMode = FilterMode.Bilinear;
        Graphics.Blit(dummy, ao, mat, 0);
        mat.SetVector("_Dir", new Vector4(1, 0, 0, 0)); Graphics.Blit(ao, ao2, mat, 1);
        mat.SetVector("_Dir", new Vector4(0, 1, 0, 0)); Graphics.Blit(ao2, ao, mat, 1);
        mat.SetTexture("_AO", ao);

        // солнечные лучи: только когда солнце перед камерой
        Vector3 sunDir = MapGen.SunDir;
        float facing = Vector3.Dot(cam.transform.forward, sunDir);
        Vector3 sp = cam.WorldToViewportPoint(cam.transform.position + sunDir * 1000f);
        float vis = night ? 0f : Mathf.Clamp01((facing - 0.1f) / 0.5f) * Mathf.Clamp01(1.4f - Mathf.Max(Mathf.Abs(sp.x - 0.5f), Mathf.Abs(sp.y - 0.5f)));
        RenderTexture s1 = null, s2 = null;
        if (vis > 0.01f && shafts > 0f)
        {
            int qw = src.width / 4, qh = src.height / 4;
            var sf = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf) ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.Default;
            s1 = RenderTexture.GetTemporary(qw, qh, 0, sf);
            s2 = RenderTexture.GetTemporary(qw, qh, 0, sf);
            mat.SetVector("_SunPos", new Vector4(sp.x, sp.y, vis, 0));
            Graphics.Blit(dummy, s1, mat, 2);
            mat.SetFloat("_ShaftLen", 0.6f); Graphics.Blit(s1, s2, mat, 3);
            mat.SetFloat("_ShaftLen", 0.25f); Graphics.Blit(s2, s1, mat, 3);
            mat.SetTexture("_Shafts", s1);
            Color sc = MapGen.SunColor * shafts * (MapGen.Dusk ? 1.6f : 1f);
            mat.SetVector("_SunCol", new Vector4(sc.r, sc.g, sc.b, 1));
        }
        else
        {
            mat.SetTexture("_Shafts", Texture2D.blackTexture);
            mat.SetVector("_SunPos", Vector4.zero);
        }
        // ---- воздушная перспектива ----
        Vector3 camPos = cam.transform.position;
        mat.SetVector("_CamPos", camPos);
        mat.SetVector("_RayR", cam.transform.right * tanY * cam.aspect);
        mat.SetVector("_RayU", cam.transform.up * tanY);
        mat.SetVector("_RayF", cam.transform.forward);
        bool fogOn = fogHidden ? savedFog : RenderSettings.fog;
        bool under = Facility.Underground(camPos) || MapGen.FacilityMap;
        float dens = 0f, fall = 0f, baseY = 0f;
        if (Atmos && fogOn)
        {
            if (under) { dens = RenderSettings.fogDensity * (RenderSettings.fogMode == FogMode.ExponentialSquared ? 6f : 1f); fall = 0f; }
            else { dens = 0.00055f * Mathf.Clamp(RenderSettings.fogDensity / 0.0021f, 0.5f, 3f); fall = 1f / 95f; baseY = MapGen.Height(0, 0); }
        }
        mat.SetVector("_Fog", new Vector4(dens, fall, baseY, 0.985f));
        Color fc = RenderSettings.fogColor;
        mat.SetVector("_FogCol", new Vector4(fc.r, fc.g, fc.b, 1));
        mat.SetVector("_SunDirW", MapGen.SunDir);
        Color scat = under || night ? Color.black : MapGen.SunColor * (MapGen.Dusk ? 1.3f : 0.8f);
        mat.SetVector("_SunScat", new Vector4(scat.r, scat.g, scat.b, 1));

        // ---- размытие движения (только поворот/движение камеры) ----
        var vp = cam.projectionMatrix * cam.worldToCameraMatrix;
        float mbk = MotionBlur && hasPrev && Time.timeScale > 0.01f ? (PostFX.Bodycam ? 0.65f : 0.45f) : 0f;
        mat.SetMatrix("_PrevVP", hasPrev ? prevVP : vp);
        mat.SetVector("_Motion", new Vector4(mbk, 0.035f, 0, 0));
        prevVP = vp; hasPrev = true;

        // ---- глубина резкости при прицеливании ----
        var pc = PlayerController.I;
        float ads = Dof && pc != null && !pc.dead ? pc.adsW : 0f;
        RenderTexture dof = null;
        if (ads > 0.02f)
        {
            if (Physics.Raycast(cam.transform.position, cam.transform.forward, out var fh, 600f, ~(1 << Layers.ViewModel), QueryTriggerInteraction.Ignore))
                focus = Mathf.Lerp(focus, fh.distance, 1f - Mathf.Exp(-8f * Time.unscaledDeltaTime));
            else focus = Mathf.Lerp(focus, 300f, 1f - Mathf.Exp(-4f * Time.unscaledDeltaTime));
            bool scope = pc.Current != null && pc.Current.def.scope;
            mat.SetVector("_DofP", new Vector4(Mathf.Max(focus, 3f), ads * (scope ? 1f : 0.85f), scope ? 9f : 6f, Mathf.Min(1.2f, focus * 0.3f)));
            var df = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf) ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.Default;
            dof = RenderTexture.GetTemporary(src.width / 2, src.height / 2, 0, df);
            dof.filterMode = FilterMode.Bilinear;
            Graphics.Blit(src, dof, mat, 5);
            mat.SetTexture("_Dof", dof);
        }
        else { mat.SetVector("_DofP", Vector4.zero); mat.SetTexture("_Dof", Texture2D.blackTexture); }

        // ---- объёмный свет ближайших ламп ----
        PickLamps(camPos, under || night);

        Graphics.Blit(src, dst, mat, 4);
        if (dof != null) RenderTexture.ReleaseTemporary(dof);
        RenderTexture.ReleaseTemporary(ao);
        RenderTexture.ReleaseTemporary(ao2);
        if (s1 != null) RenderTexture.ReleaseTemporary(s1);
        if (s2 != null) RenderTexture.ReleaseTemporary(s2);
    }
}
