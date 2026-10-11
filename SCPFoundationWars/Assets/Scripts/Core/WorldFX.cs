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
        Graphics.Blit(src, dst, mat, 4);
        RenderTexture.ReleaseTemporary(ao);
        RenderTexture.ReleaseTemporary(ao2);
        if (s1 != null) RenderTexture.ReleaseTemporary(s1);
        if (s2 != null) RenderTexture.ReleaseTemporary(s2);
    }
}
