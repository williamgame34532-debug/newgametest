using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

// При первом открытии проекта: создаёт сцену Main, добавляет её в Build Settings,
// включает нужные шейдеры в сборку (материалы создаются кодом) и называет слои.
[InitializeOnLoad]
public static class ScpSetup
{
    const string ScenePath = "Assets/Scenes/Main.unity";

    static ScpSetup()
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
            Debug.Log("SCP: Война за Фонд — сцена создана: " + ScenePath + ". Нажми Play!");
        }
        if (EditorBuildSettings.scenes.Length == 0)
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        if (string.IsNullOrEmpty(SceneManager.GetActiveScene().path))
            EditorSceneManager.OpenScene(ScenePath);
        PlayerSettings.productName = "SCP: Война за Фонд";
        PlayerSettings.companyName = "SCPWars";
        IncludeShaders();
        NameLayers();
    }

    // Шейдеры, которые ищутся через Shader.Find, должны попасть в сборку
    [MenuItem("SCP Wars/Включить шейдеры в сборку")]
    static void IncludeShaders()
    {
        string[] names = { "Standard", "SCP/WorldText", "Particles/Standard Unlit", "Skybox/Procedural", "Unlit/Color", "Sprites/Default", "Legacy Shaders/Particles/Alpha Blended" };
        var gs = AssetDatabase.LoadAssetAtPath<GraphicsSettings>("ProjectSettings/GraphicsSettings.asset");
        if (gs == null) return;
        var so = new SerializedObject(gs);
        var arr = so.FindProperty("m_AlwaysIncludedShaders");
        if (arr == null) return;
        bool changed = false;
        foreach (var n in names)
        {
            var sh = Shader.Find(n);
            if (sh == null) continue;
            bool has = false;
            for (int i = 0; i < arr.arraySize; i++) if (arr.GetArrayElementAtIndex(i).objectReferenceValue == sh) has = true;
            if (has) continue;
            arr.InsertArrayElementAtIndex(arr.arraySize);
            arr.GetArrayElementAtIndex(arr.arraySize - 1).objectReferenceValue = sh;
            changed = true;
        }
        if (changed) so.ApplyModifiedProperties();
    }

    // Имена слоёв (для удобства в инспекторе; игра использует номера слоёв)
    static void NameLayers()
    {
        var assets = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/TagManager.asset");
        if (assets == null || assets.Length == 0) return;
        var so = new SerializedObject(assets[0]);
        var layers = so.FindProperty("layers");
        if (layers == null) return;
        string[] names = { null, null, null, null, null, null, null, null, null, "Bodies", "Corpses", "Player", "ViewModel", "Vehicles" };
        bool changed = false;
        for (int i = 9; i < names.Length; i++)
        {
            var p = layers.GetArrayElementAtIndex(i);
            if (string.IsNullOrEmpty(p.stringValue)) { p.stringValue = names[i]; changed = true; }
        }
        if (changed) so.ApplyModifiedProperties();
    }

    [MenuItem("SCP Wars/Сбросить сохранения")]
    static void ResetPrefs()
    {
        PlayerPrefs.DeleteAll();
        Debug.Log("SCP Wars: сохранения сброшены");
    }
}
