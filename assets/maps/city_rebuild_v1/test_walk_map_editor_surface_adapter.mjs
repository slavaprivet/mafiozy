import assert from 'node:assert/strict';
import {createWalkMapSurfaceAdapter} from './walk_map_editor_surface_adapter.mjs';

const previews=[],cancelled=[],adapter=createWalkMapSurfaceAdapter({rows:12,cols:12,metresPerCell:1,idFactory:()=> 'stroke-1',onPreview:value=>previews.push(value),onCancel:(value,reason)=>cancelled.push([value,reason])});
adapter.begin({x:.5,z:.5,materialId:'asphalt',radiusM:.25});adapter.move({x:9.5,z:.5});const command=adapter.finish();
assert.equal(command.type,'surface.set-stroke');assert.equal(command.stroke.id,'stroke-1');assert.equal(command.stroke.materialId,'asphalt');
const cells=command.stroke.shape.cells,keys=new Set(cells.map(([r,c])=>`${r}:${c}`));assert.equal(keys.size,cells.length);for(let c=0;c<=9;c++)assert.ok(keys.has(`0:${c}`),`gap at 0:${c}`);
assert.deepEqual(cells,[...cells].sort((a,b)=>a[0]-b[0]||a[1]-b[1]));assert.ok(previews.length>=2);

adapter.begin({x:-2,z:-2,materialId:'grass',mode:'erase',radiusM:3});const clipped=adapter.finish().stroke;assert.ok(clipped.shape.cells.length>0);assert.ok(clipped.shape.cells.every(([r,c])=>r>=0&&c>=0&&r<12&&c<12));assert.equal(clipped.mode,'erase');
adapter.begin({x:5,z:5,materialId:'earth',radiusM:1});const previewCount=previews.length;adapter.setRadius(2);assert.equal(previews.length,previewCount+1);assert.equal(adapter.radiusM,2);assert.equal(adapter.cancel('escape'),true);assert.equal(adapter.active,false);assert.equal(cancelled.at(-1)[1],'escape');assert.equal(adapter.cancel(),false);

assert.throws(()=>adapter.begin({x:1,z:1,materialId:'lava'}),/Unsupported surface material/);
assert.throws(()=>adapter.begin({x:1,z:1,materialId:'grass',radiusM:0}),/radius/);
adapter.dispose();

const quota=createWalkMapSurfaceAdapter({rows:12,cols:12,metresPerCell:1,maxStrokeCells:4,idFactory:()=> 'quota'});
const quotaStart=quota.begin({x:.5,z:.5,materialId:'grass',radiusM:.05});
assert.throws(()=>quota.move({x:9.5,z:.5}),/exceeds 4 cells/);assert.equal(quota.active,true);assert.deepEqual(quota.preview(),quotaStart,'failed quota move must be atomic');
quota.move({x:3.5,z:.5});const quotaCells=quota.finish().stroke.shape.cells;assert.deepEqual(quotaCells,[[0,0],[0,1],[0,2],[0,3]]);

const beginQuota=createWalkMapSurfaceAdapter({rows:5,cols:5,metresPerCell:1,maxStrokeCells:1});
assert.throws(()=>beginQuota.begin({x:2.5,z:2.5,materialId:'grass',radiusM:1}),/exceeds 1 cells/);assert.equal(beginQuota.active,false);

const far=createWalkMapSurfaceAdapter({rows:8,cols:8,metresPerCell:1,idFactory:()=> 'far'});
far.begin({x:-1e9,z:-1e9,materialId:'earth',radiusM:.25});far.move({x:7.5,z:7.5});const farCells=far.finish().stroke.shape.cells;
assert.ok(farCells.length>0);assert.ok(farCells.every(([r,c])=>r>=0&&c>=0&&r<8&&c<8));assert.deepEqual(farCells,[...farCells].sort((a,b)=>a[0]-b[0]||a[1]-b[1]));

const disposeEvents=[],disposeAdapter=createWalkMapSurfaceAdapter({rows:4,cols:4,metresPerCell:1,onCancel:(value,reason)=>disposeEvents.push([value,reason])});
disposeAdapter.begin({x:.5,z:.5});assert.equal(disposeAdapter.dispose(),true);assert.equal(disposeAdapter.dispose(),false);assert.equal(disposeAdapter.active,false);assert.equal(disposeEvents.length,1);assert.equal(disposeEvents[0][1],'dispose');

const isolated=createWalkMapSurfaceAdapter({rows:3,cols:3,metresPerCell:1,onPreview:value=>{if(value.shape.cells[0])value.shape.cells[0][0]=999}});
isolated.begin({x:.5,z:.5,radiusM:.05});assert.deepEqual(isolated.finish().stroke.shape.cells,[[0,0]],'preview callbacks must not mutate the active stroke');

console.log('walk map editor surface adapter: PASS');
