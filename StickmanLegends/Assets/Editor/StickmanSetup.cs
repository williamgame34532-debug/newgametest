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
    }

    [MenuItem("Stickman Legends/Сбросить сохранения")]
    static void ResetSave()
    {
        PlayerPrefs.DeleteKey("stickman_legends_save_v1");
        PlayerPrefs.Save();
        Debug.Log("Сохранения Stickman Legends удалены.");
    }
}
