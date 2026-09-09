from pathlib import Path
p=Path('assets/maps/city_rebuild_v1/walk_preview.mjs');raw=p.read_bytes();s=raw.decode('utf-8')
def replace(a,b):
 global s
 assert s.count(a)==1,a[:90]
 s=s.replace(a,b,1)
replace("import {createWorldWalkCombat} from './world_walk_combat.mjs';","import {createWorldWalkCombat} from './world_walk_combat.mjs';\nimport {createNpcGalleryHost} from './npc_gallery_host.mjs';")
replace('worldWalkCombat=null;','worldWalkCombat=null,npcGallery=null;')
replace("window.addEventListener('artist14:confirmed-hit',event=>{const hit=event.detail;if(hit?.targetId)npcPopulation?.receive(hit.targetId,hit);});", "window.addEventListener('artist14:confirmed-hit',event=>queueMicrotask(()=>{const hit=worldWalkCombat?.resolveConfirmedReceipt(event);if(hit?.targetId)npcPopulation?.receive(hit.targetId,hit);}));")
replace("walkShell.querySelector('footer').append(status);", """walkShell.querySelector('footer').append(status);
 if(new URLSearchParams(location.search).get('npcgallery')==='1'){
  const parent=document.createElement('div');parent.style.cssText='position:fixed;left:16px;top:72px;z-index:80;max-width:360px';walkShell.append(parent);
  npcGallery=await createNpcGalleryHost({THREE,scene,loader,cloneSkeleton:cloneNpcSkeleton,groundHeight,anchor:()=>hero.object.position.clone().add(new THREE.Vector3(0,0,-7)),parent,document});
 }
""")
replace('artistUpdate(dt,moved,running);updateNpcPopulation(dt);','artistUpdate(dt,moved,running);updateNpcPopulation(dt);npcGallery?.update(dt);')
assert p.read_bytes()==raw,'Concurrent edit'
p.write_bytes(s.encode('utf-8'))
