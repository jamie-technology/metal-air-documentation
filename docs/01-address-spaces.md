# Address spaces

Every pointer in AIR carries an `addrspace(N)` tag. `N` is a small integer that
encodes the MSL address space, and it drives both the memory the backend targets
and the alias/optimization facts LLVM may assume. This page maps the numbers to
MSL, grounded in what the harness set emits.

## The numbering

| `addrspace` | MSL address space | Where it comes from                                  | Harness |
| ----------- | ----------------- | ---------------------------------------------------- | ------- |
| `0`         | `thread` (private) | function-local variables; the default, usually implicit | (everywhere) |
| `1`         | `device`          | `device` buffers, read/write resources               | [`00_minimal_add`](../harnesses/compute/00_minimal_add.metal) |
| `2`         | `constant`        | `constant` buffers **and** sampler handles           | [`06_constant_address_space`](../harnesses/compute/06_constant_address_space.metal) |
| `3`         | `threadgroup`     | `[[threadgroup(n)]]` args and local threadgroup arrays | [`04_threadgroup_memory`](../harnesses/compute/04_threadgroup_memory.metal) |
| `4`         | imageblock / tile | `imageblock<>` tile-memory data                       | [`07_imageblock_tile`](../harnesses/graphics/07_imageblock_tile.metal) |
| `5`         | `ray_data`        | intersection-function payload (`[[payload]]`)         | [`13_raytracing`](../harnesses/compute/13_raytracing.metal) |
| `6`         | `object_data`     | the mesh-pipeline payload shared object→mesh          | [`05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal) |
| `7`         | mesh output       | the `metal::mesh<>` output handle                     | [`05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal) |

*(Numbers 0/1/2/3 are stable Metal conventions; 4–7 are observed from the
imageblock, raytracing, and mesh harnesses. The full set 0–7 is now exercised.)*

## `device` — `addrspace(1)`

The workhorse. A `device const float*` argument becomes:

```llvm
float addrspace(1)* nocapture noundef readonly "air-buffer-no-alias" %0
```

`device` is the only space that is both large and read-write, so it is where
general input/output buffers and read-write textures live. `const` on the MSL
side becomes `readonly` on the pointer.

## `constant` — `addrspace(2)`

`constant` is for small, uniform, read-only data. From
[`06_constant_address_space`](../harnesses/compute/06_constant_address_space.metal),
a `constant Params&` argument:

```llvm
%struct.Params addrspace(2)* nocapture noundef readonly align 16 dereferenceable(32) "air-buffer-no-alias" %2
```

Field reads lower to a `getelementptr` on that `addrspace(2)` pointer. The
`dereferenceable(32)` reflects `sizeof(Params)`.

**Samplers also live in `addrspace(2)`.** A sampler handle is modelled as a
pointer into constant memory:

```llvm
declare %struct._sampler_t addrspace(2)* @air.get_read_sampler() …
```

## `threadgroup` — `addrspace(3)`

Threadgroup memory is shared within a threadgroup and is the target of
`threadgroup_barrier`. Both an explicit `[[threadgroup(0)]]` argument and a
function-scope `threadgroup` array land here. From
[`04_threadgroup_memory`](../harnesses/compute/04_threadgroup_memory.metal):

```llvm
define void @reduce(float addrspace(1)* … %0,      ; device in
                    float addrspace(1)* … %1,      ; device out
                    float addrspace(3)* … %2, …)   ; threadgroup scratch
  …
  store float %10, float addrspace(3)* %12, align 4
```

## imageblock / tile memory — `addrspace(4)`

Tile shading keeps per-pixel data in on-chip tile memory. An `imageblock<>`
argument is modelled as a wrapper struct holding an opaque handle into
`addrspace(4)`. From
[`07_imageblock_tile`](../harnesses/graphics/07_imageblock_tile.metal):

```llvm
%"struct.metal::_imageblock_base" = type { %struct._imageblock_t addrspace(4)* }
%struct._imageblock_t = type opaque

define void @tile_resolve(%"struct.metal::_imageblock_base" %0, …)
```

The handle is opaque — reads and writes go through `air.*` imageblock
intrinsics rather than raw loads/stores, similar to textures.

## `ray_data` — `addrspace(5)`

The payload passed into a custom intersection function lives in `ray_data`. It
is writeonly from the intersection function's side (it hands results back to the
traversal). From [`13_raytracing`](../harnesses/compute/13_raytracing.metal):

```llvm
define i1 @alpha_test(%struct.Payload addrspace(5)* nocapture noundef writeonly
                      align 16 dereferenceable(32) %0, …)
  …
  store float %1, float addrspace(5)* %5, align 16
```

Note the intersection function is a normal `i1`-returning function (it returns
whether to accept the hit); only the payload pointer is special. The
acceleration structure and `intersector<>` traversal in the *calling* kernel use
ordinary `addrspace(1)`/opaque handles, not `ray_data`.

## `object_data` — `addrspace(6)`

The object→mesh **payload** in a mesh pipeline. The object stage receives it
`writeonly`, the mesh stage `readonly`. From
[`05_mesh_shader`](../harnesses/graphics/05_mesh_shader.metal):

```llvm
define void @obj_main(%struct.Payload addrspace(6)* … writeonly … %0, …)   ; produces
define void @mesh_main(%struct._mesh_t addrspace(7)* %0,
                       %struct.Payload addrspace(6)* … readonly … %1, …)   ; consumes
```

The matched `writeonly`/`readonly` on the same `addrspace(6)` type is exactly
the payload hand-off between the two mesh-pipeline stages.

## Mesh output — `addrspace(7)`

The `metal::mesh<...>` output object is an opaque handle in `addrspace(7)`:

```llvm
%struct._mesh_t addrspace(7)* %0
```

Writes to it do not go through normal loads/stores; they lower to
`air.set_vertex_data_mesh`, `air.set_primitive_data_mesh`,
`air.set_primitive_count_mesh`, etc., each taking the `addrspace(7)` handle.

## Why the tag matters

Beyond selecting physical memory, the address space is load-bearing for
optimization. A `constant` (`addrspace(2)`) pointer is known-invariant, so the
optimizer can hoist and CSE loads freely; a `device` (`addrspace(1)`) pointer
can alias other device buffers unless `"air-buffer-no-alias"` says otherwise.
This is why the same C++-level code can optimize very differently depending only
on the address space of its inputs.
