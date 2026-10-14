import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadCurrentIndex,CELL_METRES,VISUAL_SPATIAL_STATE,visualKeysForCell,canEvictVisual} from './source_index.mjs';

const index=loadCurrentIndex();
let checks=0;
const ok=(value,message)=>{assert(value,message);checks++};
const equal=(actual,expected)=>{assert.equal(actual,expected);checks++};
const deepEqual=(actual,expected)=>{assert.deepEqual(actual,expected);checks++};
const rejects=(fn,pattern)=>{assert.throws(fn,pattern);checks++};
equal(index.records.length,9901);
deepEqual(index.counts,{authored:242,procedural:9394,transport:265});
const all=new Set(),keys=new Set();
for(const [cell,ordinals] of Object.entries(index.catalogAnchorCells)){
 ok(/^-?\d+:-?\d+$/.test(cell));
 for(const ordinal of ordinals){ok(!all.has(ordinal));all.add(ordinal);equal(index.records[ordinal].anchorCell,cell);}
}
equal(all.size,9901);
for(const row of index.records){
 ok(!keys.has(row.key));keys.add(row.key);
 equal(row.visualState,'not_streamed');
 equal(row.visualSpatialState,VISUAL_SPATIAL_STATE);
 equal(row.visualEvictionEligible,false);
 equal(row.editState,'owner_receipt_required');
 ok(row.positionLocalM.every(Number.isFinite));
 const expected=`${Math.floor(row.positionLocalM[0]/CELL_METRES)}:${Math.floor(row.positionLocalM[2]/CELL_METRES)}`;
 equal(row.anchorCell,expected);
}
equal(index.visualSpatialState,VISUAL_SPATIAL_STATE);
equal(index.visualCellIncidence,null);
equal(index.visualEvictionEnabled,false);
ok(!Object.hasOwn(index,'cells'),'ambiguous visual-looking cells field must not exist');
equal(index.renderedIds,0);
equal(index.editorReady,false);
equal(index.ownerReceipt,null);

// The real 1.5 km railway has a source proxy spanning many catalog cells.
// Its one anchor cell must never be interpreted as a visual-load/evict cell.
const longRail=index.records.find(row=>row.dataset==='railway-alignment');
ok(longRail,'original railway alignment must be catalogued');
const catalog=JSON.parse(readFileSync(new URL('../../../godot/mafiozi_walk/data/map_editor/catalog.json',import.meta.url),'utf8'));
const railProxy=catalog.objects.find(row=>row.key===longRail.key).sourceRecord.proxy;
equal(railProxy.type,'rect');
ok(railProxy.halfDepth*2>CELL_METRES);
const farCell=`${Math.floor((railProxy.x-index.source.originM[0])/CELL_METRES)}:${Math.floor((railProxy.z+railProxy.halfDepth-index.source.originM[2])/CELL_METRES)}`;
ok(farCell!==longRail.anchorCell,'railway has geometry far beyond its anchor cell');
rejects(()=>visualKeysForCell(index,farCell),/Visual cell incidence unavailable/);
equal(canEvictVisual(index,longRail.key),false);
const road=index.records.find(row=>row.dataset==='road-markings');
ok(road,'road marking must be catalogued');
equal(canEvictVisual(index,road.key),false);
rejects(()=>visualKeysForCell(index,road.anchorCell),/Visual cell incidence unavailable/);

console.log(JSON.stringify({suite:'actual-9901-readonly-source-index',checks,failures:[],counts:index.counts,catalogAnchorCells:Object.keys(index.catalogAnchorCells).length,visualCellIncidence:0,visualEvictionEnabled:false,renderedIds:0,editorReady:false,gpu:false}));
