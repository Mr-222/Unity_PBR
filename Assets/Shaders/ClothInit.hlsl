#ifndef CUSTOM_CLOTH_INIT_INCLUDED
#define CUSTOM_CLOTH_INIT_INCLUDED

CustomBRDFData InitializeBRDFData(Surface surfaceWS)
{
    CustomBRDFData outBRDFData;
    
    outBRDFData.diffuseColor = surfaceWS.baseColor;
    outBRDFData.f0 = surfaceWS.sheenColor;
    outBRDFData.perceptualRoughness = surfaceWS.perceptualRoughness;
    outBRDFData.roughness = surfaceWS.roughness;
    outBRDFData.dfg = GetDFG(surfaceWS);
    outBRDFData.subsurfaceColor = surfaceWS.subsurfaceColor;

    return outBRDFData;
}

#endif