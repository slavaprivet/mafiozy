// A bounded rubber-mark pool. Simulation is renderer-independent for regression QA.
const WHEELS=[[-.92,1.3,true],[.92,1.3,true],[-.92,-1.35,false],[.92,-1.35,false]];
export function createTireTrackPool({maxSegments=1200,lifetime=10,spacing=.28,width=.19,surfaceAt=()=>true}={}){
 if(!Number.isInteger(maxSegments)||maxSegments<1||!(lifetime>0)||!(spacing>0)||!(width>0))throw Error('Invalid tire-track pool options');
 const positions=new Float32Array(maxSegments*18),opacity=new Float32Array(maxSegments*6),ages=new Float32Array(maxSegments).fill(lifetime),strengths=new Float32Array(maxSegments),activeSlots=new Set();
 // Tracks update once per render frame while a car is driven. Keep the four
 // wheel samples in fixed storage: the old path created point objects and an
 // 18-element temporary array for every wheel/mark.
 const previousX=new Float64Array(WHEELS.length),previousZ=new Float64Array(WHEELS.length),hasPrevious=new Uint8Array(WHEELS.length);
 let cursor=0,count=0;
 function clear(){opacity.fill(0);ages.fill(lifetime);strengths.fill(0);activeSlots.clear();hasPrevious.fill(0);cursor=count=0}
 function update(car,dt){
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid tire-track time');
  let dirty=false;
  for(const i of activeSlots){
   ages[i]=Math.min(lifetime,ages[i]+dt);
   const fade=Math.min(1,(lifetime-ages[i])/(lifetime*.45));
   opacity.fill(strengths[i]*fade,i*6,i*6+6);
   dirty=true;if(ages[i]>=lifetime){strengths[i]=0;activeSlots.delete(i)}
  }
  if(!car||!Number.isFinite(car.x)||!Number.isFinite(car.z)||!Number.isFinite(car.yaw)||!Number.isFinite(car.speed)){hasPrevious.fill(0);return dirty}
  const sin=Math.sin(car.yaw),cos=Math.cos(car.yaw);
  for(let wheel=0;wheel<WHEELS.length;wheel++){
   const [side,front,isFront]=WHEELS[wheel],x=car.x+side*cos+front*sin,z=car.z-side*sin+front*cos;
   const slip=isFront?car.frontSlip||0:car.rearSlip||0;
   if(slip<.2||Math.abs(car.speed)<.6||!surfaceAt(x,z)){hasPrevious[wheel]=0;continue}
   if(!hasPrevious[wheel]){previousX[wheel]=x;previousZ[wheel]=z;hasPrevious[wheel]=1;continue}
   const fromX=previousX[wheel],fromZ=previousZ[wheel],dx=x-fromX,dz=z-fromZ,length=Math.hypot(dx,dz);
   // A teleport/reset or a dropped frame must never draw a long line across town.
   if(length>3){previousX[wheel]=x;previousZ[wheel]=z;continue}
   if(length<spacing)continue;
   const ox=-dz/length*width*.5,oz=dx/length*width*.5;
   const offset=cursor*18;
   positions[offset]=fromX+ox;positions[offset+1]=.018;positions[offset+2]=fromZ+oz;
   positions[offset+3]=fromX-ox;positions[offset+4]=.018;positions[offset+5]=fromZ-oz;
   positions[offset+6]=x+ox;positions[offset+7]=.018;positions[offset+8]=z+oz;
   positions[offset+9]=x+ox;positions[offset+10]=.018;positions[offset+11]=z+oz;
   positions[offset+12]=fromX-ox;positions[offset+13]=.018;positions[offset+14]=fromZ-oz;
   positions[offset+15]=x-ox;positions[offset+16]=.018;positions[offset+17]=z-oz;
   strengths[cursor]=Math.min(.42,Math.max(0,slip)*.42);ages[cursor]=0;activeSlots.add(cursor);dirty=true;
   opacity.fill(strengths[cursor],cursor*6,cursor*6+6);
   cursor=(cursor+1)%maxSegments;count=Math.min(maxSegments,count+1);previousX[wheel]=x;previousZ[wheel]=z;
  }return dirty;
 }
 return{positions,opacity,update,clear,get count(){return count},get active(){return activeSlots.size},maxSegments};
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
 return{object,pool,update(car,dt){if(pool.update(car,dt))sync()},clear(){pool.clear();sync()},dispose(){object.removeFromParent();geometry.dispose();material.dispose()}};
}
