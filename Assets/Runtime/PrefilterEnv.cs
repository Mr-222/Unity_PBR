using System;
using UnityEngine;
using UnityEditor;

/*
 * Pre-convolving environment map
 * However, I decide to deprecate it and use Reflection Probe's built-in convolution
 */
[Obsolete("This class is obsolete, use Reflection Probe's built-in convolution instead.")]
[ExecuteAlways]
public class PrefilterEnv : MonoBehaviour
{
    public ComputeShader shader;

    public Cubemap envCube;

    private void Start()
    {
        PrefilterSpecularCubemap(envCube);
    }

    private void OnEnable()
    {
        PrefilterSpecularCubemap(envCube);
    }

    void PrefilterSpecularCubemap(Cubemap cubemap)
    {
        int kernelHandle = shader.FindKernel("PrefilterEnv");
        int bakeSize = 128; 
        var environmentMap = new Cubemap(bakeSize, TextureFormat.RGBAFloat, true);
        int maxMip = environmentMap.mipmapCount;
        int sampleCubemapSize = cubemap.width;
        environmentMap.filterMode = FilterMode.Trilinear;
        for (int mip = 0; mip < maxMip; mip++)
        {
            int size = bakeSize >> mip;
            int size2 = size * size;
            Color[] tempResult = new Color[size2];
            float roughness = (float)mip / (float)(maxMip - 1);
            ComputeBuffer resultBuffer = new ComputeBuffer(size2, sizeof(float) * 4);
            for (int face = 0; face < 6; face++)
            {
                shader.SetInt("_Face", face);
                shader.SetTexture(kernelHandle, "_Cubemap", cubemap);
                shader.SetInt("_SampleCubemapSize", sampleCubemapSize);
                shader.SetInt("_Resolution", size);
                Debug.Log("roughness " + roughness);
                shader.SetFloat("_PerceptualRoughness", roughness);
                shader.SetBuffer(kernelHandle, "_Result", resultBuffer);
                shader.Dispatch(kernelHandle, size, size, 1);
                resultBuffer.GetData(tempResult);
                environmentMap.SetPixels(tempResult, (CubemapFace)face, mip);
            }
            resultBuffer.Release();
        }
        environmentMap.Apply(false);
        
        Shader.SetGlobalTexture("_PrefilteredEnvMap", environmentMap);
        
        AssetDatabase.CreateAsset(environmentMap, "Assets/HDRs/prefilteredEnvCube.cubemap");
        AssetDatabase.Refresh();
    }
}
