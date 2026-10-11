// Постобработка: яркие места -> размытие (свечение), ACES-тонмаппинг, цветокоррекция, виньетка, зерно,
// лёгкая хроматическая аберрация, эффекты ранения (обесцвечивание и красные края)
Shader "SCP/Post"
{
    Properties { _MainTex ("Tex", 2D) = "white" {} }
    CGINCLUDE
    #include "UnityCG.cginc"
    sampler2D _MainTex, _Bloom;
    float4 _MainTex_TexelSize;
    float _Threshold, _BloomAmt, _Exposure, _Contrast, _Saturation, _Vignette, _Grain, _Hurt, _Aberr, _Time2, _Sharp;
    float4 _Tint, _Dir, _ShadowTone, _HighTone;
    fixed4 fragBright (v2f_img i) : SV_Target
    {
        float2 o = _MainTex_TexelSize.xy;
        float3 c = (tex2D(_MainTex, i.uv + o * float2(-1,-1)).rgb + tex2D(_MainTex, i.uv + o * float2(1,-1)).rgb + tex2D(_MainTex, i.uv + o * float2(-1,1)).rgb + tex2D(_MainTex, i.uv + o * float2(1,1)).rgb) * 0.25;
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
    float3 ACES (float3 x) { return saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)); }
    float Hash (float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
    fixed4 fragFinal (v2f_img i) : SV_Target
    {
        float2 uv = i.uv;
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
        float3 detail = col - nb;
        col = max(0, col + clamp(detail, -0.15, 0.15) * _Sharp);
        col += tex2D(_Bloom, uv).rgb * _BloomAmt;
        col *= _Exposure;
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
    }
    FallBack Off
}
