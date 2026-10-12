using UnityEditor;

// Карты нормалей (*_n.jpg в Resources/Textures) импортируются как Normal Map — иначе рельеф ляжет неверно
public class ScpTextureImport : AssetPostprocessor
{
    void OnPreprocessTexture()
    {
        if (!assetPath.Contains("/Resources/Textures/")) return;
        var ti = (TextureImporter)assetImporter;
        if (assetPath.EndsWith("_n.jpg") || assetPath.EndsWith("_n.png")) ti.textureType = TextureImporterType.NormalMap;
        if (assetPath.Contains("/visor_dirt")) { ti.sRGBTexture = false; ti.textureCompression = TextureImporterCompression.Uncompressed; }
        if (assetPath.Contains("/foliage_")) { ti.alphaIsTransparency = true; ti.mipMapsPreserveCoverage = true; ti.alphaTestReferenceValue = 0.4f; }
    }
}
