const LABELS={unlock_safe:'Вскрытие',unlock_door:'Взлом замка',breach_door:'Выбивание двери',cut_fence:'Резка',disable_power:'Отключение питания',revive:'Лечение',plant_bomb:'Закладка',intimidate:'Запугивание'};
const finite=Number.isFinite;
export function mercenaryActionTimerText(action,time){
 if(action?.awaiting||action?.phase==='awaiting')return 'Подтверждение действия';
 if(action?.armed||finite(action?.detonateAt)){
  if(action.waitingForSafety||action.phase==='retreat'&&action.detonateAt<=time)return 'Отходит на безопасное расстояние';
  if(!finite(action.detonateAt)||action.detonateAt<=time)return 'Подтверждение действия';
  return 'До взрыва · '+Math.ceil(action.detonateAt-time)+' с';
 }
 const label=LABELS[action?.kind];if(!label)return null;
 if(action.phase==='approach')return label+' · Подходит к цели';
 if(action.phase!=='working')return null;
 if(!finite(action.duration)||action.duration<=0||!finite(action.progress))return label;
 const remaining=action.duration*(1-Math.max(0,Math.min(1,action.progress)));
 if(remaining<=0)return 'Подтверждение действия';
 return label+' · '+(Math.ceil(remaining*10)/10).toFixed(1).replace('.',',')+' с';
}

