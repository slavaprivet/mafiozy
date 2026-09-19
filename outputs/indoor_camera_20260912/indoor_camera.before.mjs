// Preserve the user's orbit separately. Collision compression switches to an
// unobstructed eye view instead of filling the viewport with the avatar's head.
export function createIndoorCamera({THREE:T,resolvePosition}){
 let closeView=false;
 function reset(){closeView=false}
 function solve({feet,eyeHeight=1.64,desired,target,objects,ceilingY=Infinity,inside=false,aiming=false}){
  const eye=feet.clone().add(new T.Vector3(0,eyeHeight,0));
  if(Number.isFinite(ceilingY))eye.y=Math.min(eye.y,ceilingY-.25);
  const origin=feet.clone().add(new T.Vector3(0,Math.min(eyeHeight,1.45),0));
  const position=resolvePosition({THREE:T,from:origin,desired,objects,ceilingY:aiming?Infinity:ceilingY});
  const separation=Math.hypot(position.x-feet.x,position.z-feet.z);
  if(!inside){closeView=false;return{position,target:aiming?target.clone().add(position.clone().sub(desired)):target.clone(),hideHead:false,mode:'orbit'}}
  // Hysteresis avoids alternation at a stair post or a doorway edge.
  closeView=closeView?separation<3.4:separation<2.8;
  if(!closeView)return{position,target:aiming?target.clone().add(position.clone().sub(desired)):target.clone(),hideHead:false,mode:'orbit'};
  const forward=target.clone().sub(desired).normalize();
  if(forward.lengthSq()<.5)forward.set(0,0,1);
  // Eye position remains within the player's validated capsule. The view uses
  // the original orbit direction, never the upward ray from a compressed boom.
  return{position:eye,target:eye.clone().addScaledVector(forward,5),hideHead:true,mode:'eye'};
 }
 return{solve,reset,get closeView(){return closeView}};
}
