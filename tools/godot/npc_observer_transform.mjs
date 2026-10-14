// Exact byte allowlist. Pure response transformation: no source file mutation,
// application imports, browser, server, clocks, RNG or serialization at runtime.
import crypto from 'node:crypto';
export const SOURCE_PINS=Object.freeze({
 'world.html':'9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5',
 'assets/maps/city_rebuild_v1/walk_preview.mjs':'e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47',
 'assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs':'996143f37a8f380c16cde9c7ecd4eb42c4af109e4b364dff3ffc0aeca946865d',
 'assets/maps/city_rebuild_v1/npc_support_cache.mjs':'33f06489bc6f77e500e1d4e8f9735779293de8b2a00779366c4be9aba7237883',
 'assets/maps/city_rebuild_v1/mercenary_fences.mjs':'6c657e4dc141bcb2489af0e3f60437e2af12741f33f495f7e47f7a46eb2432f2',
 'assets/maps/city_rebuild_v1/mercenary_power_panel.mjs':'5bc7b10ee69cfb601d8b62c72946f79a89db3d97e6cc3a2058c91a39441318db'
});
export const sha256=value=>crypto.createHash('sha256').update(value).digest('hex');
// Sink access itself is guarded. Sink exceptions must never swallow a source
// exception or alter a source result. Arguments are already computed scalars;
// unsupported values may put the collector on HOLD but are returned unchanged.
export const OBSERVER_PRELUDE=`
function __npcObs22Arm(){try{globalThis.__mafioziNpcObserver22?.arm();}catch{}}
function __npcObs22Record(kind,a,b,c,d,e,f){try{globalThis.__mafioziNpcObserver22?.record(kind,a,b,c,d,e,f);}catch{}}
function __npcObs22Enter(kind,a,b,c,d,e,f){try{return globalThis.__mafioziNpcObserver22?.enter(kind,a,b,c,d,e,f)||0;}catch{return 0;}}
function __npcObs22Leave(token,kind,a,b,c,d,e,f){try{globalThis.__mafioziNpcObserver22?.leave(token,kind,a,b,c,d,e,f);}catch{}}
function __npcObs22Tap(kind,value,a,b){__npcObs22Record(kind,value,a,b);return value;}
function __npcObs22Call(kind,invoke,a,b){try{const value=invoke();return __npcObs22Tap(kind+'.return',value,a,b);}catch(error){__npcObs22Record(kind+'.throw');throw error;}}
function __npcObs22Ground(kind,invoke,x,z){try{const value=invoke(x,z);return __npcObs22Tap(kind+'.return',value,x,z);}catch(error){__npcObs22Record(kind+'.throw',x,z);throw error;}}
`;
// The source hash and explicit end anchor authorize the whole function closure.
// This scanner is only used on these pinned functions; it is not a JS parser.
function closure(code,signature){
 const start=unique(code,signature),body=start+signature.lastIndexOf('{');
 let depth=0,state='code';
 for(let i=body;i<code.length;i++){
  const c=code[i],n=code[i+1];
  if(state==='line'){if(c==='\n')state='code';continue;}
  if(state==='comment'){if(c==='*'&&n==='/'){state='code';i++;}continue;}
  if(state!=='code'){if(c==='\\')i++;else if(c===state)state='code';continue;}
  if(c==='/'&&n==='/'){state='line';i++;continue;}
  if(c==='/'&&n==='*'){state='comment';i++;continue;}
  if(c==='"'||c==="'"||c==='`'){state=c;continue;}
  if(c==='{')depth++;else if(c==='}'&&--depth===0)return {start,body,end:i+1};
 }
 throw Error('observer_unclosed_anchor:'+signature);
}
function unique(code,anchor){const at=code.indexOf(anchor);if(at<0||code.indexOf(anchor,at+anchor.length)>=0)throw Error('observer_anchor_not_unique:'+anchor);return at;}

