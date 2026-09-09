from pathlib import Path
p=Path('assets/maps/city_rebuild_v1/walk_preview.mjs');raw=p.read_bytes();s=raw.decode('utf-8')
def replace(a,b):
 global s
 assert s.count(a)==1,a[:90]
 s=s.replace(a,b,1)
replace("import {createWorldWalkCombat} from './world_walk_combat.mjs';","import {createWorldWalkCombat} from './world_walk_combat.mjs';\nimport {createWorldWalkMeleeInput} from './world_walk_melee_input.mjs';\nimport {createWorldWalkMeleeHost} from './world_walk_melee_host.mjs';")
replace('const artistInput=createArtist14Input({now:()=>performance.now()/1000}),artistPose=createArtist14Pose(THREE);','let artistInput=createArtist14Input({now:()=>performance.now()/1000});const artistPose=createArtist14Pose(THREE);')
replace('worldWalkCombat=null,npcGallery=null;','worldWalkCombat=null,npcGallery=null,worldWalkMelee=null;')
replace('async function initNpcPopulation(){','''async function initNpcPopulation(){
 if(npcBridge){artistInput=createWorldWalkMeleeInput({bridge:npcBridge});worldWalkMelee=createWorldWalkMeleeHost({THREE,bridge:npcBridge,getHero:()=>hero,getActors:()=>npcPopulation?.getActors()||[],obstacles:()=>[content,...(fleet?.records.map(r=>r.car.object)||[])]});}''')
replace('const hit=worldWalkCombat?.resolveConfirmedReceipt(event);if(hit?.targetId)npcPopulation?.receive(hit.targetId,hit);',"const hit=event.detail?.kind==='melee'?worldWalkMelee?.resolveConfirmedReceipt(event):worldWalkCombat?.resolveConfirmedReceipt(event);if(hit?.targetId)npcPopulation?.receive(hit.targetId,{...hit,id:hit.shotId});")
replace('updateNpcPopulation(dt);npcGallery?.update(dt);','updateNpcPopulation(dt);worldWalkMelee?.update(artistAction);npcGallery?.update(dt);')
assert p.read_bytes()==raw,'Concurrent edit'
p.write_bytes(s.encode('utf-8'))
