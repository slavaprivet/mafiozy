import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {createMaterializer,sourceWhitelistReader} from './materialize.mjs';
import {SCHEMA,pathFor,sha,verifyClosure} from '../map_editor_publication_closure/closure.mjs';
import {inventory} from '../map_editor_publication_closure/audit.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const output=fs.mkdtempSync(path.join(root,'outputs','publication-materializer-conformance-'));
let checks=0;
const check=(value,message)=>{assert(value,message);checks++;};
const same=(value,expected)=>{assert.deepEqual(value,expected);checks++;};
const entries=()=>fs.readdirSync(output).sort();
const prior=entries();

// ACTUAL inventory: no fabricated MapBundle, no ready flags, original53HOLD.
const actual=inventory();
const actualReport=verifyClosure(actual.closure,actual.readBlob,actual.trusted,{requireReady:true});
check(actualReport.integrity&&!actualReport.ready&&!actualReport.ok,'Actual integrity cannot substitute readiness');
same(actualReport.holds.length,53);
const actualPublisher=createMaterializer({...actual,outputRoot:output,userApprovedMapBundleSHA:null});
const refused=actualPublisher.publish(actual.closure);
check(!refused.ok&&!refused.wrote,'Actual publication must not create output');
same(refused.verification.holds,actualReport.holds);
same(entries(),prior);

