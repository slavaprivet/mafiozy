import {makeWalkMapObjectAddCommand,makeWalkMapObjectDeleteCommand} from './walk_map_editor_document.mjs';

export const WALK_MAP_GROUND_OVERLAY_SCHEMA='mafiozi.walk-map-editor.ground-overlay/v1';
export const WALK_MAP_GROUND_OVERLAY_MESH_PLAN_SCHEMA='mafiozi.walk-map-editor.ground-overlay-mesh-plan/v1';
export const WALK_MAP_GROUND_OVERLAY_ADAPTER_ID='mafiozi-ground-overlay-custom-v1';

export const WALK_MAP_GROUND_OVERLAY_MATERIALS=Object.freeze({
 earth:Object.freeze({renderMaterialId:'city-earth-overlay-v1',navigationSurfaceId:'earth',vehicleSpeedFactor:0.68}),
 'dirt-road':Object.freeze({renderMaterialId:'city-dirt-road-overlay-v1',navigationSurfaceId:'dirt-road',vehicleSpeedFactor:0.82})
});

export const WALK_MAP_GROUND_OVERLAY_DEPENDENCIES=Object.freeze([
 'ground-overlay-render','road-navigation','walk-navigation','vehicle-surface','grass','minimap'
]);

const MASK_NAMES=Object.freeze(['protectedMask','policeMask','bridgeDeckMask']);
const EPSILON=1e-9;

export class WalkMapGroundOverlayError extends Error{
 constructor(code,message,details={}){super(message);this.name='WalkMapGroundOverlayError';this.code=code;this.details=structuredClone(details)}
}

