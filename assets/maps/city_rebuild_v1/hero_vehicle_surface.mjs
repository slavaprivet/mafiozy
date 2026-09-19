// Height-aware walking volumes derived from the existing authored car surfaces.
// Owns no scene objects, materials, physics, or vehicle state.
export function createHeroVehicleSurface({THREE:T,getVehicles,now=()=>performance.now()/1000,maxBuildsPerUpdate=1}={}){
 const records=new Map(),point=new T.Vector3(),up=new T.Vector3(),scale=new T.Vector3(),position=new T.Vector3(),quaternion=new T.Quaternion();
 const cell=.4,stats={builds:0,triangles:0,queries:0,triangleTests:0};let active=[],lastTime;
 const excluded=/Interior_|Wheel|Tyre|Tire|Mirror|Handle|Lightbar|Lamp|Ladder|RoofRail|Roof_rail|Spoiler|Taxi_|damage_effect|Engine_|Hood_support/i;
 function build(record){
  const root=record.root,bins=new Map(),sources=[],bounds=new T.Box3(),a=new T.Vector3(),b=new T.Vector3(),c=new T.Vector3(),normal=new T.Vector3(),edge=new T.Vector3();
  root.updateWorldMatrix(true,true);const inverse=root.matrixWorld.clone().invert();
  function visit(node){
   if(node!==root&&(!node.visible||excluded.test(node.name||'')||node.isBatchedMesh))return;
   const attr=node.geometry?.attributes?.position;
   if(node.isMesh&&attr){
    const matrix=new T.Matrix4().multiplyMatrices(inverse,node.matrixWorld),index=node.geometry.index;
    sources.push({node,geometry:node.geometry,version:attr.version});
    for(let i=0;i<(index?.count??attr.count)-2;i+=3){
     a.fromBufferAttribute(attr,index?index.getX(i):i).applyMatrix4(matrix);b.fromBufferAttribute(attr,index?index.getX(i+1):i+1).applyMatrix4(matrix);c.fromBufferAttribute(attr,index?index.getX(i+2):i+2).applyMatrix4(matrix);
     bounds.expandByPoint(a);bounds.expandByPoint(b);bounds.expandByPoint(c);
     normal.subVectors(b,a).cross(edge.subVectors(c,a));if(Math.abs(normal.y)<1e-8)continue;
     const den=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z);
     const triangle={ax:a.x,ay:a.y,az:a.z,bx:b.x,by:b.y,bz:b.z,cx:c.x,cy:c.y,cz:c.z,den,walkable:normal.y/normal.length()>.6};
     for(let x=Math.floor(Math.min(a.x,b.x,c.x)/cell);x<=Math.floor(Math.max(a.x,b.x,c.x)/cell);x++)for(let z=Math.floor(Math.min(a.z,b.z,c.z)/cell);z<=Math.floor(Math.max(a.z,b.z,c.z)/cell);z++){
      const key=x+','+z;let list=bins.get(key);if(!list)bins.set(key,list=[]);list.push(triangle);
     }stats.triangles++;
    }
   }
   for(const child of node.children)visit(child);
  }
  visit(root);record.bins=bins;record.bounds=bounds;record.sources=sources;record.dirty=false;stats.builds++;
 }
 function update(time=now()){
  const dt=lastTime===undefined?0:Math.max(0,time-lastTime);lastTime=time;const seen=new Set();active=[];let budget=maxBuildsPerUpdate;
  for(const input of getVehicles?.()||[]){
   const actor=input.car||input.actor||input,root=actor.object||input.object;if(!root||seen.has(root))continue;seen.add(root);
   let r=records.get(root);if(!r){r={root,actor,input,matrix:new T.Matrix4(),inverse:new T.Matrix4(),worldBounds:new T.Box3(),previous:new T.Vector3(),readyAt:time,initialized:false};records.set(root,r)}
   r.input=input;root.updateWorldMatrix(true,false);r.matrix.copy(root.matrixWorld);r.inverse.copy(r.matrix).invert();r.matrix.decompose(position,quaternion,scale);
   const state=input.state||actor.state||{},speed=Math.max(Math.abs(state.speed||0),Math.hypot(state.vx||0,state.vz||0),r.initialized&&dt>0?position.distanceTo(r.previous)/dt:0);
   const tilted=up.set(0,1,0).applyQuaternion(quaternion).y<.99999;
   if(speed>.08||tilted||Math.abs(state.yawRate||0)>.03)r.readyAt=time+.3;
   const water=state.waterState||root.userData.vehicleWater||{};
   r.stable=time>=r.readyAt&&!tilted&&speed<=.08&&!water.inWater&&!water.sinking&&!water.submerged&&!state.sunk;
   r.previous.copy(position);r.initialized=true;
   if(r.sources?.some(s=>s.node.geometry!==s.geometry||s.geometry.attributes.position.version!==s.version))r.dirty=true;
   // Opening a lid invalidates the old support shape. Keep solid fallback until
   // the caller explicitly invalidates/rebuilds after a finished geometry edit.
   const access=[actor.hoodSpec,actor.trunkSpec];
   const accessOpen=access.some(s=>s?.lid?.userData.detached||s?.lid?.visible===false||(/^(Hood|Trunk)_hinge$/.test(s?.lid?.parent?.name||'')&&Math.abs(s.lid.parent.rotation.x)>.025));
   r.stable=r.stable&&!r.dirty&&!accessOpen;
   if(!r.bins&&budget>0){build(r);budget--}
   const p=actor.profile||root.userData.vehicleProfile||{};
   r.localFallback??=new T.Box3(new T.Vector3(-(p.halfWidth||1.3),0,-(p.halfLength||2.7)),new T.Vector3(p.halfWidth||1.3,p.height||2.2,p.halfLength||2.7));
   r.worldBounds.copy(r.bounds&&!r.bounds.isEmpty()?r.bounds:r.localFallback).applyMatrix4(r.matrix);r.tilted=tilted;active.push(r);
  }
  for(const root of records.keys())if(!seen.has(root))records.delete(root);
 }
 function column(r,x,z){
  point.set(x,r.worldBounds.max.y,z).applyMatrix4(r.inverse);const lx=point.x,lz=point.z;
  if(!r.bins||r.dirty||r.tilted){return {top:r.worldBounds.max.y,minY:r.worldBounds.min.y,walkable:false}}
  let top=-Infinity,walkable=false;
  for(const t of r.bins.get(Math.floor(lx/cell)+','+Math.floor(lz/cell))||[]){
   stats.triangleTests++;const u=((t.bz-t.cz)*(lx-t.cx)+(t.cx-t.bx)*(lz-t.cz))/t.den,v=((t.cz-t.az)*(lx-t.cx)+(t.ax-t.cx)*(lz-t.cz))/t.den;
   if(u< -1e-7||v< -1e-7||u+v>1+1e-7)continue;
   const y=u*t.ay+v*t.by+(1-u-v)*t.cy;if(y>top+1e-6){top=y;walkable=t.walkable}else if(Math.abs(y-top)<1e-6)walkable||=t.walkable;
  }
  if(!Number.isFinite(top))return null;
  point.set(lx,top,lz).applyMatrix4(r.matrix);return {top:point.y,minY:r.worldBounds.min.y,walkable};
 }
 function query(x,z,referenceY,stableOnly){
  stats.queries++;let result=null;
  for(const r of active){const b=r.worldBounds;if(x<b.min.x||x>b.max.x||z<b.min.z||z>b.max.z)continue;
   const hit=column(r,x,z);if(!hit||hit.top>referenceY||stableOnly&&(!r.stable||!hit.walkable))continue;
   if(!result||hit.top>result.top)result={...hit,stable:r.stable&&hit.walkable,vehicle:r.input};
  }return result;
 }
 function sample(x,z,referenceY=Infinity){return query(x,z,Infinity,false)}
 function supportHeight(x,z,referenceY,fallback=-Infinity){return query(x,z,referenceY+.28,true)?.top??fallback}
 function blocks(x,z,y,height=1.9,radius=0){
  // Same center + radial capsule samples as walk collision, with a height test.
  for(let i=0;i<(radius>0?9:1);i++){const a=(i-1)*Math.PI/4,px=x+(i?Math.cos(a)*radius:0),pz=z+(i?Math.sin(a)*radius:0);
   for(const r of active){const b=r.worldBounds;if(px<b.min.x||px>b.max.x||pz<b.min.z||pz>b.max.z||y>=b.max.y-.045||y+height<=b.min.y+.03)continue;const hit=column(r,px,pz);if(hit&&y<hit.top-.045&&y+height>hit.minY+.03)return true;}
  }return false;
 }
 function invalidate(vehicle){const root=vehicle?.car?.object||vehicle?.actor?.object||vehicle?.object||vehicle;const r=records.get(root);if(r){r.bins=null;r.sources=null;r.dirty=true;}}
 return {update,sample,supportHeight,blocks,invalidate,diagnostics:()=>({...stats,vehicles:active.length,ready:active.filter(r=>r.bins&&!r.dirty).length}),dispose(){records.clear();active=[]}};
}
