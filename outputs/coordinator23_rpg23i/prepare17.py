from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2]
base=root/'outputs/coordinator23_quality/candidate16'
dst=root/'outputs/coordinator23_quality/candidate17'
assert not dst.exists(),dst
shutil.copytree(base,dst,ignore=shutil.ignore_patterns('exports'))
game=dst/'godot/mafiozi_walk'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
changes={}
def edit(name, pairs):
 p=game/name;before=sha(p);s=p.read_text(encoding='utf8')
 for old,new in pairs:
  assert s.count(old)==1,(name,old[:100],s.count(old))
  s=s.replace(old,new)
 p.write_text(s,encoding='utf8',newline='\n')
 changes[name]={'before':before,'after':sha(p),'source':'Root23 actual ammo/Flight/RPG gate composition'}
proposal=root/'outputs/coordinator23_rpg23i/npc_proposal'
for row in json.loads((proposal/'RECEIPT.json').read_text(encoding='utf8'))['files']:
 p=game/row['path'];src=proposal/p.name
 assert sha(src)==row['proposal_sha256']
 before=sha(p) if p.exists() else None
 assert before==row.get('base_sha256')
 shutil.copy2(src,p)
 changes[row['path']]={'before':before,'after':sha(p),'source':str(src.relative_to(root))}
