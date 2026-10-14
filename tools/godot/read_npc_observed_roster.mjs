// Read-only adapter for a sealed primitive observer packet. Does not execute
// source, allocate source identities, sample ground, spawn actors or grant authority.
import {createHash} from 'node:crypto';

export const OBSERVED_ROSTER_VERSION='mafiozi.observed-registration-roster/v1';
const WORLD_SHA='9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5';
const MAX_BYTES=64*1024*1024,MAX_EVENTS=262144;
const HASH=/^[0-9a-f]{64}$/;
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const integer=v=>Number.isSafeInteger(v)&&v>=0;
function freeze(value){if(value&&typeof value==='object'){for(const entry of Object.values(value))freeze(entry);Object.freeze(value);}return value;}
function result(status,reasons,rows=[],extra={}){
 return freeze({schema:OBSERVED_ROSTER_VERSION,status,known:status==='OBSERVED',complete:status==='OBSERVED',reasons,rows,
  observation_kind:'REGISTRATION_PRE_QUEUE_PLACEMENT_ROWS',binding_kind:'HOST_TRUSTED_NOT_SOURCE_AUTHENTICATED',
  first_getter:{status:'FAIL',reasons:['packet_not_validated'],complete:false},...extra,
  complete_scope:'OBSERVED_PREQUEUE_PLACEMENT_ROWS_ONLY',alias_identity_known:false,
  current_frame_known:false,birth_history_known:false,registered_frame_known:false,physical_admission:false});
}
function fail(reason){throw Error(reason);}
// Separate from roster completeness: this proves an observed call chain only.
// No values, source accesses or omitted events are reconstructed here.
function firstGetter(packet,scopes,registrations,records){
 const reasons=[],s=packet.status,c=packet.config,all=[...scopes.values()];
 if(c.startArmed!==false||s.armed!==true||s.arm_count!==1)reasons.push('arming_boundary_not_unique');
 if(!integer(s.preArmEventAttempts)||!integer(s.preArmGetterEntries)||s.preArmGetterEntries>s.preArmEventAttempts||s.preArmCountersSaturated!==false)reasons.push('prearm_counters_unverified');
 if(s.preArmGetterEntries!==0)reasons.push('getter_before_arm_or_unknown');
 if(s.fault!==null||s.openScopes!==0)reasons.push('lost_or_unclosed_events');
 const getters=all.filter(x=>x.kind==='getter');
 const entries=records.filter(x=>x.record.kind==='getter.entry'),returns=records.filter(x=>x.record.kind==='getter.return');
 if(entries.length!==getters.length||returns.length!==getters.length||entries.some(x=>x.scope?.kind!=='getter')||returns.some(x=>x.scope?.kind!=='getter'))reasons.push('getter_records_missing_or_orphan');
 for(const g of getters){
  const en=g.records.filter(x=>x.kind==='getter.entry'),ret=g.records.filter(x=>x.kind==='getter.return');
  if(en.length!==1||ret.length!==1||en[0].ordinal!==g.enter+1||ret[0].ordinal!==g.leave-1||en[0].values.some(v=>v!==undefined)||typeof ret[0].values[0]!=='number'||ret[0].values.slice(1).some(v=>v!==undefined))reasons.push('getter_entry_return_pair:'+g.token);
 }
 const reg=registrations[0],end=reg?.records.filter(x=>x.kind==='registration.end')||[];
 if(registrations.length!==1||reg.parent!==null||reg.enter!==1||reg.leave===null||s.registration_end_count!==1||end.length!==1||reg.leave!==end[0].ordinal+1||reg.records.some(x=>x.kind==='registration.throw'))reasons.push('registration_boundary_incomplete');
 const first=getters[0];let chain=[];
 if(first){
  for(let p=first;p;p=p.parent)chain.push(p);
  if(chain.map(x=>x.kind).join('/')!=='getter/logical.ensure/logical.query/navigation.query/placement.slice/placement/registration'||chain.at(-1)!==reg||chain.some(x=>x.leave===null))reasons.push('first_getter_caller_chain');
  else{
   const [g,ensure,query,nav,slice,placement]=chain;
   if(all.filter(x=>x.kind==='placement'&&x.parent===reg).length!==1)reasons.push('placement_boundary_not_unique');
   const slices=all.filter(x=>x.kind==='placement.slice'&&x.parent===placement);
   const miss=ensure.records.filter(x=>x.kind==='logical.ensure.miss'),qr=query.records.filter(x=>x.kind==='logical.query.return');
   if(slices[0]!==slice||slice.values[0]!==128||slice.values[1]!==4)reasons.push('first_getter_not_initial_slice');
   if(miss.length!==1||miss[0].ordinal>=g.enter||ensure.records.some(x=>x.kind==='logical.ensure.cached')||qr.length!==1||qr[0].ordinal<=ensure.leave||typeof qr[0].values[0]!=='boolean'||!Object.is(qr[0].values[1],query.values[0])||!Object.is(qr[0].values[2],query.values[1]))reasons.push('first_getter_consuming_query');
   if(end.length===1&&placement.leave>=end[0].ordinal)reasons.push('placement_registration_order');
  }
 }
 const state=reasons.length?'FAIL':first?'OBSERVED':'ABSENT';
 return {status:state,complete:state==='OBSERVED',reasons:state==='ABSENT'?['no_natural_getter_observed']:reasons,
  proof_scope:'FIRST_INSTRUMENTED_GETTER_INITIAL_REGISTRATION_QUERY',getter_count:getters.length,
  first_entry_ordinal:entries[0]?.record.ordinal??null,first_return_ordinal:returns[0]?.record.ordinal??null,
  caller_scopes:chain.map(x=>({kind:x.kind,scope:x.token,enter:x.enter,leave:x.leave})),
  pre_arm_getter_entries:s.preArmGetterEntries??null,arm_count:s.arm_count??null,
  original_storage_transcript:false,uninterrupted_timing:false,current_frame_known:false,physical_admission:false};
}
function scalar(tag){
 if(!tag||typeof tag!=='object'||Array.isArray(tag))fail('scalar_shape');
 const keys=Object.keys(tag);
 if(tag.type==='undefined'||tag.type==='null'){
  if(keys.length!==1)fail('scalar_shape');return tag.type==='undefined'?undefined:null;
 }
 if(keys.length!==2||!Object.hasOwn(tag,'value'))fail('scalar_shape');
 if(tag.type==='boolean'&&typeof tag.value==='boolean'||tag.type==='string'&&typeof tag.value==='string'||tag.type==='number'&&typeof tag.value==='number')return tag.value;
 fail('scalar_type');
}
function restore(packet){
 const events=packet.data?.events,overlays=packet.data_float64;
 if(!Array.isArray(events)||events.length>MAX_EVENTS||!Array.isArray(overlays)||overlays.length>events.length*9)fail('event_or_overlay_budget');
 const seen=new Set();
 for(const overlay of overlays){
  const p=overlay?.path,b=overlay?.bytes_le;
  if(!Array.isArray(p)||p[0]!=='events'||!integer(p[1])||p[1]>=events.length||!Array.isArray(b)||b.length!==8||!b.every(v=>Number.isInteger(v)&&v>=0&&v<=255))fail('overlay_shape');
  let target,key;
  if(p.length===3&&['ordinal','scope','parent_scope'].includes(p[2])){target=events[p[1]];key=p[2];}
  else if(p.length===5&&p[2]==='values'&&integer(p[3])&&p[3]<6&&p[4]==='value'){
   target=events[p[1]]?.values?.[p[3]];key='value';if(target?.type!=='number')fail('overlay_not_number');
  }else fail('overlay_path');
  if(!target||typeof target!=='object'||!Object.hasOwn(target,key))fail('overlay_target');
  const signature=JSON.stringify(p);if(seen.has(signature))fail('overlay_duplicate');seen.add(signature);
  const value=Buffer.from(b).readDoubleLE(),readable=target[key];
  if(Number.isFinite(value)?typeof readable!=='number'||readable!==value:readable!==null)fail('overlay_readable_mismatch');
  target[key]=value;
 }
 for(let i=0;i<events.length;i++){
  const e=events[i];
  if(!e||typeof e!=='object'||!Array.isArray(e.values)||e.values.length!==6)fail('event_shape');
  for(const key of ['ordinal','scope','parent_scope'])if(!seen.has(JSON.stringify(['events',i,key])))fail('overlay_missing');
  for(let j=0;j<6;j++){
   if(e.values[j]?.type==='number'&&!seen.has(JSON.stringify(['events',i,'values',j,'value'])))fail('overlay_missing');
   scalar(e.values[j]);
  }
 }
 return events;
}

