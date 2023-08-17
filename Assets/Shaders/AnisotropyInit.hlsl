#ifndef CUSTOM_LIT_INIT_INCLUDED
#define CUSTOM_LIT_INIT_INCLUDED

void InitializeBRDFDataAniso(Surface surfaceWS, out CustomBRDFData outBRDFData, AnisoConfig config)
{
    outBRDFData = (CustomBRDFData)0;
    
    outBRDFData.diffuseColor = RemapDiffuseColor(surfaceWS.baseColor, surfaceWS.metallic);
    outBRDFData.f0 = RemapF0(surfaceWS.reflectance, surfaceWS.metallic, surfaceWS.baseColor);
    outBRDFData.perceptualRoughness = surfaceWS.perceptualRoughness;
    outBRDFData.roughness = surfaceWS.roughness;
    outBRDFData.dfg = GetDFG(surfaceWS);
    outBRDFData.at = max(outBRDFData.roughness * (1.0 + config.anisotropy), 0.001);
    outBRDFData.ab = max(outBRDFData.roughness * (1.0 - config.anisotropy), 0.001);
}

#endif