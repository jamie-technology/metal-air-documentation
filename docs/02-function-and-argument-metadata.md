# Function & argument metadata

The IR body of an entry point says *what it computes*; the `air.*` metadata says
*how the runtime binds and invokes it*. This page decodes that metadata for each
shader stage.

## The entry-point node

Each stage root points at one node per entry point. A compute example, from
[`00_minimal_add`](../harnesses/compute/00_minimal_add.metal):

```llvm
!air.kernel = !{!9}
!9  = !{ void (float addrspace(1)*, …, i32)* @add, !10, !11 }
!10 = !{}                       ; per-function attributes (empty here)
!11 = !{ !12, !13, !14, !15 }   ; one node per argument, in order
```

So node `!9` is a 3-tuple: **the function**, a **function-level metadata node**,
and the **argument list** `!11`. The argument list has exactly one entry per IR
parameter, in declaration order.

## Anatomy of an argument node

Argument nodes are flat lists of *key, then value(s)* — the key is a string like
`!"air.buffer"` and the following operands are its payload up to the next key.
The first operand is always the zero-based argument index.

### Buffers

```llvm
!12 = !{ i32 0, !"air.buffer",
         !"air.location_index", i32 0, i32 1,
         !"air.read",
         !"air.address_space", i32 1,
         !"air.arg_type_size", i32 4,
         !"air.arg_type_align_size", i32 4,
         !"air.arg_type_name", !"float",
         !"air.arg_name", !"a" }
```

| Key | Meaning |
| --- | --- |
| `i32 0` (leading) | argument index 0 |
| `air.buffer` | this argument is a buffer binding |
| `air.location_index, 0, 1` | binds at buffer index **0**; the trailing `1` is the slot count *(observed)* |
| `air.read` | access qualifier — `air.read`, `air.write`, or `air.read_write` |
| `air.address_space, 1` | `addrspace(1)` = `device` (see [address spaces](01-address-spaces.md)) |
| `air.arg_type_size, 4` | element size in bytes (`sizeof(float)`) |
| `air.arg_type_align_size, 4` | element alignment in bytes |
| `air.arg_type_name, "float"` | the pointee type, as written |
| `air.arg_name, "a"` | the source parameter name |

The access qualifier is derived from `const` and use: `out` in the same kernel
is `device float*` and shows `air.read_write`, while the two `const` inputs show
`air.read`.

### Built-in position arguments

Thread/grid indices are not buffers; they get a single-key node naming the
attribute:

```llvm
!15 = !{ i32 3, !"air.thread_position_in_grid",
         !"air.arg_type_name", !"uint", !"air.arg_name", !"gid" }
```

The full family (from
[`03_thread_index_attributes`](../harnesses/compute/03_thread_index_attributes.metal)
and [`04_threadgroup_memory`](../harnesses/compute/04_threadgroup_memory.metal))
uses the same shape: `air.thread_position_in_threadgroup`,
`air.threadgroup_position_in_grid`, `air.thread_index_in_threadgroup`,
`air.threads_per_threadgroup`, `air.threadgroups_per_grid`, and so on — the key
is the attribute name with the `[[ ]]` stripped.

### Textures and samplers

From [`07_texture_read_write`](../harnesses/compute/07_texture_read_write.metal):

```llvm
!12 = !{ i32 0, !"air.texture", !"air.location_index", i32 0, i32 1,
         !"air.read",  !"air.arg_type_name", !"texture2d<float, read>",  !"air.arg_name", !"src" }
!13 = !{ i32 1, !"air.texture", !"air.location_index", i32 1, i32 1,
         !"air.write", !"air.arg_type_name", !"texture2d<float, write>", !"air.arg_name", !"dst" }
```

Textures carry their own binding namespace (`air.location_index` here is a
texture slot, not a buffer slot) and the access qualifier that was part of the
MSL type. Samplers appear as `air.sampler` nodes and bind in the sampler
namespace.

## Vertex and fragment stages

