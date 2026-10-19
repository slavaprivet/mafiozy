import {assessWalkMapEditorPublishReady,isWalkMapEditorCompileReceipt} from './walk_map_editor_document.mjs';
import {isWalkMapEditorCompileResult,walkMapEditorArtifactSha256} from './walk_map_editor_compile.mjs';

export const WALK_MAP_EDITOR_PUBLISH_BUNDLE_SCHEMA='mafiozi.walk-map-editor-publish-bundle';
const ARTIFACT_NAMES=Object.freeze(['topology','buildings','decor','custom']);
const DEFAULT_FILENAMES=Object.freeze({manifest:'walk-map-manifest.json',topology:'walk-map-topology.json',buildings:'walk-map-buildings.json',decor:'walk-map-decor.json',custom:'walk-map-custom.json'});
const trustedBundles=new WeakSet();

export class WalkMapEditorPublishBundleError extends Error{constructor(message,details={}){super(message);this.name='WalkMapEditorPublishBundleError';Object.assign(this,details);}}

function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function stable(value){if(Array.isArray(value))return value.map(stable);if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value;}
function canonicalJson(value){return JSON.stringify(stable(value));}
function equal(a,b){return canonicalJson(a)===canonicalJson(b);}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(isObject(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value);}
function bytes(text){return new TextEncoder().encode(text).byteLength;}
function assertText(value,label,max=512){if(typeof value!=='string'||!value.trim()||value.length>max||/[\u0000-\u001f]/.test(value))throw new WalkMapEditorPublishBundleError(`${label} is invalid`);return value;}
function assertSha(value,label){if(typeof value!=='string'||!/^[a-f0-9]{64}$/i.test(value))throw new WalkMapEditorPublishBundleError(`${label} must be SHA-256`);return value.toLowerCase();}
function assertLimit(value,label,fallback){const result=value===undefined?fallback:value;if(!Number.isSafeInteger(result)||result<=0||result>512*1024*1024)throw new WalkMapEditorPublishBundleError(`${label} is invalid`);return result;}
function assertFilename(value,label){const name=assertText(value,label,128),stem=name.slice(0,-5).toUpperCase();if(!/^[A-Za-z0-9][A-Za-z0-9._-]*\.json$/.test(name)||name.includes('..')||/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/.test(stem))throw new WalkMapEditorPublishBundleError(`${label} must be a safe .json basename`);return name;}

function normalizeFilenames(filenames={}){
 if(!isObject(filenames))throw new WalkMapEditorPublishBundleError('filenames must be an object');for(const key of Object.keys(filenames))if(!Object.hasOwn(DEFAULT_FILENAMES,key))throw new WalkMapEditorPublishBundleError(`Unknown bundle filename slot: ${key}`);
 const result={};for(const key of ['manifest',...ARTIFACT_NAMES])result[key]=assertFilename(filenames[key]??DEFAULT_FILENAMES[key],`${key} filename`);
 const folded=new Set();for(const name of Object.values(result)){const key=name.toLocaleLowerCase('en');if(folded.has(key))throw new WalkMapEditorPublishBundleError(`Duplicate bundle filename: ${name}`);folded.add(key);}return result;
}

function sourceReference(document,name){return name==='custom'?document.base.extensions?.custom:document.base[name];}