export function transformNpcObserverResponse(path,input){
 if(!Object.hasOwn(SOURCE_PINS,path))throw Error('observer_path_not_allowed');
 if(!Buffer.isBuffer(input)&&!(input instanceof Uint8Array))throw Error('observer_bytes_required');
 const original=Buffer.from(input),originalSha256=sha256(original);
 if(originalSha256!==SOURCE_PINS[path])throw Error('observer_original_sha_mismatch:'+path);
 const code=original.toString('utf8');
 if(!Buffer.from(code).equals(original))throw Error('observer_utf8_roundtrip');
 if(code.includes('__npcObs22')||code.includes('__mafioziNpcObserver22'))throw Error('observer_symbol_collision');
 const edits=[];
 const replace=(name,anchor,replacement)=>{const start=unique(code,anchor);edits.push({name,start,end:start+anchor.length,replacement});};
 const insert=(name,at,text)=>edits.push({name,start:at,end:at,replacement:text});
 const scope=(name,signature,args='')=>{
  const bounds=closure(code,signature);
  insert(name+'.enter',bounds.body+1,`const __npcObs22Token=__npcObs22Enter('${name}'${args?','+args:''});try{`);
  insert(name+'.leave',bounds.end-1,`}finally{__npcObs22Leave(__npcObs22Token,'${name}');}`);
 };
 if(path==='world.html'){
  insert('helpers',unique(code,'function _npcNavigationAt(r,c){'),OBSERVER_PRELUDE);
  scope('navigation.query','function _npcNavigationAt(r,c){','r,c');
  scope('placement','function _npcInitialSafePlacement(){');
  scope('placement.slice','function _npcInitialPlacementStep(maxChecks=96,maxMs=2){','maxChecks,maxMs');
  scope('getter','function _getWalkNpcVehicleTraffic(){');
  // Insert after the scope prefix by replacing the first original body line.
  replace('getter.entry',' const rows=[];for(const car of CARS)if(car&&!car._nativeParkingPending'," __npcObs22Record('getter.entry');const rows=[];for(const car of CARS)if(car&&!car._nativeParkingPending");
  replace('getter.frame',"return {frame:typeof prevT==='number'?prevT:0,rows};","return {frame:__npcObs22Tap('getter.return',typeof prevT==='number'?prevT:0),rows};");
  const accessors=[
   ['row.r','return xy?car.y:car.r','return __npcObs22Tap(\'row.r\',xy?car.y:car.r,id)'],
   ['row.c','return xy?car.x:car.c','return __npcObs22Tap(\'row.c\',xy?car.x:car.c,id)'],
   ['row.ang','return Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy||0,car.dirDx||1)','return __npcObs22Tap(\'row.ang\',Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy||0,car.dirDx||1),id)'],
   ['row.distance','return Math.hypot((xy?car.y:car.r)-player.r,(xy?car.x:car.c)-player.c)','return __npcObs22Tap(\'row.distance\',Math.hypot((xy?car.y:car.r)-player.r,(xy?car.x:car.c)-player.c),id)']
  ];
  for(const [name,anchor,replacement]of accessors)replace(name,anchor,replacement);
  // Service accessor identity is not read again: observing the scalar alone
  // remains partial; no additional car.id read is introduced to label it.
  replace('service.r','get r(){return car.y}','get r(){return __npcObs22Tap(\'service.r\',car.y)}');
  replace('service.c','get c(){return car.x}','get c(){return __npcObs22Tap(\'service.c\',car.x)}');
  replace('service.ang','get ang(){return car.ang||0}','get ang(){return __npcObs22Tap(\'service.ang\',car.ang||0)}');
  replace('service.distance','get viewerDistance(){return Math.hypot(car.y-player.r,car.x-player.c)}','get viewerDistance(){return __npcObs22Tap(\'service.distance\',Math.hypot(car.y-player.r,car.x-player.c))}');
  replace('placement.deadline','const deadline=performance.now()+maxMs;let checks=0;',"const deadline=performance.now()+maxMs;__npcObs22Record('placement.deadline',deadline,maxChecks,maxMs);let checks=0;");
  replace('placement.commit','row.r=chosen.r;row.c=chosen.c;n.walking=false;',"__npcObs22Record('placement.chosen',chosen.r,chosen.c,kind,xy);row.r=chosen.r;row.c=chosen.c;n.walking=false;");
  replace('placement.source_id','function _npcInitialPlacementEligible(n){return n&&n.id!==undefined',"function _npcInitialPlacementEligible(n){return n&&__npcObs22Tap('placement.source_id',n.id)!==undefined");
  replace('placement.rows','_npcInitialPlacementRows=rows;',"_npcInitialPlacementRows=rows;__npcObs22Record('placement.rows',rows.length);let __npcObs22RowOrdinal=0;");
  replace('placement.row.enter','for(const row of rows){const {n}=row;if(!_npcInitialPlacementEligible(n)',"for(const row of rows){const __npcObs22RowToken=__npcObs22Enter('placement.row',__npcObs22RowOrdinal++,row.kind,row.xy,row.r,row.c);try{const {n}=row;if(!_npcInitialPlacementEligible(n)");
  const rowEnd='_npcInitialPlacementQueue.push(row);\r\n }\r\n _npcInitialPlacementStep(128,4);';
  replace('placement.row.leave',rowEnd,"_npcInitialPlacementQueue.push(row);\r\n }finally{__npcObs22Leave(__npcObs22RowToken,'placement.row');}}\r\n _npcInitialPlacementStep(128,4);");
 }else{
  insert('helpers',0,OBSERVER_PRELUDE);
  if(path.endsWith('/walk_preview.mjs')){
   replace('registration',' npcBridge?.registerWalkNpcNavigationResolver?.(npcNativeNavigation.query);'," {__npcObs22Arm();const __npcObs22Registration=__npcObs22Enter('registration');try{npcBridge?.registerWalkNpcNavigationResolver?.(npcNativeNavigation.query);}catch(__npcObs22Error){__npcObs22Record('registration.throw');throw __npcObs22Error;}finally{__npcObs22Record('registration.end');__npcObs22Leave(__npcObs22Registration,'registration');}}");
   replace('merc.gate',' if(window.MafioziMercenaries?.canUseLocalEffects?.()){'," if(__npcObs22Call('merc.gate',()=>window.MafioziMercenaries?.canUseLocalEffects?.())){");
   replace('merc.fence.read',"JSON.parse(localStorage.getItem(key)||'[]')","JSON.parse(__npcObs22Call('merc.fence.read',()=>localStorage.getItem(key))||'[]')");
   replace('merc.power.read',"powered=localStorage.getItem(powerKey)!=='off';","powered=__npcObs22Call('merc.power.read',()=>localStorage.getItem(powerKey))!=='off';");
  }else if(path.endsWith('/npc_logical_vehicle_binding.mjs')){
   scope('logical.ensure','function ensure(){');
   replace('logical.ensure.hit','if(records)return;records=[];',"if(records){__npcObs22Record('logical.ensure.cached');return;}__npcObs22Record('logical.ensure.miss');records=[];");
   replace('logical.ground','actor.floorY=groundHeight(c*worldScale,r*worldScale);',"actor.floorY=__npcObs22Ground('ground.logical',groundHeight,c*worldScale,r*worldScale);");
   const body='blocks(x,z,body={}){ensure();const bucket=grid.get(Math.floor(x/cellSize)+\',\'+Math.floor(z/cellSize))||[];return bucket.some(record=>record.id!==body.ignoreId&&trafficActorBlocks(record.actor,x,z,0,body));}';
   replace('logical.query',body,"blocks(x,z,body={}){const __npcObs22Token=__npcObs22Enter('logical.query',x,z);try{ensure();const bucket=grid.get(Math.floor(x/cellSize)+','+Math.floor(z/cellSize))||[];return __npcObs22Tap('logical.query.return',bucket.some(record=>record.id!==body.ignoreId&&trafficActorBlocks(record.actor,x,z,0,body)),x,z);}finally{__npcObs22Leave(__npcObs22Token,'logical.query');}}");
  }else if(path.endsWith('/npc_support_cache.mjs')){
   replace('ground.uncached','if(!Number.isFinite(x)||!Number.isFinite(z))return sample(x,z);',"if(!Number.isFinite(x)||!Number.isFinite(z))return __npcObs22Ground('ground.support.uncached',sample,x,z);");
   replace('ground.cached','if(cached!==undefined){stats.hits++;return cached;}',"if(cached!==undefined){stats.hits++;return __npcObs22Tap('ground.support.cached',cached,x,z);}");
   replace('ground.sample','stats.misses++;const value=sample(x,z);',"stats.misses++;const value=__npcObs22Ground('ground.support',sample,x,z);");
  }else if(path.endsWith('/mercenary_fences.mjs')){
   replace('merc.fence.ground','const y=groundHeight(site.x,site.z),object=new THREE.Group();',"const y=__npcObs22Ground('ground.merc.fence',groundHeight,site.x,site.z),object=new THREE.Group();");
  }else if(path.endsWith('/mercenary_power_panel.mjs')){
   replace('merc.power.ground','object.position.set(site.x,groundHeight(site.x,site.z),site.z);',"object.position.set(site.x,__npcObs22Ground('ground.merc.power',groundHeight,site.x,site.z),site.z);");
  }
 }
 edits.sort((a,b)=>a.start-b.start||a.end-b.end);
 for(let i=1;i<edits.length;i++)if(edits[i].start<edits[i-1].end)throw Error('observer_overlapping_edits');
 const parts=[],receipts=[];let cursor=0;
 for(const e of edits){parts.push(code.slice(cursor,e.start),e.replacement);cursor=e.end;receipts.push({name:e.name,startByte:Buffer.byteLength(code.slice(0,e.start)),endByte:Buffer.byteLength(code.slice(0,e.end)),originalSha256:sha256(Buffer.from(code.slice(e.start,e.end))),replacementSha256:sha256(Buffer.from(e.replacement)),replacement:e.replacement});}
 parts.push(code.slice(cursor));const bytes=Buffer.from(parts.join(''));
 return {schema:'mafiozi.npc-observer-transform/v1',path,originalSha256,instrumentedSha256:sha256(bytes),bytes,edits:receipts,observerPreludeSha256:sha256(OBSERVER_PRELUDE),evidenceKind:'UNPAUSED_INSTRUMENTED_SOURCE_OBSERVATION',completeFrame:false,physicalAdmission:false};
}
