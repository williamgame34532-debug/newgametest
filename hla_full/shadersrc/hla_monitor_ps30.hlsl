// Half-Life: Alyx «vr_monitor» display effect, ported to Shader Model 3 for Garry's Mod
// (screenspace_general, $pixshader "hla_monitor_ps30"). The math follows the decompiled pixel
// shader of HL:A (tools/hla_convert/vcs_decompile.py, vr_monitor_pc_50_ps):
//   per-channel horizontal jitter (chromatic split) + occasional vsync jump, scanlines,
//   tint, vignette, film grain with flickering contrast.
// HL:A samples 7 textures; screenspace_general has 4, so vignette, vsync and contrast are formulas.
//
// s0 $basetexture  the screen image (render target with the UI)
// s1 $texture1     scanlines           (HL:A g_tScanlines, .g)
// s2 $texture2     film grain noise    (HL:A g_tFilmGrain, .g)
// s3 $texture3     jitter noise        (HL:A g_tHorizontalJitter, .g, sampled at u = .125/.375/.625)
// c0 = time, jitter speed, vsync jump scale, film grain strength
// c1 = red shift, green shift, blue shift, scanline tiling (lines across the height / texture size)
// c2 = tint r, g, b, vignette strength
// c3 = scanline scroll speed, vsync roll (already scaled, per frame), contrast (per frame), unused
// (per-frame values come from Lua: the same for every pixel, and cheaper there)


sampler BaseTexture  : register(s0);
sampler ScanlineTex  : register(s1);
sampler GrainTex     : register(s2);
sampler JitterTex    : register(s3);

uniform float4 C0 : register(c0);
uniform float4 C1 : register(c1);
uniform float4 C2 : register(c2);
uniform float4 C3 : register(c3);

struct PS_INPUT
{
	float2 uv : TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR
{
	float t = C0.x;
	float2 uv = i.uv;

	// jitter: three samples of the jitter row give one offset per colour channel (HL:A: -1/0/+1 bias)
	float jy = uv.y * 2.0 + t * C0.y;
	float3 jit;
	jit.x = tex2D(JitterTex, float2(jy, 0.125)).g - 1.0;
	jit.y = tex2D(JitterTex, float2(jy, 0.375)).g;
	jit.z = tex2D(JitterTex, float2(jy, 0.625)).g + 1.0;

	// vsync jump (HL:A: g_tVSyncControl at y*0.02 + time*0.25, centred on 0.5): a rare short roll
	float vs = C3.y;

	float3 shift = jit * C1.xyz * 0.01 + vs;
	float k = 1.0 + vs;
	float3 col;
	col.r = tex2D(BaseTexture, uv + float2(shift.r * k, vs)).r;
	col.g = tex2D(BaseTexture, uv + float2(shift.g * k, vs)).g;
	col.b = tex2D(BaseTexture, uv + float2(shift.b * k, vs)).b;

	// scanlines and tint
	float scan = tex2D(ScanlineTex, float2(uv.x, uv.y * C1.w + t * C3.x)).g;
	col *= scan * C2.rgb;

	// vignette (HL:A g_tVignette): darker towards the edges
	float2 d = uv * 2.0 - 1.0;
	float vig = saturate(1.0 - dot(d * float2(0.55, 0.75), d * float2(0.55, 0.75)) * C2.w);
	col *= vig;

	// film grain with flickering contrast (HL:A: grain*strength*contrast + 0.5, multiplied in)
	float contrast = C3.z;
	float grain = tex2D(GrainTex, uv + t * float2(19.2, 7.1)).g - 0.5;
	col *= grain * C0.w * contrast * 2.0 + 1.0;

	return float4(col, 1.0);
}
