# Function constants

Harness: [`compute/12_function_constants`](../harnesses/compute/12_function_constants.metal).

Function constants are MSL's **specialization constants**: values left undefined
at compile time and bound when a pipeline state is created. In AIR they are
`externally_initialized` globals in a dedicated section, plus a
`!air.function_constants` metadata table.

## The globals

Each `[[function_constant(n)]]` becomes a global constant:

```llvm
@_Z7useBias.MTL_FC_INIT_0_b     = linkonce_odr hidden addrspace(2)
        externally_initialized constant i8    undef, section "air.fc_initializer", align 1
@_Z11defaultBias.MTL_FC_INIT_1_f = linkonce_odr hidden addrspace(2)
        externally_initialized constant float undef, section "air.fc_initializer", align 4
@_Z4mode.MTL_FC_INIT_2_i        = linkonce_odr hidden addrspace(2)
        externally_initialized constant i32   undef, section "air.fc_initializer", align 4
```

Anatomy of the symbol name `_Z7useBias.MTL_FC_INIT_0_b`:

- `_Z7useBias` — the Itanium-mangled source name.
- `.MTL_FC_INIT_0` — marker + the `[[function_constant(0)]]` index.
- `_b` — a type tag (`b`ool, `f`loat, `i`nt, …).

Key attributes:

- **`externally_initialized`** — the value comes from outside the module (the
  pipeline descriptor), so the optimizer may not assume the `undef` initializer.
- **`addrspace(2)`** — they live in constant space.
- **`section "air.fc_initializer"`** — how the runtime finds them to patch.

A use is just a load from the global, which specialization later constant-folds:

```llvm
%1 = load i8,    i8    addrspace(2)* @_Z7useBias.MTL_FC_INIT_0_b,     align 1, !range !36
%3 = load i32,   i32   addrspace(2)* @_Z4mode.MTL_FC_INIT_2_i,        align 4
switch i32 %3, label … [ … ]   ; the switch on `mode` is resolved at specialization
```

The `!range !{i8 0, i8 2}` on the bool load tells the optimizer the byte is 0 or
1.

## The metadata table

```llvm
!air.function_constants = !{!18, !19, !20}
!18 = !{ i8*    @_Z7useBias.MTL_FC_INIT_0_b,     !"bool",  !"useBias",     i32 0 }
!19 = !{ float* @_Z11defaultBias.MTL_FC_INIT_1_f, !"float", !"defaultBias", i32 1 }
!20 = !{ i32*   @_Z4mode.MTL_FC_INIT_2_i,        !"int",   !"mode",        i32 2 }
```

Each entry is `{ global, type-name, source-name, index }`. The runtime uses the
source name / index to match the value you set on the pipeline descriptor.

## `is_function_constant_defined` and derived constants

`is_function_constant_defined(x)` is an intrinsic, not a compile-time literal —
because "is it defined" is only known at specialization:

```llvm
declare i1 @air.is_function_constant_defined(i8 addrspace(2)* nocapture)
```

A `constant` initialized from other function constants (like this harness's
`biasIsProvided`) is emitted as a **module static initializer** that runs at
specialization time:

```llvm
define internal void @_GLOBAL__sub_I_12_function_constants.metal() section "air.static_init" {
  %4 = tail call i1 @air.is_function_constant_defined(i8 addrspace(2)* bitcast (float addrspace(2)* @…defaultBias… to i8 addrspace(2)*))
  …
}
```

## Implications for a Swift backend

Specialization constants require the frontend to:

1. emit each constant as an `externally_initialized`, `addrspace(2)`,
   `section "air.fc_initializer"` global with the `.MTL_FC_INIT_<n>_<t>` naming,
2. register it in `!air.function_constants` as `{global, type, name, index}`,
3. lower reads as loads (not as baked literals), and
4. route `is_function_constant_defined` and derived constants through the
   `air.static_init` initializer mechanism rather than folding them.
