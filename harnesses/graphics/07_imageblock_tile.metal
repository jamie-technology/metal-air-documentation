// Feature: tile shading / imageblocks.
// Demonstrates: an imageblock<> argument to a tile (kernel) function, which
// lives in tile memory. This harness exists to surface the address space used
// for imageblock/tile data (candidate for addrspace(4); see
// docs/01-address-spaces.md).
#include <metal_stdlib>
using namespace metal;

struct FragValues {
    half4 color [[color(0)]];
};

// A tile function (kernel dispatched over an imageblock tile) that reads the
// per-pixel imageblock and writes a resolved average out to a device buffer.
kernel void tile_resolve(imageblock<FragValues, imageblock_layout_implicit> ib,
                         device half4* out [[buffer(0)]],
                         ushort2 lid  [[thread_position_in_threadgroup]],
                         ushort2 tgs  [[threads_per_threadgroup]],
                         uint2   gid  [[thread_position_in_grid]])
{
    FragValues f = ib.read(lid);
    out[gid.y * 64 + gid.x] = f.color;
}
