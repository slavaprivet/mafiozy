import {
 createWalkMapEditorDatasetAdapter,
 createWalkMapEditorSurfaceAdapter,
 createWalkMapEditorTopologyAdapter
} from './walk_map_editor_compile.mjs';

export const WALK_MAP_EDITOR_CITY_SCHEMAS=Object.freeze({
 topology:'mafiozy.city-rebuild-placement-topology/v1',
 buildings:'mafiozi.city-rebuild.buildings-placement/v1',
 decor:'mafiozi.city-rebuild.decor-plan/v1',
 custom:'mafiozi.walk-map-editor.custom/v1'
});

export const WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT=Object.freeze({
 asphalt:Object.freeze({available:true,tile:0,evidence:'world drawTile: tile 0 is road asphalt; topology roadMask is 1 for tile 0'}),
 grass:Object.freeze({available:true,tile:8,evidence:'world drawTile and minimap: tile 8 is grass/park'}),
 earth:Object.freeze({available:false,tile:null,reason:'В актуальной topology нет отдельного доказанного кода земли; tile 9 — бордюр/плитка, tile 14 — песок'}),
 'dirt-road':Object.freeze({available:false,tile:null,reason:'В актуальной topology нет отдельного доказанного кода просёлочной дороги'})
});

const EDITABLE_SOURCE_TILES=new Set([0,8,9]);
function clone(value){return structuredClone(value);}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function fail(message){throw new Error(message);}
function assertInstancesSnapshot(snapshot,schema,label){if(!plain(snapshot)||snapshot.schema!==schema||!Array.isArray(snapshot.instances))fail(`${label} schema mismatch`);return snapshot;}
function assertEntities(entities,label){
 if(!Array.isArray(entities))fail(`${label} instances must be an array`);const ids=new Set();for(const entity of entities){if(!plain(entity)||typeof entity.id!=='string'||!entity.id||ids.has(entity.id))fail(`${label} instances require unique string ids`);ids.add(entity.id)}return entities;
}
function updateCount(output,key,value){if(plain(output.counts)&&Object.prototype.hasOwnProperty.call(output.counts,key))output.counts[key]=value;}
function instancesAdapter({dataset,id,schema,updateCounts=()=>{}}){
 return createWalkMapEditorDatasetAdapter({dataset,id,version:1,
  readEntities(snapshot){assertInstancesSnapshot(snapshot,schema,id);return clone(snapshot.instances)},
  writeEntities(snapshot,entities){assertInstancesSnapshot(snapshot,schema,id);assertEntities(entities,id);const output=clone(snapshot);output.instances=clone(entities);updateCounts(output,output.instances);return output},
  getId:entity=>entity?.id
 });
}

function buildingsAdapter(){return instancesAdapter({dataset:'buildings',id:'mafiozi-city-buildings-placement-v1',schema:WALK_MAP_EDITOR_CITY_SCHEMAS.buildings,updateCounts(output,entities){updateCount(output,'instances',entities.length);updateCount(output,'assetTypesPlaced',new Set(entities.map(entity=>entity.assetId).filter(Boolean)).size);updateCount(output,'residences',entities.filter(entity=>entity.role==='residence').length)}})}
function decorAdapter(){return instancesAdapter({dataset:'decor',id:'mafiozi-city-decor-plan-v1',schema:WALK_MAP_EDITOR_CITY_SCHEMAS.decor,updateCounts(output,entities){updateCount(output,'instances',entities.length);updateCount(output,'lamps',entities.filter(entity=>entity.role==='roadside_lamp'||/^lamp_/.test(entity.assetId||'')).length);updateCount(output,'fountains',entities.filter(entity=>/^fountain_/.test(entity.assetId||'')).length)}})}
function customAdapter(){return instancesAdapter({dataset:'custom',id:'mafiozi-walk-map-custom-v1',schema:WALK_MAP_EDITOR_CITY_SCHEMAS.custom,updateCounts(output,entities){updateCount(output,'instances',entities.length)}})}

