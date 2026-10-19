"""Create an additive observer package without changing any tested harness."""
from pathlib import Path
import hashlib
import json

base = Path(__file__).resolve().parent.parent
old = base / 'qa58_merged'
new = base / 'qa58_merged_v4'
new.mkdir(exist_ok=False)
names = ['run58.py', 'archive_harness31.py', 'audit_spatial_liveness31.py',
         'entry_soak31_extended.gd', 'observer_soak31_v3.gd', 'observer_soak31_v2.gd',
         'observer_mass_extended.gd', 'observer_perf_extended.gd']
for name in names:
    (new / name).write_bytes((old / name).read_bytes())
entry = new / 'entry_soak31_extended.gd'
entry.write_text(entry.read_text().replace('observer_soak31_v3.gd', 'observer_soak58_v4.gd'), encoding='utf-8')
runner = new / 'run58.py'
s = runner.read_text().replace("OUT / 'observer_soak31_v3.gd',", "OUT / 'observer_soak58_v4.gd', OUT / 'observer_soak31_v3.gd',")
s = s.replace("record['actual_measurement_elapsed_s'] = native['actual_measurement_elapsed_s']\n            record['physical_ticks_per_wall_second'] = record['physical_ticks_observed'] / record['actual_measurement_elapsed_s']", "record['serialization_elapsed_s'] = native['actual_measurement_elapsed_s']\n            record['native_frame_elapsed_s'] = native['frame_at_s'][-1]\n            record['native_frame_duration_sum_s'] = sum(frames) / 1000.0\n            record['actual_measurement_elapsed_s'] = record['native_frame_elapsed_s']\n            record['physical_ticks_per_wall_second'] = record['physical_ticks_observed'] / record['native_frame_elapsed_s']")
runner.write_text(s, encoding='utf-8')
print('New observer package copied; old harness unchanged')
