"""Gate expensive diagnostic serialization; retain bounded native performance counters."""
import json,pathlib
OUT=pathlib.Path(__file__).resolve().parent;GAME=OUT.parent.parent/'game'
helper='scripts/city/runtime/npc_runtime_trace30.gd'
text='''extends RefCounted
## Explicit troubleshooting only; errors and semantic state remain unconditional.
static var _enabled := -1
static func enabled() -> bool:
\tif _enabled<0:_enabled=1 if OS.get_cmdline_user_args().has("--city-debug-trace30=1") else 0
\treturn _enabled==1
'''
(OUT/helper).parent.mkdir(parents=True,exist_ok=True);(OUT/helper).write_text(text,encoding='utf-8')
changes=[{'file':'scripts/hospital/npc_simple_hospital.gd','before':'func _emit(result: String) -> void:\n\t_event=result','after':'func _emit(result: String) -> void:\n\t_event=result\n\tif not preload("res://scripts/city/runtime/npc_runtime_trace30.gd").enabled():return'}]
rel='scripts/npc_city_population.gd'
changes.extend([
 {'file':rel,'before':'\t\t_city_fallback_ring_cache = 19','after':'\t\t_city_fallback_ring_cache = 24 # Resident25 starts 44.2m from the nearest dry cell; 384 probes stay below512.'},
 {'file':rel,'before':'int(argument.trim_prefix("--city-spawn-rings=")), 16, 19)','after':'int(argument.trim_prefix("--city-spawn-rings=")), 16, 24)'},
])
source=(GAME/rel).read_text(encoding='utf-8')
for line in source.splitlines():
    if any('print("'+tag in line for tag in ['DSH_PHYS ','DSH_STEPSPERFRAME ','DSH_NAVSTEP ','DSH_CITY ','DSH_PERF ']):
        changes.append({'file':rel,'before':line,'after':line[:len(line)-len(line.lstrip())]+'if preload("res://scripts/city/runtime/npc_runtime_trace30.gd").enabled():'+line.lstrip()})
(OUT/'HUNKS.json').write_text(json.dumps({'changes':changes,'helper':helper,'retained':'Every simulation and bounded timing counter; only verbose JSON/floor debug query and recurring console diagnostics gated'},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'hunks':len(changes),'helper':helper}))
