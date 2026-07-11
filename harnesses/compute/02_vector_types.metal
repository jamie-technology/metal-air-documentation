// Feature: vector types and swizzles.
// Demonstrates: float2/float3/float4 memory layout (note float3 is 16-byte
// aligned), component-wise arithmetic lowered to LLVM vector ops, and how
// swizzles (.xyz, .wzyx) become shufflevector instructions.
#include <metal_stdlib>
using namespace metal;

kernel void vector_types(device const float4* a   [[buffer(0)]],
                         device const float4* b   [[buffer(1)]],
                         device float4*       out [[buffer(2)]],
                         uint                 gid [[thread_position_in_grid]])
{
    float4 va = a[gid];
    float4 vb = b[gid];
    float4 sum = va + vb;          // vector fadd
    float3 rgb = sum.xyz * 0.5;    // swizzle + scalar broadcast
    out[gid] = float4(rgb, va.w);  // reconstruct with a shuffle
}
