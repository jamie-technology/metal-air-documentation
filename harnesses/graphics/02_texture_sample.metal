// Feature: texture sampling in a fragment shader.
// Demonstrates: texture2d<float> + sampler arguments ([[texture(n)]],
// [[sampler(n)]]), an interpolated UV varying, and how sample() lowers to an
// AIR sample intrinsic carrying texture + sampler handles and coordinates.
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

fragment float4 fmain(VertexOut in [[stage_in]],
                      texture2d<float> tex [[texture(0)]],
                      sampler          smp [[sampler(0)]])
{
    return tex.sample(smp, in.uv);
}
