// Feature: mesh shader pipeline (object + mesh stages).
// Demonstrates: an [[object]] function that emits a payload and sets the mesh
// grid size via mesh_grid_properties, and a [[mesh]] function that writes
// vertices and primitives into a metal::mesh<> output. In AIR these carry
// !air.object / !air.mesh function metadata plus the payload/threadgroup
// binding info. Requires Metal 3 (metal3.0+).
#include <metal_stdlib>
#include <metal_mesh>
using namespace metal;

struct Payload {
    float4 offset;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct PrimOut {
    float4 flatColor [[flat]];
};

// One triangle per mesh threadgroup.
using TriMesh = metal::mesh<VertexOut, PrimOut, 3, 1, metal::topology::triangle>;

[[object, max_total_threads_per_threadgroup(1)]]
void obj_main(object_data Payload&    payload [[payload]],
              mesh_grid_properties    grid,
              uint                    tgid    [[threadgroup_position_in_grid]])
{
    payload.offset = float4(float(tgid), 0.0, 0.0, 0.0);
    grid.set_threadgroups_per_grid(uint3(1, 1, 1));
}

[[mesh, max_total_threads_per_threadgroup(3)]]
void mesh_main(TriMesh                    output,
               const object_data Payload& payload [[payload]],
               uint                       lid     [[thread_index_in_threadgroup]])
{
    if (lid == 0) {
        output.set_primitive_count(1);
        output.set_index(0, 0);
        output.set_index(1, 1);
        output.set_index(2, 2);

        PrimOut prim;
        prim.flatColor = float4(1.0, 0.5, 0.0, 1.0);
        output.set_primitive(0, prim);
    }

    const float2 verts[3] = { float2(0, 1), float2(-1, -1), float2(1, -1) };
    VertexOut v;
    v.position = float4(verts[lid], 0.0, 1.0) + payload.offset;
    v.color    = float4(verts[lid] * 0.5 + 0.5, 0.0, 1.0);
    output.set_vertex(lid, v);
}

// A mesh-pipeline fragment receives a single stage_in that nests the per-vertex
// (interpolated) and per-primitive (flat) outputs.
struct FragmentIn {
    VertexOut v;
    PrimOut   p;
};

fragment float4 mesh_frag(FragmentIn in [[stage_in]])
{
    return in.v.color * in.p.flatColor;
}
