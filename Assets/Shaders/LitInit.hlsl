#ifndef CUSTOM_LIT_INIT_INCLUDED
#define CUSTOM_LIT_INIT_INCLUDED

void InitializeBRDFData(Surface surfaceWS, out CustomBRDFData outBRDFData)
{
    outBRDFData = (CustomBRDFData)0;
    
    outBRDFData.diffuseColor = RemapDiffuseColor(surfaceWS.baseColor, surfaceWS.metallic);
    outBRDFData.f0 = RemapF0(surfaceWS.reflectance, surfaceWS.metallic, surfaceWS.baseColor);
    outBRDFData.perceptualRoughness = surfaceWS.perceptualRoughness;
    outBRDFData.roughness = surfaceWS.roughness;
    outBRDFData.dfg = GetDFG(surfaceWS);
    #ifdef _CLEARCOAT
        outBRDFData.clearCoat = clamp(surfaceWS.clearCoat, 1e-2, 1.0);
        outBRDFData.clearCoatPerceptualRoughness = surfaceWS.clearCoatPerceptualRoughness;
        outBRDFData.clearCoatRoughness = surfaceWS.clearCoatRoughness;
        // recompute f0 based on a clear coat-material interface instead of air-material, IOR has changed
        float3 f0Base = F0ClearCoatToSurface(outBRDFData.f0);
        outBRDFData.f0 = lerp(outBRDFData.f0, f0Base, outBRDFData.clearCoat);
        outBRDFData.roughness = lerp(outBRDFData.roughness, max(outBRDFData.roughness, outBRDFData.clearCoatRoughness), outBRDFData.clearCoat);
    #endif
}

#endif