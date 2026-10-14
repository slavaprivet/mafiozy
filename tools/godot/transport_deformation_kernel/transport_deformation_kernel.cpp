#include "transport_deformation_kernel.h"
#include <cmath>

namespace mafiozi::transport {
namespace {
constexpr std::size_t kNodeCount = 45;
bool finite3(const float* value) noexcept {
  return std::isfinite(value[0]) && std::isfinite(value[1]) &&
         std::isfinite(value[2]);
}
} // namespace

DeformationStatus deform_surface(const DeformationInput& in,
                                 const DeformationOutput& out) noexcept {
  if (!in.base_xyz || !in.vertex_binding || !in.node_indices_8 ||
      !in.node_weights_8 || !in.node_offsets_xyz ||
      !in.inverse_basis_columns_9 || !out.unique_local_xyz ||
      !out.displaced_xyz || !out.displacement_xyz ||
      !out.flat_normals_xyz) return DeformationStatus::null_buffer;
  if (!in.vertex_count || in.vertex_count % 3 || !in.binding_count)
    return DeformationStatus::invalid_count;
  for (std::size_t n = 0; n < kNodeCount; ++n)
    if (!finite3(in.node_offsets_xyz + n * 3))
      return DeformationStatus::nonfinite_input;
  for (std::size_t i = 0; i < 9; ++i)
    if (!std::isfinite(in.inverse_basis_columns_9[i]))
      return DeformationStatus::nonfinite_input;

  const double* e = in.inverse_basis_columns_9;
  for (std::size_t binding = 0; binding < in.binding_count; ++binding) {
    double dx = 0.0, dy = 0.0, dz = 0.0;
    const std::size_t begin = binding * 8;
    for (std::size_t corner = 0; corner < 8; ++corner) {
      const std::uint8_t node = in.node_indices_8[begin + corner];
      const double weight = in.node_weights_8[begin + corner];
      if (node >= kNodeCount) return DeformationStatus::node_out_of_range;
      if (!std::isfinite(weight)) return DeformationStatus::nonfinite_input;
      const float* offset = in.node_offsets_xyz + std::size_t(node) * 3;
      dx += double(offset[0]) * weight;
      dy += double(offset[1]) * weight;
      dz += double(offset[2]) * weight;
    }
    float* local = out.unique_local_xyz + binding * 3;
    local[0] = float(e[0] * dx + e[3] * dy + e[6] * dz);
    local[1] = float(e[1] * dx + e[4] * dy + e[7] * dz);
    local[2] = float(e[2] * dx + e[5] * dy + e[8] * dz);
    if (!finite3(local)) return DeformationStatus::nonfinite_result;
  }

  for (std::size_t vertex = 0; vertex < in.vertex_count; ++vertex) {
    const std::uint32_t binding = in.vertex_binding[vertex];
    if (binding >= in.binding_count)
      return DeformationStatus::binding_out_of_range;
    const float* local = out.unique_local_xyz + std::size_t(binding) * 3;
    const float* base = in.base_xyz + vertex * 3;
    if (!finite3(base)) return DeformationStatus::nonfinite_input;
    float* displacement = out.displacement_xyz + vertex * 3;
    float* position = out.displaced_xyz + vertex * 3;
    for (std::size_t axis = 0; axis < 3; ++axis) {
      displacement[axis] = local[axis];
      // Source BufferAttribute ultimately stores Float32.
      position[axis] = float(double(base[axis]) + double(local[axis]));
    }
    if (!finite3(position)) return DeformationStatus::nonfinite_result;
  }

  for (std::size_t triangle = 0; triangle < in.vertex_count; triangle += 3) {
    const float* a = out.displaced_xyz + triangle * 3;
    const float* b = a + 3;
    const float* c = b + 3;
    const double abx = double(b[0]) - a[0];
    const double aby = double(b[1]) - a[1];
    const double abz = double(b[2]) - a[2];
    const double acx = double(c[0]) - a[0];
    const double acy = double(c[1]) - a[1];
    const double acz = double(c[2]) - a[2];
    double nx = aby * acz - abz * acy;
    double ny = abz * acx - abx * acz;
    double nz = abx * acy - aby * acx;
    if (!std::isfinite(nx) || !std::isfinite(ny) || !std::isfinite(nz))
      return DeformationStatus::nonfinite_result;
    const double length = std::sqrt(nx * nx + ny * ny + nz * nz);
    if (!std::isfinite(length)) return DeformationStatus::nonfinite_result;
    if (length > 0.0) { nx /= length; ny /= length; nz /= length; }
    else { nx = 0.0; ny = 0.0; nz = 0.0; }
    for (std::size_t corner = 0; corner < 3; ++corner) {
      float* normal = out.flat_normals_xyz + (triangle + corner) * 3;
      normal[0] = float(nx); normal[1] = float(ny); normal[2] = float(nz);
      if (!finite3(normal)) return DeformationStatus::nonfinite_result;
    }
  }
  return DeformationStatus::ok;
}

} // namespace mafiozi::transport
