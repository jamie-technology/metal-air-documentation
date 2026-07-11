// Feature: Metal 4 `tensor` type (element access).
// Demonstrates: a `tensor<device float, dextents<int,2>>` bound as a kernel
// argument, multi-dimensional subscript (C++23 `t[x, y]`), and the AIR that
// backs it — an opaque `%struct._tensor_t` handle, `air.tensor` argument
// metadata, and `air.get_data_pointer_typed_*_tensor` address computation.
// STD: metal4.0
#include <metal_stdlib>
using namespace metal;

kernel void tensor_scale(tensor<device float, dextents<int, 2>> in  [[buffer(0)]],
                         tensor<device float, dextents<int, 2>> out [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]])
{
    int x = int(gid.x);
    int y = int(gid.y);
    out[x, y] = in[x, y] * 2.0f;
}
