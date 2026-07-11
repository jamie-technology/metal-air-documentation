# Harnesses

Each `.metal` file is a small, self-contained MSL example that isolates one
feature (or a tight family of features). Its header comment states what it is
meant to demonstrate in the resulting AIR.

## Generating AIR

```sh
./generate.sh            # all harnesses
./generate.sh compute    # just harnesses/compute
```

For every `<name>.metal` this writes, into a sibling `air/` directory:

| File          | Command                          | What it is                                   |
| ------------- | -------------------------------- | -------------------------------------------- |
| `<name>.air`  | `metal -c`                       | AIR bitcode object — the real compiler output |
| `<name>.ll`   | `metal -S -emit-llvm`            | Human-readable AIR (LLVM IR text), optimized |
| `<name>.O0.ll`| `metal -S -emit-llvm -O0`        | Unoptimized IR, closer to the source shape   |

The `.ll` files are the primary thing we read and document. `.O0.ll` is useful
when the optimizer folds away structure you want to see.

Requires the Metal toolchain:
`xcodebuild -downloadComponent MetalToolchain`.

The `air/` output is git-ignored; it is fully regenerable from the sources.

## Inventory

### compute/
- `00_minimal_add` — baseline: device buffers, `[[thread_position_in_grid]]`
- `01_scalar_types` — scalar type lowering (i1/i8/i16/i32, half, float)
- `02_vector_types` — vector layout, component ops, swizzle → shufflevector
- `03_thread_index_attributes` — the built-in thread/grid position attributes
- `04_threadgroup_memory` — `threadgroup` address space + barriers (reduction)
- `05_atomics` — atomic fetch_add / compare_exchange intrinsics
- `06_constant_address_space` — `constant` buffers, by-value uniform struct
- `07_texture_read_write` — texture `read()`/`write()` intrinsics
- `08_math_builtins` — sqrt/sin/fma/clamp/mix/rsqrt lowering
- `09_control_flow` — if/else, loop, switch → basic blocks / phi / select
- `10_simdgroup_ops` — `air.simd_*` / `air.quad_*` (sum, shuffle, broadcast, ballot)
- `11_argument_buffers` — struct of resources with `[[id(n)]]` → `air.indirect_buffer`
- `12_function_constants` — `[[function_constant(n)]]` → `!air.function_constants`
- `13_raytracing` — acceleration structures, `intersector<>`, `[[intersection]]` (`ray_data` = addrspace 5)
- `14_atomic_variants` — op/signedness/scope coverage (`.s`/`.u`, `global`/`local`)
- `15_simd_int` — integer SIMD reductions (confirms `air.simd_<op>.<sign>.i32`)
- `16_simdgroup_matrix` — `simdgroup_matrix<>` 8×8 matmul (`air.simdgroup_matrix_8x8_*`)
- `17_tensor_scale` — Metal 4 `tensor<>` element access (`air.tensor`, `// STD: metal4.0`)
- `18_tensor_matmul` — MPP `matmul2d` cooperative tensor op (`air.externally_defined` call)

### graphics/
- `00_passthrough` — baseline vertex+fragment, `[[stage_in]]`, `[[position]]`
- `01_vertex_ids` — `[[vertex_id]]` / `[[instance_id]]`, pull-model fetch
- `02_texture_sample` — fragment texture + sampler `sample()`
- `03_interpolation_qualifiers` — `[[flat]]`, `[[center_no_perspective]]`, `[[point_size]]`
- `04_tessellation` — factor kernel + post-tessellation vertex (`[[patch]]`)
- `05_mesh_shader` — `[[object]]` + `[[mesh]]` stages → `!air.object` / `!air.mesh`
- `06_amplification_barycentric` — `[[amplification_id/count]]`, `[[barycentric_coord]]`, `[[primitive_id]]`
- `07_imageblock_tile` — `imageblock<>` tile function (imageblock = addrspace 4)
