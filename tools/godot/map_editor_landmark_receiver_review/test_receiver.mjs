/** Separate adversarial review; never edits receiver/harness/browser/source. */
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import {parseTar,validateBundle,startReceiver,MAX_BYTES} from '../map_editor_landmark_canvas_capture/receive.mjs';
import {parserTar} from '../map_editor_landmark_canvas_capture/bundle.browser.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const base=path.join(root,'outputs/landmark-canvas-harness-847KsC');
const output=fs.mkdtempSync(path.join(root,'outputs','landmark-receiver-proof-'));
const observedCapture='614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32';
const source=fs.readFileSync(path.join(base,'source.json')),closureBytes=fs.readFileSync(path.join(base,'closure.json'));
const closure=JSON.parse(closureBytes),names=['receipt.json',...closure.textures.flatMap(texture=>texture.images.flatMap((_image,ordinal)=>['png','rgba'].map(ext=>`images/${texture.id}-image-${ordinal}.${ext}`))).sort()];
let checks=0;
const check=(value,message)=>{assert(value,message);checks++;};
const throws=callback=>{assert.throws(callback);checks++;};
function checksum(header){header.fill(32,148,156);let sum=0;for(const byte of header)sum+=byte;header.write(sum.toString(8).padStart(6,'0')+'\0 ',148,'ascii');}
function header(name,size){const h=Buffer.alloc(512);h.write(name,0,'utf8');for(const [offset,length,value]of [[100,8,0o644],[108,8,0],[116,8,0],[124,12,size],[136,12,0]])h.write(value.toString(8).padStart(length-1,'0'),offset,'ascii');h[156]=48;h.write('ustar',257,'ascii');h.write('00',263,'ascii');checksum(h);return h;}
function tar(fileNames=names){return Buffer.concat([...fileNames.flatMap(name=>[header(name,1),Buffer.alloc(512,0).fill(65,0,1)]),Buffer.alloc(1024)]);}
const validHeaders=tar();
check(parseTar(validHeaders).size===87,'Receiver accepts canonical87 tiny headers');
check(parserTar(validHeaders).size===87,'Browser shared parser accepts same canonical headers');
throws(()=>validateBundle(validHeaders,source,closureBytes,observedCapture));
throws(()=>validateBundle(validHeaders,source,closureBytes));
for(const name of ['../escape.bin','images/../../escape.gd','res://evil.gd','C:/Users/file.png'])throws(()=>parseTar(tar(['receipt.json',name])));
for(const [offset,value]of [[156,120],[157,65],[345,65]]){const changed=Buffer.from(validHeaders);changed[offset]=value;checksum(changed.subarray(0,512));throws(()=>parseTar(changed));}
const badChecksum=Buffer.from(validHeaders);badChecksum[148]^=1;throws(()=>parseTar(badChecksum));
const badPad=Buffer.from(validHeaders);badPad[513]=1;throws(()=>parseTar(badPad));
throws(()=>parseTar(validHeaders.subarray(0,validHeaders.length-512)));
throws(()=>parseTar(Buffer.concat([validHeaders,Buffer.alloc(512)])));
throws(()=>parseTar(Buffer.concat([validHeaders,Buffer.alloc(512,1)])));
throws(()=>parseTar(tar(['receipt.json','receipt.json'])));
throws(()=>parseTar(tar(['images/texture-0-image-0.png','receipt.json'])));
const unterminatedField=Buffer.from(validHeaders);unterminatedField[20]=65;checksum(unterminatedField.subarray(0,512));throws(()=>parseTar(unterminatedField));
const badUTF8=Buffer.from(validHeaders);badUTF8[0]=255;checksum(badUTF8.subarray(0,512));throws(()=>parseTar(badUTF8));
const noncanonicalHeader=Buffer.from(validHeaders);noncanonicalHeader.write('ignored-owner-name',265,'ascii');checksum(noncanonicalHeader.subarray(0,512));
const headerDivergence=parseTar(noncanonicalHeader).size===87;
throws(()=>parserTar(noncanonicalHeader));
check(headerDivergence,'Observed permissive receiver versus canonical browser uname-header difference');

const server=startReceiver(base,output,observedCapture);
await once(server,'listening');
const port=server.address().port,origin=`http://127.0.0.1:${port}`;
const httpRequest=(options={},body=Buffer.alloc(1024))=>new Promise((resolve,reject)=>{
 const {headers:extraHeaders,...otherOptions}=options;
 const request=http.request({hostname:'127.0.0.1',port,path:'/capture-bundle',method:'POST',agent:false,...otherOptions,headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':String(body.length),Connection:'close',...extraHeaders}},response=>{const chunks=[];response.on('data',chunk=>chunks.push(chunk));response.on('end',()=>resolve({status:response.statusCode,text:Buffer.concat(chunks).toString()}));});
 request.setTimeout(3000,()=>request.destroy(Error('Review request timeout')));request.on('error',reject);request.end(body);
});
try{
 const get=await httpRequest({method:'GET',path:'/',headers:{Host:`127.0.0.1:${port}`,Connection:'close'}},Buffer.alloc(0));check(get.status===200,'Actual prepared whitelist GET');
 for(const options of [
  {headers:{Host:`localhost:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':'1024'}},
  {headers:{Host:`127.0.0.1:${port}`,Origin:'http://evil.invalid','Content-Type':'application/x-tar','Content-Length':'1024'}},
  {headers:{Host:`127.0.0.1:${port}`,'Content-Type':'application/x-tar','Content-Length':'1024'}},
  {headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/json','Content-Length':'1024'}},
  {path:'/other'},
  {method:'OPTIONS'},
  {headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':'0'}}
 ]){const body=options.headers?.['Content-Length']==='0'?Buffer.alloc(0):Buffer.alloc(1024);const result=await httpRequest(options,body);check(result.status>=400&&result.status<500,'Method/origin/host/type/path/size negative refused');check(fs.readdirSync(output).length===0,'No output allocated for HTTP negative');}
 const tooBig=await httpRequest({headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':String(MAX_BYTES+1)}},Buffer.alloc(1));check(tooBig.status===403,'Oversized declared request rejected without allocating70MB');check(fs.readdirSync(output).length===0,'No size-violation output');
 const invalid=await httpRequest();check(invalid.status===403&&JSON.parse(invalid.text).retainedPartial===null,'Invalid empty tar rejects before output');
 const pending=http.request({hostname:'127.0.0.1',port,path:'/capture-bundle',method:'POST',headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':'1024',Connection:'close'}});
 pending.on('error',()=>{});pending.flushHeaders();pending.write(Buffer.from([0]));
 await new Promise(resolve=>setTimeout(resolve,25));
 const busy=await httpRequest();check(busy.status===403&&JSON.parse(busy.text).error.includes('busy'),'Concurrent allowed POST denied while one request active');
 pending.destroy();await new Promise(resolve=>setTimeout(resolve,25));
 const recovered=await httpRequest();check(recovered.status===403&&!JSON.parse(recovered.text).error.includes('busy'),'Abort releases busy flag');
 check(fs.readdirSync(output).length===0,'All invalid/aborted requests produce zero output directories');
}finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
console.log(JSON.stringify({suite:'landmark-receiver-negative-review',checks,status:'PROBES_CONFIRMED',receiverBrowserHeaderDivergence:headerDivergence,outputWrites:0,actualValidPositive:false,partialWritePositive:'pending actual archive',expectedCapturePin:observedCapture,serverClosed:true,zeroWebGL:true,nativeUsed:false,gpuUsed:false,fontOrGPUApproved:false}));
