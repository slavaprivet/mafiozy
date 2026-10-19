export const WALK_MAP_TOPOLOGY_PAINT_SCHEMA='mafiozi.walk-map-editor.topology-paint/v1';
export const WALK_MAP_TOPOLOGY_PAINT_ADAPTER_ID='city-topology-paint-v1';
export const WALK_MAP_TOPOLOGY_PAINT_MATERIALS=Object.freeze({asphalt:0,grass:8});

const ROWS=200,COLS=180,METRES_PER_CELL=4.1,EDITABLE_TILES=new Set([0,8]);
const BASE_DEPENDENCIES=Object.freeze(['topology-render','topology-collision','walk-navigation','minimap']);
const ROAD_DEPENDENCIES=Object.freeze(['vehicle-navigation','road-dressing','parking','parking-access','road-access']);

export class WalkMapTopologyPaintError extends Error{constructor(code,message,details={}){super(message);this.name='WalkMapTopologyPaintError';this.code=code;this.details=structuredClone(details)}}
function fail(code,message,details){throw new WalkMapTopologyPaintError(code,message,details)}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)}
function finite(value){return typeof value==='number'&&Number.isFinite(value)}
function clone(value){return value===undefined?undefined:structuredClone(value)}
function cellKey(r,c){return `${r}:${c}`}
function assertTopology(topology){
 if(!plain(topology)||topology.schema!=='mafiozy.city-rebuild-placement-topology/v1'||topology.map?.rows!==ROWS||topology.map?.cols!==COLS||topology.map?.worldUnitsPerCell!==METRES_PER_CELL)fail('TOPOLOGY_SCHEMA_UNSUPPORTED','Редактор покрытий требует исходную сетку 200×180 с шагом 4,1 м');
 for(const name of ['grid','roadMask','walkableMask','protectedMask','policeMask','bridgeDeckMask'])if(!Array.isArray(topology[name])||topology[name].length!==ROWS||topology[name].some(row=>!Array.isArray(row)||row.length!==COLS))fail('TOPOLOGY_DIMENSIONS_INVALID',`Повреждена матрица topology.${name}`);
 return topology;
}
function hashPush(state,value){for(let index=0;index<value.length;index++){const code=value.charCodeAt(index);state.a=Math.imul(state.a^code,16777619);state.b=Math.imul(state.b^code,2246822519)}return state}
export function walkMapTopologySourceRevision(topology){
 assertTopology(topology);const state={a:2166136261,b:3335557771};hashPush(state,`${topology.schema}|${ROWS}|${COLS}|${METRES_PER_CELL}|`);
 for(const name of ['grid','roadMask','protectedMask','policeMask','bridgeDeckMask']){hashPush(state,`${name}:`);for(let r=0;r<ROWS;r++){for(let c=0;c<COLS;c++)hashPush(state,`${topology[name][r][c]},`);hashPush(state,';')}}
 return `topology-v1:${ROWS}x${COLS}:${(state.a>>>0).toString(16).padStart(8,'0')}${(state.b>>>0).toString(16).padStart(8,'0')}`;
}
function materialTile(materialId){const tile=WALK_MAP_TOPOLOGY_PAINT_MATERIALS[materialId];if(tile===undefined)fail('TOPOLOGY_MATERIAL_UNSUPPORTED',`Покрытие ${String(materialId)} не поддерживается: доступны только асфальт и трава`);return tile}
function normalizeCell(value,index){const r=value?.r??value?.row??value?.[0],c=value?.c??value?.column??value?.[1];if(!Number.isInteger(r)||!Number.isInteger(c))fail('TOPOLOGY_CELL_INVALID',`Некорректная клетка кисти #${index}`);if(r<0||c<0||r>=ROWS||c>=COLS)fail('TOPOLOGY_CELL_OUT_OF_BOUNDS',`Клетка ${r}:${c} находится вне сетки 200×180`,{r,c});return {r,c}}
function normalizeRequestedCells(topology,cells,tile){
 if(!Array.isArray(cells)||!cells.length)fail('TOPOLOGY_STROKE_EMPTY','Кисть не содержит клеток');if(cells.length>ROWS*COLS)fail('TOPOLOGY_STROKE_TOO_LARGE','Кисть превышает размер карты');
 const unique=new Map();for(let index=0;index<cells.length;index++){const {r,c}=normalizeCell(cells[index],index),key=cellKey(r,c);if(!unique.has(key))unique.set(key,{r,c,from:topology.grid[r][c],to:tile})}
 return [...unique.values()].sort((a,b)=>a.r-b.r||a.c-b.c);
}
function normalizeInventory(value){
 const inventory=typeof value==='function'?value():value;if(!plain(inventory)||inventory.complete?.buildings!==true||inventory.complete?.parking!==true||inventory.complete?.roadAccess!==true||!Array.isArray(inventory.buildings)||!Array.isArray(inventory.parkingKeepouts)||!Array.isArray(inventory.roadAccessCells))fail('TOPOLOGY_INVENTORY_INCOMPLETE','Покраска topology требует полные списки зданий, парковок и дорожных доступов');return inventory;
}
function rectCR(value){
 const direct=value?.rectCR||value?.footprint||value;if([direct?.minC,direct?.minR,direct?.maxC,direct?.maxR].every(finite))return {minC:direct.minC,minR:direct.minR,maxC:direct.maxC,maxR:direct.maxR};
 const metres=value?.rectM||value?.rect||value;if([metres?.minX,metres?.minZ,metres?.maxX,metres?.maxZ].every(finite))return {minC:metres.minX/METRES_PER_CELL,minR:metres.minZ/METRES_PER_CELL,maxC:metres.maxX/METRES_PER_CELL,maxR:metres.maxZ/METRES_PER_CELL};return null;
}
function overlapsCell(rect,r,c){return !!rect&&c<rect.maxC&&c+1>rect.minC&&r<rect.maxR&&r+1>rect.minR}
function accessCell(value,index){const raw=value?.cellRC||value?.roadProbeRC||value,r=raw?.r??raw?.row??raw?.[0],c=raw?.c??raw?.column??raw?.[1];if(!finite(r)||!finite(c))fail('TOPOLOGY_ROAD_ACCESS_INVALID',`Некорректная точка дорожного доступа #${index}`);return {r:Math.floor(r),c:Math.floor(c),id:value?.id??value?.buildingId??null}}
function protectedMasks(topology,r,c){return ['protectedMask','policeMask','bridgeDeckMask'].filter(name=>!!topology[name][r][c])}
function validateEditCell(topology,edit,inventory){
 const {r,c,from,to}=edit;if(from===to)return;
 const masks=protectedMasks(topology,r,c);if(masks.length)fail('TOPOLOGY_CELL_PROTECTED','Защищённую клетку карты нельзя перекрашивать',{r,c,masks});
 if(!EDITABLE_TILES.has(from)){const reason=from===9?'tile 9 — тротуар/бордюр, а не земля':from===14?'tile 14 — песок, а не земля':from===16?'клетка относится к воде':'код покрытия не доказан для безопасного редактирования';fail('TOPOLOGY_SOURCE_TILE_LOCKED',`Клетка ${r}:${c} заблокирована: ${reason}`,{r,c,tile:from})}
 for(const building of inventory.buildings)for(const [part,value] of [['footprint',building.footprint],['clearance',building.clearance],['entryCorridor',building.entryCorridor]])if(overlapsCell(rectCR(value),r,c))fail('TOPOLOGY_BUILDING_OVERLAP','Покрытие под зданием или его входом изменять нельзя без пересборки размещения',{r,c,buildingId:building.id??null,part});
 for(const parking of inventory.parkingKeepouts)if(overlapsCell(rectCR(parking),r,c))fail('TOPOLOGY_PARKING_OVERLAP','Покрытие парковки или её въезда изменять нельзя без пересборки парковки',{r,c,parkingId:parking.id??parking.lotId??null});
}
function allAccessCells(inventory){
 const result=inventory.roadAccessCells.map(accessCell);for(const building of inventory.buildings)if(building.entry?.roadProbeRC)result.push(accessCell({roadProbeRC:building.entry.roadProbeRC,id:building.id},result.length));return result;
}
function assertRoadAccess(grid,roadMask,inventory){for(const access of allAccessCells(inventory)){if(access.r<0||access.c<0||access.r>=ROWS||access.c>=COLS)fail('TOPOLOGY_ROAD_ACCESS_INVALID','Точка дорожного доступа находится вне карты',access);if(!roadMask[access.r][access.c]||![0,19].includes(grid[access.r][access.c]))fail('TOPOLOGY_ROAD_ACCESS_BLOCKED','Штрих перекрывает обязательный дорожный доступ здания или парковки',access)}}
function assertConnectedRoads(roadMask){
 let start=null,total=0;for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++)if(roadMask[r][c]){total++;if(!start)start=[r,c]}if(!start)fail('TOPOLOGY_ROAD_NETWORK_EMPTY','На карте должна остаться дорожная сеть');
 const queue=[start],seen=new Uint8Array(ROWS*COLS);seen[start[0]*COLS+start[1]]=1;let count=0;for(let index=0;index<queue.length;index++){const [r,c]=queue[index];count++;for(const [dr,dc] of [[-1,0],[1,0],[0,-1],[0,1]]){const rr=r+dr,cc=c+dc,key=rr*COLS+cc;if(rr<0||cc<0||rr>=ROWS||cc>=COLS||seen[key]||!roadMask[rr][cc])continue;seen[key]=1;queue.push([rr,cc])}}
 if(count!==total)fail('TOPOLOGY_ROAD_NETWORK_DISCONNECTED','Штрих создаёт изолированную дорогу или разрывает существующую сеть',{connected:count,total});
}
function updateValidation(topology,edits){
 if(!plain(topology.validation))return;topology.validation={...topology.validation};if(plain(topology.validation.counts)){const counts={...topology.validation.counts};for(const {from,to} of edits)if(from!==to){if(Number.isSafeInteger(counts[String(from)]))counts[String(from)]--;if(Number.isSafeInteger(counts[String(to)]))counts[String(to)]++}topology.validation.counts=counts;if(Number.isSafeInteger(topology.validation.connectedRoadCells))topology.validation.connectedRoadCells=(counts['0']||0)+(counts['19']||0)}
}
function patchedTopology(topology,edits){
 const output={...topology,grid:[...topology.grid],roadMask:[...topology.roadMask],walkableMask:[...topology.walkableMask]},rows=new Set(edits.map(edit=>edit.r));for(const r of rows){output.grid[r]=[...topology.grid[r]];output.roadMask[r]=[...topology.roadMask[r]];output.walkableMask[r]=[...topology.walkableMask[r]]}
 for(const {r,c,to} of edits){output.grid[r][c]=to;output.roadMask[r][c]=to===0?1:0;output.walkableMask[r][c]=output.policeMask[r][c]?0:1}updateValidation(output,edits);return output;
}
function normalizeOperation(operation){if(operation?.schema!==WALK_MAP_TOPOLOGY_PAINT_SCHEMA||operation.kind!=='topology-paint'||typeof operation.sourceRevision!=='string'||!Array.isArray(operation.edits))fail('TOPOLOGY_OPERATION_INVALID','Некорректная операция покраски topology');return operation}

