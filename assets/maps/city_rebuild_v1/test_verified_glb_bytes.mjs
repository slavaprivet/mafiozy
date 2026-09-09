import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {loadVerifiedGlbBytes} from './verified_glb_bytes.mjs';

const payload=new Uint8Array([1,2,3,4]),asset={url:'https://assets.test/hero.glb',bytes:payload.byteLength,sha256:createHash('sha256').update(payload).digest('hex')};
let fetches=0;
const fetcher=async()=>{
 fetches++;
 await new Promise(resolve=>setTimeout(resolve,5));
 return {ok:true,arrayBuffer:async()=>payload.buffer.slice(0)};
};
const [first,second]=await Promise.all([loadVerifiedGlbBytes({asset,fetch:fetcher,requireHash:true}),loadVerifiedGlbBytes({asset,fetch:fetcher,requireHash:true})]);
assert.equal(fetches,1,'concurrent hero/NPC consumers share one verified fetch');
assert.notEqual(first,second,'each GLTF parser receives a private ArrayBuffer');
new Uint8Array(first)[0]=99;
assert.equal(new Uint8Array(second)[0],1,'one parser buffer cannot corrupt another');
const third=await loadVerifiedGlbBytes({asset,fetch:fetcher,requireHash:true});
assert.equal(fetches,1,'later gallery/portrait request reuses verified bytes');
assert.equal(new Uint8Array(third)[0],1,'cached source bytes stay immutable to callers');

let preAbortedFetches=0;
const alreadyAborted=new AbortController();alreadyAborted.abort();
await assert.rejects(()=>loadVerifiedGlbBytes({asset,fetch:async()=>{preAbortedFetches++;return {ok:true,arrayBuffer:async()=>payload.buffer.slice(0)}},signal:alreadyAborted.signal,requireHash:true}),error=>error?.name==='AbortError');
assert.equal(preAbortedFetches,0,'an already aborted caller starts no request');

let release,abortFetches=0;
const delayed=new Promise(resolve=>{release=resolve});
const abortFetcher=async()=>{abortFetches++;await delayed;return {ok:true,arrayBuffer:async()=>payload.buffer.slice(0)}};
const controller=new AbortController(),aborted=loadVerifiedGlbBytes({asset,fetch:abortFetcher,signal:controller.signal,requireHash:true});
controller.abort();
await assert.rejects(aborted,error=>error?.name==='AbortError','an aborted consumer must not parse late');
const survivor=loadVerifiedGlbBytes({asset,fetch:abortFetcher,requireHash:true});release();
assert.equal(new Uint8Array(await survivor)[0],1);
assert.equal(abortFetches,1,'an aborted waiter does not poison the shared verified request');

let badFetches=0;
const invalid={...asset,url:'https://assets.test/bad.glb'};
const badFetcher=async()=>{badFetches++;return {ok:true,arrayBuffer:async()=>new Uint8Array([9,9,9,9]).buffer}};
await assert.rejects(()=>loadVerifiedGlbBytes({asset:invalid,fetch:badFetcher,requireHash:true}),/hash mismatch/);
await assert.rejects(()=>loadVerifiedGlbBytes({asset:invalid,fetch:badFetcher,requireHash:true}),/hash mismatch/);
assert.equal(badFetches,2,'a rejected verification never remains cached');
console.log(JSON.stringify({passed:true,checks:['concurrent_dedup','private_parse_buffers','cached_later_consumer','already_aborted_no_request','abort_isolated','failed_verification_evicted'],fetches}));
