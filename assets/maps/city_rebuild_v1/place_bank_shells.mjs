import {cellsForRect,rectanglesOverlap as overlaps} from './building_placement.mjs';
const M=4.1,rect=(minR,minC,maxR,maxC)=>({minR,minC,maxR,maxC});
const polygon=q=>[[q.minC,q.minR],[q.maxC,q.minR],[q.maxC,q.maxR],[q.minC,q.maxR]];
function inside(c,r,p){let yes=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])yes=!yes}return yes}
export function placeBankShells({plan:input,manifest,topology,source,decor,ledger}){
 const plan=structuredClone(input),reserved=ledger.rows.filter(r=>Array.isArray(r.plannedRC)&&/^(bank|business|poi):/.test(r.id)).map(r=>({id:r.id,...rect(r.plannedRC[0]-2.5,r.plannedRC[1]-2.5,r.plannedRC[0]+2.5,r.plannedRC[1]+2.5)}));
 const blockers=(decor.instances??[]).flatMap(d=>(d.collision?.worldBodies??[]).map(b=>rect(Math.min(...b.polygonCR.map(p=>p[1])),Math.min(...b.polygonCR.map(p=>p[0])),Math.max(...b.polygonCR.map(p=>p[1])),Math.max(...b.polygonCR.map(p=>p[0])))));
 const dry=(q,tiles)=>cellsForRect(q).every(p=>tiles.includes(topology.grid[p.r]?.[p.c])&&!topology.protectedMask[p.r]?.[p.c]);
 for(const asset of manifest.entries.slice().reverse()){
  const id=asset.canonicalGameplayId;if(plan.instances.some(i=>i.gameplayId===id))continue;
  const preferred=id==='bank:large'?'central':id==='bank:medium'?'eastside':'old_town';
  const candidates=[];for(let r=3;r<197;r+=.5)for(let c=3;c<177;c+=.5)if(topology.grid[Math.floor(r)]?.[Math.floor(c)]===8){const d=source.districts.find(d=>inside(c,r,d.polygon_grid));if(d)candidates.push({r,c,d})}
  candidates.sort((a,b)=>(b.d.id===preferred)-(a.d.id===preferred));let item=null;
  search:for(const {r,c,d}of candidates)for(const yaw of [0,90,180,270]){
   const angle=yaw*Math.PI/180,rot=([x,y,z])=>[x*Math.cos(angle)+z*Math.sin(angle),-x*Math.sin(angle)+z*Math.cos(angle)],b=asset.visualBounds;
   const pts=[];for(const x of[b.min[0],b.max[0]])for(const z of[b.min[2],b.max[2]]){const q=rot([x,0,z]);pts.push([c+q[0]/M,r+q[1]/M])}
   const fp=rect(Math.min(...pts.map(p=>p[1])),Math.min(...pts.map(p=>p[0])),Math.max(...pts.map(p=>p[1])),Math.max(...pts.map(p=>p[0]))),clear=rect(fp.minR-.4,fp.minC-.4,fp.maxR+.4,fp.maxC+.4);
   if(!dry(fp,[8])||!polygon(fp).every(([c,r])=>inside(c,r,d.polygon_grid)))continue;
   const protectedAreas=[...(plan.protectedRects??[]),...reserved.filter(x=>x.id!==id)];
   if(protectedAreas.some(x=>overlaps(fp,x))||blockers.some(x=>overlaps(fp,x))||plan.instances.some(x=>overlaps(clear,x.clearance)||overlaps(fp,x.entryCorridor)))continue;
   const q=rot(asset.publicDoorLocalXYZ),door={r:r+q[1]/M,c:c+q[0]/M},normal=rot([0,0,1]),nr=Math.round(normal[1]),nc=Math.round(normal[0]);let end=null;
   for(let step=.5;step<10;step+=.25){const p={r:door.r+nr*step,c:door.c+nc*step},t=topology.grid[Math.floor(p.r)]?.[Math.floor(p.c)];if(![0,8,9].includes(t))break;if(t===0){end=p;break}}if(!end)continue;
   const cor=nr?rect(Math.min(door.r,end.r)-.05,door.c-.5,Math.max(door.r,end.r)+.05,door.c+.5):rect(door.r-.5,Math.min(door.c,end.c)-.05,door.r+.5,Math.max(door.c,end.c)+.05);
   if(!dry(cor,[0,8,9])||protectedAreas.some(x=>overlaps(cor,x))||blockers.some(x=>overlaps(cor,x))||plan.instances.some(x=>overlaps(cor,x.footprint)))continue;
   item={id:'REBUILD-'+id,assetId:asset.assetId,role:'bank_shell',districtId:d.id,gameplayId:id,gameplayActive:false,artAcceptance:asset.artAcceptance,binding:asset.binding,transform:{positionM:[c*M,0,r*M],yawDegrees:yaw,uniformScale:1,modelLocalOffsetM:[0,0,0]},footprint:fp,clearance:clear,entryCorridor:cor,entry:{anchorRC:door,roadProbeRC:end,authoredLocalXYZ:asset.publicDoorLocalXYZ,evidence:asset.publicDoorEvidence},bounds:asset.visualBounds,collision:{method:'bank_shell_outer_envelope',worldBodies:[{polygonCR:polygon(fp),rectangleRC:fp,minYM:0,maxYM:asset.dimensionsXYZ[1]}]},hideNodeNames:[],bankLayout:asset.layout,bankRoomProfile:asset.roomProfile,bankDoorProfile:{...asset.doorProfile,sha256:asset.binding.sha256},displayName:asset.displayName??id};break search;
  }
  if(!item)throw Error('No safe bank site: '+id);
  plan.instances.push(item);plan.unresolved=plan.unresolved.filter(r=>r.id!==id);plan.unresolved.push({id,reason:'visual_rooms_placed_host_gameplay_and_original_anchor_migration_pending'});
 }
 plan.counts.instances=plan.instances.length;plan.counts.assetTypesPlaced=new Set(plan.instances.map(i=>i.assetId)).size;plan.counts.fixedSiteCandidates=plan.instances.filter(i=>i.gameplayId).length;
 plan.footprints=plan.instances.map(i=>({id:i.id,...i.footprint}));plan.doorCorridors=plan.instances.map(i=>({id:i.id,...i.entryCorridor}));return plan;
}
