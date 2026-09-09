/** Presentation only. All coordinates, footprint sizes and velocities are metres/seconds.
 * waterAt(x,z): null | {level,depth,floor}. Actors: {id,position,velocity?,yaw?,
 * massKg?,footprint?:{width,length},contactOffsetY?,contactPoints?:[{x,y,z,front?}],
 * enabled?,teleport?}. Yaw zero faces +Z. Hero position is the foot origin.
 * First observation, a teleport or a long suspended frame never makes an impact.
 */
const TAU=Math.PI*2;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const finite=(v,f=0)=>Number.isFinite(v)?v:f;
const validPoint=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z);
const lerp=(a,b,t)=>a+(b-a)*t;
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const pool=(n)=>Array.from({length:n},()=>({active:false}));
// Shared contract with environmentRippleAt: amplitude must not change wave speed.
export const WATER_RIPPLE_START_RADIUS=.08;
export const WATER_RIPPLE_SPEED=1.35;
export const WATER_RIPPLE_LIFETIME=4.5;
export const waterRippleRadius=age=>WATER_RIPPLE_START_RADIUS+Math.max(0,finite(age))*WATER_RIPPLE_SPEED;

export function createWaterInteractionSimulator({waterAt,groundHeight,maxDroplets=240,maxRings=24,maxFoam=72,maxActors=24,maxDistance=100,random=Math.random,gravity=9.81,drag=.65}={}){
  if(typeof waterAt!=='function')throw new TypeError('waterAt is required');
  const droplets=pool(clamp(Math.floor(finite(maxDroplets,240)),0,1024));
  const rings=pool(clamp(Math.floor(finite(maxRings,24)),0,64));
  const foam=pool(clamp(Math.floor(finite(maxFoam,72)),0,256));
  maxActors=clamp(Math.floor(finite(maxActors,24)),1,64);maxDistance=clamp(finite(maxDistance,100),1,1000);
  const tracks=new Map();let now=0,disposed=false,budget=0;
  const totals={bursts:0,impacts:0,wakes:0,droplets:0,recontacts:0,suppressed:0,peakDroplets:0};
  const rnd=()=>clamp(finite(random(),.5),0,.999999);
  const sample=(x,z)=>{const w=waterAt(x,z);if(!w||!Number.isFinite(w.level))return null;const depth=Number.isFinite(w.depth)?w.depth:Number.isFinite(w.floor)?w.level-w.floor:0;return depth>.012?{level:w.level,depth}:null;};
  function take(list){if(!list.length)return null;return list.find(p=>!p.active)||list.reduce((old,p)=>p.age>old.age?p:old,list[0]);}
  function ring(x,z,y,strength){const p=take(rings);if(!p)return;Object.assign(p,{active:true,x,z,y:y+.016,age:0,life:WATER_RIPPLE_LIFETIME,strength:clamp(strength,0,2),radius:waterRippleRadius(0)});}
  function foamAt(x,z,y,strength){const p=take(foam);if(!p||!sample(x,z))return;Object.assign(p,{active:true,x,z,y:y+.022,age:0,life:.5+rnd()*.8,radius:.05+Math.min(.24,strength*.05),angle:rnd()*TAU});}
  function burst(point,velocity,{vehicle=false,mass=80,depth=.2,wake=false,front=true,wheelSide=1,yaw=0}={}){
    const w=sample(point.x,point.z);if(!w)return;
    const horizontal=Math.hypot(velocity.x,velocity.z),down=Math.max(0,-velocity.y);
    const depthScale=clamp(Math.sqrt(Math.max(0,depth)/.6),.12,1);
    const energy=.5*mass*(down*down+(vehicle?.22:.08)*horizontal*horizontal)*depthScale;
    const power=clamp(Math.log1p(energy/35),.12,5);
    const strength=clamp((wake?.08:.28)+power*(wake?.14:.3),.08,2);
    const count=Math.min(budget,Math.floor((wake?2:5)+power*(vehicle?5:4)));
    if(!count)return;budget-=count;totals.bursts++;totals[wake?'wakes':'impacts']++;
    ring(point.x,point.z,w.level,strength);
    const heading=finite(yaw),sin=Math.sin(heading),cos=Math.cos(heading);
    const travelSign=velocity.x*sin+velocity.z*cos<0?-1:1;
    for(let i=0;i<count;i++){
      const p=take(droplets);if(!p)break;
      const angle=rnd()*TAU;
      const side=.4+power*(.25+rnd()*.35),up=(wake?.3:.65)+power*(.24+rnd()*.42);
      let vx=Math.sin(angle)*side+velocity.x*.18,vz=Math.cos(angle)*side+velocity.z*.18;
      if(vehicle){
        // Mirrored outward sheets: never aim both tyres' fans across the chassis.
        // The leading axle makes the bow (the rear axle leads when reversing).
        const outward=side*(.65+rnd()*.55)*(wheelSide<0?-1:1);
        const along=side*(front?.25+rnd()*.55:-.15-rnd()*.35)*travelSign;
        vx=cos*outward+sin*along+velocity.x*.18;
        vz=-sin*outward+cos*along+velocity.z*.18;
      }
      Object.assign(p,{active:true,x:point.x+(rnd()-.5)*.12,y:w.level+.03,z:point.z+(rnd()-.5)*.12,
        vx,vy:up,vz,
        radius:(.014+rnd()*.027)*(vehicle?1.25:1),age:0,life:1.2+power*.28});
      totals.droplets++;
    }
    foamAt(point.x,point.z,w.level,power);
  }
  function contactPoints(actor,vehicle){
    if(vehicle&&Array.isArray(actor.contactPoints)&&actor.contactPoints.length){const sin=Math.sin(finite(actor.yaw)),cos=Math.cos(finite(actor.yaw)),origin=actor.position;return actor.contactPoints.filter(validPoint).slice(0,4).map(p=>({x:p.x,y:p.y,z:p.z,front:p.front??((p.x-origin.x)*sin+(p.z-origin.z)*cos>0),side:(p.x-origin.x)*cos-(p.z-origin.z)*sin<0?-1:1}));}
    const p=actor.position,y=p.y+finite(actor.contactOffsetY);
    if(!vehicle)return [{x:p.x,y,z:p.z,front:true}];
    const w=clamp(finite(actor.footprint?.width,1.9),.5,5)*.43,l=clamp(finite(actor.footprint?.length,4.5),1,12)*.36;
    const yaw=finite(actor.yaw),s=Math.sin(yaw),c=Math.cos(yaw);
    return [[-w,l],[w,l],[-w,-l],[w,-l]].map(([x,z],i)=>({x:p.x+x*c+z*s,y,z:p.z-x*s+z*c,front:i<2,side:x<0?-1:1}));
  }
  function wetAt(p){const w=sample(p.x,p.z);return w&&p.y<=w.level+.045?w:null;}
  function sweep(a,b){
    const steps=clamp(Math.ceil(distance(a,b)/.22),1,40);
    for(let i=1;i<=steps;i++){const t=i/steps,p={x:lerp(a.x,b.x,t),y:lerp(a.y,b.y,t),z:lerp(a.z,b.z,t)},w=wetAt(p);if(w)return {point:p,water:w};}
    return null;
  }
  function observe(actor,vehicle,dt,rawDt,focus){
    if(!actor||actor.enabled===false||!validPoint(actor.position))return;
    const p=actor.position,key=(vehicle?'car:':'hero:')+String(actor.id??(vehicle?'':'player'));
    if(vehicle&&(actor.id==null||actor.id===''))return;
    if(focus&&Math.hypot(p.x-focus.x,p.z-focus.z)>maxDistance)return;
    const points=contactPoints(actor,vehicle);if(!points.length)return;
    const prior=tracks.get(key),wet=points.map(wetAt);
    const next={position:{x:p.x,y:p.y,z:p.z},points,wet,seen:now,travel:prior?.travel||0};
    tracks.set(key,next);
    const movement=prior?distance(p,prior.position):0;
    const speed=validPoint(actor.velocity)?Math.hypot(actor.velocity.x,actor.velocity.y,actor.velocity.z):0;
    if(!prior||actor.teleport||rawDt>.25||movement>Math.max(8,speed*rawDt*2+2)||points.length!==prior.points.length){totals.suppressed++;next.travel=0;return;}
    const velocity={x:(p.x-prior.position.x)/rawDt,y:(p.y-prior.position.y)/rawDt,z:(p.z-prior.position.z)/rawDt};
    // Preserve downward pre-contact impact velocity when the gameplay solver lands.
    if(Number.isFinite(actor.velocity?.y))velocity.y=Math.min(velocity.y,actor.velocity.y);
    const horizontal=Math.hypot(velocity.x,velocity.z);
    const forwardTravel=velocity.x*Math.sin(finite(actor.yaw))+velocity.z*Math.cos(finite(actor.yaw))>=0;
    const leading=point=>!vehicle||point.front===forwardTravel;
    const mass=clamp(finite(actor.massKg,vehicle?1400:80),10,20000)/(vehicle?points.length:1);
    let entered=false;
    for(let i=0;i<points.length;i++){
      if(prior.wet[i])continue;
      const hit=sweep(prior.points[i],points[i]);if(!hit)continue;
      const down=Math.max(0,-velocity.y),impact=down>1.35||vehicle&&horizontal>1.3;
      if(impact||horizontal>.35){burst(hit.point,velocity,{vehicle,mass,depth:hit.water.depth,wake:!impact,front:leading(points[i]),wheelSide:points[i].side,yaw:actor.yaw});entered=true;}
    }
    next.travel+=Math.hypot(p.x-prior.position.x,p.z-prior.position.z);
    const spacing=vehicle?.9:.55;
    if(!entered&&horizontal>(vehicle?.65:.35)&&next.travel>=spacing){
      for(let i=0;i<points.length;i++){if(!wet[i]||!leading(points[i]))continue;burst(points[i],velocity,{vehicle,mass,depth:wet[i].depth,wake:true,front:true,wheelSide:points[i].side,yaw:actor.yaw});}
      next.travel%=spacing;
    }
    if(entered||!wet.some(Boolean)||horizontal<.1)next.travel=0;
  }
  function stepParticles(dt){
    const steps=Math.max(1,Math.ceil(dt/(1/60))),h=dt/steps,damping=Math.exp(-Math.max(0,drag)*h);
    for(let s=0;s<steps;s++)for(const p of droplets){if(!p.active)continue;
      const beforeY=p.y;p.age+=h;p.vx*=damping;p.vz*=damping;p.vy=p.vy*damping-Math.max(0,gravity)*h;p.x+=p.vx*h;p.y+=p.vy*h;p.z+=p.vz*h;
      const w=sample(p.x,p.z);
      if(w&&p.vy<0&&beforeY>w.level&&p.y<=w.level){p.active=false;totals.recontacts++;foamAt(p.x,p.z,w.level,.3);if(rnd()<.16)ring(p.x,p.z,w.level,.08);}
      else if(p.age>=p.life||p.y<-1000||(!w&&typeof groundHeight==='function'&&p.y<=groundHeight(p.x,p.z)))p.active=false;
    }
    for(const p of rings){if(!p.active)continue;p.age+=dt;p.radius=waterRippleRadius(p.age);if(p.age>=p.life)p.active=false;}
    for(const p of foam){if(!p.active)continue;p.age+=dt;if(p.age>=p.life||!sample(p.x,p.z))p.active=false;}
  }
  const stats=()=>({...totals,activeDroplets:droplets.filter(p=>p.active).length,activeRings:rings.filter(p=>p.active).length,activeFoam:foam.filter(p=>p.active).length,trackedActors:tracks.size,maxDroplets:droplets.length,maxRings:rings.length,maxFoam:foam.length,time:now,disposed});
  return {droplets,rings,foam,sample,
    update(dt,{hero,vehicles=[],focus}={}){
      if(disposed)return;const rawDt=finite(dt);if(rawDt<=0)return;dt=clamp(rawDt,0,1/15);now+=dt;budget=96;
      stepParticles(dt);
      observe(hero,false,dt,rawDt,focus);
      for(const actor of (Array.isArray(vehicles)?vehicles:[]).slice(0,Math.max(0,maxActors-1)))observe(actor,true,dt,rawDt,focus);
      for(const [id,track] of tracks)if(track.seen!==now)tracks.delete(id);
      totals.peakDroplets=Math.max(totals.peakDroplets,droplets.filter(p=>p.active).length);
    },
    getRipples(){return rings.filter(p=>p.active&&p.age<WATER_RIPPLE_LIFETIME).sort((a,b)=>b.strength*(1-b.age/WATER_RIPPLE_LIFETIME)-a.strength*(1-a.age/WATER_RIPPLE_LIFETIME)).slice(0,8).map(p=>({x:p.x,z:p.z,y:p.y,age:p.age,strength:p.strength,radius:p.radius,duration:WATER_RIPPLE_LIFETIME}));},
    stats,
    dispose(){disposed=true;tracks.clear();for(const list of [droplets,rings,foam])for(const p of list)p.active=false;}
  };
}

