using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

internal class TAARendererFeature : ScriptableRendererFeature
{
    #region TAAPass
    private class TAARenderPass : ScriptableRenderPass
    {
        private static readonly Vector2[] Halton23Sequence16 =
        {
            new(0, 0),
            new(0.5f, 0.3333333333333333f),
            new(0.25f, 0.6666666666666666f),
            new(0.75f, 0.1111111111111111f),
            new(0.125f, 0.4444444444444444f),
            new(0.625f, 0.7777777777777777f),
            new (0.375f, 0.2222222222222222f),
            new (0.875f, 0.5555555555555556f),
            new (0.0625f, 0.8888888888888888f),
            new (0.5625f, 0.037037037037037035f),
            new (0.3125f, 0.37037037037037035f),
            new (0.8125f, 0.7037037037037037f),
            new (0.1875f, 0.14814814814814814f),
            new (0.6875f, 0.48148148148148145f),
            new (0.4375f, 0.8148148148148147f),
            new (0.9375f, 0.25925925925925924f),
        };
        
        private float blendFactor = .05f;
        private const string shaderName = "Hidden/TAA";
        private Material mat;
        private RenderTexture prevRT;
        private Matrix4x4 prevInvVPMatrix;
        private Camera cam;

        public TAARenderPass(float blendFactor)
        {
            this.blendFactor = blendFactor;
            Shader shader = Shader.Find(shaderName);
            if (shader == null)
            {
                Debug.LogError("Did not find TAA shader!");
            }
            mat = new Material(shader)
            { 
                hideFlags = HideFlags.HideAndDontSave
            };
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            cam = renderingData.cameraData.camera;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            cam = renderingData.cameraData.camera;
            if (!(cam.cameraType == CameraType.SceneView || cam.cameraType == CameraType.Game))
                return;
            
            CommandBuffer cmd = CommandBufferPool.Get(shaderName);
            
            int w = cam.pixelWidth;
            int h = cam.pixelHeight;
            if (prevRT == null || prevRT.width != w || prevRT.height != h)
            {
                prevRT = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.DefaultHDR);
                cmd.Blit(BuiltinRenderTextureType.CurrentActive, prevRT);
                mat.SetTexture("_PrevTex", prevRT);
            }
            
            mat.SetFloat("_Blend", Time.frameCount > 1 ? blendFactor : 1f);
            mat.SetMatrix("_InvCameraProjection", cam.nonJitteredProjectionMatrix.inverse);
            mat.SetMatrix("_FrameMatrix", prevInvVPMatrix * cam.cameraToWorldMatrix);

            int des = Shader.PropertyToID("_Temp");
            cmd.GetTemporaryRT(des, w, h, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            
            var cameraTarget = renderingData.cameraData.renderer.cameraColorTarget;
            cmd.Blit(BuiltinRenderTextureType.CurrentActive, des, mat);
            cmd.Blit(des, cameraTarget);
            cmd.Blit(des, prevRT);

            cmd.ReleaseTemporaryRT(des);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            
            prevInvVPMatrix = cam.nonJitteredProjectionMatrix * cam.worldToCameraMatrix;
            
            cam.ResetProjectionMatrix();
        }
        
        public override void FrameCleanup(CommandBuffer cmd)
        {
            // Jitter
            cam.ResetProjectionMatrix();
            cam.nonJitteredProjectionMatrix = cam.projectionMatrix;
            Matrix4x4 projectionMatrix = cam.projectionMatrix;
            Vector2 jitter = new (
                (Halton23Sequence16[Time.frameCount % 16].x - 0.5f) / cam.pixelWidth * 2f, 
                (Halton23Sequence16[Time.frameCount % 16].y - 0.5f) / cam.pixelHeight * 2f
            );
            projectionMatrix.m02 = jitter.x;
            projectionMatrix.m12 = jitter.y;
            cam.projectionMatrix = projectionMatrix;
        }
    }
    
    TAARenderPass pass;
    #endregion

    #region setting
    [Serializable]
    class Setting
    {
        [Range(0f, 1f)] public float blend = .05f;
    }
    
    [SerializeField] Setting setting = new Setting();
    #endregion
    
    public override void Create()
    {
        pass = new TAARenderPass(setting.blend);
        pass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
