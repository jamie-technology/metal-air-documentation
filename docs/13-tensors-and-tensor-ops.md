# Tensors & tensor ops (Metal 4)

Harnesses: [`compute/17_tensor_scale`](../harnesses/compute/17_tensor_scale.metal),
[`compute/18_tensor_matmul`](../harnesses/compute/18_tensor_matmul.metal).

Metal 4 adds a first-class `tensor` type and, on top of it, the
`MetalPerformancePrimitives` (**MPP**) tensor-ops library — cooperative matmul /
convolution designed for on-GPU ML. These are the "AI instructions" surface.
Both harnesses require `-std=metal4.0` (the toolchain gates the feature behind
`__HAVE_TENSOR__`); the harnesses pin it with a `// STD: metal4.0` directive that
[`generate.sh`](../harnesses/README.md) honours.

## The `tensor` type

A `tensor<device float, dextents<int, 2>>` argument is an **opaque handle** plus
a shape, bound like a buffer but with its own metadata kind:

```llvm
%struct._tensor_t = type opaque

!12 = !{ i32 0, !"air.tensor", !"air.location_index", i32 0, i32 1, !"air.read_write",
         !"air.address_space", i32 1,
         !"air.arg_type_name", !"tensor<float, dextents<int, 2>>", !"air.arg_name", !"in" }
```

`air.tensor` is a new argument kind alongside `air.buffer` / `air.texture` (see
[argument metadata](02-function-and-argument-metadata.md)). The element pointer
is not exposed directly; indexing computes an address through an intrinsic:

```llvm
; out[x, y] = in[x, y] * 2  (multi-dimensional C++23 subscript)
%… = call float addrspace(1)* @air.get_data_pointer_typed_global_tensor.s.i32.global(…)
```

`air.get_data_pointer_typed_global_tensor` turns tensor + integer coordinates
into a `device` element pointer; the `.s.i32.global` suffix encodes signed
`i32` indices into the `global`/device tensor. Bounds and strides live behind the
handle, so the frontend never bakes a layout.

## Tensor ops: `matmul2d`

The MPP matmul is where the interesting lowering happens. Source:

```cpp
matmul2d<desc, execution_simdgroups<4>> op;
auto mA = A.slice(0, tgid.y*64);          // per-threadgroup tile
op.run(mA, mB, mC);
```

`op.run()` does **not** inline a matmul. It lowers to a call to an
externally-defined library function:

```llvm
declare void @__tensorops_impl_matmul2d_op_run_dv_f16_dv_f16_dv_f32(
    %"struct.mpp::tensor_ops::matmul2d_descriptor"*,  ; the descriptor (by value, 20 bytes)
    i8*, i32,   ; operand A: type-erased handle + address-space tag (1 = device)
    i8*, i32,   ; operand B
    i8*, i32,   ; operand C
    i32)        ; simdgroup size (from air.get_simdgroup_size)
    section "air.externally_defined"
```

Three things a backend author must internalise:

1. **The math is not in your module.** The actual matmul (which drives the
   matrix hardware) lives in a precompiled MPP AIR library that is linked in.
   Your kernel only emits the *call*. This is the `section
   "air.externally_defined"` marker — an unresolved symbol the linker/pipeline
   satisfies from MPP.
2. **Tensor operands are type-erased at the ABI boundary.** Each `tensor<>` is
   passed as `i8*` (the handle, bit-cast) plus an `i32` address-space tag, not as
   a typed pointer. The element types survive only in the mangled function name
   (`dv_f16_dv_f16_dv_f32` = device half, device half, device float).
3. **The descriptor is a value.** `matmul2d_descriptor(64, 32, dynamic_extent,
   …)` becomes a 20-byte constant (template-instantiated as
   `@_ZTA…matmul2d_descriptor…`) that is `memcpy`'d to the stack and passed by
   pointer.

The `execution_simdgroups<4>` scope shows up as the `air.get_simdgroup_size`
query feeding the call — the op needs to know how many lanes cooperate.

## Implications for a Swift backend

Tensors split cleanly into two jobs:

- **The `tensor` type** — introduce an opaque tensor handle, emit `air.tensor`
  argument metadata, and lower indexing to
  `air.get_data_pointer_typed_*_tensor`. This is comparable in effort to
  supporting textures.
- **Tensor ops (matmul/conv)** — you do *not* codegen the kernels. You reproduce
  the MPP ABI: build the descriptor constant, type-erase the operands to `i8* +
  i32`, and emit an `air.externally_defined` call to the correctly-mangled
  `__tensorops_impl_*` symbol, then link against the MPP library. Effectively the
  Swift frontend is a *caller* of MPP, exactly as MSL is.

This externally-defined-call pattern is the model for any "heavy" Apple GPU
library primitive, and is worth supporting generically rather than per-op.
