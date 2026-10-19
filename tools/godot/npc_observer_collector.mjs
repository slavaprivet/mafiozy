// Unpaused observer-owned primitive storage. Importing this module does not run
// source, create a browser, inspect actors, read storage, RNG or clocks.
export const COLLECTOR_NAMESPACE='__mafioziNpcObserver22';
export const COLLECTOR_VERSION='mafiozi.scalar-observer/v1';

// Keep this factory self-contained: bootstrapSource embeds its exact source.
export function createScalarCollector(options={}){
 const capacity=options.capacity??32768,maxScopes=options.maxScopes??64,maxStringLength=options.maxStringLength??4096,maxStringUnits=options.maxStringUnits??1048576,startArmed=options.startArmed===undefined?true:options.startArmed;
 if(!Number.isInteger(capacity)||capacity<1||capacity>262144||!Number.isInteger(maxScopes)||maxScopes<1||maxScopes>4096||!Number.isInteger(maxStringLength)||maxStringLength<1||maxStringLength>1048576||!Number.isInteger(maxStringUnits)||maxStringUnits<1||maxStringUnits>16777216||typeof startArmed!=='boolean')throw Error('observer_invalid_configuration');
 // Every event has six fixed scalar columns. Strings are immutable primitives;
 // source objects/functions are never retained or examined, even on failure.
 const numbers=new Float64Array(capacity*6),types=new Uint8Array(capacity*6),strings=new Array(capacity*6).fill(undefined),kinds=new Array(capacity).fill(undefined);
 const operations=new Uint8Array(capacity),scopeIds=new Uint32Array(capacity),parentIds=new Uint32Array(capacity),scopeStack=new Uint32Array(maxScopes),scopeKinds=new Array(maxScopes).fill(undefined);
 let count=0,depth=0,nextScope=1,stringUnits=0,fault=null,holdAtOrdinal=null,registrationEndCount=0,getterEntryCount=0,sealed=false;
 let armed=startArmed,armCount=0,preArmEventAttempts=0,preArmGetterEntries=0,preArmCountersSaturated=false;
 const isFiniteNumber=Number.isFinite,isInteger=Number.isInteger,freeze=Object.freeze;
 const config=freeze({capacity,maxScopes,maxStringLength,maxStringUnits,startArmed});
 function hold(reason){if(fault===null){fault=reason;holdAtOrdinal=count+1;}}
 function preArm(kind,operation){
  if(preArmEventAttempts<9007199254740991)preArmEventAttempts++;else preArmCountersSaturated=true;
  if(operation===0&&kind==='getter.entry'){if(preArmGetterEntries<9007199254740991)preArmGetterEntries++;else preArmCountersSaturated=true;}
 }
 function arm(){try{if(sealed||fault!==null)return false;if(armCount<9007199254740991)armCount++;else preArmCountersSaturated=true;armed=true;return true;}catch{hold('observer_fault');return false;}}
 function scalarType(v){if(v===undefined)return 0;if(v===null)return 1;if(typeof v==='boolean')return v?3:2;if(typeof v==='number')return 4;if(typeof v==='string')return v.length<=maxStringLength?5:-2;return -1;}
 function put(offset,value,type){types[offset]=type;if(type===4)numbers[offset]=value;else if(type===5)strings[offset]=value;}
 function append(operation,scope,parent,kind,a,b,c,d,e,f){
  if(fault!==null||sealed)return false;
  if(!armed){preArm(kind,operation);return false;}
  if(count>=capacity){hold('event_capacity');return false;}
  if(typeof kind!=='string'||kind.length===0||kind.length>128){hold('invalid_kind');return false;}
  const ta=scalarType(a),tb=scalarType(b),tc=scalarType(c),td=scalarType(d),te=scalarType(e),tf=scalarType(f);
  if(ta<0||tb<0||tc<0||td<0||te<0||tf<0){hold(ta===-2||tb===-2||tc===-2||td===-2||te===-2||tf===-2?'string_length':'unsupported_scalar');return false;}
  const units=kind.length+(ta===5?a.length:0)+(tb===5?b.length:0)+(tc===5?c.length:0)+(td===5?d.length:0)+(te===5?e.length:0)+(tf===5?f.length:0);
  if(units>maxStringUnits-stringUnits){hold('string_budget');return false;}
  const offset=count*6;
  put(offset,a,ta);put(offset+1,b,tb);put(offset+2,c,tc);put(offset+3,d,td);put(offset+4,e,te);put(offset+5,f,tf);
  operations[count]=operation;scopeIds[count]=scope;parentIds[count]=parent;kinds[count]=kind;count++;stringUnits+=units;
  if(operation===0&&kind==='registration.end')registrationEndCount++;
  if(operation===0&&kind==='getter.entry')getterEntryCount++;
  return true;
 }
 function record(kind,a,b,c,d,e,f){try{append(0,depth?scopeStack[depth-1]:0,depth>1?scopeStack[depth-2]:0,kind,a,b,c,d,e,f);}catch{hold('observer_fault');}}
 function enter(kind,a,b,c,d,e,f){try{
  if(fault!==null||sealed)return 0;if(!armed){preArm(kind,1);return 0;}if(depth>=maxScopes){hold('scope_capacity');return 0;}
  const token=nextScope,parent=depth?scopeStack[depth-1]:0;
  if(!append(1,token,parent,kind,a,b,c,d,e,f))return 0;
  nextScope++;scopeStack[depth]=token;scopeKinds[depth++]=kind;return token;
 }catch{hold('observer_fault');return 0;}}
 function leave(token,kind,a,b,c,d,e,f){try{
  if(fault!==null||sealed)return;
  if(!armed){preArm(kind,2);return;}
  if(!isInteger(token)||token<=0||depth===0||scopeStack[depth-1]!==token||scopeKinds[depth-1]!==kind){hold('invalid_scope');return;}
  if(append(2,token,depth>1?scopeStack[depth-2]:0,kind,a,b,c,d,e,f)){scopeStack[--depth]=0;scopeKinds[depth]=undefined;}
 }catch{hold('observer_fault');}}
 function tap(kind,value,a,b){try{record(kind,value,a,b);}catch{hold('observer_fault');}return value;}
 function status(){return freeze({schema:'mafiozi.scalar-observer-status/v1',state:fault?'CAPTURE_INCOMPLETE_HOLD':sealed?'SEALED':armed?'RECORDING':'DISARMED',events:count,openScopes:depth,fault,holdAtOrdinal,stringUnits,registration_end_count:registrationEndCount,getter_entry_count:getterEntryCount,sealed,armed,arm_count:armCount,preArmEventAttempts,preArmGetterEntries,preArmCountersSaturated,
  allocated_numeric_bytes:numbers.byteLength+types.byteLength+operations.byteLength+scopeIds.byteLength+parentIds.byteLength+scopeStack.byteLength,preallocated_primitive_reference_slots:strings.length+kinds.length+scopeKinds.length,
  registered_frame:false,physical_admission:false});}
 function seal(){if(!sealed){if(depth!==0)hold('snapshot_open_scope');sealed=true;}return status();}
 function snapshot(){
  // Snapshot is explicitly a later control operation. Seal before allocating so
  // repeated snapshots cannot see subsequently changing observer data.
  seal();
  const overlays=[],events=[],bytes=new Uint8Array(8),view=new DataView(bytes.buffer);
  function encodedNumber(value,where){view.setFloat64(0,value,true);overlays.push(freeze({path:freeze(where),bytes_le:freeze(Array.from(bytes))}));return isFiniteNumber(value)?value:null;}
  function scalar(offset,index){const t=types[offset],where=['events',index,'values',offset%6,'value'];
   if(t===0)return freeze({type:'undefined'});if(t===1)return freeze({type:'null'});if(t===2||t===3)return freeze({type:'boolean',value:t===3});
   if(t===4)return freeze({type:'number',value:encodedNumber(numbers[offset],where)});return freeze({type:'string',value:strings[offset]});
  }
  for(let i=0;i<count;i++){
   const values=[];for(let j=0;j<6;j++)values.push(scalar(i*6+j,i));
   events.push(freeze({ordinal:encodedNumber(i+1,['events',i,'ordinal']),operation:operations[i]===0?'record':operations[i]===1?'enter':'leave',kind:kinds[i],scope:encodedNumber(scopeIds[i],['events',i,'scope']),parent_scope:encodedNumber(parentIds[i],['events',i,'parent_scope']),values:freeze(values)}));
  }
  return freeze({schema:'mafiozi.scalar-observer-packet/v1',profile:'UNPAUSED_INSTRUMENTED_SOURCE_OBSERVATION',config,status:status(),data:freeze({events:freeze(events)}),data_float64:freeze(overlays),registered_frame:false,physical_admission:false});
 }
 return freeze({record,enter,leave,tap,arm,status,seal,snapshot});
}

export function bootstrapSource(config={}){
 // Validate configuration without running source, then emit only canonical
 // validated integer bounds. Property access happens here, outside source code.
 const validated=createScalarCollector(config).snapshot().config;
 return `(()=>{'use strict';const name=${JSON.stringify(COLLECTOR_NAMESPACE)};if(name in globalThis)throw Error('NPC_OBSERVER_NAMESPACE_CONFLICT');const sink=(${createScalarCollector.toString()})(${JSON.stringify(validated)});Object.defineProperty(globalThis,name,{value:sink,writable:false,configurable:false,enumerable:false});})();\n`;
}
