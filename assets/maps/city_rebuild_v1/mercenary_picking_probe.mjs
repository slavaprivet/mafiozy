// QA-only instrumentation. The original Raycaster performs the one traversal
// and one sort; wrappers never synthesize hits or change the render graph.
export function mercenaryPickingRootCategory(root,kind){
 if(kind==='vehicle')return 'cars';if(kind==='npc'||kind==='player')return 'npc';
 for(let node=root;node;node=node.parent){const data=node.userData||{},name=node.name||'';
  if(data.nativeTerrainKind)return 'native-terrain:'+data.nativeTerrainKind;
  if(data.landscape||data.landscapeGround||data.landscapeWater||data.landscapeTrail)return 'landscape';
  if(data.explorationRailway)return 'railway';
  if(data.explorationDecor)return 'exploration-decor';
  if(name==='EnvironmentGrass'||name==='CityRoadDressing'||name==='CityParking'||name==='Город · покрытия, трава и дорожное оформление')return 'environment';
  if(data.instance)return 'building-or-decor';
 }
 return 'other';
}

export function createMercenaryPickingProbe({enabled=false,document:doc,now=()=>performance.now(),intervalMs=1000,capacity=120}={}){
 // No timer, DOM, registry or traversal work at all outside perfqa.
 if(!enabled)return null;
 let active=null,lastSample=-Infinity,samples=0,blockedSamples=0,disposed=false;
 const history=[],limit=Math.max(1,Math.min(120,capacity|0));
 const summarize=values=>{const sorted=values.slice().sort((a,b)=>a-b),at=q=>sorted[Math.max(0,Math.ceil(sorted.length*q)-1)]??0;return {samples:sorted.length,p50Ms:at(.5),p95Ms:at(.95),maxMs:sorted.at(-1)??0};};
 function begin(time){
  if(disposed||active)return false;const start=Number.isFinite(time)?time:now();
  if(start-lastSample<Math.max(1000,intervalMs))return false;lastSample=start;
  active={version:1,kind:'natural-hover-qa',sampleId:++samples,timings:{},roots:[],candidateCount:0,intersections:0,raycastCalls:0,instrumentationComplete:true};
  active.started=start;active.cursor=start;return true;
 }
 function mark(name){if(!active)return;const time=now();active.timings[name]=(active.timings[name]||0)+Math.max(0,time-active.cursor);active.cursor=time;}
 function selected(result,hit){
  if(!active)return;active.selectedTargetId=result?.id??null;
  active.firstAcceptedHit=hit?{uuid:hit.object?.uuid??null,name:hit.object?.name??'',instanceId:hit.instanceId??null,faceIndex:hit.faceIndex??null,distance:hit.distance}:null;
  mark('resolveMs');
 }
 function intersect(raycaster,roots,getKind=()=>null){
  if(!active)return raycaster.intersectObjects(roots,true);
  const sample=active,restores=[],visited=new Set(),records=[],stack=[];
  const prepareStart=now();
  sample.candidateCount=roots.length;
  sample.ray={origin:raycaster.ray.origin.toArray(),direction:raycaster.ray.direction.toArray(),near:raycaster.near,far:Number.isFinite(raycaster.far)?raycaster.far:null,farKind:Number.isFinite(raycaster.far)?'finite':'infinite'};
  function wrap(node,record){
   const original=node.raycast;if(typeof original!=='function')return;
   const descriptor=Object.getOwnPropertyDescriptor(node,'raycast');
   // Standard Group/Object3D no-op methods do not contain their children.
   // Instrument actual geometric/custom methods, not empty group callbacks.
   if(!node.isMesh&&!node.isLine&&!node.isPoints&&!node.isSprite&&!descriptor)return;
   if(descriptor&&(!('value'in descriptor)||!descriptor.configurable&&!descriptor.writable)||!descriptor&&!Object.isExtensible(node)){sample.instrumentationComplete=false;return;}
   function wrapped(...args){
    const frame={childMs:0},start=now();stack.push(frame);
    try{return Reflect.apply(original,this,args);}
    finally{const elapsed=Math.max(0,now()-start);stack.pop();if(stack.length)stack.at(-1).childMs+=elapsed;record.raycastMs+=Math.max(0,elapsed-frame.childMs);record.calls++;sample.raycastCalls++;}
   }
   try{Object.defineProperty(node,'raycast',descriptor?{...descriptor,value:wrapped}:{value:wrapped,writable:true,configurable:true,enumerable:true});restores.push({node,descriptor,wrapped});}
   catch{sample.instrumentationComplete=false;}
  }
  function restore(){
   const start=now();
   for(let i=restores.length-1;i>=0;i--){const {node,descriptor,wrapped}=restores[i];
    // A custom raycast may deliberately replace itself. Preserve that original
    // behavior rather than overwriting its new method with an old descriptor.
    if(node.raycast!==wrapped){sample.instrumentationComplete=false;continue;}
    if(descriptor)Object.defineProperty(node,'raycast',descriptor);else delete node.raycast;
   }
   sample.timings.restoreMs=Math.max(0,now()-start);sample.cursor=now();
  }
  try{
   for(const root of roots){const record={uuid:root?.uuid??null,name:root?.name||'',category:mercenaryPickingRootCategory(root,getKind(root)),raycastMs:0,calls:0};records.push(record);
    const pending=[root];while(pending.length){const node=pending.pop();if(!node||visited.has(node))continue;visited.add(node);wrap(node,record);for(const child of node.children||[])pending.push(child);}
   }
   sample.timings.prepareMs=Math.max(0,now()-prepareStart);sample.instrumentedNodes=restores.length;sample.visitedNodes=visited.size;
   const start=now();
   try{const hits=raycaster.intersectObjects(roots,true);sample.intersections=hits.length;return hits;}
   finally{
    sample.timings.intersectTotalMs=Math.max(0,now()-start);
    const exclusive=records.reduce((sum,r)=>sum+r.raycastMs,0);sample.timings.exclusiveRaycastMs=exclusive;
    sample.timings.traversalSortProbeResidualMs=Math.max(0,sample.timings.intersectTotalMs-exclusive);
    const groups={};for(const record of records){const group=groups[record.category]||(groups[record.category]={roots:0,calls:0,raycastMs:0});group.roots++;group.calls+=record.calls;group.raycastMs+=record.raycastMs;}
    sample.categories=groups;sample.roots=records.sort((a,b)=>b.raycastMs-a.raycastMs).slice(0,10);
   }
  }finally{restore();}
 }
 function finish({blocked=false,failed=false}={}){
  if(!active)return;const sample=active;active=null;
  sample.blocked=blocked;sample.failed=failed;if(blocked)blockedSamples++;
  sample.timings.wholeHoverMs=Math.max(0,now()-sample.started);delete sample.started;delete sample.cursor;
  history.push(sample.timings);if(history.length>limit)history.shift();
  const phaseNames=new Set(history.flatMap(t=>Object.keys(t))),rolling={};for(const phase of phaseNames)rolling[phase]=summarize(history.filter(t=>Number.isFinite(t[phase])).map(t=>t[phase]));
  sample.rolling=rolling;sample.totalSamples=samples;sample.blockedSamples=blockedSamples;
  // DOM failure must never replace a game exception or lose an input action.
  try{if(doc?.documentElement?.dataset)doc.documentElement.dataset.mercenaryPickingProfile=JSON.stringify(sample);}catch{}
 }
 return {begin,mark,selected,intersect,finish,get active(){return !!active;},dispose(){disposed=true;active=null;history.length=0;if(doc?.documentElement?.dataset)delete doc.documentElement.dataset.mercenaryPickingProfile;}};
}
