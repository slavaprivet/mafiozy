// Presentation and physical geometry only. The source owns permissions, money,
// inventory and persistence. Sending a command is not an accepted receipt.
const pools=new WeakMap();
const OPEN_ANGLE=-Math.PI*112/180,OPEN_SECONDS=.85;
const BODY_BOXES=[
 {p:[-.396,.66,0],s:[.068,1.24,.68]},
 {p:[ .396,.66,0],s:[.068,1.24,.68]},
 {p:[0,.074,0],s:[.724,.068,.68]},
 {p:[0,1.246,0],s:[.724,.068,.68]},
 {p:[0,.66,-.306],s:[.724,1.104,.068]},
];
const DOOR_BOX={p:[.369,.66,.008],s:[.738,1.108,.104]};
// The whole rotating leaf stays inside this hinge-centred disc. Include its
// wheel/locking bars, not just the thinner source collision rectangle.
const DOOR_SWEEP_RADIUS=.80;
// Root is at the centre of the steel body; the dial/wheel project towards +Z.
export const INTERIOR_SAFE_DIMENSIONS=Object.freeze({width:.86,height:1.28,depth:.88,bodyDepth:.68,rear:-.34,front:.54,openReach:1.12});
const finite=(v,f=0)=>Number.isFinite(Number(v))?Number(v):f;