// No gameplay clock, effect or mutation: only source receipts and cached bounds.
export function createMercenaryActionTimers({THREE,document:doc=globalThis.document,parent=doc?.body,camera,getHost=()=>null,getTarget=()=>null,getFocus=()=>null,nowSeconds=()=>Date.now()/1000,maxDistance=100}={}){
 if(!THREE||!doc?.createElement||!parent||!camera)throw Error('Action timers require Three, document, parent and camera');
 const overlay=doc.createElement('div');overlay.dataset.walkHud='mercenary-action-timers';overlay.setAttribute('aria-label','Действия специалистов');overlay.style.cssText='position:fixed;inset:0;z-index:9998;pointer-events:none;overflow:hidden';parent.append(overlay);
 const slots=[],active=new Map(),bounds=new WeakMap(),point=new THREE.Vector3(),view=new THREE.Vector3(),box=new THREE.Box3(),part=new THREE.Box3(),inverse=new THREE.Matrix4(),transform=new THREE.Matrix4(),instance=new THREE.Matrix4(),combined=new THREE.Matrix4();
 let disposed=false,pollElapsed=.1,width=0,height=0,polls=0,boundsComputed=0,visibleCount=0;
 function hide(slot){slot.node.hidden=true;slot.node.style.display='none';}
 function acquire(){let slot=slots.find(item=>!item.key);if(slot)return slot;if(slots.length>=10)return null;const node=doc.createElement('div');node.style.cssText='position:absolute;white-space:nowrap;transform:translate(-50%,-100%);padding:5px 10px;border:1px solid #a88c58;border-radius:5px;background:#201c1dec;color:#f2db9e;font:600 12px/1.4 system-ui;text-shadow:0 1px 2px #000;pointer-events:none';overlay.append(node);slot={node,key:null,target:null,anchor:null};hide(slot);slots.push(slot);return slot;}
 function localAnchor(object){let anchor=bounds.get(object);if(anchor)return anchor;object.updateWorldMatrix(true,true);inverse.copy(object.matrixWorld).invert();box.makeEmpty();const authored=object.userData?.mercenaryTarget?.highlightBounds;if(authored?.min?.length===3&&authored?.max?.length===3){box.min.fromArray(authored.min);box.max.fromArray(authored.max);}else object.traverse(node=>{if(!node.isMesh||!node.geometry||node.userData?.mercenaryPickIgnore)return;for(let p=node;p;p=p.parent){if(p.visible===false)return;if(p===object)break;}const geometry=node.geometry;if(!geometry.boundingBox)geometry.computeBoundingBox();if(!geometry.boundingBox||geometry.boundingBox.isEmpty())return;transform.multiplyMatrices(inverse,node.matrixWorld);if(node.isInstancedMesh){for(let i=0;i<node.count;i++){node.getMatrixAt(i,instance);combined.multiplyMatrices(transform,instance);box.union(part.copy(geometry.boundingBox).applyMatrix4(combined));}}else box.union(part.copy(geometry.boundingBox).applyMatrix4(transform));});boundsComputed++;anchor=new THREE.Vector3();if(box.isEmpty())anchor.set(0,1.9,0);else{box.getCenter(anchor);anchor.y=box.max.y+.25;}bounds.set(object,anchor);return anchor;}
 function poll(){
  polls++;const host=getHost(),rows=[],seen=new Set();let works=0,charges=0;const time=nowSeconds();
  const add=(action,memberId)=>{if(!action?.targetId)return;const charge=action.armed||finite(action.detonateAt)||action.kind==='plant_bomb'&&(action.awaiting||action.phase==='awaiting');if(charge?charges>=5:works>=5)return;const key=String(action.id??action.actionId??action.requestId??'member:'+memberId);if(seen.has(key))return;const text=mercenaryActionTimerText(action,time);if(!text)return;seen.add(key);rows.push({key,text,targetId:action.targetId});if(charge)charges++;else works++;};
  for(const charge of host?.getCharges?.()||[])add({...charge,armed:true},charge.memberId);
  for(const pending of host?.getPendingTransactions?.()||[])add({...pending,awaiting:true,phase:'awaiting'},pending.memberId);
  const roster=host?.getRoster?.(),members=Array.isArray(roster)?roster:roster?.members||[];for(const member of members.slice(0,5))add(host?.getAction?.(member.id),member.id);
  for(const [key,slot]of active)if(!seen.has(key)){active.delete(key);slot.key=null;slot.target=null;slot.anchor=null;hide(slot);}
  for(const row of rows){let slot=active.get(row.key);if(!slot){slot=acquire();if(!slot)continue;slot.key=row.key;active.set(row.key,slot);}if(slot.node.textContent!==row.text)slot.node.textContent=row.text;slot.target=getTarget(row.targetId);slot.anchor=slot.target?.object?.isObject3D?localAnchor(slot.target.object):null;}
  width=parent.clientWidth||doc.documentElement?.clientWidth||doc.defaultView?.innerWidth||0;height=parent.clientHeight||doc.documentElement?.clientHeight||doc.defaultView?.innerHeight||0;
 }
 function updatePresentation(dt=0){
  if(disposed)return;pollElapsed+=finite(dt)?Math.max(0,dt):0;if(pollElapsed>=.1){pollElapsed=0;poll();}visibleCount=0;if(!active.size)return;
  camera.updateWorldMatrix(true,false);const focus=getFocus();
  for(const slot of active.values()){
   const target=slot.target,object=target?.object;if(!target||target.valid===false||width<=0||height<=0){hide(slot);continue;}
   if(object?.isObject3D){let shown=!!object.parent;for(let p=object;p&&shown;p=p.parent)if(p.visible===false)shown=false;if(!shown){hide(slot);continue;}object.updateWorldMatrix(true,false);point.copy(slot.anchor).applyMatrix4(object.matrixWorld);}
   else if(target.position&&finite(target.position.x)&&finite(target.position.z))point.set(target.position.x,(Number(target.position.y)||0)+(target.kind==='npc'||target.kind==='player'?1.9:.8),target.position.z);
   else{hide(slot);continue;}
   if(focus&&Math.hypot(point.x-focus.x,point.z-focus.z)>maxDistance){hide(slot);continue;}
   view.copy(point).applyMatrix4(camera.matrixWorldInverse);if(view.z>=0){hide(slot);continue;}point.project(camera);
   const x=(point.x*.5+.5)*width,y=(-point.y*.5+.5)*height,padding=Math.max(70,slot.node.textContent.length*3.6);
   if(!finite(x)||!finite(y)||point.z< -1||point.z>1||x<padding||x>width-padding||y<26||y>height){hide(slot);continue;}
   slot.node.style.left=x.toFixed(1)+'px';slot.node.style.top=y.toFixed(1)+'px';slot.node.hidden=false;slot.node.style.display='block';visibleCount++;
  }
 }
 function dispose(){if(disposed)return;disposed=true;for(const slot of slots)hide(slot);active.clear();slots.length=0;overlay.remove();}
 return{element:overlay,updatePresentation,dispose,stats:()=>({active:active.size,pooled:slots.length,visible:visibleCount,polls,boundsComputed,disposed})};
}
