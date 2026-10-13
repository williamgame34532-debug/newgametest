// Эффекты мира (камера сцены, до оружия): затенение окружения по глубине (SSAO) и солнечные лучи.
// 0 — SSAO (половинное разрешение), 1 — размытие AO с учётом глубины, 2 — маска неба для лучей,
// 3 — радиальное размытие лучей к солнцу, 4 — сведение: кадр * AO + лучи.
// Проходы 0 и 2 рисуются из пустой текстуры: координаты = координаты экрана (как у глубины).
Shader "SCP/WorldFX"
{
    Properties { _MainTex ("Tex", 2D) = "white" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _AO, _Shafts, _Dof;
    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    float4 _MainTex_TexelSize;
    float4 _TanHalf;      // x,y — тангенсы половины угла обзора
    float4 _Params;       // x — радиус (м), y — сила AO, z — дальность затухания AO (м), w — смещение
    float4 _Dir;          // направление размытия (в текселях)
    float4 _SunPos;       // xy — солнце на экране (uv), z — видимость солнца 0..1
    float4 _SunCol;       // цвет и сила лучей
    float _ShaftLen;
    // атмосфера: x — плотность у земли, y — 1/высота спада, z — высота земли, w — предел
    float4 _Fog, _FogCol, _SunDirW, _SunScat;
    float4 _CamPos, _RayR, _RayU, _RayF;   // луч взгляда = F + R*ndc.x + U*ndc.y (уже с тангенсами)
    float4x4 _PrevVP;
    float4 _Motion;                        // x — сила размытия движения, y — предел длины (uv)
    float4 _DofP;
    float4 _LampP[4], _LampC[4];
    float4 _Clouds;                        // x — покрытие, y — сила тени, z — время, w — высота облаков
    float CHash (float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
    float VNoise (float2 p)
    {
        float2 i = floor(p), f = frac(p);
        float2 u = f * f * (3 - 2 * f);
        float a = CHash(i), b = CHash(i + float2(1, 0)), c = CHash(i + float2(0, 1)), d = CHash(i + float2(1, 1));
        return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
    }
    // тень облаков: точка проецируется вдоль солнечного луча на слой облаков
    float CloudShadow (float3 wp)
    {
        float t = (_Clouds.w - wp.y) / max(_SunDirW.y, 0.15);
        float2 q = (wp.xz + _SunDirW.xz * t) * 0.0021 + float2(_Clouds.z * 0.006, _Clouds.z * 0.0025);
        float n = VNoise(q) * 0.55 + VNoise(q * 2.3 + 7.1) * 0.3 + VNoise(q * 5.1 + 3.7) * 0.15;
        float cov = smoothstep(1 - _Clouds.x, 1 - _Clouds.x + 0.22, n);
        return 1 - cov * _Clouds.y;
    }           // ближайшие лампы: позиция + радиус, цвет * сила
    // свечение воздуха вокруг лампы вдоль луча (аналитический интеграл 1/r² по отрезку)
    float3 LampGlow (float3 dir, float len)
    {
        float3 acc = 0;
        [unroll]
        for (int k = 0; k < 4; k++)
        {
            float3 lp = _LampP[k].xyz - _CamPos.xyz;
            float tc = dot(lp, dir);
            float h = max(length(lp - dir * tc), 0.25);
            float a0 = atan((0 - tc) / h), a1 = atan((len - tc) / h);
            float fall = saturate(1 - (h - 0.25) / max(_LampP[k].w, 0.01));
            acc += _LampC[k].rgb * (a1 - a0) / h * fall * fall;
        }
        return acc;
    }                          // x — дистанция фокуса, y — сила, z — радиус (текселей), w — ближняя граница
    float2 ScreenUV (float2 uv)
    {
        #if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0) uv.y = 1 - uv.y;
        #endif
        return uv;
    }
    float3 WorldRay (float2 suv) { float2 ndc = suv * 2 - 1; return _RayF.xyz + _RayR.xyz * ndc.x + _RayU.xyz * ndc.y; }
    // экспоненциальный по высоте туман: интеграл плотности вдоль луча
    float FogAmount (float3 ray, float dist)
    {
        float3 dir = ray / max(length(ray), 1e-4);
        float k = _Fog.y;
        float start = _Fog.x * exp(-k * (_CamPos.y - _Fog.z));
        float t = k * dir.y * dist;
        float integ = abs(t) > 1e-4 ? (1 - exp(-t)) / t : 1;
        return start * dist * integ;
    }
    float3 Atmosphere (float3 c, float3 ray, float dist)
    {
        float amt = FogAmount(ray, dist);
        float ext = exp(-amt);
        ext = max(ext, 1 - _Fog.w);
        float3 dir = normalize(ray);
        float cosT = dot(dir, _SunDirW.xyz);
        float g = 0.76;
        float mie = (1 - g * g) / pow(max(1 + g * g - 2 * g * cosT, 1e-3), 1.5);
        float3 ins = _FogCol.rgb + _SunScat.rgb * mie * 0.035;
        return c * ext + ins * (1 - ext);
    }
    float CoC (float d)
    {
        // фокус на точке прицеливания: всё заметно дальше — размыто (как глаз при взгляде в прицел)
        float far = saturate((d - _DofP.x * 1.25) / max(_DofP.x * 1.5, 2));
        float nearB = saturate((_DofP.w - d) / max(_DofP.w, 0.01));
        return saturate(max(far, nearB * 0.6)) * _DofP.y;
    }

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

    // размытие по глубине для прицеливания (половинное разрешение, сбор с диска)
    fixed4 fragDof (v2f_img i) : SV_Target
    {
        float2 suv = ScreenUV(i.uv);
        float c0 = CoC(EyeDepth(suv));
        float2 px = _MainTex_TexelSize.xy * _DofP.z;
        float3 acc = tex2D(_MainTex, i.uv).rgb; float w = 1;
        [unroll]
        for (int k = 0; k < 20; k++)
        {
            float a = k * 2.39996;
            float r = sqrt((k + 0.5) / 20);
            float2 o = float2(cos(a), sin(a)) * r;
            float2 tuv = i.uv + o * px * c0;
            float cs = CoC(EyeDepth(ScreenUV(tuv)));
            float wt = saturate(cs * 1.5 + 0.1);
            float3 sc = tex2Dlod(_MainTex, float4(tuv, 0, 0)).rgb;
            sc = (sc == sc) ? min(sc, 32) : 0;
            acc += sc * wt; w += wt;
        }
        return fixed4(acc / w, c0);
    }

    fixed4 fragComposite (v2f_img i) : SV_Target
    {
        float2 uv = ScreenUV(i.uv);
        float raw = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0, 0));
        float eye = LinearEyeDepth(raw);
        bool isSky = Linear01Depth(raw) > 0.9995;
        float3 ray = WorldRay(uv);
        float3 c = tex2D(_MainTex, i.uv).rgb;
        c = (c == c) ? c : 0;
        // размытие движения камеры: где эта точка была в прошлом кадре
        if (_Motion.x > 0.001)
        {
            float3 wp = _CamPos.xyz + ray * (isSky ? 2000 : eye);
            float4 pc = mul(_PrevVP, float4(wp, 1));
            float2 puv = pc.xy / max(pc.w, 1e-4) * 0.5 + 0.5;
            float2 vel = (uv - puv) * _Motion.x;
            float vl = length(vel);
            vel *= min(1, _Motion.y / max(vl, 1e-5));
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0) vel.y = -vel.y;
            #endif
            if (pc.w > 0 && vl > 0.0008)
            {
                float3 mb = c;
                [unroll]
                for (int k = 1; k <= 6; k++)
                {
                    float3 sc = tex2Dlod(_MainTex, float4(i.uv - vel * (k / 6.0 - 0.5), 0, 0)).rgb;
                    mb += (sc == sc) ? min(sc, 32) : 0;
                }
                c = mb / 7;
            }
        }
        // глубина резкости при прицеливании
        if (_DofP.y > 0.001)
        {
            float4 b = tex2D(_Dof, i.uv);
            float cc = CoC(eye);
            c = lerp(c, b.rgb, smoothstep(0.02, 0.6, cc));
        }
        float ao = tex2D(_AO, uv).r;
        float ak = _Params.y;
        c *= lerp(1, ao, ak);
        // бегущие тени облаков по земле и постройкам
        if (!isSky && _Clouds.y > 0) c *= CloudShadow(_CamPos.xyz + ray * eye);
        // воздушная перспектива: дальнее голубеет и тонет в дымке, против солнца дымка светится
        if (!isSky && _Fog.x > 0) c = Atmosphere(c, ray, eye * length(ray));
        c += tex2D(_Shafts, uv).rgb * _SunCol.rgb * _SunPos.z;
        // объёмный свет ламп в пыльном воздухе
        if (_LampC[0].a > 0) c += LampGlow(normalize(ray), min(isSky ? 60 : eye * length(ray), 60));
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
               #pragma target 3.0
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragDof
               #pragma target 3.0
               ENDCG }
    }
    FallBack Off
}
