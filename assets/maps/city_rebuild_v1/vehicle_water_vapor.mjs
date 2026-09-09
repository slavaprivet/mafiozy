// Brief grey water/engine-failure vapour, never fire or permanent damage smoke.
import {sampleVehicleEngineHighPoint} from './vehicle_water_state.mjs';
export const VEHICLE_WATER_VAPOR_LIMITS=Object.freeze({particles:96,emitters:24,emissionSeconds:2.6,maxLife:4,maxDistance:110});
const finite=Number.isFinite,clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
export function createVehicleWaterVapor({THREE}){
 const limits=VEHICLE_WATER_VAPOR_LIMITS,observed=new WeakMap(),emitters=new Map(),present=new Set();
 const particles=Array.from({length:limits.particles},()=>({active:false}));
 const geometry=new THREE.PlaneGeometry(1,1),data=new THREE.InstancedBufferAttribute(new Float32Array(limits.particles*4),4);data.setUsage(THREE.DynamicDrawUsage);geometry.setAttribute('puffData',data);
 const material=new THREE.ShaderMaterial({transparent:true,depthWrite:false,depthTest:true,side:THREE.DoubleSide,
  vertexShader:`attribute vec4 puffData; varying vec2 vPuff; varying float vAlpha; varying float vShade;
   void main(){vec2 p=position.xy;float c=cos(puffData.z),s=sin(puffData.z);p=mat2(c,-s,s,c)*p;
    vec4 centre=modelViewMatrix*instanceMatrix*vec4(0.,0.,0.,1.);centre.xy+=p*puffData.x;
    gl_Position=projectionMatrix*centre;vPuff=uv*2.-1.;vAlpha=puffData.y;vShade=puffData.w;}`,
  fragmentShader:`varying vec2 vPuff;varying float vAlpha;varying float vShade;
   void main(){float r=length(vPuff);float radial=exp(-3.5*r*r)*(1.-smoothstep(.68,1.,r));
    float curl=.88+.12*sin(vPuff.x*7.+vShade*8.)*sin(vPuff.y*6.-vShade*5.);
    float alpha=radial*curl*vAlpha;if(alpha<.002)discard;
    gl_FragColor=vec4(mix(vec3(.43,.47,.49),vec3(.76,.79,.8),vShade),alpha);}`
 });
 const object=new THREE.InstancedMesh(geometry,material,limits.particles);object.name='Vehicle_water_engine_vapor';object.count=0;object.frustumCulled=false;object.renderOrder=4;object.raycast=()=>{};object.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
 const matrix=new THREE.Matrix4();let disposed=false,triggers=0,totalParticles=0,peak=0,sequence=0,lastOrigin=null;
 function random(){let t=(++sequence*2654435761)>>>0;t=Math.imul(t^(t>>>16),2246822519);return ((t^(t>>>13))>>>0)/4294967296;}
 const near=(p,focus)=>!focus||!finite(focus.x)||!finite(focus.z)||Math.hypot(p.x-focus.x,p.z-focus.z)<=limits.maxDistance;
 function spawn(origin,strength){
  const p=particles.find(p=>!p.active);if(!p)return false;
  const angle=random()*Math.PI*2,radius=random()*.15;
  p.active=true;p.x=origin.x+Math.cos(angle)*radius;p.y=origin.y;p.z=origin.z+Math.sin(angle)*radius;
  p.vx=(random()-.5)*.2;p.vy=.6+random()*.5;p.vz=(random()-.5)*.2;p.age=0;p.life=2.8+random()*1.2;
  p.size=.65+random()*.3;p.alpha=(.38+random()*.18)*strength;p.angle=angle;p.shade=.5+random()*.5;
  totalParticles++;return true;
 }
 function update(dt,records=[],focus=null){
  if(disposed)return;
  if(!finite(dt)||dt<0)throw Error('Finite nonnegative vapour timestep required');
  const seconds=Math.min(dt,10);present.clear();
  for(const p of particles)if(p.active){p.age+=seconds;if(p.age>=p.life){p.active=false;continue;}p.x+=p.vx*seconds;p.y+=p.vy*seconds;p.z+=p.vz*seconds;}
  for(const record of records){
   const car=record?.car;if(!car?.object)continue;present.add(car);
   const water=record.state?.waterState,flooded=!!(water?.engineDisabled||water?.flooded),prior=observed.get(car);
   // Loading an already broken/saved vehicle is not a new failure event.
   if(prior===false&&flooded){
    triggers++;if(emitters.size<limits.emitters&&near(car.object.position,focus))emitters.set(car,{elapsed:0,budget:0});
   }
   observed.set(car,flooded);if(!flooded)emitters.delete(car);
   const emitter=emitters.get(car);if(!emitter)continue;
   const elapsedBefore=emitter.elapsed;emitter.elapsed+=seconds;
   const emissionDt=Math.max(0,Math.min(seconds,limits.emissionSeconds-elapsedBefore));
   if(emissionDt>0&&dt<=.25&&near(car.object.position,focus)){
    const engine=sampleVehicleEngineHighPoint({THREE,car});
    if(engine){
     const origin={x:engine.x,y:Math.max(engine.y+.06,finite(water?.waterLevel)?water.waterLevel+.06:-Infinity),z:engine.z};lastOrigin=origin;
     // Emission tails away instead of abruptly stopping at the final frame.
     const strength=1-clamp(elapsedBefore/limits.emissionSeconds,0,1)*.75;
     emitter.budget+=emissionDt*15*strength;
     while(emitter.budget>=1){spawn(origin,strength);emitter.budget--;}
    }
   }
   if(emitter.elapsed>=limits.emissionSeconds)emitters.delete(car);
  }
  for(const car of emitters.keys())if(!present.has(car))emitters.delete(car);
  let count=0,active=0;
  for(const p of particles)if(p.active){active++;if(!near(p,focus))continue;
   const progress=p.age/p.life,alpha=p.alpha*Math.min(1,p.age/.16)*Math.pow(1-progress,1.6),size=p.size+p.age*.32;
   matrix.makeTranslation(p.x,p.y,p.z);object.setMatrixAt(count,matrix);data.setXYZW(count,size,alpha,p.angle,p.shade);count++;
  }
  peak=Math.max(peak,active);object.count=count;object.visible=count>0;object.instanceMatrix.needsUpdate=true;data.needsUpdate=true;
 }
 function stats(){return {disposed,active:particles.filter(p=>p.active).length,visible:object.count,emitters:emitters.size,triggers,totalParticles,peak,capacity:limits.particles,lastOrigin:lastOrigin?{...lastOrigin}:null};}
 function dispose(){if(disposed)return;disposed=true;emitters.clear();for(const p of particles)p.active=false;object.count=0;object.visible=false;object.removeFromParent();geometry.dispose();material.dispose();object.dispose?.();}
 return {object,update,dispose,stats};
}
