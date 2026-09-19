// Audited merged door components, not the obsolete EntranceAnchor at z=14.59.
// The same source mesh and entry-profile ramp are checked by the actual-GLB test.
const ASSET='compact_podium_glass_tower_v1';
const SHA256='caa4b79ab28993e3a8c84054f5366de2df94a4d70ff76f7073d01dd73caea531';
const DOOR=Object.freeze({x:-3,y:.21,z:6.9100000858306885});
const HALF_WIDTH=1.475000023841858;
const finiteVector=(v,n)=>Array.isArray(v)&&v.length===n&&v.every(Number.isFinite);

/** Worker-safe world coordinates of the existing physical tower entrance.
 * This is an approach contract, never a terrain, ownership or placement edit.
 * The landing is half a metre outside the existing ramp, so a 0.38m pedestrian
 * can stand entirely on ground before following the ramp to the real door.
 */
export function planTowerPublicApproach(instance){
 if(instance?.assetId!==ASSET||instance.binding?.sha256!==SHA256||instance.binding?.lod!==0)return null;
 const transform=instance.transform,position=transform?.positionM,offset=transform?.modelLocalOffsetM,scale=transform?.horizontalScale||[1,1],base=transform?.uniformScale??1;
 if(!finiteVector(position,3)||!finiteVector(offset,3)||!finiteVector(scale,2)||scale.some(s=>s<=0)||!Number.isFinite(base)||base<=0||!Number.isFinite(transform.yawDegrees))return null;
 const yaw=transform.yawDegrees*Math.PI/180,sin=Math.sin(yaw),cos=Math.cos(yaw),sx=scale[0]*base,sz=scale[1]*base;
 const world=(x,y,z)=>({x:position[0]+(x+offset[0])*sx*cos+(z+offset[2])*sz*sin,y:position[1]+(y+offset[1])*base,z:position[2]-(x+offset[0])*sx*sin+(z+offset[2])*sz*cos});
 const door=world(DOOR.x,DOOR.y,DOOR.z),rampLengthLocal=Math.max(2.2,door.y*4.5);
 // This is the current entry profile's exact local ramp surface. Refuse a
 // transform whose authored ramp does not meet street y=0; do not invent a
 // different floor in the worker or silently mask a geometry regression.
 const rampToe=world(DOOR.x,DOOR.y-door.y,DOOR.z+rampLengthLocal);
 if(Math.abs(rampToe.y)>1e-5)return null;
 const outward={x:sin,z:cos},landing={x:rampToe.x+sin*.5,y:0,z:rampToe.z+cos*.5};
 return {version:1,kind:'tower_public_approach',buildingId:instance.id,assetId:ASSET,sourceSHA256:SHA256,doorLocal:{...DOOR},door,rampToe,landing,outward,rampLengthLocal,widthM:HALF_WIDTH*2*sx,suffix:[landing,rampToe,door],requiresDoorInteraction:true,source:'actual Runtime_TowerDoor_Left/Right and Entry_Continuous_Ramp'};
}

/** Attach the same deterministic contract to the real entry without replacing
 * its animated leaves, interaction prompt, floor sampler or collision cache. */
export function applyTowerPublicApproach({THREE:T,entry,instance}){
 if(entry?.towerPublicApproach)return entry.towerPublicApproach;
 const plan=planTowerPublicApproach(instance);if(!plan||!entry?.object)return null;
 const ramp=entry.object.getObjectByName('Entry_Continuous_Ramp');
 if(!ramp?.geometry?.attributes.position)return null;
 entry.object.updateWorldMatrix(true,true);
 const actualDoor=entry.object.getWorldPosition(new T.Vector3()),actualToe=entry.object.localToWorld(new T.Vector3(0,-plan.door.y,plan.rampLengthLocal));
 if(actualDoor.distanceTo(new T.Vector3(plan.door.x,plan.door.y,plan.door.z))>1e-5||actualToe.distanceTo(new T.Vector3(plan.rampToe.x,plan.rampToe.y,plan.rampToe.z))>1e-5)return null;
 const originalDispose=entry.dispose,previousPublicApproach=entry.publicApproach,previousReport=entry.report.towerPublicApproach;
 let disposed=false,entryDisposed=false;
 const report={...plan,geometryChanged:false,collisionBodiesPreserved:true,addedDraws:0,addedTriangles:0};
 const api={plan,report,landingPoint:()=>new T.Vector3(plan.landing.x,plan.landing.y,plan.landing.z),routePoints:()=>plan.suffix.map(p=>new T.Vector3(p.x,p.y,p.z)),dispose(){
  if(disposed)return;disposed=true;
  if(entry.publicApproach===api){if(previousPublicApproach===undefined)delete entry.publicApproach;else entry.publicApproach=previousPublicApproach;}
  if(entry.towerPublicApproach===api)delete entry.towerPublicApproach;
  if(entry.report.towerPublicApproach===report){if(previousReport===undefined)delete entry.report.towerPublicApproach;else entry.report.towerPublicApproach=previousReport;}
 }};
 entry.publicApproach=api;entry.towerPublicApproach=api;entry.report.towerPublicApproach=report;
 entry.dispose=function(){if(entryDisposed)return;entryDisposed=true;api.dispose();originalDispose.call(entry);};
 return api;
}
