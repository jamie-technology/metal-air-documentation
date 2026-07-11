# Mesh shaders

Harness: [`graphics/05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal).

The mesh pipeline replaces the vertex stage with two programmable stages: an
**object** stage that dispatches work and emits a payload, and a **mesh** stage
that writes vertices and primitives directly into an output object. AIR gives
each its own named-metadata root (`!air.object`, `!air.mesh`), two dedicated
address spaces ([addr spaces](01-address-spaces.md): payload = `addrspace(6)`,
mesh output = `addrspace(7)`), and a family of `air.set_*_mesh` intrinsics.

## The object stage

```llvm
!air.object = !{!9}
!9 = !{ void (%struct.Payload addrspace(6)*, %struct._mesh_grid_properties_t addrspace(3)*, i32)* @obj_main,
        !10, !11, !16 }
```

Two special arguments:

```llvm
; the payload it produces (object_data, addrspace 6):
!12 = !{ i32 0, !"air.payload", !"air.struct_type_info", !13,
         !"air.arg_type_size", i32 16, …, !"air.arg_type_name", !"Payload" }
; the grid-size control (lives in threadgroup memory, addrspace 3):
!14 = !{ i32 1, !"air.mesh_grid_properties", !"air.arg_type_name", !"mesh_grid_properties", … }
```

`set_threadgroups_per_grid()` — how the object stage launches the mesh grid —
lowers to its own intrinsic on the grid-properties handle:

```llvm
tail call void @air.set_threadgroups_per_grid_mesh_properties(
    %struct._mesh_grid_properties_t addrspace(3)* %1, <3 x i32> <i32 1, i32 1, i32 1>)
```

## The mesh stage

```llvm
!air.mesh = !{!17}
!17 = !{ void (%struct._mesh_t addrspace(7)*, %struct.Payload addrspace(6)*, i32)* @mesh_main,
         !10, !18, !28 }
!19 = !{ i32 0, !"air.mesh", !20, !"air.arg_type_name", !"mesh<VertexOut, PrimOut, 3, 1, triangle>", … }
!20 = !{ !"air.mesh_type_info", !21, !24, i32 3, i32 1, !"air.triangle" }
!26 = !{ i32 1, !"air.payload", … }   ; the payload, now consumed (readonly)
```

`air.mesh_type_info` encodes the `metal::mesh<Vertex, Prim, MaxVerts,
MaxPrims, topology>` template arguments — here max 3 vertices, max 1 primitive,
`triangle` topology, plus references (`!21`, `!24`) to the per-vertex and
per-primitive output struct layouts.

### Writing the output

The mesh output object is opaque (`%struct._mesh_t addrspace(7)*`) and is written
exclusively through intrinsics:

```llvm
tail call void @air.set_primitive_count_mesh(%struct._mesh_t addrspace(7)* %0, i32 1)
tail call void @air.set_index_mesh(%struct._mesh_t addrspace(7)* %0, i32 0, i8 0)   ; index buffer
tail call void @air.set_primitive_data_mesh.v4f32(%struct._mesh_t addrspace(7)* %0, i32 0, i32 0, <4 x float> …)
tail call void @air.set_vertex_data_mesh.v4f32(%struct._mesh_t addrspace(7)* %0, i32 0, i32 %lane, <4 x float> …)
```

Note `air.set_index_mesh` takes an `i8` index value (small index type) and the
`set_*_data_mesh` intrinsics are type-suffixed per attribute. Each carries the
output slot/attribute index so the runtime can scatter into the right buffer.

## The fragment side

A mesh-pipeline fragment receives one `[[stage_in]]` struct that **nests** the
per-vertex and per-primitive outputs (see the harness's `FragmentIn`); this is
purely a source-level convention and lowers to the same fragment argument
metadata as any other stage.

## Implications for a Swift backend

Mesh shaders are the most metadata-heavy stage pair:

1. two entry roots (`!air.object`, `!air.mesh`) with the right argument kinds
   (`air.payload`, `air.mesh_grid_properties`, `air.mesh`);
2. the payload in `object_data` (`addrspace(6)`) — writeonly on the object side,
   readonly on the mesh side;
3. the mesh output as an opaque `addrspace(7)` handle written only via
   `air.set_{vertex,primitive,index,primitive_count}_mesh` intrinsics;
4. an `air.mesh_type_info` node capturing the `mesh<>` template parameters
   (vertex/primitive types, max counts, topology).

None of the *instructions* are exotic — it is again the metadata and intrinsic
contract that a backend must reproduce faithfully.
