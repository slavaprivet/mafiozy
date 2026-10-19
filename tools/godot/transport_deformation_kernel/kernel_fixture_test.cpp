#include "transport_deformation_kernel.h"
#include "kernel_fixture_data.h"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <vector>

int main() {
  using namespace mafiozi::transport;
  namespace f = mafiozi::transport::fixture;
  const std::size_t count = f::base.size() / 3;
  const std::size_t supports = f::nodes.size() / 8;
  std::vector<float> local(supports * 3), positions(count * 3),
      displacement(count * 3), normals(count * 3);
  DeformationInput in{f::base.data(), count, f::bindings.data(),
      f::nodes.data(), f::weights.data(), supports, f::offsets.data(),
      f::inverse.data()};
  DeformationOutput out{local.data(), positions.data(), displacement.data(),
      normals.data()};
  if (deform_surface(in, out) != DeformationStatus::ok) return 1;
  double position_error = 0, normal_error = 0;
  for (std::size_t i = 0; i < count * 3; ++i) {
    if (!std::isfinite(positions[i]) || !std::isfinite(normals[i])) return 2;
    position_error = std::max(position_error,
        std::abs(double(positions[i]) - f::expected_positions[i]));
    normal_error = std::max(normal_error,
        std::abs(double(normals[i]) - f::expected_normals[i]));
  }
  if (position_error > 3e-6 || normal_error > 5e-5) return 3;
  auto invalid = in;
  invalid.base_xyz = nullptr;
  if (deform_surface(invalid, out) != DeformationStatus::null_buffer) return 4;
  invalid = in;
  invalid.vertex_count = 1;
  if (deform_surface(invalid, out) != DeformationStatus::invalid_count) return 5;
  std::vector<float> bad_offsets(f::offsets.begin(), f::offsets.end());
  bad_offsets[0] = std::numeric_limits<float>::infinity();
  invalid = in;
  invalid.node_offsets_xyz = bad_offsets.data();
  if (deform_surface(invalid, out) != DeformationStatus::nonfinite_input) return 6;
  std::vector<std::uint8_t> bad_nodes(f::nodes.begin(), f::nodes.end());
  bad_nodes[0] = 45;
  invalid = in;
  invalid.node_indices_8 = bad_nodes.data();
  if (deform_surface(invalid, out) != DeformationStatus::node_out_of_range) return 7;
  std::vector<double> overflowing_basis(f::inverse.begin(), f::inverse.end());
  std::fill(overflowing_basis.begin(), overflowing_basis.end(),
      std::numeric_limits<double>::max());
  invalid = in;
  invalid.inverse_basis_columns_9 = overflowing_basis.data();
  if (deform_surface(invalid, out) != DeformationStatus::nonfinite_result) return 8;
  std::cout << "SOURCE_KERNEL_PASS vertices=" << count
      << " position_error=" << position_error
      << " normal_error=" << normal_error << '\n';
  return 0;
}
