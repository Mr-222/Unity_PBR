using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class QuadAreaLight : MonoBehaviour
{
    private Material lightMaterial;
    private MeshRenderer meshrenderer;
    private MaterialPropertyBlock propertyBlock;
    private Mesh mesh;
    private CommandBuffer buffer;
    private RenderTexture prefilteredDiffuse;
    private RenderTexture prefilteredSpecular;
    
    public struct AreaLightData
    {
        public Color color;
        public float intensity;
        public bool doubleSided;
        public Vector4 position0;
        public Vector4 position1;
        public Vector4 position2;
        public Vector4 position3;
        public RenderTexture diffuseTex;
        public RenderTexture specTex;
    }
    private AreaLightData lightData = new AreaLightData();
    
    // Up to 16 area lights in the scene.
    private static List<AreaLightData> lightDataList = new List<AreaLightData>(); 
    public static List<AreaLightData> lights
    {
        get => lightDataList;
    }

    [SerializeField]
    private Color color;
    
    [SerializeField, Range(0f, 20f)]
    private float intensity = 1f;
    
    [SerializeField]
    private bool doubleSided = false;

    [SerializeField] 
    private Texture2D lightTexture;
    
    // Start is called before the first frame update
    void Start()
    {
        Shader.EnableKeyword("_QUAD_AREA_LIGHT");
        
        propertyBlock = new MaterialPropertyBlock();
        meshrenderer = GetComponent<MeshRenderer>();
        mesh = GetComponent<MeshFilter>().sharedMesh;
        lightMaterial = new Material(Shader.Find("Hidden/AreaLight"));
        meshrenderer.material = lightMaterial;
    }

    private void OnEnable()
    {
        Shader.EnableKeyword("_QUAD_AREA_LIGHT");
        
        if (lightMaterial != null)
        {
            meshrenderer.material = lightMaterial;
        }
    }
    
    private void OnDisable()
    {
        lightDataList.Remove(lightData);
        if (lightDataList.Count <= 0)
        {
            Shader.DisableKeyword("_QUAD_AREA_LIGHT");
        }
        
        if (prefilteredDiffuse != null)
        {
            Texture2D white = Texture2D.blackTexture;
            Graphics.Blit(white, prefilteredDiffuse);
            Graphics.Blit(white, prefilteredSpecular);
        }
    }

    private void OnValidate()
    {
        if (lightTexture != Texture2D.whiteTexture)  
            PrefilterLightTexture();
        else
        {
            Texture2D white = Texture2D.whiteTexture;
            Graphics.Blit(white, prefilteredDiffuse);
            Graphics.Blit(white, prefilteredSpecular);
        }
    }

    // Update is called once per frame
    void Update()
    {
        UpdateLightData();
        
        var buffer = CommandBufferPool.Get("LTC");
        
        Graphics.ExecuteCommandBuffer(buffer);
        buffer.Clear();
        CommandBufferPool.Release(buffer);
    }

    private void OnDestroy()
    {
        lightDataList.Remove(lightData);
        if (lightDataList.Count <= 0)
        {
            Shader.DisableKeyword("_QUAD_AREA_LIGHT");
        }

        if (prefilteredDiffuse != null)
        {
            prefilteredDiffuse.Release();
            prefilteredSpecular.Release();
        }
    }

    private void UpdateLightData()
    {
        int index = lightDataList.FindIndex(item => item.Equals(lightData));
        
        lightData.color = color;
        lightData.intensity = intensity;
        lightData.doubleSided = doubleSided;
        
        // Original vertices arrangement:
        // vertices[2]  vertices[3]
        // vertices[0]  vertices[1]
        // We need to rearrange them to counterclockwise sequence.
        if (mesh == null)
        {
            mesh = GetComponent<MeshFilter>().sharedMesh;
        }
        Vector3[] vertices = mesh.vertices;
        // Transform to world space.
        for (int i = 0; i < mesh.vertexCount; i++)
        {
            vertices[i] = transform.TransformPoint(vertices[i]);
        }
        
        lightData.position0 = new Vector4(vertices[0].x, vertices[0].y, vertices[0].z, 1.0f);
        lightData.position1 = new Vector4(vertices[1].x, vertices[1].y, vertices[1].z, 1.0f);
        lightData.position2 = new Vector4(vertices[3].x, vertices[3].y, vertices[3].z, 1.0f);
        lightData.position3 = new Vector4(vertices[2].x, vertices[2].y, vertices[2].z, 1.0f);

        lightData.diffuseTex = prefilteredDiffuse;
        lightData.specTex = prefilteredSpecular;

        if (index >= 0)
            lightDataList[index] = lightData;
        else
        {
            lightDataList.Add(lightData);
            index = lightDataList.Count - 1;
        }

        if (propertyBlock == null)
            propertyBlock = new MaterialPropertyBlock();

        if (lightTexture == null)
            lightTexture = Texture2D.whiteTexture;
        
        propertyBlock.SetInt("_AreaLightIndex", index);
        propertyBlock.SetTexture("_LightTexture", lightTexture);
        meshrenderer.SetPropertyBlock(propertyBlock);
    }

    RenderTexture CalculateSpec(Texture2D tex)
    {
        RenderTexture filterd_tex = new RenderTexture(tex.width, tex.height, 0, RenderTextureFormat.DefaultHDR, tex.mipmapCount);
        filterd_tex.wrapMode = TextureWrapMode.Clamp;
        filterd_tex.useMipMap = true;
        filterd_tex.autoGenerateMips = false;
        filterd_tex.filterMode = FilterMode.Trilinear;
        filterd_tex.Create();
        RenderTexture swap_tex = new RenderTexture(tex.width, tex.height, 0, RenderTextureFormat.DefaultHDR, tex.mipmapCount);
        swap_tex.useMipMap = true;
        swap_tex.autoGenerateMips = false;
        swap_tex.Create();
        
        var blurMat = new Material(Shader.Find("Hidden/Blur"));

        CommandBuffer cb = new CommandBuffer();

        cb.Blit(tex, filterd_tex);
        cb.Blit(filterd_tex, swap_tex);
        for (int i = 1; i < tex.mipmapCount; i++)
        { 
            cb.SetRenderTarget(filterd_tex, i);
            cb.SetGlobalInt("_Level", i - 1);
            cb.Blit(swap_tex, BuiltinRenderTextureType.CurrentActive, blurMat, 0);
            cb.SetRenderTarget(swap_tex, i);
            cb.Blit(filterd_tex, BuiltinRenderTextureType.CurrentActive, blurMat, 1);
        }
        Graphics.ExecuteCommandBuffer(cb);
        swap_tex.Release();
        cb.Release();
        return filterd_tex;
    }

    RenderTexture CalculateDiffuse(Texture2D tex)
    {
        RenderTexture filterd_tex = new RenderTexture(tex.width, tex.height, 0, RenderTextureFormat.DefaultHDR, tex.mipmapCount);
        filterd_tex.wrapMode = TextureWrapMode.Clamp;
        filterd_tex.useMipMap = true;
        filterd_tex.autoGenerateMips = false;
        filterd_tex.filterMode = FilterMode.Trilinear;
        filterd_tex.Create();
        RenderTexture swap_tex = new RenderTexture(tex.width, tex.height, 0, RenderTextureFormat.DefaultHDR, tex.mipmapCount);
        swap_tex.useMipMap = true;
        swap_tex.autoGenerateMips = false;
        swap_tex.Create();

        var blurMat = new Material(Shader.Find("Hidden/Blur"));

        CommandBuffer cb = new CommandBuffer();

        cb.Blit(tex, filterd_tex, blurMat, 2);
        cb.Blit(filterd_tex, swap_tex);
        for (int i = 1; i < tex.mipmapCount; i++)
        { 
            cb.SetRenderTarget(filterd_tex, i);
            cb.SetGlobalInt("_Level", i - 1);
            cb.Blit(swap_tex, BuiltinRenderTextureType.CurrentActive, blurMat, 0);
            cb.SetRenderTarget(swap_tex, i);
            cb.Blit(filterd_tex, BuiltinRenderTextureType.CurrentActive, blurMat, 1);
        }
        Graphics.ExecuteCommandBuffer(cb);
        swap_tex.Release();
        cb.Release();
        return filterd_tex;
    }
    
    void PrefilterLightTexture()
    {
        if (prefilteredDiffuse != null)
        {
            prefilteredDiffuse.Release();
            prefilteredDiffuse = null;
            prefilteredSpecular.Release();
            prefilteredSpecular = null;
        }

        if (lightTexture != null)
        {
            prefilteredDiffuse = CalculateDiffuse(lightTexture);
            prefilteredSpecular = CalculateSpec(lightTexture);
        }
    }
}
