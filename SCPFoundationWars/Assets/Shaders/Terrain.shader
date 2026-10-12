// Рельеф: четыре слоя (трава/песок, земля, камень, снег) смешиваются по цвету вершин; против повторяемости —
// второе чтение каждого слоя в другом масштабе и крупные пятна освещённости.
Shader "SCP/Terrain"
{
    Properties
    {
        _L0 ("Layer R (grass)", 2D) = "white" {}
        _L1 ("Layer G (dirt)", 2D) = "white" {}
        _L2 ("Layer B (rock)", 2D) = "white" {}
        _L3 ("Layer A (snow)", 2D) = "white" {}
        _N0 ("Normal R", 2D) = "bump" {}
        _N1 ("Normal G", 2D) = "bump" {}
        _N2 ("Normal B", 2D) = "bump" {}
        _N3 ("Normal A", 2D) = "bump" {}
        _NStr ("Normal strength", Float) = 1
        _Scale ("Tiling", Float) = 0.18
        _Gloss ("Layer gloss", Vector) = (0.05, 0.08, 0.15, 0.35)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 4.0
        sampler2D _L0, _L1, _L2, _L3, _N0, _N1, _N2, _N3;
        float _Scale, _NStr; float4 _Gloss;
        struct Input { float3 worldPos; float4 vcol; float3 wn; };
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.vcol = v.color;
            o.wn = UnityObjectToWorldNormal(v.normal);
        }
        // два масштаба одного слоя; вдали крупный берёт верх — повторяемость плиток не видна
        fixed3 Layer(sampler2D t, float2 uv, float far) { return lerp(tex2D(t, uv).rgb, tex2D(t, uv * 0.21 + 0.37).rgb, lerp(0.3, 0.7, far)); }
        float Lum(fixed3 c) { return dot(c, float3(0.3, 0.5, 0.2)); }
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.worldPos.xz * _Scale;
            float dist = distance(IN.worldPos, _WorldSpaceCameraPos);
            float far = saturate((dist - 20) / 90);
            float4 w = max(IN.vcol, 0.0001);
            float3 wn = normalize(IN.wn);
            // камень на крутых склонах — трипланарно: на обрывах текстура не растягивается
            float3 bw = pow(abs(wn), 6); bw /= (bw.x + bw.y + bw.z);
            float3 p = IN.worldPos * _Scale * 0.6;
            fixed3 rockTop = Layer(_L2, uv * 0.6, far);
            fixed3 rockSide = tex2D(_L2, p.zy).rgb * bw.x + tex2D(_L2, p.xy).rgb * bw.z;
            fixed3 c2 = rockSide + rockTop * bw.y;
            fixed3 c0 = Layer(_L0, uv, far), c1 = Layer(_L1, uv * 1.3, far), c3 = Layer(_L3, uv * 0.9, far);
            // смешивание по «высоте» детали: камни и комья проступают сквозь траву, а не мутно просвечивают
            float4 hw = w * float4(0.5 + Lum(c0), 0.5 + Lum(c1), 0.5 + Lum(c2) * 1.2, 0.5 + Lum(c3));
            hw = pow(hw, 5);
            hw /= dot(hw, float4(1,1,1,1));
            fixed3 c = c0 * hw.x + c1 * hw.y + c2 * hw.z + c3 * hw.w;
            // крупные пятна: выгоревшие и влажные участки, как на аэрофото
            float macro = tex2D(_L1, IN.worldPos.xz * 0.0031).r;
            float macro2 = tex2D(_L0, IN.worldPos.xz * 0.0011 + 0.5).g;
            c *= lerp(0.8, 1.12, saturate(macro * 1.6)) * lerp(0.9, 1.08, saturate(macro2 * 1.8));
            // затенение в складках склона
            c *= lerp(0.85, 1.0, saturate(wn.y * 1.4));
            o.Albedo = c;
            // рельеф поверхности по картам нормалей слоёв (касательные меша идут вдоль мировых X/Z, как и uv)
            float3 nrm = UnpackNormal(tex2D(_N0, uv)) * hw.x + UnpackNormal(tex2D(_N1, uv * 1.3)) * hw.y
                       + UnpackNormal(tex2D(_N2, uv * 0.6)) * hw.z * bw.y + float3(0, 0, 1) * hw.z * (1 - bw.y)
                       + UnpackNormal(tex2D(_N3, uv * 0.9)) * hw.w;
            nrm.xy *= _NStr * lerp(1.0, 0.5, far);
            o.Normal = normalize(nrm);
            o.Smoothness = dot(hw, _Gloss);
            o.Metallic = 0;
            o.Occlusion = lerp(0.7, 1.0, saturate(Lum(c) * 2.2));
        }
        ENDCG
    }
    FallBack "Diffuse"
}
