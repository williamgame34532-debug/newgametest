using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

// При первом открытии проекта создаёт сцену Main и добавляет её в Build Settings.
// Сама игра стартует из кода (Game.Boot), поэтому сцена может быть пустой.
[InitializeOnLoad]
public static class StickmanSetup
{
    const string ScenePath = "Assets/Scenes/Main.unity";

    static StickmanSetup()
    {
        EditorApplication.delayCall += Setup;
    }

    static void Setup()
    {
        if (EditorApplication.isPlayingOrWillChangePlaymode) return;
        if (!System.IO.File.Exists(ScenePath))
        {
            System.IO.Directory.CreateDirectory("Assets/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, ScenePath);
            AssetDatabase.Refresh();
            Debug.Log("Stickman Legends: сцена создана — " + ScenePath + ". Нажми Play!");
        }
        if (EditorBuildSettings.scenes.Length == 0)
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        if (string.IsNullOrEmpty(SceneManager.GetActiveScene().path))
            EditorSceneManager.OpenScene(ScenePath);
        PlayerSettings.productName = "Stickman Legends";
        PlayerSettings.companyName = "StickWars";
        ApplyBranding();
    }

    const string IconPath = "Assets/Resources/Branding/Icon.png";
    const string SplashPath = "Assets/Resources/Branding/SplashBG.png";
    const string LogoPath = "Assets/Resources/Branding/Logo.png";

    // Иконка игры вместо стандартной и заставка Unity в стиле игры (кровавый закат, силуэты, логотип)
    [MenuItem("Stickman Legends/Применить иконку и заставку")]
    static void ApplyBranding()
    {
        if (!System.IO.File.Exists(IconPath)) return;
        SetImport(IconPath, TextureImporterType.Default);
        SetImport(SplashPath, TextureImporterType.Sprite);
        SetImport(LogoPath, TextureImporterType.Sprite);

        var icon = AssetDatabase.LoadAssetAtPath<Texture2D>(IconPath);
        if (icon != null)
        {
            // иконка по умолчанию (для всех платформ) + отдельно для Windows/Mac/Linux
            PlayerSettings.SetIconsForTargetGroup(BuildTargetGroup.Unknown, new[] { icon });
            var standalone = PlayerSettings.GetIconSizesForTargetGroup(BuildTargetGroup.Standalone);
            var arr = new Texture2D[standalone.Length];
            for (int i = 0; i < arr.Length; i++) arr[i] = icon;
            PlayerSettings.SetIconsForTargetGroup(BuildTargetGroup.Standalone, arr);
        }

        var bg = AssetDatabase.LoadAssetAtPath<Sprite>(SplashPath);
        var logo = AssetDatabase.LoadAssetAtPath<Sprite>(LogoPath);
        PlayerSettings.SplashScreen.show = true;
        PlayerSettings.SplashScreen.backgroundColor = new Color(0.07f, 0.01f, 0.03f);
        if (bg != null) { PlayerSettings.SplashScreen.background = bg; PlayerSettings.SplashScreen.backgroundPortrait = bg; }
        PlayerSettings.SplashScreen.overlayOpacity = 0f;
        PlayerSettings.SplashScreen.animationMode = PlayerSettings.SplashScreen.AnimationMode.Dolly;
        PlayerSettings.SplashScreen.unityLogoStyle = PlayerSettings.SplashScreen.UnityLogoStyle.LightOnDark;
        PlayerSettings.SplashScreen.drawMode = PlayerSettings.SplashScreen.DrawMode.UnityLogoBelow;
        if (logo != null) PlayerSettings.SplashScreen.logos = new[] { PlayerSettings.SplashScreenLogo.Create(2.5f, logo) };
        // логотип Unity можно убрать только на Unity Plus/Pro — на Personal он останется маленьким под нашим логотипом
        try { PlayerSettings.SplashScreen.showUnityLogo = false; } catch { }
    }

    static void SetImport(string path, TextureImporterType type)
    {
        var imp = AssetImporter.GetAtPath(path) as TextureImporter;
        if (imp == null) return;
        bool changed = imp.textureType != type || imp.mipmapEnabled || !imp.alphaIsTransparency;
        if (!changed) return;
        imp.textureType = type;
        if (type == TextureImporterType.Sprite) imp.spriteImportMode = SpriteImportMode.Single;
        imp.alphaIsTransparency = true;
        imp.mipmapEnabled = false;
        imp.npotScale = TextureImporterNPOTScale.None;
        imp.textureCompression = TextureImporterCompression.Uncompressed;
        imp.SaveAndReimport();
    }

    [MenuItem("Stickman Legends/Сбросить сохранения")]
    static void ResetSave()
    {
        PlayerPrefs.DeleteKey("stickman_legends_save_v1");
        PlayerPrefs.Save();
        Debug.Log("Сохранения Stickman Legends удалены.");
    }
}
