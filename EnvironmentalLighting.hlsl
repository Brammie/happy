#include "RendererCommon.hlsli"

SamplerState g_ScreenSampler  : register(s0);
SamplerState g_TextureSampler : register(s1);

Texture2D<float4> g_AlbedoRoughnessBuffer    : register(t0);
Texture2D<float4> g_NormalMetallicBuffer     : register(t1);
Texture2D<float4> g_OcclusionBuffer          : register(t2);
Texture2D<float4> g_SpecularBuffer           : register(t3);
Texture2D<float>  g_DepthBuffer              : register(t4);

TextureCubeArray<float4> g_Lighting          : register(t5);
TextureCube<float4>      g_Environment       : register(t6);

float3 sampleEnv(float3 normal, float index)
{
	return g_Lighting.Sample(g_TextureSampler, float4(normal.x, normal.z, normal.y, index)).xyz;
}

float4 main(VSOut input) : SV_TARGET
{
	// Fetch material data from G-Buffer
	float4 albedoRoughness = g_AlbedoRoughnessBuffer.Sample(g_ScreenSampler, input.tex);
	float4 normalMetallic  = g_NormalMetallicBuffer.Sample(g_ScreenSampler, input.tex);
	float4 occlusion       = g_OcclusionBuffer.Sample(g_ScreenSampler, input.tex) * 2 - 1;
	float  depth           = g_DepthBuffer.Sample(g_ScreenSampler, input.tex);

	// Calculate view normal
	float3 screenNormal = float3(
		(input.tex.x - .5) * 2 * (width / height),
		(input.tex.y - .5) * -2,
		-currentProjection[0][0] * 2);
	float3 viewNormal = normalize(mul(screenNormal, (float3x3)currentView));

	// Apply PBR
	if (depth < 1)
	{
		float3 normal = normalMetallic.xyz * 2.0f - 1.0f;
		float rough = albedoRoughness.w;
		float metal = normalMetallic.w;
		float invRough = 1 - rough;
		float invMetal = 1 - metal;
		float reflectivity = metal +invMetal*invRough*pow(1.0f + dot(viewNormal, normal), 4)*0.1f;

		float3 diffuse = sampleEnv(normal, convolutionStages - 1) * albedoRoughness.xyz;
		float3 specular = sampleEnv(reflect(viewNormal, normal), (convolutionStages - 1) * rough) * albedoRoughness.xyz;

		float ambient = 1.0f;
		if (aoEnabled > 0) ambient = pow(1 - saturate(occlusion.w), 2);

		return float4(lerp(diffuse, specular, reflectivity) * ambient, 1.0f);
	}
	// Render the environment
	else
	{
		return g_Environment.Sample(g_TextureSampler, viewNormal.xzy);
	}
}