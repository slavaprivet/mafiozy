import {cellsForRect,rectanglesOverlap as overlaps} from './building_placement.mjs';
import {BUILDING_SIZE_POLICY,SITE_BODY_SCALES} from './building_size_policy.mjs';
const M=4.1;
const rect=points=>({minC:Math.min(...points.map(p=>p[0])),maxC:Math.max(...points.map(p=>p[0])),minR:Math.min(...points.map(p=>p[1])),maxR:Math.max(...points.map(p=>p[1]))});
const corners=r=>[[r.minC,r.minR],[r.maxC,r.minR],[r.maxC,r.maxR],[r.minC,r.maxR]];
function inside(c,r,p){let yes=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])yes=!yes}return yes}
export function resizeBuildingPlacement({base,topology,source,decor,ledger}){
 const plan=structuredClone(base),report=[],reserved=ledger.rows.filter(r=>Array.isArray(r.plannedRC)&&/^(bank|business|poi):/.test(r.id)).map(r=>({id:r.id,minR:r.plannedRC[0]-2.5,maxR:r.plannedRC[0]+2.5,minC:r.plannedRC[1]-2.5,maxC:r.plannedRC[1]+2.5}));
 const decoration=(decor.instances??[]).filter(d=>d.clearancePolygonCR).map(d=>rect(d.clearancePolygonCR));
 const dry=(r,tiles)=>cellsForRect(r).every(p=>tiles.includes(topology.grid[p.r]?.[p.c])&&!topology.protectedMask[p.r]?.[p.c]);
 const ordered=plan.instances.slice().sort((a,b)=>{const area=i=>(i.footprint.maxC-i.footprint.minC)*(i.footprint.maxR-i.footprint.minR)*(BUILDING_SIZE_POLICY[i.assetId]?.[0]??1)*(BUILDING_SIZE_POLICY[i.assetId]?.[1]??1);return area(b)-area(a)});
 for(const current of ordered){
  const policy=BUILDING_SIZE_POLICY[current.assetId];if(!policy)continue;
  const old=base.instances.find(i=>i.id===current.id),[targetX,targetZ,label]=policy,quarter=Math.round(old.transform.yawDegrees/90)%2;
  const oldC=old.transform.positionM[0]/M,oldR=old.transform.positionM[2]/M,district=source.districts.find(d=>d.id===old.districtId),largePublic=['hospital','civic_hall'].includes(old.assetId);
  if(SITE_BODY_SCALES[old.assetId]){
   const s=SITE_BODY_SCALES[old.assetId];
   current.transform.horizontalScale=[s,s];current.transform.preserveSiteBounds=true;
   const anchor={r:oldR+(old.entry.anchorRC.r-oldR)*s,c:oldC+(old.entry.anchorRC.c-oldC)*s};
   current.entry.anchorRC=anchor;
   current.entryCorridor={minR:Math.min(old.entryCorridor.minR,anchor.r-.42*s),maxR:Math.max(old.entryCorridor.maxR,anchor.r+.42*s),minC:Math.min(old.entryCorridor.minC,anchor.c-.42*s),maxC:Math.max(old.entryCorridor.maxC,anchor.c+.42*s)};
   current.roomSizing={label,exteriorAndInterior:true,preserveOriginalYard:true,source:'2026-09-08 user approved',previousPositionM:old.transform.positionM,areaMultiplier:s*s};
   report.push({id:old.id,assetId:old.assetId,label,scale:[s,s],targetScale:[targetX,targetZ],areaMultiplier:s*s,movedMetres:0,preserveOriginalYard:true});
   continue;
  }
  const candidates=[{r:oldR,c:oldC}];for(let r=3;r<197;r+=.5)for(let c=3;c<177;c+=.5)if(topology.grid[Math.floor(r)]?.[Math.floor(c)]===8&&(largePublic||inside(c,r,district.polygon_grid)))candidates.push({r,c});
  candidates.sort((a,b)=>Math.hypot(a.r-oldR,a.c-oldC)-Math.hypot(b.r-oldR,b.c-oldC));
  let result=null;const stages=[0,0,0,0,0];
  sizing: for(const fraction of [1,.85,.7,.55,.4,.25,.15,.075,.05,.025]){
  const sx=1+(targetX-1)*fraction,sz=1+(targetZ-1)*fraction,worldSX=quarter?sz:sx,worldSZ=quarter?sx:sz;
  for(const p of candidates){
   const convert=([c,r])=>[p.c+(c-oldC)*worldSX,p.r+(r-oldR)*worldSZ],convertRect=r=>rect(corners(r).map(convert));
   const footprint=convertRect(old.footprint),clearance={minR:footprint.minR+.0-.65,minC:footprint.minC-.65,maxR:footprint.maxR+.65,maxC:footprint.maxC+.65};
   const targetDistrict=largePublic?source.districts.find(d=>corners(footprint).every(([c,r])=>inside(c,r,d.polygon_grid))):district;
   stages[0]++;if(!targetDistrict||!dry(footprint,[8])||!corners(footprint).every(([c,r])=>inside(c,r,targetDistrict.polygon_grid)))continue;stages[1]++;
   const blockers=[...(plan.protectedRects??[]),...reserved.filter(r=>r.id!==old.gameplayId)];
   const others=plan.instances.filter(i=>i.id!==old.id);
   if(blockers.some(b=>overlaps(footprint,b))||others.some(i=>overlaps(clearance,i.clearance)||overlaps(footprint,i.entryCorridor))||decoration.some(d=>overlaps(footprint,d)))continue;
   stages[2]++;const [dc,dr]=convert([old.entry.anchorRC.c,old.entry.anchorRC.r]),vC=old.entry.roadProbeRC.c-old.entry.anchorRC.c,vR=old.entry.roadProbeRC.r-old.entry.anchorRC.r,nc=Math.abs(vC)>Math.abs(vR)?Math.sign(vC):0,nr=nc?0:Math.sign(vR);
   const edgeR=nr>0?footprint.maxR:nr<0?footprint.minR:dr,edgeC=nc>0?footprint.maxC:nc<0?footprint.minC:dc;
   let end=null;for(let t=.25;t<=12;t+=.25){const r=edgeR+nr*t,c=edgeC+nc*t,tile=topology.grid[Math.floor(r)]?.[Math.floor(c)];if(![0,8,9].includes(tile))break;if(tile===0){end={r,c};break}}
   if(!end)continue;stages[3]++;
   const half=.42*Math.max(sx,sz),entryCorridor=nr?{minR:Math.min(dr,end.r)-.05,maxR:Math.max(dr,end.r)+.05,minC:dc-half,maxC:dc+half}:{minR:dr-half,maxR:dr+half,minC:Math.min(dc,end.c)-.05,maxC:Math.max(dc,end.c)+.05};
   if(!dry(entryCorridor,[0,8,9])||blockers.some(b=>overlaps(entryCorridor,b))||others.some(i=>overlaps(entryCorridor,i.footprint))||decoration.some(d=>overlaps(entryCorridor,d)))continue;
   const item=structuredClone(old);item.districtId=targetDistrict.id;item.transform.positionM=[p.c*M,0,p.r*M];item.transform.horizontalScale=[sx,sz];item.footprint=footprint;item.clearance=clearance;item.entryCorridor=entryCorridor;item.entry.anchorRC={r:dr,c:dc};item.entry.roadProbeRC=end;
   item.collision.worldBodies=old.collision.worldBodies.map(b=>({...b,polygonCR:b.polygonCR.map(convert),rectangleRC:b.rectangleRC?convertRect(b.rectangleRC):undefined}));
   item.roomSizing={label,exteriorAndInterior:true,source:'2026-09-08 user approved',previousPositionM:old.transform.positionM,areaMultiplier:sx*sz};
   result=item;break sizing;
  }
  }
  if(!result)throw Error('No safe enlarged placement for '+old.id+' stages '+stages);
  Object.assign(current,result);const [sx,sz]=result.transform.horizontalScale;report.push({id:old.id,assetId:old.assetId,label,scale:[sx,sz],targetScale:[targetX,targetZ],areaMultiplier:sx*sz,movedMetres:Math.hypot(current.transform.positionM[0]-old.transform.positionM[0],current.transform.positionM[2]-old.transform.positionM[2])});
 }
 plan.footprints=plan.instances.map(i=>({id:i.id,...i.footprint}));plan.doorCorridors=plan.instances.map(i=>({id:i.id,...i.entryCorridor}));plan.roomSizingRevision='2026-09-08-v1';
 return {plan,report};
}


