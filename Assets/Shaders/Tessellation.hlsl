#ifndef CUSTOM_TESSELLATION
#define CUSTOM_TESSELLATION

#ifdef _SHADING_MODEL_CLOTH
    #define LitPassVertex ClothPassVertex
#endif

struct TessellationControlPoint
{
    float4 positionOS : INTERNALTESSPOS;
    float2 baseUV     : TEXCOORD0;
    float4 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    LIGHTMAP_UV_ATTRIBUTE
};

[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("MyPatchConstantFunction")]
TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

float TessellationEdgeFactor (float3 p0, float3 p1)
{
    float edgeLength = distance(p0, p1);

    float3 edgeCenter = (p0 + p1) * .5;
    float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

    return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);
}

TessellationFactors MyPatchConstantFunction (InputPatch<TessellationControlPoint, 3> patch)
{
    TessellationFactors f;
    #if _TESSELLATION
        float3 p0 = mul(unity_ObjectToWorld, patch[0].positionOS).xyz;
        float3 p1 = mul(unity_ObjectToWorld, patch[1].positionOS).xyz;
        float3 p2 = mul(unity_ObjectToWorld, patch[2].positionOS).xyz;
    
        f.edge[0] = TessellationEdgeFactor(p1, p2);
        f.edge[1] = TessellationEdgeFactor(p2, p0);
        f.edge[2] = TessellationEdgeFactor(p0, p1);
        f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3;
    #else
        f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 1;
    #endif

    return f;
}

#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

[domain("tri")]
Varyings MyDomainProgram (TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    Attributes data;
    MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS);
    MY_DOMAIN_PROGRAM_INTERPOLATE(baseUV);
    MY_DOMAIN_PROGRAM_INTERPOLATE(normalOS);
    MY_DOMAIN_PROGRAM_INTERPOLATE(tangentOS);
    #ifdef LIGHTMAP_ON
        MY_DOMAIN_PROGRAM_INTERPOLATE(lightMapUV);
    #endif

    return LitPassVertex(data);
}

TessellationControlPoint MyTessellationVertexProgram (Attributes input) {
    TessellationControlPoint p;
    p.positionOS = input.positionOS;
    p.baseUV = input.baseUV;
    p.normalOS = input.normalOS;
    p.tangentOS = input.tangentOS;
    TRANSFER_LIGHTMAP_DATA(input, p);
    
    return p;
}

#endif