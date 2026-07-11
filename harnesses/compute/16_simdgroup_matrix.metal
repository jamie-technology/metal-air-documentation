// Feature: SIMD-group matrix multiply (the classic matmul instruction).
// Demonstrates: simdgroup_matrix<T, Cols, Rows>, simdgroup_load / _store against
// device memory, make_filled_simdgroup_matrix, and simdgroup_multiply_accumulate
// — the cooperative 8x8 matrix-multiply hardware op that predates the newer
// tensor types. Surfaces the air.simdgroup_matrix_* intrinsics.
#include <metal_stdlib>
using namespace metal;

kernel void sgemm8x8(device const float* A [[buffer(0)]],
                     device const float* B [[buffer(1)]],
                     device float*       C [[buffer(2)]],
                     uint sgitg [[simdgroup_index_in_threadgroup]])
{
    simdgroup_matrix<float, 8, 8> a, b;
    simdgroup_load(a, A, /*elements_per_row=*/8);
    simdgroup_load(b, B, 8);

    // c = a * b + 0
    simdgroup_matrix<float, 8, 8> c = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
    simdgroup_multiply_accumulate(c, a, b, c);

    simdgroup_store(c, C, 8);
}
