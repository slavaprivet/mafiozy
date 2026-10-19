import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createWalkMapEditorSelectionVisual,WALK_MAP_EDITOR_SELECTION_COLORS} from './walk_map_editor_selection_visual.mjs';

class Color{constructor(value){this.value=value}set(value){this.value=value}}
class Matrix4{constructor(tx=0){this.tx=tx}copy(other){this.tx=other.tx;return this}invert(){this.tx=-this.tx;return this}multiplyMatrices(a,b){this.tx=a.tx+b.tx;return this}}
class Box3{
 constructor(min=Infinity,max=-Infinity){this.minX=min;this.maxX=max}makeEmpty(){this.minX=Infinity;this.maxX=-Infinity;return this}isEmpty(){return this.minX>this.maxX}copy(other){this.minX=other.minX;this.maxX=other.maxX;return this}applyMatrix4(matrix){if(!this.isEmpty()){this.minX+=matrix.tx;this.maxX+=matrix.tx}return this}union(other){if(!other.isEmpty()){this.minX=Math.min(this.minX,other.minX);this.maxX=Math.max(this.maxX,other.maxX)}return this}setFromObject(root){if(root.fallbackBounds)this.copy(root.fallbackBounds);return this}}
class Box3Helper{constructor(box,color){this.box=box;this.material={color:new Color(color),dispose(){this.disposed=true}};this.geometry={dispose(){this.disposed=true}};this.visible=true;this.updateCount=0}updateMatrixWorld(){this.updateCount++}}
const THREE={Box3,Box3Helper,Color,Matrix4},scene={children:[],add(node){this.children.push(node)},remove(node){this.children=this.children.filter(item=>item!==node)}};
function rootWithChildren(count){
 const root={isObject3D:true,visible:true,position:{x:10},matrixWorld:new Matrix4(),children:[],deepUpdates:0,shallowUpdates:0,traversals:0};
 for(let i=0;i<count;i++)root.children.push({matrixWorld:new Matrix4(),localX:i,geometry:{boundingBox:new Box3(0,1)}});
 root.updateWorldMatrix=(_parents,children)=>{children?root.deepUpdates++:root.shallowUpdates++;root.matrixWorld.tx=root.position.x;if(children)for(const child of root.children)child.matrixWorld.tx=root.position.x+child.localX};
 root.traverse=callback=>{root.traversals++;callback(root);for(const child of root.children)callback(child)};return root;
}

const visual=createWalkMapEditorSelectionVisual({THREE,scene});assert.equal(scene.children.length,1);assert.equal(visual.helper.visible,false);assert.equal(visual.helper.material.depthTest,false);
const house=rootWithChildren(1000);assert.equal(visual.select(house),true);assert.equal(visual.box.minX,10);assert.equal(visual.box.maxX,1010);assert.equal(house.traversals,1);assert.equal(house.deepUpdates,1);
assert.equal(visual.helper.material.color.value,WALK_MAP_EDITOR_SELECTION_COLORS.normal);assert.equal(visual.select(house,{isLocked:true}),true);assert.equal(house.traversals,1,'reselect must reuse local bounds');assert.equal(visual.helper.material.color.value,WALK_MAP_EDITOR_SELECTION_COLORS.locked);
assert.equal(visual.setPreviewing(true),true);assert.equal(visual.helper.material.color.value,WALK_MAP_EDITOR_SELECTION_COLORS.preview);
const hotStarted=performance.now();for(let i=0;i<2000;i++){house.position.x=20+i*.01;assert.equal(visual.update(),true)}const hotElapsed=performance.now()-hotStarted;
assert.equal(house.traversals,1,'pointer-move updates must not traverse descendants');assert.equal(house.deepUpdates,1);assert.ok(house.shallowUpdates>=2000);assert.equal(visual.diagnostics().cacheBuilds,1);assert.equal(visual.diagnostics().deepVisits,1001);
assert.equal(visual.invalidate(house),true);assert.equal(visual.update(),true);assert.equal(house.traversals,2);assert.equal(visual.diagnostics().cacheBuilds,2);
house.visible=false;assert.equal(visual.update(),false);assert.equal(visual.helper.visible,false);house.visible=true;
const empty=rootWithChildren(0);assert.equal(visual.select(empty),false);visual.clear();assert.equal(visual.selected,null);assert.equal(visual.select(null),false);
const helper=visual.helper;visual.dispose();visual.dispose();assert.equal(scene.children.length,0);assert.equal(helper.geometry.disposed,true);assert.equal(helper.material.disposed,true);assert.equal(visual.select(house),false);assert.equal(visual.update(),false);
export const selectionVisualBenchmark=Object.freeze({descendants:1000,updates:2000,hotElapsed,traversals:house.traversals,deepUpdates:house.deepUpdates});
console.log('walk map editor selection visual: PASS');
