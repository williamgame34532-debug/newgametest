// Архитектура: текстура проецируется по мировым осям с реальным шагом (без растяжения на больших коробках),
// крупная вариация из той же текстуры ломает повтор, низ стен темнее (грязь, сырость)
Shader "SCP/Triplanar"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Scale ("Tile size (m)", Float) = 3
        _Glossiness ("Smoothness", Range(0,1)) = 0.15
        _Metallic ("Metallic", Range(0,1)) = 0
        _Grime ("Variation", Range(0,1)) = 0.4
        _Base ("Ground Y", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
        sampler2D _MainTex;
        fixed4 _Color;
        float _Scale, _Base;
        half _Glossiness, _Metallic, _Grime;
        float _Wetness;
        struct Input { float3 worldPos; float3 worldNormal; };
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float3 n = abs(normalize(IN.worldNormal));
            n = n * n; n = n * n; n /= (n.x + n.y + n.z);
            float3 p = IN.worldPos / _Scale;
            fixed4 c = tex2D(_MainTex, p.zy) * n.x + tex2D(_MainTex, p.xz) * n.y + tex2D(_MainTex, p.xy) * n.z;
            fixed4 m = tex2D(_MainTex, p.zy * 0.11 + 0.37) * n.x + tex2D(_MainTex, p.xz * 0.11 + 0.13) * n.y + tex2D(_MainTex, p.xy * 0.11 + 0.71) * n.z;
            float lum = dot(m.rgb, float3(0.3, 0.59, 0.11));
            c.rgb *= lerp(1.0, 0.7 + lum * 0.6, _Grime);
            // потёки и сырость у земли
            float wet = saturate(1.0 - (IN.worldPos.y - _Base) / 1.2) * (1.0 - n.y);
            c.rgb *= 1.0 - wet * 0.22 * _Grime;
            // дождь: поверхность темнеет и блестит, сильнее сверху
            float rw = _Wetness * (0.45 + 0.55 * n.y);
            o.Albedo = c.rgb * _Color.rgb * lerp(1, 0.62, rw);
            o.Metallic = _Metallic;
            o.Smoothness = lerp(_Glossiness * (1.0 + wet * 0.6), 0.78, rw);
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
