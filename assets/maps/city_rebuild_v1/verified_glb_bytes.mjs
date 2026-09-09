// Parsed scenes deliberately remain private to their actor. This cache only
// shares immutable, verified source bytes, so a hero/NPC/portrait can still
// dispose its own geometry, material, texture and skeleton resources safely.
const caches=new WeakMap();

function abortError(){return new DOMException('Aborted','AbortError');}

function withSignal(promise,signal){
 if(!signal)return promise;
 if(signal.aborted)return Promise.reject(abortError());
 return new Promise((resolve,reject)=>{
  const onAbort=()=>{signal.removeEventListener('abort',onAbort);reject(abortError());};
  signal.addEventListener('abort',onAbort,{once:true});
  promise.then(value=>{signal.removeEventListener('abort',onAbort);resolve(value);},error=>{signal.removeEventListener('abort',onAbort);reject(error);});
 });
}

async function verifyAsset(asset,fetcher,{requireHash=false}={}){
 const response=await fetcher(asset.url);
 if(!response?.ok)throw Error('GLB asset HTTP '+(response?.status??'failed'));
 const bytes=new Uint8Array(await response.arrayBuffer());
 if(bytes.byteLength!==asset.bytes)throw Error('GLB asset byte mismatch');
 const subtle=globalThis.crypto?.subtle;
 if(requireHash&&!subtle)throw Error('GLB SHA-256 unavailable');
 if(subtle){
  const digest=await subtle.digest('SHA-256',bytes),hex=[...new Uint8Array(digest)].map(value=>value.toString(16).padStart(2,'0')).join('');
  if(hex!==asset.sha256)throw Error('GLB asset hash mismatch');
 }
 return bytes;
}

// A caller aborting its presentation must not poison the shared request for
// another actor. It stops waiting/parse for that caller; immutable download
// completion stays available to the next live consumer.
export function loadVerifiedGlbBytes({asset,fetch:fetcher=globalThis.fetch,signal,requireHash=false}={}){
 if(!asset?.url||!Number.isInteger(asset.bytes)||asset.bytes<1||!asset.sha256)throw Error('Verified GLB asset metadata required');
 if(typeof fetcher!=='function')throw Error('Verified GLB fetch required');
 if(signal?.aborted)return Promise.reject(abortError());
 let cache=caches.get(fetcher);if(!cache){cache=new Map();caches.set(fetcher,cache);}
 const key=asset.url+'|'+asset.bytes+'|'+asset.sha256;
 let pending=cache.get(key);
 if(!pending){
  pending=verifyAsset(asset,fetcher,{requireHash});
  cache.set(key,pending);
  pending.catch(()=>{if(cache.get(key)===pending)cache.delete(key);});
 }
 // GLTFLoader receives a fresh backing store. Its parser and every resulting
 // scene remain independently owned exactly as before this cache existed.
 return withSignal(pending,signal).then(bytes=>bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
}
