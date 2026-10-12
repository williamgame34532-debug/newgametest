// Трава: пучки из скрещённых карточек. Поверхностный шейдер — свет, тени и окружение считает сам Unity
// (нормаль травы смотрит вверх, как у земли — пучок освещён так же, как почва под ним), ветер в вершинах,
// отсечение по альфе, растворение вдали, просвечивание против солнца.
Shader "SCP/Grass"
{
    Properties
    {
        _MainTex ("Blades", 2D) = "white" {}
        _Cutoff ("Cutoff", Range(0,1)) = 0.45
        _Wind ("Wind", Float) = 1
        _Fade ("Fade distance", Float) = 75
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" "IgnoreProjector"="True" }
        Cull Off
        CGPROGRAM
        #pragma surface surf Grass vertex:vert alphatest:_Cutoff
        #pragma target 3.0
        sampler2D _MainTex;
        float _Wind, _Fade;
        struct Input { float2 uv_MainTex; float4 color : COLOR; float fade; };
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float4 wp = mul(unity_ObjectToWorld, v.vertex);
            float h = v.texcoord.y;
            float t = _Time.y * _Wind;
            float sway = sin(t * 1.6 + wp.x * 0.31 + wp.z * 0.23) * 0.6 + sin(t * 3.3 + wp.x * 1.3 + wp.z * 0.7) * 0.25;
            float3 off = float3(sway, 0, sway * 0.55) * 0.13 * h * h;
            v.vertex.xyz += mul((float3x3)unity_WorldToObject, off);
            v.normal = mul((float3x3)unity_WorldToObject, float3(0, 1, 0));
            float d = distance(wp.xyz, _WorldSpaceCameraPos);
            o.fade = saturate((_Fade - d) / (_Fade * 0.3));
            o.color = v.color * lerp(0.65, 1.0, h);
            o.color.a = h;
        }
        half4 LightingGrass (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
        {
            half ndl = saturate(dot(half3(0, 1, 0), lightDir)) * 0.8 + 0.2;
            half back = pow(saturate(dot(viewDir, -lightDir)), 4) * 0.7 * s.Gloss;
            return half4(s.Albedo * _LightColor0.rgb * (ndl + back * half3(1.0, 1.15, 0.55)) * atten, s.Alpha);
        }
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = c.rgb * IN.color.rgb;
            o.Gloss = IN.color.a;
            o.Alpha = c.a * IN.fade;
        }
        ENDCG
    }
    FallBack Off
}
