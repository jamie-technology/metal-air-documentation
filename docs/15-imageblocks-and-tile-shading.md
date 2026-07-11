# Imageblocks & tile shading

Harness: [`graphics/07_imageblock_tile`](../harnesses/graphics/07_imageblock_tile.metal).

Tile shading keeps per-pixel data for a screen tile in on-chip **tile memory**
and lets a kernel (a "tile function") read/write it directly. The data structure
is an `imageblock<>`, which AIR models as an opaque handle in
[`addrspace(4)`](01-address-spaces.md) accessed through `air.*imageblock`
intrinsics.

## The imageblock handle

An `imageblock<FragValues, layout_implicit>` argument is a wrapper struct around
an opaque tile-memory pointer:

```llvm
%"struct.metal::_imageblock_base" = type { %struct._imageblock_t addrspace(4)* }
%struct._imageblock_t = type opaque

define void @tile_resolve(%"struct.metal::_imageblock_base" %0, …)
```

The argument metadata gives it its own kind and records the per-pixel struct
layout:

```llvm
!12 = !{ i32 0, !"air.imageblock", !"implicit", !"air.struct_type_info", !13,
         !"air.arg_type_align_size", i32 8,
         !"air.arg_type_name", !"imageblock<FragValues, layout_implicit>", !"air.arg_name", !"ib" }
```

- **`air.imageblock`** — the argument kind.
- **`implicit`** — the layout mode (`imageblock_layout_implicit`); an explicit
  layout would describe each field's tile-memory placement.
- **`air.struct_type_info`** — the same member-table mechanism used by
  [argument buffers](09-argument-buffers.md), here describing the per-pixel
  `FragValues` struct.

## Reading a pixel

`ib.read(lid)` lowers to a typed load intrinsic:

```llvm
%6 = tail call fast <4 x half> @air.load.implicit_imageblock.v4f16(
        i32 0,          ; element / color index
        <2 x i16> %2,   ; the in-tile coordinate (thread_position_in_threadgroup)
        i32 0, i16 0)
```

Points to note:

- the coordinate is `<2 x i16>` — tile coordinates are small, so 16-bit;
- the return type suffix (`.v4f16`) matches the `half4 color` field;
- `implicit_imageblock` in the name mirrors the `implicit` layout tag; the
  leading `i32 0` selects the element/attribute within the per-pixel struct.

Writes use the corresponding `air.store.*_imageblock.*` form (not exercised here
but symmetric).

## Implications for a Swift backend

Imageblocks are a tile-function-only feature, so first the backend must support
tile dispatch at all. Then:

1. introduce an opaque imageblock handle in `addrspace(4)`, wrapped in the
   `_imageblock_base` struct;
2. emit `air.imageblock` argument metadata with the layout tag and an
   `air.struct_type_info` member table for the per-pixel struct;
3. lower `read`/`write` to `air.load/store.<layout>_imageblock.<type>` with
   `<2 x i16>` coordinates.

The `air.struct_type_info` machinery is shared with argument buffers, so a
backend that already emits those is most of the way here.
