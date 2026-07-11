// Feature: baseline compute kernel.
// Demonstrates: device address space buffers, [[buffer(n)]] argument binding,
// [[thread_position_in_grid]], a single load/add/store. This is the reference
// point every other compute harness is a delta against.
#include <metal_stdlib>
using namespace metal;

kernel void add(device const float* a   [[buffer(0)]],
                device const float* b   [[buffer(1)]],
                device float*       out [[buffer(2)]],
                uint                gid [[thread_position_in_grid]])
{
    out[gid] = a[gid] + b[gid];
}
