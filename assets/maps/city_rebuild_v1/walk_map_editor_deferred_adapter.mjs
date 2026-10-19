function immutable(value){return Object.freeze(structuredClone(value));}
function validAdapter(value){return value&&typeof value.enumerate==='function'&&typeof value.hasKey==='function'&&typeof value.recordFor==='function';}

/**
 * Keeps lazily-created owners outside the static composite until each key has
 * been delivered to the UI. A key cannot be picked or mutated before its batch
 * is registered.
 */
export function createWalkMapDeferredAdapter({baseAdapter}={}){
 if(!validAdapter(baseAdapter))throw new Error('Deferred adapter requires a base adapter');
 let disposed=false;const ownerByKey=new Map(),owners=new Set(),ordered=[];
 const active=()=>{if(disposed)throw new Error('Deferred map adapter is disposed')};
 function owner(key){active();if(baseAdapter.hasKey(key))return baseAdapter;const value=ownerByKey.get(key);if(!value)throw new Error(`Unknown deferred map object: ${key}`);return value;}
 function call(key,name,...args){const target=owner(key),method=target[name];if(typeof method!=='function')throw new Error(`Deferred map object does not support ${name}: ${key}`);return method.call(target,key,...args);}
 function registerBatch(generatedAdapter,items){
  active();if(!validAdapter(generatedAdapter)||!Array.isArray(items))throw new Error('Deferred registration requires an adapter and item batch');const staged=[],seen=new Set();
  for(const raw of items){const key=String(raw?.key??'');if(!key||seen.has(key)||baseAdapter.hasKey(key)||ownerByKey.has(key)||!generatedAdapter.hasKey(key))throw new Error(`Invalid or duplicate deferred key: ${key||'<empty>'}`);seen.add(key);staged.push(raw)}
  owners.add(generatedAdapter);for(const item of staged){ownerByKey.set(item.key,generatedAdapter);ordered.push(item)}return Object.freeze(staged.slice());
 }
 function enumerate({category=null,query='',offset=0,limit=Infinity}={}){active();const base=baseAdapter.enumerate(),all=[...base,...ordered],needle=String(query??'').trim().toLocaleLowerCase('ru'),filtered=(!category||category==='all')&&!needle?all:all.filter(item=>(!category||category==='all'||item.category===category)&&(!needle||`${item.label||''} ${item.assetId||''} ${item.id||''}`.toLocaleLowerCase('ru').includes(needle))),start=Math.max(0,Number.isSafeInteger(offset)?offset:0),count=Number.isFinite(limit)?Math.max(0,Math.floor(limit)):Infinity;return filtered.slice(start,count===Infinity?undefined:start+count)}
 function resolveIntersection(hit){active();const base=baseAdapter.resolveIntersection?.(hit);if(base)return base;for(const candidate of owners){const result=candidate.resolveIntersection?.(hit);if(result&&ownerByKey.get(result.key)===candidate)return result}return null}
 function resolvePoint(point,options={}){active();let best=baseAdapter.resolvePoint?.(point,options)??null;for(const candidate of owners){const external=options.acceptKey,acceptKey=(key,item)=>ownerByKey.get(key)===candidate&&(!external||external(key,item)),result=candidate.resolvePoint?.(point,{...options,acceptKey});if(result&&(!best||result.distance<best.distance-1e-9||Math.abs(result.distance-best.distance)<=1e-9&&result.key<best.key))best=result}return best}
 function cancelAllPreviews(){active();let count=Number(baseAdapter.cancelAllPreviews?.()??baseAdapter.disposePreview?.())||0;for(const candidate of owners)count+=Number(candidate.disposePreview?.())||0;return count}
 return Object.freeze({id:'deferred-map-v1',get datasets(){return Object.freeze([...new Set([...(baseAdapter.datasets||[]),...[...owners].flatMap(item=>item.datasets||[])])])},hasKey:key=>!disposed&&(baseAdapter.hasKey(key)||ownerByKey.has(key)),enumerate,registerBatch,resolveIntersection,resolvePoint,
  deleteCommand:key=>call(key,'deleteCommand'),transformCommand:(key,transform)=>call(key,'transformCommand',transform),beginPreview:key=>call(key,'beginPreview'),updatePreview:(key,transform)=>call(key,'updatePreview',transform),commitPreview:key=>call(key,'commitPreview'),cancelPreview:key=>owner(key).cancelPreview?.(key)??false,cancelAllPreviews,disposePreview:cancelAllPreviews,dependenciesFor:key=>immutable(owner(key).dependenciesFor?.(key)||[]),recordFor:key=>immutable(owner(key).recordFor(key)),rootFor:key=>owner(key).rootFor?.(key)??null,replaceRecord:(key,record,root)=>call(key,'replaceRecord',record,root),deactivate:key=>call(key,'deactivate'),suppress:(key,value=true)=>owner(key).suppress?.(key,value)??false,
  dispose(){if(disposed)return;disposed=true;ownerByKey.clear();ordered.length=0;baseAdapter.dispose?.();for(const candidate of owners)candidate.dispose?.();owners.clear()}});
}
