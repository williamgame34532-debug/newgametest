// Постобработка: яркие места -> размытие (свечение), ACES-тонмаппинг, цветокоррекция, виньетка, зерно,
// лёгкая хроматическая аберрация, эффекты ранения (обесцвечивание и красные края)
Shader "SCP/Post"
{
    Properties { _MainTex ("Tex", 2D) = "white" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _Bloom, _Lum, _LumPrev, _VisorTex;
    float _Visor, _VisorFog, _VisorRain;
    float4 _SunScreen, _FlareTint;      // солнце на экране (uv) и его видимость; цвет блика
    float4 _MainTex_TexelSize;
    float _Threshold, _BloomAmt, _Exposure, _Contrast, _Saturation, _Vignette, _Grain, _Hurt, _Aberr, _Time2, _Sharp;
    float _Fisheye, _Body, _AdaptK, _AutoExp;
    float4 _Tint, _Dir, _ShadowTone, _HighTone;
    // NaN/бесконечность из любого шейдера сцены не должны расползаться свечением в чёрные квадраты
    float3 Safe (float3 c) { c = (c == c) ? c : 0; return clamp(c, 0, 64); }
    fixed4 fragBright (v2f_img i) : SV_Target
    {
        float2 o = _MainTex_TexelSize.xy;
        float3 c = (tex2D(_MainTex, i.uv + o * float2(-1,-1)).rgb + tex2D(_MainTex, i.uv + o * float2(1,-1)).rgb + tex2D(_MainTex, i.uv + o * float2(-1,1)).rgb + tex2D(_MainTex, i.uv + o * float2(1,1)).rgb) * 0.25;
        c = Safe(c);
        float br = max(c.r, max(c.g, c.b));
        float k = saturate((br - _Threshold) / max(br, 0.0001));
        return fixed4(c * k, 1);
    }
    fixed4 fragBlur (v2f_img i) : SV_Target
    {
        float2 d = _MainTex_TexelSize.xy * _Dir.xy;
        float3 c = tex2D(_MainTex, i.uv).rgb * 0.227;
        c += (tex2D(_MainTex, i.uv + d * 1.384).rgb + tex2D(_MainTex, i.uv - d * 1.384).rgb) * 0.316;
        c += (tex2D(_MainTex, i.uv + d * 3.231).rgb + tex2D(_MainTex, i.uv - d * 3.231).rgb) * 0.070;
        return fixed4(c, 1);
    }
    // яркость кадра для автоэкспозиции: плавно догоняет текущую (как у нательной камеры)
    fixed4 fragAdapt (v2f_img i) : SV_Target
    {
        float3 c = Safe(tex2D(_MainTex, float2(0.5, 0.5)).rgb);
        float cur = max(0.02, dot(c, float3(0.2126, 0.7152, 0.0722)));
        float prev = tex2D(_LumPrev, float2(0.5, 0.5)).r;
        prev = (prev == prev && prev > 0.0001) ? prev : cur;
        return fixed4(lerp(prev, cur, _AdaptK).xxx, 1);
    }
    float3 ACES (float3 x) { return saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)); }
    float Hash (float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
    fixed4 fragFinal (v2f_img i) : SV_Target
    {
        // широкоугольная «бочка» нательной камеры: края кадра выгнуты
        float2 c0 = i.uv - 0.5;
        float rr = dot(c0, c0);
        float2 uv = 0.5 + c0 * (1 + _Fisheye * rr) / (1 + _Fisheye * 0.5);
        float2 cc = uv - 0.5;
        float r2 = dot(cc, cc);
        // хроматическая аберрация к краям (и сильнее при ранении)
        float ab = (_Aberr + _Hurt * 0.004) * r2 * 4;
        float3 col;
        col.r = tex2D(_MainTex, uv - cc * ab).r;
        col.g = tex2D(_MainTex, uv).g;
        col.b = tex2D(_MainTex, uv + cc * ab).b;
        // резкость: усиливаем детали относительно соседей (как в современных шутерах)
        float2 px = _MainTex_TexelSize.xy;
        float3 nb = (tex2D(_MainTex, uv + float2(px.x, 0)).rgb + tex2D(_MainTex, uv - float2(px.x, 0)).rgb
                   + tex2D(_MainTex, uv + float2(0, px.y)).rgb + tex2D(_MainTex, uv - float2(0, px.y)).rgb) * 0.25;
        col = Safe(col); nb = Safe(nb);
        float3 detail = col - nb;
        col = max(0, col + clamp(detail, -0.15, 0.15) * _Sharp);
        col += Safe(tex2D(_Bloom, uv).rgb) * _BloomAmt;
        // ---- блик солнца в оптике: ореол, «призраки» линз по линии через центр, кольцо ----
        if (_SunScreen.z > 0.001)
        {
            float asp = _MainTex_TexelSize.z / _MainTex_TexelSize.w;
            float2 sp = _SunScreen.xy;
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0) sp.y = 1 - sp.y;
            #endif
            float2 dir = 0.5 - sp;
            float r0 = length((uv - sp) * float2(asp, 1));
            float3 fl = _FlareTint.rgb * (0.0025 / (r0 * r0 + 0.0025)) * 0.35;
            [unroll] for (int k = 0; k < 4; k++)
            {
                float2 gp = sp + dir * (0.55 + k * 0.42);
                float rr = length((uv - gp) * float2(asp, 1));
                float sz = 0.025 + 0.022 * k;
                float3 tint = k == 0 ? float3(0.4, 0.7, 1.0) : k == 1 ? float3(1.0, 0.75, 0.4) : k == 2 ? float3(0.5, 1.0, 0.6) : float3(0.9, 0.5, 1.0);
                fl += tint * smoothstep(sz, sz * 0.55, rr) * (0.035 - k * 0.006);
            }
            float rh = length((uv - (sp + dir * 2.0)) * float2(asp, 1));
            fl += float3(0.6, 0.8, 1.0) * smoothstep(0.02, 0.0, abs(rh - 0.28)) * 0.025;
            col += fl * _SunScreen.z;
        }
        // ---- стекло маски шлема: запотевание от дыхания, капли, царапины и разводы, светящиеся в ярком свете ----
        if (_Visor > 0.001)
        {
            float4 vd = tex2D(_VisorTex, i.uv);
            // капли дождя преломляют картинку
            float drop = vd.b * _VisorRain;
            if (drop > 0.02)
            {
                float2 g = float2(ddx(vd.b), ddy(vd.b)) * 6;
                float3 dc = Safe(tex2D(_MainTex, uv - g * 0.04 + float2(0, 0.01)).rgb);
                col = lerp(col, dc * 1.08 + 0.01, saturate(drop * 1.6));
            }
            // запотевание: мутный размытый слой, гуще внизу и по краям
            float fogK = saturate((vd.g * 1.3 + saturate(0.55 - i.uv.y) * 0.9 + r2 * 0.8) * _VisorFog);
            if (fogK > 0.01)
            {
                float3 bl = 0;
                [unroll] for (int k = 0; k < 8; k++)
                {
                    float a = k * 0.785398;
                    bl += Safe(tex2D(_MainTex, uv + float2(cos(a), sin(a)) * 0.016).rgb);
                }
                bl /= 8;
                col = lerp(col, bl * 0.85 + 0.035 + Safe(tex2D(_Bloom, uv).rgb) * 0.6, fogK * 0.75);
            }
            // грязь на стекле подсвечивается ярким светом (солнце, фонари, вспышки)
            float3 glare = Safe(tex2D(_Bloom, uv).rgb);
            col += (vd.r * 0.7 + vd.g * 0.35) * (glare * 1.8 + 0.015) * _Visor;
        }
        col *= _Exposure;
        // автоэкспозиция: в тёмном помещении картинку вытягивает (с шумом), при выходе на свет — пересвет
        float avg = max(0.02, tex2D(_Lum, float2(0.5, 0.5)).r);
        col *= lerp(1, clamp(0.28 / avg, 0.85, 2.4), _AutoExp);
        col = ACES(col);
        // цветокоррекция: контраст вокруг серого, насыщенность, оттенок
        float lum = dot(col, float3(0.2126, 0.7152, 0.0722));
        float sat = _Saturation * (1 - _Hurt * 0.6);
        col = lerp(lum.xxx, col, sat);
        col = (col - 0.5) * _Contrast + 0.5;
        col *= _Tint.rgb;
        // раздельное тонирование: тени холодно-зелёные, света тёплые (приглушённая «военная» палитра)
        float l2 = saturate(dot(saturate(col), float3(0.2126, 0.7152, 0.0722)));
        col *= lerp(_ShadowTone.rgb, _HighTone.rgb, smoothstep(0.1, 0.75, l2));
        // мягкое плечо в светах и приподнятый чёрный (плёночная кривая)
        col = col * (1 - 0.06) + 0.012;
        // край визора: тёмная резиновая рамка, у края стекло темнее
        if (_Visor > 0.001)
        {
            float2 vq = abs(c0) * 2 / float2(0.985, 0.945);
            float e = pow(vq.x, 7) + pow(vq.y, 7);
            float lens = smoothstep(1.0, 0.86, e);
            col *= lerp(1, lerp(0.55, 1, smoothstep(0.98, 0.45, e)), _Visor);
            col = lerp(col, float3(0.012, 0.013, 0.014) + Hash(i.uv * 400) * 0.01, (1 - lens) * _Visor);
        }
        // виньетка и красные края при ранении
        float v = smoothstep(0.8, 0.15, r2 * 2.2);
        col *= lerp(1, v, _Vignette);
        col = lerp(col, float3(0.35, 0.02, 0.02), saturate((r2 * 2.6 - 0.25)) * _Hurt);
        // зерно плёнки
        float n = Hash(uv * _MainTex_TexelSize.zw + _Time2 * 37.0) - 0.5;
        col += n * _Grain * (1.2 - lum);
        // цифровая матрица: цветной шум в тенях, лёгкие строки развёртки, пережатые света
        if (_Body > 0.001)
        {
            float3 cn = float3(Hash(uv * 711.3 + _Time2 * 13.1), Hash(uv * 517.9 + _Time2 * 7.7), Hash(uv * 331.7 + _Time2 * 5.3)) - 0.5;
            col += cn * 0.05 * _Body * saturate(1 - lum * 1.6);
            col *= 1 - 0.035 * _Body * step(0.5, frac(uv.y * _MainTex_TexelSize.w * 0.5));
            col = lerp(col, smoothstep(0.0, 1.04, col), 0.5 * _Body);
            col.b *= 1 + 0.04 * _Body;
        }
        return fixed4(saturate(col), 1);
    }
    ENDCG
    SubShader
    {
        ZTest Always Cull Off ZWrite Off
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragBright
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragBlur
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragFinal
               ENDCG }
        Pass { CGPROGRAM
               #pragma vertex vert_img
               #pragma fragment fragAdapt
               ENDCG }
    }
    FallBack Off
}
