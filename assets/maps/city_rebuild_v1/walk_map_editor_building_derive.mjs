const EPSILON=1e-7;
const DIRTY_BUILDING_DEPENDENCIES=Object.freeze([
 'building-entry','walk-collision','vehicle-collision','building-sample','shot-index','camera-index','static-batches','minimap','parking','parking-walks','road-access','npc-support','decor-keepouts','grass'
]);

function clone(value){return structuredClone(value);}
function finite(value){return typeof value==='number'&&Number.isFinite(value);}
function stableNumber(value){const rounded=Math.round(value*1e12)/1e12;return Math.abs(value-rounded)<1e-12?rounded:value;}
function fail(code,message=code,details={}){return {ok:false,code,message,details};}
function normalizedYaw(value){const yaw=((value%360)+360)%360;return Math.abs(yaw-360)<EPSILON?0:yaw;}
function transformOf(record){const transform=record.transform||{},horizontal=transform.horizontalScale||[1,1];return {positionM:[...(transform.positionM||[0,0,0])],yawDegrees:normalizedYaw(transform.yawDegrees||0),uniformScale:transform.uniformScale??1,horizontalScale:[horizontal[0]??1,horizontal[1]??1],modelLocalOffsetM:[...(transform.modelLocalOffsetM||[0,0,0])],preserveSiteBounds:transform.preserveSiteBounds===true};}
function validateTransform(transform){return Array.isArray(transform.positionM)&&transform.positionM.length===3&&transform.positionM.every(finite)&&finite(transform.yawDegrees)&&finite(transform.uniformScale)&&transform.uniformScale>0&&Array.isArray(transform.horizontalScale)&&transform.horizontalScale.length===2&&transform.horizontalScale.every(value=>finite(value)&&value>0);}
function sameTransform(a,b){return a.positionM.every((value,index)=>Object.is(value,b.positionM[index])||Math.abs(value-b.positionM[index])<EPSILON)&&Math.abs(a.yawDegrees-b.yawDegrees)<EPSILON&&Math.abs(a.uniformScale-b.uniformScale)<EPSILON&&a.horizontalScale.every((value,index)=>Math.abs(value-b.horizontalScale[index])<EPSILON)&&a.modelLocalOffsetM.every((value,index)=>Object.is(value,b.modelLocalOffsetM[index])||Math.abs(value-b.modelLocalOffsetM[index])<EPSILON)&&a.preserveSiteBounds===b.preserveSiteBounds;}

export function transformBuildingPointCR(point,baseTransform,nextTransform,metresPerCell=4.1){
 const [c,r]=point,[x0,,z0]=baseTransform.positionM,[x1,,z1]=nextTransform.positionM,t0=baseTransform.yawDegrees*Math.PI/180,t1=nextTransform.yawDegrees*Math.PI/180,c0=Math.cos(t0),s0=Math.sin(t0),c1=Math.cos(t1),s1=Math.sin(t1),sx0=baseTransform.uniformScale*baseTransform.horizontalScale[0],sz0=baseTransform.uniformScale*baseTransform.horizontalScale[1],sx1=nextTransform.uniformScale*nextTransform.horizontalScale[0],sz1=nextTransform.uniformScale*nextTransform.horizontalScale[1],dx=c*metresPerCell-x0,dz=r*metresPerCell-z0,lx=(c0*dx-s0*dz)/sx0,lz=(s0*dx+c0*dz)/sz0,x=x1+c1*sx1*lx+s1*sz1*lz,z=z1-s1*sx1*lx+c1*sz1*lz;
 return [stableNumber(x/metresPerCell),stableNumber(z/metresPerCell)];
}

function transformY(y,baseTransform,nextTransform){const y0=baseTransform.positionM[1],y1=nextTransform.positionM[1];return stableNumber(y1+(y-y0)*(nextTransform.uniformScale/baseTransform.uniformScale));}
function rectPoints(rect){return [[rect.minC,rect.minR],[rect.maxC,rect.minR],[rect.maxC,rect.maxR],[rect.minC,rect.maxR]];}
function boundsOf(points){return {minR:Math.min(...points.map(p=>p[1])),minC:Math.min(...points.map(p=>p[0])),maxR:Math.max(...points.map(p=>p[1])),maxC:Math.max(...points.map(p=>p[0]))};}
function pointInPolygon(c,r,polygon){let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])inside=!inside}return inside;}
function rectsOverlap(a,b,margin=0){return a.minC<b.maxC-margin&&a.maxC>b.minC+margin&&a.minR<b.maxR-margin&&a.maxR>b.minR+margin;}
function transformRect(rect,project){const points=rectPoints(rect).map(project);return {bounds:boundsOf(points),points};}
function cellAt(topology,r,c){const rr=Math.floor(r),cc=Math.floor(c);if(rr<0||cc<0||rr>=topology.grid.length||cc>=topology.grid[0].length)return null;return {r:rr,c:cc,tile:topology.grid[rr][cc]};}
function protectedAt(topology,r,c){return !!(topology.protectedMask?.[r]?.[c]||topology.policeMask?.[r]?.[c]||topology.bridgeDeckMask?.[r]?.[c]);}
function parkingBoundsCR(value,metresPerCell){
 const direct=value?.rectCR||value?.footprint||value;if([direct?.minC,direct?.minR,direct?.maxC,direct?.maxR].every(finite))return {minC:direct.minC,minR:direct.minR,maxC:direct.maxC,maxR:direct.maxR};
 const metres=value?.rectM||value?.rect||value;if([metres?.minX,metres?.minZ,metres?.maxX,metres?.maxZ].every(finite))return {minC:metres.minX/metresPerCell,minR:metres.minZ/metresPerCell,maxC:metres.maxX/metresPerCell,maxR:metres.maxZ/metresPerCell};
 return null;
}

