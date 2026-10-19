from pathlib import Path
here=Path(__file__).resolve().parent
source=(here/'entry_geometry58.gd').read_text(encoding='utf-8')
source=source.replace('while float(Time.get_ticks_usec()-begin)/1000000.0<30.0:', 'while float(Time.get_ticks_usec()-begin)/1000000.0<30.0 or Engine.get_physics_frames()-begin_frame<1800:')
source=source.replace('evidence.native_ticks>=1790','evidence.native_ticks>=1800')
(here/'entry_geometry58_v3.gd').write_text(source,encoding='utf-8')
c4=(here/'entry_c4_homes58.gd').read_text(encoding='utf-8').replace('extends "entry_geometry58.gd"','extends "entry_geometry58_v3.gd"')
(here/'entry_c4_homes58.gd').write_text(c4,encoding='utf-8')
runner=(here/'run_geometry58_v2.py').read_text(encoding='utf-8').replace('entry_geometry58.gd','entry_c4_homes58.gd')
runner=runner.replace("Path(__file__),run/", "HERE/'entry_geometry58_v3.gd',Path(__file__),run/")
runner=runner.replace('>160:', '>220:').replace('owned startup+30s stability watchdog','owned startup+30s native stability+C4 watchdog')
runner=runner.replace('housing geometry/native support; not sleep, C4 blast or performance acceptance','housing geometry/native support/C4; not sleep or performance acceptance')
(here/'run_c4_homes58.py').write_text(runner,encoding='utf-8')
