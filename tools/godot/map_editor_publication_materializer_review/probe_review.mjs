/** Adversarial proof only; frozen materializer/verifier never modified. */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {createMaterializer} from '../map_editor_publication_materializer/materialize.mjs';
import {sha} from '../map_editor_publication_closure/closure.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const receipt=JSON.parse(fs.readFileSync(path.join(root,'tools/godot/map_editor_publication_materializer/receipt.json')));
const fixture=fs.readdirSync(receipt.outputDirectory).find(name=>name.startsWith('map-publication-'));
const source=path.join(receipt.outputDirectory,fixture);
const closure=JSON.parse(fs.readFileSync(path.join(source,'manifest.json')));
const output=fs.mkdtempSync(path.join(root,'outputs','publication-review-'));
const originalMaterializer=sha(fs.readFileSync(path.join(root,'tools/godot/map_editor_publication_materializer/materialize.mjs')));
const readBlob=portable=>{if(!closure.blobs.some(row=>row.path===portable))throw Error('No synthetic admitted blob');return fs.readFileSync(path.join(source,portable));};
function host(){return {readBlob,userApprovedMapBundleSHA:closure.mapBundle_sha256,outputRoot:output,trusted:{sourceManifests:new Set(closure.families.map(f=>f.manifest_sha256)),familyManifests:new Map(closure.families.map(f=>[f.id,f.manifest_sha256])),textureCaptures:new Map(),runtimeGates:new Set(['native-importer-closure-v1','source-baseline-identity','ground-owner','procedural-owner','parking-rail-route-owner','protected-landmark-authority-collider-doors-nav','GLB-importer-material-parity','rail-caption-GPU-sampler-parity','landmarks-original-PMREM-IBL']),validateMapBundle:value=>value.fixtureOnly===true&&value.schema==='SYNTHETIC-user-approved-map-fixture'}};}
let checks=0;
const check=(value,message)=>{assert(value,message);checks++;};

// GENUINE mutable-postflight gap: during canonical comparison of a replaced
// texture receipt, its accessor removes a runtime gate already checked earlier.
const altered=host();
altered.trusted.textureCaptures.set('unused-synthetic-probe',{width:1});
let captureGetterCalls=0;
altered.trusted.validateMapBundle=value=>{
 altered.trusted.textureCaptures.set('unused-synthetic-probe',{get width(){captureGetterCalls++;altered.trusted.runtimeGates.delete('ground-owner');return 1;}});
 return value.fixtureOnly===true;
};
const mutable=createMaterializer(altered).publish(closure);
check(mutable.ok&&mutable.wrote,'Reproduced: frozen module permits postflight accessor gate removal');
check(captureGetterCalls>0&&!altered.trusted.runtimeGates.has('ground-owner'),'Gate absent at publication success');

// Request copies reject ordinary accessors, but Proxy traps execute and valid
// proxy data is not rejected. Parsed JSON caller restriction remains mandatory.
let proxyTrapCalls=0;
const proxy=new Proxy(closure,{getPrototypeOf(target){proxyTrapCalls++;return Reflect.getPrototypeOf(target);},ownKeys(target){proxyTrapCalls++;return Reflect.ownKeys(target);},getOwnPropertyDescriptor(target,key){proxyTrapCalls++;return Reflect.getOwnPropertyDescriptor(target,key);}});
const proxyResult=createMaterializer(host()).publish(proxy);
check(proxyResult.ok&&proxyTrapCalls>0,'Reproduced: executable Proxy request accepted');

// REAL writes with injected filesystem failure, scoped only to this process.
// No fake owner validator success is claimed for an actual map.
const originalOpen=fs.openSync;
let blobOpens=0,partial;
try{
 fs.openSync=function(file,flags,...rest){if(typeof file==='string'&&file.includes(`${path.sep}blobs${path.sep}`)&&flags==='wx'&&++blobOpens===2)throw Error('review injected second blob open failure');return originalOpen.call(fs,file,flags,...rest);};
 partial=createMaterializer(host()).publish(closure);
}finally{fs.openSync=originalOpen;}
check(!partial.ok&&partial.wrote&&partial.partial_retained,'Second-blob failure correctly reported retained partial');
check(fs.existsSync(partial.destination)&&fs.readdirSync(path.join(partial.destination,'blobs')).length===1,'Exactly first real written blob retained');
check(!fs.existsSync(path.join(partial.destination,'manifest.json')),'No manifest on early partial write');
const afterFailure=createMaterializer(host()).publish(closure);
check(afterFailure.ok&&afterFailure.destination!==partial.destination,'Failure does not overwrite retained directory');
check(sha(fs.readFileSync(path.join(root,'tools/godot/map_editor_publication_materializer/materialize.mjs')))===originalMaterializer,'Frozen source unchanged');
console.log(JSON.stringify({suite:'materializer-adversarial-review',checks,status:'PROBES_CONFIRMED',mutableTrustPostflightGap:mutable.ok&&captureGetterCalls>0,captureGetterCalls,proxyAccepted:proxyResult.ok,proxyTrapCalls,partialFailureCorrect:!partial.ok&&partial.partial_retained,sourceUnchanged:true,syntheticOnly:true,outputDirectory:output,nativeUsed:false,gpuUsed:false,actualPublication:false}));
