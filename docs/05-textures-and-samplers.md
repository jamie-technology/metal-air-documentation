# Textures & samplers

Harnesses: [`compute/07_texture_read_write`](../harnesses/compute/07_texture_read_write.metal),
[`graphics/02_texture_sample`](../harnesses/graphics/02_texture_sample.metal).

Textures and samplers are **opaque handles**, not memory you load through. All
access goes via `air.*` intrinsics that take the handle plus coordinates.

## Opaque handle types

```llvm
%struct._texture_2d_t = type opaque
%struct._sampler_t    = type opaque
```

- A **texture** handle is passed as `%struct._texture_2d_t addrspace(1)*`
  (device space, but the pointer is opaque — you never dereference it).
- A **sampler** handle is `%struct._sampler_t addrspace(2)*` (constant space).

Each 2D/3D/cube/array texture variant has its own opaque struct type and its own
family of intrinsics.

## Sampling

From the fragment sampler harness:

```llvm
%5 = tail call { <4 x float>, i8 } @air.sample_texture_2d.v4f32(
        %struct._texture_2d_t addrspace(1)* %2,   ; texture handle
        %struct._sampler_t    addrspace(2)* %3,   ; sampler handle
        <2 x float> %1,                           ; uv
        i1 true,                                  ; (LOD/bias present flag, observed)
        <2 x i32> zeroinitializer,                ; integer offset
        i1 false, float 0.0, float 0.0, i32 0)    ; bias / min-lod / … operands
```

Two things to note:

- **The return type is `{ <4 x float>, i8 }`** — the RGBA sample *plus* an `i8`.
  The extra byte is a residency/valid flag (used by sparse textures and the
  `sparse_color` query). Reads have the same shape.
- The coordinate type and result type are baked into the suffix (`.v4f32`).

## Reads and writes

```llvm
%13 = tail call { <4 x float>, i8 } @air.read_texture_2d.v4f32(tex, sampler, <2 x i32> coord, …)
       tail call void @air.write_texture_2d.v4f32(tex, <2 x i32> coord, <4 x float> value, …)
```

`read()` uses **integer** coordinates (`<2 x i32>`) and, interestingly, still
threads a sampler handle obtained from `@air.get_read_sampler()` — an implicit
"read" sampler synthesized by the front-end. `write()` takes the value and
integer coordinates and returns `void`.

## Queries

`get_width()` / `get_height()` are their own intrinsics taking a LOD level:

```llvm
%5 = tail call i32 @air.get_width_texture_2d(%struct._texture_2d_t addrspace(1)* %0, i32 0)
```

## Argument metadata

Textures and samplers bind in their own namespaces (see
[function & argument metadata](02-function-and-argument-metadata.md)):

```llvm
!… = !{ i32 2, !"air.texture", !"air.location_index", i32 0, i32 1, !"air.sample",
        !"air.arg_type_name", !"texture2d<float, sample>", !"air.arg_name", !"tex" }
!… = !{ i32 3, !"air.sampler", !"air.location_index", i32 0, i32 1,
        !"air.arg_type_name", !"sampler", !"air.arg_name", !"smp" }
```

The access qualifier (`air.sample` / `air.read` / `air.write` / `air.read_write`)
is part of the MSL texture type and is preserved here.

## Implications for a Swift backend

To expose textures in Swift you need to:

1. introduce opaque handle types in the right address spaces (texture →
   `addrspace(1)`, sampler → `addrspace(2)`),
2. call the correctly-suffixed `air.sample_/read_/write_texture_<dim>.<type>`
   intrinsic (including the residency `i8` in the return tuple), and
3. emit `air.texture` / `air.sampler` argument metadata so the runtime binds the
   handles.

The opaque-handle model means Swift's type system would represent a texture as
an abstract resource, never as a pointer you can chase.
