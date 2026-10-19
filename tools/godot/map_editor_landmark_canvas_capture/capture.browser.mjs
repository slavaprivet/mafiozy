import * as THREE from './vendor/three.module.js';
// No WebGLRenderer is constructed. Actual source factories run only after capture().
const pins={source:'4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c',closure:'0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81'};
const assert=(condition,message)=>{if(!condition)throw Error(message);};
const hash=async bytes=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
const canonical=value=>JSON.stringify(sort(value));
function sort(value){if(Array.isArray(value))return value.map(sort);if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(key=>[key,sort(value[key])]));return value;}
const encoder=new TextEncoder();
let webglAttempts=0;
function blockContexts(proto){if(!proto)return;const get=proto.getContext;proto.getContext=function(kind,...args){if(kind!=='2d'){webglAttempts++;throw Error('Only original Canvas2D allowed; WebGL/other context refused');}return get.call(this,kind,...args);};}
blockContexts(HTMLCanvasElement.prototype);if(globalThis.OffscreenCanvas)blockContexts(OffscreenCanvas.prototype);
let assets=new Map(),lastReceipt=null,busy=false;
function nativeDocument(){
 const traces=new WeakMap();
 return {traces,createElement(type){assert(type==='canvas','Original recipe requested non-canvas');const cv=document.createElement('canvas');const get=cv.getContext.bind(cv);let proxy;
  cv.getContext=kind=>{assert(kind==='2d','Source context must be 2d');if(proxy)return proxy;const context=get(kind);assert(context,'Native Canvas2D unavailable');const measurements=[],draws=[];traces.set(cv,{measurements,draws});proxy=new Proxy(context,{get(target,key){const value=Reflect.get(target,key,target);if(typeof value!=='function')return value;return(...args)=>{const result=value.apply(target,args);if(key==='measureText')measurements.push({text:String(args[0]),font:target.font,width:result.width,actualBoundingBoxLeft:result.actualBoundingBoxLeft,actualBoundingBoxRight:result.actualBoundingBoxRight,actualBoundingBoxAscent:result.actualBoundingBoxAscent,actualBoundingBoxDescent:result.actualBoundingBoxDescent});if(key==='fillText'||key==='strokeText'){const probe=document.createElement('span');probe.id='source-font-'+document.querySelectorAll('[data-source-font]').length;probe.dataset.sourceFont='true';probe.style.font=target.font;probe.style.whiteSpace='pre';probe.textContent=String(args[0]);document.getElementById('font-probes').append(probe);draws.push({operation:key,text:String(args[0]),font:target.font,args:args.slice(1),align:target.textAlign,baseline:target.textBaseline,probeId:probe.id});}return result;};},set(target,key,value){return Reflect.set(target,key,value,target);}});return proxy;};return cv;}};
}
function sampler(texture){return {colorSpace:texture.colorSpace,flipY:texture.flipY,generateMipmaps:texture.generateMipmaps,minFilter:texture.minFilter,magFilter:texture.magFilter,wrapS:texture.wrapS,wrapT:texture.wrapT,anisotropy:texture.anisotropy,mapping:texture.mapping,repeat:texture.repeat.toArray(),offset:texture.offset.toArray()};}
function instantiate(source,doc){
 const recipes=source.recipes;
 const encountered=[],materialSeen=new Set(),textureSeen=new Set();
 const inspect=scene=>scene.traverse(object=>{for(const material of object.material?(Array.isArray(object.material)?object.material:[object.material]):[]){if(materialSeen.has(material))continue;materialSeen.add(material);for(const value of Object.values(material))if(value?.isTexture&&!textureSeen.has(value)){textureSeen.add(value);encountered.push(value);}}});
 // Exact original source statements, same scope/prerequisites as accepted CPU oracle.
 const code=recipes.scalarConstants.code+recipes.layout.code+recipes.surfaceTextures.code+';const jail=({'+recipes.jailSnapshot.code+'}).jail;let originalCanal;{'+recipes.canalSnapshot.code+'originalCanal=canal;}const worldSnapshot={canal:originalCanal,landmarks:{jail}};'+recipes.box.code+recipes.outline.code+recipes.labelSprite.code+';const canal=worldSnapshot.canal,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;{'+recipes.bridge.code+'}inspect(scene);scene=new THREE.Scene();staticOutlineGeometries=[];{'+recipes.prison.code+'}inspect(scene);return encountered;';
 assert(!/new\s+(?:THREE\.)?WebGLRenderer\b|PMREMGenerator|\.render\s*\(/.test(code),'Source asks for renderer/prefilter');
 return new Function('THREE','document','renderer','scene','Math','originR','originC','WORLD_SCALE','batchStaticOutlines','staticOutlineGeometries','sharedOutlineMaterial','prisonAlarmBeacons','prisonReleaseGate','prisonReleaseGateLight','prisonVehicleLockGate','inspect','encountered',code)(THREE,doc,{capabilities:{getMaxAnisotropy:()=>16},domElement:{dataset:{}}},new THREE.Scene(),Math,source.originGridRC[0],source.originGridRC[1],4.1,true,[],new THREE.LineBasicMaterial({color:0x0a111b,transparent:true,opacity:.78}),[],null,null,null,inspect,encountered);
}
export async function capture(){
 assert(!busy,'Capture already active');busy=true;
 try{
  assert(THREE.REVISION==='180','Original Three180 required');
  const [sourceResponse,closureResponse]=await Promise.all([fetch('./source.json'),fetch('./closure.json')]);
  assert(sourceResponse.ok&&closureResponse.ok,'Prepared reviewed source files unavailable');
  const sourceBytes=await sourceResponse.arrayBuffer(),closureBytes=await closureResponse.arrayBuffer();
  assert(await hash(sourceBytes)===pins.source&&await hash(closureBytes)===pins.closure,'Frozen source/closure hash mismatch');
  const source=JSON.parse(new TextDecoder().decode(sourceBytes)),closure=JSON.parse(new TextDecoder().decode(closureBytes));
  for(const recipe of Object.values(source.recipes))assert(await hash(encoder.encode(recipe.code))===recipe.sha256,'Original recipe hash mismatch');
  document.getElementById('font-probes').replaceChildren();await document.fonts.ready;
  const doc=nativeDocument(),textures=instantiate(source,doc);assert(textures.length===38,'Original texture enumeration changed');
  const nextAssets=new Map(),slots=[];
  for(let index=0;index<textures.length;index++){
   const texture=textures[index],expected=closure.textures[index];assert(expected.id==='texture-'+index,'Source IDs changed');
   assert(canonical(sampler(texture))===canonical(expected.sampler),'Exact original sampler changed');
   const images=texture.isCubeTexture?texture.images:[texture.image];assert(images.length===expected.images.length,'Source image count changed');
   for(let ordinal=0;ordinal<images.length;ordinal++){
    const cv=images[ordinal],image=expected.images[ordinal],key=expected.id+'-image-'+ordinal;
    assert(cv instanceof HTMLCanvasElement&&cv.width===image.width&&cv.height===image.height,'Original Canvas dimensions changed');
    const data=cv.getContext('2d').getImageData(0,0,cv.width,cv.height);assert(data.colorSpace==='srgb'&&data.data instanceof Uint8ClampedArray,'Original sRGB RGBA8 readback required');
    const rgba=new Uint8Array(data.data.buffer.slice(data.data.byteOffset,data.data.byteOffset+data.data.byteLength));
    const blob=await new Promise(resolve=>cv.toBlob(resolve,'image/png'));assert(blob,'Native PNG encoder failed');const png=new Uint8Array(await blob.arrayBuffer());
    const trace=doc.traces.get(cv);assert(trace,'Canvas did not originate from original factory');
    slots.push({id:key,textureId:expected.id,ordinal,cubeFaceOrdinal:texture.isCubeTexture?ordinal:null,width:cv.width,height:cv.height,rgbaBytes:rgba.length,rgbaSha256:await hash(rgba),pngBytes:png.length,pngSha256:await hash(png),sourceRecipeSha256:image.sourceRecipeSha256,sourceRecipeKey:image.recipeKey,sourceSampler:expected.sampler,nativeFontMeasurements:trace.measurements,nativeTextDraws:trace.draws,platformFonts:null,fontBackendStatus:trace.draws.length?'HOLD_OWNER_CDP_PLATFORM_FONT_EVIDENCE':'NO_TEXT'});
    nextAssets.set(key,{rgba,png});
   }
  }
  assert(slots.length===43&&webglAttempts===0,'43 exact source slots/zero WebGL required');
  const receipt={schema:'original-landmark-canvas-browser-capture-v1',sourceManifestSha256:pins.source,sourceClosureSha256:pins.closure,originalSources:source.sourceReceipts,recipePins:Object.fromEntries(Object.entries(source.recipes).map(([key,value])=>[key,value.sha256])),threeRevision:'180',samplerCapabilityInput:16,slots,browser:{userAgent:navigator.userAgent,platform:navigator.platform,languages:navigator.languages,devicePixelRatio:devicePixelRatio,colorSpace:'srgb',fontBackendVersion:null},zeroWebGL:true,webglAttempts,ready:false,gates:['Owner coordinated browser/backend provenance','Actual platform-font backend and no substituted font evidence','Repeat all43 RGBA hashes on same backend','Original GPU mip/filter/anisotropy visual parity','Cube face orientation + original PMREM/native IBL acceptance','No gameowner authority admission']};
  receipt.canonicalSha256=await hash(encoder.encode(canonical(receipt)));assets=nextAssets;lastReceipt=receipt;return receipt;
 }finally{busy=false;}
}
export function receipt(){return lastReceipt;}
export function artifact(id,kind){assert(kind==='rgba'||kind==='png','Artifact kind refused');const entry=assets.get(id);assert(entry,'Unknown source slot');return entry[kind].slice();}
export function download(id,kind){const bytes=artifact(id,kind),url=URL.createObjectURL(new Blob([bytes],{type:kind==='png'?'image/png':'application/octet-stream'})),link=document.createElement('a');link.href=url;link.download=id+'.'+kind;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
window.landmarkCanvasCapture={capture,receipt,artifact,download,canonical};
