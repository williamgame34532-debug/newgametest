using UnityEngine;

// Постобработка кадра (встроенный конвейер): вешается на верхнюю камеру стека — мир и оружие в руках обрабатываются вместе
[RequireComponent(typeof(Camera))]
public class PostFX : MonoBehaviour
{
    public static bool Enabled = true;
    public static bool Bodycam = false;
    public static bool Visor = true;     // вид из шлема: стекло маски, запотевание, HUD на визоре
    // режим вида: 0 — маска шлема, 1 — нательная камера, 2 — обычный
    public static int ViewMode { get => Bodycam ? 1 : Visor ? 0 : 2; set { Bodycam = value == 1; Visor = value == 0; } }
    static Texture2D visorTex;   // стиль нательной камеры: широкий угол, автоэкспозиция, цифровой шум
    static RenderTexture lumA, lumB;
    static Material mat;
    static PostFX current;
    public static Camera Top => current != null && current.enabled ? current.GetComponent<Camera>() : null;
    // «таркоподобная» картинка: приглушённые цвета, плотный контраст, резкость, тени с зеленцой, тёплые света
    public float exposure = 1.1f, contrast = 1.08f, saturation = 0.93f, vignette = 0.35f, grain = 0.03f, bloom = 0.3f, threshold = 1.2f, aberration = 0.0008f, sharp = 0.5f;
    public Color tint = new Color(1.0f, 1f, 0.96f);
    public Color shadowTone = new Color(0.94f, 1.0f, 1.0f), highTone = new Color(1.04f, 1.0f, 0.93f);

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
        // средняя яркость кадра → 1×1, плавная адаптация
        var s16 = RenderTexture.GetTemporary(16, 9, 0, fmt);
        var s4 = RenderTexture.GetTemporary(4, 2, 0, fmt);
        var s1 = RenderTexture.GetTemporary(1, 1, 0, fmt);
        var q = RenderTexture.GetTemporary(w, h, 0, fmt);
        Graphics.Blit(src, q); Graphics.Blit(q, s16); Graphics.Blit(s16, s4); Graphics.Blit(s4, s1);
        RenderTexture.ReleaseTemporary(q);
        if (lumA == null) { lumA = new RenderTexture(1, 1, 0, RenderTextureFormat.ARGBHalf); lumB = new RenderTexture(1, 1, 0, RenderTextureFormat.ARGBHalf); }
        mat.SetTexture("_LumPrev", lumA);
        mat.SetFloat("_AdaptK", 1f - Mathf.Exp(-1.6f * Mathf.Max(0.001f, Time.unscaledDeltaTime)));
        Graphics.Blit(s1, lumB, mat, 3);
        var tmp = lumA; lumA = lumB; lumB = tmp;
        mat.SetTexture("_Lum", lumA);
        RenderTexture.ReleaseTemporary(s16); RenderTexture.ReleaseTemporary(s4); RenderTexture.ReleaseTemporary(s1);
        // стекло маски
        if (visorTex == null) visorTex = Resources.Load<Texture2D>("Textures/visor_dirt");
        bool vis = Visor && visorTex != null && pc != null && !pc.dead && !Cinematic.Active;
        mat.SetFloat("_Visor", vis ? 1f : 0f);
        if (vis)
        {
            mat.SetTexture("_VisorTex", visorTex);
            mat.SetFloat("_VisorFog", pc.VisorFog);
            mat.SetFloat("_VisorRain", MapGen.Raining && !Facility.Underground(Game.Cam.transform.position) ? 1f : 0f);
        }
        float bc = Bodycam ? 1f : 0f;
        mat.SetFloat("_Body", bc);
        mat.SetFloat("_Fisheye", bc * 0.32f);
        mat.SetFloat("_AutoExp", bc * 0.75f);
        mat.SetFloat("_BloomAmt", bloom * (MapGen.Night ? 1.4f : 1f));
        mat.SetFloat("_Exposure", exposure * (MapGen.Night ? 1.25f : 1f));
        mat.SetFloat("_Contrast", contrast);
        mat.SetFloat("_Saturation", saturation * (MapGen.Night ? 0.8f : 1f));
        mat.SetFloat("_Vignette", vignette + hurt * 0.4f);
        mat.SetFloat("_Grain", grain * (MapGen.Night ? 1.6f : 1f));
        mat.SetFloat("_Hurt", hurt);
        mat.SetFloat("_Aberr", aberration + bc * 0.0022f);
        mat.SetFloat("_Sharp", sharp + bc * 0.45f);
        mat.SetColor("_ShadowTone", MapGen.Night ? new Color(0.92f, 0.98f, 1.06f) : shadowTone);
        mat.SetColor("_HighTone", MapGen.Night ? new Color(1f, 1f, 1f) : highTone);
        mat.SetFloat("_Time2", Time.unscaledTime % 100f);
        mat.SetColor("_Tint", MapGen.Night ? new Color(0.92f, 0.97f, 1.08f) : tint);
        Graphics.Blit(src, dst, mat, 2);
        RenderTexture.ReleaseTemporary(a);
        RenderTexture.ReleaseTemporary(b);
    }
}
