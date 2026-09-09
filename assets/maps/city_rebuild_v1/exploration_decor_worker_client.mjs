import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';

export function planExplorationDecorAsync(input){
 if(typeof Worker!=='function')return Promise.resolve().then(()=>({plan:buildExplorationDecorPlan(input),workerMs:null,mode:'main-fallback'}));
 return new Promise((resolve,reject)=>{
  let worker;try{worker=new Worker(new URL('./exploration_decor_worker.mjs',import.meta.url),{type:'module',name:'walk-forest-plan'})}catch(error){reject(error);return}
  const id=1,finish=fn=>value=>{worker.terminate();fn(value)};
  worker.onmessage=finish(message=>{const data=message.data||{};if(data.id!==id)return;if(data.error)reject(new Error(data.error));else resolve({plan:data.plan,workerMs:data.workerMs??null,mode:'worker'})});
  worker.onerror=finish(event=>reject(event.error||new Error(event.message||'Forest planning worker failed')));
  try{worker.postMessage({id,input})}catch(error){worker.terminate();reject(error)}
 });
}
