# Tessellation

Harness: [`graphics/04_tessellation`](../harnesses/graphics/04_tessellation.metal).

Metal's tessellation pipeline is two shader-authored stages around a
fixed-function tessellator: (1) a **compute kernel** that writes per-patch
tessellation factors, and (2) a **post-tessellation vertex function** that runs
per generated vertex and reads the patch's control points. AIR represents the
second stage with `air.patch*` metadata and a synthesized control-point fetch
function.

## Stage 1 — the factor kernel

This is an ordinary compute kernel ([arg metadata](02-function-and-argument-metadata.md))
that writes a library-defined factor struct:

```llvm
%"struct.metal::MTLTriangleTessellationFactorsHalf" = type { [3 x half], half }

define void @tess_factors(%"struct.metal::MTLTriangleTessellationFactorsHalf" addrspace(1)* … %0, …)
```

The struct is `{ [3 x half] edgeFactors, half insideFactor }`. (There is a
non-`Half` variant with `float`/`ushort` fields; the harness uses the half form.)
Nothing here is tessellation-specific in the IR — it is the *layout of the output
struct* that the fixed-function tessellator later consumes.

## Stage 2 — the post-tessellation vertex function

This is where AIR adds machinery. The function is marked `[[patch(triangle, 3)]]`
and takes `patch_control_point<T>`; both surface in metadata.

### Opaque control-point handle + fetch function

```llvm
%struct._patch_control_point_t = type opaque

define <{ <4 x float> }> @tess_vertex(%struct._patch_control_point_t* %0,
                                      <3 x float> noundef %1) {   ; %1 = [[position_in_patch]]
  %3 = tail call { <4 x float> } @_Z12ControlPoint.MTL_CONTROL_POINT_FN(i32 0, %struct._patch_control_point_t* %0)
  %7 = tail call { <4 x float> } @_Z12ControlPoint.MTL_CONTROL_POINT_FN(i32 1, %struct._patch_control_point_t* %0)
  …
```

`patch.cp[i]` does **not** lower to a load — it lowers to a call to a synthesized
`…MTL_CONTROL_POINT_FN(index, handle)` that returns the i-th control point. The
control-point buffer layout is thus abstracted behind this generated function.
The `[[position_in_patch]]` barycentric input arrives as a plain `<3 x float>`
parameter.

### Patch metadata

```llvm
!air.vertex = !{!17}
; the stage_in argument is a patch_control_point input, wired to the fetch fn:
!21 = !{ i32 0, !"air.patch_control_point_input", !22, !23 }
!22 = !{ !"air.patch_control_point_function",
         { <4 x float> } (i32, %struct._patch_control_point_t*)* @_Z12ControlPoint.MTL_CONTROL_POINT_FN }
; the patch descriptor itself:
!25 = !{ !"air.patch", !"triangle", !"air.patch_control_point", i32 3 }
```

- **`air.patch`** records the patch primitive (`triangle`) and the control-point
  count (`3`) — i.e. the `[[patch(triangle, 3)]]` attribute.
- **`air.patch_control_point_input`** marks the `[[stage_in]]` argument as patch
  control points and names the fetch function via
  `air.patch_control_point_function`.

## Implications for a Swift backend

Tessellation is one of the more involved stages to emit because the frontend must
synthesize the control-point fetch function and wire it up in metadata, rather
than just describing a buffer binding. Concretely:

1. emit the post-tessellation vertex under `!air.vertex` with an `air.patch`
   descriptor (primitive + control-point count);
2. generate a `…MTL_CONTROL_POINT_FN(i32 index, handle)` accessor and reference
   it from `air.patch_control_point_function`;
3. lower `[[position_in_patch]]` as a vector parameter.

Stage 1 needs nothing special beyond agreeing on the
`MTLTriangleTessellationFactors[Half]` struct layout.
