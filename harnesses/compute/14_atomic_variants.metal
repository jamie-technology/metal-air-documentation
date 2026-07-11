// Feature: atomic operation coverage — signedness, address space, and ordering.
// Exists to resolve open questions from docs/03: the .s vs .u intrinsic suffix
// (via signed/unsigned min), the device vs threadgroup scope operand, the full
// set of op names (or/and/xor/min/max/exchange/store/load), and which
// memory_order values MSL actually accepts.
#include <metal_stdlib>
using namespace metal;

kernel void atomic_variants(device atomic_int*        sdev [[buffer(0)]],
                            device atomic_uint*       udev [[buffer(1)]],
                            threadgroup atomic_uint*  utg  [[threadgroup(0)]],
                            device const int*         in   [[buffer(2)]],
                            device int*               out  [[buffer(3)]],
                            uint gid [[thread_position_in_grid]])
{
    int  s = in[gid];
    uint u = uint(s);

    // Signedness: min on a signed vs unsigned atomic should pick .s vs .u.
    atomic_fetch_min_explicit(sdev, s, memory_order_relaxed);   // signed
    atomic_fetch_max_explicit(udev, u, memory_order_relaxed);   // unsigned

    // Op-name coverage on the device unsigned atomic.
    atomic_fetch_or_explicit (udev, u, memory_order_relaxed);
    atomic_fetch_and_explicit(udev, u, memory_order_relaxed);
    atomic_fetch_xor_explicit(udev, u, memory_order_relaxed);
    atomic_fetch_sub_explicit(udev, u, memory_order_relaxed);
    atomic_exchange_explicit (udev, u, memory_order_relaxed);

    // Address-space contrast: same op on threadgroup memory.
    atomic_fetch_add_explicit(utg, u, memory_order_relaxed);

    // Load / store.
    atomic_store_explicit(udev, u, memory_order_relaxed);
    out[gid] = atomic_load_explicit(sdev, memory_order_relaxed);
}
