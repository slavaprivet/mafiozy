// Opt-in /walk?carqa=1 controls. Every hit uses the existing contact/damage API.
export function createVehicleVisualQa(T,{document,panel,getRecord,onContact,onRelease=()=>{}}){
 panel.style.maxWidth='350px';panel.style.maxHeight='calc(100vh - 140px)';panel.style.overflowY='auto';panel.style.zIndex='1000';
 const nodes=[],position=new T.Vector3(),target=new T.Vector3();let view='normal',disposed=false;
 const fxStatus=document.createElement('span');fxStatus.setAttribute('role','status');fxStatus.setAttribute('aria-label','QA: состояние эффектов');fxStatus.style.flexBasis='100%';panel.append(fxStatus);nodes.push(fxStatus);
 const add=(label,action)=>{const b=document.createElement('button');b.textContent=label;b.setAttribute('aria-label',label);b.onclick=action;panel.append(b);nodes.push(b);return b};
 const contact=(side,speed)=>{const r=getRecord();if(!r)return;const yaw=r.state.yaw,p=r.car.profile,x=side==='rear'?0:side==='left'?p.halfWidth:-p.halfWidth,z=side==='rear'?-p.halfLength:0,nx=side==='rear'?0:Math.sign(x),nz=side==='rear'?-1:0;r.car.object.updateWorldMatrix(true,false);onContact({point:r.car.object.localToWorld(new T.Vector3(x,.85,z)),normal:{x:nx*Math.cos(yaw)+nz*Math.sin(yaw),y:0,z:-nx*Math.sin(yaw)+nz*Math.cos(yaw)},impactSpeed:speed,slideSpeed:0})};
 for(const [label,side,speed]of [['QA: удар справа','right',16],['QA: удар сзади','rear',18]])add(label,()=>contact(side,speed));
 add('QA: возгорание',()=>{const r=getRecord();if(!r||r.damage.disabled)return;r.damage.blastImpact({damage:Math.max(0,r.damage.state.hp-Math.floor(r.damage.state.maxHp*.18)),eventId:'visual-ignite-'+Date.now()})});
 add('QA: взрыв',()=>{const r=getRecord();if(r&&!r.damage.disabled)r.damage.blastImpact({damage:r.damage.state.maxHp*3,eventId:'visual-blast-'+Date.now()})});
 for(const [label,next]of [['QA: вид на колёса','wheels'],['QA: вид на салон','cabin'],['QA: вид на огонь','fire'],['QA: обычный вид','normal']])add(label,()=>{onRelease();view=next});
 const label=document.createElement('label'),slow=document.createElement('input');slow.type='checkbox';slow.setAttribute('aria-label','QA: замедление ×5');label.append(slow,' QA: замедление ×5');panel.append(label);nodes.push(label);
 // The normal camera is untouched unless a visible inspection view is chosen.
 function applyCamera(camera,controls){
  if(disposed)return;const r=getRecord();if(!r)return;const state=r.damage.state,label=state.wrecked?(state.wreckAge<.9?'Вспышка взрыва':state.wreckAge<5?'Дым после взрыва':'Обгоревший кузов'):state.destroying?'До взрыва: '+Math.max(0,state.destroyRemaining).toFixed(1)+' с':state.burning?'Машина горит':'Машина цела';if(fxStatus.textContent!==label)fxStatus.textContent=label;
  if(view==='normal')return;const p=r.car.profile,front=r.car.wheels.find(w=>w.front)?.restPosition?.z??p.wheelBase*.5;
  if(view==='wheels'){target.set(p.halfWidth*.65,p.wheelRadius||.4,front);position.set(p.halfWidth+3,1.10,front+1.65)}
  else if(view==='cabin'){const seat=r.car.seats?.[0]?.anchor;target.set(seat?.side||0,(seat?.y||.4)+.9,seat?.front||0);position.set(p.halfWidth+2.1,p.height*.72,(seat?.front||0)+1.1)}
  else{const e=r.car.hoodSpec?.engineBounds;target.set(0,p.height*.65,e?(e.min[2]+e.max[2])*.5:p.halfLength*.55);position.set(p.halfWidth+5,p.height+2,p.halfLength+5)}
  r.car.object.updateWorldMatrix(true,false);r.car.object.localToWorld(position);r.car.object.localToWorld(target);camera.position.copy(position);controls.target.copy(target);camera.lookAt(target);camera.updateMatrixWorld();
 }
 return{get timeScale(){return slow.checked?.2:1},applyCamera,reset(){view='normal';slow.checked=false},dispose(){disposed=true;for(const n of nodes)n.remove()}};
}
