// Feature: vertex-stage built-in inputs.
// Demonstrates: [[vertex_id]] and [[instance_id]] attribute lowering, and
// indexing a `constant` buffer by the vertex id instead of using [[stage_in]]
// (the "pull" vertex fetch model).
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vmain(constant float4* positions [[buffer(0)]],
                       uint vid [[vertex_id]],
                       uint iid [[instance_id]])
{
    VertexOut out;
    out.position = positions[vid];
    out.position.x += float(iid) * 0.1;
    out.color = float4(float(vid), float(iid), 0.0, 1.0);
    return out;
}
