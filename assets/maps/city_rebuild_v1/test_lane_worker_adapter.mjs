// Node adapter for the real browser worker module; no pathfinding stubs.
import {Worker} from 'node:worker_threads';
export function nodeLaneWorker(){
 const worker=new Worker(`const {parentPort,workerData}=require('node:worker_threads');const pending=[];globalThis.self={postMessage:value=>parentPort.postMessage(value)};parentPort.on('message',data=>{if(self.onmessage)self.onmessage({data});else pending.push(data)});import(workerData.url).then(()=>{for(const data of pending.splice(0))self.onmessage({data})});`,{eval:true,workerData:{url:new URL('./city_lane_route_worker.mjs',import.meta.url).href}});
 const wrapper={onmessage:null,onerror:null,postMessage:value=>worker.postMessage(value),terminate:()=>worker.terminate()};worker.on('message',data=>wrapper.onmessage?.({data}));worker.on('error',error=>wrapper.onerror?.(error));return wrapper;
}
