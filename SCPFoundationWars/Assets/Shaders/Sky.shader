// Небо: градиент, дымка у горизонта, солнце с ореолом, движущиеся объёмные облака (фрактальный шум),
// ночью — звёзды и луна. Параметры задаёт MapGen под время суток.
Shader "SCP/Sky"
{
    Properties
    {
        _Zenith ("Zenith", Color) = (0.25,0.45,0.8,1)
        _Horizon ("Horizon", Color) = (0.7,0.8,0.9,1)
        _Ground ("Ground", Color) = (0.35,0.33,0.3,1)
        _Haze ("Haze", Color) = (0.8,0.82,0.85,1)
        _SunDir ("Sun Dir", Vector) = (0.3,0.6,0.3,0)
        _SunColor ("Sun Color", Color) = (1,0.95,0.85,1)
        _SunSize ("Sun Size", Float) = 1
        _CloudColor ("Cloud Lit", Color) = (1,1,1,1)
        _CloudShadow ("Cloud Shadow", Color) = (0.55,0.6,0.68,1)
        _CloudCover ("Cloud Cover", Range(0,1)) = 0.45
        _CloudSpeed ("Cloud Speed", Float) = 0.004
        _Stars ("Stars", Range(0,1)) = 0
        _MoonDir ("Moon Dir", Vector) = (-0.4,0.5,0.6,0)
        _MoonColor ("Moon Color", Color) = (0.9,0.92,1,1)
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
            fixed4 _Zenith, _Horizon, _Ground, _Haze, _SunColor, _CloudColor, _CloudShadow, _MoonColor;
            float4 _SunDir, _MoonDir;
            float _SunSize, _CloudCover, _CloudSpeed, _Stars;
            struct v2f { float4 pos : SV_POSITION; float3 dir : TEXCOORD0; };
            v2f vert (appdata_base v) { v2f o; o.pos = UnityObjectToClipPos(v.vertex); o.dir = v.vertex.xyz; return o; }

            float hash2(float2 p) { p = frac(p * float2(123.34, 456.21)); p += dot(p, p + 45.32); return frac(p.x * p.y); }
            float hash3(float3 p) { p = frac(p * 0.3183099 + 0.1); p *= 17.0; return frac(p.x * p.y * p.z * (p.x + p.y + p.z)); }
            float noise(float2 p)
            {
                float2 i = floor(p), f = frac(p);
                float2 u = f * f * (3 - 2 * f);
                return lerp(lerp(hash2(i), hash2(i + float2(1,0)), u.x), lerp(hash2(i + float2(0,1)), hash2(i + float2(1,1)), u.x), u.y);
            }
            float fbm(float2 p)
            {
                float v = 0, a = 0.5;
                for (int k = 0; k < 5; k++) { v += a * noise(p); p = p * 2.03 + float2(17.1, 9.2); a *= 0.5; }
                return v;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 d = normalize(i.dir);
                float h = d.y;
                float3 sd = normalize(_SunDir.xyz);
                float sdot = dot(d, sd);
                // градиент
                float3 sky = lerp(_Horizon.rgb, _Zenith.rgb, pow(saturate(h), 0.5));
                sky = lerp(sky, _Ground.rgb, saturate(-h * 5));
                // подсветка у горизонта со стороны солнца
                float sunSide = saturate(sdot * 0.5 + 0.5);
                sky += _SunColor.rgb * pow(sunSide, 6) * exp(-abs(h) * 6) * 0.35;
                // дымка
                sky = lerp(sky, _Haze.rgb, exp(-abs(h) * 14) * 0.65);
                // солнце
                float disk = smoothstep(0.9996 - _SunSize * 0.0004, 0.9999 - _SunSize * 0.0002, sdot);
                float glow = pow(saturate(sdot), 12) * 0.35 + pow(saturate(sdot), 200) * 1.2;
                sky += _SunColor.rgb * (glow + disk * 18) * step(-0.02, h);
                // звёзды
                if (_Stars > 0.001 && h > 0)
                {
                    float3 p = d * 260;
                    float3 c = floor(p);
                    float r = hash3(c);
                    float st = step(0.9965, r) * saturate(1 - length(frac(p) - 0.5) * 3) * (0.6 + 0.4 * sin(_Time.y * (2 + r * 6) + r * 50));
                    sky += st * _Stars * saturate(h * 4) * 1.6;
                    // Млечный путь
                    float band = exp(-pow(dot(d, normalize(float3(0.3, 0.2, 0.9))) * 3.5, 2)) * fbm(d.xz * 6 + 3) * 0.12;
                    sky += band * _Stars * float3(0.7, 0.75, 1);
                    // луна
                    float3 md = normalize(_MoonDir.xyz);
                    float mdot = dot(d, md);
                    float moon = smoothstep(0.9993, 0.9995, mdot);
                    float crater = fbm(d.xy * 400) * 0.35;
                    sky = lerp(sky, _MoonColor.rgb * (0.85 - crater), moon * _Stars);
                    sky += _MoonColor.rgb * pow(saturate(mdot), 300) * 0.4 * _Stars + _MoonColor.rgb * pow(saturate(mdot), 20) * 0.06 * _Stars;
                }
                // облака: два слоя, освещены солнцем, тень снизу, редеют к горизонту
                if (h > 0)
                {
                    float2 uv = d.xz / (h + 0.12) * 0.55;
                    float t = _Time.y * _CloudSpeed;
                    float n = fbm(uv * 1.6 + float2(t * 40, t * 18));
                    float n2 = fbm(uv * 4.5 + float2(t * 70, -t * 30)) * 0.35;
                    float dens = saturate((n + n2 - (1 - _CloudCover)) * 2.6);
                    float shade = fbm(uv * 1.6 + float2(t * 40, t * 18) + sd.xz * 0.12);
                    float lit = saturate(1 - (shade - n) * 4);
                    float3 cc = lerp(_CloudShadow.rgb, _CloudColor.rgb, lit);
                    cc += _SunColor.rgb * pow(saturate(sdot), 8) * 0.5 * (1 - dens * 0.5);
                    float fade = saturate(h * 7);
                    sky = lerp(sky, cc, dens * fade * 0.97);
                    // высокие перистые облака
                    float ci = fbm(float2(uv.x * 0.6 + t * 15, uv.y * 3)) ;
                    sky = lerp(sky, _CloudColor.rgb, saturate((ci - 0.6) * 2) * 0.35 * fade);
                }
                return fixed4(sky, 1);
            }
            ENDCG
        }
    }
    Fallback Off
}
