// Feature: hardware raytracing (compute) + intersection function.
// Demonstrates: acceleration_structure arguments, the `ray` type, an
// `intersector<>` traversal, and an [[intersection]] function whose payload
// lives in the `ray_data` address space. This harness exists to surface the
// address space numbers used by raytracing (see docs/01-address-spaces.md).
#include <metal_stdlib>
#include <metal_raytracing>
using namespace metal;
using namespace raytracing;

struct Payload {
    float4 color;
    float  hitT;
};

kernel void trace(instance_acceleration_structure accel [[buffer(0)]],
                  device const float3* origins [[buffer(1)]],
                  device const float3* dirs    [[buffer(2)]],
                  device float4*       out     [[buffer(3)]],
                  uint gid [[thread_position_in_grid]])
{
    ray r;
    r.origin       = origins[gid];
    r.direction    = dirs[gid];
    r.min_distance = 0.0f;
    r.max_distance = INFINITY;

    intersector<instancing, triangle_data> isect;
    intersection_result<instancing, triangle_data> result = isect.intersect(r, accel);

    if (result.type == intersection_type::triangle) {
        float2 bary = result.triangle_barycentric_coord;
        out[gid] = float4(bary, float(result.primitive_id), result.distance);
    } else {
        out[gid] = float4(0.0);
    }
}

// A custom intersection function: its payload is `ray_data`.
[[intersection(triangle, triangle_data)]]
bool alpha_test(ray_data Payload& payload      [[payload]],
                float             dist         [[distance]],
                uint              prim         [[primitive_id]],
                float2            bary         [[barycentric_coord]])
{
    payload.hitT  = dist;
    payload.color = float4(bary, float(prim), 1.0);
    return true; // accept the intersection
}
