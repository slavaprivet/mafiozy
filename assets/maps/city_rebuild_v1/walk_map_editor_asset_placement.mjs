import {makeWalkMapObjectAddCommand} from './walk_map_editor_document.mjs';

function clone(value){return value===undefined?undefined:structuredClone(value);}
function finite(value){return typeof value==='number'&&Number.isFinite(value);}
function plainObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function normalizeTransform(value={}){
 const positionM=value.positionM||[0,0,0],horizontalScale=value.horizontalScale||[1,1],modelLocalOffsetM=value.modelLocalOffsetM||[0,0,0],result={positionM:[...positionM],yawDegrees:value.yawDegrees??0,uniformScale:value.uniformScale??1,horizontalScale:[...horizontalScale],modelLocalOffsetM:[...modelLocalOffsetM],preserveSiteBounds:value.preserveSiteBounds===true};
 if(result.positionM.length!==3||!result.positionM.every(finite)||!finite(result.yawDegrees)||!finite(result.uniformScale)||result.uniformScale<=0||result.horizontalScale.length!==2||!result.horizontalScale.every(item=>finite(item)&&item>0)||result.modelLocalOffsetM.length!==3||!result.modelLocalOffsetM.every(finite))throw new Error('Invalid asset placement transform');
 return result;
}
function applyTransform(root,transform){
 root.position?.fromArray?.(transform.positionM);if(root.position&&!root.position.fromArray){root.position.x=transform.positionM[0];root.position.y=transform.positionM[1];root.position.z=transform.positionM[2]}
 if(root.rotation)root.rotation.y=transform.yawDegrees*Math.PI/180;
 const sx=transform.uniformScale*transform.horizontalScale[0],sy=transform.uniformScale,sz=transform.uniformScale*transform.horizontalScale[1];if(root.scale?.set)root.scale.set(sx,sy,sz);else if(root.scale){root.scale.x=sx;root.scale.y=sy;root.scale.z=sz}
 if(root.updateWorldMatrix)root.updateWorldMatrix(true,false);else root.updateMatrixWorld?.(true);
}
function trustedAssetBinding(asset){
 if(asset?.available!==true)throw new Error(asset?.available===false&&asset?.reason?asset.reason:'Asset is unavailable');
 if(typeof asset.key!=='string'||!asset.key||typeof asset.assetId!=='string'||!asset.assetId)throw new Error('Asset has no stable palette key');
 const binding=asset.binding;if(!binding?.url||!/^[a-f0-9]{64}$/i.test(binding.sha256||''))throw new Error('Asset has no trusted model binding');return clone(binding);
}
function normalizeDependencies(value){
 if(!Array.isArray(value)||value.some(item=>typeof item!=='string'||!item.trim()))throw new Error('Trusted asset compiler returned invalid dependencies');
 return [...new Set(value.map(item=>item.trim()))];
}
function normalizeId(value){
 if(typeof value!=='string'||!value.trim()||value.trim().length>512||/[\u0000-\u001f]/.test(value))throw new Error('Trusted asset compiler returned an invalid object id');return value.trim();
}

