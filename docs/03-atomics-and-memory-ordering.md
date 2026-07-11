# Atomics & memory ordering

Harnesses: [`compute/05_atomics`](../harnesses/compute/05_atomics.metal),
[`compute/14_atomic_variants`](../harnesses/compute/14_atomic_variants.metal).

MSL atomics do **not** lower to LLVM's native `atomicrmw` / `cmpxchg`
instructions. They lower to `air.atomic.*` intrinsic calls that carry the
memory order, sync scope, and volatility as explicit integer operands.

## The atomic type

`atomic_uint` / `atomic_int` are wrapper structs, not bare integers:

```llvm
%"struct.metal::_atomic" = type { i32 }
```

An `device atomic_uint*` argument is therefore a pointer to that struct; the
actual atomic operates on the `i32` field reached by a `getelementptr … i32 0`.

## `atomic_fetch_add`

```llvm
%10 = tail call i32 @air.atomic.global.add.u.i32(
          i32 addrspace(1)* nocapture %9,  ; pointer to the atomic's i32
          i32 %8,                          ; operand
          i32 0,                           ; memory order   -> relaxed
          i32 2,                           ; sync scope
          i1 true)                         ; volatile
```

Decoding the intrinsic name `air.atomic.global.add.u.i32`:

| Component | Meaning |
| --- | --- |
| `global` | the pointer's address space — `global` = `device` (`addrspace(1)`), `local` = `threadgroup` (`addrspace(3)`) |
| `add` | the operation |
| `u` | operand signedness — `u`nsigned; the signed forms use `s` (confirmed below) |
| `i32` | the value type |

### Operation and suffix coverage

From [`14_atomic_variants`](../harnesses/compute/14_atomic_variants.metal), the
full set of names emitted:

| MSL call | Intrinsic |
| --- | --- |
| `atomic_fetch_add` (unsigned) | `air.atomic.global.add.u.i32` |
| `atomic_fetch_sub` | `air.atomic.global.sub.u.i32` |
| `atomic_fetch_or` / `and` / `xor` | `air.atomic.global.{or,and,xor}.u.i32` |
| `atomic_fetch_min` on `atomic_int` | `air.atomic.global.min.**s**.i32` |
| `atomic_fetch_max` on `atomic_uint` | `air.atomic.global.max.**u**.i32` |
| `atomic_exchange` | `air.atomic.global.xchg.i32` |
| `atomic_load` | `air.atomic.global.load.i32` |
| `atomic_store` | `air.atomic.global.store.i32` |
| threadgroup `atomic_fetch_add` | `air.atomic.**local**.add.u.i32` |

The `.s`/`.u` tag only appears where signedness changes behaviour (min/max);
bitwise and additive ops use `.u` regardless of the atomic's signedness, and
`xchg`/`load`/`store` carry no sign tag at all.

The trailing scalar operands are the interesting part for a backend to
reproduce:

- **memory order** — always `0`. MSL supports **only** `memory_order_relaxed`:
  the standard library's `_explicit` overloads carry a static assertion
  (`METAL_VALID_MODIFY_ORDER` and friends) that rejects any other order at
  compile time, so this operand is `0` in every atomic in the harness set.
- **sync scope** — the memory scope the ordering applies over. Observed values:
  **`2` = device**, **`1` = threadgroup** (see the two calls below). The source
  uses the `thread_scope` enum (`thread_scope_thread` /`_simdgroup`
  /`_threadgroup` /`_device`).
- **volatile** — `i1 true`.

The device/threadgroup scope difference is visible directly — the same op on a
`device` vs a `threadgroup` atomic differs in both the intrinsic name
(`global`/`local`) and the scope operand (`2`/`1`):

```llvm
; device (addrspace 1): name has .global, scope operand 2
%11 = call i32 @air.atomic.global.min.s.i32(i32 addrspace(1)* %10, i32 %9, i32 0, i32 2, i1 true)
; threadgroup (addrspace 3): name has .local, scope operand 1
%20 = call i32 @air.atomic.local.add.u.i32 (i32 addrspace(3)* %19, i32 %9, i32 0, i32 1, i1 true)
```

## `atomic_compare_exchange_weak`

```llvm
%13 = call i32 @air.atomic.global.cmpxchg.weak.i32(
          i32 addrspace(1)* nocapture %12, ; pointer to the atomic
          i32* nocapture nonnull %5,       ; pointer to `expected` (updated on failure)
          i32 %8,                          ; desired
          i32 0, i32 0,                    ; success order, failure order
          i32 2,                           ; sync scope
          i1 true)                         ; volatile
```

Note that compare-exchange takes a **pointer** to `expected` (in the default
`thread`/private space, `addrspace(0)` — an `alloca`), matching the C++
`atomic_compare_exchange` signature that writes the observed value back on
failure. It also carries **two** memory orders (success and failure).

## Implications for a Swift backend

To emit atomics you cannot simply use LLVM's `atomicrmw`; you must:

1. model the atomic as a struct-wrapped integer,
2. call the correctly-named `air.atomic.<space>.<op>.<sign>.<type>` intrinsic,
3. thread the memory-order / scope / volatile integer operands through.

The `<space>` component means the *same* atomic operation on a `threadgroup`
atomic emits a different intrinsic name than on a `device` atomic — the address
space is baked into the symbol, not just the pointer type.
