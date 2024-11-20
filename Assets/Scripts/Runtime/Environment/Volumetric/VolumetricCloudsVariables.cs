using System;
using UnityEngine;
using UnityEngine.Rendering;

[GenerateHLSL(needAccessors = false, generateCBuffer = true)]
public struct VolumetricCloudsVariables
{
    public Vector2Int cameraColorTextureSize;

    public Vector2Int halfDepthTextureSize;

    public Vector4 cloudsTextureSize;

    public Color cloudColor;

    // ����ϵ��
    public Vector4 extinction;

    // �緽��
    public Vector2 windDirection;

    public float cloudMaskUVScale;

    // ���ǰ뾶
    public float planetRadius;

    // �Ʋ㺣�θ߶�
    public float cloudLayerAltitude;

    // �Ʋ���
    public float cloudLayerThickness;

    public float shapeFactor;

    // �ܶ�
    public float densityNoiseScale;
    public float densityMultiplier;

    // ��ʴ
    public float erosionFactor;
    public float erosionNoiseScale;

    // Lighting
    public float lightIntensity;
    public float multiScattering;
    public float powderEffectIntensity;
    public float erosionOcclusion;

    // HG����
    public float phaseG;
    public float phaseG2;
    public float phaseBlend;

    // ��������
    public float fadeInStart;
    public float fadeInDistance;

    public int numPrimarySteps;

    public int useDownsampleResolution;
}
