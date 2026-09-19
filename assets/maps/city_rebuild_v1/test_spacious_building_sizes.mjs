import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildSpaciousBuildingSizes} from './build_spacious_building_sizes.mjs';
import {cellsForRect,rectanglesOverlap as overlap} from './building_placement.mjs';
const poly=r=>[[r.minC,r.minR],[r.maxC,r.minR],[r.maxC,r.maxR],[r.minC,r.maxR]];
function fixture(){
 const footprint={minC:10,minR:18,maxC:14,maxR:22},body={minC:10,minR:18,maxC:14,maxR:21.8},home={id:'home',assetId:'old_town_narrow_townhouse_v1',role:'residence',gameplayId:null,districtId:'district',binding:{sha256:'same-glb',url:'same-url'},transform:{positionM:[12*4.1,0,20*4.1],yawDegrees:0,uniformScale:1,horizontalScale:[1.5,1.1],modelLocalOffsetM:[0,.1,0]},footprint,clearance:{minC:9.5,minR:17.5,maxC:14.5,maxR:22.5},entry:{anchorRC:{c:12,r:22},roadProbeRC:{c:12,r:25.25}},entryCorridor:{minC:11.5,maxC:12.5,minR:21.9,maxR:25.3},collision:{worldBodies:[{minYM:0,maxYM:7,rectangleRC:body,polygonCR:poly(body)}]}};
 const bank={...structuredClone(home),id:'bank',assetId:'bank_small_shell_v1',role:'bank_shell',gameplayId:'bank:small',bankLayout:{roomLabels:[{id:'vault',label:'Сейфовая'}]},transform:{...home.transform,positionM:[40*4.1,0,20*4.1]},footprint:{minC:38,minR:18,maxC:42,maxR:22},clearance:{minC:37.5,minR:17.5,maxC:42.5,maxR:22.5},entry:{anchorRC:{c:40,r:22},roadProbeRC:{c:40,r:25.25}},entryCorridor:{minC:39.5,maxC:40.5,minR:21.9,maxR:25.3}};
 const grid=Array.from({length:60},()=>Array(60).fill(8));grid[25].fill(0);
 return {base:{instances:[home,bank],protectedRects:[]},topology:{status:'READY',grid,protectedMask:grid.map(r=>r.map(()=>0))},source:{districts:[{id:'district',polygon_grid:[[0,0],[60,0],[60,60],[0,60]]}]},fixtures:[{instanceId:'home',level:0,rect:[-2.5,-5,2.5,5]},{instanceId:'bank',level:0,rect:[-2,-4,2,4]}],maximumLocalMoveM:0};
}
test('sizing is pure and rescales actual footprint, door and colliders together',()=>{
 const input=fixture(),before=JSON.stringify(input),{plan,report}=buildSpaciousBuildingSizes(input),old=input.base.instances[0],next=plan.instances[0];
 assert.equal(JSON.stringify(input),before);assert.equal(report.changed,1);assert.equal(report.livePlacementWritten,false);assert.equal(report.changes[0].minWidthTarget,7);assert.deepEqual(next.binding,old.binding);assert.equal(next.id,old.id);assert.equal(next.gameplayId,old.gameplayId);assert.deepEqual(plan.instances[1],input.base.instances[1]);
 assert.ok(Math.abs(next.transform.horizontalScale[0]-2.1)<1e-10);assert.equal(next.transform.horizontalScale[1],1.1);assert.ok(Math.abs((next.footprint.maxC-next.footprint.minC)-5.6)<1e-10);
 for(const body of next.collision.worldBodies){assert.equal(body.minYM,0);assert.equal(body.maxYM,7);assert.equal(overlap(body.rectangleRC,next.entryCorridor),false);assert.deepEqual(body.polygonCR,poly(body.rectangleRC));}
 const p=next.entry.roadProbeRC;assert.equal(input.topology.grid[Math.floor(p.r)][Math.floor(p.c)],0);assert.equal(plan.footprints[0].id,next.id);assert.deepEqual(plan.doorCorridors[0],{id:next.id,...next.entryCorridor});
});
test('protected cells reject an enlargement without changing the original building',()=>{
 const input=fixture();input.topology.protectedMask[20][9]=1;
 const {plan,report}=buildSpaciousBuildingSizes(input);assert.equal(report.changed,0);assert.equal(report.unresolvedCount,1);assert.deepEqual(plan.instances,input.base.instances);assert.ok(report.unresolved[0].reasons.some(r=>r.reason==='protected_cell'));
});
test('runtime scale cap is reported for review and never silently clamps requested room width',()=>{
 const input=fixture();input.base.instances[0].transform.horizontalScale[0]=2.7;
 const {report}=buildSpaciousBuildingSizes(input);assert.equal(report.changed,1);assert.deepEqual(report.runtimeScaleCapExceptions,['home']);assert.ok(report.changes[0].targetScale[0]>3);assert.equal(report.changes[0].minWidthTarget,7);
});

if(process.env.MAFIOZY_AUDIT_SIZE_CANDIDATE==='1')test('current dry candidate retains all 75 identities and validates every changed envelope and route',()=>{
 const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),out=process.env.MAFIOZY_SIZE_CANDIDATE_DIR??path.join(root,'outputs/interiors_spacious'),read=f=>JSON.parse(fs.readFileSync(f,'utf8')),base=read(path.join(here,'buildings_placement.v1.json')),topology=read(path.join(here,'topology_for_placement.json')),candidate=read(path.join(out,'spacious_sizes.candidate.json')),report=read(path.join(out,'spacious_sizes.report.json'));
 assert.equal(candidate.instances.length,75);assert.deepEqual(candidate.instances.map(i=>i.id),base.instances.map(i=>i.id));const changed=new Set(report.changes.map(i=>i.id));
 for(const next of candidate.instances){const old=base.instances.find(i=>i.id===next.id);if(!changed.has(next.id)){assert.deepEqual(next,old);continue}assert.deepEqual(next.binding,old.binding);assert.equal(next.gameplayId,old.gameplayId);assert.equal(next.districtId,old.districtId);assert.ok(Math.hypot(next.transform.positionM[0]-old.transform.positionM[0],next.transform.positionM[2]-old.transform.positionM[2])<=report.maximumLocalMoveM+1e-6);
  for(const p of cellsForRect(next.footprint)){assert.equal(topology.grid[p.r][p.c],8,next.id);assert.equal(topology.protectedMask[p.r][p.c],0,next.id)}
  for(const p of cellsForRect(next.entryCorridor)){assert.ok([0,8,9].includes(topology.grid[p.r][p.c]),next.id);assert.equal(topology.protectedMask[p.r][p.c],0,next.id)}
  for(const other of candidate.instances)if(other.id!==next.id){assert.equal(overlap(next.clearance,other.clearance),false,next.id+' / '+other.id);assert.equal(overlap(next.footprint,other.entryCorridor),false,next.id+' blocks other door');assert.equal(overlap(next.entryCorridor,other.footprint),false,next.id+' door blocked')}
  for(const p of candidate.protectedRects){assert.equal(overlap(next.footprint,p),false,next.id+' protected geometry');assert.equal(overlap(next.entryCorridor,p),false,next.id+' protected geometry')}
  for(const b of next.collision.worldBodies){assert.equal(overlap(b.rectangleRC,next.entryCorridor),false);for(const [c,r]of b.polygonCR){assert.ok(c>=next.footprint.minC-1e-6&&c<=next.footprint.maxC+1e-6&&r>=next.footprint.minR-1e-6&&r<=next.footprint.maxR+1e-6)}}
 }
});
