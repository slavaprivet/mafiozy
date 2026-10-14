const NORMAL_COLOR=0xf0c86e;
const LOCKED_COLOR=0xe06c5f;
const PREVIEW_COLOR=0x78d7a8;

function validRoot(root){return !!root&&typeof root==='object'&&root.isObject3D===true;}

export function createWalkMapEditorSelectionVisual({THREE,scene,normalColor=NORMAL_COLOR,lockedColor=LOCKED_COLOR,previewColor=PREVIEW_COLOR}={}){
 if(!THREE?.Box3||!THREE?.Box3Helper||!THREE?.Color||!THREE?.Matrix4||!scene?.add||!scene?.remove)throw new Error('Selection visual requires THREE Box3/Box3Helper/Color/Matrix4 and a scene');
 const box=new THREE.Box3(),scratch=new THREE.Box3(),inverse=new THREE.Matrix4(),relative=new THREE.Matrix4(),helper=new THREE.Box3Helper(box,normalColor),cache=new WeakMap();let selected=null,locked=false,previewing=false,disposed=false,cacheBuilds=0,updates=0,deepVisits=0;
 helper.name='WalkMapEditorSelection';helper.visible=false;helper.renderOrder=10000;helper.frustumCulled=false;
 if(helper.material){helper.material.depthTest=false;helper.material.depthWrite=false;helper.material.transparent=true;helper.material.opacity=.92;}
 scene.add(helper);
 function applyColor(){const value=previewing?previewColor:locked?lockedColor:normalColor;if(helper.material?.color?.set)helper.material.color.set(value);else helper.material.color=new THREE.Color(value);}
 function geometryBounds(node){
  if(node?.isInstancedMesh||node?.isSkinnedMesh){node.computeBoundingBox?.();if(node.boundingBox&&!node.boundingBox.isEmpty?.())return node.boundingBox}
  const geometry=node?.geometry;if(!geometry)return null;if(!geometry.boundingBox)geometry.computeBoundingBox?.();return geometry.boundingBox||null;
 }
 function buildLocalBounds(root){
  const local=new THREE.Box3().makeEmpty();root.updateWorldMatrix?.(true,true);if(!root.matrixWorld)return local;inverse.copy(root.matrixWorld).invert();
  root.traverse?.(node=>{deepVisits++;const bounds=geometryBounds(node);if(!bounds||bounds.isEmpty?.())return;relative.multiplyMatrices(inverse,node.matrixWorld);scratch.copy(bounds).applyMatrix4(relative);local.union(scratch)});
  if(local.isEmpty()&&typeof local.setFromObject==='function'){local.setFromObject(root,true);if(!local.isEmpty())local.applyMatrix4(inverse)}cache.set(root,local);cacheBuilds++;return local;
 }
 function update(){
  if(disposed||!selected||selected.visible===false){helper.visible=false;return false}const local=cache.get(selected)||buildLocalBounds(selected);if(local.isEmpty()){helper.visible=false;return false}
  selected.updateWorldMatrix?.(true,false);if(!selected.matrixWorld){helper.visible=false;return false}box.copy(local).applyMatrix4(selected.matrixWorld);const empty=box.isEmpty();helper.visible=!empty;if(!empty){updates++;helper.updateMatrixWorld?.(true)}return !empty;
 }
 function select(root,{isLocked=false,isPreview=false,geometryChanged=false}={}){
  if(disposed)return false;selected=validRoot(root)?root:null;if(geometryChanged&&selected)cache.delete(selected);locked=!!isLocked;previewing=!!isPreview;applyColor();return update();
 }
 function clear(){selected=null;locked=false;previewing=false;helper.visible=false;box.makeEmpty();applyColor();}
 function setPreviewing(value){previewing=!!value;applyColor();return update();}
 function invalidate(root=selected){if(!root)return false;const removed=cache.delete(root);if(root===selected)helper.visible=false;return removed;}
 function dispose(){if(disposed)return;disposed=true;clear();scene.remove(helper);helper.geometry?.dispose?.();helper.material?.dispose?.();}
 return {helper,box,get selected(){return selected},get locked(){return locked},get previewing(){return previewing},select,update,clear,setPreviewing,invalidate,diagnostics:()=>Object.freeze({cacheBuilds,updates,deepVisits,cachedSelected:!!selected&&cache.has(selected)}),dispose};
}

export const WALK_MAP_EDITOR_SELECTION_COLORS=Object.freeze({normal:NORMAL_COLOR,locked:LOCKED_COLOR,preview:PREVIEW_COLOR});
