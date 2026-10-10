// Трава: пучки из скрещённых карточек, колышется на ветру, плавно исчезает вдали
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
        #pragma surface surf Lambert vertex:vert alphatest:_Cutoff
        #pragma target 3.0
        sampler2D _MainTex;
        float _Wind, _Fade;
        struct Input { float2 uv_MainTex; float4 vcol; float fade; };
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float4 wp = mul(unity_ObjectToWorld, v.vertex);
            float h = v.texcoord.y;
            float t = _Time.y * _Wind;
            float sway = sin(t * 1.6 + wp.x * 0.31 + wp.z * 0.23) * 0.6 + sin(t * 3.3 + wp.x * 1.3 + wp.z * 0.7) * 0.25;
            wp.xz += float2(sway, sway * 0.55) * 0.13 * h * h;
            v.vertex = mul(unity_WorldToObject, wp);
            v.normal = mul((float3x3)unity_WorldToObject, float3(0, 1, 0));
            float d = distance(wp.xyz, _WorldSpaceCameraPos);
            o.fade = saturate((_Fade - d) / (_Fade * 0.3));
            o.vcol = v.color;
        }
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = c.rgb * IN.vcol.rgb;
            o.Alpha = c.a * IN.fade;
        }
        ENDCG
    }
    FallBack Off
}