function fail(code,message,details){throw new WalkMapGroundOverlayError(code,message,details)}
function clone(value){return structuredClone(value)}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)}
function finite(value){return typeof value==='number'&&Number.isFinite(value)}
function pointKey([r,c]){return `${r}:${c}`}
function compareCells(a,b){return a[0]-b[0]||a[1]-b[1]}
function assertDimensions(map,rows,cols){
 const actualRows=rows??map?.rows,actualCols=cols??map?.cols;
 if(!Number.isSafeInteger(actualRows)||actualRows<=0||!Number.isSafeInteger(actualCols)||actualCols<=0)fail('INVALID_MAP_DIMENSIONS','Размеры карты должны быть положительными целыми числами');
 return {rows:actualRows,cols:actualCols};
}
function assertStableId(id){
 if(typeof id!=='string'||!id.trim()||id!==id.trim()||id.length>128||!/^[a-z0-9][a-z0-9._:-]*$/i.test(id))fail('INVALID_OVERLAY_ID','Overlay требует стабильный безопасный id');
 return id;
}
function assertMaterial(materialId){
 const material=WALK_MAP_GROUND_OVERLAY_MATERIALS[materialId];
 if(!material)fail('UNTRUSTED_GROUND_MATERIAL',`Материал ${String(materialId)} не разрешён для ground overlay`,{materialId});
 return material;
}
function normalizeCell(cell,{rows,cols}){
 if(!Array.isArray(cell)||cell.length!==2||!cell.every(Number.isInteger))fail('INVALID_OVERLAY_CELL','Ячейка должна быть парой целых [row,column]',{cell});
 const [r,c]=cell;if(r<0||c<0||r>=rows||c>=cols)fail('OVERLAY_CELL_OUT_OF_BOUNDS',`Ячейка ${r}:${c} вне карты ${rows}x${cols}`,{cell:[r,c],rows,cols});return [r,c];
}
function orientation(a,b,c){return (b[1]-a[1])*(c[0]-a[0])-(b[0]-a[0])*(c[1]-a[1])}
function onSegment(a,b,p){return Math.abs(orientation(a,b,p))<=EPSILON&&p[0]>=Math.min(a[0],b[0])-EPSILON&&p[0]<=Math.max(a[0],b[0])+EPSILON&&p[1]>=Math.min(a[1],b[1])-EPSILON&&p[1]<=Math.max(a[1],b[1])+EPSILON}
function segmentsIntersect(a,b,c,d){
 const abC=orientation(a,b,c),abD=orientation(a,b,d),cdA=orientation(c,d,a),cdB=orientation(c,d,b);
 if(((abC>EPSILON&&abD<-EPSILON)||(abC<-EPSILON&&abD>EPSILON))&&((cdA>EPSILON&&cdB<-EPSILON)||(cdA<-EPSILON&&cdB>EPSILON)))return true;
 return onSegment(a,b,c)||onSegment(a,b,d)||onSegment(c,d,a)||onSegment(c,d,b);
}
function assertSimplePolygon(points){
 for(let i=0;i<points.length;i++)for(let j=i+1;j<points.length;j++){
  if(j===i+1||(i===0&&j===points.length-1))continue;
  if(segmentsIntersect(points[i],points[(i+1)%points.length],points[j],points[(j+1)%points.length]))fail('SELF_INTERSECTING_OVERLAY_POLYGON','Polygon overlay не должен самопересекаться');
 }
}
function normalizeShape(shape,dimensions){
 if(!plain(shape))fail('INVALID_OVERLAY_SHAPE','Overlay shape должен быть объектом');
 if(shape.type==='cells'){
  if(!Array.isArray(shape.cells)||shape.cells.length===0)fail('INVALID_OVERLAY_SHAPE','Cell overlay должен содержать хотя бы одну ячейку');
  const cells=shape.cells.map(cell=>normalizeCell(cell,dimensions)),seen=new Set();
  for(const cell of cells){const key=pointKey(cell);if(seen.has(key))fail('DUPLICATE_OVERLAY_CELL',`Повтор ячейки ${key}`,{cell});seen.add(key)}
  return {...clone(shape),type:'cells',cells};
 }
 if(shape.type==='polygon'){
  if(!Array.isArray(shape.points)||shape.points.length<3)fail('INVALID_OVERLAY_SHAPE','Polygon overlay требует минимум три точки');
  const points=shape.points.map(point=>{
   if(!Array.isArray(point)||point.length!==2||!point.every(finite))fail('INVALID_OVERLAY_POINT','Точка polygon должна быть конечной парой [row,column]',{point});
   const [r,c]=point;if(r<0||c<0||r>dimensions.rows||c>dimensions.cols)fail('OVERLAY_POINT_OUT_OF_BOUNDS','Точка polygon находится вне карты',{point:[r,c]});return [r,c];
  });
  if(new Set(points.map(pointKey)).size!==points.length)fail('DUPLICATE_OVERLAY_POINT','Точки polygon не должны повторяться');
  assertSimplePolygon(points);
  let twiceArea=0;for(let i=0;i<points.length;i++)twiceArea+=points[i][1]*points[(i+1)%points.length][0]-points[(i+1)%points.length][1]*points[i][0];
  if(Math.abs(twiceArea)<=EPSILON)fail('ZERO_AREA_OVERLAY_POLYGON','Polygon overlay должен иметь ненулевую площадь');
  return {...clone(shape),type:'polygon',points};
 }
 fail('INVALID_OVERLAY_SHAPE',`Неизвестный тип overlay shape: ${String(shape.type)}`);
}
function pointInPolygon(point,polygon){
 for(let i=0;i<polygon.length;i++)if(onSegment(polygon[i],polygon[(i+1)%polygon.length],point))return true;
 let inside=false;const [r,c]=point;
 for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
  const [ri,ci]=polygon[i],[rj,cj]=polygon[j];
  if(((ri>r)!==(rj>r))&&(c<(cj-ci)*(r-ri)/(rj-ri)+ci))inside=!inside;
 }
 return inside;
}
function polygonIntersectsCell(points,r,c){
 const corners=[[r,c],[r,c+1],[r+1,c+1],[r+1,c]],edges=corners.map((point,index)=>[point,corners[(index+1)%4]]);
 if(points.some(([pr,pc])=>pr>=r-EPSILON&&pr<=r+1+EPSILON&&pc>=c-EPSILON&&pc<=c+1+EPSILON))return true;
 if(corners.some(corner=>pointInPolygon(corner,points)))return true;
 for(let i=0;i<points.length;i++)for(const [a,b] of edges)if(segmentsIntersect(points[i],points[(i+1)%points.length],a,b))return true;
 return false;
}
function coverageCells(shape,{rows,cols}){
 if(shape.type==='cells')return clone(shape.cells).sort(compareCells);
 const minR=Math.max(0,Math.floor(Math.min(...shape.points.map(point=>point[0])))),maxR=Math.min(rows-1,Math.ceil(Math.max(...shape.points.map(point=>point[0])))-1);
 const minC=Math.max(0,Math.floor(Math.min(...shape.points.map(point=>point[1])))),maxC=Math.min(cols-1,Math.ceil(Math.max(...shape.points.map(point=>point[1])))-1),cells=[];
 for(let r=minR;r<=maxR;r++)for(let c=minC;c<=maxC;c++)if(polygonIntersectsCell(shape.points,r,c))cells.push([r,c]);
 if(!cells.length)fail('EMPTY_OVERLAY_COVERAGE','Polygon overlay не покрывает ни одной ячейки карты');return cells;
}
function assertProtectionMasks(protectionMasks,{rows,cols},cells){
 if(protectionMasks===undefined||protectionMasks===null)return;
 if(!plain(protectionMasks))fail('INVALID_PROTECTION_MASKS','protectionMasks должен быть объектом');
 for(const name of MASK_NAMES){
  const mask=protectionMasks[name];if(mask===undefined)continue;
  if(!Array.isArray(mask)||mask.length!==rows||mask.some(row=>!Array.isArray(row)||row.length!==cols))fail('INVALID_PROTECTION_MASK_DIMENSIONS',`${name} должен иметь размер ${rows}x${cols}`,{mask:name});
  for(const [r,c] of cells)if(mask[r][c])fail('PROTECTED_GROUND_OVERLAY_CELL',`Ячейка ${r}:${c} защищена маской ${name}`,{cell:[r,c],mask:name});
 }
}
function pointInTriangle(point,a,b,c){
 const d1=orientation(point,a,b),d2=orientation(point,b,c),d3=orientation(point,c,a),hasNeg=d1<-EPSILON||d2<-EPSILON||d3<-EPSILON,hasPos=d1>EPSILON||d2>EPSILON||d3>EPSILON;return !(hasNeg&&hasPos);
}
function triangulate(points){
 const indices=points.map((_point,index)=>index),triangles=[],signed=points.reduce((sum,point,index)=>sum+point[1]*points[(index+1)%points.length][0]-points[(index+1)%points.length][1]*point[0],0);
 if(signed<0)indices.reverse();
 while(indices.length>3){let clipped=false;
  for(let cursor=0;cursor<indices.length;cursor++){
   const previous=indices[(cursor+indices.length-1)%indices.length],current=indices[cursor],next=indices[(cursor+1)%indices.length];
   if(orientation(points[previous],points[current],points[next])<=EPSILON)continue;
   if(indices.some(index=>index!==previous&&index!==current&&index!==next&&pointInTriangle(points[index],points[previous],points[current],points[next])))continue;
   triangles.push([previous,current,next]);indices.splice(cursor,1);clipped=true;break;
  }
  if(!clipped)fail('POLYGON_TRIANGULATION_FAILED','Не удалось построить детерминированную сетку polygon overlay');
 }
 triangles.push([...indices]);return triangles;
}
function createMeshPlan(record,{metresPerCell=4.1}={}){
 if(!finite(metresPerCell)||metresPerCell<=0)fail('INVALID_CELL_SIZE','metresPerCell должен быть положительным числом');
 const y=record.render.groundHeightM+record.render.zOffsetM,materialId=record.render.materialId;
 if(record.geometry.type==='cells')return {schema:WALK_MAP_GROUND_OVERLAY_MESH_PLAN_SCHEMA,recordId:record.id,materialId,coordinateSystem:'x=column,z=row,y=height',primitives:record.coverageCells.map(([r,c])=>({key:`cell:${r}:${c}`,kind:'cell',cell:[r,c],verticesM:[[c*metresPerCell,y,r*metresPerCell],[(c+1)*metresPerCell,y,r*metresPerCell],[(c+1)*metresPerCell,y,(r+1)*metresPerCell],[c*metresPerCell,y,(r+1)*metresPerCell]],triangles:[[0,1,2],[0,2,3]]}))};
 const points=record.geometry.points;
 return {schema:WALK_MAP_GROUND_OVERLAY_MESH_PLAN_SCHEMA,recordId:record.id,materialId,coordinateSystem:'x=column,z=row,y=height',primitives:[{key:`polygon:${record.id}`,kind:'polygon',verticesM:points.map(([r,c])=>[c*metresPerCell,y,r*metresPerCell]),triangles:triangulate(points)}]};
}

