// Листва и хвоя: карточки с прозрачностью по маске, двусторонние, качаются на ветру (сильнее к концам веток).
// Свет «насквозь»: против солнца листья и хвоя светятся (просвечивание), у ствола — темнее (самозатенение кроны).
Shader "SCP/Foliage"
{
    Properties
    {
        _MainTex ("Albedo (A = mask)", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _Cutoff ("Cutoff", Range(0,1)) = 0.4
        _Wind ("Wind", Float) = 0.12
        _Trans ("Translucency", Float) = 0.8
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" "IgnoreProjector"="True" }
        Cull Off
        CGPROGRAM
        #pragma surface surf Foliage vertex:vert alphatest:_Cutoff addshadow
        #pragma target 3.0
        sampler2D _MainTex;
        fixed4 _Color;
        float _Wind, _Trans;
        struct Input { float2 uv_MainTex; };
        void vert (inout appdata_full v)
        {
            float3 wp = mul(unity_ObjectToWorld, v.vertex).xyz;
            float k = v.texcoord.y * _Wind;
            float s = sin(_Time.y * 1.7 + wp.x * 0.11 + wp.z * 0.07) + 0.5 * sin(_Time.y * 3.1 + wp.y * 0.5);
            float3 off = float3(s, 0.3 * s, s * 0.6) * k;
            v.vertex.xyz += mul((float3x3)unity_WorldToObject, off);
        }
        half4 LightingFoliage (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
        {
            half ndl = abs(dot(s.Normal, lightDir));
            half wrap = ndl * 0.65 + 0.35;
            half back = pow(saturate(dot(viewDir, -lightDir)), 5) * _Trans;
            half3 c = s.Albedo * _LightColor0.rgb * (wrap + back * half3(1.1, 1.25, 0.6)) * atten;
            return half4(c, s.Alpha);
        }
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb * lerp(0.55, 1.0, saturate(IN.uv_MainTex.y * 1.5));
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Transparent/Cutout/VertexLit"
}