export function createWalkMapAssetPlacement({scene,loadTemplate,cloneTemplate=template=>template.clone(true),compileRecord,idFactory=()=>globalThis.crypto?.randomUUID?.()??`custom-${Date.now().toString(36)}`,idExists=()=>false,groundHeight=()=>0,onPreview=()=>{},onCancel=()=>{}}={}){
 if(!scene?.add||!scene?.remove||typeof loadTemplate!=='function'||typeof cloneTemplate!=='function')throw new Error('Asset placement requires a scene and model loader');
 if(typeof compileRecord!=='function')throw new Error('Trusted asset record compiler is required');
 if(typeof idFactory!=='function'||typeof idExists!=='function')throw new Error('Asset placement requires trusted id providers');
 const templates=new Map(),issuedIds=new Set();let preview=null,pending=null,committing=null,disposed=false,epoch=0;
 function active(){if(disposed)throw new Error('Asset placement is disposed');}
 function templateFor(asset,binding){
  const key=binding.sha256.toLowerCase();if(templates.has(key))return templates.get(key);
  const request=Promise.resolve().then(()=>loadTemplate(clone(binding),clone(asset))).then(template=>{if(!template||typeof template!=='object')throw new Error('Asset template loader returned no model');return template});templates.set(key,request);request.catch(()=>{if(templates.get(key)===request)templates.delete(key)});return request;
 }
 function placeOnGround(transform,asset){const height=groundHeight(transform.positionM[0],transform.positionM[2],clone(asset));if(height===null||height===undefined)return transform;if(!finite(height))throw new Error('Ground height must be a finite number');transform.positionM[1]=height;return transform;}
 function notifyCancelled(value,reason,isPending=false){onCancel({asset:clone(value.asset),root:value.root||null,reason,pending:isPending});}
 function cancel(reason='cancel'){
  const oldPending=pending,oldPreview=preview;if(!oldPending&&!oldPreview)return false;epoch++;pending=null;preview=null;committing=null;
  if(oldPreview){scene.remove(oldPreview.root);notifyCancelled(oldPreview,reason,false)}
  if(oldPending)notifyCancelled(oldPending,reason,true);
  return true;
 }
 async function begin(asset,{positionM=[0,0,0],yawDegrees=0,uniformScale=1,horizontalScale=[1,1],modelLocalOffsetM=[0,0,0],preserveSiteBounds=false}={}){
  active();const binding=trustedAssetBinding(asset);cancel('replace');const ticket=++epoch;pending={ticket,asset:clone(asset),root:null};let template;
  try{template=await templateFor(asset,binding)}catch(error){if(disposed||ticket!==epoch)return null;if(pending?.ticket===ticket)pending=null;throw error}
  if(disposed||ticket!==epoch||pending?.ticket!==ticket)return null;pending=null;
  let root,added=false;
  try{
   root=cloneTemplate(template,asset);if(!root||typeof root!=='object')throw new Error('Asset template clone returned no model');
   const transform=placeOnGround(normalizeTransform({positionM,yawDegrees,uniformScale,horizontalScale,modelLocalOffsetM,preserveSiteBounds}),asset);applyTransform(root,transform);root.userData={...(root.userData||{}),walkMapEditorPreview:true,editorAssetKey:asset.key};added=true;scene.add(root);preview={asset:clone(asset),root,transform};onPreview({asset:clone(preview.asset),root,transform:clone(transform)});return root;
  }catch(error){if(added)scene.remove(root);if(preview?.root===root)preview=null;epoch++;throw error}
 }
 function update(changes={}){
  active();if(!preview)throw new Error('No asset placement preview');if(committing)throw new Error('Asset placement commit is in progress');
  const next=normalizeTransform({...preview.transform,...clone(changes)});if(changes.positionM)placeOnGround(next,preview.asset);applyTransform(preview.root,next);preview.transform=next;onPreview({asset:clone(preview.asset),root:preview.root,transform:clone(next)});return clone(next);
 }
 function rejectPreview(current,reason){if(preview!==current)return;preview=null;committing=null;epoch++;scene.remove(current.root);notifyCancelled(current,reason,false);}
 async function commit({metadata={}}={}){
  active();if(!preview)throw new Error('No asset placement preview');if(committing)throw new Error('Asset placement commit is already in progress');
  const current=preview,ticket=epoch;committing=current;let compiled;
  try{compiled=await compileRecord({asset:clone(current.asset),transform:clone(current.transform)})}catch(error){if(disposed||ticket!==epoch||preview!==current)throw new Error('Asset placement commit was cancelled');rejectPreview(current,'compile-reject');throw error}
  if(disposed||ticket!==epoch||preview!==current){if(committing===current)committing=null;throw new Error('Asset placement commit was cancelled')}
  try{
   if(!compiled?.ok||!plainObject(compiled.record))throw new Error(compiled?.message||compiled?.code||'Asset placement did not pass trusted compilation');
   const dependencies=normalizeDependencies(compiled.dependencies),record=clone(compiled.record);if(record.assetId!==undefined&&record.assetId!==current.asset.assetId)throw new Error('Trusted asset compiler changed the asset id');record.assetId=current.asset.assetId;record.transform=normalizeTransform(record.transform||current.transform);
   const id=normalizeId(record.id??idFactory(clone(current.asset),clone(record)));if(issuedIds.has(id)||idExists(id,clone(current.asset)))throw new Error(`Duplicate asset placement id: ${id}`);record.id=id;
   const source={dataset:compiled.dataset||'custom',id,sourceFile:compiled.sourceFile||'walk-map-editor'},command=makeWalkMapObjectAddCommand({source,object:record,metadata:{...clone(metadata),assetKey:current.asset.key,assetId:current.asset.assetId,adapter:'trusted-asset-placement-v1',dependencies:[...dependencies]}});
   preview=null;committing=null;epoch++;scene.remove(current.root);issuedIds.add(id);return {command,record,source,dependencies:[...dependencies],root:current.root};
  }catch(error){rejectPreview(current,'compile-reject');throw error}
 }
 return {
  get preview(){return preview?{asset:clone(preview.asset),transform:clone(preview.transform),root:preview.root}:null},get loading(){return !!pending||!!committing},
  begin,update,commit,cancel,
  dispose(){if(disposed)return;try{cancel('dispose')}finally{disposed=true;epoch++;pending=null;committing=null;templates.clear()}},
  diagnostics(){return {disposed,loading:!!pending,committing:!!committing,preview:!!preview,cachedTemplates:templates.size,issuedIds:issuedIds.size}}
 };
}
