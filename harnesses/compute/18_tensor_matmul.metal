// Feature: Metal 4 cooperative tensor-ops matmul (the AI matmul instruction).
// Demonstrates: mpp::tensor_ops::matmul2d from MetalPerformancePrimitives — a
// cooperative, multi-SIMD-group tiled matmul over `tensor<>` operands. This is
// the highest-level "AI" primitive: C = A x B computed by 4 SIMD-groups working
// together. Surfaces the air.* cooperative-matmul intrinsics and the tensor
// slice/offset machinery. Requires -std=metal4.0.
// STD: metal4.0
#include <metal_stdlib>
#include <MetalPerformancePrimitives/MetalPerformancePrimitives.h>
using namespace metal;
using namespace mpp::tensor_ops;

kernel void tensor_matmul(tensor<device half,  dextents<int32_t, 2>> A [[buffer(0)]],
                          tensor<device half,  dextents<int32_t, 2>> B [[buffer(1)]],
                          tensor<device float, dextents<int32_t, 2>> C [[buffer(2)]],
                          uint2 tgid [[threadgroup_position_in_grid]])
{
    // 64x32 tile = A(64xK) * B(Kx32); K read dynamically from the tensors.
    constexpr auto desc = matmul2d_descriptor(
        64, 32, static_cast<int>(dynamic_extent),
        /*transpose_left=*/false, /*transpose_right=*/false,
        /*relaxed_precision=*/false);

    matmul2d<desc, execution_simdgroups<4>> op;

    // Per-threadgroup slices of the global tensors.
    auto mA = A.slice(0,            tgid.y * 64);
    auto mB = B.slice(tgid.x * 32,  0);
    auto mC = C.slice(tgid.x * 32,  tgid.y * 64);

    op.run(mA, mB, mC);  // assumes C pre-zeroed
}
