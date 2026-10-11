// Трава: пучки из скрещённых карточек. Обычный вершинно-фрагментный шейдер (без surface-магии):
// ветер в вершинах, отсечение по альфе, освещение солнцем + окружение, туман, растворение вдали.
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
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            sampler2D _MainTex; float4 _MainTex_ST;
            float _Cutoff, _Wind, _Fade;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; fixed4 color : COLOR; };
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 col : COLOR;
                float fade : TEXCOORD1;
                SHADOW_COORDS(2)
                UNITY_FOG_COORDS(3)
            };
            v2f vert (appdata v)
            {
                v2f o;
                float4 wp = mul(unity_ObjectToWorld, v.vertex);
                float h = v.uv.y;
                float t = _Time.y * _Wind;
                float sway = sin(t * 1.6 + wp.x * 0.31 + wp.z * 0.23) * 0.6 + sin(t * 3.3 + wp.x * 1.3 + wp.z * 0.7) * 0.25;
                wp.xz += float2(sway, sway * 0.55) * 0.13 * h * h;
                o.pos = mul(UNITY_MATRIX_VP, wp);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                float d = distance(wp.xyz, _WorldSpaceCameraPos);
                o.fade = saturate((_Fade - d) / (_Fade * 0.3));
                // освещение как у земли (нормаль вверх) + чуть темнее у корня
                float ndl = saturate(dot(float3(0, 1, 0), normalize(_WorldSpaceLightPos0.xyz)));
                float3 light = _LightColor0.rgb * ndl * 0.85 + ShadeSH9(float4(0, 1, 0, 1));
                o.col = fixed4(v.color.rgb * light * lerp(0.65, 1.0, h), 1);
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv);
                clip(c.a * i.fade - _Cutoff);
                fixed4 col = fixed4(c.rgb * i.col.rgb * lerp(0.7, 1.0, SHADOW_ATTENUATION(i)), 1);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    FallBack Off
}