/** Three.js wrapper: exactly three bounded instanced batches, no lights/textures. */
export function createWaterInteractionEffects({THREE,...options}={}){
  if(!THREE?.InstancedMesh)throw new TypeError('THREE is required');
  const sim=createWaterInteractionSimulator(options),object=new THREE.Group();object.name='Water interaction · droplets, shore-clipped rings and foam';
  const segmentCount=12,opacityName='waterInstanceOpacity',dummy=new THREE.Object3D(),up=new THREE.Vector3(0,1,0),velocity=new THREE.Vector3();
  function batch(name,geometry,count,color,opacity,roughness){
    geometry.setAttribute(opacityName,new THREE.InstancedBufferAttribute(new Float32Array(Math.max(1,count)),1).setUsage(THREE.DynamicDrawUsage));
    const material=new THREE.MeshStandardMaterial({color,roughness,metalness:.08,transparent:true,opacity,depthWrite:false,side:THREE.DoubleSide});material.forceSinglePass=true;
    material.onBeforeCompile=shader=>{shader.vertexShader=`attribute float ${opacityName}; varying float vWaterOpacity;\n`+shader.vertexShader;shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>\n vWaterOpacity = ${opacityName};`);shader.fragmentShader='varying float vWaterOpacity;\n'+shader.fragmentShader;shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>','#include <color_fragment>\n diffuseColor.a *= vWaterOpacity;');};
    material.customProgramCacheKey=()=> 'water-interaction-opacity-v1';
    const mesh=new THREE.InstancedMesh(geometry,material,Math.max(1,count));mesh.name=name;mesh.count=0;mesh.frustumCulled=false;mesh.raycast=()=>{};mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.renderOrder=3;object.add(mesh);return mesh;
  }
  const drops=batch('Ballistic water droplets',new THREE.SphereGeometry(1,6,4),sim.droplets.length,0xb7e0e3,.9,.16);
  const circles=batch('Shore-clipped expanding arcs',new THREE.RingGeometry(.97,1.03,3,1,0,TAU/segmentCount),sim.rings.length*segmentCount,0xd6efeb,.55,.6);
  const froth=batch('Surface recontact foam',new THREE.CircleGeometry(1,7),sim.foam.length,0xe1eee5,.62,.85);
  function write(mesh,index,p,scale,alpha,quaternion){dummy.position.set(p.x,p.y,p.z);dummy.scale.set(scale.x,scale.y,scale.z);dummy.quaternion.copy(quaternion);dummy.updateMatrix();mesh.setMatrixAt(index,dummy.matrix);mesh.geometry.attributes[opacityName].setX(index,clamp(alpha,0,1));}
  const flat=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),rotation=new THREE.Quaternion(),turn=new THREE.Quaternion();
  function upload(){let n=0;for(const p of sim.droplets){if(!p.active)continue;velocity.set(p.vx,p.vy,p.vz);const speed=velocity.length();rotation.setFromUnitVectors(up,speed>.001?velocity.normalize():up);const fade=clamp((p.life-p.age)/.25,0,1);write(drops,n++,p,{x:p.radius,y:p.radius*(1+Math.min(3,speed*.28)),z:p.radius},fade,rotation);}drops.count=n;
    n=0;for(const p of sim.rings){if(!p.active)continue;const fade=Math.pow(1-p.age/p.life,1.8);if(fade<.015)continue;for(let i=0;i<segmentCount;i++){
      let wet=true;for(const fraction of [0,.5,1]){const angle=(i+fraction)*TAU/segmentCount;for(const rim of [.97,1.03]){const w=sim.sample(p.x+Math.cos(angle)*p.radius*rim,p.z-Math.sin(angle)*p.radius*rim);if(!w||Math.abs(w.level-(p.y-.016))>.08){wet=false;break;}}if(!wet)break;}if(!wet)continue;
      turn.setFromAxisAngle(up,i*TAU/segmentCount);rotation.copy(turn).multiply(flat);write(circles,n++,p,{x:p.radius,y:p.radius,z:1},fade*Math.min(1,.3+p.strength),rotation);
    }}circles.count=n;
    n=0;for(const p of sim.foam){if(!p.active)continue;turn.setFromAxisAngle(up,p.angle);rotation.copy(turn).multiply(flat);const size=p.radius*(1+p.age*.65);write(froth,n++,p,{x:size,y:size*.62,z:1},Math.pow(1-p.age/p.life,1.5),rotation);}froth.count=n;
    for(const mesh of [drops,circles,froth]){mesh.instanceMatrix.needsUpdate=true;mesh.geometry.attributes[opacityName].needsUpdate=true;mesh.visible=mesh.count>0;}
  }
  let disposed=false;
  return {object,update(dt,input){if(disposed)return;sim.update(dt,input);upload();},getRipples:()=>sim.getRipples(),stats:()=>({...sim.stats(),drawCalls:[drops,circles,froth].filter(m=>m.visible&&m.count).length,ringSegments:circles.count}),
    dispose(){if(disposed)return;disposed=true;sim.dispose();for(const mesh of [drops,circles,froth]){mesh.geometry.dispose();mesh.material.dispose();mesh.dispose?.();}object.removeFromParent();object.clear();}
  };
}
