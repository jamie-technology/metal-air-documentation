// Feature: baseline vertex + fragment pair.
// Demonstrates: [[stage_in]] vertex input struct with [[attribute(n)]], the
// [[position]] output, a rasterizer-interpolated varying, and a fragment
// shader returning a [[color(0)]]. Reference point for all graphics harnesses.
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vmain(VertexIn in [[stage_in]])
{
    VertexOut out;
    out.position = float4(in.position, 1.0);
    out.color    = in.color;
    return out;
}

fragment float4 fmain(VertexOut in [[stage_in]])
{
    return in.color;
}
