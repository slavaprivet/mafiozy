import assert from 'node:assert/strict';
import {coverCameraShoulder} from './hero_cover_camera.mjs';
for(const yaw of [0,.73,-1.9])for(const winding of [-1,1]){
 const forward={x:Math.sin(yaw),z:Math.cos(yaw)},tangent={x:-forward.z*winding,z:forward.x*winding};
 for(const side of [-1,1])assert.equal(coverCameraShoulder({tangent},forward,side),side*winding*.48,'view follows actual exposed side independently of winding/yaw');
}
assert.equal(coverCameraShoulder(null,{x:0,z:1}),0);assert.equal(coverCameraShoulder({tangent:{x:1,z:0}},{x:0,z:0}),0);console.log('PASS cover camera shoulders: both corners, reversed winding, world yaw, vertical view');
