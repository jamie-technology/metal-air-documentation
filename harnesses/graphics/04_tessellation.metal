// Feature: tessellation pipeline stages.
// Demonstrates: (1) a compute kernel that writes MTLTriangleTessellationFactors
// into a device buffer, and (2) a post-tessellation vertex function marked with
// [[patch(triangle, 3)]] that reads control points via patch_control_point<T>
// and the [[position_in_patch]] barycentric coordinate. In AIR the
// post-tessellation vertex carries !air.patch metadata describing patch type
// and control-point count.
#include <metal_stdlib>
using namespace metal;

struct ControlPoint {
    float4 position [[attribute(0)]];
};

struct PatchIn {
    patch_control_point<ControlPoint> cp;
};

struct VertexOut {
    float4 position [[position]];
};

// Stage 1: emit per-patch tessellation factors.
kernel void tess_factors(device MTLTriangleTessellationFactorsHalf* factors [[buffer(0)]],
                         constant float& edge   [[buffer(1)]],
                         constant float& inside [[buffer(2)]],
                         uint pid [[thread_position_in_grid]])
{
    factors[pid].edgeTessellationFactor[0]   = half(edge);
    factors[pid].edgeTessellationFactor[1]   = half(edge);
    factors[pid].edgeTessellationFactor[2]   = half(edge);
    factors[pid].insideTessellationFactor    = half(inside);
}

// Stage 2: post-tessellation vertex function.
[[patch(triangle, 3)]]
vertex VertexOut tess_vertex(PatchIn patch [[stage_in]],
                             float3 bary [[position_in_patch]])
{
    float4 p = patch.cp[0].position * bary.x
             + patch.cp[1].position * bary.y
             + patch.cp[2].position * bary.z;
    VertexOut out;
    out.position = p;
    return out;
}
