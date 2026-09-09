import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
self.onmessage=event=>{
 const {id,input}=event.data||{};
 try{const started=performance.now(),plan=buildExplorationDecorPlan(input);self.postMessage({id,plan,workerMs:performance.now()-started})}
 catch(error){self.postMessage({id,error:error?.message||String(error)})}
};