export function createWalkMapTopologyPaintOperation({topology,cells,materialId,id='topology-paint'}={}){
 assertTopology(topology);const tile=materialTile(materialId),edits=normalizeRequestedCells(topology,cells,tile);return {schema:WALK_MAP_TOPOLOGY_PAINT_SCHEMA,id:String(id),kind:'topology-paint',materialId,sourceRevision:walkMapTopologySourceRevision(topology),edits};
}

export function createWalkMapTopologyRestoreOperation({topology,baseTopology,cells,id='topology-restore'}={}){
 assertTopology(topology);assertTopology(baseTopology);if(!Array.isArray(cells)||!cells.length)fail('TOPOLOGY_STROKE_EMPTY','Кисть не содержит клеток');if(cells.length>ROWS*COLS)fail('TOPOLOGY_STROKE_TOO_LARGE','Кисть превышает размер карты');const unique=new Map();for(let index=0;index<cells.length;index++){const {r,c}=normalizeCell(cells[index],index),key=cellKey(r,c);if(unique.has(key))continue;const to=baseTopology.grid[r][c];if(!EDITABLE_TILES.has(to))fail('TOPOLOGY_RESTORE_TILE_LOCKED',`Нельзя снять редакторское покрытие с клетки ${r}:${c}: исходный tile ${to} не относится к асфальту или траве`,{r,c,tile:to});unique.set(key,{r,c,from:topology.grid[r][c],to})}return {schema:WALK_MAP_TOPOLOGY_PAINT_SCHEMA,id:String(id),kind:'topology-paint',materialId:'trusted-base-restore',sourceRevision:walkMapTopologySourceRevision(topology),edits:[...unique.values()].sort((a,b)=>a.r-b.r||a.c-b.c)};
}

