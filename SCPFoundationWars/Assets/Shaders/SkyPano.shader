// Небо из фотопанорамы (равнопромежуточная проекция): настоящие облака и свет вместо нарисованных.
// Низ панорамы (земля) заменяется дымкой — её закрывает рельеф и горы.
Shader "SCP/SkyPano"
{
    Properties
    {
        _Pano ("Panorama", 2D) = "gray" {}
        _Exposure ("Exposure", Float) = 1
        _Rotation ("Rotation (deg)", Float) = 0
        _Tint ("Tint", Color) = (1,1,1,1)
        _Haze ("Horizon haze", Color) = (0.7,0.72,0.75,1)
        _HazeAmt ("Haze amount", Range(0,1)) = 0.35
        _Horizon ("Horizon height (v)", Float) = 0.5
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _Pano;
            float _Exposure, _Rotation, _HazeAmt, _Horizon;
            fixed4 _Tint, _Haze;
            struct v2f { float4 pos : SV_POSITION; float3 dir : TEXCOORD0; };
            v2f vert (appdata_base v) { v2f o; o.pos = UnityObjectToClipPos(v.vertex); o.dir = v.vertex.xyz; return o; }
            fixed4 frag (v2f i) : SV_Target
            {
                float3 d = normalize(i.dir);
                float a = radians(_Rotation);
                float s = sin(a), c = cos(a);
                d.xz = float2(d.x * c - d.z * s, d.x * s + d.z * c);
                float u = atan2(d.x, d.z) / (2 * UNITY_PI) + 0.5;
                float h = max(d.y, -0.02);
                // верхняя полусфера панорамы растягивается на всё небо выше линии горизонта снимка
                float v = lerp(_Horizon, 1, asin(saturate(h)) / (UNITY_PI * 0.5));
                // без mip-провала на шве atan2
                float3 col = tex2Dlod(_Pano, float4(u, v, 0, 0)).rgb;
                col *= _Tint.rgb * _Exposure;
                float haze = pow(1 - saturate(d.y * 3.0), 3) * _HazeAmt;
                col = lerp(col, _Haze.rgb, saturate(haze));
                if (d.y < 0) col = lerp(col, _Haze.rgb * 0.8, saturate(-d.y * 12));
                return fixed4(col, 1);
            }
            ENDCG
        }
    }
}
