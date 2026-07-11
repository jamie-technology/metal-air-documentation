# Argument buffers

Harness: [`compute/11_argument_buffers`](../harnesses/compute/11_argument_buffers.metal).

An argument buffer is a struct of resources (textures, samplers, buffers, plain
constants) bound as a **single** buffer slot. Instead of each resource being a
top-level kernel argument, they are members reached through one indirection —
which is exactly how the AIR models it: one `air.indirect_buffer` argument whose
`air.struct_type_info` enumerates the members.

## The top-level argument

The whole `Material` struct is a single argument of kind `air.indirect_buffer`:

```llvm
!12 = !{ i32 0, !"air.indirect_buffer",
         !"air.buffer_size", i32 64,
         !"air.location_index", i32 0, i32 1,
         !"air.read",
         !"air.address_space", i32 1,
         !"air.struct_type_info", !13,          ; <- the member table
         !"air.arg_type_size", i32 64,
         !"air.arg_type_align_size", i32 16,
         !"air.arg_type_name", !"Material",
         !"air.arg_name", !"mat" }
```

Compared to a plain `air.buffer` ([arg metadata](02-function-and-argument-metadata.md)),
the new pieces are `air.indirect_buffer`, `air.buffer_size` (the encoded size of
the argument buffer), and the `air.struct_type_info` pointer.

## The member table

`air.struct_type_info` (`!13`) is a flat list, three fixed fields then
per-member records:

```llvm
!13 = !{ i32 0, i32 8, i32 0, !"texture2d<float, sample>", !"albedo", !"air.indirect_argument", !14,
         i32 8,  i32 8, i32 0, !"texture2d<float, sample>", !"normal", !"air.indirect_argument", !15,
         i32 16, i32 8, i32 0, !"sampler", !"smp",     !"air.indirect_argument", !16,
         i32 24, i32 8, i32 0, !"float",   !"weights", !"air.indirect_argument", !17,
         i32 32, i32 16,i32 0, !"float4",  !"tint",    !"air.indirect_argument", !18,
         i32 48, i32 4, i32 0, !"uint",    !"flags",   !"air.indirect_argument", !19 }
```

Each member record is: **byte offset, size, (flags?), type-name, member-name,
`air.indirect_argument`, →detail-node**. So `albedo` is at offset 0, `normal` at
8, the `smp` sampler at 16, and so on — these offsets are the `[[id(n)]]` slots
laid out in the buffer. The trailing `air.indirect_argument` nodes (`!14`…)
carry each member's own binding detail (access qualifier, index).

## In the function body

Access lowers to a `getelementptr` into the argument-buffer struct to fetch the
handle, then the normal texture/sampler intrinsics
([textures](05-textures-and-samplers.md)). The resources inside an argument
buffer behave identically to directly-bound ones once loaded — the indirection
is only in *how they are bound*, not in how they are *used*.

## Implications for a Swift backend

Argument buffers are "just a struct" at the language level but require the
backend to:

1. emit the argument as `air.indirect_buffer` (not `air.buffer`), with
   `air.buffer_size` and the struct's size/alignment;
2. build the `air.struct_type_info` member table with correct byte offsets —
   these must match the host-side encoder's expectations;
3. emit an `air.indirect_argument` detail node per member.

The member layout is the ABI contract with `MTLArgumentEncoder` on the host, so
the offsets are not free to choose — they follow the struct layout rules for the
target.
