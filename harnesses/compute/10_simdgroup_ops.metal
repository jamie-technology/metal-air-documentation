// Feature: SIMD-group (subgroup / warp) operations.
// Demonstrates: the air.simd_* and air.quad_* intrinsics behind reductions
// (simd_sum), shuffles (simd_shuffle, simd_shuffle_xor), broadcasts, ballots
// (simd_ballot -> a lane mask), and the [[thread_index_in_simdgroup]] /
// [[simdgroups_per_threadgroup]] built-ins.
#include <metal_stdlib>
using namespace metal;

kernel void simdgroup_ops(device const float* in   [[buffer(0)]],
                          device float*       out  [[buffer(1)]],
                          device uint*        masks [[buffer(2)]],
                          uint  gid  [[thread_position_in_grid]],
                          uint  lane [[thread_index_in_simdgroup]],
                          uint  sgid [[simdgroup_index_in_threadgroup]])
{
    float v = in[gid];

    float sum   = simd_sum(v);                 // full-subgroup reduction
    float xored = simd_shuffle_xor(v, 1u);     // butterfly exchange
    float first = simd_broadcast_first(v);     // lane 0 -> all lanes
    float shuf  = simd_shuffle(v, lane ^ 2u);  // arbitrary shuffle

    simd_vote ballot = simd_ballot(v > 0.0);   // predicate -> lane mask
    masks[sgid] = uint((simd_vote::vote_t)ballot);

    out[gid] = sum + xored + first + shuf;
}
