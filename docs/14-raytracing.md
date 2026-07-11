# Raytracing

Harness: [`compute/13_raytracing`](../harnesses/compute/13_raytracing.metal).

Hardware raytracing is expressed in a compute kernel via an
`acceleration_structure` argument, the `ray` type, and an `intersector<>` that
traverses it — plus optional custom `[[intersection]]` functions. AIR lowers the
traversal to a single big `air.intersect.*` intrinsic and represents intersection
functions as ordinary functions with a [`ray_data` payload](01-address-spaces.md).

## The acceleration structure argument

```llvm
!12 = !{ i32 0, !"air.instance_acceleration_structure", !"air.location_index", i32 0, i32 1,
         !"air.read", !"air.arg_type_name", !"acceleration_structure<instancing>", !"air.arg_name", !"accel" }
```

It binds like a resource (`air.instance_acceleration_structure` — its own
argument kind) and arrives in the function as an opaque
`%struct._instance_acceleration_structure_t addrspace(1)*`.

## The traversal intrinsic

`isect.intersect(r, accel)` becomes one call that returns the whole intersection
result as a struct:

```llvm
%12 = call { i32, float, i32, i32, i8 addrspace(1)*, i32, i32, <2 x float>, i1 }
       @air.intersect.instancing.triangle_data(
           <3 x float> origin, <3 x float> direction, float tmin, float tmax,
           %struct._instance_acceleration_structure_t addrspace(1)* %0,   ; the AS
           i32 -1,                                                        ; ray mask
           %struct._intersection_function_table_t addrspace(1)* %11,      ; function table
           i8* null, i64 0, …, i32 3, …, i1 false, i1 false)
```

- The intrinsic name encodes the traversal configuration
  (`.instancing.triangle_data`) — instance AS with triangle intersection data.
- The **return struct** is the decoded `intersection_result`: `{ type,
  distance, primitive_id, geometry_id, <instance ptr>, …, <2 x float>
  barycentric_coord, valid }`. The harness reads `.type`, `.primitive_id`,
  `.distance`, and `.triangle_barycentric_coord` straight out of this tuple.
- When no custom intersection functions are bound, the function-table operand
  comes from `air.get_null_intersection_function_table()`.

## Custom intersection functions

An `[[intersection(triangle, triangle_data)]]` function is a normal function that
returns `i1` (accept/reject) and whose payload lives in `ray_data`
(`addrspace(5)`):

```llvm
define i1 @alpha_test(%struct.Payload addrspace(5)* … %0,  ; payload (ray_data)
                      float %1,                            ; [[distance]]
                      i32 %2,                              ; [[primitive_id]]
                      <2 x float> %3)                      ; [[barycentric_coord]]

!17 = !{ i1 (%struct.Payload addrspace(5)*, float, i32, <2 x float>)* @alpha_test,
         !18, !20, !"air.triangle", !"air.triangle_data" }
```

The entry-point metadata tags it with the primitive (`air.triangle`) and data
kind (`air.triangle_data`) so the runtime can slot it into an intersection
function table. Its arguments (`air.payload`, `air.distance`, `air.primitive_id`,
`air.barycentric_coord`) use the same single-key metadata shape as any built-in
input.

## Implications for a Swift backend

Raytracing needs:

1. opaque `acceleration_structure` handle types with
   `air.*_acceleration_structure` argument metadata;
2. lowering `intersect()` to the correctly-configured `air.intersect.<as>.<data>`
   intrinsic and destructuring the returned tuple into the result fields;
3. emitting `[[intersection]]` functions as `i1`-returning functions with a
   `ray_data` (`addrspace(5)`) payload and the primitive/data tags in metadata.

As with [tensor ops](13-tensors-and-tensor-ops.md), the heavy lifting is in a
fixed-function/library layer; the frontend's job is the call shape and the
metadata.
