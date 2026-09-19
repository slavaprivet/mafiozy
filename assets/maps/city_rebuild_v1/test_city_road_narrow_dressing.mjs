import test from 'node:test';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { createNarrowPassagePaintMask, narrowPassageSignApproaches, findNarrowPassageSignVerge } from './city_road_dressing_plan.mjs';
import { createCityRoadDressing } from './city_road_dressing.mjs';

const passage = { id: 'verified-neck', roadId: 'local-road', pathId: 'local-road:0', direction: 1, widthM: 4.1, fromApproachId: 'west-mouth', toApproachId: 'east-mouth', points: [{ x: 0, z: 0, yaw: Math.PI / 2 }, { x: 8, z: 0, yaw: Math.PI / 2 }, { x: 18, z: 0, yaw: Math.PI / 2 }] };
const mark = (kind, x = 8, z = 0, extra = {}) => ({ kind, x, z, tx: 1, tz: 0, width: .15, length: 2, roadId: passage.roadId, ...extra });

test('only two-way lines/arrows inside the finite same-road neck are suppressed', () => {
  const blocked = createNarrowPassagePaintMask([passage]);
  for (const kind of ['center_dash', 'lane_dash', 'arrow_shaft', 'arrow_head', 'arrow_turn_branch']) assert(blocked(mark(kind)));
  assert(blocked(mark('center_dash', -.5)), 'a stripe entering the finite neck cannot imply a second lane');
  for (const kind of ['edge', 'crosswalk', 'stop_line', 'yield_line', 'yield_triangle', 'one_way_arrow_shaft', 'one_way_arrow_head']) assert(!blocked(mark(kind)), 'preserve physical controls/crossing: ' + kind);
  assert(!blocked(mark('center_dash', -2))); assert(!blocked(mark('center_dash', 20))); assert(!blocked(mark('center_dash', 8, 3)));
  assert(!blocked(mark('center_dash', 8, 0, { roadId: 'transverse-road' }))); assert(!blocked(mark('arrow_shaft', 8, 0, { narrowPassageId: passage.id })));
  assert(!createNarrowPassagePaintMask([])(mark('center_dash')));
});

test('curved finite mask uses actual segment geometry instead of its broad AABB', () => {
  const rotated = { ...passage, points: [{ x: 0, z: 0, yaw: Math.PI / 4 }, { x: 8, z: 8, yaw: Math.PI / 4 }] }, blocked = createNarrowPassagePaintMask([rotated]);
  assert(blocked(mark('center_dash', 4, 4, { tx: Math.SQRT1_2, tz: Math.SQRT1_2 })));
  assert(!blocked(mark('center_dash', 1, 7)), 'empty corner of passage AABB is not the carriageway');
});

test('one-way and no-entry faces point at their actual approaching streams', () => {
  const [allowed, prohibited] = narrowPassageSignApproaches(passage);
  assert.equal(allowed.kind, 'one_way'); assert.equal(prohibited.kind, 'no_entry');
  assert.equal(allowed.point, passage.points[0]); assert.equal(prohibited.point, passage.points.at(-1));
  assert(allowed.outward.x < -.999); assert(prohibited.outward.x > .999);
  assert.equal(allowed.approachId, passage.fromApproachId); assert.equal(prohibited.approachId, passage.toApproachId);
  assert.equal(allowed.allowedDirection, 1); assert.equal(prohibited.prohibitedDirection, -1);
});

const mouth={point:{x:0,z:0},outward:{x:0,z:1},widthM:4.1},dryVerge=x=>({road:Math.abs(x)<2.05,land:Math.abs(x)>=2.05});
test('a blocked narrow right verge uses the first safe left shoulder at the same mouth',()=>{
 const right=findNarrowPassageSignVerge({...mouth,surfaceAt:dryVerge,safeSign:x=>Math.abs(x)>2.5});assert(right.x>2.5);assert.equal(right.controlPlacement.side,'right');
 const left=findNarrowPassageSignVerge({...mouth,surfaceAt:dryVerge,safeSign:x=>x< -2.5});assert(left.x< -2.5);assert.equal(left.controlPlacement.side,'left');assert.equal(left.controlPlacement.rightVergeUnavailable,true);assert.equal(left.yaw,0);assert(Math.abs(left.z)<=2);
});
test('narrow sign fallback cannot cross water or another road or drift to a different mouth',()=>{
 for(const gap of['water','road']){const surfaceAt=x=>{const side=Math.abs(x);return side<2.05?{road:true,land:false}:side<3?{road:false,land:true}:side<4?{road:gap==='road',land:false}:{road:false,land:true}};assert.equal(findNarrowPassageSignVerge({...mouth,surfaceAt,safeSign:x=>Math.abs(x)>4.5}),null);}
 assert.equal(findNarrowPassageSignVerge({...mouth,surfaceAt:dryVerge,safeSign:(x,z)=>Math.abs(z)>2}),null);
 let probes=0;assert.equal(findNarrowPassageSignVerge({...mouth,surfaceAt(x){probes++;return dryVerge(x)},safeSign:()=>false}),null);assert(probes<700,'fixed local search, independent of city size');
});

const THREE = await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor') + '/build/three.module.js'));
test('distinct one-way/no-entry pictograms reuse box/cylinder batches with no added lights/material classes', () => {
  const build = kinds => createCityRoadDressing({ THREE, plan: { markings: [], signs: kinds.map((kind, i) => ({ id: kind, kind, x: i * 4, z: 0, y: 0, yaw: i ? Math.PI : 0 })), signals: [], stats: {} } });
  const one = build(['one_way']), no = build(['no_entry']), both = build(['one_way', 'no_entry']);
  assert.equal(one.stats.instances, 8, 'posts, blue bordered plate and three white arrow strokes');
  assert.equal(no.stats.instances, 6, 'posts, red bordered disk and horizontal white bar');
  assert.equal(both.stats.instances, 14); assert.equal(both.stats.equipmentDraws, 2); assert.equal(both.stats.triangles, one.stats.triangles + no.stats.triangles);
  assert.equal(both.stats.pointLights, 0); const materials = new Set(); both.object.traverse(node => { if (node.material) materials.add(node.material); assert(!node.isLight); }); assert(materials.size <= 4);
  for (const road of [one, no, both]) { road.update(0, { focus: { x: 0, z: 0 } }); assert(road.stats.visibleDraws > 0); road.dispose(); road.dispose(); assert.equal(road.object.children.length, 0); }
});
