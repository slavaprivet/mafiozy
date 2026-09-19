import assert from 'node:assert/strict';
import {createWorldTrafficPresentation} from './world_traffic_presentation.mjs';
const object=()=>({position:{x:0,y:0,z:0,set(x,y,z){Object.assign(this,{x,y,z});}},rotation:{y:0},userData:{},traverse(){},removeFromParent(){}});
const row={id:'turning-resident',r:0,c:0,ang:Math.PI/2,model:'sedan'};
async function scenario({reverse=false,right=false,authored=false}={}){
 const updates=[],fleet=createWorldTrafficPresentation({scene:{add(){}},loader:{async loadAsync(){return {scene:object()};}},vehicleFactory:()=>({object:object(),profile:{wheelBase:2.65},update(state,braking){updates.push({...state,braking});}})});
 fleet.sync([row]);await fleet.whenIdle();fleet.update(.1);
 const sign=right?-1:1,gear=reverse?-1:1,yaw=sign*gear*.2;
 const to={...row,c:sign*5*(1-Math.cos(.2))/4.1,r:gear*5*Math.sin(.2)/4.1,ang:Math.PI/2-yaw,...(authored?{steer:-.15}:{})};
 fleet.sync([to]);fleet.update(.1);
 const steer=updates.at(-1).steer;
 if(authored)assert.equal(steer,-.15,'authored input stays authoritative');
 else assert(steer*sign>.25&&Math.abs(steer)<=.6,'front wheels follow signed travel curvature');
 fleet.sync([{...to,parked:true,braking:true}]);for(let i=0;i<30;i++)fleet.update(.1);
 assert.equal(updates.at(-1).braking,true);
 if(!authored)assert.equal(updates.at(-1).steer,0,'settled parked wheels return to centre');
 const count=updates.length;for(let i=0;i<120;i++)fleet.update(.1);
 assert.equal(updates.length,count,'parked car does not acquire recurring presentation work');
 fleet.sync([{...row,r:100,c:100}]);fleet.update(.1);
 assert.equal(updates.at(-1).distance,0,'teleport is not wheel travel');assert.equal(updates.at(-1).steer,0);
 fleet.dispose();return {reverse,right,authored,steer};
}
const results=[];for(const options of [{},{right:true},{reverse:true},{reverse:true,right:true},{authored:true}])results.push(await scenario(options));
console.log(JSON.stringify({pass:true,results,limits:'Renderer input/curvature/brake state only; does not validate source driving or parking geometry.'},null,2));
