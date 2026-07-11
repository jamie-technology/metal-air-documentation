// Feature: math library builtins.
// Demonstrates: which functions become LLVM intrinsics (llvm.sqrt, llvm.sin),
// which become air.* calls (air.fast_* under -ffast-math), and how fma /
// clamp / mix / rsqrt are represented.
#include <metal_stdlib>
using namespace metal;

kernel void math_builtins(device const float* in  [[buffer(0)]],
                          device float*       out [[buffer(1)]],
                          uint                gid [[thread_position_in_grid]])
{
    float x = in[gid];
    float r = sqrt(x);
    r = sin(r) + cos(r);
    r = fma(r, x, 1.0);
    r = clamp(r, 0.0, 1.0);
    r = mix(x, r, 0.25);
    r = rsqrt(r + 1.0);
    out[gid] = r;
}