function validateFootprint({polygon,bounds,topology,otherInstances,parkingKeepouts,id,metresPerCell}){
 if(topology){const rows=topology.grid?.length||0,cols=topology.grid?.[0]?.length||0;
  if(bounds.minR<0||bounds.minC<0||bounds.maxR>rows||bounds.maxC>cols)return fail('BUILDING_OUT_OF_BOUNDS','Здание выходит за границы карты');
  for(let r=Math.floor(bounds.minR);r<Math.ceil(bounds.maxR);r++)for(let c=Math.floor(bounds.minC);c<Math.ceil(bounds.maxC);c++)if(pointInPolygon(c+.5,r+.5,polygon)){if(topology.grid[r]?.[c]===16)return fail('BUILDING_ON_WATER','Здание попадает в воду',{r,c});if(protectedAt(topology,r,c))return fail('BUILDING_ON_PROTECTED','Здание попадает в защищённую область',{r,c});}
 }
 for(const other of otherInstances||[]){if(other.id===id)continue;if(other.footprint&&rectsOverlap(bounds,other.clearance||other.footprint,.01))return fail('BUILDING_OVERLAP','Здание пересекает другой объект',{otherId:other.id});if(other.entryCorridor&&rectsOverlap(bounds,other.entryCorridor,.01))return fail('BLOCKS_OTHER_ENTRY','Здание перекрывает вход другого объекта',{otherId:other.id});}
 for(const parking of parkingKeepouts||[]){const parkingBounds=parkingBoundsCR(parking,metresPerCell);if(parkingBounds&&rectsOverlap(bounds,parkingBounds,.01))return fail('PARKING_OVERLAP','Здание пересекает парковку',{parkingId:parking.id||parking.lotId||null});}
 return null;
}

function rebuildRoadAccess({base,next,project,footprintPolygon,topology,metresPerCell}){
 if(!base.entry?.anchorRC||!base.entry?.roadProbeRC||!topology)return {entry:next.entry,exactCorridor:null};
 const anchorPoint=project([base.entry.anchorRC.c,base.entry.anchorRC.r]),oldProbe=project([base.entry.roadProbeRC.c,base.entry.roadProbeRC.r]),vx=oldProbe[0]-anchorPoint[0],vz=oldProbe[1]-anchorPoint[1],length=Math.hypot(vx,vz);
 if(length<EPSILON)return fail('ENTRY_DIRECTION_INVALID','Не удалось определить направление входа');
 const dx=vx/length,dz=vz/length;let probe=null,leftFootprint=false;
 for(let distance=0;distance<=12;distance+=.25){const c=anchorPoint[0]+dx*distance,r=anchorPoint[1]+dz*distance,cell=cellAt(topology,r,c);if(!cell)return fail('ENTRY_OUT_OF_BOUNDS','Проход от входа выходит за карту');if(pointInPolygon(c,r,footprintPolygon)){continue}else leftFootprint=true;if(!leftFootprint)continue;if(cell.tile===16||protectedAt(topology,cell.r,cell.c))return fail('ENTRY_PATH_BLOCKED','Проход от входа пересекает воду или защищённую область',{r:cell.r,c:cell.c});if(topology.roadMask?.[cell.r]?.[cell.c]){probe=[c,r];break}if(![0,8,9,19].includes(cell.tile))return fail('ENTRY_PATH_BLOCKED','Проход от входа пересекает недопустимое покрытие',{r:cell.r,c:cell.c});}
 if(!probe)return fail('NO_STRAIGHT_ROAD_ACCESS','От нового входа нет прямого сухого прохода к дороге');
 let halfWidth=.3;if(base.entryCorridor){for(const point of rectPoints(base.entryCorridor).map(project)){const px=point[0]-anchorPoint[0],pz=point[1]-anchorPoint[1];halfWidth=Math.max(halfWidth,Math.abs(px*(-dz)+pz*dx));}}
 const nx=-dz,nz=dx,exactCorridor=[[anchorPoint[0]+nx*halfWidth,anchorPoint[1]+nz*halfWidth],[anchorPoint[0]-nx*halfWidth,anchorPoint[1]-nz*halfWidth],[probe[0]-nx*halfWidth,probe[1]-nz*halfWidth],[probe[0]+nx*halfWidth,probe[1]+nz*halfWidth]],entry={...clone(next.entry),anchorRC:{r:anchorPoint[1],c:anchorPoint[0]},roadProbeRC:{r:probe[1],c:probe[0]}};
 return {entry,exactCorridor};
}

