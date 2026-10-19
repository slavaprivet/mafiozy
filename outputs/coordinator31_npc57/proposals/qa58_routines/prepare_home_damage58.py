from pathlib import Path
here=Path(__file__).resolve().parent
source=(here/'entry_c4_homes58.gd').read_text(encoding='utf-8')
source=source.replace('var house: Node3D=homes.current_sites()[0]','var house: Node3D=homes.registry58.assigned("resident_3").house.get_ref()')
source=source.replace('mouse58(true);mouse58(false);await step58(2)', 'if has_method("mark_damage58"):call("mark_damage58")\n\tmouse58(true);mouse58(false);await step58(2)')
source=source.replace('var max_bed_travel:=0.0','var max_bed_travel:=0.0\n\tvar native_unfrozen: bool=not mattress.freeze')
source=source.replace('max_bed_travel=maxf(max_bed_travel,mattress.global_position.distance_to(bed_start))','max_bed_travel=maxf(max_bed_travel,mattress.global_position.distance_to(bed_start))\n\t\tnative_unfrozen=native_unfrozen or not mattress.freeze')
source=source.replace('"bed_travel_m":max_bed_travel','"bed_unfrozen_observed":native_unfrozen,"bed_travel_m":max_bed_travel')
source=source.replace('mattress.get_meta("detached",false) and not mattress.freeze and max_bed_travel>.10','mattress.get_meta("detached",false) and native_unfrozen and max_bed_travel>.10')
source=source.replace('var generation: int=house.rebuild_generation','if has_method("wait_exit58"):await call("wait_exit58")\n\tvar generation: int=house.rebuild_generation')
(here/'entry_c4_home_damage58.gd').write_text(source,encoding='utf-8')
p=here/'entry_home_damage58.gd'
content=p.read_text(encoding='utf-8').replace('extends "entry_c4_homes58.gd"','extends "entry_c4_home_damage58.gd"')
content+='''
func mark_damage58() -> void:
	component.damage_trigger_frame=Engine.get_physics_frames()

func wait_exit58() -> void:
	var deadline: int=Time.get_ticks_msec()+60000
	while component.home.active() and Time.get_ticks_msec()<deadline:
		await process_frame
'''
p.write_text(content,encoding='utf-8')
source=(here/'run_c4_homes58.py').read_text(encoding='utf-8')
source=source.replace('stage58_04','stage58_05')
start=source.index('    patch=read(');end=source.index('    scheduler=',start)
source=source[:start]+"    run=HERE/'runs'/name;run.mkdir(parents=True,exist_ok=False)\n"+source[end:]
start=source.index('    controls=');end=source.index('    command=',start)
source=source[:start]+'''    files=['entry_geometry58_v3.gd','entry_c4_home_damage58.gd','entry_home_damage58.gd','home_damage_driver58.gd']
    controls=[manifest,scheduler,lock,assembly,ROOT/'godot/current_version.json',Path(__file__),*[HERE/f for f in files]]
    cp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS.json',cp)
    with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for p in controls:archive.write(p,p.relative_to(ROOT).as_posix())
'''+source[end:]
source=source.replace("[str(engine),'--headless','--path'", "[str(engine),'--path'")
source=source.replace('entry_c4_homes58.gd','entry_home_damage58.gd')
source=source.replace("probe('headless'", "probe('graphical'").replace("Lease('headless'", "Lease('graphical'")
source=source.replace('>220:', '>360:').replace('owned startup+30s native stability+C4 watchdog','owned original-resident sleep+C4 interruption watchdog')
source=source.replace('housing geometry/native support/C4; not sleep or performance acceptance','original resident3 sleep+C4+exit+reset; component only, not natural or performance acceptance')
(here/'run_home_damage58.py').write_text(source,encoding='utf-8')
