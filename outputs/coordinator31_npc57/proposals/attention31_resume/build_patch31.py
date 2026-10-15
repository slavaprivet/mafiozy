from pathlib import Path
import hashlib, json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / 'outputs/coordinator31_npc57/game'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

pins = {}

def patch(rel, edits):
    source = SOURCE / rel
    text = source.read_text(encoding='utf-8')
    for before, after in edits:
        assert text.count(before) == 1, (rel, before, text.count(before))
        text = text.replace(before, after)
    target = HERE / 'patch' / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8', newline='\n')
    pins[rel] = {'base_sha256': sha(source), 'candidate_sha256': sha(target)}

patch('scripts/city/runtime/npc_threat_life30.gd', [
    ('const PHONE_SECONDS := 4.0', 'const PHONE_SECONDS := 4.0\nconst RECOVER_RETRY_SECONDS31 := 2.0\nconst FRESH_OBSERVATION_SECONDS31 := 1.0\nconst TURN_SPEED31 := 6.0'),
    ('func step(delta: float, row: Dictionary) -> bool:', '''func _recover31() -> void:
\t_phase="RECOVER";_age=0.0

func _face_known_threat31(body: CharacterBody3D, delta: float) -> void:
\t# Use only the observed point, never the hidden player's live position.
\t# Service/physical movement keeps authority over both travel and walking yaw.
\tif not bool(_event.get("source_identified",false)) or Vector2(body.velocity.x,body.velocity.z).length_squared()>.01:return
\tvar facing: Vector3=Vector3(_event.escape_from)-body.global_position
\tif facing.is_finite() and Vector2(facing.x,facing.z).length_squared()>.0001:
\t\tbody.rotation.y=lerp_angle(body.rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-TURN_SPEED31*delta))

func step(delta: float, row: Dictionary) -> bool:'''),
    ('if not _release_service(life):return false', 'if not _release_service(life):\n\t\t\t_face_known_threat31(life._token.body,delta)\n\t\t\treturn false'),
    ('\t\t_driver.hold(delta)\n\t\tif _age>=.8:', '\t\t_driver.hold(delta)\n\t\t_face_known_threat31(body,delta)\n\t\tif _age>=.8:'),
    ('if _driver.status=="idle" and not _start_leg(life):_phase="RECOVER"', 'if _driver.status=="idle" and not _start_leg(life):_recover31()'),
    ('else:_clear_phone();_phase="RECOVER"', 'else:_clear_phone();_recover31()'),
    ('elif result=="arrived" or _attempts>=3:_phase="RECOVER"', 'elif result=="arrived" or _attempts>=3:_recover31()'),
    ('if body.global_position.distance_to(_anchor)>.05:_clear_phone();_phase="RECOVER"', 'if body.global_position.distance_to(_anchor)>.05:_clear_phone();_recover31()'),
    ('_called=true;_clear_phone();_phase="RECOVER"', '_called=true;_clear_phone();_recover31()'),
    ('\telif _phase=="RECOVER":_driver.hold(delta)', '''\telif _phase=="RECOVER":
\t\t_driver.hold(delta)
\t\t_face_known_threat31(body,delta)
\t\t# Continuing visibility must not pin a frightened resident in one place.
\t\t# Retry bounded physical retreat after a short rest only while observation
\t\t# is fresh. Without renewed evidence the existing quiet deadline releases.
\t\tif _age>=RECOVER_RETRY_SECONDS31 and _world.get_ref()._now-_last_observation<=FRESH_OBSERVATION_SECONDS31:
\t\t\t_driver.cancel();_phase="FLEE";_age=0.0;_attempts=0'''),
])

patch('scripts/npc_visual/npc_attention29.gd', [
    ('\t\tif route != null and not route.attention_pause29(): return false', '''\t\tif route != null and not route.attention_pause29():
\t\t\t# A blocked service driver may be inactive while its outer EXIT_RETRY
\t\t\t# owner still runs. Face the focused player, but keep retry clocks and
\t\t\t# physical service dispatch running; attention takes no hold ownership.
\t\t\t_face_player31(body,delta)
\t\t\treturn false'''),
    ('''\tvar scene: Node = body.get_tree().current_scene
\tvar player: Node3D = scene.get("_player") as Node3D
\tvar facing: Vector3 = player.global_position - body.global_position
\tif Vector2(facing.x, facing.z).length_squared() > .0001:
\t\tbody.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))
\t# The existing host performs the sole skeleton/visual-yaw write.
\tbody.set_meta("npc_attention29", {"frame":Engine.get_physics_frames(), "active":true})
\treturn true''', '''\t_face_player31(body,delta)
\t# The existing host performs the sole skeleton/visual-yaw write.
\tbody.set_meta("npc_attention29", {"frame":Engine.get_physics_frames(), "active":true})
\treturn true

func _face_player31(body: CharacterBody3D, delta: float) -> void:
\tvar scene: Node = body.get_tree().current_scene
\tvar player: Node3D = scene.get("_player") as Node3D
\tif not is_instance_valid(player):return
\tvar facing: Vector3 = player.global_position - body.global_position
\tif Vector2(facing.x, facing.z).length_squared() > .0001:
\t\tbody.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))'''),
])
(HERE / 'PATCH.json').write_text(json.dumps(pins, indent=2)+'\n', encoding='utf-8')
print(json.dumps(pins))
