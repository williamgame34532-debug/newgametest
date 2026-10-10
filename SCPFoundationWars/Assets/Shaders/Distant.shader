// Далёкие горы: простое освещение по цвету вершин и ручная дымка (без тумана сцены, иначе их бы не было видно)
Shader "SCP/Distant"
{
    Properties
    {
        _Haze ("Haze", Color) = (0.7,0.75,0.8,1)
        _HazeAmt ("Haze Amount", Range(0,1)) = 0.5
        _SunDir ("Sun Dir", Vector) = (0.3,0.6,0.3,0)
        _SunColor ("Sun Color", Color) = (1,1,1,1)
        _Ambient ("Ambient", Color) = (0.5,0.55,0.6,1)
    }
    SubShader
    {
        Tags { "Queue"="Geometry+10" "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            fixed4 _Haze, _SunColor, _Ambient; float _HazeAmt; float4 _SunDir;
            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; fixed4 color : COLOR; };
            struct v2f { float4 pos : SV_POSITION; fixed4 col : COLOR; float h : TEXCOORD0; };
            v2f vert (appdata v)
            {
                v2f o; o.pos = UnityObjectToClipPos(v.vertex);
                float3 n = UnityObjectToWorldNormal(v.normal);
                float l = saturate(dot(n, normalize(_SunDir.xyz)));
                o.col = v.color * (_Ambient + _SunColor * l * 0.8);
                o.h = mul(unity_ObjectToWorld, v.vertex).y;
                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                float lowHaze = saturate(1 - i.h / 140) * 0.35;
                return fixed4(lerp(i.col.rgb, _Haze.rgb, saturate(_HazeAmt + lowHaze)), 1);
            }
            ENDCG
        }
    }
}
