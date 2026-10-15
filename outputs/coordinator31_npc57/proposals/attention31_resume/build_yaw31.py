from pathlib import Path
import hashlib, json

here=Path(__file__).resolve().parent
game=here.parents[3]/'outputs/coordinator31_npc57/game'
rows=[]
for rel,old,new in [
 ('scripts/city/runtime/npc_threat_life30.gd',
  '\t\tbody.rotation.y=lerp_angle(body.rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-TURN_SPEED31*delta))',
  '\t\t# A rigid capsule must stay unit scale. Repeated Euler setters can carry\n\t\t# accumulated float scale from the host basis into later route admission.\n\t\tvar yaw: float=lerp_angle(body.rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-TURN_SPEED31*delta))\n\t\tbody.basis=Basis(Vector3.UP,yaw)'),
 ('scripts/npc_visual/npc_attention29.gd',
  '\t\tbody.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))',
  '\t\t# This actor is a rigid upright capsule; do not accumulate Euler scale.\n\t\tvar yaw: float = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))\n\t\tbody.basis = Basis(Vector3.UP, yaw)')]:
    source=game/rel
    text=source.read_text(encoding='utf-8')
    assert text.count(old)==1,rel
    dest=here/'patch_yaw31'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(text.replace(old,new),encoding='utf-8',newline='\n')
    rows.append({'path':rel,'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'candidate':str(dest)})
(here/'PATCH_YAW31.json').write_text(json.dumps({'files':rows,'scope':'Stationary threat/attention yaw preserves the unit rigid capsule; surface safety unchanged'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows,ensure_ascii=False))