export function compileWalkMapTopologyPaint({topology,operation,inventory}={}){
 assertTopology(topology);const normalized=normalizeOperation(operation),actualRevision=walkMapTopologySourceRevision(topology);if(normalized.sourceRevision!==actualRevision)fail('TOPOLOGY_SOURCE_STALE','Topology изменилась после начала штриха',{expected:actualRevision,actual:normalized.sourceRevision});
 const complete=normalizeInventory(inventory),seen=new Set(),edits=[];for(let index=0;index<normalized.edits.length;index++){const raw=normalized.edits[index],{r,c}=normalizeCell(raw,index),key=cellKey(r,c);if(seen.has(key))fail('TOPOLOGY_CELL_DUPLICATE',`Клетка ${key} повторяется в операции`);seen.add(key);if(!EDITABLE_TILES.has(raw.to))fail('TOPOLOGY_TARGET_TILE_UNSUPPORTED',`Разрешены только tile 0 (асфальт) и tile 8 (трава)`,{r,c,tile:raw.to});const current=topology.grid[r][c];if(current!==raw.from)fail('TOPOLOGY_CELL_STALE',`Клетка ${key} изменилась после начала штриха`,{expected:raw.from,actual:current});edits.push({r,c,from:current,to:raw.to})}
 edits.sort((a,b)=>a.r-b.r||a.c-b.c);const changed=edits.filter(edit=>edit.from!==edit.to);for(const edit of changed)validateEditCell(topology,edit,complete);if(!changed.length)return {ok:true,adapter:WALK_MAP_TOPOLOGY_PAINT_ADAPTER_ID,changed:false,topology,edits:[],dependencies:[],fullRebuild:false,sourceRevision:actualRevision,resultRevision:actualRevision,receipt:{schema:'mafiozi.walk-map-editor.topology-paint-receipt/v1',operationId:normalized.id,changed:false,sourceRevision:actualRevision,resultRevision:actualRevision,edits:[],dependencies:[],inverseOperation:null}};
 const result=patchedTopology(topology,changed),roadChanged=changed.some(edit=>(edit.from===0)!==(edit.to===0));if(roadChanged){assertRoadAccess(result.grid,result.roadMask,complete);assertConnectedRoads(result.roadMask)}const resultRevision=walkMapTopologySourceRevision(result),dependencies=[...BASE_DEPENDENCIES,...(roadChanged?ROAD_DEPENDENCIES:[])],inverseOperation={schema:WALK_MAP_TOPOLOGY_PAINT_SCHEMA,id:`undo:${normalized.id}`,kind:'topology-paint',materialId:'mixed-restore',sourceRevision:resultRevision,edits:changed.map(({r,c,from,to})=>({r,c,from:to,to:from}))};
 const receipt={schema:'mafiozi.walk-map-editor.topology-paint-receipt/v1',operationId:normalized.id,changed:true,sourceRevision:actualRevision,resultRevision,edits:clone(changed),dependencies:[...dependencies],inverseOperation};return {ok:true,adapter:WALK_MAP_TOPOLOGY_PAINT_ADAPTER_ID,changed:true,topology:result,edits:clone(changed),dependencies,fullRebuild:true,sourceRevision:actualRevision,resultRevision,receipt};
}

export function createWalkMapTopologyPaintRebuilder({getTopology,installTopology,inventory}={}){
 if(typeof getTopology!=='function'||typeof installTopology!=='function')throw new Error('Topology paint rebuilder requires getTopology/installTopology');return async function rebuild({operation,label='Topology paint'}={}){const before=getTopology(),compiled=compileWalkMapTopologyPaint({topology:before,operation,inventory});if(!compiled.changed)return compiled;try{await installTopology(compiled.topology,{label,dependencies:compiled.dependencies,fullRebuild:true,committed:true,receipt:compiled.receipt});return compiled}catch(error){try{await installTopology(before,{label,dependencies:compiled.dependencies,fullRebuild:true,rollback:true,error:error.message,receipt:compiled.receipt})}catch(rollbackError){throw new AggregateError([error,rollbackError],`${label}: rebuild and rollback failed`)}throw error}};
}

export const WALK_MAP_TOPOLOGY_PAINT_DEPENDENCIES=Object.freeze({base:BASE_DEPENDENCIES,road:ROAD_DEPENDENCIES});
