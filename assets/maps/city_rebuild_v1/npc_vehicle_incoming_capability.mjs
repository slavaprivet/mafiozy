import {isBreakableGlass} from './glass_breakage.mjs';

// Admission to the EXISTING bounded exact sight/contact query, not a hit proof.
// Does not inspect profile.id, touch transforms, open glass, raycast or mutate HP.
// A local Walk root and the current authored seat/head are still checked by
// createVehicleOccupantSight. Source-car visualPivot authority remains excluded.
export function createLocalVehicleIncomingCapability(){
 const geometryCache=new WeakMap();let geometryScans=0,vertices=0;
 const yes=Object.freeze({supported:true,reason:'authored-local-seat-window'});
 const failures=new Map(),fail=reason=>{if(!failures.has(reason))failures.set(reason,Object.freeze({supported:false,reason}));return failures.get(reason)};
 const beneath=(node,root)=>{for(let p=node;p;p=p.parent)if(p===root)return true;return false};
 function check(car,seatId){
  if(!car?.object?.isObject3D||!Array.isArray(car.seats))return fail('local-seat-metadata-unavailable');
  const seat=car.seats.find(s=>s?.id===seatId),a=seat?.anchor;
  if(!a||![a.side,a.y,a.front].every(Number.isFinite)||Math.abs(seat.side)!==1||Math.sign(a.side)!==seat.side)return fail('local-seat-anchor-invalid');
  if(typeof car.doors?.get!=='function')return fail('local-seat-door-unavailable');
  const doorId=seat.doorId,door=car.doors.get(doorId)||car.doors.get(doorId==='front_left'?1:doorId==='front_right'?-1:doorId);
  if(!door||!beneath(door,car.object))return fail('local-seat-door-unavailable');
  // All current local factories own their pane directly under the seat's door.
  // Legacy Kingswell has one unnamed but explicitly breakable direct glass
  // mesh; it must pass the same area check. Transparency alone is insufficient.
  const pane=door.children.find(n=>n.isMesh&&(n.name==='Fitted_door_glass_'+doorId||n.name==='Door_window_'+doorId||n.userData.bodyWindow===doorId))||door.children.find(n=>n.isMesh&&!Array.isArray(n.material)&&isBreakableGlass(n,n.material));
  if(!pane)return fail('local-seat-window-unavailable');
  const materials=Array.isArray(pane.material)?pane.material:[pane.material];
  if(!materials.length||materials.some(m=>!m||!isBreakableGlass(pane,m)))return fail('local-seat-window-material-invalid');
  const g=pane.geometry,p=g?.attributes?.position;
  if(!p||p.count<3)return fail('local-seat-window-geometry-invalid');
  let cached=geometryCache.get(g);
  if(!cached||cached.position!==p||cached.version!==p.version||cached.count!==p.count){
   geometryScans++;let minY=Infinity,maxY=-Infinity,minZ=Infinity,maxZ=-Infinity,finite=true;
   for(let i=0;i<p.count;i++){vertices++;const x=p.getX(i),y=p.getY(i),z=p.getZ(i);if(![x,y,z].every(Number.isFinite)){finite=false;break;}minY=Math.min(minY,y);maxY=Math.max(maxY,y);minZ=Math.min(minZ,z);maxZ=Math.max(maxZ,z);}
   // Bounds only assert that authored window metadata has usable area. Exact
   // triangle hits (including unbroken extra panes) still decide all visibility.
   cached={position:p,version:p.version,count:p.count,valid:finite&&maxY-minY>.20&&maxZ-minZ>.25};geometryCache.set(g,cached);
  }
  return cached.valid?yes:fail('local-seat-window-geometry-invalid');
 }
 return {check,stats:()=>({geometryScans,vertices})};
}
