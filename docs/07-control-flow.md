# Control flow

Harness: [`compute/09_control_flow`](../harnesses/compute/09_control_flow.metal).

Control flow in AIR is **plain LLVM IR** — `br`, `switch`, `phi`, `select`, and
the standard basic-block CFG. There is nothing GPU-specific at this level; thread
divergence and reconvergence are handled by the GPU backend *below* AIR, not
represented in it. This is good news for a Swift backend: ordinary LLVM control
flow lowering just works.

## Branches and phi nodes

An `if/else` where both arms produce a value becomes a conditional branch that
reconverges at a `phi`:

```llvm
%24 = phi i32 [ %22, %21 ], [ 0, %9 ], [ %20, %12 ]
```

Each `[ value, predecessor-block ]` pair says which value flows in from which
predecessor. The optimizer built this from the `if (v < 0) … else …` plus the
loop below it.

## Loops

The bounded `for` loop lowers to a back-edge with `!llvm.loop` metadata marking
the latch (from the `-O0` output, which keeps the structure legible):

```llvm
23:                                       ; preds = %32, %22   <- loop header
  %24 = phi i32 …                          ; induction variable
  %27 = icmp ult i32 %24, %26
  br i1 %27, label %28, label %35          ; exit test
28:                                        ; loop body
  …
  br label %32
32:                                        ; latch
  br label %23, !llvm.loop !23             ; back-edge
```

The `!llvm.loop` metadata carries loop hints (unroll, etc.); it is standard LLVM,
not an AIR extension.

## Switches

A `switch` on a small integer stays a `switch` instruction — the front-end does
not pre-lower it to a chain of branches:

```llvm
switch i32 %25, label %32 [   ; %32 = default
    i32 0, label %26
    i32 1, label %28
    i32 2, label %30
]
%35 = phi i32 [ %33, %32 ], [ %31, %30 ], [ %29, %28 ], [ %27, %26 ]
```

The four incoming edges reconverge at a single `phi`, one value per case.

## `select`

Short, side-effect-free conditionals become `select` rather than branches, just
as in host LLVM — e.g. the ternary in the function-constants harness. This keeps
the CFG flat, which matters more on a GPU than a CPU because branches can force
divergence.

## Implications for a Swift backend

This is the one area needing **no special handling**: emit the same LLVM CFG you
would for any target. The two things worth doing deliberately are

- prefer `select` / branchless forms where the source allows, since flat control
  flow avoids divergence penalties on the GPU, and
- keep `!llvm.loop` hints if your frontend has them — the AIR backend honours the
  standard metadata.
