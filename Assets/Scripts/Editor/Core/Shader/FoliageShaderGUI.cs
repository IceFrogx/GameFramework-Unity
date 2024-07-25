using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class FoliageShaderGUI : BaseShaderGUI
{
    private new static class Styles
    {
        public static readonly GUIContent baseMap = EditorGUIUtility.TrTextContent("Base Map",
            "Specifies the base Material and/or Color of the surface. If you��ve selected Transparent or Alpha Clipping under Surface Options, your Material uses the Texture��s alpha channel or color.");
    }

    private MaterialProperty m_BaseMapProp;
    private MaterialProperty m_BaseColorProp;

    private MaterialProperty m_EnableSubsurfaceScattering;
    private MaterialProperty m_UseGradientColorProp;

    protected override void FindProperties(MaterialProperty[] properties)
    {
        base.FindProperties(properties);

        m_BaseMapProp = FindProperty("_BaseMap", false);
        m_BaseColorProp = FindProperty("_BaseColor", false);

        m_EnableSubsurfaceScattering = FindProperty("_EnableSubsurfaceScattering", false);
        m_UseGradientColorProp = FindProperty("_UseGradientColor", false);
    }

    protected override void DoGUI()
    {
        DoGUI_Main();
        DoGUI_AlphaCutoff();
        DoGUI_SSS();
        DoGUI_Other();
        DoGUI_UnityDefaultPart();
    }

    private void DoGUI_Main()
    {
        EditorGUILayout.BeginVertical(BaseShaderGUI.Styles.frameBgStyle);
        {
            DoGUI_Title("< Main >");

            m_Editor.TexturePropertySingleLine(Styles.baseMap, m_BaseMapProp, m_BaseColorProp);

            DrawProperty(m_UseGradientColorProp, "��ɫ����");
            if (m_UseGradientColorProp.floatValue > 0.5f)
            {
                DrawProperty("_BaseBottomColor", "�ײ���ɫ", false);
                DrawProperty("_ColorMaskHeight", "��ɫռ��", false);
            }
        }
        EditorGUILayout.EndVertical();
    }

    private void DoGUI_AlphaCutoff()
    {
        EditorGUILayout.BeginVertical(BaseShaderGUI.Styles.frameBgStyle);
        {
            DoGUI_Title("< ͸��ͨ���ü� >");
            GUILayout.Label("����ʹ��������ܽ���ʹ��ϷЧ���½���", EditorStyles.centeredGreyMiniLabel);
            DrawProperty("_UseAlphaCutoff", "ʹ��͸��ͨ���ü�", false);
            DrawProperty("_AlphaCutoff", "�ü�Alphaֵ", false);
        }
        EditorGUILayout.EndVertical();
    }

    private void DoGUI_SSS()
    {
        if (!HasProperty("_SubsurfaceRadius"))
            return;

        EditorGUILayout.BeginVertical(BaseShaderGUI.Styles.frameBgStyle);
        {
            DoGUI_Title("< SSS >");

            DrawProperty(m_EnableSubsurfaceScattering, "ʹ�ôα���ɢ��");
            if (m_EnableSubsurfaceScattering.floatValue > 0.5f)
            {
                DrawProperty("_SubsurfaceRadius", "ɢ��뾶", false);
                DrawProperty("_SubsurfaceColor", "ɢ����ɫ", false);
                DrawProperty("_SubsurfaceColorIntensity", "ɢ����ɫǿ��", false);
            }
        }
        EditorGUILayout.EndVertical();
    }

    private void DoGUI_Other()
    {
        EditorGUILayout.BeginVertical(BaseShaderGUI.Styles.frameBgStyle);
        {
            DoGUI_Title("< Other >");
            DrawProperty("_Cull", "������������ü�", false);
            DrawProperty("_EnableWind", "�綯Ч��", false);
        }
        EditorGUILayout.EndVertical();
    }
}
