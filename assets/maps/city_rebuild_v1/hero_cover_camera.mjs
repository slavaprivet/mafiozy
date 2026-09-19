// View the exposed side while preserving the player's aim direction.
export function coverCameraShoulder(cover,forward,side=1){
 if(!cover)return 0;const length=Math.hypot(forward.x,forward.z);if(length<.001)return 0;
 const lateral=(-cover.tangent.x*forward.z+cover.tangent.z*forward.x)*(side<0?-1:1)/length;
 return Math.abs(lateral)<.12?0:Math.sign(lateral)*.48;
}
