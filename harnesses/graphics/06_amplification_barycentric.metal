// Feature: vertex amplification and fragment barycentric coordinates.
// Demonstrates: [[amplification_id]] / [[amplification_count]] in the vertex
// stage (one draw producing multiple amplified outputs, e.g. for stereo /
// multiview), and [[barycentric_coord]] + [[primitive_id]] read in the fragment
// stage. These surface as their own air.* argument-metadata kinds.
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vmain(constant float4* positions [[buffer(0)]],
                       uint vid    [[vertex_id]],
                       uint ampId  [[amplification_id]],
                       uint ampCnt [[amplification_count]])
{
    VertexOut out;
    out.position = positions[vid];
    // Nudge each amplified view so the two outputs differ.
    out.position.x += float(ampId) / float(ampCnt);
    out.color = float4(float(ampId), float(ampCnt), 0.0, 1.0);
    return out;
}

fragment float4 fmain(VertexOut in   [[stage_in]],
                      float3 bary     [[barycentric_coord]],
                      uint   primId   [[primitive_id]])
{
    // Weight the interpolated color by the barycentric coordinates.
    float w = bary.x * 0.5 + bary.y * 0.3 + bary.z * 0.2;
    return in.color * w + float4(float(primId & 7u) / 7.0);
}