export function normalizeWalkMapGroundOverlayRecord(record,{map,rows,cols,protectionMasks}={}){
 if(!plain(record))fail('INVALID_OVERLAY_RECORD','Ground overlay record должен быть объектом');
 const dimensions=assertDimensions(map,rows,cols),id=assertStableId(record.id),material=assertMaterial(record.materialId),geometry=normalizeShape(record.geometry??record.shape,dimensions),cells=coverageCells(geometry,dimensions);
 assertProtectionMasks(protectionMasks,dimensions,cells);
 const groundHeightM=record.render?.groundHeightM??0,zOffsetM=record.render?.zOffsetM??0.02;
 if(!finite(groundHeightM)||!finite(zOffsetM)||zOffsetM<0||zOffsetM>1)fail('INVALID_OVERLAY_HEIGHT','Высота ground overlay некорректна');
 return {...clone(record),schema:WALK_MAP_GROUND_OVERLAY_SCHEMA,id,kind:'ground-overlay',materialId:record.materialId,geometry,coverageCells:cells,render:{...clone(record.render??{}),adapter:'ground-overlay-render/v1',materialId:material.renderMaterialId,groundHeightM,zOffsetM},navigation:{...clone(record.navigation??{}),adapter:'road-navigation-overlay/v1',surfaceId:material.navigationSurfaceId,vehicleSpeedFactor:material.vehicleSpeedFactor,rebuildRequired:true},protection:{...clone(record.protection??{}),policy:'reject-protected-cells/v1',checkedCells:clone(cells)},dependencies:clone(WALK_MAP_GROUND_OVERLAY_DEPENDENCIES)};
}

