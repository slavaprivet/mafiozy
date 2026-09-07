import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {buildPlacementTopology} from './placement_topology.mjs';
import {capturePoliceProtectedCells,policeShapesFromAddendum} from './police_snapshot.mjs';
import {pointInPolygon} from './topology.mjs';
const artifact=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url),'utf8'));
const bytes=fs.readFileSync(artifact.sources.addendum.path),source=JSON.parse(bytes),baseBytes=fs.readFileSync(artifact.sources.base.path),base=JSON.parse(baseBytes);
const hash=b=>createHash('sha256').update(b).digest('hex');
assert.equal(hash(bytes),artifact.sources.addendum.sha256);assert.equal(hash(baseBytes),artifact.sources.base.sha256);
const freeze=x=>{if(x&&typeof x==='object'){Object.freeze(x);Object.values(x).forEach(freeze);}return x;};
const before=JSON.stringify(source),baseBefore=JSON.stringify(base);
const candidate=buildPlacementTopology(freeze(source),{base:freeze(base)});
assert.deepEqual(candidate,buildPlacementTopology(source,{base}));assert.equal(JSON.stringify(source),before);assert.equal(JSON.stringify(base),baseBefore);
const {sources,...published}=artifact;assert.deepEqual(published,candidate);
assert.equal(candidate.status,'ISOLATED_WALK_TOPOLOGY_PENDING_HOST');assert.equal(candidate.pendingHostSnapshot,true);
assert.equal(candidate.validation.roadComponentCount,1);assert.equal(candidate.validation.connectedRoadCells,12276);assert.equal(candidate.validation.fragmentCount,248);
assert.equal(candidate.validation.underlyingCompilerErrors.length,1);assert.equal(candidate.validation.underlyingCompilerErrors[0].code,'EXACT_HOST_POLICE_TILES_REQUIRED');
assert.equal(candidate.vehicleReady,false);assert.equal(candidate.gameplayReady,false);assert.equal(candidate.productionReady,false);
assert.deepEqual(candidate.runtimeRepairs,[]);assert.equal(candidate.sourceCorrections.removed_disconnected_fragments.length,8);
assert.deepEqual(candidate.validation.emptyRoadIds,['L-GO-H-095','AL-010','AL-043']);
const enabled=candidate.crossings.filter(x=>x.layer==='bridge_deck'&&x.status.startsWith('enabled_'));
assert.equal(enabled.length,4);assert.equal(candidate.districts.length,8);
let roadCount=0,policeCount=0;
for(const name of ['grid','roadMask','walkableMask','protectedMask','policeMask','bridgeDeckMask']){
 assert.equal(candidate[name].length,200);assert(candidate[name].every(row=>row.length===180));
}
for(let r=0;r<200;r++)for(let c=0;c<180;c++){
 const t=candidate.grid[r][c];
 for(const name of ['roadMask','walkableMask','protectedMask','policeMask','bridgeDeckMask'])assert([0,1].includes(candidate[name][r][c]));
 if(candidate.policeMask[r][c]){policeCount++;assert.equal(candidate.walkableMask[r][c],0);assert.equal(candidate.protectedMask[r][c],1);}
 if(t===16)assert.equal(candidate.walkableMask[r][c],0);
 if(candidate.roadMask[r][c]){roadCount++;assert([0,19].includes(t));}
 if(t===19)assert(enabled.some(x=>pointInPolygon([c+.5,r+.5],x.driveable_envelope_polygon_grid_cr)));
}
assert.equal(roadCount,12276);assert.equal(policeCount,882);
assert.equal(candidate.grid[22][90],16);assert.equal(candidate.grid[45][90],16);assert.equal(candidate.grid[51][90],19);
assert.equal(candidate.validation.counts[14],116,'explicit derivative beach polygon rasterized');
// Synthetic host test only, never recorded as a real-world acceptance.
const syntheticOldMap=Array.from({length:200},()=>Array(180).fill(8));syntheticOldMap[76][76]=3;
const actualCells=capturePoliceProtectedCells(syntheticOldMap,policeShapesFromAddendum(source.protected_police_complex));
assert.throws(()=>buildPlacementTopology(source,{base,policeProtectedCells:actualCells}),/authority/);
const hostCandidate=buildPlacementTopology(source,{base,policeProtectedCells:actualCells,policeSnapshotAuthority:'host-buildMap'});
assert.equal(hostCandidate.pendingHostSnapshot,false);assert.equal(hostCandidate.grid[76][76],3);assert.equal(hostCandidate.productionReady,false);
const invalid=structuredClone(source);invalid.roads[0].land_fragments_grid_cr.push([[70,100],[110,100]]);
assert.throws(()=>buildPlacementTopology(invalid,{base}),/Placement topology rejected/);
console.log('PASS: hash-pinned v3 artifact, deterministic native200x180,248fragments,1roadcomponent12276cells,882police reserved,4explicit bridges/2deferred tunnels,116sand,all masks,source trims explicit,host-pending provenance and bad-source rejection.');
