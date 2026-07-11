// Feature: argument buffers.
// Demonstrates: a struct of resources tagged with [[id(n)]] passed as a single
// `device` argument. In AIR each member surfaces as its own binding in the
// argument metadata (buffers, textures, samplers, and plain constants), rather
// than as top-level kernel arguments.
#include <metal_stdlib>
using namespace metal;

struct Material {
    texture2d<float>    albedo   [[id(0)]];
    texture2d<float>    normal   [[id(1)]];
    sampler             smp      [[id(2)]];
    device const float* weights  [[id(3)]];
    float4              tint     [[id(4)]];
    uint                flags    [[id(5)]];
};

kernel void shade(device const Material& mat [[buffer(0)]],
                  device const float2*   uv  [[buffer(1)]],
                  device float4*         out [[buffer(2)]],
                  uint gid [[thread_position_in_grid]])
{
    float2 coord = uv[gid];
    float4 a = mat.albedo.sample(mat.smp, coord);
    float4 n = mat.normal.sample(mat.smp, coord);
    out[gid] = a * mat.tint + n * mat.weights[mat.flags & 3u];
}
