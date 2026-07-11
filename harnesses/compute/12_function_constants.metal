// Feature: function constants (specialization constants).
// Demonstrates: [[function_constant(n)]] values and the is_function_constant_defined()
// query. In AIR these become !air.func_constant metadata plus branches on the
// constant; the value is not resolved until pipeline specialization time.
#include <metal_stdlib>
using namespace metal;

constant bool  useBias        [[function_constant(0)]];
constant float defaultBias    [[function_constant(1)]];
constant int   mode           [[function_constant(2)]];
// Derived constant: evaluated at specialization time, not runtime.
constant bool  biasIsProvided = is_function_constant_defined(defaultBias);

kernel void specialized(device const float* in  [[buffer(0)]],
                        device float*       out [[buffer(1)]],
                        uint                gid [[thread_position_in_grid]])
{
    float v = in[gid];

    if (useBias) {
        v += biasIsProvided ? defaultBias : 1.0;
    }

    switch (mode) {              // `mode` is a specialization constant
        case 0:  v = v * v;   break;
        case 1:  v = sqrt(v); break;
        default: break;
    }

    out[gid] = v;
}
