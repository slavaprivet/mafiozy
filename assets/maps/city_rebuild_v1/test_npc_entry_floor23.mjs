import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
const report={comparisons:0,maxError:0,geometryInvalidations:0};
const states=new WeakMap();
globalThis.entryFloorBefore23=c=>{
 let state=states.get(c.object);if(!state){state={calls:0};states.set(c.object,state);}state.calls++;
 // Versioned geometry edits invalidate cached bounds, including a sole that
 // moves below its old box. This touches only the disposable actual test clone.
 if(state.calls===2){
  const point=c.object.position.clone();let lowest=Infinity,chosen=null;
  c.scene.traverse(mesh=>{if(!mesh.isMesh)return;const attr=mesh.geometry.attributes.position;if(!attr)return;if(mesh.isSkinnedMesh)mesh.skeleton.update();for(let i=0;i<attr.count;i++){point.fromBufferAttribute(attr,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld);if(point.y<lowest){lowest=point.y;chosen={attr,i};}}});
  chosen.attr.setY(chosen.i,chosen.attr.getY(chosen.i)-.002);chosen.attr.needsUpdate=true;report.geometryInvalidations++;
 }
};
globalThis.entryFloorCompare23=(cached,oracle)=>{const error=Math.abs(cached-oracle);report.comparisons++;report.maxError=Math.max(report.maxError,error);assert(error<1e-7,'cached exact floor differs from native full vertex scan: '+error);};
registerHooks({load(url,ctx,next){const result=next(url,ctx);if(!url.endsWith('/npc_locomotion_pose.mjs'))return result;const source=String(result.source),needle='if(entryAge>0){entryFloor();c.object.updateMatrixWorld(true);}';assert(source.includes(needle),'exercise current production floor gate');return{...result,source:source.replace(needle,`if(entryAge>0){globalThis.entryFloorBefore23(c);const before=c.visualPivot.position.y;entryFloor();const cached=c.visualPivot.position.y;c.object.updateMatrixWorld(true);c.groundPose();globalThis.entryFloorCompare23(cached,Math.max(before,c.visualPivot.position.y));c.visualPivot.position.y=cached;c.object.updateMatrixWorld(true);}`)};}});
await import('./test_npc_walk_board_entry23.mjs');
assert(report.comparisons>=256);assert.equal(report.geometryInvalidations,64);
fs.writeFileSync(new URL('../../../outputs/npc_entry_floor23_oracle.json',import.meta.url),JSON.stringify(report,null,2));console.log(report);
