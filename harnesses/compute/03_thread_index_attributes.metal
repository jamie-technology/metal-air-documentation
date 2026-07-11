// Feature: thread/grid indexing attributes.
// Demonstrates: the family of built-in position attributes and the intrinsics
// they lower to — thread_position_in_grid, thread_position_in_threadgroup,
// threadgroup_position_in_grid, thread_index_in_threadgroup,
// threads_per_threadgroup, and threadgroups_per_grid.
#include <metal_stdlib>
using namespace metal;

kernel void thread_indices(device uint* out [[buffer(0)]],
                           uint3 tpig  [[thread_position_in_grid]],
                           uint3 tpitg [[thread_position_in_threadgroup]],
                           uint3 tgpig [[threadgroup_position_in_grid]],
                           uint  tiitg [[thread_index_in_threadgroup]],
                           uint3 tptg  [[threads_per_threadgroup]],
                           uint3 tgpg  [[threadgroups_per_grid]])
{
    uint linear = tpig.x + tpig.y * tptg.x;
    out[linear] = tpitg.x + tgpig.x + tiitg + tgpg.x;
}
