// READ-ONLY candidate experiment: no runtime picking implementation changed.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const ray=new T.Raycaster(new T.Vector3(0,0,5),new T.Vector3(0,0,-1),0,80);
const geometry=new T.BoxGeometry(),material=new T.MeshBasicMaterial(),resources=[];
const visible=o=>{for(let n=o;n;n=n.parent)if(n.visible===false)return false;return true;};
const accept=hit=>visible(hit.object)&&hit.object.userData?.mercenaryPickIgnore!==true;
const signature=hits=>hits.filter(accept).map(h=>[h.object.uuid,h.distance,h.faceIndex,h.instanceId,h.point.toArray()]);
const old=roots=>ray.intersectObjects(roots,true);
const candidate=roots=>ray.intersectObjects(roots.filter(visible),true);
const mesh=()=>new T.Mesh(geometry,material);
let parityCases=0;
function same(roots){assert.deepEqual(signature(candidate(roots)),signature(old(roots)));parityCases++;}

// Invisible roots/ancestors removed; accepted equal-distance order and duplicates preserved.
const first=mesh(),second=mesh(),hiddenRoot=new T.Group(),hiddenChild=mesh(),hiddenAncestor=new T.Group(),visibleRoot=mesh();
hiddenRoot.visible=false;hiddenRoot.add(hiddenChild);hiddenAncestor.visible=false;hiddenAncestor.add(visibleRoot);
for(const node of [first,second,hiddenRoot,hiddenAncestor])node.updateMatrixWorld(true);
same([hiddenRoot,first,visibleRoot,second,first]);

// Root-only filtering deliberately retains invisible children in a visible root.
const parent=new T.Group(),child=mesh();child.visible=false;parent.add(child,mesh());parent.updateMatrixWorld(true);same([parent]);
assert.equal(old([parent]).length,candidate([parent]).length,'root-only filter is not branch pruning');

// Parent layers mismatch does NOT prune matching descendants in Three.
parent.layers.set(1);same([parent]);assert(candidate([parent]).some(hit=>hit.object===parent.children[1]));

// Preserve recursive raycast=false stop semantics on visible custom roots.
const stopper=new T.Group();stopper.raycast=()=>false;stopper.add(mesh());stopper.updateMatrixWorld(true);same([stopper]);assert.equal(candidate([stopper]).length,0);
stopper.layers.set(1);same([stopper]);assert(candidate([stopper]).length>0,'layer mismatch bypasses own raycast=false, not children');

// Canonical material-hidden sources still supply picking: do not filter materials.
const source=mesh();source.material=material.clone();resources.push(source.material);source.material.visible=false;source.updateMatrixWorld(true);same([source]);assert(candidate([source]).length>0);

// Ignore is hit-only, not inherited; an ignored parent can have targetable descendants.
const ignored=new T.Group();ignored.userData.mercenaryPickIgnore=true;ignored.add(mesh());ignored.updateMatrixWorld(true);same([ignored]);assert(signature(candidate([ignored])).length>0);

// Filtering must not refresh stale matrices, which would change old picking behavior.
first.position.x=100;same([first,second]);assert(candidate([first]).length>0,'position changed but matrixWorld deliberately remains old');

// Bounded operation count, not a timing/FPS claim: standard hidden NPC-like roots.
let oldCalls=0,newCalls=0,counting='old';const npcRoots=[];
for(let i=0;i<72;i++){const root=new T.Group();root.visible=i<12;for(let j=0;j<2;j++){const part=mesh(),original=part.raycast;part.raycast=function(...args){if(counting==='old')oldCalls++;else newCalls++;return original.apply(this,args)};root.add(part);}root.updateMatrixWorld(true);npcRoots.push(root);}
const baseline=signature(old(npcRoots));counting='new';assert.deepEqual(signature(candidate(npcRoots)),baseline);assert.equal(oldCalls,144);assert.equal(newCalls,24);

// Counterexample: generic custom raycast can emit hits belonging outside its subtree.
const hiddenCustom=new T.Group(),external=mesh();hiddenCustom.visible=false;
hiddenCustom.raycast=(_ray,hits)=>hits.push({object:external,distance:1,point:new T.Vector3()});
assert.notDeepEqual(signature(old([hiddenCustom])),signature(candidate([hiddenCustom])));

// Counterexample: raycast side effects can change post-intersection visibility.
const selfShowing=new T.Group(),selfChild=mesh();selfShowing.visible=false;selfShowing.add(selfChild);
selfShowing.raycast=()=>{selfShowing.visible=true;};selfShowing.updateMatrixWorld(true);
const oldSelf=signature(old([selfShowing]));selfShowing.visible=false;const newSelf=signature(candidate([selfShowing]));
assert(oldSelf.length>0&&newSelf.length===0);

for(const resource of resources)resource.dispose();geometry.dispose();material.dispose();
console.log(JSON.stringify({parityCases,standardHiddenRootRaycasts:{before:oldCalls,after:newCalls},genericCounterexamples:2,scope:'actual Three CPU fixture; no production edit, no timing/FPS assertion'}));