// TINY SYNTHETIC schema-conformance fixtures ONLY. Frozen census is satisfied
// by9901 synthetic semantic keys and196 REFERENCES to one tiny original GLB;
// no real runtime/source/user approval or missing actual raster is manufactured.
const rawByPath=new Map(),blobs=new Map(),families=[];
const add=(kind,raw)=>{const hash=sha(raw),portable=pathFor(kind,hash);if(!blobs.has(hash)){blobs.set(hash,{sha256:hash,bytes:raw.length,kind,path:portable});rawByPath.set(portable,raw);}return hash;};
const json=o=>Buffer.from(JSON.stringify(o));
const gltf=Buffer.from('{"asset":{"version":"2.0"}}');
const chunk=Buffer.alloc(Math.ceil(gltf.length/4)*4,32);gltf.copy(chunk);
const glb=Buffer.alloc(20+chunk.length);glb.writeUInt32LE(0x46546c67,0);glb.writeUInt32LE(2,4);glb.writeUInt32LE(glb.length,8);glb.writeUInt32LE(chunk.length,12);glb.writeUInt32LE(0x4e4f534a,16);chunk.copy(glb,20);
const glbSHA=add('glb',glb),shared=Buffer.from([1,2,3,4]),sharedSHA=add('buffer',shared);
const sourceBuffer={file:`buffers/${sharedSHA}.bin`,sha256:sharedSHA,bytes:shared.length};
const fixtureMap={schema:'SYNTHETIC-user-approved-map-fixture',fixtureOnly:true,object:'synthetic-one'};
const mapSHA=add('json',json(fixtureMap));
const source={
 catalog:{objects:Array.from({length:9901},(_,i)=>({key:`fixture:${i}`})),resources:Array.from({length:196},()=>({sha256:glbSHA,bytes:glb.length}))},
 'ground-topology':{fixtureFamily:'ground-topology'},
 'ground-palette':{fixtureFamily:'ground-palette'},
 procedural:{objectIndex:{'fixture:procedural':{}},buffers:[sourceBuffer]},
 transport:{semanticObjects:[{key:'fixture:parking'}],buffers:[sourceBuffer],railway:{trainAsset:{sha256:glbSHA,bytes:glb.length}}},
 landmarks:{records:[{key:'fixture:landmark'}]},
 'landmark-textures':{textures:Array.from({length:38},(_,i)=>({id:`fixture:texture:${i}`,images:[]}))},
 'rail-caption-capture':{captures:[]}
};
for(const [id,manifest]of Object.entries(source)){
 const manifestSHA=add('json',json(manifest));
 const keys=id==='catalog'?manifest.objects.map(o=>o.key):id==='procedural'?Object.keys(manifest.objectIndex):id==='transport'?manifest.semanticObjects.map(o=>o.key):id==='landmarks'?manifest.records.map(o=>o.key):id==='landmark-textures'?manifest.textures.map(o=>o.id):[];
 families.push({id,manifest_sha256:manifestSHA,semanticKeys:keys});
}
const closure={schema:SCHEMA,engineContract:'godot-native-map-importer/closure-v1',mapBundle_sha256:mapSHA,families,blobs:[...blobs.values()]};
const trusted={sourceManifests:new Set(families.map(f=>f.manifest_sha256)),familyManifests:new Map(families.map(f=>[f.id,f.manifest_sha256])),textureCaptures:new Map(),runtimeGates:new Set(['native-importer-closure-v1','source-baseline-identity','ground-owner','procedural-owner','parking-rail-route-owner','protected-landmark-authority-collider-doors-nav','GLB-importer-material-parity','rail-caption-GPU-sampler-parity','landmarks-original-PMREM-IBL']),validateMapBundle:value=>JSON.stringify(value)===JSON.stringify(fixtureMap)};
const readBlob=portable=>{if(!rawByPath.has(portable))throw Error('Not a synthetic admitted source');return rawByPath.get(portable);};
const host={readBlob,trusted,userApprovedMapBundleSHA:mapSHA,outputRoot:output};
check(verifyClosure(closure,readBlob,trusted,{requireReady:true}).ready,'Synthetic schema conforming source gates only');
const wrongApproval=createMaterializer({...host,userApprovedMapBundleSHA:'0'.repeat(64)}).publish(closure);
check(!wrongApproval.ok&&!wrongApproval.wrote,'Exact user-approved snapshot mismatch');same(entries(),prior);
const missingValidator=createMaterializer({...host,trusted:{...trusted,validateMapBundle:undefined}}).publish(closure);
check(!missingValidator.ok&&!missingValidator.wrote,'Installed validator mandatory');same(entries(),prior);
const claimed=structuredClone(closure);claimed.ready=true;
check(!createMaterializer(host).publish(claimed).wrote,'User ready flag cannot bypass verifier');same(entries(),prior);
for(const malicious of ['../evil.gd','res://.godot/uid_cache.bin','C:/private/file.json','blobs/evil.js']){
 const bad=structuredClone(closure);bad.blobs[0].path=malicious;let touched=false;
 const result=createMaterializer({...host,readBlob:p=>{if(p===malicious)touched=true;return readBlob(p);}}).publish(bad);
 check(!result.ok&&!result.wrote&&!touched,'Noncanonical path cannot reach source reader');same(entries(),prior);
}
const corrupt=createMaterializer({...host,readBlob:p=>{const raw=readBlob(p);return p===closure.blobs[0].path?Buffer.alloc(raw.length):raw;}}).publish(closure);
check(!corrupt.ok&&!corrupt.wrote,'Corruption refused prewrite');same(entries(),prior);
const badSource={...trusted,sourceManifests:new Set()};
check(!createMaterializer({...host,trusted:badSource}).publish(closure).wrote,'Source admissions cannot be missing');same(entries(),prior);
const changingGates={...trusted,runtimeGates:new Set(trusted.runtimeGates)};
changingGates.validateMapBundle=value=>{changingGates.runtimeGates.delete('ground-owner');return trusted.validateMapBundle(value);};
check(!createMaterializer({...host,trusted:changingGates}).publish(closure).wrote,'Validator cannot leave stale runtime admission');same(entries(),prior);
const changingSource={...trusted,familyManifests:new Map(trusted.familyManifests)};
const sourceChanging=createMaterializer({...host,trusted:changingSource,readBlob:p=>{changingSource.familyManifests.set('catalog','0'.repeat(64));return readBlob(p);}}).publish(closure);
check(!sourceChanging.ok&&!sourceChanging.wrote,'Reader cannot change admitted source family during snapshot');same(entries(),prior);
const accessor={...closure};let getterInvoked=false;Object.defineProperty(accessor,'blobs',{enumerable:true,get(){getterInvoked=true;return closure.blobs;}});
check(!createMaterializer(host).publish(accessor).wrote&&!getterInvoked,'Executable data getter refused');same(entries(),prior);
const huge={...closure,engineContract:'x'.repeat(4097)};
check(!createMaterializer(host).publish(huge).wrote,'Oversized input rejected without writes');same(entries(),prior);
let publisher,nested;
publisher=createMaterializer({...host,readBlob:p=>{nested=publisher.publish(closure);return readBlob(p);}});
const ready=publisher.publish(closure);
check(ready.ok&&ready.wrote,'Synthetic ready closure materialized');check(nested&&!nested.ok&&!nested.wrote,'Reader reentry refused');
same(fs.readdirSync(ready.destination).sort(),['blobs','manifest.json']);
same(fs.readdirSync(path.join(ready.destination,'blobs')).length,closure.blobs.length);
check(closure.blobs.length<196,'Shared GLB+buffer deduplicated original bytes');
for(const row of closure.blobs){same(fs.readFileSync(path.join(ready.destination,row.path)),readBlob(row.path));check(sha(fs.readFileSync(path.join(ready.destination,row.path)))===row.sha256,'Exclusive output hash');}
same(JSON.parse(fs.readFileSync(path.join(ready.destination,'manifest.json'),'utf8')),closure);
check(fs.readdirSync(path.join(ready.destination,'blobs')).every(name=>/^[a-f0-9]{64}\.(json|glb|bin|rgba)$/.test(name)),'No scripts/cache/UID or user names');
const second=createMaterializer(host).publish(closure);check(second.ok&&second.destination!==ready.destination,'Unique exclusive output never overwrites');
const whitelistSource=path.join(output,'trusted-fixture.bin');fs.writeFileSync(whitelistSource,shared,{flag:'wx'});
const reader=sourceWhitelistReader(new Map([[pathFor('buffer',sharedSHA),{source:whitelistSource,kind:'buffer',sha256:sharedSHA,bytes:shared.length}]]));
same(reader(pathFor('buffer',sharedSHA)),shared);
assert.throws(()=>reader('../not-admitted.bin'));checks++;
fs.writeFileSync(whitelistSource,Buffer.from([4,3,2,1]));assert.throws(()=>reader(pathFor('buffer',sharedSHA)));checks++;
console.log(JSON.stringify({suite:'publication-materializer',checks,status:'PASS',actualIntegrity:actualReport.integrity,actualReady:actualReport.ready,actualHolds:actualReport.holds.length,actualOutputWrites:0,syntheticBlobCount:closure.blobs.length,syntheticSourceApprovalOnly:true,outputDirectory:output,nativeUsed:false,gpuUsed:false,productionRelease:false}));
