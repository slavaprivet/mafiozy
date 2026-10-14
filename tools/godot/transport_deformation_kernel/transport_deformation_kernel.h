#pragma once
#include <cstddef>
#include <cstdint>

namespace mafiozi::transport {

enum class DeformationStatus : std::uint8_t {
  ok = 0,
  null_buffer,
  invalid_count,
  binding_out_of_range,
  node_out_of_range,
  nonfinite_input,
  nonfinite_result,
};

// Pure-data surface input. Matrix values are three column vectors in the same
// order as Godot Basis / Three Matrix3 elements:
// x=e[0]*dx+e[3]*dy+e[6]*dz, etc.
struct DeformationInput {
  const float* base_xyz;
  std::size_t vertex_count;
  const std::uint32_t* vertex_binding;
  const std::uint8_t* node_indices_8;
  const double* node_weights_8;
  std::size_t binding_count;
  const float* node_offsets_xyz; // exactly 45 nodes
  const double* inverse_basis_columns_9;
};

// Caller-owned, correctly sized, non-overlapping staging buffers.
// The wrapper must reject size multiplication overflow and aliasing before the
// call, and discard every output buffer on any non-ok status. unique_local_xyz
// is scratch retained only so a future Godot wrapper controls all allocation.
struct DeformationOutput {
  float* unique_local_xyz;       // binding_count * 3
  float* displaced_xyz;          // vertex_count * 3
  float* displacement_xyz;       // vertex_count * 3
  float* flat_normals_xyz;        // vertex_count * 3
};

DeformationStatus deform_surface(const DeformationInput& input,
                                 const DeformationOutput& output) noexcept;

} // namespace mafiozi::transport
