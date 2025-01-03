﻿#ifndef __GRASS_PASS_HLSL__
#define __GRASS_PASS_HLSL__

#include "GrassInput.hlsl"

inline float4 GetGrassPosition(Attributes input, float3 normalWS)
{
    float3 positionOS = input.positionOS;
    float3 positionWS = TransformObjectToWorld(positionOS);
    float lerpY = input.texcoord.y;// * input.texcoord.y;
    float wave = Pow2(lerpY);

#if USING_WIND
    // 风动效果
    positionWS += SimpleGrassWind(positionWS, lerpY);
#elif USING_WIND_WAVE
    // 风浪效果
    float4 windWave = SimpleWindWave(positionWS, lerpY);
    positionWS += windWave.xyz;
    wave = windWave.w;
#endif

    // 与物体互动
#if USING_INTERACTIVE    
     // 获取周围角色信息
    float4 playerPosWS = GetTrailObject(positionWS);
    if (playerPosWS.w > 0)
    {
        float dist = distance(positionWS, playerPosWS.xyz);
    
        // 草的描点
        float3 pivotPointWS = TransformObjectToWorld(float3(input.texcoord2, input.texcoord3.x));
        //pivotPointWS.y = unity_ObjectToWorld._24;
        float pushDown = saturate((1 - dist / playerPosWS.w) * lerpY) * _GrassPushStrength;
        float3 direction = SafeNormalize(playerPosWS.xyz - pivotPointWS);
        float3 newPos = positionWS + (direction * pushDown);
	    float orgDist = distance(positionWS, pivotPointWS);
        positionWS = pivotPointWS + (SafeNormalize(newPos - pivotPointWS) * orgDist);
    }
#endif
    
    return float4(positionWS, wave);
}

///////////////////////////////////////////////////////////////////////////////
//                               Forward                                      /
///////////////////////////////////////////////////////////////////////////////
inline void InitializeSurfaceData(Varyings input, inout CustomSurfaceData surfaceData)
{
#if USING_ALPHA_CUTOFF
    half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord.xy);
    clip(albedoAlpha.a - _AlphaCutoff);
#else
    half4 albedoAlpha = (half4) 1;
#endif

    surfaceData.albedo = albedoAlpha.rgb * lerp(_BaseColor, _GrassTipColor, input.texcoord.y);
    surfaceData.alpha = albedoAlpha.a;
    
    surfaceData.smoothness = 1 - _Roughness;
    
    // 自发光
    surfaceData.emission = _EmissionIntensity * input.texcoord.z;
    surfaceData.emissionColor = _EmissionColor;
}

inline void InitializeInputData(Varyings input, CustomSurfaceData surfaceData, inout CustomInputData inputData)
{
    inputData.positionWS = input.positionWSAndFog.xyz;
    inputData.normalWS = input.normalWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);
    inputData.viewDirectionWS = viewDirWS;

	// 阴影值
    inputData.shadowCoord = GetShadowCoordInFragment(inputData.positionWS, input.shadowCoord);
    
    // 雾
    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), input.positionWSAndFog.w);
    
    inputData.bakedGI = SampleSHPixel(input.vertexSH, inputData.normalWS.xyz);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SampleShadowMask();
}

Varyings vert(Attributes input)
{
    UNITY_SETUP_INSTANCE_ID(input);

    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float4 positionWS = GetGrassPosition(input, normalWS);

    Varyings output;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    output.positionCS = TransformWorldToHClip(positionWS.xyz);
    output.texcoord = half3(input.texcoord, positionWS.w);
    output.normalWS = normalWS;
    output.positionWSAndFog = float4(positionWS.xyz, ComputeFogFactor(output.positionCS.z));
    output.shadowCoord = GetShadowCoord(positionWS.xyz, output.positionCS);

    // sh
    output.vertexSH = SampleSHVertex(output.normalWS);
        
    return output;
}

FragData frag(Varyings input)
{
    CustomSurfaceData surfaceData = GetDefaultSurfaceData();
    InitializeSurfaceData(input, surfaceData);

    CustomInputData inputData = GetDefaultInputData();
    InitializeInputData(input, surfaceData, inputData);
    
    half4 shadowMask = CalculateShadowMask(inputData);
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);
    BxDFContext bxdfContext = GetBxDFContext(inputData, mainLight.direction);
    
    // 阴影值
    half shadowAtten = mainLight.shadowAttenuation;
    half3 shadow = lerp(_G_ShadowColor, 1, shadowAtten);

    // GI
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
    inputData.bakedGI *= surfaceData.albedo;
    half3 giColor = inputData.bakedGI;
    
    // 反射环境
    half perceptualRoughness = _Roughness;
    giColor += _ReflectionIntensity * GetGlossyEnvironmentReflection(bxdfContext.R, perceptualRoughness);

    // 主灯颜色(草不要暗部效果)
    half3 mainLightColor = surfaceData.albedo * mainLight.color * shadow * bxdfContext.NoL_01;

    half3 color = mainLightColor + giColor;
    
    // 自发光
    color += surfaceData.emission * surfaceData.emissionColor * shadow;

    // 与雾混合
    color = MixFog(color, inputData, surfaceData);

    FragData output = (FragData) 0;
    output.color = half4(color, 1);
    output.normal = float4(input.normalWS * 0.5 + 0.5, 0.0);
    return output;
}

///////////////////////////////////////////////////////////////////////////////
//                             ShadowCaster                                   /
///////////////////////////////////////////////////////////////////////////////
float3 _LightDirection;
float3 _LightPosition;

Varyings ShadowPassVertex(Attributes input)
{
    UNITY_SETUP_INSTANCE_ID(input);
    
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float4 positionWS = GetGrassPosition(input, normalWS);
    
    Varyings output = (Varyings) 0;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
#if USING_ALPHA_CUTOFF
    output.texcoord = half3(input.texcoord, 1);
#endif

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
	float3 lightDirectionWS = SafeNormalize(_LightPosition - positionWS.xyz);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS.xyz, normalWS, lightDirectionWS));
#if UNITY_REVERSED_Z
	positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
    output.positionCS = positionCS;
    
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_Target
{
#if USING_ALPHA_CUTOFF
    half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord.xy);
    clip(albedoAlpha.a - _AlphaCutoff);
#endif
    return 0;
}

///////////////////////////////////////////////////////////////////////////////
//                              DepthOnly                                     /
///////////////////////////////////////////////////////////////////////////////
Varyings DepthOnlyVertex(Attributes input)
{
    UNITY_SETUP_INSTANCE_ID(input);
        
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float4 positionWS = GetGrassPosition(input, normalWS);
    
    Varyings output = (Varyings) 0;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    output.positionCS = TransformWorldToHClip(positionWS.xyz);
#if USING_ALPHA_CUTOFF
    output.texcoord = half3(input.texcoord, 1);
#endif
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
#if USING_ALPHA_CUTOFF
    half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord.xy);
	clip(albedoAlpha.a - _AlphaCutoff);
#endif
    return 0;
}

#endif
