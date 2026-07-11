// Feature: atomic operations.
// Demonstrates: atomic_uint / atomic_int in device and threadgroup space, and
// how atomic_fetch_add / atomic_store / atomic_compare_exchange lower to AIR
// atomic intrinsics with memory_order arguments.
#include <metal_stdlib>
using namespace metal;

kernel void atomics(device atomic_uint*      counter [[buffer(0)]],
                    device const uint*       in      [[buffer(1)]],
                    device atomic_int*       accum   [[buffer(2)]],
                    uint                     gid     [[thread_position_in_grid]])
{
    uint v = in[gid];
    atomic_fetch_add_explicit(counter, v, memory_order_relaxed);

    int expected = 0;
    atomic_compare_exchange_weak_explicit(
        accum, &expected, int(v),
        memory_order_relaxed, memory_order_relaxed);
}
