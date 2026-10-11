// Эффекты мира (камера сцены, до оружия): затенение окружения по глубине (SSAO) и солнечные лучи.
// 0 — SSAO (половинное разрешение), 1 — размытие AO с учётом глубины, 2 — маска неба для лучей,
// 3 — радиальное размытие лучей к солнцу, 4 — сведение: кадр * AO + лучи.
// Проходы 0 и 2 рисуются из пустой текстуры: координаты = координаты экрана (как у глубины).
Shader "SCP/WorldFX"
{
    Properties { _MainTex ("Tex", 2D) = "white" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _AO, _Shafts;
    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    float4 _MainTex_TexelSize;
    float4 _TanHalf;      // x,y — тангенсы половины угла обзора
    float4 _Params;       // x — радиус (м), y — сила AO, z — дальность затухания AO (м), w — смещение
    float4 _Dir;          // направление размытия (в текселях)
    float4 _SunPos;       // xy — солнце на экране (uv), z — видимость солнца 0..1
    float4 _SunCol;       // цвет и сила лучей
    float _ShaftLen;

    float EyeDepth (float2 uv) { return LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0, 0))); }
    float3 ViewPos (float2 uv, float d) { float2 ndc = uv * 2 - 1; return float3(ndc.x * _TanHalf.x * d, ndc.y * _TanHalf.y * d, d); }
    float2 ToUV (float3 p) { return float2(p.x / (p.z * _TanHalf.x), p.y / (p.z * _TanHalf.y)) * 0.5 + 0.5; }
    float Hash (float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }

    fixed4 fragAO (v2f_img i) : SV_Target
    {
        float d = EyeDepth(i.uv);
        if (d > _Params.z * 1.5) return 1;
        float3 p = ViewPos(i.uv, d);
        float3 n = normalize(cross(ddx(p), ddy(p)));
        if (dot(n, p) > 0) n = -n;
        float ang = Hash(i.uv * _ScreenParams.xy) * 6.2831;
        float2 cs = float2(cos(ang), sin(ang));
        float R = _Params.x * saturate(0.35 + d * 0.04);
        float occ = 0;
        const int N = 12;
        [unroll]
        for (int k = 0; k < N; k++)
        {
            float fk = (k + 0.5) / N;
            float a = fk * 25.1327;                     // спираль по полусфере
            float z = 1 - fk;
            float r = sqrt(1 - z * z);
            float3 dir = float3(cos(a) * r, sin(a) * r, z);
            dir.xy = float2(dir.x * cs.x - dir.y * cs.y, dir.x * cs.y + dir.y * cs.x);
            if (dot(dir, n) < 0) dir = -dir;
            float len = lerp(0.2, 1.0, fk * fk);
            float3 sp = p + dir * R * len;
            float2 suv = ToUV(sp);
            float inside = (all(suv > 0) && all(suv < 1)) ? 1 : 0;
            float sd = EyeDepth(saturate(suv));
            float range = saturate(R / max(abs(d - sd), 0.001));
            occ += (sd < sp.z - _Params.w) ? range * inside : 0;
        }
        float ao = 1 - occ / N;
        ao = lerp(1, ao, saturate(1 - d / _Params.z));
        return ao;
    }

    fixed4 fragBlurAO (v2f_img i) : SV_Target
    {
        float2 o = _MainTex_TexelSize.xy * _Dir.xy;
        float d0 = EyeDepth(i.uv);
        float s = tex2Dlod(_MainTex, float4(i.uv, 0, 0)).r * 2, w = 2;
        [unroll]
        for (int k = 1; k <= 3; k++)
        {
            float2 u1 = i.uv + o * k, u2 = i.uv - o * k;
            float w1 = saturate(1 - abs(EyeDepth(u1) - d0) / (0.08 * d0 + 0.05));
            float w2 = saturate(1 - abs(EyeDepth(u2) - d0) / (0.08 * d0 + 0.05));
            s += tex2Dlod(_MainTex, float4(u1, 0, 0)).r * w1 + tex2Dlod(_MainTex, float4(u2, 0, 0)).r * w2;
            w += w1 + w2;
        }
        return s / w;
    }

    fixed4 fragSky (v2f_img i) : SV_Target
    {
        // маска неба по глубине (без кадра — чтобы не зависеть от переворота текстуры при сглаживании)
        float raw = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(i.uv, 0, 0));
        float sky = Linear01Depth(raw) > 0.995 ? 1 : 0;
        float2 dv = (i.uv - _SunPos.xy) * float2(_ScreenParams.x / _ScreenParams.y, 1);
        float near = saturate(1 - length(dv) * 1.4);
        return fixed4(sky * (0.08 + near * near * 1.6).xxx, 1);
    }

    fixed4 fragRadial (v2f_img i) : SV_Target
    {
        float2 delta = (_SunPos.xy - i.uv) * _ShaftLen / 16;
        float2 uv = i.uv;
        float3 s = 0;
        float decay = 1;
        [unroll]
        for (int k = 0; k < 16; k++)
        {
            s += tex2D(_MainTex, uv).rgb * decay;
            uv += delta;
            decay *= 0.93;
        }
        return fixed4(s / 9, 1);
    }

    fixed4 fragComposite (v2f_img i) : SV_Target
    {
        float3 c = tex2D(_MainTex, i.uv).rgb;
        c = (c == c) ? c : 0;
        float2 uv = i.uv;
        #if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0) uv.y = 1 - uv.y;
        #endif
        float ao = tex2D(_AO, uv).r;
        float ak = _Params.y;
        c *= lerp(1, ao, ak);
        c += tex2D(_Shafts, uv).rgb * _SunCol.rgb * _SunPos.z;
        return fixed4(c, 1);
    }
    ENDCG
    SubShader
    {
        ZTest Always Cull Off ZWrite Off
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragAO
               #pragma target 3.0
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragBlurAO
               #pragma target 3.0
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragSky
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragRadial
               #pragma target 3.0
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragComposite
               ENDCG }
    }
    FallBack Off
}
