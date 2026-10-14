/** Original root-observed capture DELIVERY proof, not font/GPU acceptance. */
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import {buildTarBundle} from '../map_editor_landmark_canvas_capture/bundle.browser.mjs';
import {validateBundle,startReceiver,MAX_BYTES} from '../map_editor_landmark_canvas_capture/receive.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const base=path.join(root,'outputs/landmark-canvas-harness-847KsC');
const capture=path.join(root,'outputs/landmark-canvas-capture-ZQyA1N');
const output=fs.mkdtempSync(path.join(root,'outputs','landmark-receiver-actual-proof-'));
const expected='614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const receipt=JSON.parse(fs.readFileSync(path.join(capture,'receipt.json')));
const sourceBytes=fs.readFileSync(path.join(base,'source.json')),closureBytes=fs.readFileSync(path.join(base,'closure.json'));
let checks=0;
const check=(value,message)=>{assert(value,message);checks++;};
const before=hash(fs.readFileSync(path.join(root,'tools/godot/map_editor_landmark_canvas_capture/receive.mjs')));
const bundle=await buildTarBundle({receipt:()=>receipt,artifact:(id,kind)=>new Uint8Array(fs.readFileSync(path.join(capture,'images',id+'.'+kind)))},closureBytes);
const bytes=Buffer.from(bundle.bytes.buffer,bundle.bytes.byteOffset,bundle.bytes.byteLength);
check(bundle.receiptSha256===expected&&bundle.entries===87&&bytes.length<=MAX_BYTES,'Actual observed43 pairs fit receiver limit');
const result=validateBundle(bytes,sourceBytes,closureBytes,expected);
check(result.files.size===87&&result.ready===false,'Actual bundle87 validated, HOLD retained');
assert.throws(()=>validateBundle(bytes,sourceBytes,closureBytes,'0'.repeat(64)));checks++;
const server=startReceiver(base,output,expected);await once(server,'listening');
const port=server.address().port,origin=`http://127.0.0.1:${port}`;
const post=body=>new Promise((resolve,reject)=>{
 const request=http.request({hostname:'127.0.0.1',port,path:'/capture-bundle',method:'POST',agent:false,headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':String(body.length),Connection:'close'}},response=>{let text='';response.on('data',chunk=>text+=chunk);response.on('end',()=>resolve({status:response.statusCode,body:JSON.parse(text)}));});
 request.setTimeout(15000,()=>request.destroy(Error('Actual review HTTP timeout')));request.on('error',reject);request.end(body);
});
let good,partial;
try{
 const changed=Buffer.from(bytes);changed[changed.length-1536]^=1;
 const invalid=await post(changed);
 check(invalid.status===403&&invalid.body.retainedPartial===null,'Late corrupt archive refused before output');
 check(fs.readdirSync(output).length===0,'ALL original hashes verified before allocating any capture directory');
 good=await post(bytes);check(good.status===200&&good.body.ok&&good.body.ready===false,'Actual HTTP delivery successful but not ready');
 check(good.body.captureCanonicalSha256===expected,'Exact root-observed pin returned');
 for(const row of result.records){const stored=fs.readFileSync(path.join(good.body.directory,row.name));check(stored.length===row.bytes&&hash(stored)===row.sha256,'Exact stored original bytes '+row.name);}
 const storage=JSON.parse(fs.readFileSync(path.join(good.body.directory,'storage_receipt.json')));
 check(storage.ready===false&&storage.gpu===false&&storage.fontBackendAccepted===false&&storage.iblAccepted===false&&storage.productionInstalled===false,'Storage receipt cannot grant owners/font/GPU acceptance');
 const originalOpen=fs.openSync;let imageOpens=0;
 try{
  fs.openSync=function(filename,flags,...rest){if(typeof filename==='string'&&filename.startsWith(output)&&filename.includes(`${path.sep}images${path.sep}`)&&flags==='wx'&&++imageOpens===2)throw Error('review injected second original image open failure');return originalOpen.call(fs,filename,flags,...rest);};
  partial=await post(bytes);
 }finally{fs.openSync=originalOpen;}
 check(partial.status===403&&!partial.body.ok&&typeof partial.body.retainedPartial==='string','Partial IO failure returns explicit retained path');
 check(fs.readdirSync(path.join(partial.body.retainedPartial,'images')).length===1&&fs.existsSync(path.join(partial.body.retainedPartial,'receipt.json')),'Partial retains exact firstimage plus receipt');
 check(!fs.existsSync(path.join(partial.body.retainedPartial,'storage_receipt.json')),'No success storage receipt on partial write');
 const next=await post(Buffer.alloc(1024));check(next.status===403&&!next.body.error.includes('busy'),'Busy flag releases after actual partial IO failure');
}finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
check(hash(fs.readFileSync(path.join(root,'tools/godot/map_editor_landmark_canvas_capture/receive.mjs')))===before,'Receiver source unchanged during this proof');
console.log(JSON.stringify({suite:'landmark-receiver-actual-delivery-review',checks,status:'PASS',bundleBytes:bytes.length,archiveSHA:hash(bytes),rootObservedCaptureSHA:expected,originalFiles:87,originalImages:43,allStoredHashesExact:true,lateCorruptionNoOutput:true,partialPath:partial.body.retainedPartial,goodPath:good.body.directory,receiverSHA:before,serverClosed:true,browserStarted:false,nativeUsed:false,gpuUsed:false,fontOrGPUApproved:false,productionInstalled:false}));
