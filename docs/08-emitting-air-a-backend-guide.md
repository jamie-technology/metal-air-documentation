# Emitting AIR: a backend guide

This page is written for the project's end goal — **making a Swift frontend emit
AIR** — rather than for reading Metal's output. It distills the rest of the docs
into "what a non-Metal compiler must produce to get a loadable GPU kernel," and
shows that the textual-IR path round-trips all the way to a `.metallib`.

Everything here is verified against the minimal harness
[`compute/00_minimal_add`](../harnesses/compute/00_minimal_add.metal).

## The pipeline you're targeting

```
your frontend ──emit──▶  AIR bitcode (.air)  ──metallib──▶  .metallib  ──▶  MTLLibrary
```

Metal's own path is `metal -c` → `.air` → `metallib`. A Swift backend replaces
only the first box. Two facts make this tractable:

1. **AIR is LLVM bitcode.** If your frontend is LLVM-based (Swift's is), you emit
   bitcode with the LLVM APIs you already have — you just target AIR's triple and
   follow its conventions.
2. **The text path round-trips.** You can emit textual `.ll`, assemble it, and
   package it:

   ```sh
   xcrun metal-as   kernel.ll  -o kernel.air     # textual AIR -> bitcode
   xcrun metallib   kernel.air -o kernel.metallib # -> loadable MetalLib
   ```

   This is invaluable for bring-up: emit text, `metal-as` it, and read the
   errors. (Confirmed working on the harness set — the `.ll` files assemble and
   package into a `MetalLib executable` unchanged.)

## The minimum viable module

A loadable compute kernel needs all of the following. Missing metadata is the
usual reason a hand-built module loads but the function is invisible or the
runtime rejects it.

### 1. Module header

```llvm
target datalayout = "e-p:64:64:64-i1:8:8-…-n8:16:32"
target triple     = "air64_v28-apple-macosx26.0.0"
```

Copy the exact data layout from a reference module (see
[overview](00-air-overview.md)); it encodes AIR's alignment rules, including
**no native i64** (`n8:16:32`).

### 2. The function

```llvm
define void @add(float addrspace(1)* nocapture noundef readonly "air-buffer-no-alias" %0,
                 float addrspace(1)* nocapture noundef readonly "air-buffer-no-alias" %1,
                 float addrspace(1)* nocapture noundef writeonly "air-buffer-no-alias" %2,
                 i32 noundef %3) local_unnamed_addr #0 { … ret void }
```

Rules:

- returns `void`;
- every buffer is a pointer in the correct [address space](01-address-spaces.md)
  (`device` → `addrspace(1)`, `constant` → `addrspace(2)`, …);
- built-in inputs like `[[thread_position_in_grid]]` are **trailing scalar
  parameters**, not globals;
- the `"air-buffer-no-alias"` attribute and `readonly`/`writeonly` are how you
  hand the optimizer the aliasing facts it needs — get these wrong and you get
  either miscompiles or missed optimization, not a load failure.

### 3. Entry-point + argument metadata

This is the part a naive LLVM backend forgets. The runtime learns the function
is a kernel, and how to bind its arguments, **only** from metadata:

```llvm
!air.kernel = !{!9}
!9  = !{ void (…)* @add, !10, !11 }   ; {function, fn-attrs, arg-list}
!10 = !{}
!11 = !{ !12, !13, !14, !15 }         ; one node per argument, in order
!12 = !{ i32 0, !"air.buffer", !"air.location_index", i32 0, i32 1, !"air.read",
         !"air.address_space", i32 1, !"air.arg_type_size", i32 4,
         !"air.arg_type_align_size", i32 4, !"air.arg_type_name", !"float",
         !"air.arg_name", !"a" }
!15 = !{ i32 3, !"air.thread_position_in_grid", !"air.arg_type_name", !"uint",
         !"air.arg_name", !"gid" }
```

The full grammar of these nodes — buffers, textures, samplers, stage I/O — is in
[function & argument metadata](02-function-and-argument-metadata.md). Use
`!air.vertex` / `!air.fragment` / `!air.object` / `!air.mesh` for other stages.

### 4. Module-level metadata

```llvm
!llvm.module.flags    = !{…, !"air.max_device_buffers"…}  ; resource ceilings
!air.version          = !{i32 2, i32 8, i32 0}            ; AIR format version
!air.language_version = !{!"Metal", i32 3, i32 2, i32 0}  ; source language tag
!air.compile_options  = !{!"air.compile.fast_math_enable", …}
```

The `air.max_*` module flags and `air.version` are what `metallib` /
`metal-validate` check for compatibility. A backend can lift these verbatim from
a reference module compiled for the same target.

## What maps cleanly vs. what needs care

| Concern | Effort for a Swift backend |
| --- | --- |
| Scalar/vector arithmetic, control flow | **Free** — plain LLVM ([control flow](07-control-flow.md)) |
| Address spaces | Mechanical — annotate pointers correctly ([addr spaces](01-address-spaces.md)) |
| Argument binding | **The main work** — emit the metadata contract exactly ([arg metadata](02-function-and-argument-metadata.md)) |
| SIMD-group ops | Easy — call `air.simd_*` intrinsics ([simd](04-simd-group-operations.md)) |
| Atomics | Moderate — `air.atomic.*` intrinsics, not `atomicrmw` ([atomics](03-atomics-and-memory-ordering.md)) |
| Textures/samplers | Moderate — opaque handles + intrinsics ([textures](05-textures-and-samplers.md)) |
| Function constants | Moderate — special globals + table ([function constants](06-function-constants.md)) |

The recurring theme: **the instructions are ordinary LLVM; the ABI lives in the
metadata and the intrinsic names.** A Swift-to-AIR backend is therefore less
about novel codegen and more about faithfully reproducing AIR's naming and
metadata conventions — which is exactly what the rest of this documentation
catalogs.

## Validating your output

```sh
xcrun metal-as    yourkernel.ll   -o yourkernel.air   # syntax / IR legality
xcrun metallib    yourkernel.air  -o yourkernel.metallib
xcrun metal-validate yourkernel.metallib              # metadata / ABI checks
```

Then load it at runtime with `newLibraryWithData:` and confirm the function is
enumerable and a pipeline state builds. If assembly succeeds but the function is
missing, suspect the entry-point metadata (step 3) first.
