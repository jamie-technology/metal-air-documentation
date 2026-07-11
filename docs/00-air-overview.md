# AIR overview

## What AIR is

AIR is **LLVM bitcode** with a Metal-specific set of conventions layered on top:
a fixed target triple and data layout, a family of `air.*` intrinsic functions,
and a tree of `air.*` named metadata that carries everything the Metal runtime
needs that plain LLVM IR cannot express (argument bindings, entry-point stages,
resource limits, and so on).

A `.metallib` ultimately contains this bitcode. A raw `.air` object is *LLVM
bitcode, wrapper* — a small Mach-O-style wrapper around the bitcode:

```
$ file harnesses/compute/air/00_minimal_add.air
… : LLVM bitcode, wrapper
```

Because it is LLVM bitcode, the entire IR toolchain applies — you just have to
use the Metal fork of it shipped in the Metal Toolchain.

## Getting readable AIR

`metal -c` emits the bitcode object. To read it, ask the front-end to emit
textual LLVM IR instead:

```sh
xcrun metal -S -emit-llvm  shader.metal -o shader.ll      # optimized
xcrun metal -S -emit-llvm -O0 shader.metal -o shader.O0.ll  # unoptimized
```

`harnesses/generate.sh` does exactly this for every harness. The optimized `.ll`
is what the backend actually consumes; the `-O0` variant is closer to the source
and useful when the optimizer has folded away the structure you wanted to see.

The toolchain itself is not installed by default; fetch it once with:

```sh
xcodebuild -downloadComponent MetalToolchain
```

## Anatomy of a module

Here is the complete non-body content of the simplest harness,
[`compute/00_minimal_add.metal`](../harnesses/compute/00_minimal_add.metal):

```llvm
; ModuleID = './compute/00_minimal_add.metal'
source_filename = "./compute/00_minimal_add.metal"
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-…-n8:16:32"
target triple = "air64_v28-apple-macosx26.0.0"

define void @add(float addrspace(1)* nocapture noundef readonly "air-buffer-no-alias" %0,
                 float addrspace(1)* nocapture noundef readonly "air-buffer-no-alias" %1,
                 float addrspace(1)* nocapture noundef writeonly "air-buffer-no-alias" %2,
                 i32 noundef %3) local_unnamed_addr #0 { … }

!llvm.module.flags   = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!air.kernel          = !{!9}
!air.compile_options = !{!16, !17, !18}
!llvm.ident          = !{!19}
!air.version         = !{!20}
!air.language_version = !{!21}
!air.source_file_name = !{!22}
```

### Target triple

```
air64_v28-apple-macosx26.0.0
```

- **`air64`** — the AIR architecture, 64-bit. Pointers are 64-bit
  (`p:64:64:64` in the data layout).
- **`_v28`** — an AIR ABI/version tag *(observed: this tracks the toolchain, not
  the `-std` you pass; see `!air.version` below for the language-facing number)*.
- **`apple-macosx26.0.0`** — vendor/OS, the deployment target.

### Data layout

Little-endian (`e`), 64-bit pointers, natural alignment for each integer and
float width, and an extensive vector-alignment table
(`v16:16` … `v1024:1024`). `n8:16:32` lists the native integer widths — 8, 16,
and 32 bits, i.e. **there is no native 64-bit integer**; `i64` is legal in the IR
but not a native register width, which is why sub-word integers are widened to
`i32` rather than `i64` (see [scalar types](../harnesses/compute/01_scalar_types.metal)).

### Entry-point signature

A kernel lowers to a plain `void`-returning function. Note the parameter
attributes the front-end attaches:

- **`addrspace(1)`** — the `device` address space (see [address spaces](01-address-spaces.md)).
- **`"air-buffer-no-alias"`** — a string attribute asserting the buffer does not
  alias other buffer arguments, feeding LLVM's alias analysis. It is the AIR
  equivalent of `restrict`.
- **`nocapture noundef readonly` / `writeonly`** — standard LLVM pointer facts,
  derived from the `const`-ness and use of each argument.

The scalar `i32 %3` is the `[[thread_position_in_grid]]` value; it is a real
parameter here, described by argument metadata rather than passed by the user.

## The `air.*` named-metadata roots

Named metadata (the `!air.foo = !{…}` lines) is where AIR keeps Metal semantics.
Across the harness set these roots appear:

| Named metadata          | Meaning                                                        |
| ----------------------- | ------------------------------------------------------------- |
| `!air.kernel`           | Compute entry points and their argument descriptions          |
| `!air.vertex`           | Vertex / post-tessellation-vertex entry points                |
| `!air.fragment`         | Fragment entry points                                         |
| `!air.object`           | Mesh-pipeline object stage                                    |
| `!air.mesh`             | Mesh-pipeline mesh stage                                      |
| `!air.compile_options`  | Front-end flags baked into the module (see below)             |
| `!air.version`          | AIR format version, as `{major, minor, patch}`                |
| `!air.language_version` | The MSL language version, e.g. `{"Metal", 3, 2, 0}`           |
| `!air.source_file_name` | Absolute path of the source                                  |
| `!air.function_constants` | Declared function constants (see the harness page)          |

Entry-point roots are covered in detail in
[function & argument metadata](02-function-and-argument-metadata.md).

### Compile options and versions

```llvm
!air.compile_options = !{!16, !17, !18}
!16 = !{!"air.compile.denorms_disable"}
!17 = !{!"air.compile.fast_math_enable"}
!18 = !{!"air.compile.framebuffer_fetch_enable"}
!19 = !{!"Apple metal version 32023.883 (metalfe-32023.883)"}  ; !llvm.ident
!20 = !{i32 2, i32 8, i32 0}          ; !air.version  -> AIR 2.8.0
!21 = !{!"Metal", i32 3, i32 2, i32 0} ; !air.language_version -> MSL 3.2
```

`fast_math_enable` is the default and is why the function body shows `fadd fast`
and why the function carries `"unsafe-fp-math"="true"`, `"no-nans-fp-math"` and
friends in its attribute group. Compile with `-fno-fast-math` to see these flip.

## `llvm.module.flags`

Standard LLVM module flags plus AIR resource ceilings:

```llvm
!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 26, i32 4]}
!2 = !{i32 7, !"frame-pointer", i32 2}
!3 = !{i32 7, !"air.max_device_buffers", i32 31}
!4 = !{i32 7, !"air.max_constant_buffers", i32 31}
!5 = !{i32 7, !"air.max_threadgroup_buffers", i32 31}
!6 = !{i32 7, !"air.max_textures", i32 128}
!7 = !{i32 7, !"air.max_read_write_textures", i32 8}
!8 = !{i32 7, !"air.max_samplers", i32 16}
```

These `air.max_*` values are the binding-slot limits the module was compiled
against — 31 buffers, 128 textures, 16 samplers, 8 read-write textures. They are
constant across the whole harness set, i.e. they reflect the target family, not
anything about the individual shader.
