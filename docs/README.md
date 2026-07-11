# AIR documentation

The missing documentation for Apple's AIR (Apple Intermediate Representation) —
the format the Metal compiler front-end emits before GPU-specific backends turn
it into machine code.

Every claim here is grounded in AIR generated from a harness under
[`../harnesses/`](../harnesses/). Regenerate it with `harnesses/generate.sh` and
read the `.ll` files alongside these pages. Snippets are quoted verbatim from
that output; the toolchain version they came from is recorded in each module's
`!llvm.ident` (see [the overview](00-air-overview.md)).

## Pages

1. [AIR overview](00-air-overview.md) — what AIR is, the toolchain, and the
   anatomy of a module (target triple, data layout, module flags, the `air.*`
   named-metadata roots).
2. [Address spaces](01-address-spaces.md) — the `addrspace(N)` numbering and
   what maps to `device`, `constant`, `threadgroup`, `object_data`, and mesh
   output.
3. [Function & argument metadata](02-function-and-argument-metadata.md) — how
   entry points (`!air.kernel`, `!air.vertex`, `!air.fragment`, `!air.object`,
   `!air.mesh`) and their arguments are described.

### Feature pages (keyed to harnesses)

4. [Atomics & memory ordering](03-atomics-and-memory-ordering.md) —
   `air.atomic.*` intrinsics, order/scope operands.
5. [SIMD-group operations](04-simd-group-operations.md) — `air.simd_*` /
   `air.quad_*` reductions, shuffles, ballots.
6. [Textures & samplers](05-textures-and-samplers.md) — opaque handles and the
   `air.sample_/read_/write_texture_*` intrinsics.
7. [Function constants](06-function-constants.md) — specialization constants,
   `air.fc_initializer` globals, `!air.function_constants`.
8. [Control flow](07-control-flow.md) — br / phi / switch / select (plain LLVM).
9. [Argument buffers](09-argument-buffers.md) — `air.indirect_buffer` +
   `air.struct_type_info` member tables.
10. [Tessellation](10-tessellation.md) — factor kernel + post-tessellation
    vertex, `air.patch*`, synthesized control-point fetch.
11. [Mesh shaders](11-mesh-shaders.md) — object/mesh stages, payload &
    mesh-output address spaces, `air.set_*_mesh` intrinsics.
12. [Raytracing](14-raytracing.md) — acceleration structures, the
    `air.intersect.*` traversal tuple, `[[intersection]]` functions.
13. [Imageblocks & tile shading](15-imageblocks-and-tile-shading.md) — tile
    memory (addrspace 4), `air.*imageblock` intrinsics.
14. [Vertex amplification & barycentrics](16-amplification-and-barycentrics.md) —
    `air.amplification_*`, `air.barycentric_coord`, `air.primitive_id`.

### AI / matrix / tensor

15. [SIMD-group matrices](12-simdgroup-matrices.md) — `simdgroup_matrix<>` and
    the `air.simdgroup_matrix_8x8_*` matmul intrinsics.
16. [Tensors & tensor ops (Metal 4)](13-tensors-and-tensor-ops.md) — the
    `tensor` type, `air.tensor`, and MPP `matmul2d` as an
    `air.externally_defined` library call.

### For the Swift fork

17. [Emitting AIR: a backend guide](08-emitting-air-a-backend-guide.md) — what a
    non-Metal frontend must produce to get a loadable kernel, and the
    text→`metal-as`→`metallib` path that round-trips it.

## Conventions

- **Verbatim AIR** is shown in `llvm` code blocks, lightly trimmed (long
  attribute lists elided with `…`) but never reworded.
- **Metadata node numbers** (`!9`, `!12`) are per-module and unstable across
  compiler versions; treat them as intra-snippet references only.
- Facts observed from output but not confirmed against a spec are flagged with
  *(observed)*.
