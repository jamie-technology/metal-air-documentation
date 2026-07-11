// Feature: interpolation qualifiers on varyings.
// Demonstrates: [[flat]], [[center_no_perspective]], and default (perspective,
// center) interpolation, plus [[point_size]] from the vertex stage. These
// qualifiers show up as metadata on the fragment input signature in AIR.
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position  [[position]];
    float  psize     [[point_size]];
    float4 smoothCol;
    float4 flatCol   [[flat]];
    float2 screenUV  [[center_no_perspective]];
};

vertex VertexOut vmain(uint vid [[vertex_id]])
{
    VertexOut out;
    out.position  = float4(float(vid), 0.0, 0.0, 1.0);
    out.psize     = 1.0;
    out.smoothCol = float4(1.0, 0.0, 0.0, 1.0);
    out.flatCol   = float4(0.0, 1.0, 0.0, 1.0);
    out.screenUV  = float2(vid);
    return out;
}

fragment float4 fmain(VertexOut in [[stage_in]])
{
    return in.smoothCol + in.flatCol + float4(in.screenUV, 0.0, 0.0);
}
