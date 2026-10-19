// Isolated candidate; not imported by Walk until reviewed by its owner.
// Only interaction admission uses this clock. Animation and physics keep dt.
export function createVehicleEntryHoldClock({maxGapSeconds=.5}={}){
 let startedAt=null,lastAt=null,needsRelease=false;
 const result={elapsed:0,ready:false,interrupted:false};
 const clear=()=>{result.elapsed=0;result.ready=false;result.interrupted=false;return result;};
 function reset(){startedAt=lastAt=null;needsRelease=false;return clear();}
 function advance(pressed,eligible,now,duration=.3){
  clear();
  const valid=Number.isFinite(now),gap=lastAt===null?0:now-lastAt;
  lastAt=valid?now:null;
  if(!pressed){startedAt=null;needsRelease=false;return result;}
  // Do not credit a suspended tab, a sleeping device or a stalled main thread.
  // The physical input must be released before another attempt can start.
  if(!valid||gap<0||gap>maxGapSeconds){startedAt=null;needsRelease=true;result.interrupted=true;return result;}
  if(needsRelease||!eligible){startedAt=null;return result;}
  // A newly observed press receives no time from before it was observed.
  if(startedAt===null)startedAt=now;
  result.elapsed=Math.min(duration,Math.max(0,now-startedAt));
  result.ready=result.elapsed>=duration-1e-8;
  if(result.ready)needsRelease=true;
  return result;
 }
 return {advance,reset};
}
