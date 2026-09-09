from pathlib import Path
p=Path('assets/maps/city_rebuild_v1/walk_preview.mjs')
raw=p.read_bytes();s=raw.decode('utf-8')
def replace(old,new):
 global s
 if s.count(old)!=1: raise RuntimeError('Expected one match: '+old[:80])
 s=s.replace(old,new,1)
replace("import {createNpcPopulation} from './npc_population.mjs';", "import {createNpcPopulation,npcWeaponId} from './npc_population.mjs';\nimport {createWorldWalkCombat} from './world_walk_combat.mjs';")
replace('let npcPopulation=null,npcBridge=window.Mafiozi3DBridge||null;', 'let npcPopulation=null,npcBridge=window.Mafiozi3DBridge||null,worldWalkCombat=null;')
replace('async function initNpcPopulation(){','''async function initNpcPopulation(){
 if(npcBridge)worldWalkCombat=createWorldWalkCombat({THREE,bridge:npcBridge,getActors:()=>npcPopulation?.getActors()||[],obstacles:()=>[content,...(fleet?.records.map(r=>r.car.object)||[])]});
 window.addEventListener('artist14:confirmed-hit',event=>{const hit=event.detail;if(hit?.targetId)npcPopulation?.receive(hit.targetId,hit);});''')
replace('walking:!!keys.size,stance:heroPosture.target','walking:[...keys].some(key=>[\'KeyW\',\'KeyA\',\'KeyS\',\'KeyD\'].includes(key)),stance:heroPosture.target')
replace('function updateCombat(dt,moving=false,running=false){','''function syncWorldWeapon(){
 if(!npcBridge)return;
 const source=npcBridge.getPlayerState(),id=npcWeaponId(source.weapon);
 if(currentWeapon.id!==id){artistInput.cancel();releaseWeapon();hero?.mountWeapon(null);disposeWeapon(weaponModel);weaponModel=null;currentWeapon=ARSENAL.find(w=>w.id===id);if(id!=='none'){weaponModel=createWeaponModel({THREE,id});hero?.mountWeapon(weaponModel)}}
 const state=fireState();state.magazine=source.magazine||0;state.reserveAmmo=source.reserve||0;
}
function updateCombat(dt,moving=false,running=false){
 syncWorldWeapon();''')
old='const result=stepWeaponFire(fireState(),{triggerHeld:allowed&&triggerHeld,triggerPressed:allowed&&triggerPressed,reload:allowed&&reloadPressed,aiming,posture,moving,running},dt);'
new='''const fireInput={triggerHeld:allowed&&triggerHeld,triggerPressed:allowed&&triggerPressed,reload:allowed&&reloadPressed,aiming,posture,moving,running};
 const result=worldWalkCombat?worldWalkCombat.step(fireState(),fireInput,dt,{origin:weaponModel?resolveWeaponShotTransforms(THREE,weaponModel).origin:null,forward:camera.getWorldDirection(new THREE.Vector3())}):stepWeaponFire(fireState(),fireInput,dt);'''
replace(old,new)
replace('for(const shot of combat.result.shots)effects.shoot(shot,transforms,target,obstacles);','for(const shot of combat.result.shots)effects.shoot(shot,transforms,shot.worldTarget||target,obstacles);')
replace('function equipWeapon(id){','''function equipWeapon(id){
 if(npcBridge?.selectWalkWeapon){const result=npcBridge.selectWalkWeapon(id);syncWorldWeapon();updateWeaponUi();return result.accepted;}''')
assert p.read_bytes()==raw,'Concurrent edit; retry from fresh bytes'
p.write_bytes(s.encode('utf-8'))