export function createWalkMapEditorPublishBundle(compileResult,{registeredObjectDatasets=[],registeredSurfaceMaterials=[],filenames={},publisherId='walk-map-editor-publisher-v1',publishedAt=null,maxArtifactBytes=64*1024*1024,maxBundleBytes=256*1024*1024}={}){
 if(!isWalkMapEditorCompileResult(compileResult))throw new WalkMapEditorPublishBundleError('TRUSTED_COMPILE_RESULT_REQUIRED');
 if(!isWalkMapEditorCompileReceipt(compileResult.compileReceipt))throw new WalkMapEditorPublishBundleError('TRUSTED_COMPILE_RECEIPT_REQUIRED');
 if(!Array.isArray(registeredObjectDatasets)||!Array.isArray(registeredSurfaceMaterials))throw new WalkMapEditorPublishBundleError('Publisher adapter lists must be arrays');
 const perFileLimit=assertLimit(maxArtifactBytes,'maxArtifactBytes',64*1024*1024),totalLimit=assertLimit(maxBundleBytes,'maxBundleBytes',256*1024*1024),names=normalizeFilenames(filenames),receipt=compileResult.compileReceipt,document=compileResult.document;
 const readiness=assessWalkMapEditorPublishReady(document,{registeredObjectDatasets,registeredSurfaceMaterials,compileReceipt:receipt});if(!readiness.ready)throw new WalkMapEditorPublishBundleError(`PUBLISH_NOT_READY: ${readiness.errors.join('; ')}`);
 if(compileResult.protectionReport?.unresolved?.length||compileResult.protectionReport?.protectedTouches?.length)throw new WalkMapEditorPublishBundleError('COMPILE_PROTECTION_REPORT_REJECTED');
 const sourceManifest={};for(const name of ARTIFACT_NAMES){const reference=sourceReference(document,name);if(!isObject(reference))throw new WalkMapEditorPublishBundleError(`Missing source reference: ${name}`);sourceManifest[name]={sha256:assertSha(reference.sha256,`${name} source`),revision:assertText(reference.revision,`${name} revision`)};if(name!=='custom'&&receipt.sourceDigests[name]!==sourceManifest[name].sha256)throw new WalkMapEditorPublishBundleError(`RECEIPT_SOURCE_MISMATCH: ${name}`);}
 const artifactManifest={},artifactFiles=[];for(const name of ARTIFACT_NAMES){const artifact=compileResult.artifacts?.[name];if(!isObject(artifact)||typeof artifact.json!=='string')throw new WalkMapEditorPublishBundleError(`Missing compiled artifact: ${name}`);let parsed;try{parsed=JSON.parse(artifact.json);}catch(error){throw new WalkMapEditorPublishBundleError(`Compiled artifact JSON is invalid: ${name}: ${error.message}`);}if(canonicalJson(parsed)!==artifact.json||!equal(parsed,artifact.value))throw new WalkMapEditorPublishBundleError(`Compiled artifact is not canonical: ${name}`);const digest=walkMapEditorArtifactSha256(artifact.json);if(digest!==assertSha(artifact.sha256,`${name} artifact`)||receipt.outputDigests?.[name]!==digest)throw new WalkMapEditorPublishBundleError(`RECEIPT_OUTPUT_MISMATCH: ${name}`);const size=bytes(artifact.json);if(size>perFileLimit)throw new WalkMapEditorPublishBundleError(`ARTIFACT_TOO_LARGE: ${name}`);artifactManifest[name]={filename:names[name],sha256:digest,bytes:size};artifactFiles.push(deepFreeze({kind:name,filename:names[name],mimeType:'application/json;charset=utf-8',text:artifact.json,sha256:digest,bytes:size}));}
 const manifestCore={schema:WALK_MAP_EDITOR_PUBLISH_BUNDLE_SCHEMA,schemaVersion:1,manifestFilename:names.manifest,document:{documentId:receipt.documentId,revision:receipt.revision,digest:receipt.documentDigest},compiler:{compilerId:receipt.compilerId,compiledAt:receipt.compiledAt},publisher:{publisherId:assertText(publisherId,'publisherId'),publishedAt:assertText(publishedAt??receipt.compiledAt,'publishedAt')},policyDigest:assertSha(receipt.policyDigest,'policy digest'),sources:sourceManifest,artifacts:artifactManifest};
 const manifest=deepFreeze({...manifestCore,bundleDigest:walkMapEditorArtifactSha256(canonicalJson(manifestCore))}),manifestJson=canonicalJson(manifest),manifestSize=bytes(manifestJson);if(manifestSize>perFileLimit)throw new WalkMapEditorPublishBundleError('MANIFEST_TOO_LARGE');
 const manifestFile=deepFreeze({kind:'manifest',filename:names.manifest,mimeType:'application/json;charset=utf-8',text:manifestJson,sha256:walkMapEditorArtifactSha256(manifestJson),bytes:manifestSize}),files=deepFreeze([manifestFile,...artifactFiles]),totalBytes=files.reduce((sum,file)=>sum+file.bytes,0);if(totalBytes>totalLimit)throw new WalkMapEditorPublishBundleError('BUNDLE_TOO_LARGE');
 const bundle=deepFreeze({schema:WALK_MAP_EDITOR_PUBLISH_BUNDLE_SCHEMA,schemaVersion:1,manifest,manifestSha256:manifestFile.sha256,files,totalBytes});trustedBundles.add(bundle);return bundle;
}

export function isWalkMapEditorPublishBundle(value){return trustedBundles.has(value);}

export async function downloadWalkMapEditorPublishBundle(bundle,{download,createBlob=globalThis.Blob?((parts,options)=>new Blob(parts,options)):null}={}){
 if(!trustedBundles.has(bundle))throw new WalkMapEditorPublishBundleError('TRUSTED_PUBLISH_BUNDLE_REQUIRED');if(typeof createBlob!=='function')throw new WalkMapEditorPublishBundleError('A Blob factory is required');if(typeof download!=='function')throw new WalkMapEditorPublishBundleError('A download callback is required');
 const requests=[];try{for(const file of bundle.files){const blob=createBlob([file.text],{type:file.mimeType});if((typeof blob!=='object'&&typeof blob!=='function')||blob===null||typeof blob.then==='function')throw new Error('Blob factory returned no synchronous object');requests.push(Object.freeze({filename:file.filename,mimeType:file.mimeType,sha256:file.sha256,bytes:file.bytes,blob}));}}catch(error){throw new WalkMapEditorPublishBundleError(`BLOB_PREPARATION_FAILED: ${error.message}`,{cause:error,downloadedCount:0});}
 let downloadedCount=0;for(const request of requests)try{await download(request);downloadedCount++;}catch(error){throw new WalkMapEditorPublishBundleError(`DOWNLOAD_FAILED: ${request.filename}: ${error.message}`,{cause:error,filename:request.filename,downloadedCount});}
 return Object.freeze({downloadedCount,totalBytes:bundle.totalBytes,filenames:Object.freeze(requests.map(request=>request.filename))});
}
