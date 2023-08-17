using UnityEngine;
using UnityEditor;

[ExecuteAlways]
public class BakeLUT : MonoBehaviour
{
    public ComputeShader shader;

    private void Start()
    {
        BakeLUTGGXAndCloth();
        BakeLUTGGXMultiscatter();
    }

    private void OnEnable()
    {
        BakeLUTGGXAndCloth();
        BakeLUTGGXMultiscatter();
    }

    void BakeLUTGGXAndCloth()
    {
        int kernelHandle = shader.FindKernel("DFV");
        RenderTexture renderTexture = new RenderTexture(512, 512, 0);
        renderTexture.enableRandomWrite = true;
        renderTexture.format = RenderTextureFormat.Default;
        renderTexture.wrapMode = TextureWrapMode.Clamp;
        renderTexture.autoGenerateMips = false;
        renderTexture.useMipMap = false;
        renderTexture.Create();
        shader.SetTexture(kernelHandle, "LUT", renderTexture);
        shader.Dispatch(kernelHandle, 512/4, 512/4, 1);
        Shader.SetGlobalTexture("_DFGLUT", renderTexture);
        Debug.Log("LUT integration finished.");
        
        Texture2D texture2D = saveRenderTextureToTexture2D(renderTexture, TextureFormat.RGBA32);
        saveTexture2DToPNG(texture2D, "./Assets/LUTs/LUT.png");
    }

    void BakeLUTGGXMultiscatter()
    {
        int kernelHandle = shader.FindKernel("DFV_Multiscatter");
        RenderTexture renderTexture = new RenderTexture(512, 512, 0);
        renderTexture.enableRandomWrite = true;
        renderTexture.format = RenderTextureFormat.RG32;
        renderTexture.wrapMode = TextureWrapMode.Clamp;
        renderTexture.autoGenerateMips = false;
        renderTexture.useMipMap = false;
        renderTexture.Create();
        shader.SetTexture(kernelHandle, "LUT_MultiScatter", renderTexture);
        shader.Dispatch(kernelHandle, 512/4, 512/4, 1);
        Shader.SetGlobalTexture("_DFGMultiScatteringLUT", renderTexture);
        Debug.Log("Multiscatter LUT integration finished.");

        // .png file can't store RG32 format directly, so use RGBA32 instead.
        renderTexture = new RenderTexture(512, 512, 0);
        renderTexture.enableRandomWrite = true;
        renderTexture.format = RenderTextureFormat.Default;
        renderTexture.wrapMode = TextureWrapMode.Clamp;
        renderTexture.autoGenerateMips = false;
        renderTexture.useMipMap = false;
        renderTexture.Create();
        shader.SetTexture(kernelHandle, "LUT_MultiScatter", renderTexture);
        shader.Dispatch(kernelHandle, 512/4, 512/4, 1);
        Texture2D texture2D = saveRenderTextureToTexture2D(renderTexture, TextureFormat.RGBA32);
        saveTexture2DToPNG(texture2D, "./Assets/LUTs/LUT_MultiScatter.png");
    }

    public Texture2D saveRenderTextureToTexture2D(RenderTexture renderTexture, TextureFormat format)
    {
        RenderTexture.active = renderTexture;
        Texture2D texture2D = 
            new Texture2D(renderTexture.width, renderTexture.height, format, false, false);
        texture2D.wrapMode = TextureWrapMode.Clamp;
        texture2D.ReadPixels(new Rect(0, 0, renderTexture.width, renderTexture.height), 0, 0);
        texture2D.Apply();
        RenderTexture.active = null;
        #if UNITY_EDITOR
            DestroyImmediate(renderTexture);
        #else
            Destroy(renderTexture);
        #endif
        return texture2D;
    }
    
    public void saveTexture2DToPNG(Texture2D texture, string file) {
        byte[] bytes = texture.EncodeToPNG();
        #if UNITY_EDITOR
            DestroyImmediate(texture);
        #else
            Destroy(texture);
        #endif
        System.IO.File.WriteAllBytes(file, bytes);
        Debug.Log("Write tex2D to .png file.");
        AssetDatabase.Refresh();
    }
}