Vertex and fragment entry points use `!air.vertex` / `!air.fragment` but the
same node shape. What differs is the *kinds* of argument node. From
[`00_passthrough`](../harnesses/graphics/00_passthrough.metal):

```llvm
!air.vertex = !{!9}
!air.fragment = !{!16}

; vertex [[stage_in]] members -> air.vertex_input, one per [[attribute(n)]]
!14 = !{ i32 0, !"air.vertex_input", !"air.location_index", i32 0, i32 1,
         !"air.arg_type_name", !"float3", !"air.arg_name", !"position" }
!15 = !{ i32 1, !"air.vertex_input", !"air.location_index", i32 1, i32 1,
         !"air.arg_type_name", !"float4", !"air.arg_name", !"color" }

; the [[position]] output
!11 = !{ !"air.position", !"air.arg_type_name", !"float4", !"air.arg_name", !"position" }

; a fragment reading that varying: note the interpolation qualifiers
!20 = !{ i32 0, !"air.position", !"air.center", !"air.no_perspective",
         !"air.arg_type_name", !"float4", !"air.arg_name", !"position", !"air.arg_unused" }

; fragment output
!18 = !{ !"air.render_target", i32 0, i32 0, !"air.arg_type_name", !"float4" }
```

Things worth noting:

- **`air.vertex_input`** describes a `[[stage_in]]` attribute pulled from a
  vertex buffer; `air.location_index` is the `[[attribute(n)]]` number.
- **`air.position`** appears twice with different roles — as a vertex *output*
  and as a fragment *input* — and the fragment side records the interpolation
  mode (`air.center`, `air.no_perspective`). See
  [`03_interpolation_qualifiers`](../harnesses/graphics/03_interpolation_qualifiers.metal)
  for `air.flat` and friends.
- **`air.render_target`** with its color index is the fragment `[[color(0)]]`
  output.
- **`air.arg_unused`** marks a varying the fragment stage receives in its
  signature but never reads.

## Mesh-pipeline stages

The mesh harness
([`05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal)) adds two roots
and two argument kinds unique to it:

```llvm
!air.object = !{!9}
!air.mesh   = !{!17}

; the mesh output object
!19 = !{ i32 0, !"air.mesh", …, !"air.arg_type_name",
         !"mesh<VertexOut, PrimOut, 3, 1, triangle>", !"air.arg_name", !"output" }

; the grid-size setter passed to the object stage (lives in threadgroup memory)
!14 = !{ i32 1, !"air.mesh_grid_properties",
         !"air.arg_type_name", !"mesh_grid_properties", !"air.arg_name", !"grid" }
```

The object/mesh payload argument is an `object_data` pointer
(`addrspace(6)`) and is described like any other buffer-shaped argument; the
distinctive nodes are `air.mesh` (the output handle) and
`air.mesh_grid_properties` (the object stage's grid control).

## Summary of argument kinds

| Node key | Bound as | Seen in |
| --- | --- | --- |
| `air.buffer` | a buffer slot | every compute harness |
| `air.indirect_buffer` | an argument buffer (nested resources) | [`11_argument_buffers`](../harnesses/compute/11_argument_buffers.metal) |
| `air.texture` | a texture slot | [`07_texture_read_write`](../harnesses/compute/07_texture_read_write.metal) |
| `air.sampler` | a sampler slot | [`02_texture_sample`](../harnesses/graphics/02_texture_sample.metal) |
| `air.*_in_*` / `air.*_per_*` | a built-in thread/grid value | [`03_thread_index_attributes`](../harnesses/compute/03_thread_index_attributes.metal) |
| `air.vertex_input` | a `[[stage_in]]` vertex attribute | [`00_passthrough`](../harnesses/graphics/00_passthrough.metal) |
| `air.position` | clip-space position (out) / fragment position (in) | [`00_passthrough`](../harnesses/graphics/00_passthrough.metal) |
| `air.render_target` | a fragment color output | [`00_passthrough`](../harnesses/graphics/00_passthrough.metal) |
| `air.mesh` / `air.mesh_grid_properties` | mesh output / grid control | [`05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal) |