function isSpecial(record){return record.role==='district_detention'||record.gameplayActive===true||['civic_hall','hospital','police_station'].includes(record.assetId)||/^bank_/.test(record.assetId||'');}

export function deriveMovedBuilding({trustedBase,nextTransform,topology=null,otherInstances=[],parkingKeepouts=[],metresPerCell=4.1,allowSpecialFullRebuild=false}={}){
 if(!trustedBase?.id)return fail('BASE_BUILDING_REQUIRED','Не найдена исходная запись здания');
 const baseTransform=transformOf(trustedBase),next={...baseTransform,...clone(nextTransform||{})};next.positionM=[...(next.positionM||baseTransform.positionM)];next.horizontalScale=[...(next.horizontalScale||baseTransform.horizontalScale)];next.modelLocalOffsetM=[...(next.modelLocalOffsetM||baseTransform.modelLocalOffsetM)];next.yawDegrees=normalizedYaw(next.yawDegrees);
 if(!validateTransform(next))return fail('INVALID_BUILDING_TRANSFORM','Недопустимое положение или масштаб здания');
 if(isSpecial(trustedBase)&&!allowSpecialFullRebuild)return fail('FULL_REBUILD_REQUIRED','Для этого здания требуется полная безопасная пересборка');
 if(sameTransform(baseTransform,next)&&!topology&&!(otherInstances?.length)&&!(parkingKeepouts?.length))return {ok:true,record:clone(trustedBase),exact:{footprintPolygon:trustedBase.footprint?rectPoints(trustedBase.footprint):null,clearancePolygon:trustedBase.clearance?rectPoints(trustedBase.clearance):null,corridorPolygon:trustedBase.entryCorridor?rectPoints(trustedBase.entryCorridor):null},dirty:[],requiresFullRebuild:isSpecial(trustedBase)};
 const quarter=next.yawDegrees/90;if(Math.abs(quarter-Math.round(quarter))>EPSILON)return fail('UNSUPPORTED_BUILDING_YAW','Здания первой версии поворачиваются шагом 90°');
 if(!trustedBase.footprint)return fail('BASE_FOOTPRINT_REQUIRED','У исходного здания нет footprint');
 const project=point=>transformBuildingPointCR(point,baseTransform,next,metresPerCell),footprint=transformRect(trustedBase.footprint,project),validation=validateFootprint({polygon:footprint.points,bounds:footprint.bounds,topology,otherInstances,parkingKeepouts,id:trustedBase.id,metresPerCell});if(validation)return validation;
 const record=clone(trustedBase);record.transform={...clone(record.transform||{}),positionM:[...next.positionM],yawDegrees:next.yawDegrees,uniformScale:next.uniformScale,horizontalScale:[...next.horizontalScale],modelLocalOffsetM:[...next.modelLocalOffsetM],preserveSiteBounds:next.preserveSiteBounds};record.footprint=footprint.bounds;
 let clearancePolygon=null;if(trustedBase.clearance){const transformed=transformRect(trustedBase.clearance,project);record.clearance=transformed.bounds;clearancePolygon=transformed.points}
 if(record.collision?.worldBodies)record.collision.worldBodies=trustedBase.collision.worldBodies.map(body=>{const polygonCR=(body.polygonCR||rectPoints(body.rectangleRC)).map(project),nextBody={...clone(body),polygonCR,minYM:body.minYM===undefined?undefined:transformY(body.minYM,baseTransform,next),maxYM:body.maxYM===undefined?undefined:transformY(body.maxYM,baseTransform,next)};if(body.rectangleRC)nextBody.rectangleRC={...boundsOf(polygonCR),conservativeRectangle:false};return nextBody});
 if(trustedBase.entry?.anchorRC){const point=project([trustedBase.entry.anchorRC.c,trustedBase.entry.anchorRC.r]);record.entry={...clone(trustedBase.entry),anchorRC:{r:point[1],c:point[0]}};if(trustedBase.entry.roadProbeRC){const road=project([trustedBase.entry.roadProbeRC.c,trustedBase.entry.roadProbeRC.r]);record.entry.roadProbeRC={r:road[1],c:road[0]}}}
 let corridorPolygon=null;if(trustedBase.entryCorridor){const transformed=transformRect(trustedBase.entryCorridor,project);record.entryCorridor=transformed.bounds;corridorPolygon=transformed.points}
 const access=rebuildRoadAccess({base:trustedBase,next:record,project,footprintPolygon:footprint.points,topology,metresPerCell});if(access?.ok===false)return access;if(access?.entry){record.entry=access.entry;if(access.exactCorridor){record.entryCorridor=boundsOf(access.exactCorridor);corridorPolygon=access.exactCorridor}}
 return {ok:true,record,exact:{footprintPolygon:footprint.points,clearancePolygon,corridorPolygon},dirty:[...DIRTY_BUILDING_DEPENDENCIES],requiresFullRebuild:isSpecial(trustedBase)};
}

export {DIRTY_BUILDING_DEPENDENCIES};
