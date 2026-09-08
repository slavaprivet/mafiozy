import {movePedestrian} from './walk_motion.mjs';
export const JUMP=Object.freeze({flight:.8,recovery:.45,height:1.05,speed:6.5,radius:.36});
export const NORMAL_JUMP_SPEED=3.5;
export const DOUBLE_JUMP_WINDOW_MS=500;
export function jumpDirection(forward,input){
 const length=Math.hypot(forward.x,forward.z)||1,fx=forward.x/length,fz=forward.z/length;
 const ahead=Number(!!input.forward)-Number(!!input.back),side=Number(!!input.right)-Number(!!input.left);
 const x=fx*ahead-fz*side,z=fz*ahead+fx*side,n=Math.hypot(x,z);
 return n?{x:x/n,z:z/n}:{x:0,z:0};
}
export function launchJump(position,direction,{startedAt=0}={}){
 if(![position.x,position.z,direction.x,direction.z].every(Number.isFinite))throw Error('Invalid jump');
 const n=Math.hypot(direction.x,direction.z),dx=n?direction.x/n:0,dz=n?direction.z/n:0;
 return {x:position.x,z:position.z,y:0,dx,dz,directional:n>0,mode:'normal',startedAt,elapsed:0,progress:0,done:false,blocked:false};
}
// Upgrade the existing trajectory; never restart flight or add a second impulse.
export function tryDiveJump(state,direction,now){
 const age=now-state.startedAt;
 if(state.mode!=='normal'||state.done||state.falling||state.ceilingHit||age<0||age>DOUBLE_JUMP_WINDOW_MS||state.elapsed>=JUMP.flight)return state;
 const n=Math.hypot(direction.x,direction.z);
 if(!Number.isFinite(n)||!n)return state;
 return {...state,mode:'dive',dx:direction.x/n,dz:direction.z/n,directional:true};
}
export function stepJump(state,dt,allowed){
 if(!Number.isFinite(dt)||dt<0)throw Error('Invalid jump time');
 if(state.done)return state;
 const elapsed=Math.min(JUMP.flight+JUMP.recovery,state.elapsed+Math.min(dt,.1));
 const travel=Math.max(0,Math.min(elapsed,JUMP.flight)-Math.min(state.elapsed,JUMP.flight))*(state.mode==='dive'?JUMP.speed:NORMAL_JUMP_SPEED);
 const result=movePedestrian(state,{x:state.dx*travel,z:state.dz*travel},allowed,JUMP.radius);
 const p=Math.min(1,elapsed/JUMP.flight);
 return {...state,x:result.x,z:result.z,y:4*JUMP.height*p*(1-p),elapsed,progress:elapsed/(JUMP.flight+JUMP.recovery),done:elapsed>=JUMP.flight+JUMP.recovery,blocked:state.blocked||(state.directional&&travel>0&&Math.hypot(result.x-state.x,result.z-state.z)<travel-.00001)};
}
