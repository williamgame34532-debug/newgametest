using UnityEngine;

// Постобработка кадра (встроенный конвейер): вешается на верхнюю камеру стека — мир и оружие в руках обрабатываются вместе
[RequireComponent(typeof(Camera))]
public class PostFX : MonoBehaviour
{
    public static bool Enabled = true;
    static Material mat;
    static PostFX current;
    public float exposure = 1.05f, contrast = 1.08f, saturation = 1.05f, vignette = 0.45f, grain = 0.035f, bloom = 0.55f, threshold = 1.0f, aberration = 0.0015f;
    public Color tint = new Color(1.02f, 1f, 0.97f);

    // Переносит эффект на камеру c (например, камеру оружия), с остальных снимает
    public static void SetTop(Camera c)
    {
        if (c == null) return;
        if (current != null && current.gameObject != c.gameObject) current.enabled = false;
        current = c.GetComponent<PostFX>();
        if (current == null) current = c.gameObject.AddComponent<PostFX>();
        current.enabled = true;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (!Enabled) { Graphics.Blit(src, dst); return; }
        if (mat == null)
        {
            var sh = Shader.Find("SCP/Post");
            if (sh == null || !sh.isSupported) { Graphics.Blit(src, dst); return; }
            mat = new Material(sh) { hideFlags = HideFlags.HideAndDontSave };
        }
        // настроение по времени суток
        float hurt = 0f;
        var pc = PlayerController.I;
        if (pc != null && !pc.dead) hurt = Mathf.Clamp01(pc.hurt * 0.8f + Mathf.Clamp01(0.4f - pc.unit.hp / pc.unit.maxHp) * 1.5f);
        else if (pc != null && pc.dead) hurt = 0.6f;
        int w = src.width / 4, h = src.height / 4;
        var fmt = src.format;
        var a = RenderTexture.GetTemporary(w, h, 0, fmt);
        var b = RenderTexture.GetTemporary(w, h, 0, fmt);
        mat.SetFloat("_Threshold", threshold);
        Graphics.Blit(src, a, mat, 0);
        for (int i = 0; i < 2; i++)
        {
            mat.SetVector("_Dir", new Vector4(1.5f + i, 0, 0, 0)); Graphics.Blit(a, b, mat, 1);
            mat.SetVector("_Dir", new Vector4(0, 1.5f + i, 0, 0)); Graphics.Blit(b, a, mat, 1);
        }
        mat.SetTexture("_Bloom", a);
        mat.SetFloat("_BloomAmt", bloom * (MapGen.Night ? 1.4f : 1f));
        mat.SetFloat("_Exposure", exposure * (MapGen.Night ? 1.25f : 1f));
        mat.SetFloat("_Contrast", contrast);
        mat.SetFloat("_Saturation", saturation * (MapGen.Night ? 0.8f : 1f));
        mat.SetFloat("_Vignette", vignette + hurt * 0.4f);
        mat.SetFloat("_Grain", grain * (MapGen.Night ? 1.6f : 1f));
        mat.SetFloat("_Hurt", hurt);
        mat.SetFloat("_Aberr", aberration);
        mat.SetFloat("_Time2", Time.unscaledTime % 100f);
        mat.SetColor("_Tint", MapGen.Night ? new Color(0.92f, 0.97f, 1.08f) : tint);
        Graphics.Blit(src, dst, mat, 2);
        RenderTexture.ReleaseTemporary(a);
        RenderTexture.ReleaseTemporary(b);
    }
}
