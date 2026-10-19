import {transformBuildingPointCR} from './walk_map_editor_building_derive.mjs';
import {makeWalkMapObjectDeleteCommand,makeWalkMapObjectTransformCommand} from './walk_map_editor_document.mjs';

export const WALK_MAP_DECOR_PREPARE_ADAPTER_ID='authored-decor-derived-v1';
export const WALK_MAP_DECOR_DEPENDENCIES=Object.freeze(['decor-collision','street-lighting','decor-keepouts','grass','minimap','static-batches']);

const EPSILON=1e-8;
export class WalkMapDecorPrepareError extends Error{constructor(code,message,details={}){super(message);this.name='WalkMapDecorPrepareError';this.code=code;this.details=structuredClone(details)}}
function fail(code,message,details){throw new WalkMapDecorPrepareError(code,message,details)}
function clone(value){return structuredClone(value)}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)}
function finite(value){return typeof value==='number'&&Number.isFinite(value)}
function stable(value){if(Array.isArray(value))return value.map(stable);if(plain(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value}
function equal(a,b){return JSON.stringify(stable(a))===JSON.stringify(stable(b))}
function unique(values){return [...new Set(values.filter(value=>typeof value==='string'&&value))]}
function number(value){const rounded=Math.round(value*1e12)/1e12;return Math.abs(value-rounded)<1e-12?rounded:value}
function transformOf(record){const raw=record?.transform||{},horizontal=raw.horizontalScale||[1,1];return {...clone(raw),positionM:[...(raw.positionM||[0,0,0])],yawDegrees:raw.yawDegrees||0,uniformScale:raw.uniformScale??1,horizontalScale:[horizontal[0]??1,horizontal[1]??1],modelLocalOffsetM:[...(raw.modelLocalOffsetM||[0,0,0])]}}
function validateTransform(transform){return Array.isArray(transform.positionM)&&transform.positionM.length===3&&transform.positionM.every(finite)&&finite(transform.yawDegrees)&&finite(transform.uniformScale)&&transform.uniformScale>0&&transform.uniformScale<=100&&Array.isArray(transform.horizontalScale)&&transform.horizontalScale.length===2&&transform.horizontalScale.every(value=>finite(value)&&value>0&&value<=100)&&Array.isArray(transform.modelLocalOffsetM)&&transform.modelLocalOffsetM.length===3&&transform.modelLocalOffsetM.every(finite)}
function pointEqual(a,b){return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((value,index)=>Math.abs(value-b[index])<EPSILON)}
function sameTransform(a,b){return pointEqual(a.positionM,b.positionM)&&Math.abs(a.yawDegrees-b.yawDegrees)<EPSILON&&Math.abs(a.uniformScale-b.uniformScale)<EPSILON&&pointEqual(a.horizontalScale,b.horizontalScale)&&pointEqual(a.modelLocalOffsetM,b.modelLocalOffsetM)}
function transformY(value,base,next){return number(next.positionM[1]+(value-base.positionM[1])*(next.uniformScale/base.uniformScale))}
function projectPolygon(polygon,project){if(!Array.isArray(polygon)||polygon.length<3||polygon.some(point=>!Array.isArray(point)||point.length!==2||!point.every(finite)))fail('DECOR_GEOMETRY_INVALID','У декора отсутствует доказанный polygon');return polygon.map(point=>project(point))}
function bounds(points){return {minC:Math.min(...points.map(p=>p[0])),minR:Math.min(...points.map(p=>p[1])),maxC:Math.max(...points.map(p=>p[0])),maxR:Math.max(...points.map(p=>p[1]))}}
function orientation(a,b,c){return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])}
function onSegment(a,b,p){return Math.abs(orientation(a,b,p))<=EPSILON&&p[0]>=Math.min(a[0],b[0])-EPSILON&&p[0]<=Math.max(a[0],b[0])+EPSILON&&p[1]>=Math.min(a[1],b[1])-EPSILON&&p[1]<=Math.max(a[1],b[1])+EPSILON}
function segmentsOverlap(a,b,c,d){const abC=orientation(a,b,c),abD=orientation(a,b,d),cdA=orientation(c,d,a),cdB=orientation(c,d,b);if(((abC>EPSILON&&abD<-EPSILON)||(abC<-EPSILON&&abD>EPSILON))&&((cdA>EPSILON&&cdB<-EPSILON)||(cdA<-EPSILON&&cdB>EPSILON)))return true;return onSegment(a,b,c)||onSegment(a,b,d)||onSegment(c,d,a)||onSegment(c,d,b)}
function pointInPolygon(point,polygon){for(let i=0;i<polygon.length;i++)if(onSegment(polygon[i],polygon[(i+1)%polygon.length],point))return true;let inside=false;const [x,y]=point;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const [xi,yi]=polygon[i],[xj,yj]=polygon[j];if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)inside=!inside}return inside}
function polygonsOverlap(a,b){if(a.some(point=>pointInPolygon(point,b))||b.some(point=>pointInPolygon(point,a)))return true;for(let i=0;i<a.length;i++)for(let j=0;j<b.length;j++)if(segmentsOverlap(a[i],a[(i+1)%a.length],b[j],b[(j+1)%b.length]))return true;return false}
function rectPolygon(rect){return [[rect.minC,rect.minR],[rect.maxC,rect.minR],[rect.maxC,rect.maxR],[rect.minC,rect.maxR]]}
function parkingPolygon(value,metresPerCell){const direct=value?.rectCR||value?.footprint||value;if([direct?.minC,direct?.minR,direct?.maxC,direct?.maxR].every(finite))return rectPolygon(direct);const metres=value?.rectM||value?.rect||value;if([metres?.minX,metres?.minZ,metres?.maxX,metres?.maxZ].every(finite))return rectPolygon({minC:metres.minX/metresPerCell,minR:metres.minZ/metresPerCell,maxC:metres.maxX/metresPerCell,maxR:metres.maxZ/metresPerCell});return null}
function polygonTouchesCell(polygon,r,c){const cell=[[c,r],[c+1,r],[c+1,r+1],[c,r+1]];return polygon.some(point=>point[0]>=c-EPSILON&&point[0]<=c+1+EPSILON&&point[1]>=r-EPSILON&&point[1]<=r+1+EPSILON)||cell.some(point=>pointInPolygon(point,polygon))||polygon.some((point,index)=>cell.some((corner,cellIndex)=>segmentsOverlap(point,polygon[(index+1)%polygon.length],corner,cell[(cellIndex+1)%cell.length])))}
function polygonCells(polygon,rows,cols){const box=bounds(polygon),result=[];for(let r=Math.max(0,Math.floor(box.minR));r<=Math.min(rows-1,Math.ceil(box.maxR)-1);r++)for(let c=Math.max(0,Math.floor(box.minC));c<=Math.min(cols-1,Math.ceil(box.maxC)-1);c++)if(polygonTouchesCell(polygon,r,c))result.push([r,c]);return {box,cells:result}}
function assertTopology(topology){const rows=topology?.grid?.length,cols=topology?.grid?.[0]?.length;if(!Number.isSafeInteger(rows)||!Number.isSafeInteger(cols)||rows<=0||cols<=0||!Array.isArray(topology.roadMask))fail('DECOR_TOPOLOGY_REQUIRED','Перенос декора требует доверенную topology');return {rows,cols}}
function assertInventory(inventory){if(!plain(inventory)||inventory.complete?.buildings!==true||inventory.complete?.decor!==true||inventory.complete?.parking!==true||!Array.isArray(inventory.buildings)||!Array.isArray(inventory.decor)||!Array.isArray(inventory.parkingKeepouts))fail('DECOR_INVENTORY_INCOMPLETE','Перенос декора требует полные списки зданий, декора и парковок')}
function validatePlacement({id,polygon,topology,inventory,metresPerCell}){
 const {rows,cols}=assertTopology(topology),{box,cells}=polygonCells(polygon,rows,cols);if(box.minC<0||box.minR<0||box.maxC>cols||box.maxR>rows)fail('DECOR_OUT_OF_BOUNDS','Декор выходит за границы карты');
 for(const [r,c] of cells){if(topology.grid[r]?.[c]===16)fail('DECOR_ON_WATER','Декор попадает в воду',{r,c});if(topology.protectedMask?.[r]?.[c]||topology.policeMask?.[r]?.[c]||topology.bridgeDeckMask?.[r]?.[c])fail('DECOR_ON_PROTECTED','Декор попадает в защищённую область',{r,c});if(topology.roadMask?.[r]?.[c])fail('DECOR_ON_ROAD','Декор перекрывает проезжую часть',{r,c})}
 for(const building of inventory.buildings){for(const rect of [building.clearance,building.footprint,building.entryCorridor])if(rect&&polygonsOverlap(polygon,rectPolygon(rect)))fail('DECOR_BUILDING_OVERLAP','Декор пересекает здание или его вход',{buildingId:building.id})}
 for(const other of inventory.decor){if(String(other.id)===String(id)||!other.clearancePolygonCR)continue;if(polygonsOverlap(polygon,other.clearancePolygonCR))fail('DECOR_OVERLAP','Декор пересекает другой объект',{otherId:other.id})}
 for(const parking of inventory.parkingKeepouts){const other=parkingPolygon(parking,metresPerCell);if(other&&polygonsOverlap(polygon,other))fail('DECOR_PARKING_OVERLAP','Декор пересекает парковку или её въезд',{parkingId:parking.id||parking.lotId||null})}
}