function roundedBox(T){
 const g=new T.BoxGeometry(1,1,1,2,2,2),p=g.attributes.position,n=g.attributes.normal,v=new T.Vector3(),c=new T.Vector3(),d=new T.Vector3();
 for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);c.copy(v).clampScalar(-.465,.465);d.copy(v).sub(c).normalize();v.copy(c).addScaledVector(d,.035);p.setXYZ(i,v.x,v.y,v.z);n.setXYZ(i,d.x,d.y,d.z)}
 return g;
}
function acquirePool(T){
 let pool=pools.get(T);if(pool){pool.refs++;return pool}
 const primitives={box:roundedBox(T),cylinder:new T.CylinderGeometry(.5,.5,1,16),ring:new T.TorusGeometry(.5,.085,5,24),sphere:new T.SphereGeometry(.5,12,8)};
 const matrix=new T.Matrix4(),quaternion=new T.Quaternion(),scale=new T.Vector3(),position=new T.Vector3(),normalMatrix=new T.Matrix3(),point=new T.Vector3(),normal=new T.Vector3(),color=new T.Color();
 function bake(parts){
  const positions=[],normals=[],colors=[],indices=[];
  for(const part of parts){
   const g=primitives[part.shape||'box'],p=g.attributes.position,n=g.attributes.normal,base=positions.length/3;
   position.fromArray(part.p);scale.fromArray(part.s);quaternion.setFromEuler(new T.Euler(...(part.r||[0,0,0])));matrix.compose(position,quaternion,scale);normalMatrix.getNormalMatrix(matrix);color.set(part.c);
   for(let i=0;i<p.count;i++){point.fromBufferAttribute(p,i).applyMatrix4(matrix);normal.fromBufferAttribute(n,i).applyMatrix3(normalMatrix).normalize();positions.push(point.x,point.y,point.z);normals.push(normal.x,normal.y,normal.z);colors.push(color.r,color.g,color.b)}
   if(g.index)for(const i of g.index.array)indices.push(base+i);else for(let i=0;i<p.count;i++)indices.push(base+i);
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('normal',new T.Float32BufferAttribute(normals,3));g.setAttribute('color',new T.Float32BufferAttribute(colors,3));g.setIndex(indices);g.computeBoundingBox();g.computeBoundingSphere();return g;
 }
 const steel='#46545a',edge='#778184',dark='#212b31',brass='#b59559',paper='#c7c4a9',band='#667d69';
 const body=BODY_BOXES.map(b=>({...b,c:steel}));
 // A genuine open cavity, shelf, rolled front frame, raised hinge barrels and feet.
 body.push({p:[0,.685,-.025],s:[.715,.027,.525],c:edge});
 for(const x of[-.391,.391])body.push({p:[x,.66,.344],s:[.047,1.21,.045],c:edge});
 for(const y of[.083,1.237])body.push({p:[0,y,.344],s:[.737,.04,.045],c:edge});
 for(const x of[-.335,.335])for(const z of[-.255,.255])body.push({p:[x,.025,z],s:[.15,.05,.14],c:dark});
 for(const y of[.325,1.025])body.push({shape:'cylinder',p:[-.367,y,.366],s:[.052,.15,.052],c:brass});
 const door=[{...DOOR_BOX,c:steel},{p:[.369,.66,.068],s:[.635,1.008,.024],c:dark},{p:[.369,.66,.084],s:[.599,.972,.02],c:steel}];
 for(const x of[.062,.676])door.push({p:[x,.66,.08],s:[.014,1.002,.012],c:brass});
 for(const y of[.165,1.155])door.push({p:[.369,y,.08],s:[.616,.014,.012],c:brass});
 // Dial, readable index, wheel hub and three substantial spokes catch real light.
 const disc=(x,y,z,radius,thickness,c)=>({shape:'cylinder',p:[x,y,z],s:[radius*2,thickness,radius*2],r:[Math.PI/2,0,0],c});
 door.push(disc(.285,.88,.113,.075,.032,brass),disc(.285,.88,.133,.052,.018,dark));
 for(let i=0;i<12;i++){const a=i*Math.PI/6;door.push({p:[.285+Math.sin(a)*.042,.88+Math.cos(a)*.042,.145],s:[.007,i%3===0?.014:.008,.004],r:[0,0,-a],c:paper})}
 door.push({p:[.285,.969,.105],s:[.012,.026,.012],c:brass});
 door.push(disc(.47,.635,.117,.045,.045,brass),{shape:'ring',p:[.47,.635,.171],s:[.24,.24,.19],c:edge});
 for(let i=0;i<3;i++){const a=i*Math.PI*2/3;door.push({p:[.47+Math.sin(a)*.054,.635+Math.cos(a)*.054,.169],s:[.021,.126,.022],r:[0,0,-a],c:brass})}
 // The inner plate and actual locking bars remain visible after the door opens.
 door.push({p:[.369,.66,-.051],s:[.61,.98,.025],c:edge});
 for(const y of[.35,.94])door.push({p:[.628,y,-.078],s:[.235,.04,.038],c:brass});
 door.push({p:[.525,.65,-.073],s:[.034,.65,.029],c:dark},{p:[.37,1.06,.11],s:[.135,.049,.014],c:brass});
 const loot=[];
 for(const [x,y,z]of[[-.2,.735,-.1],[.04,.735,-.08],[.19,.155,-.15]]){
  loot.push({p:[x,y,z],s:[.185,.058,.285],c:paper},{p:[x,y+.032,z],s:[.038,.007,.289],c:band});
  for(const dy of[-.011,.008])loot.push({p:[x,y+dy,z+.144],s:[.177,.003,.002],c:'#a4a88e'});
 }
 const bag=[{shape:'sphere',p:[0,.22,0],s:[.46,.44,.34],c:'#93815c'},{shape:'cylinder',p:[0,.45,0],s:[.14,.12,.11],c:'#ae9c75'},{shape:'ring',p:[0,.42,0],s:[.16,.035,.13],r:[Math.PI/2,0,0],c:'#4d3c26'},{p:[0,.22,.163],s:[.14,.16,.015],c:'#d3c19a'},{p:[0,.22,.173],s:[.018,.13,.009],c:'#596844'},{p:[0,.23,.174],s:[.078,.019,.009],c:'#596844'}];
 pool={refs:1,geometries:{body:bake(body),door:bake(door),loot:bake(loot),bag:bake(bag)},metal:new T.MeshStandardMaterial({vertexColors:true,metalness:.62,roughness:.43}),paper:new T.MeshStandardMaterial({vertexColors:true,roughness:.86,metalness:0})};
 for(const g of Object.values(primitives))g.dispose();pools.set(T,pool);return pool;
}
function releasePool(T,pool){if(--pool.refs)return;for(const g of Object.values(pool.geometries))g.dispose();pool.metal.dispose();pool.paper.dispose();pools.delete(T)}
function required(value,name){if(typeof value!=='string'||!value.trim())throw new TypeError(`Interior safe needs a stable ${name}`);return value}

/**
 * onUnlock/onCollect(id, {buildingId,roomId,requestId,context}) must return an
 * authoritative receipt (or Promise): {ok:true,opened:true,collected?:true} /
 * {ok:true,collected:true}. No callbacks means locked, with no invented loot.
 * For major_safe_open, the source already pays awards: return collected:true.
 */
export function createInteriorSafe(T,{id,buildingId,roomId,position=[0,0,0],yaw=0,onUnlock,onCollect,sourceState,metresPerCell=4.1}={}){
 required(id,'id');required(buildingId,'buildingId');required(roomId,'roomId');
 if(!Number.isFinite(metresPerCell)||metresPerCell<=0)throw new TypeError('Invalid metresPerCell');
 const pool=acquirePool(T),object=new T.Group(),doorPivot=new T.Group();object.name='Interior_Safe';object.position.set(finite(position.x??position[0]),finite(position.y??position[1]),finite(position.z??position[2]));object.rotation.y=finite(yaw);
 const bodyMesh=new T.Mesh(pool.geometries.body,pool.metal),doorMesh=new T.Mesh(pool.geometries.door,pool.metal),lootMesh=new T.Mesh(pool.geometries.loot,pool.paper);
 bodyMesh.name='Safe_Hollow_Steel_Body';doorMesh.name='Safe_Hinged_Door';lootMesh.name='Safe_Source_Loot';
 for(const m of[bodyMesh,doorMesh,lootMesh]){m.castShadow=m.receiveShadow=true;m.matrixAutoUpdate=false;m.updateMatrix()}
 object.add(bodyMesh,doorPivot,lootMesh);doorPivot.position.set(-.369,0,.352);doorPivot.add(doorMesh);lootMesh.visible=false;
 const lootBag=new T.Mesh(pool.geometries.bag,pool.paper);lootBag.name='Safe_Dropped_Money_Bag';lootBag.castShadow=lootBag.receiveShadow=true;lootBag.visible=false;object.add(lootBag);
 const state={opened:false,collected:false,locked:true,lootDropped:false,revision:-1},scratch=new T.Vector3(),lastMatrix=new Float64Array(16);lastMatrix.fill(NaN);
 let lootFraction=0,lootActive=false,openingOperator=null,waitingForOperator=false;
 let disposed=false,fraction=0,active=false,unlockPending=null,collectPending=null,collisionRevision=0,cachedRevision=-1,cachedBodies=[],animationUpdates=0,colliderBuilds=0;
 const meta={id,kind:'safe',label:'Сейф',locked:true,lockable:true,workRange:.08,buildingId,roomId};
 Object.assign(object.userData,{mercenaryTarget:meta,locked:true,lockable:true,interiorSafeId:id});
 function publish(){object.userData.locked=meta.locked=state.locked;object.userData.mercenaryOpened=state.opened;object.userData.collected=state.collected;lootMesh.visible=state.opened&&!state.collected&&!state.lootDropped;lootBag.visible=state.opened&&!state.collected&&state.lootDropped&&fraction>.45}
 function getState(){return {id,buildingId,roomId,...state,opening:active||lootActive,waitingForOperator,openFraction:fraction,pending:unlockPending?'unlock':collectPending?'collect':null,disposed}}
 function applySourceState(snapshot,{animate=true}={}){
  if(disposed||!snapshot||typeof snapshot!=='object')return {ok:false,reason:disposed?'disposed':'invalid_source_state'};
  if(snapshot.targetId!=null&&snapshot.targetId!==id)return {ok:false,reason:'wrong_target'};
  const revision=Number.isFinite(snapshot.revision)?snapshot.revision:null;
  if(revision!==null&&revision<state.revision)return {ok:false,reason:'stale_source_state'};
  if(revision!==null)state.revision=revision;
  // Once confirmed, stale refreshes cannot close a looted safe or replenish it.
  if(snapshot.opened===true||snapshot.collected===true){state.opened=true;state.locked=false}
  if(snapshot.collected===true)state.collected=true;
  if(snapshot.lootDropped===true)state.lootDropped=true;
  if(state.lootDropped&&!state.collected&&lootFraction<1){if(animate)lootActive=true;else{lootFraction=1;lootActive=false;lootBag.position.set(0,0,1.05)}}
  if(state.opened&&fraction<1){if(animate)active=true;else{fraction=1;active=false;doorPivot.rotation.y=OPEN_ANGLE;collisionRevision++}}
  publish();return {ok:true,opened:state.opened,collected:state.collected};
 }
 function request(action,context){
  if(disposed)return Promise.resolve({ok:false,reason:'disposed'});
  if(action==='unlock'&&state.opened)return Promise.resolve({ok:true,duplicate:true,opened:true,collected:state.collected});
  if(action==='collect'&&state.collected)return Promise.resolve({ok:true,duplicate:true,opened:state.opened,collected:true});
  if(action==='collect'&&!state.opened)return Promise.resolve({ok:false,reason:'locked'});
  const pending=action==='unlock'?unlockPending:collectPending;if(pending)return pending;
  const callback=action==='unlock'?onUnlock:onCollect;if(typeof callback!=='function')return Promise.resolve({ok:false,reason:'source_not_connected'});
  // Position reads belong to presentation; never send executable callbacks to
  // the authoritative safe ledger. Acceptance still completes immediately so
  // the ordinary squad route can move the operator away from the closed leaf.
  const {getOperatorPosition,...authorityContext}=context||{};
  const operator=action==='unlock'&&typeof getOperatorPosition==='function'&&context?.memberId?{id:context.memberId,read:getOperatorPosition}:null;
  const task=Promise.resolve().then(()=>{
   if(disposed)return {ok:false,reason:'disposed'};
   return callback(id,{buildingId,roomId,requestId:`${id}:${action}`,context:typeof getOperatorPosition==='function'?authorityContext:context});
  }).then(receipt=>{
   if(disposed)return {ok:false,reason:'disposed'};
   if(receipt?.ok!==true)return {ok:false,reason:receipt?.reason||'source_rejected'};
   if(receipt.targetId!=null&&receipt.targetId!==id)return {ok:false,reason:'wrong_target'};
   if(action==='unlock'&&receipt.opened!==true&&receipt.collected!==true)return {ok:false,reason:'unconfirmed_unlock'};
   if(action==='collect'&&receipt.collected!==true)return {ok:false,reason:'unconfirmed_collection'};
   if(operator)openingOperator=operator;
   const applied=applySourceState(receipt);return applied.ok?{...receipt,...applied,targetId:id}:applied;
  }).catch(()=>({ok:false,reason:'source_error'})).finally(()=>{if(action==='unlock')unlockPending=null;else collectPending=null});
  if(action==='unlock')unlockPending=task;else collectPending=task;return task;
 }
 function operatorBlocksOpening(){
  if(!openingOperator)return false;
  let p;try{p=openingOperator.read(openingOperator.id);}catch{return true;}
  if(!p){openingOperator=null;return false;}
  if(!Number.isFinite(p.x)||!Number.isFinite(p.y)||!Number.isFinite(p.z))return true;
  object.updateWorldMatrix(true,false);doorPivot.updateWorldMatrix(false,false);
  const m=object.matrixWorld.elements,scaleXZ=Math.max(Math.hypot(m[0],m[2]),Math.hypot(m[8],m[10]));
  doorPivot.getWorldPosition(scratch);
  // Native source body is 0.18 cells, not 0.18 metres. Keep the .08 m accepted
  // approach envelope clear too. Height separates occupants on other floors.
  const overlapsHeight=p.y<scratch.y+1.3&&p.y+1.9>scratch.y;
  return overlapsHeight&&Math.hypot(p.x-scratch.x,p.z-scratch.z)<DOOR_SWEEP_RADIUS*scaleXZ+.18*metresPerCell+.08;
 }
 function update(dt){
  if(disposed||!active&&!lootActive)return false;dt=Number.isFinite(dt)?Math.max(0,Math.min(.1,dt)):0;if(!dt)return false;
  waitingForOperator=active&&operatorBlocksOpening();
  if(active&&!waitingForOperator){fraction=Math.min(1,fraction+dt/OPEN_SECONDS);const eased=fraction*fraction*(3-2*fraction);doorPivot.rotation.y=OPEN_ANGLE*eased;active=fraction<1;collisionRevision++;if(!active)openingOperator=null;}
  if(lootActive&&fraction>.45){lootFraction=Math.min(1,lootFraction+dt/.7);const t=lootFraction;lootBag.position.set(0,Math.max(0,.65*(1-t)-.3*t*t)+Math.sin(t*Math.PI*3)*.035*(1-t),.24+.81*t);lootBag.rotation.z=Math.sin(t*Math.PI*2)*.15*(1-t);lootActive=t<1&&!state.collected;}
  publish();animationUpdates++;return true;
 }
 function getCollisionBodies(){
  if(disposed)return cachedBodies;object.updateWorldMatrix(true,false);const elements=object.matrixWorld.elements;
  let changed=cachedRevision!==collisionRevision;for(let i=0;i<16;i++)if(lastMatrix[i]!==elements[i]){changed=true;break}
  if(!changed)return cachedBodies;lastMatrix.set(elements);doorPivot.updateWorldMatrix(false,false);cachedRevision=collisionRevision;colliderBuilds++;
  const body=(box,node,movingDoor=false)=>{
   const [x,y,z]=box.p,[w,h,d]=box.s,polygonCR=[],matrix=node.matrixWorld;let minYM=Infinity,maxYM=-Infinity;
   for(const [px,pz]of[[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]]){
    scratch.set(x+px,y-h/2,z+pz).applyMatrix4(matrix);polygonCR.push([scratch.x/metresPerCell,scratch.z/metresPerCell]);minYM=Math.min(minYM,scratch.y);maxYM=Math.max(maxYM,scratch.y);
    scratch.set(x+px,y+h/2,z+pz).applyMatrix4(matrix);minYM=Math.min(minYM,scratch.y);maxYM=Math.max(maxYM,scratch.y);
   }
   return {polygonCR,minYM,maxYM,buildingEntryId:buildingId,interiorSafe:true,interiorFurniture:true,safeId:id,movingDoor};
  };
  cachedBodies=BODY_BOXES.map(box=>body(box,object));cachedBodies.push(body(DOOR_BOX,doorPivot,true));return cachedBodies;
 }
 const api={object,doorPivot,lootBag,unlock:context=>request('unlock',context),collect:context=>request('collect',context),applySourceState,update,getCollisionBodies,getState,
  get needsUpdate(){return !disposed&&(active||lootActive)},
  stats(){return {draws:disposed?0:2+Number(lootMesh.visible)+Number(lootBag.visible),triangles:disposed?0:Object.entries(pool.geometries).reduce((sum,[key,g])=>sum+((key==='loot'?lootMesh.visible:key==='bag'?lootBag.visible:true)?g.index.count/3:0),0),pooledReferences:pool.refs,animationUpdates,colliderBuilds,active:!disposed&&(active||lootActive)}},
  dispose(){if(disposed)return;disposed=true;active=false;openingOperator=null;waitingForOperator=false;cachedBodies=[];object.removeFromParent();delete object.userData.interiorSafe;object.userData.lockable=meta.lockable=false;object.userData.destroyed=true;releasePool(T,pool)},
 };
 object.userData.interiorSafe={unlock:api.unlock,collect:api.collect,getState};
 Object.assign(meta,{unlock:api.unlock,collect:api.collect,getState});
 meta.getApproachPosition=()=>{object.updateWorldMatrix(true,false);return object.localToWorld(new T.Vector3(0,0,1.34));};
 meta.workRange=.08;meta.getWorkPoint=()=>object.localToWorld(new T.Vector3(-.084,.88,.5));meta.getWorkNormal=()=>new T.Vector3(0,0,1).transformDirection(object.matrixWorld);
 meta.highlightBounds={min:[-.45,0,-.36],max:[.45,1.30,.56]};
 meta.getLootPosition=()=>{lootBag.updateWorldMatrix(true,false);return lootBag.getWorldPosition(new T.Vector3());};
 if(sourceState)applySourceState(sourceState,{animate:false});return api;
}
