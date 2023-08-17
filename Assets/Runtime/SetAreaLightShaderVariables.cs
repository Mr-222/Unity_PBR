using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class SetAreaLightShaderVariables : MonoBehaviour
{
    private Texture2D ltc1;
    private Texture2D ltc2;
    
    private void Start()
    {
        CreateLTCTextures();
    }

    // Update is called once per frame
    void Update()
    {
        CommandBuffer cb = CommandBufferPool.Get("LTC");
        
        SetLTCTextures(ref cb);
        
        List<QuadAreaLight.AreaLightData> lights = QuadAreaLight.lights;
        
        Vector4[] colors = new Vector4[16];
        float[] intensities = new float[16];
        float[] doubles = new float[16];
        Vector4[] positions = new Vector4[64];
        
        for (int i = 0; i < lights.Count; i++)
        { 
            var light = lights[i];
            colors[i] = light.color;
            intensities[i] = light.intensity;
            doubles[i] = light.doubleSided ? 1f : 0f;
            positions[i * 4] = light.position0;
            positions[i * 4 + 1] = light.position1;
            positions[i * 4 + 2] = light.position2;
            positions[i * 4 + 3] = light.position3;
            
            cb.SetGlobalTexture("_PrefilteredDiffuse" + i, light.diffuseTex);
            cb.SetGlobalTexture("_PrefilteredSpecular" + i, light.specTex);
        }
        
        cb.SetGlobalInt("_AreaLightNum", lights.Count);
        cb.SetGlobalVectorArray("_AreaLightColor", colors);
        cb.SetGlobalFloatArray("_AreaLightIntensity", intensities);
        cb.SetGlobalFloatArray("_DoubleSided", doubles);
        cb.SetGlobalVectorArray("_AreaLightVertexPositions", positions);

        Graphics.ExecuteCommandBuffer(cb);
        cb.Clear();
        CommandBufferPool.Release(cb);
    }

    void CreateLTCTextures()
    {
        ltc1 = new Texture2D(64, 64, TextureFormat.RGBA64, false, true);
        ltc1.wrapMode = TextureWrapMode.Clamp;
        ltc1.filterMode = FilterMode.Bilinear;

        ltc2 = new Texture2D(64, 64, TextureFormat.RGBA64, false, true);
        ltc2.wrapMode = TextureWrapMode.Clamp;
        ltc2.filterMode = FilterMode.Bilinear;
        
        const string path1 = "./Assets/LUTs/ltc1.png";
        const string path2 = "./Assets/LUTs/ltc2.png";
   
        byte[] ltc1Data = File.ReadAllBytes(path1);
        byte[] ltc2Data = File.ReadAllBytes(path2);
        ltc1.LoadImage(ltc1Data);
        ltc2.LoadImage(ltc2Data);
    }
    
    private void SetLTCTextures(ref CommandBuffer commandBuffer)
    {
        commandBuffer.SetGlobalTexture("_LTC1", ltc1);
        commandBuffer.SetGlobalTexture("_LTC2", ltc2);
    }
}
