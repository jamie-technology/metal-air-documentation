# Vertex amplification & barycentrics

Harness: [`graphics/06_amplification_barycentric`](../harnesses/graphics/06_amplification_barycentric.metal).

Two smaller pipeline features that each add a built-in argument kind:
**vertex amplification** (one vertex invocation producing several amplified
outputs, e.g. for stereo/multiview) and **fragment barycentrics** (reading the
raw barycentric weights and primitive id in the fragment stage). Both are just
new `air.*` argument-metadata kinds on top of the ordinary
[vertex/fragment machinery](02-function-and-argument-metadata.md).

## Vertex amplification

`[[amplification_id]]` and `[[amplification_count]]` arrive as scalar `uint`
parameters with single-key metadata nodes:

```llvm
!16 = !{ i32 2, !"air.amplification_id",    !"air.arg_type_name", !"uint", !"air.arg_name", !"ampId" }
!17 = !{ i32 3, !"air.amplification_count", !"air.arg_type_name", !"uint", !"air.arg_name", !"ampCnt" }
```

- `amplification_id` is which amplified output (0 … count-1) this invocation is
  producing;
- `amplification_count` is how many were requested on the draw.

There is nothing special in the function body — the shader just reads two more
`uint`s. The pipeline replays the vertex function `count` times with different
ids; AIR only needs to *name* the inputs.

## Fragment barycentrics

`[[barycentric_coord]]` and `[[primitive_id]]` are fragment-stage built-ins:

```llvm
!… = !{ i32 …, !"air.barycentric_coord", !"air.arg_type_name", !"float3", !"air.arg_name", !"bary" }
!… = !{ i32 …, !"air.primitive_id",      !"air.arg_type_name", !"uint",   !"air.arg_name", !"primId" }
```

`barycentric_coord` is the `float3` of raw weights for the three triangle
vertices at this fragment — the values the rasterizer would otherwise use
internally to interpolate varyings, exposed directly so a shader can do its own
interpolation or gradient tricks. `primitive_id` identifies the source triangle.

## Implications for a Swift backend

Both are trivial once the base [vertex/fragment stages](02-function-and-argument-metadata.md)
work: expose the four attributes and emit the matching single-key metadata nodes
(`air.amplification_id`, `air.amplification_count`, `air.barycentric_coord`,
`air.primitive_id`). No new address spaces, intrinsics, or body-level lowering —
the values are supplied by the pipeline and described entirely in argument
metadata.

This is the general shape of "small" GPU built-ins: a new `air.<name>` key on an
otherwise ordinary scalar/vector parameter. Most of the thread/grid indices
([indexing](02-function-and-argument-metadata.md#built-in-position-arguments))
follow the identical pattern.
