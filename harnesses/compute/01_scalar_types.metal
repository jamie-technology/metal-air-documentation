// Feature: scalar type lowering.
// Demonstrates: how bool, char, uchar, short, ushort, int, uint, half, float
// map to AIR/LLVM types (i1/i8/i16/i32, half/float), the address-space
// annotations on each buffer, and how sub-word integers are widened.
#include <metal_stdlib>
using namespace metal;

kernel void scalar_types(device const char*   i8   [[buffer(0)]],
                         device const short*  i16  [[buffer(1)]],
                         device const int*    i32  [[buffer(2)]],
                         device const half*   f16  [[buffer(3)]],
                         device const float*  f32  [[buffer(4)]],
                         device int*          oi   [[buffer(5)]],
                         device half*         oh   [[buffer(6)]],
                         device float*        of   [[buffer(7)]],
                         uint                 gid  [[thread_position_in_grid]])
{
    oi[gid] = int(i8[gid]) + int(i16[gid]) + i32[gid];
    oh[gid] = f16[gid] * half(2.0);
    of[gid] = f32[gid] + float(f16[gid]);
}
