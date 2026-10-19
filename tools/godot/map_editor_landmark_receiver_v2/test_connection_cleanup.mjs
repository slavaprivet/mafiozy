import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
import {startReceiver,MAX_BYTES} from './receive.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const output=fs.mkdtempSync(path.join(root,'outputs','landmark-receiver-cleanup-proof-'));
const pin='614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32';
const server=startReceiver(path.join(root,'outputs/landmark-canvas-harness-847KsC'),output,pin);
await once(server,'listening');
const port=server.address().port,origin=`http://127.0.0.1:${port}`;
const agent=new http.Agent({keepAlive:true,maxSockets:1});
let checks=0;
const sockets=new Set();
const check=(value,message)=>{assert(value,message);checks++;};
const post=(declared=1024,body=Buffer.alloc(1024))=>new Promise((resolve,reject)=>{
 const request=http.request({hostname:'127.0.0.1',port,path:'/capture-bundle',method:'POST',agent,headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':String(declared),Connection:'keep-alive'}},response=>{let data='';response.on('data',chunk=>data+=chunk);response.on('end',()=>resolve({status:response.statusCode,headers:response.headers,body:JSON.parse(data)}));});
 request.on('socket',socket=>sockets.add(socket));request.on('error',reject);request.setTimeout(1500,()=>request.destroy(Error('Keep-alive probe stalled')));request.end(body);
});
try{
 const refused=await post(MAX_BYTES+1,Buffer.alloc(1));
 check(refused.status===403&&refused.headers.connection==='close','Early refused incomplete body explicitly closes connection');
 const after=await post();check(after.status===403&&!after.body.error.includes('busy'),'Subsequent same-agent request does not stall');
 check(sockets.size>=2,'Closed refused socket cannot be reused');
 // Real native HTTP timeout handling, reduced ONLY on this returned testserver.
 // Regular progress defeats inactivity, so native overall requestTimeout is
 // the boundary exercised here. Production defaults remain30000ms.
 server.requestTimeout=120;server.headersTimeout=120;server.setTimeout(120);
 let progressWrites=0;
 const slow=await new Promise(resolve=>{
  let complete=false,interval,limit;
  const finish=result=>{if(complete)return;complete=true;clearInterval(interval);clearTimeout(limit);resolve(result);};
  const request=http.request({hostname:'127.0.0.1',port,path:'/capture-bundle',method:'POST',agent:false,headers:{Host:`127.0.0.1:${port}`,Origin:origin,'Content-Type':'application/x-tar','Content-Length':'1024',Connection:'close'}},response=>{response.resume();response.on('end',()=>finish({status:response.statusCode}));});
  request.on('error',error=>finish({closed:true,error:error.code}));request.on('close',()=>finish({closed:true}));request.flushHeaders();request.write(Buffer.from([0]));
  interval=setInterval(()=>{if(!request.destroyed){progressWrites++;request.write(Buffer.from([0]));}},20);
  limit=setTimeout(()=>{request.destroy();finish({hardLimit:true});},2500);
 });
 check(!slow.hardLimit&&(slow.closed||slow.status===408),'Slow progressing body is bounded by native request timeout');
 check(progressWrites>3,'Probe progressed repeatedly rather than simply idling');
 await new Promise(resolve=>setTimeout(resolve,30));
 const recovered=await post();check(recovered.status===403&&!recovered.body.error.includes('busy'),'Slow/timeout abort releases busy');
 check(fs.readdirSync(output).length===0,'No archive output from early refusal/slowbody');
}finally{agent.destroy();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
console.log(JSON.stringify({suite:'receiver-v2-http-cleanup',checks,status:'PASS',slowBodyNativeTimeout:true,progressingBodyBounded:true,keepAliveRefusalCloses:true,outputWrites:0,serverClosed:true,nativeGameUsed:false,gpuUsed:false,fontOrGPUApproved:false}));