edit('scripts/weapons/rpg_effects.gd',[
 ('## Original source rocket geometry + explosion animation. Cosmetic only.','## Original rocket/visual pool. Optional typed local NPC gate owns damage admission.'),
 ('\tvar hit: Dictionary = _host.get_ref()._projectile_ray(request)','\tvar host: Node = _host.get_ref()\n\t# The configured gate replaces this query; denial never falls through to another ray.\n\tif host.npc_rpg_gate != null: return host.npc_rpg_gate.native_query(self,request)\n\tvar hit: Dictionary = host._projectile_ray(request)'),
 ('\tvar host: Node = _host.get_ref()\n\tvar result: Dictionary = _flight.prepare_launch(shot,receipt,host.inventory.get_item_uid("rpg"),direction.normalized())','\tif not shot.get("projectiles") is Array or shot.projectiles.size()!=1: return {"ok":false,"reason":"projectile"}\n\tvar projectile: Dictionary = shot.projectiles[0]\n\tfor key: String in ["yawOffset","pitchOffset"]:\n\t\tvar value: Variant = projectile.get(key)\n\t\tif not (value is int or value is float) or not is_finite(float(value)): return {"ok":false,"reason":"spread"}\n\t# This local Fire shot has not passed through a world-admitted final aim.\n\t# Use its already sampled offsets exactly once, in original source order.\n\tdirection=direction.normalized().rotated(Vector3.UP,float(projectile.yawOffset))\n\tvar right:=direction.cross(Vector3.UP)\n\tif right.length_squared()>1e-8: direction=direction.rotated(right.normalized(),float(projectile.pitchOffset))\n\tvar host: Node = _host.get_ref()\n\tvar result: Dictionary = _flight.prepare_launch(shot,receipt,host.inventory.get_item_uid("rpg"),direction.normalized())'),
 ('func _impact(receipt: Dictionary) -> void:\n\tif not _live(): return\n\t_impacts += 1','func _impact(receipt: Dictionary) -> void:\n\tif not _live(): return\n\tvar gate: RefCounted = _host.get_ref().npc_rpg_gate\n\tif gate != null:\n\t\tgate.native_impact(self,receipt)\n\t\t# A recipient/context callback can tear down the entire scene synchronously.\n\t\tif not _live(): return\n\t_impacts += 1'),
 ('# One outward event, only for source scorch hook and diagnostics. No HP/AoE.','# This outward event remains cosmetic; only the consumed native callback above admits HP.')
])
edit('scripts/weapons/preview_weapons.gd',[
 ('const RpgEffects = preload("res://scripts/weapons/rpg_effects.gd")','const RpgEffects = preload("res://scripts/weapons/rpg_effects.gd")\nconst RpgGate = preload("res://scripts/npc_visual/npc_rpg_blast_gate.gd")'),
 ('var rpg_effects: RefCounted','var rpg_effects: RefCounted\nvar npc_rpg_gate: RefCounted\nvar rpg_admission: Dictionary = {}'),
 ('func _owner_current() -> bool:','func configure_npc_rpg(resident_host: RefCounted, owners: Array[RefCounted]) -> Dictionary:\n\tif npc_rpg_gate != null or not _owner_current() or owners.size()!=3: return {"ok":false,"reason":"rpg_binding"}\n\tvar gate := RpgGate.new()\n\tvar result: Dictionary = gate.configure(self,resident_host,owners,Callable(owners[0],"current_damage_context"))\n\tif not result.get("ok",false): gate.dispose(); return result\n\tnpc_rpg_gate=gate\n\treturn result\n\nfunc _owner_current() -> bool:'),
 ('\t\tif not _settle_pending(true): rpg_effects.cancel_shot(prepared.ticket); return\n\t\t# Both commits are synchronous; preflight already ran all external ports.\n\t\tvar emitted: bool=rpg_effects.commit_shot(prepared.ticket)\n\t\tassert(emitted,"Reserved RPG launch must commit with accepted inventory")','\t\tvar gate_ticket: RefCounted\n\t\tif npc_rpg_gate != null:\n\t\t\trpg_admission=npc_rpg_gate.before_ammo_commit(rpg_effects,prepared.ticket)\n\t\t\tif not rpg_admission.get("ok",false):\n\t\t\t\trpg_effects.cancel_shot(prepared.ticket); _settle_pending(false); return\n\t\t\tgate_ticket=rpg_admission.ticket\n\t\tif not _settle_pending(true):\n\t\t\tif gate_ticket != null: npc_rpg_gate.cancel_ammo_commit(gate_ticket)\n\t\t\trpg_effects.cancel_shot(prepared.ticket); return\n\t\t# Inventory and actual Flight commits remain consecutive, without external callbacks.\n\t\tvar emitted: bool=rpg_effects.commit_shot(prepared.ticket)\n\t\tif not emitted:\n\t\t\tif gate_ticket != null: npc_rpg_gate.cancel_ammo_commit(gate_ticket)\n\t\t\trpg_admission={"ok":false,"reason":"reserved_flight_commit_failed"}\n\t\t\tpush_error("Accepted RPG ammo could not commit its reserved Flight")\n\t\t\treturn\n\t\tif gate_ticket != null:\n\t\t\trpg_admission=npc_rpg_gate.after_ammo_commit(rpg_effects,gate_ticket)\n\t\t\t# No refund/retry or cosmetic damage fallback: a denied flight query retires it.\n\t\t\tif not rpg_admission.get("ok",false): push_error("RPG native admission rejected: "+str(rpg_admission))'),
 ('func _exit_tree() -> void:\n\tif aim_camera!=null: aim_camera.dispose()','func _exit_tree() -> void:\n\tif npc_rpg_gate != null: npc_rpg_gate.dispose()\n\tif aim_camera!=null: aim_camera.dispose()')
])
edit('scripts/preview_population.gd',[
 ('var combat_status := "unbound"','var combat_status := "unbound"\nvar _rpg_gate: RefCounted'),
 ('\t\t\tresidents._records[row.source_id]["walk_pause"] = Callable(owner,"should_pause_walk")\n\treturn true','\t\t\tresidents._records[row.source_id]["walk_pause"] = Callable(owner,"should_pause_walk")\n\t\tvar rpg_link: Dictionary = scene.preview_weapons.configure_npc_rpg(residents,hit_owners)\n\t\tif not rpg_link.get("ok",false): return _fail("native_rpg_owner:"+str(rpg_link))\n\t\t_rpg_gate=scene.preview_weapons.npc_rpg_gate\n\treturn true'),
 ('\t_disposed = true\n\tif _final_dead_contact_port != null:','\t_disposed = true\n\tif _rpg_gate != null: _rpg_gate.dispose(); _rpg_gate=null\n\tif _final_dead_contact_port != null:')
])
edit('export_presets.cfg', [('export_files=PackedStringArray(', 'export_files=PackedStringArray("res://scripts/npc_visual/npc_rpg_blast_gate.gd", ')])
(dst/'INTEGRATION.json').write_text(json.dumps({'parent':'candidate16','status':'RPG17 isolated; authentic combined/GPU pending','changes':changes},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'candidate':str(dst),'changed':list(changes)},ensure_ascii=False))
