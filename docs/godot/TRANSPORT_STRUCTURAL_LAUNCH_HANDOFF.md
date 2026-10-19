# Structural detached-part launch — frozen source adapter

scripts/transport/transport_vehicle_structural_launch.gd SHA2a5dea8c700ab8bf1688b6a17d18fcb95a4ab666a06425b6b87aac7795dd1e8e.
scripts/tests/test_transport_vehicle_structural_launch.gd SHA29e73a3f001790c966b538a30b490531fe9e2e38329fb94179f651415602b4bf.
tools/godot/export_transport_structural_launch_oracle.mjs SHA24f169ebf25b94844e29acb573333dae765307193eb832ebc9e262c6b14919a7.
data/transport/structural_launch_oracle.json SHA8408d57fb173c3b2ffd455d02a1c266e773a3d1c61fb8751f59b59a923bfb2f6.

API static launch(part_id,impact_count,normal_native,impact_speed_mps,signed_speed_mps,travel_yaw_native). Returns explicit native linear/angular velocities, source mass24kg wheel/18kg other, source_seed_u32, deterministic_sine_draws6 and shared_rng_draws0. Pure calculation; no HP, identity/event authority or physical spawn.

Actual vehicle_crash.mjs detach lines127-135 source SHA cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44. Crucial JS binary64 full identifier reduce before final >>>0 is retained, including long-ID floating rounding. Source impact0 falls back8, cap24; signed speed remains unbounded. Normal is supplied unchanged; native polar/axial X/Z sign conversion applied once. Host must pass the actual post-impact source impact count, actual travel yaw/contact normal.

88 author+88 independent parent headless checks PASS; all12 logical part IDs, independent first-impact seed table and mixed hood/wheel examples, overflow/cap/fallback/signed-speed cases and malformed inputs. Authored missing rear doors are not created by this helper. Trunk owns special existing detachment/cargo path; do not clone twice.

No loaded-scene cost/FPS measured; this helper performs a bounded identifier loop and six sine evaluations per admitted part. Actual geometry cloning/collision preparation remains separate, currently benchmarked to resolve damaged-part refresh before same-frame detachment. Native physical flight deliberately uses actual world collisions per direct user instruction, not the original analytic floor sampler trajectory. Main/Git/LIVE Root21.
