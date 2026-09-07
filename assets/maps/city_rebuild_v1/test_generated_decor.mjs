import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {polygonsOverlap} from './decor_placement.mjs';
import {pointInPolygon} from './topology.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),read=n=>JSON.parse(fs.readFileSync(path.join(here,n)));
const p=read('decor_placement.v1.json'),t=read('topology_for_placement.json'),b=read(p.buildingsSource.file);
for(const src of[p.topologySource,p.buildingsSource,p.infrastructureSource])assert.equal(hash(fs.readFileSync(path.join(here,src.file))),src.sha256,'Final placement uses stale upstream '+src.file);
assert.equal(p.scope,'isolated_walk_preview');assert.equal(p.productionPhysicsAuthorized,false);assert.equal(p.pendingHostSnapshot,true);assert.equal(p.errors.length,0);assert.equal(p.counts.fountains,8);
const rect=x=>[[x.minC,x.minR],[x.maxC,x.minR],[x.maxC,x.maxR],[x.minC,x.maxR]];
for(const instance of p.instances){
 const bytes=fs.readFileSync(path.join(root,instance.binding.url.replace(/^\//,'')));assert.equal(bytes.length,instance.binding.bytes);assert.equal(hash(bytes),instance.binding.sha256);
 for(const building of b.instances){assert.equal(polygonsOverlap(instance.clearancePolygonCR,rect(building.clearance)),false,instance.id+' vs '+building.id);assert.equal(polygonsOverlap(instance.clearancePolygonCR,rect(building.entryCorridor)),false,instance.id+' entrance');}
 const poly=instance.clearancePolygonCR;
 for(let r=Math.floor(Math.min(...poly.map(x=>x[1])));r<Math.ceil(Math.max(...poly.map(x=>x[1])));r++)for(let c=Math.floor(Math.min(...poly.map(x=>x[0])));c<Math.ceil(Math.max(...poly.map(x=>x[0])));c++)if(polygonsOverlap(poly,rect({minR:r,maxR:r+1,minC:c,maxC:c+1}))){assert.ok([8,9,14].includes(t.grid[r][c]),instance.id+' illegal surface');assert.equal(t.protectedMask[r][c],0,instance.id+' protected surface');}
 if(instance.role==='roadside_lamp'){assert.equal(t.grid[Math.floor(instance.r)][Math.floor(instance.c)],9);assert.deepEqual(instance.transform.modelLocalOffsetM,[0,0,0]);assert.ok(instance.collision.sourceBodies.every(x=>/^Lamp_Base_/.test(x.node)));}
}
for(let i=0;i<p.instances.length;i++)for(let j=i+1;j<p.instances.length;j++)assert.equal(polygonsOverlap(p.instances[i].clearancePolygonCR,p.instances[j].clearancePolygonCR),false);
const lamps=p.instances.filter(x=>x.role==='roadside_lamp'),districtCounts={};for(const l of lamps){const d=t.districts.find(x=>pointInPolygon([l.c,l.r],x.polygon_grid));assert.ok(d);districtCounts[d.id]=(districtCounts[d.id]||0)+1;}
assert.equal(Object.keys(districtCounts).length,8);for(const n of Object.values(districtCounts))assert.equal(n,16);
const seen=new Set();for(const a of p.asphaltRects)for(let r=a.minR;r<a.maxR;r++)for(let c=a.minC;c<a.maxC;c++){const key=`${r},${c}`;assert.equal(t.grid[r][c],0);assert.equal(t.policeMask[r][c],0);assert.ok(!seen.has(key));seen.add(key);}
let expected=0;for(let r=0;r<200;r++)for(let c=0;c<180;c++)if(t.grid[r][c]===0&&!t.policeMask[r][c])expected++;
assert.equal(seen.size,expected);assert.equal(seen.size,p.counts.asphaltCells);assert.equal(p.surfaces[0].glbInstances,0);
assert.ok(p.materialDescriptors.find(x=>x.id==='MAT_CLAY_ASPHALT_CLEAN'&&x.baseColorFactor[0]<.11));
assert.equal(p.instances.filter(x=>x.role==='bridge').length,0,'Do not pretend short mini GLBs fit major crossings');assert.equal(p.bridgeFitReport.filter(x=>x.status==='NO_SINGLE_READY_GLB_FITS').length,3);
console.log(JSON.stringify({PASS:true,instances:p.instances.length,districtLamps:districtCounts,asphaltCells:seen.size,upstreamPins:'exact'}));
