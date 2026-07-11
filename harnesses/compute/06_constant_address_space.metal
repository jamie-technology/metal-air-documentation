// Feature: constant address space and by-value struct arguments.
// Demonstrates: [[buffer(n)]] with `constant` (addrspace(2)), a uniform struct
// passed by const reference, and how struct field access lowers to
// getelementptr on the constant buffer.
#include <metal_stdlib>
using namespace metal;

struct Params {
    float  scale;
    float  bias;
    uint   count;
    float4 tint;
};

kernel void apply_params(device const float* in     [[buffer(0)]],
                         device float*       out    [[buffer(1)]],
                         constant Params&    params [[buffer(2)]],
                         uint                gid    [[thread_position_in_grid]])
{
    if (gid >= params.count) return;
    out[gid] = in[gid] * params.scale + params.bias + params.tint.x;
}
