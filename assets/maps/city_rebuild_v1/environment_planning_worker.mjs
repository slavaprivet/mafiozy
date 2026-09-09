import {buildEnvironmentVisualPlans} from './environment_planning_worker_core.mjs';

self.onmessage=event=>{
  const {id,input}=event.data||{};
  try{
    const started=performance.now(),plans=buildEnvironmentVisualPlans(input);
    self.postMessage({id,...plans,workerMs:performance.now()-started});
  }catch(error){
    self.postMessage({id,error:{name:error?.name||'Error',message:error?.message||String(error)}});
  }
};
