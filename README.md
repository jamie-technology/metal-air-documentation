# Metal AIR documentation

The missing documentation for Apple's AIR representation.

## Goals

Document AIR comprehensively by generating small MSL examples that demo a specific set of features each, then inspecting the resulting AIR from the Metal compiler and documenting it.

We actually want to make a fork of Swift that supports writing GPU kernels that compile to AIR.

## Layout

- docs/
    - Where the documentation of the AIR format will live
- harnesses/
    - compute/
        - Compute MSL shaders
    - graphics/
        - Graphical MSL shaders