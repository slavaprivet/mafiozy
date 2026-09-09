from pathlib import Path
p=Path('assets/maps/city_rebuild_v1/walk_preview.mjs');raw=p.read_bytes();s=raw.decode('utf-8')
def rep(a,b):
 global s
 assert s.count(a)==1,a[:70]
 s=s.replace(a,b,1)
rep("position:fixed;left:16px;top:72px;z-index:80;max-width:360px", "position:fixed;left:280px;top:70px;z-index:80;width:350px;max-height:80vh;overflow:auto")
rep('anchor:()=>hero.object.position.clone().add(new THREE.Vector3(0,0,-7))','anchor:hero.object.position.clone().add(new THREE.Vector3(0,0,-12))')
rep('parent,document});', '''parent,document});
  npcGallery.panel.style.position='relative';npcGallery.panel.style.top='0';npcGallery.panel.style.left='0';
  const showGallery=npcGallery.gallery.populate;npcGallery.gallery.populate=async rows=>{const records=await showGallery(rows);if(records.length){setFreeMouse(false);const center=new THREE.Vector3();records.forEach(r=>center.add(r.actor.object.position));center.divideScalar(records.length);controls.target.copy(center).y+=1;camera.position.copy(center).add(new THREE.Vector3(9,7,14));camera.lookAt(controls.target);}return records;};''')
rep("addEventListener('pagehide',()=>{npcPopulation?.dispose();", "addEventListener('pagehide',()=>{npcPopulation?.dispose();npcGallery?.dispose();worldWalkCombat?.dispose();worldWalkMelee?.dispose();")
assert p.read_bytes()==raw
p.write_bytes(s.encode('utf-8'))
