# SIMD-group matrices

Harness: [`compute/16_simdgroup_matrix`](../harnesses/compute/16_simdgroup_matrix.metal).

`simdgroup_matrix<T, Cols, Rows>` is the older, lower-level matrix-multiply
primitive: a small (typically 8×8) matrix cooperatively held and multiplied by a
whole SIMD-group. It predates the Metal 4 [tensor ops](13-tensors-and-tensor-ops.md)
and is the right building block when you want to hand-write a tiled GEMM. It maps
to a tidy family of `air.simdgroup_matrix_*` intrinsics.

## The intrinsics

The four operations in the harness lower one-to-one:

```llvm
air.simdgroup_matrix_8x8_init_filled.v64f32.f32          ; make_filled_simdgroup_matrix<float,8,8>(0)
air.simdgroup_matrix_8x8_load.v64f32.p1f32               ; simdgroup_load(a, A, 8)
air.simdgroup_matrix_8x8_multiply_accumulate.v64f32.v64f32.v64f32.v64f32
air.simdgroup_matrix_8x8_store.v64f32.p1f32              ; simdgroup_store(c, C, 8)
```

Reading the suffixes:

- **`8x8`** — the matrix dimensions are baked into the symbol; a different size
  is a different intrinsic.
- **`v64f32`** — the storage type is a flat `<64 x float>` vector (8×8 = 64
  elements). A `simdgroup_matrix` is, at the IR level, just this vector held
  across the SIMD-group's registers.
- **`p1f32`** on load/store — the memory operand is a `float addrspace(1)*`
  (device pointer), plus an elements-per-row stride (`8`).
- `multiply_accumulate` takes four `v64f32` operands: `d = a*b + c`.

## Storage model

Because the matrix is a plain `<64 x float>` value (see the data layout's vector
alignment in the [overview](00-air-overview.md)), a `simdgroup_matrix` is passed
around like any other SSA value — there is no opaque handle and no special
address space. Only the *cooperative* semantics (the whole SIMD-group
participates) are implied by the intrinsic; the IR type is ordinary.

## Relationship to tensor ops

| | `simdgroup_matrix` | `matmul2d` ([tensor ops](13-tensors-and-tensor-ops.md)) |
| --- | --- | --- |
| Scope | one SIMD-group | multiple SIMD-groups (`execution_simdgroups<N>`) |
| Operand | in-register `<64 x float>` | `tensor<>` in memory, tiled/sliced |
| Lowering | inline `air.simdgroup_matrix_*` intrinsics | call to an externally-defined `__tensorops_impl_*` |
| Use when | you hand-roll the tiling | you want the library's tuned GEMM |

## Implications for a Swift backend

This is one of the more backend-friendly GPU features: expose a
`SIMDGroupMatrix<T, R, C>` value type backed by a `<R*C x T>` vector, and lower
its ops to the correspondingly-suffixed `air.simdgroup_matrix_<RxC>_*`
intrinsics. No metadata contract, no external linkage — just the right intrinsic
names and the flat-vector storage convention.
