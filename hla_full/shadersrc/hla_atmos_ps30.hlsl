sampler FrameTex : register(s0);
sampler GrainTex : register(s1);

uniform float4 C0 : register(c0);
uniform float4 C1 : register(c1);
uniform float4 C2 : register(c2);

struct PS_INPUT
{
	float2 uv : TEXCOORD0;
};

float3 filmic(float3 x)
{
	float3 a = x * (2.51 * x + 0.03);
	float3 b = x * (2.43 * x + 0.59) + 0.14;
	return saturate(a / b);
}

float4 main(PS_INPUT i) : COLOR
{
	float2 uv = i.uv;
	float2 d = uv - 0.5;
	float r2 = dot(d, d);

	float2 ca = d * C0.w * r2;
	float3 col;
	col.r = tex2D(FrameTex, uv + ca).r;
	col.g = tex2D(FrameTex, uv).g;
	col.b = tex2D(FrameTex, uv - ca).b;

	float2 px = C2.xy;
	float3 blur = tex2D(FrameTex, uv + float2(px.x, 0)).rgb + tex2D(FrameTex, uv - float2(px.x, 0)).rgb
		+ tex2D(FrameTex, uv + float2(0, px.y)).rgb + tex2D(FrameTex, uv - float2(0, px.y)).rgb;
	col += (col - blur * 0.25) * C1.z;

	float3 toned = filmic(col * 1.08);
	col = lerp(col, toned, C1.x);

	float lum = dot(col, float3(0.2126, 0.7152, 0.0722));
	float3 shadowTint = float3(0.92, 0.98, 1.08);
	float3 lightTint = float3(1.04, 1.01, 0.95);
	float3 split = lerp(shadowTint, lightTint, smoothstep(0.15, 0.75, lum));
	col *= lerp(float3(1, 1, 1), split, C1.y);

	float vig = 1.0 - C0.z * smoothstep(0.12, 0.62, r2 * 1.6);
	col *= vig;

	float2 guv = uv * C2.zw + float2(frac(C0.x * 7.31), frac(C0.x * 3.17));
	float g = tex2D(GrainTex, guv).g - 0.5;
	col += g * C0.y * (1.0 - lum * 0.6);

	return float4(saturate(col), 1);
}
