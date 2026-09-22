// Interaction admission uses elapsed time; animation and physics keep their dt.
export function createVehicleEntryHoldClock({maxGapSeconds=.5,traceEnabled=()=>false}={}){
 let startedAt=null,lastAt=null,needsRelease=false;
 const trace=[];let traceAt=-Infinity,tracePressed=false,traceEligible=false,traceReady=false,traceInterrupted=false,traceLatched=false,traceChannel='local';
 const result={elapsed:0,ready:false,interrupted:false};
 const clear=()=>{result.elapsed=0;result.ready=false;result.interrupted=false;return result;};
 function record(pressed,eligible,now,gap,channel,reason='sample'){
  if(!traceEnabled())return result;
  pressed=!!pressed;eligible=!!eligible;
  const changed=pressed!==tracePressed||eligible!==traceEligible||result.ready!==traceReady||result.interrupted!==traceInterrupted||needsRelease!==traceLatched||channel!==traceChannel;
  if((pressed||tracePressed)&&(reason!=='sample'||changed||now-traceAt>=1)){
   trace.push({at:now,pressed,eligible,elapsed:result.elapsed,ready:result.ready,interrupted:result.interrupted,channel,gap,latched:needsRelease,reason});
   if(trace.length>16)trace.shift();traceAt=now;
  }
  tracePressed=pressed;traceEligible=eligible;traceReady=result.ready;traceInterrupted=result.interrupted;traceLatched=needsRelease;traceChannel=channel;
  return result;
 }
 function reset(reason='release',now=lastAt){const gap=lastAt===null?0:now-lastAt;startedAt=lastAt=null;needsRelease=false;clear();return record(false,false,now,gap,traceChannel,reason);}
 function advance(pressed,eligible,now,duration=.3,channel='local'){
  clear();
  const valid=Number.isFinite(now),gap=lastAt===null?0:now-lastAt;
  lastAt=valid?now:null;
  if(!pressed){startedAt=null;needsRelease=false;return record(pressed,eligible,now,gap,channel);}
  // A suspended tab or stalled main thread must not complete an old hold.
  // Only an already observed hold can be stale; idle time before a new press
  // grants no credit and must not force an unnecessary release.
  if(!valid||gap<0||(startedAt!==null&&gap>maxGapSeconds)){startedAt=null;needsRelease=true;result.interrupted=true;return record(pressed,eligible,now,gap,channel);}
  if(needsRelease||!eligible){startedAt=null;return record(pressed,eligible,now,gap,channel);}
  // Never grant time before the first observed eligible press.
  if(startedAt===null)startedAt=now;
  result.elapsed=Math.min(duration,Math.max(0,now-startedAt));
  result.ready=result.elapsed>=duration-1e-8;
  if(result.ready)needsRelease=true;
  return record(pressed,eligible,now,gap,channel);
 }
 return {advance,reset,getTrace:()=>trace};
}
