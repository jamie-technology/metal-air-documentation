// Feature: control flow lowering.
// Demonstrates: if/else, a bounded for loop, a switch, and how the optimizer
// forms basic blocks, phi nodes, and select instructions in AIR. Useful for
// documenting how divergent control flow is represented before GPU lowering.
#include <metal_stdlib>
using namespace metal;

kernel void control_flow(device const int* in  [[buffer(0)]],
                         device int*       out [[buffer(1)]],
                         constant uint&    n   [[buffer(2)]],
                         uint              gid [[thread_position_in_grid]])
{
    int v = in[gid];
    int acc = 0;

    if (v < 0) {
        acc = -v;                 // branch -> phi
    } else {
        for (uint i = 0; i < n; ++i)
            acc += int(i);        // loop with induction var
    }

    switch (v & 3) {              // switch table
        case 0:  acc += 1;  break;
        case 1:  acc += 10; break;
        case 2:  acc += 100; break;
        default: acc -= 1;  break;
    }

    out[gid] = acc;
}