function assertTopologyShape(snapshot){
 if(!plain(snapshot)||snapshot.schema!==WALK_MAP_EDITOR_CITY_SCHEMAS.topology||!plain(snapshot.map)||!Number.isSafeInteger(snapshot.map.rows)||!Number.isSafeInteger(snapshot.map.cols)||snapshot.map.rows<=0||snapshot.map.cols<=0)fail('City topology schema mismatch');
 const {rows,cols}=snapshot.map;for(const name of ['grid','roadMask','walkableMask','protectedMask','policeMask','bridgeDeckMask']){const matrix=snapshot[name];if(!Array.isArray(matrix)||matrix.length!==rows||matrix.some(row=>!Array.isArray(row)||row.length!==cols))fail(`City topology ${name} dimensions mismatch`)}return {rows,cols};
}
function assertCell(snapshot,row,col){const {rows,cols}=plain(snapshot?.map)?snapshot.map:{};if(!Number.isInteger(row)||!Number.isInteger(col)||row<0||col<0||row>=rows||col>=cols)fail(`City topology cell is outside ${rows}x${cols}`)}
function writeKnownSurface(snapshot,row,col,value){
 assertCell(snapshot,row,col);if(![0,8,9].includes(value))fail(`Unsupported city surface tile: ${String(value)}`);if(snapshot.protectedMask[row][col]||snapshot.policeMask[row][col]||snapshot.bridgeDeckMask[row][col])fail(`Protected city topology cell: ${row}:${col}`);
 const previous=snapshot.grid[row][col];if(!EDITABLE_SOURCE_TILES.has(previous))fail(`Unsupported source tile for surface edit: ${previous}`);snapshot.grid[row][col]=value;snapshot.roadMask[row][col]=value===0?1:0;snapshot.walkableMask[row][col]=snapshot.policeMask[row][col]?0:1;
 const counts=snapshot.validation?.counts;if(plain(counts)&&previous!==value){const oldKey=String(previous),newKey=String(value);if(Number.isSafeInteger(counts[oldKey]))counts[oldKey]--;if(Number.isSafeInteger(counts[newKey]))counts[newKey]++;if(Number.isSafeInteger(snapshot.validation.connectedRoadCells))snapshot.validation.connectedRoadCells=(counts['0']||0)+(counts['19']||0)}
}
function topologyAdapter(){return createWalkMapEditorTopologyAdapter({id:'mafiozi-city-topology-grid-v1',version:1,
 dimensions:snapshot=>assertTopologyShape(snapshot),
 readCell(snapshot,row,col){assertCell(snapshot,row,col);return snapshot.grid[row][col]},
 writeCell(snapshot,row,col,value){writeKnownSurface(snapshot,row,col,value)},
 eraseCell(_snapshot,row,col){fail(`City topology erase is unsupported without an explicit restore value at ${row}:${col}`)}
})}

export function createEmptyWalkMapEditorCustomDataset(){return {schema:WALK_MAP_EDITOR_CITY_SCHEMAS.custom,status:'empty',counts:{instances:0},instances:[]}}

export function createWalkMapEditorCitySchemaAdapters(){
 const datasetAdapters=new Map([['buildings',buildingsAdapter()],['decor',decorAdapter()],['custom',customAdapter()]]),surfaceAdapters=new Map([
  ['asphalt',createWalkMapEditorSurfaceAdapter({materialId:'asphalt',id:'mafiozi-city-asphalt-tile0-v1',version:1,paintValue:0})],
  ['grass',createWalkMapEditorSurfaceAdapter({materialId:'grass',id:'mafiozi-city-grass-tile8-v1',version:1,paintValue:8})]
 ]);
 return Object.freeze({datasetAdapters,topologyAdapter:topologyAdapter(),surfaceAdapters,surfaceSupport:WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT,schemas:WALK_MAP_EDITOR_CITY_SCHEMAS});
}
