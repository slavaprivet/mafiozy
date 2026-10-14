import {createWalkMapEditorRuntime} from './walk_map_editor_runtime.mjs';
import {createWalkMapEditorCamera} from './walk_map_editor_camera.mjs';
import {createWalkMapEditorGeneratedPreview} from './walk_map_editor_generated_preview.mjs';

function asPromise(value){return Promise.resolve(value);}

export function createWalkMapEditorWalkHost({
 THREE,renderer,scene,camera,controls,adapter,placement=null,explorationPlacement=null,surface=null,groundOverlayPreview=null,selectionVisual=null,generatedPreview=null,palette=()=>[],
 getPickRoots=()=>[],groundHeight=()=>0,prepareCommands,prepareSurfaceStroke=null,commitCommands,undo,redo,save,files,
 catalogOpen=null,catalogClose=null,catalogRetry=null,catalogCategory=null,catalogDispose=null,
 releaseControls=()=>{},enterGameEditor=()=>{},leaveGameEditor=()=>{},requestRebuild=()=>{},
 initialBrushRadiusM=2.05,minBrushRadiusM=.25,maxBrushRadiusM=98.4,defaultSurfaceMaterialId='grass',metresPerCell=4.1,
 document:doc=globalThis.document,parent=doc?.body,target=globalThis.window,
 createRuntime=createWalkMapEditorRuntime,createCamera=createWalkMapEditorCamera,createGeneratedPreview=createWalkMapEditorGeneratedPreview
}={}){
 if(!THREE||!renderer?.domElement||!scene||!camera||!controls||!adapter?.enumerate)throw new Error('Walk editor host requires the live THREE scene, camera, controls and adapter');
 if(typeof prepareCommands!=='function')throw new Error('Walk editor host requires a trusted prepareCommands callback');
 if(typeof commitCommands!=='function')throw new Error('Walk editor host requires an authoritative commitCommands callback');
 if(!Number.isFinite(initialBrushRadiusM)||!Number.isFinite(minBrushRadiusM)||!Number.isFinite(maxBrushRadiusM)||minBrushRadiusM<=0||minBrushRadiusM>maxBrushRadiusM)throw new Error('Walk editor host brush bounds are invalid');
 if(!Number.isFinite(metresPerCell)||metresPerCell<=0)throw new Error('Walk editor host cell size is invalid');
 const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),groundPlane=new THREE.Plane(new THREE.Vector3(0,1,0),0),groundPointValue=new THREE.Vector3();
 const mapBounds=()=>{const map=adapter.mapBounds?.();return map||{minX:0,minZ:0,maxX:738,maxZ:820}};
 const editorCamera=createCamera({THREE,camera,controls,bounds:mapBounds(),groundHeight});
 const canDrawGeneratedPreview=THREE.Group&&THREE.BufferGeometry&&THREE.BufferAttribute&&THREE.LineBasicMaterial&&THREE.LineLoop&&scene.add&&scene.remove;
 const generatedSemanticPreview=generatedPreview===false?null:generatedPreview||(canDrawGeneratedPreview&&typeof adapter.transformCommand==='function'?createGeneratedPreview({THREE,scene,adapter,groundHeight}):null);
 let runtime=null,dragKey=null,disposed=false,disposing=false,disposePromise=null,entered=false,gameEntered=false,enterPromise=null,leavePromise=null;
 let lastSemanticHit=null;
 let brushRadiusM=Math.min(maxBrushRadiusM,Math.max(minBrushRadiusM,initialBrushRadiusM)),paintMaterialId=defaultSurfaceMaterialId;

 function rayFromEvent(event=null){
  const rect=renderer.domElement.getBoundingClientRect(),x=event?.clientX??rect.left+rect.width/2,y=event?.clientY??rect.top+rect.height/2;pointer.set((x-rect.left)/rect.width*2-1,-((y-rect.top)/rect.height)*2+1);raycaster.setFromCamera(pointer,camera);return raycaster;
 }
 function groundPoint(event=null){rayFromEvent(event);groundPlane.constant=0;if(!raycaster.ray.intersectPlane(groundPlane,groundPointValue))return null;groundPointValue.y=groundHeight(groundPointValue.x,groundPointValue.z)||0;return groundPointValue.clone();}
 function rememberSemanticHit(resolved){
  if(!resolved?.key)return;let proxy=resolved.proxy;
  if(!proxy)try{proxy=adapter.recordFor?.(resolved.key)?.proxy}catch{}
  lastSemanticHit=proxy?{key:resolved.key,proxy}:null;
 }
 function pick({event}={}){
  const intersections=rayFromEvent(event).intersectObjects(getPickRoots()||[],true);
  for(const intersection of intersections){const resolved=adapter.resolveIntersection?.(intersection);if(resolved){rememberSemanticHit(resolved);return {key:resolved.key,intersection,proxy:resolved.proxy||lastSemanticHit?.proxy||null}}}
  const point=groundPoint(event),resolved=point&&adapter.resolvePoint?.({x:point.x,z:point.z},{toleranceM:Math.max(.6,metresPerCell*.2)});if(!resolved)return null;rememberSemanticHit(resolved);return {key:resolved.key,intersection:{point,distance:resolved.distance,proxy:resolved.proxy||true},proxy:resolved.proxy||null};
 }
 function selectedRecord(){const key=runtime?.selection?.key;return key?adapter.recordFor?.(key):null;}
 function generatedPreviewArgs(key,item=runtime?.selection){
  if(!generatedSemanticPreview||!key)return null;let record=null;try{record=adapter.recordFor?.(key)}catch{return null}
  const proxy=lastSemanticHit?.key===key?lastSemanticHit.proxy:record?.proxy,args={key,item,record,proxy};return generatedSemanticPreview.recognizes?.(args)?args:null;
 }
 function beginGeneratedPreview(key,item,operation){
  const args=generatedPreviewArgs(key,item);if(!args)return null;if(!generatedSemanticPreview.canHandle?.({...args,operation}))return false;
  return !!generatedSemanticPreview.begin({...args,operation});
 }
 function syncSelectionVisual(item=runtime?.selection){
  if(!selectionVisual)return false;
  try{const root=item?.key?adapter.rootFor?.(item.key):null;if(!root){selectionVisual.clear?.();return false}return selectionVisual.select?.(root,{isLocked:!!item.locked,isPreview:!!selectionVisual.previewing})??false}catch{selectionVisual.clear?.();return false}
 }
 async function rebuild(meta){lastSemanticHit=null;selectionVisual?.invalidate?.();await asPromise(requestRebuild(meta));runtime?.refreshCatalog();syncSelectionVisual()}
 async function restoreAfterRejectedCommit(label,dependencies,error=null){selectionVisual?.setPreviewing?.(false);try{await rebuild({label,dependencies,rollback:true,error:error?.message||null})}catch(rebuildError){if(error)throw new AggregateError([error,rebuildError],`${label}: commit and recovery failed`);throw rebuildError}}
 async function commit(command,label,dependencies=[]){
  if(!command)return false;let prepared,preparedCommands,preparedDependencies=dependencies,result;
  try{prepared=await prepareCommands([command],{label,dependencies})}catch(error){await restoreAfterRejectedCommit(label,dependencies,error);throw error}
  if(Array.isArray(prepared))preparedCommands=prepared;
  else if(prepared&&Array.isArray(prepared.commands)){preparedCommands=prepared.commands;if(Array.isArray(prepared.dependencies))preparedDependencies=prepared.dependencies}
  if(!preparedCommands?.length){const error=new Error('Trusted command preparation rejected the edit');await restoreAfterRejectedCommit(label,dependencies,error);throw error}
  try{result=await commitCommands(preparedCommands,{label,dependencies:preparedDependencies})}catch(error){await restoreAfterRejectedCommit(label,preparedDependencies,error);throw error}
  if(result===false){await restoreAfterRejectedCommit(label,preparedDependencies);return false}
  selectionVisual?.setPreviewing?.(false);
  try{await rebuild({label,dependencies:preparedDependencies,committed:true})}catch(error){await restoreAfterRejectedCommit(label,preparedDependencies,error);throw error}
  return result??true;
 }
 async function historyMutation(callback,label){
  if(typeof callback!=='function')return false;let result;
  try{result=await asPromise(callback())}catch(error){await restoreAfterRejectedCommit(label,[],error);throw error}
  if(result===false)return false;
  try{await rebuild({label,dependencies:[],committed:true})}catch(error){await restoreAfterRejectedCommit(label,[],error);throw error}
  return result??true;
 }
 async function deleteObject({item,confirmed}){if(generatedSemanticPreview?.active)generatedSemanticPreview.cancel('delete');const command=adapter.deleteCommand(item.key);return commit(command,`Удалить: ${item.label}`,adapter.dependenciesFor?.(item.key)||[])}
 async function commitCurrent(){
  if(groundOverlayPreview?.active){const result=groundOverlayPreview.commit();return commit(result.command,'Добавить покрытие',result.dependencies)}
  if(explorationPlacement?.preview){const result=await explorationPlacement.commit();return commit(result.command,'Добавить procedural объект',result.dependencies)}
  if(placement?.preview){const result=await placement.commit();return commit(result.command,'Добавить объект',result.dependencies)}
  if(generatedSemanticPreview?.active){
   try{const result=await generatedSemanticPreview.commit();if(!result)return false;return commit(result.command,'Изменить процедурный объект',result.dependencies)}
   catch(error){selectionVisual?.setPreviewing?.(false);syncSelectionVisual();throw error}
  }
  const key=runtime?.selection?.key;if(!key||generatedPreviewArgs(key))return false;const command=adapter.commitPreview?.(key);return commit(command,'Изменить объект',adapter.dependenciesFor?.(key)||[]);
 }
 async function placeAsset(asset){
  if(asset?.placementMode==='paint'&&asset.materialId){paintMaterialId=asset.materialId;return {tool:'paint',materialId:paintMaterialId}}
  const point=groundPoint();if(!point)return false;
  if(asset?.placementMode==='exploration'){placement?.cancel('replace-with-exploration');const root=await explorationPlacement?.begin(asset,{positionM:[point.x,point.y,point.z]});return root?{tool:'place'}:false}
  explorationPlacement?.cancel('replace-with-authored');const root=await placement?.begin(asset,{positionM:[point.x,point.y,point.z]});return root?{tool:'place'}:false;
 }
 function overlayShape(point){return {type:'cells',cells:[[Math.floor(point.z/metresPerCell),Math.floor(point.x/metresPerCell)]]}}
 async function placeEditorAsset(asset){
  if(asset?.placementMode!=='overlay'){groundOverlayPreview?.cancel('replace-with-other-tool');return placeAsset(asset)}
  if(!groundOverlayPreview||!asset.materialId)return false;
  placement?.cancel('replace-with-ground-overlay');explorationPlacement?.cancel('replace-with-ground-overlay');
  const point=groundPoint();if(!point)return false;
  groundOverlayPreview.begin({materialId:asset.materialId,shape:overlayShape(point),groundHeightM:point.y});return {tool:'place',materialId:asset.materialId};
 }
 function cancel(reason='editor-cancel'){
  dragKey=null;if(surface?.active)surface.cancel(reason);groundOverlayPreview?.cancel(reason);placement?.cancel(reason);explorationPlacement?.cancel(reason);generatedSemanticPreview?.cancel(reason);
  if(adapter.cancelAllPreviews)adapter.cancelAllPreviews();else{const key=runtime?.selection?.key;if(key)adapter.cancelPreview?.(key)}selectionVisual?.setPreviewing?.(false);syncSelectionVisual();
 }
 function adjustBrush(name){
  const factor=name==='brush-larger'?1.25:.8;brushRadiusM=Math.min(maxBrushRadiusM,Math.max(minBrushRadiusM,brushRadiusM*factor));
  if(surface?.active)surface.setRadius(brushRadiusM);return true;
 }
 async function sceneAction(action,event,context){
  if(editorCamera.handleAction(action,event))return true;
  const name=action.action,tool=context.tool,key=context.selection?.key;
  if(name==='cancel-pointer'){cancel('pointer-cancel');return true}
  if(name==='primary-start'&&tool==='place'&&groundOverlayPreview?.active){const point=groundPoint(event);if(point)groundOverlayPreview.updateShape(overlayShape(point),{groundHeightM:point.y});return !!point}
  if(name==='primary-start'&&tool==='place'&&(placement?.preview||explorationPlacement?.preview)){const point=groundPoint(event);if(point)(explorationPlacement?.preview?explorationPlacement:placement).update({positionM:[point.x,point.y,point.z]});return !!point}
  if(name==='primary-start'&&['move','rotate'].includes(tool)&&key){const generated=beginGeneratedPreview(key,context.selection,tool);if(generated!==null){if(generated){dragKey=key;selectionVisual?.setPreviewing?.(true)}return generated}adapter.beginPreview?.(key);dragKey=key;selectionVisual?.setPreviewing?.(true);return true}
  if(name==='pointer-move'){
   const point=groundPoint(event);if(!point)return false;
   if(groundOverlayPreview?.active){groundOverlayPreview.updateShape(overlayShape(point),{groundHeightM:point.y});return true}
   if(explorationPlacement?.preview){explorationPlacement.update({positionM:[point.x,point.y,point.z]});return true}
   if(placement?.preview){placement.update({positionM:[point.x,point.y,point.z]});return true}
   if(dragKey&&tool==='move'){if(generatedSemanticPreview?.active&&generatedSemanticPreview.key===dragKey)generatedSemanticPreview.update({positionM:[point.x,point.y,point.z]});else{adapter.updatePreview?.(dragKey,{positionM:[point.x,point.y,point.z]});selectionVisual?.update?.()}return true}
  }
  if(name==='primary-end'){dragKey=null;if(tool==='place'&&(groundOverlayPreview?.active||explorationPlacement?.preview||placement?.preview))return commitCurrent();return true}
  if(name==='rotate-step'){
   if(explorationPlacement?.preview){explorationPlacement.update({yawDegrees:(explorationPlacement.preview.transform.yawDegrees||0)+action.degrees});return true}
   if(placement?.preview){placement.update({yawDegrees:(placement.preview.transform.yawDegrees||0)+action.degrees});return true}
   if(key){const generated=beginGeneratedPreview(key,context.selection,'rotate');if(generated!==null){if(!generated)return false;generatedSemanticPreview.rotate(action.degrees);selectionVisual?.setPreviewing?.(true);return true}adapter.beginPreview?.(key);const record=selectedRecord(),yaw=record?.transform?.yawDegrees||0;adapter.updatePreview?.(key,{yawDegrees:yaw+action.degrees});selectionVisual?.setPreviewing?.(true);selectionVisual?.update?.();return true}
  }
  if(name==='scale-smaller'||name==='scale-larger'){
   const factor=name==='scale-larger'?1.1:1/1.1;if(explorationPlacement?.preview){explorationPlacement.update({uniformScale:explorationPlacement.preview.transform.uniformScale*factor});return true}
   if(placement?.preview){placement.update({uniformScale:placement.preview.transform.uniformScale*factor});return true}
   if(key){if(generatedPreviewArgs(key,context.selection))return false;adapter.beginPreview?.(key);const record=selectedRecord(),scale=record?.transform?.uniformScale??1;adapter.updatePreview?.(key,{uniformScale:Math.max(.1,Math.min(10,scale*factor))});selectionVisual?.setPreviewing?.(true);selectionVisual?.update?.();return true}
  }
  if(name==='paint-start'||name==='erase-start'){
   const point=groundPoint(event);if(!point||!surface)return false;
   if(context.activeAsset?.materialId)paintMaterialId=context.activeAsset.materialId;
   surface.begin({x:point.x,z:point.z,materialId:paintMaterialId,mode:name==='erase-start'?'erase':'paint',radiusM:brushRadiusM});return true;
  }
  if(name==='paint-move'||name==='erase-move'){const point=groundPoint(event);if(point&&surface?.active)surface.move({x:point.x,z:point.z});return true}
  if(name==='paint-end'||name==='erase-end'){
   if(!surface?.active)return false;const raw=surface.finish(),label=name==='erase-end'?'Стереть покрытие':'Нарисовать покрытие';
   if(typeof prepareSurfaceStroke!=='function')return commit(raw,label,['topology','road-navigation','grass','minimap']);
   const prepared=await prepareSurfaceStroke(raw,{label});if(!prepared||prepared.changed===false)return false;return commit(prepared.command,label,prepared.dependencies||[]);
  }
  if(name==='brush-smaller'||name==='brush-larger')return adjustBrush(name);
  return false;
 }
 async function enterEditor({mode}){
  if(disposed||disposing)return false;if(enterPromise)return enterPromise;if(leavePromise)await leavePromise;if(entered){editorCamera.setMode(mode);return true}
  const task=(async()=>{
   await asPromise(releaseControls());gameEntered=true;
   try{await asPromise(enterGameEditor());if(disposed||disposing)return false;editorCamera.enter(mode);entered=true;return true}
   catch(error){
    const failures=[error];try{editorCamera.restore()}catch(cleanupError){failures.push(cleanupError)}
    try{await asPromise(leaveGameEditor())}catch(cleanupError){failures.push(cleanupError)}
    entered=false;gameEntered=false;if(failures.length>1)throw new AggregateError(failures,'Map editor entry and recovery failed');throw error;
   }
  })();
  enterPromise=task;try{return await task}finally{if(enterPromise===task)enterPromise=null}
 }
 async function leaveEditor(reason='leave'){
  if(leavePromise)return leavePromise;const pendingEnter=enterPromise;
  const task=(async()=>{if(pendingEnter)try{await pendingEnter}catch{};if(!entered&&!gameEntered)return true;cancel(reason);editorCamera.restore();await asPromise(leaveGameEditor());entered=false;gameEntered=false;return true})();
  leavePromise=task;try{return await task}finally{if(leavePromise===task)leavePromise=null}
 }

 runtime=createRuntime({document:doc,parent,target,canvas:renderer.domElement,adapter,hooks:{
  palette:()=>palette(),pick,enter:enterEditor,leave:({reason}={})=>leaveEditor(reason||'leave'),
  setMode:mode=>editorCamera.setMode(mode),placeAsset:placeEditorAsset,deleteObject,commit:commitCurrent,cancel,
  clearInput:reason=>{editorCamera.handleAction({action:'clear-input',reason});if(dragKey||surface?.active||groundOverlayPreview?.active||explorationPlacement?.preview||generatedSemanticPreview?.active)cancel(`clear-input:${reason||'unknown'}`)},
  selectionChanged:item=>{if(generatedSemanticPreview?.active&&generatedSemanticPreview.key!==item?.key)generatedSemanticPreview.cancel('selection-change');return syncSelectionVisual(item)},
  undo:()=>historyMutation(undo,'Отмена'),
  redo:()=>historyMutation(redo,'Повтор'),save:()=>save?.(),files:context=>files?.(context),sceneAction,
   historyState:()=>({canUndo:!!undo?.canUndo?.(),canRedo:!!redo?.canRedo?.()}),
   catalogOpen,catalogClose,catalogRetry,catalogCategory,catalogDispose
 }});
 return {runtime,camera:editorCamera,generatedPreview:generatedSemanticPreview,get brushRadiusM(){return brushRadiusM},get paintMaterialId(){return paintMaterialId},update(dt){if(!disposed&&!disposing&&runtime.active)editorCamera.update(dt)},pick,groundPoint,cancel,dispose(){
  if(disposePromise)return disposePromise;disposing=true;disposePromise=(async()=>{try{cancel('host-dispose');await runtime.dispose();await leaveEditor('host-dispose')}finally{editorCamera.dispose?.();selectionVisual?.dispose?.();placement?.dispose?.();explorationPlacement?.dispose?.();surface?.dispose?.();groundOverlayPreview?.dispose?.();generatedSemanticPreview?.dispose?.();adapter.dispose?.();disposed=true;disposing=false}})();return disposePromise;
 }};
}
