"""Adapt the real-input lifecycle regression to also observe shared service cleanup."""
import pathlib

OUT = pathlib.Path(__file__).resolve().parent
qa = OUT/'qa'
source = (qa/'observer_death28.gd').read_text(encoding='utf-8')
needle = '\tif _pop.hit_owners.size()!=1:_finish("one_resident_contract");return false\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '''\tvar staff: Node=scene.get("preview_venue_staff29")
\tvar sites: Node=scene.get("preview_service_sites29")
\tif not is_instance_valid(staff) or staff._rows.size()!=12 or not is_instance_valid(sites) or sites.current_sites().size()!=8:_finish("final_staff_sites_missing");return false
''')
needle = '\t\t\t_dead_frames+=1\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '''\t\t\tvar registry: RefCounted=get_tree().current_scene.get_meta("npc_venue_registry29",null)
\t\t\tif registry==null:_finish("venue_registry_missing");return
\t\t\tif registry._actors.size()!=0 or registry.ledger.requests.size()!=0 or registry._service29.keys.size()!=0:_finish("dead_service_claim_retained");return
''')
(qa/'observer_death54.gd').write_text(source, encoding='utf-8')
entry = (qa/'entry_death28.gd').read_text(encoding='utf-8').replace('observer_death28.gd', 'observer_death54.gd')
(qa/'entry_death54.gd').write_text(entry, encoding='utf-8')
print('Final death observer prepared; production unchanged.')
