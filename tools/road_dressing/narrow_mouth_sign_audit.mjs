// Audit-only geometry checks. Deliberately does not call the placement search:
// a flag or a successful repeat of the same generator cannot validate a post.
const M=4.1,RADIUS=.2,EPS=1e-7;
const finite=(...n)=>n.every(Number.isFinite);
export function createNarrowMouthAuditContext(snapshot,topology,railPlan){
 const instances=[...(snapshot.buildings||[]),...(snapshot.authoredDecor||[])],reserved=[];
 const polygonBounds=p=>{if(!p?.length)return;reserved.push({minX:Math.min(...p.map(p=>p[0]))*M,maxX:Math.max(...p.map(p=>p[0]))*M,minZ:Math.min(...p.map(p=>p[1]))*M,maxZ:Math.max(...p.map(p=>p[1]))*M});};
 for(const i of instances){for(const r of[i.footprint,i.entryCorridor,i.clearance].filter(Boolean))reserved.push({minX:r.minC*M,maxX:r.maxC*M,minZ:r.minR*M,maxZ:r.maxR*M});polygonBounds(i.clearancePolygonCR);for(const b of i.collision?.worldBodies||[]){polygonBounds(b.polygonCR);if(b.placementKeepoutPolygonCR)polygonBounds(b.placementKeepoutPolygonCR);}}
 for(const b of snapshot.decorPlan?.colliders||[])polygonBounds(b.placementKeepoutPolygonCR||b.polygonCR);
 reserved.push(...(snapshot.parkingPlan?.keepouts||[]),...(snapshot.parkingPlan?.accessKeepouts||[]));
 const road=snapshot.roadPlan,crossings=[...(road.trafficPlan?.crosswalks||[]),...(road.trafficPlan?.serviceCrossings||[])];
 return{topology,railPlan,reserved,passages:road.trafficPlan?.narrowPassages||[],poles:[...(road.signs||[]),...(road.signals||[])],colliders:road.colliders||[],landings:crossings.flatMap(c=>c.endpoints||[])};
}
function surface(topology,x,z){const r=Math.floor(z/M),c=Math.floor(x/M),blocked=topology.protectedMask?.[r]?.[c]||topology.policeMask?.[r]?.[c],road=!!topology.roadMask?.[r]?.[c];return{road:road&&!blocked,land:[8,9].includes(topology.grid?.[r]?.[c])&&!road&&!blocked};}
function diskOnDryLand(topology,x,z){
 for(let r=Math.floor((z-RADIUS)/M);r<=Math.floor((z+RADIUS)/M);r++)for(let c=Math.floor((x-RADIUS)/M);c<=Math.floor((x+RADIUS)/M);c++){
  const dx=Math.max(c*M-x,0,x-(c+1)*M),dz=Math.max(r*M-z,0,z-(r+1)*M);
  if(dx*dx+dz*dz<RADIUS*RADIUS-EPS&&!surface(topology,(c+.5)*M,(r+.5)*M).land)return false;
 }
 return true;
}
// Exact grid-boundary intervals detect even a short diagonal water/road gap.
function dryShoulder(topology,origin,normal,length){
 const cuts=[0,length];for(const axis of['x','z']){const v=normal[axis];if(Math.abs(v)<EPS)continue;const a=origin[axis],b=a+v*length;for(let k=Math.ceil(Math.min(a,b)/M);k<=Math.floor(Math.max(a,b)/M);k++){const t=(k*M-a)/v;if(t>EPS&&t<length-EPS)cuts.push(t);}}
 cuts.sort((a,b)=>a-b);let firstLand=null;
 for(let i=1;i<cuts.length;i++){if(cuts[i]-cuts[i-1]<EPS)continue;const at=(cuts[i]+cuts[i-1])/2,s=surface(topology,origin.x+normal.x*at,origin.z+normal.z*at);if(s.land){firstLand??=cuts[i-1];}else if(!s.road||firstLand!==null)return null;}
 return firstLand;
}
export function auditNarrowMouthSign(pole,context){
 const fail=reason=>({valid:false,reason}),meta=pole?.controlPlacement;
 if(meta?.mode!=='verified_narrow_mouth_verge')return fail('wrong_placement_mode');
 const passage=context.passages.find(p=>p.id===pole.passageId);
 if(!passage||!['one_way','no_entry'].includes(pole.kind)||pole.roadId!==passage.roadId||!passage.signIds?.includes(pole.id))return fail('unknown_passage_identity');
 const entry=pole.kind==='one_way',mouth=entry?passage.points[0]:passage.points.at(-1),approachId=entry?passage.fromApproachId:passage.toApproachId,sign=entry?-1:1,out={x:Math.sin(mouth.yaw)*sign,z:Math.cos(mouth.yaw)*sign};
 if(pole.approachId!==approachId||(entry?pole.allowedDirection!==passage.direction:pole.prohibitedDirection!==-passage.direction))return fail('wrong_approach_direction');
 if(!finite(pole.x,pole.z,pole.yaw,mouth.x,mouth.z,mouth.yaw,passage.widthM,meta.advanceM,meta.lateralM,meta.curbSetbackM))return fail('nonfinite_pose');
 if(Math.sin(pole.yaw)*out.x+Math.cos(pole.yaw)*out.z<.99)return fail('wrong_facing');
 const dx=pole.x-mouth.x,dz=pole.z-mouth.z,advance=dx*out.x+dz*out.z,right=dx*out.z-dz*out.x,lateral=Math.abs(right),side=right>0?'right':'left';
 if(Math.abs(advance)>2+EPS||lateral<.5-EPS||lateral>passage.widthM/2+6+EPS)return fail('outside_same_mouth');
 if(meta.side!==side||side==='left'&&meta.rightVergeUnavailable!==true||Math.abs(meta.advanceM-advance)>EPS||Math.abs(meta.lateralM-lateral)>EPS||meta.curbSetbackM<0||meta.curbSetbackM>3+EPS)return fail('inconsistent_placement_metadata');
 const origin={x:mouth.x+out.x*advance,z:mouth.z+out.z*advance},normal={x:out.z*Math.sign(right),z:-out.x*Math.sign(right)},firstLand=dryShoulder(context.topology,origin,normal,lateral);
 if(firstLand===null||firstLand<EPS||lateral-firstLand>3.2+EPS||Math.abs((lateral-firstLand)-meta.curbSetbackM)>.200001)return fail('not_first_continuous_dry_shoulder');
 if(!diskOnDryLand(context.topology,pole.x,pole.z))return fail('post_footprint_off_dry_land');
 if(context.railPlan?.blocksPlacement(pole.x,pole.z,1.35))return fail('rail_keepout');
 if(context.reserved.some(b=>pole.x+.65>b.minX&&pole.x-.65<b.maxX&&pole.z+.65>b.minZ&&pole.z-.65<b.maxZ))return fail('reserved_building_or_access');
 if(context.landings.some(p=>Math.hypot(p.x-pole.x,p.z-pole.z)<1.05-EPS))return fail('crossing_landing');
 if(context.poles.some(p=>p.id!==pole.id&&Math.hypot(p.x-pole.x,p.z-pole.z)<1.5-EPS))return fail('another_post');
 const body=context.colliders.find(b=>b.id===pole.id);
 if(!body||body.minYM!==0||body.maxYM<3||body.groundRadius!==RADIUS||body.polygonCR?.length!==8||body.polygonCR.some(([c,r],i)=>Math.hypot(c*M-pole.x-Math.cos(i/8*Math.PI*2)*RADIUS,r*M-pole.z-Math.sin(i/8*Math.PI*2)*RADIUS)>EPS))return fail('missing_or_displaced_physical_post');
 return{valid:true,passageId:passage.id,mouth:{x:mouth.x,z:mouth.z},advanceM:advance,lateralM:lateral,side,firstDryShoulderM:firstLand,actualCurbSetbackM:lateral-firstLand};
}
