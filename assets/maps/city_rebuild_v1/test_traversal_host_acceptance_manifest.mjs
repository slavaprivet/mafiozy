import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';

const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const manifestPath=path.join(here,'traversal_host_acceptance_manifest.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex').toUpperCase();
const resolveRoot=value=>path.isAbsolute(value)?value:path.resolve(root,value);
const verified=[];
for(const [relative,expected]of Object.entries(manifest.dependencies)){
 const file=resolveRoot(relative);assert.ok(fs.existsSync(file),`missing frozen dependency: ${relative}`);const actual=sha(file);assert.equal(actual,expected,`frozen dependency changed: ${relative}`);verified.push(relative);
}
const baseline={};
for(const [relative,expected]of Object.entries(manifest.sourceBaseline)){
 const file=resolveRoot(relative);assert.ok(fs.existsSync(file),`missing actual source: ${relative}`);const actual=sha(file);assert.equal(actual,expected,`actual source changed since manifest freeze: ${relative}`);baseline[relative]=actual;
}

const candidateHost=resolveRoot(process.env.WALK_PREVIEW_CANDIDATE||'assets/maps/city_rebuild_v1/walk_preview.mjs');
const candidateNavigation=resolveRoot(process.env.BUILDING_VERTICAL_NAVIGATION_CANDIDATE||'assets/maps/city_rebuild_v1/building_vertical_navigation.mjs');
const candidateMode=!!(process.env.WALK_PREVIEW_CANDIDATE||process.env.BUILDING_VERTICAL_NAVIGATION_CANDIDATE);
for(const file of [candidateHost,candidateNavigation])assert.ok(fs.existsSync(file),`candidate missing: ${file}`);
const hostSource=fs.readFileSync(candidateHost,'utf8'),navigationSource=fs.readFileSync(candidateNavigation,'utf8');
for(const anchor of manifest.walkSemanticAnchors)assert.ok(hostSource.includes(anchor),`walk semantic prerequisite missing: ${anchor}`);
for(const anchor of manifest.navigationSemanticAnchors)assert.ok(navigationSource.includes(anchor),`navigation semantic prerequisite missing: ${anchor}`);
for(const anchor of manifest.transportPreservationAnchors)assert.ok(hostSource.includes(anchor),`transport preservation anchor missing: ${anchor}`);

const testResults=[];
const orderedTests=candidateMode?[...manifest.tests].sort((a,b)=>Number(b.endsWith('test_hero_motion_pose_host_gate.mjs'))-Number(a.endsWith('test_hero_motion_pose_host_gate.mjs'))):manifest.tests;
for(const relative of orderedTests){
 const started=performance.now(),file=resolveRoot(relative),isHostGate=relative.endsWith('test_hero_motion_pose_host_gate.mjs');
 const env={...process.env};
 if(isHostGate){env.WALK_PREVIEW_CANDIDATE=candidateHost;env.BUILDING_VERTICAL_NAVIGATION_CANDIDATE=candidateNavigation;if(candidateMode)env.WALK_POSE_REQUIRE_INTEGRATED='1';else delete env.WALK_POSE_REQUIRE_INTEGRATED;}
 const result=spawnSync(process.execPath,[file],{cwd:root,env,encoding:'utf8',timeout:120000,maxBuffer:8*1024*1024});
 if(result.status!==0){process.stderr.write(result.stdout||'');process.stderr.write(result.stderr||'');assert.fail(`${relative} failed with exit ${result.status}`)}
 let receipt=null;const lines=String(result.stdout||'').trim().split(/\r?\n/).filter(Boolean);try{receipt=JSON.parse(lines.at(-1))}catch{}
 assert.notEqual(receipt?.passed,false,`${relative} reported failed`);
 if(isHostGate){assert.equal(receipt?.integrationDetected,candidateMode,`host gate mode mismatch: expected ${candidateMode?'integrated':'HOLD'}`);assert.equal(receipt?.status,candidateMode?'integrated-semantic-gate':'HOLD-ready');}
 testResults.push({test:relative,passed:true,ms:+(performance.now()-started).toFixed(2),receipt:receipt?{passed:receipt.passed,status:receipt.status}:null});
}

console.log(JSON.stringify({passed:true,status:candidateMode?'integrated-candidate-PASS':'HOLD-PASS',manifestVersion:manifest.version,manifestPath,dependencyCount:verified.length,baseline,candidate:{hostPath:candidateHost,hostSha256:sha(candidateHost),navigationPath:candidateNavigation,navigationSha256:sha(candidateNavigation)},semanticPrerequisites:{walk:manifest.walkSemanticAnchors.length,navigation:manifest.navigationSemanticAnchors.length,transport:manifest.transportPreservationAnchors.length},tests:testResults},null,2));