export function deriveMovedDecor({trustedBase,nextTransform,topology,inventory,metresPerCell=4.1}={}){
 if(!trustedBase?.id)fail('BASE_DECOR_REQUIRED','Не найдена исходная запись декора');if(!Number.isFinite(metresPerCell)||metresPerCell<=0)fail('DECOR_CELL_SIZE_INVALID','Некорректный масштаб карты');
 const base=transformOf(trustedBase),next={...base,...clone(nextTransform||{})};next.positionM=[...(next.positionM||base.positionM)];next.horizontalScale=[...(next.horizontalScale||base.horizontalScale)];next.modelLocalOffsetM=[...(next.modelLocalOffsetM||base.modelLocalOffsetM)];if(!validateTransform(next))fail('DECOR_TRANSFORM_INVALID','Недопустимое положение или масштаб декора');if(!pointEqual(next.modelLocalOffsetM,base.modelLocalOffsetM))fail('DECOR_LOCAL_OFFSET_CHANGE_UNSUPPORTED','Локальное смещение модели сохраняется и не редактируется отдельно');
 assertInventory(inventory);assertTopology(topology);
 const project=point=>transformBuildingPointCR(point,base,next,metresPerCell),clearance=projectPolygon(trustedBase.clearancePolygonCR,project);validatePlacement({id:trustedBase.id,polygon:clearance,topology,inventory,metresPerCell});if(sameTransform(base,next))return {ok:true,record:clone(trustedBase),exact:{clearancePolygonCR:clone(trustedBase.clearancePolygonCR)},dirty:[]};
 const record=clone(trustedBase);record.transform={...clone(record.transform||{}),positionM:[...next.positionM],yawDegrees:next.yawDegrees,uniformScale:next.uniformScale,horizontalScale:[...next.horizontalScale],modelLocalOffsetM:[...next.modelLocalOffsetM]};record.r=number(next.positionM[2]/metresPerCell);record.c=number(next.positionM[0]/metresPerCell);record.clearancePolygonCR=clearance;
 if(Array.isArray(record.collision?.worldBodies))record.collision.worldBodies=trustedBase.collision.worldBodies.map(body=>({...clone(body),polygonCR:projectPolygon(body.polygonCR,project),minYM:body.minYM===undefined?undefined:transformY(body.minYM,base,next),maxYM:body.maxYM===undefined?undefined:transformY(body.maxYM,base,next)}));if(record.collision)record.collision.scaleApplied=next.uniformScale;
 return {ok:true,record,exact:{clearancePolygonCR:clone(clearance)},dirty:clone(WALK_MAP_DECOR_DEPENDENCIES)};
}