/** Binding must come from the independently reviewed host RUN/PLAN receipt,
 * never from packet self-declarations. It is trusted metadata, not source auth.
 * A shape-valid TEST_ONLY packet remains a fixture. All outputs are deep frozen.
 */
export function readObservedRoster(input,binding){
 let provenance;
 try{
  if(!Buffer.isBuffer(input)&&!(input instanceof Uint8Array))fail('bytes_required');
  const bytes=Buffer.from(input);
  if(bytes.length===0||bytes.length>MAX_BYTES)fail('packet_bytes');
  if(!binding||typeof binding!=='object'||typeof binding.run_id!=='string'||binding.run_id.length===0||binding.run_id.length>256||typeof binding.test_only!=='boolean')fail('host_binding');
  for(const name of ['data_sha256','world_source_sha256','collector_sha256','transformer_sha256','runner_sha256'])if(typeof binding[name]!=='string'||!HASH.test(binding[name]))fail('host_binding:'+name);
  if(binding.world_source_sha256!==WORLD_SHA)fail('world_source_binding');
  if(hash(bytes)!==binding.data_sha256)fail('packet_hash');
  provenance={run_id:binding.run_id,data_sha256:binding.data_sha256,world_source_sha256:binding.world_source_sha256,collector_sha256:binding.collector_sha256,transformer_sha256:binding.transformer_sha256,runner_sha256:binding.runner_sha256};
  const text=bytes.toString('utf8');if(!Buffer.from(text).equals(bytes))fail('packet_utf8');
  const packet=JSON.parse(text);
  if(packet?.schema!=='mafiozi.scalar-observer-packet/v1'||packet.profile!=='UNPAUSED_INSTRUMENTED_SOURCE_OBSERVATION'||packet.registered_frame!==false||packet.physical_admission!==false)fail('packet_schema_or_admission');
  const status=packet.status,config=packet.config;
  if(!status||status.sealed!==true||status.registered_frame!==false||status.physical_admission!==false)fail('unsealed_or_admitted_packet');
  if(!config||!integer(config.capacity)||config.capacity<1||config.capacity>MAX_EVENTS||!integer(config.maxScopes)||config.maxScopes<1||config.maxScopes>4096)fail('packet_config');
  if(status.fault!==null&&typeof status.fault!=='string'||!integer(status.events)||!integer(status.openScopes)||!integer(status.registration_end_count)||!integer(status.getter_entry_count))fail('packet_status');
  if(status.state!==(status.fault===null?'SEALED':'CAPTURE_INCOMPLETE_HOLD')||status.fault===null&&status.holdAtOrdinal!==null||status.fault!==null&&status.holdAtOrdinal!==status.events+1)fail('packet_status_consistency');
  const events=restore(packet);
  if(events.length!==status.events||events.length>config.capacity)fail('packet_count');
  const stack=[],scopes=new Map(),registrations=[],headers=[],rowScopes=[],records=[];
  let scopeSeq=0,endCount=0,getterCount=0,maxDepth=0;
  for(let i=0;i<events.length;i++){
   const e=events[i],v=e.values.map(scalar),top=stack.at(-1)||null,parent=stack.at(-2)||null;
   if(e.ordinal!==i+1||!integer(e.scope)||!integer(e.parent_scope)||typeof e.kind!=='string'||e.kind.length<1||e.kind.length>128)fail('event_identity');
   if(e.operation==='enter'){
    if(e.scope!==++scopeSeq||e.parent_scope!==(top?.token||0))fail('scope_enter');
    const s={token:e.scope,kind:e.kind,parent:top,enter:e.ordinal,leave:null,values:v,records:[]};scopes.set(s.token,s);stack.push(s);maxDepth=Math.max(maxDepth,stack.length);
    if(s.kind==='registration')registrations.push(s);
    if(s.kind==='placement.row')rowScopes.push(s);
   }else if(e.operation==='leave'){
    if(!top||top.token!==e.scope||top.kind!==e.kind||e.parent_scope!==(parent?.token||0))fail('scope_leave');
    top.leave=e.ordinal;stack.pop();
   }else if(e.operation==='record'){
    if(e.scope!==(top?.token||0)||e.parent_scope!==(parent?.token||0))fail('scope_record');
    const r={ordinal:e.ordinal,kind:e.kind,values:v};if(top)top.records.push(r);records.push({record:r,scope:top});
    if(e.kind==='registration.end')endCount++;
    if(e.kind==='getter.entry')getterCount++;
    if(e.kind==='placement.rows')headers.push({record:r,scope:top});
   }else fail('event_operation');
  }
  if(stack.length!==status.openScopes||maxDepth>config.maxScopes||endCount!==status.registration_end_count||getterCount!==status.getter_entry_count)fail('scope_status_mismatch');
  const extra={provenance,test_only:binding.test_only,packet_event_count:events.length,first_getter:firstGetter(packet,scopes,registrations,records)};
  const reasons=[];
  if(status.fault!==null)reasons.push('collector_hold:'+status.fault);
  if(stack.length)reasons.push('unclosed_source_scope');
  if(registrations.length!==1)return result('ABSENT',[...reasons,'registration_count:'+registrations.length],[],extra);
  const reg=registrations[0];
  if(reg.parent!==null)reasons.push('nested_registration');
  if(reg.leave===null)reasons.push('registration_not_closed');
  const regEnds=reg.records.filter(r=>r.kind==='registration.end');
  if(endCount!==1||regEnds.length!==1)reasons.push('registration_end_missing_or_duplicate');
  if(reg.records.some(r=>r.kind==='registration.throw'))reasons.push('registration_threw');
  const placements=[...scopes.values()].filter(s=>s.kind==='placement'&&s.parent===reg);
  if(placements.length!==1)return result('ABSENT',[...reasons,'placement_count:'+placements.length],[],extra);
  const placement=placements[0];
  if(placement.leave===null)reasons.push('placement_not_closed');
  if(regEnds.length===1&&(placement.leave===null||regEnds[0].ordinal<=placement.leave||reg.leave!==regEnds[0].ordinal+1))reasons.push('registration_end_order');
  const localHeaders=headers.filter(h=>h.scope===placement);
  if(localHeaders.length!==1)return result('ABSENT',[...reasons,'placement_header_count:'+localHeaders.length],[],extra);
  const header=localHeaders[0].record,count=header.values[0];
  if(!integer(count)||count>MAX_EVENTS||header.values.slice(1).some(v=>v!==undefined))fail('placement_header_shape');
  const candidates=rowScopes.filter(s=>s.parent===placement),rows=[];
  if(candidates.length!==count)reasons.push('placement_row_count:'+candidates.length+'/'+count);
  for(let i=0;i<candidates.length;i++){
   const s=candidates[i],[ordinal,kind,xy,r,c,unused]=s.values,rowReasons=[];
   if(ordinal!==i||s.enter<header.ordinal)fail('placement_row_order');
   if(unused!==undefined||!['resident','police'].includes(kind)||typeof xy!=='boolean'||typeof r!=='number'||typeof c!=='number')fail('placement_row_shape');
   if(s.leave===null)rowReasons.push('row_not_closed');
   if(!Number.isFinite(r)||!Number.isFinite(c))rowReasons.push('nonfinite_source_coordinates');
   const ids=s.records.filter(e=>e.kind==='placement.source_id');
   let sourceId={observed:false,type:'absent'};
   if(ids.length!==1)rowReasons.push('natural_source_id_count:'+ids.length);
   else{
    const id=ids[0].values[0];
    if(ids[0].values.slice(1).some(v=>v!==undefined))fail('source_id_shape');
    sourceId=id===undefined?{observed:true,type:'undefined'}:id===null?{observed:true,type:'null'}:{observed:true,type:typeof id,value:id};
    if(id===undefined)rowReasons.push('source_id_undefined');
    if(typeof id==='number'&&!Number.isFinite(id))rowReasons.push('source_id_nonfinite');
   }
   rows.push({row_ordinal:ordinal,row_scope:s.token,kind,xy,r,c,source_id:sourceId,complete:rowReasons.length===0,reasons:rowReasons});
   for(const reason of rowReasons)reasons.push('row['+i+']:'+reason);
  }
  return result(reasons.length?'PARTIAL':'OBSERVED',reasons,rows,{...extra,registration_scope:reg.token,placement_scope:placement.token,expected_row_count:count,header_event_ordinal:header.ordinal});
 }catch(error){return result('ABSENT',[error instanceof Error?error.message:'reader_failure'],[],provenance?{provenance,test_only:binding.test_only}:{});}
}