export function compileWalkMapGroundOverlay({record,id,materialId,shape,map,rows,cols,protectionMasks,groundHeightM=0,zOffsetM=0.02,metresPerCell=4.1,metadata={}}={}){
 const candidate=record??{schema:WALK_MAP_GROUND_OVERLAY_SCHEMA,id,kind:'ground-overlay',materialId,geometry:clone(shape),render:{groundHeightM,zOffsetM},metadata:clone(metadata)},normalized=normalizeWalkMapGroundOverlayRecord(candidate,{map,rows,cols,protectionMasks});
 return {record:normalized,source:{dataset:'custom',id:normalized.id,adapter:WALK_MAP_GROUND_OVERLAY_ADAPTER_ID},affectedCells:clone(normalized.coverageCells),dependencies:clone(WALK_MAP_GROUND_OVERLAY_DEPENDENCIES),meshPlan:createMeshPlan(normalized,{metresPerCell})};
}

function commandMetadata(record,metadata){return {...clone(metadata),adapter:WALK_MAP_GROUND_OVERLAY_ADAPTER_ID,materialId:record.materialId,dependencies:clone(WALK_MAP_GROUND_OVERLAY_DEPENDENCIES),affectedCells:clone(record.coverageCells)}}
export function createWalkMapGroundOverlayAddCommand({record,map,rows,cols,protectionMasks,metadata={}}={}){
 const normalized=normalizeWalkMapGroundOverlayRecord(record,{map,rows,cols,protectionMasks});return makeWalkMapObjectAddCommand({source:{dataset:'custom',id:normalized.id,adapter:WALK_MAP_GROUND_OVERLAY_ADAPTER_ID},object:normalized,metadata:commandMetadata(normalized,metadata)});
}
export function createWalkMapGroundOverlayDeleteCommand({record,map,rows,cols,protectionMasks,metadata={}}={}){
 const normalized=normalizeWalkMapGroundOverlayRecord(record,{map,rows,cols,protectionMasks});return makeWalkMapObjectDeleteCommand({source:{dataset:'custom',id:normalized.id,adapter:WALK_MAP_GROUND_OVERLAY_ADAPTER_ID},before:normalized,metadata:commandMetadata(normalized,metadata)});
}

export function createWalkMapGroundOverlayMeshPlan(record,options={}){return createMeshPlan(record,options)}