export function createWalkMapDecorCommandPreparer({resolveCurrentEntity,topology,inventory,metresPerCell=4.1,deriveDecor=deriveMovedDecor}={}){
 if(typeof resolveCurrentEntity!=='function')throw new Error('Decor preparation requires a trusted current-entity resolver');if(typeof deriveDecor!=='function')throw new Error('Decor preparation requires a trusted derivation compiler');
 return async function prepareDecorCommand(raw,{dependencies=[]}={}){
  const patch=raw?.type==='object.set-patch'?raw.patch:null;if(patch?.source?.dataset!=='decor'||!['modify','delete'].includes(patch.action))fail('DECOR_COMMAND_UNSUPPORTED','Разрешены только перемещение и удаление авторского декора');
  const current=await resolveCurrentEntity(clone(patch.source));if(!plain(current)||String(current.id)!==String(patch.source.id))fail('TRUSTED_DECOR_MISSING',`Не найдена доверенная запись декора ${patch.source.id}`);if(!equal(patch.before,current))fail('STALE_DECOR_PREVIEW',`Устаревшее состояние декора ${patch.source.id}`);
  const allDependencies=unique([...dependencies,...(patch.metadata?.dependencies||[]),...WALK_MAP_DECOR_DEPENDENCIES]),metadata={...clone(patch.metadata||{}),adapter:WALK_MAP_DECOR_PREPARE_ADAPTER_ID,dependencies:allDependencies};
  if(patch.action==='delete')return {command:makeWalkMapObjectDeleteCommand({source:patch.source,before:current,metadata}),dependencies:allDependencies};
  if(!patch.after?.transform)fail('DECOR_TRANSFORM_REQUIRED','Для перемещения декора нужен transform');const resolvedInventory=typeof inventory==='function'?inventory():inventory,resolvedTopology=typeof topology==='function'?topology():topology,result=await deriveDecor({trustedBase:current,nextTransform:patch.after.transform,topology:resolvedTopology,inventory:resolvedInventory,metresPerCell});
  if(!result?.ok)fail(result?.code||'DECOR_DERIVE_FAILED',result?.message||'Не удалось пересчитать декор',result?.details||{});return {command:makeWalkMapObjectTransformCommand({source:patch.source,before:current,after:result.record,metadata}),dependencies:allDependencies};
 };
}
