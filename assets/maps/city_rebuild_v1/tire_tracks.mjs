// A bounded rubber-mark pool. Simulation is renderer-independent for regression QA.
const WHEELS=[[-.92,1.3,true],[.92,1.3,true],[-.92,-1.35,false],[.92,-1.35,false]];
export function createTireTrackPool({maxSegments=1200,lifetime=10,spacing=.28,width=.19,surfaceAt=()=>true}={}){
 if(!Number.isInteger(maxSegments)||maxSegments<1||!(lifetime>0)||!(spacing>0)||!(width>0))throw Error('Invalid tire-track pool options');
 const positions=new Float32Array(maxSegments*18),opacity=new Float32Array(maxSegments*6),ages=new Float32Array(maxSegments).fill(lifetime),strengths=new Float32Array(maxSegments);
 let cursor=0,count=0,previous=WHEELS.map(()=>null);
 function clear(){opacity.fill(0);ages.fill(lifetime);strengths.fill(0);previous=WHEELS.map(()=>null);cursor=count=0}
 function update(car,dt){
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid tire-track time');
  for(let i=0;i<maxSegments;i++)if(strengths[i]){
   ages[i]=Math.min(lifetime,ages[i]+dt);
   const fade=Math.min(1,(lifetime-ages[i])/(lifetime*.45));
   opacity.fill(strengths[i]*fade,i*6,i*6+6);
   if(ages[i]>=lifetime)strengths[i]=0;
  }
  if(!car||![car.x,car.z,car.yaw,car.speed].every(Number.isFinite)){previous=WHEELS.map(()=>null);return}
  const sin=Math.sin(car.yaw),cos=Math.cos(car.yaw);
  WHEELS.forEach(([side,front,isFront],wheel)=>{
   const point={x:car.x+side*cos+front*sin,z:car.z-side*sin+front*cos};
   const slip=isFront?car.frontSlip||0:car.rearSlip||0;
   if(slip<.2||Math.abs(car.speed)<.6||!surfaceAt(point.x,point.z)){previous[wheel]=null;return}
   const from=previous[wheel];
   if(!from){previous[wheel]=point;return}
   const dx=point.x-from.x,dz=point.z-from.z,length=Math.hypot(dx,dz);
   // A teleport/reset or a dropped frame must never draw a long line across town.
   if(length>3){previous[wheel]=point;return}
   if(length<spacing)return;
   const ox=-dz/length*width*.5,oz=dx/length*width*.5;
   positions.set([from.x+ox,.018,from.z+oz,from.x-ox,.018,from.z-oz,point.x+ox,.018,point.z+oz,
    point.x+ox,.018,point.z+oz,from.x-ox,.018,from.z-oz,point.x-ox,.018,point.z-oz],cursor*18);
   strengths[cursor]=Math.min(.42,Math.max(0,slip)*.42);ages[cursor]=0;
   opacity.fill(strengths[cursor],cursor*6,cursor*6+6);
   cursor=(cursor+1)%maxSegments;count=Math.min(maxSegments,count+1);previous[wheel]=point;
  });
 }
 return{positions,opacity,update,clear,get count(){return count},get active(){return strengths.reduce((n,s)=>n+(s>0),0)},maxSegments};
}

export function createTireTracks(T,options={}){
 const pool=createTireTrackPool(options),geometry=new T.BufferGeometry();
 const position=new T.BufferAttribute(pool.positions,3),alpha=new T.BufferAttribute(pool.opacity,1);
 position.setUsage(T.DynamicDrawUsage);alpha.setUsage(T.DynamicDrawUsage);
 geometry.setAttribute('position',position);geometry.setAttribute('trackOpacity',alpha);
 const material=new T.ShaderMaterial({transparent:true,depthWrite:false,side:T.DoubleSide,
  uniforms:{trackColor:{value:new T.Color('#343732')}},
  vertexShader:'attribute float trackOpacity; varying float vOpacity; void main(){vOpacity=trackOpacity;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',
  fragmentShader:'uniform vec3 trackColor; varying float vOpacity; void main(){if(vOpacity<0.002)discard;gl_FragColor=vec4(trackColor,vOpacity);\n#include <tonemapping_fragment>\n#include <colorspace_fragment>\n}'});
 const object=new T.Mesh(geometry,material);object.name='Tire_marks';object.frustumCulled=false;object.renderOrder=1;
 function sync(){position.needsUpdate=true;alpha.needsUpdate=true;geometry.setDrawRange(0,pool.count*6)}
 return{object,pool,update(car,dt){pool.update(car,dt);sync()},clear(){pool.clear();sync()},dispose(){object.removeFromParent();geometry.dispose();material.dispose()}};
}
