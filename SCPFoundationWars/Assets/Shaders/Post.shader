// Постобработка: яркие места -> размытие (свечение), ACES-тонмаппинг, цветокоррекция, виньетка, зерно,
// лёгкая хроматическая аберрация, эффекты ранения (обесцвечивание и красные края)
Shader "SCP/Post"
{
    Properties { _MainTex ("Tex", 2D) = "white" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _Bloom, _Lum, _LumPrev;
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
