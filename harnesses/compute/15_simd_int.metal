// Feature: integer SIMD-group reductions.
// Exists to confirm the exact intrinsic suffix for integer simd ops (open
// question from docs/04): does simd_sum over int/uint carry a signedness tag,
// and what element suffix is used.
#include <metal_stdlib>
using namespace metal;

kernel void simd_int(device const int*  in  [[buffer(0)]],
                     device int*         out [[buffer(1)]],
                     device uint*        umx [[buffer(2)]],
                     uint gid [[thread_position_in_grid]])
{
    int  s = in[gid];
    uint u = uint(s);

    int  sum  = simd_sum(s);        // integer reduction
    int  smin = simd_min(s);        // signed min
    uint umax = simd_max(u);        // unsigned max
    int  prod = simd_product(s);
    uint pref = simd_prefix_exclusive_sum(u);

    out[gid] = sum + smin + prod;
    umx[gid] = umax + pref;
}
