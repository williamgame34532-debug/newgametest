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
        #pragma target 3.0
        sampler2D _L0, _L1, _L2, _L3, _N0, _N1, _N2, _N3;
        float _Scale, _NStr; float4 _Gloss;
        struct Input { float3 worldPos; float4 vcol; };
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.vcol = v.color;
        }
        fixed3 Layer(sampler2D t, float2 uv) { return lerp(tex2D(t, uv).rgb, tex2D(t, uv * 0.21 + 0.37).rgb, 0.45); }
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.worldPos.xz * _Scale;
            float4 w = max(IN.vcol, 0.0001);
            // «высотное» смешивание: чем ярче деталь слоя, тем раньше она проступает
            fixed3 c0 = Layer(_L0, uv), c1 = Layer(_L1, uv * 1.3), c2 = Layer(_L2, uv * 0.6), c3 = Layer(_L3, uv * 0.9);
            float4 hw = w * float4(0.6 + dot(c0, float3(0.33,0.33,0.33)), 0.6 + dot(c1, float3(0.33,0.33,0.33)), 0.6 + dot(c2, float3(0.33,0.33,0.33)), 0.6 + dot(c3, float3(0.33,0.33,0.33)));
            hw = pow(hw, 3);
            hw /= dot(hw, float4(1,1,1,1));
            fixed3 c = c0 * hw.x + c1 * hw.y + c2 * hw.z + c3 * hw.w;
            float macro = tex2D(_L1, IN.worldPos.xz * 0.0031).r;
            c *= lerp(0.82, 1.12, saturate(macro * 1.6));
            o.Albedo = c;
            // рельеф поверхности по картам нормалей слоёв (касательные меша идут вдоль мировых X/Z, как и uv)
            float3 nrm = UnpackNormal(tex2D(_N0, uv)) * hw.x + UnpackNormal(tex2D(_N1, uv * 1.3)) * hw.y
                       + UnpackNormal(tex2D(_N2, uv * 0.6)) * hw.z + UnpackNormal(tex2D(_N3, uv * 0.9)) * hw.w;
            nrm.xy *= _NStr;
            o.Normal = normalize(nrm);
            o.Smoothness = dot(hw, _Gloss);
            o.Metallic = 0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
