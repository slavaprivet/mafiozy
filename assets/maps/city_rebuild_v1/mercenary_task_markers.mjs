import {createMercenarySelectionView} from './mercenary_selection_view.mjs';

// Presentation-only queue receipts. Never starts, cancels or advances a job.
export function createMercenaryTaskMarkers({THREE,scene,document:doc,parent=doc?.body,camera,getFocus=()=>null,getRoots=null,getOcclusionRoots=null,getActors=()=>[],maxVisible=10}={}){
 const cap=Math.max(1,Math.min(10,maxVisible)),overlay=doc.createElement('div'),records=new Map(),pool=[],world=new THREE.Vector3(),clip=new THREE.Vector3(),eye=new THREE.Vector3(),cameraPos=new THREE.Vector3(),direction=new THREE.Vector3(),ray=new THREE.Raycaster(),occlusionEnabled=typeof getRoots==='function'||typeof getOcclusionRoots==='function';
 // Deliberately not data-walk-hud: this transparent annotation layer must not
 // become a fullscreen occlusion mask for the existing friendly name badges.
 overlay.dataset.mercenaryQueueMarkers='';overlay.style.cssText='position:fixed;inset:0;pointer-events:none;overflow:hidden;z-index:9997';parent.append(overlay);
 let disposed=false,shown=0,totalBuilds=0,clock=0,lastRayAt=-Infinity,raycasts=0;
 const done=t=>!t?.object?.isObject3D||t.valid===false||t.invalid||t.completed||t.opened||t.destroyed||t.wrecked||t.object.userData.mercenaryOpened||t.object.userData.mercenaryTarget?.opened||t.kind==='fence'&&(t.cut||t.object.userData.mercenaryCut)||t.kind==='power_panel'&&(t.powered===false||t.disabled);
 const hide=r=>{r.node.hidden=true;r.node.style.display='none';};
 const roofAnchors=new WeakMap();
 function roofAnchor(object){let cached=roofAnchors.get(object);if(cached)return cached;const box=new THREE.Box3(),inverse=new THREE.Matrix4(),matrix=new THREE.Matrix4(),instance=new THREE.Matrix4(),point=new THREE.Vector3();object.updateWorldMatrix(true,true);inverse.copy(object.matrixWorld).invert();object.traverse(node=>{if(!node.isMesh||!node.geometry?.attributes?.position)return;for(let p=node;p;p=p.parent){if(!p.visible||p.userData?.mercenaryPickIgnore)return;if(p===object)break;}const local=node.geometry.boundingBox||new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position),count=node.isInstancedMesh?node.count:1;for(let i=0;i<count;i++){matrix.multiplyMatrices(inverse,node.matrixWorld);if(node.isInstancedMesh){node.getMatrixAt(i,instance);matrix.multiply(instance);}for(let x=0;x<2;x++)for(let y=0;y<2;y++)for(let z=0;z<2;z++){point.set(x?local.max.x:local.min.x,y?local.max.y:local.min.y,z?local.max.z:local.min.z).applyMatrix4(matrix);box.expandByPoint(point);}}});cached=box.isEmpty()?new THREE.Vector3():new THREE.Vector3((box.min.x+box.max.x)/2,box.max.y,(box.min.z+box.max.z)/2);roofAnchors.set(object,cached);return cached;}
 function acquire(){let r=pool.find(r=>!r.id);if(r)return r;if(pool.length>=cap)return null;const node=doc.createElement('div');node.setAttribute('aria-label','Задание специалиста');node.style.cssText='position:absolute;display:none;transform:translate(-50%,-100%);min-width:25px;padding:4px 7px;box-sizing:border-box;border:1px solid;border-radius:12px;background:#18201fdd;color:#e4e9dc;font:700 13px/1.2 system-ui;text-align:center;pointer-events:none;box-shadow:0 1px 5px #0005';overlay.append(node);r={node,id:null,object:null,view:null,anchor:new THREE.Vector3(),state:null};pool.push(r);return r;}
 function release(r){r.id=null;r.object=null;r.view?.setTarget(null);hide(r);}
 function sync(rows=[],aimed=null){
  if(disposed)return new Set();const chosen=[],seen=new Set();
  // Current jobs from every member precede pending jobs, so long queues cannot
  // displace another specialist's current work from the bounded marker budget.
  const candidates=rows.filter(r=>r?.target&&!done(r.target)).slice().sort((a,b)=>(a.queued?1:0)-(b.queued?1:0)||(a.number||1)-(b.number||1));
  const aimId=aimed&&!done(aimed)?String(aimed.id):null,aimIndex=candidates.findIndex(r=>String(r.target.id)===aimId);
  if(aimIndex>=cap){const row=candidates.splice(aimIndex,1)[0];candidates.splice(cap-1,0,row);}
  const externalAim=aimId!==null&&aimIndex<0,limit=cap-(externalAim&&aimed.kind!=='vehicle'?1:0);
  for(const row of candidates){const id=String(row.target.id);if(seen.has(id)||chosen.length>=limit)continue;seen.add(id);chosen.push({...row,id});}
  const keep=new Set(chosen.map(r=>r.id));for(const[id,r]of records)if(!keep.has(id)){records.delete(id);release(r);}
  for(const row of chosen){const t=row.target;let r=records.get(row.id);if(!r){r=acquire();if(!r)continue;r.id=row.id;records.set(row.id,r);}
   if(r.object!==t.object){r.object=t.object;r.view?.setTarget(null);if(t.kind==='vehicle')r.anchor.copy(roofAnchor(t.object));else r.anchor.set(0,t.kind==='npc'||t.kind==='player'?(t.downed||t.hp<=0?.65:2.1):1.6,0);r.checkedAt=-Infinity;r.occluded=occlusionEnabled;r.worldPoint ||=new THREE.Vector3();}
   if(t.kind!=='vehicle'){
    if(!r.view)r.view=createMercenarySelectionView({THREE,scene});const before=r.view.stats().outlineBuilds;r.view.setTarget({...t,working:!row.queued,queued:!!row.queued});totalBuilds+=r.view.stats().outlineBuilds-before;
    const b=t.object.getObjectByName('Mercenary_Object_Focus_Arcs')?.userData.focusBounds;if(b)r.anchor.set((b.min[0]+b.max[0])/2,b.max[1]+.30,(b.min[2]+b.max[2])/2);
   }else r.view?.setTarget(null);
   const color=row.queued?'#d4aa62':'#79d6a0';r.node.style.color=color;r.node.style.borderColor=color;const label=String(row.number||1);if(r.node.textContent!==label)r.node.textContent=label;r.node.dataset.taskTarget=row.id;r.node.dataset.taskNumber=label;r.node.dataset.taskState=row.queued?'queued':'working';
   const state=row.queued?'В очереди':'Выполняется';r.node.setAttribute('aria-label',`${row.memberName||'Специалист'} · ${state} · №${label}`);r.node.title=`${row.memberName||'Специалист'} · ${state} · №${label}`;r.state=state;r.target=t;
  }
  return new Set(chosen.map(r=>r.id));
 }
 function update(dt=0){if(disposed)return;clock+=Math.max(0,dt);shown=0;let nextCheck=null;const w=parent.clientWidth||doc.documentElement?.clientWidth||doc.defaultView?.innerWidth||0,h=parent.clientHeight||doc.documentElement?.clientHeight||doc.defaultView?.innerHeight||0,focus=getFocus();camera.updateWorldMatrix(true,false);camera.getWorldPosition(cameraPos);
  for(const r of records.values()){
   r.view?.update(dt);if(done(r.target)){r.view?.setTarget(null);hide(r);continue;}let visible=true,attached=false;for(let p=r.object;p;p=p.parent){if(!p.visible)visible=false;if(p.isScene)attached=true;}
   if(!visible||!attached||!w||!h){hide(r);continue;}r.object.updateWorldMatrix(true,false);world.copy(r.anchor).applyMatrix4(r.object.matrixWorld);if(r.target.kind==='vehicle')world.y+=.18;if(focus&&world.distanceToSquared(focus)>10000){hide(r);continue;}
   eye.copy(world).applyMatrix4(camera.matrixWorldInverse);clip.copy(world).project(camera);if(eye.z>=0||clip.z< -1||clip.z>1||Math.abs(clip.x)>1||Math.abs(clip.y)>1){hide(r);continue;}r.worldPoint.copy(world);if(occlusionEnabled&&(!nextCheck||r.checkedAt<nextCheck.checkedAt))nextCheck=r;r.node.style.left=((clip.x*.5+.5)*w).toFixed(1)+'px';r.node.style.top=((-clip.y*.5+.5)*h).toFixed(1)+'px';r.node.hidden=r.occluded;r.node.style.display=r.occluded?'none':'block';if(!r.occluded)shown++;
  }
  // Same opaque-material and ignored-actor policy as friendly badges, bounded
  // to one indexed ray every 50 ms (at most ten visible annotation targets).
  if(nextCheck&&clock-lastRayAt>=.05){lastRayAt=clock;const r=nextCheck,wasHidden=r.occluded;r.checkedAt=clock;r.occluded=false;direction.copy(r.worldPoint).sub(cameraPos);ray.far=Math.max(0,direction.length()-.12);direction.normalize();ray.set(cameraPos,direction);const ignored=new Set((getActors()||[]).map(a=>a?.object||a?.actor?.object).filter(Boolean));ignored.add(r.object);const roots=((getOcclusionRoots?getOcclusionRoots(cameraPos,direction,ray.far):getRoots?.())||[]).map(a=>a?.object||a).filter(a=>a?.isObject3D&&!ignored.has(a));if(roots.length){raycasts++;r.occluded=ray.intersectObjects(roots,true).some(hit=>{for(let p=hit.object;p;p=p.parent)if(p.visible===false||ignored.has(p)||p.userData?.mercenaryPickIgnore||p.userData?.isHero)return false;const materials=Array.isArray(hit.object.material)?hit.object.material:[hit.object.material];return materials.some(m=>m&&m.visible!==false&&(!m.transparent||m.opacity>=.8));});}r.node.hidden=r.occluded;r.node.style.display=r.occluded?'none':'block';if(wasHidden&&!r.occluded)shown++;else if(!wasHidden&&r.occluded)shown--;}
 }
 return{sync,update,clear:()=>sync(),stats:()=>({active:records.size,visible:shown,pooled:pool.length,geometryBuilds:totalBuilds,cap,raycasts}),dispose(){if(disposed)return;disposed=true;for(const r of pool)r.view?.dispose();records.clear();pool.length=0;overlay.remove();}};
}
