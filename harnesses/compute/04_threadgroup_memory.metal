// Feature: threadgroup address space and barriers.
// Demonstrates: [[threadgroup(n)]] arguments and function-local threadgroup
// arrays (addrspace(3)), plus threadgroup_barrier lowering to an AIR barrier
// intrinsic with mem_flags. A simple parallel reduction shows the pattern.
#include <metal_stdlib>
using namespace metal;

kernel void reduce(device const float* in  [[buffer(0)]],
                   device float*       out [[buffer(1)]],
                   threadgroup float*  scratch [[threadgroup(0)]],
                   uint gid  [[thread_position_in_grid]],
                   uint lid  [[thread_index_in_threadgroup]],
                   uint tgsz [[threads_per_threadgroup]],
                   uint tgid [[threadgroup_position_in_grid]])
{
    scratch[lid] = in[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tgsz / 2; stride > 0; stride >>= 1) {
        if (lid < stride)
            scratch[lid] += scratch[lid + stride];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (lid == 0)
        out[tgid] = scratch[0];
}
