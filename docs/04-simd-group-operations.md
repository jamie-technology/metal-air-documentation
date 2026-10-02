# SIMD-group operations

Harnesses: [`compute/10_simdgroup_ops`](../harnesses/compute/10_simdgroup_ops.metal),
[`compute/15_simd_int`](../harnesses/compute/15_simd_int.metal).

A SIMD-group (a.k.a. subgroup / warp / quad) is the set of threads that execute
in lockstep on one execution unit. MSL's `simd_*` and `quad_*` functions lower
directly to `air.simd_*` / `air.quad_*` intrinsics — one intrinsic per
operation, type-suffixed like everything else in AIR.

## Reductions, shuffles, broadcasts

```llvm
%10 = tail call fast float @air.simd_sum.f32(float %9)
%11 = tail call fast float @air.simd_shuffle_xor.f32(float %9, i16 1)
%12 = tail call fast float @air.simd_broadcast_first.f32(float %9)
%15 = tail call fast float @air.simd_shuffle.f32(float %9, i16 %14)
```

Observations for a backend:

- **Lane indices are `i16`**, not `i32` — `simd_shuffle(v, lane)` truncates the
  lane argument to `i16`.
- The value type is the intrinsic suffix (`.f32`); each element type gets a
  distinct symbol. Integer variants confirm the pattern (from
  [`15_simd_int`](../harnesses/compute/15_simd_int.metal)) — and, like atomics,
  they carry a signedness tag where it matters:

  ```llvm
  air.simd_sum.s.i32                  ; simd_sum(int)
  air.simd_product.s.i32              ; simd_product(int)
  air.simd_min.s.i32                  ; simd_min(int)   -> signed
  air.simd_max.u.i32                  ; simd_max(uint)  -> unsigned
  air.simd_prefix_exclusive_sum.u.i32 ; scan
  ```

  So the full grammar is `air.simd_<op>[.<sign>].<type>`, with the `.s`/`.u` tag
  present on integer ops (note `simd_sum`/`simd_product` do carry `.s` for a
  signed input, unlike the additive *atomics*, which do not).
- The `fast` flag rides along because the module is compiled with fast-math.

## Ballots and votes

`simd_ballot(predicate)` returns a lane mask:

```llvm
%17 = tail call i64 @air.simd_ballot.i64(i1 %16)
```

The predicate is an `i1`; the result is an `i64` bitmask (one bit per lane). MSL
wraps this in the `simd_vote` type, but at the AIR level it is just the `i64`.

## Built-in SIMD position values

The subgroup analogues of the thread/threadgroup indices are ordinary built-in
arguments (see [function & argument metadata](02-function-and-argument-metadata.md)):

```llvm
!… = !{ i32 …, !"air.simdgroup_index_in_threadgroup", … }
```

`[[thread_index_in_simdgroup]]` (the lane id) and
`[[simdgroup_index_in_threadgroup]]` come in as scalar `i32` parameters with
their own single-key metadata nodes, exactly like `[[thread_position_in_grid]]`.

## Quad operations

`quad_*` variants (operating over 2×2 quads, available in fragment shaders too)
follow the identical pattern under the `air.quad_*` prefix. They are not
exercised by the current harness but share the shape documented here.

## Implications for a Swift backend

These are the easiest GPU-specific ops to emit: pick the right
`air.simd_<op>.<type>` name, match the `i16` lane-argument convention, and emit
a normal call. There is no metadata contract beyond the intrinsic declaration
itself.

One caveat found the hard way: the ops require a **fully typed-pointer** module.
A device-buffer kernel assembled with opaque pointers (`ptr addrspace(1)`) loads
fine on the AGX driver — until it contains an `air.simd_*` call, at which point
pipeline creation fails with `AGXMetalG13X Code=3 "Failed to upgrade function
bitcode"`. The real `metal` compiler's output for these is fully typed
(`float addrspace(1)*`), and typing the kernel's pointers makes it load. So a
backend that emits opaque pointers elsewhere must switch to typed pointers for
any module that uses the SIMD-group (or `air.simdgroup_matrix_*`) intrinsics.
