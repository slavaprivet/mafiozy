import {GRASS_LIMITS} from './environment_grass_plan.mjs';
export const GRASS_WIND=Object.freeze({amplitude:.11,secondary:.45,speed:1.8,secondarySpeed:3.1,directionZ:.54});
export const GRASS_CONTACT=Object.freeze({samples:8,recovery:3.8,strength:.55,radius:1.05,sampleDistance:.42,soleCore:.72,compression:1});
const smooth=(a,b,v)=>{const t=Math.max(0,Math.min(1,(v-a)/(b-a)));return t*t*(3-2*t)};
export const grassPressedHeight=t=>.025*smooth(.22,.55,t)+.005*smooth(.55,1,t);
export function grassContactOffset({x,z,time,height=1,weight=1,progress=weight,trail=[],flex=1}={}){
  let best=0,dx=0,dz=0;
  for(const p of trail){const age=Math.max(0,time-p.time),distance=Math.hypot(x-p.x,z-p.z),radius=p.radius||GRASS_CONTACT.radius,t=Math.max(0,Math.min(1,(1-distance/radius)/(1-GRASS_CONTACT.soleCore))),decay=Math.max(0,1-age/GRASS_CONTACT.recovery),force=t*t*(3-2*t)*decay*decay;
    if(force>best){best=force;dx=distance>.001?(x-p.x)/distance:1;dz=distance>.001?(z-p.z)/distance:0;}}
  const bend=GRASS_CONTACT.strength*height*weight*weight*best*flex;
  return{x:dx*bend,z:dz*bend,y:(-height*weight+grassPressedHeight(progress))*best*flex,pressure:best*flex};
}
/** CPU reference of the actual world-space vertex deformation (also used by GLB QA). */
export function grassDeformVertex({vertex,base,root,time,height,weight,progress=weight,trail=[],flex=1,slopeX=0,slopeZ=0,feet=[]}){
 const contact=grassContactOffset({x:root.x,z:root.z,time,height,weight,progress,trail,flex}),wind=grassWindOffset({x:root.x,z:root.z,time,height,weight});
 const p={x:vertex.x+wind.x*flex+contact.x,y:vertex.y+contact.y,z:vertex.z+wind.z*flex+contact.z};
 if(progress>0&&flex>.9&&feet.length&&contact.pressure>.95){
   const center={x:0,z:0};for(const f of feet){center.x+=(f.heel.x+f.toe.x)/(feet.length*2);center.z+=(f.heel.z+f.toe.z)/(feet.length*2)}
   let nx=base.x-center.x,nz=base.z-center.z;const d=Math.hypot(nx,nz);if(d>.001){nx/=d;nz/=d}else{nx=1;nz=0}
   let edge=-Infinity;for(const f of feet)edge=Math.max(edge,f.heel.x*nx+f.heel.z*nz+f.radius,f.toe.x*nx+f.toe.z*nz+f.radius);
   const push=Math.max(0,edge+.018-p.x*nx-p.z*nz);p.x+=nx*push;p.z+=nz*push;
 }
 // The same terrain tangent applies before and after bending. The original
 // base is fixed, while the exposed blade follows the slope after egress.
 p.y+=slopeX*(p.x-root.x)+slopeZ*(p.z-root.z);
 return p;
}
/** CPU reference to the shader's world-space bend; all roots stay exactly fixed. */
export function grassWindOffset({x,z,time,height=1,weight=1}={}){
  const wave=Math.sin(time*GRASS_WIND.speed+x*.08+z*.055)+GRASS_WIND.secondary*Math.sin(time*GRASS_WIND.secondarySpeed+x*.13-z*.09),bend=GRASS_WIND.amplitude*wave*height*weight*weight;
  return {x:bend,z:bend*GRASS_WIND.directionZ};
}
export function grassDistanceFade(distance,near=GRASS_LIMITS.fadeStart,far=GRASS_LIMITS.viewDistance){const t=Math.max(0,Math.min(1,(distance-near)/(far-near||1)));return 1-t*t*(3-2*t);}

// The selected set is maintained as a max-heap: its root is the farthest
// retained tuft.  This retains exactly the same nearest-first sequence as a
// full stable sort, without sorting every candidate in a dense forest.
const grassCandidateOrder=(a,b)=>a._selectionDistance-b._selectionDistance||a._selectionOrder-b._selectionOrder;
const siftGrassCandidateDown=(items,index=0)=>{for(;;){const left=index*2+1,right=left+1;let largest=index;if(left<items.length&&grassCandidateOrder(items[left],items[largest])>0)largest=left;if(right<items.length&&grassCandidateOrder(items[right],items[largest])>0)largest=right;if(largest===index)return;[items[index],items[largest]]=[items[largest],items[index]];index=largest;}};
export function retainNearestGrassCandidate(items,candidate,limit){
 if(limit<1)return items;
 if(items.length<limit){items.push(candidate);for(let index=items.length-1;index>0;){const parent=(index-1)>>1;if(grassCandidateOrder(items[index],items[parent])<=0)break;[items[index],items[parent]]=[items[parent],items[index]];index=parent;}return items;}
 if(grassCandidateOrder(candidate,items[0])<0){items[0]=candidate;siftGrassCandidateDown(items)}
 return items;
}
export const sortNearestGrassCandidates=items=>items.sort(grassCandidateOrder);

/** Tapered closed triangular blades, with actual thickness rather than alpha cards. */
export function createGrassTuftGeometry(THREE,style='grass'){
  const vertices=[],indices=[],colors=[],progress=[],bases=[],blades=style==='reed'?9:7;
  if(style==='shrub'){
    for(let leaf=0;leaf<3;leaf++){
      const a=leaf*Math.PI*2/3,cx=Math.cos(a)*.22,cz=Math.sin(a)*.22,base=vertices.length/3;
      for(let r=0;r<=4;r++)for(let s=0;s<=7;s++){
        const phi=r*Math.PI/4,theta=s*Math.PI*2/7;
        vertices.push(cx+Math.sin(phi)*Math.cos(theta)*.38,.08+(1+Math.cos(phi))*(leaf===0?.46:.36),cz+Math.sin(phi)*Math.sin(theta)*.32);progress.push(vertices.at(-2));bases.push(cx,cz);
        const tone=.72+(4-r)*.065;colors.push(tone,tone,tone);
      }
      for(let r=0;r<4;r++)for(let s=0;s<7;s++){const k=base+r*8+s;indices.push(k,k+8,k+1,k+1,k+8,k+9);}
    }
  }else
  for(let b=0;b<blades;b++){
    const angle=b*Math.PI*2/blades+(style==='reed'?.2:.1),height=b===0?1:.62+(b*.17)% .36,lean=.14+(b%3)*.05,originX=Math.cos(angle)*.13,originZ=Math.sin(angle)*.13,base=vertices.length/3;
    for(let ring=0;ring<4;ring++){
      const t=[0,.22,.55,1][ring],y=t*height,w=t===0?0:(style==='reed'?.047:.063)*(1-t)*(1-.28*t),cx=originX+Math.cos(angle)*lean*t*t,cz=originZ+Math.sin(angle)*lean*t*t;
      for(let side=0;side<3;side++){
        const a=side*Math.PI*2/3,localX=Math.cos(a)*w,localZ=Math.sin(a)*w*.32;
        vertices.push(cx+Math.cos(angle)*localX-Math.sin(angle)*localZ,y,cz+Math.sin(angle)*localX+Math.cos(angle)*localZ);
        progress.push(t);bases.push(originX,originZ);
        const tone=.76+t*.26;colors.push(tone,tone,tone);
      }
    }
    // Pointed root and tip close the solid without degenerate cap triangles.
    for(let ring=0;ring<3;ring++)for(let side=0;side<3;side++){const a=base+ring*3+side,b=base+ring*3+(side+1)%3,c=a+3,d=b+3;if(ring>0)indices.push(a,b,c);if(ring<2)indices.push(b,d,c);}
  }
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));geometry.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));geometry.setAttribute('grassProgress',new THREE.Float32BufferAttribute(progress,1));geometry.setAttribute('grassBase',new THREE.Float32BufferAttribute(bases,2));geometry.setAttribute('grassFlex',new THREE.Float32BufferAttribute(Array(vertices.length/3).fill(style==='shrub'?.22:1),1));geometry.setIndex(indices);geometry.computeVertexNormals();geometry.computeBoundingBox();geometry.computeBoundingSphere();geometry.userData={grassStyle:style,blades:style==='shrub'?0:blades,solidGeometry:true};return geometry;
}

export function createGrassWindMaterial(THREE,uniforms){
  const material=new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.94,metalness:0});
  material.customProgramCacheKey=()=> 'mafiozi-solid-grass-contact-v4-visible-sole';
  material.onBeforeCompile=shader=>{
    Object.assign(shader.uniforms,uniforms);
    shader.vertexShader=shader.vertexShader.replace('#include <common>',`#include <common>
uniform float uGrassTime;
uniform vec2 uGrassFocus;
uniform float uGrassFadeNear;
uniform float uGrassFadeFar;
uniform vec4 uGrassTrail[8];
uniform vec4 uGrassFeet[4];
uniform float uGrassFeetCount;
attribute float grassFlex;
attribute float grassProgress;
attribute vec2 grassBase;
attribute vec2 grassSlope;
vec4 environmentGrassContact(vec2 root) {
  float best = 0.0; vec2 direction = vec2(1.0,0.0);
  for (int i=0; i<8; i++) {
    vec4 p = uGrassTrail[i];
    float age = max(0.0,uGrassTime-p.z);
    vec2 delta = root-p.xy; float d = length(delta);
    float t = clamp((1.0-d/max(.001,p.w))/${(1-GRASS_CONTACT.soleCore).toFixed(3)},0.0,1.0);
    float decay = max(0.0,1.0-age/3.8);
    float force = t*t*(3.0-2.0*t)*decay*decay;
    if(force>best) { best=force; direction=d>.001?delta/d:vec2(1.0,0.0); }
  }
  return vec4(direction.x*.55,-1.0,direction.y*.55,1.0)*best*grassFlex;
}
float environmentGrassPressedHeight(float t) { return .025*smoothstep(.22,.55,t)+.005*smoothstep(.55,1.0,t); }
vec2 environmentGrassWind(vec2 root) {
  float wave = sin(uGrassTime * ${GRASS_WIND.speed.toFixed(2)} + root.x * .08 + root.y * .055)
    + ${GRASS_WIND.secondary.toFixed(2)} * sin(uGrassTime * ${GRASS_WIND.secondarySpeed.toFixed(2)} + root.x * .13 - root.y * .09);
  float bend = ${GRASS_WIND.amplitude.toFixed(3)} * wave;
  return vec2(bend, bend * ${GRASS_WIND.directionZ.toFixed(2)});
}
`);
    shader.vertexShader=shader.vertexShader.replace('#include <beginnormal_vertex>',`#include <beginnormal_vertex>
vec3 grassRoot = (modelMatrix * instanceMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
float grassHeight = length(instanceMatrix[1].xyz);
vec4 grassContact = environmentGrassContact(grassRoot.xz);
vec2 grassBend = (environmentGrassWind(grassRoot.xz)*grassFlex + grassContact.xz) * grassHeight;
vec3 grassRight = normalize(instanceMatrix[0].xyz);
vec3 grassForward = normalize(instanceMatrix[2].xyz);
vec3 grassWorldBend = vec3(grassBend.x, 0.0, grassBend.y);
vec2 grassLocalBend = vec2(dot(grassWorldBend, grassRight) / length(instanceMatrix[0].xyz), dot(grassWorldBend, grassForward) / length(instanceMatrix[2].xyz));
float grassWeight = clamp(position.y, 0.0, 1.0);
float grassVerticalScale = max(.001, 1.0 + grassContact.y + grassContact.w*.03/max(.1,grassHeight));
objectNormal = normalize(vec3(objectNormal.x * grassVerticalScale, objectNormal.y - dot(objectNormal.xz, grassLocalBend) * 2.0 * grassWeight, objectNormal.z * grassVerticalScale));
vec3 grassSlopeWorld=vec3(grassSlope.x,0.0,grassSlope.y);
vec2 grassLocalSlope=vec2(dot(grassSlopeWorld,grassRight)*length(instanceMatrix[0].xyz),dot(grassSlopeWorld,grassForward)*length(instanceMatrix[2].xyz))/grassHeight;
objectNormal=normalize(vec3(objectNormal.x-grassLocalSlope.x*objectNormal.y,objectNormal.y,objectNormal.z-grassLocalSlope.y*objectNormal.y));
`);
    shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>
float grassFade = 1.0 - smoothstep(uGrassFadeNear, uGrassFadeFar, distance(grassRoot.xz, uGrassFocus));
transformed.xz += grassLocalBend * grassWeight * grassWeight;
transformed.y += grassContact.y * grassWeight + environmentGrassPressedHeight(grassProgress)*grassContact.w/grassHeight;
vec3 grassWorld = (modelMatrix * instanceMatrix * vec4(transformed,1.0)).xyz;
if (grassProgress>0.0 && grassFlex>.9 && grassContact.w>.95 && uGrassFeetCount>0.0) {
  vec2 center=vec2(0.0);
  for(int i=0;i<2;i++){if(float(i)<uGrassFeetCount)center+=(uGrassFeet[i*2].xz+uGrassFeet[i*2+1].xz)/(uGrassFeetCount*2.0);}
  vec2 base=(modelMatrix*instanceMatrix*vec4(grassBase.x,0.0,grassBase.y,1.0)).xz;
  vec2 n=base-center;float nd=length(n);n=nd>.001?n/nd:vec2(1.0,0.0);
  float edge=-1e20;
  for(int i=0;i<2;i++){if(float(i)<uGrassFeetCount){edge=max(edge,dot(uGrassFeet[i*2].xz,n)+uGrassFeet[i*2].w);edge=max(edge,dot(uGrassFeet[i*2+1].xz,n)+uGrassFeet[i*2+1].w);}}
  grassWorld.xz+=n*max(0.0,edge+.018-dot(grassWorld.xz,n));
}
grassWorld.y+=dot(grassSlope,grassWorld.xz-grassRoot.xz);
vec3 grassDelta=grassWorld-(modelMatrix*instanceMatrix*vec4(transformed,1.0)).xyz;
transformed.x += dot(grassDelta,grassRight)/length(instanceMatrix[0].xyz);
transformed.z += dot(grassDelta,grassForward)/length(instanceMatrix[2].xyz);
transformed.y += grassDelta.y/grassHeight;
transformed.y *= grassFade;
transformed.xz *= grassFade;
`);
    material.userData.compiledShader=shader;
  };
  return material;
}

export function createEnvironmentGrass({THREE,plan,limits={}}={}){
  if(!THREE||!plan?.tufts)throw Error('Grass renderer requires THREE and placement plan');
  const budget={...GRASS_LIMITS,...limits},object=new THREE.Group();object.name='EnvironmentGrass';
  const geometries={grass:createGrassTuftGeometry(THREE,'grass'),reed:createGrassTuftGeometry(THREE,'reed'),shrub:createGrassTuftGeometry(THREE,'shrub')},uniforms={uGrassFeet:{value:Array.from({length:4},()=>new THREE.Vector4())},uGrassFeetCount:{value:0},uGrassTrail:{value:Array.from({length:8},()=>new THREE.Vector4(0,0,-1e6,1))},uGrassTime:{value:0},uGrassFocus:{value:new THREE.Vector2()},uGrassFadeNear:{value:budget.fadeStart},uGrassFadeFar:{value:budget.viewDistance}},material=createGrassWindMaterial(THREE,uniforms),chunks=new Map(),matrix=new THREE.Matrix4(),position=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3(),up=new THREE.Vector3(0,1,0),color=new THREE.Color();
  const chunksByRow=new Map();let widestTuftRadius=0;
  for(const tuft of plan.tufts){
    const ix=Math.floor(tuft.x/budget.chunkSize),iz=Math.floor(tuft.z/budget.chunkSize),key=ix+','+iz;
    if(!chunks.has(key)){
      const group=new THREE.Group();group.name='GrassChunk_'+key;object.add(group);
      const chunk={group,ix,iz,order:chunks.size,byStyle:{grass:[],reed:[],shrub:[]},meshes:{},bounds:new THREE.Box3(),center:{x:(ix+.5)*budget.chunkSize,z:(iz+.5)*budget.chunkSize}};
      chunks.set(key,chunk);if(!chunksByRow.has(iz))chunksByRow.set(iz,[]);chunksByRow.get(iz).push(chunk);
    }
    const c=chunks.get(key);matrix.compose(position.set(tuft.x,tuft.y,tuft.z),q.setFromAxisAngle(up,tuft.yaw),scale.set(tuft.width,tuft.height,tuft.width));color.setHex(tuft.color);
    c.byStyle[tuft.style].push({...tuft,matrix:Float32Array.from(matrix.elements),colorArray:[color.r,color.g,color.b],chunk:c});
    widestTuftRadius=Math.max(widestTuftRadius,tuft.radius||0);
    const slopeMargin=tuft.radius*Math.hypot(tuft.slopeX||0,tuft.slopeZ||0);
    c.bounds.expandByPoint(new THREE.Vector3(tuft.x-tuft.radius,tuft.y-.03-slopeMargin,tuft.z-tuft.radius));c.bounds.expandByPoint(new THREE.Vector3(tuft.x+tuft.radius,tuft.y+tuft.height+.03+slopeMargin,tuft.z+tuft.radius));
  }
  let totalTriangles=0,totalBatches=0;
  for(const c of chunks.values())for(const style of['grass','reed','shrub']){
    const tufts=c.byStyle[style];if(!tufts.length)continue;const sourceGeometry=geometries[style],geometry=new THREE.BufferGeometry();geometry.setIndex(sourceGeometry.index);for(const [key,attribute]of Object.entries(sourceGeometry.attributes))geometry.setAttribute(key,attribute);geometry.boundingBox=sourceGeometry.boundingBox;geometry.boundingSphere=sourceGeometry.boundingSphere;geometry.userData=sourceGeometry.userData;geometry.setAttribute('grassSlope',new THREE.InstancedBufferAttribute(new Float32Array(tufts.length*2),2).setUsage(THREE.DynamicDrawUsage));const mesh=new THREE.InstancedMesh(geometry,material,tufts.length);mesh.name='Grass_'+style;mesh.castShadow=false;mesh.receiveShadow=true;
    for(let i=0;i<tufts.length;i++){matrix.fromArray(tufts[i].matrix);mesh.setMatrixAt(i,matrix);color.fromArray(tufts[i].colorArray);mesh.setColorAt(i,color);}
    mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.instanceColor.setUsage(THREE.DynamicDrawUsage);
    mesh.boundingBox=c.bounds.clone();mesh.boundingSphere=new THREE.Sphere();c.bounds.getBoundingSphere(mesh.boundingSphere);mesh.userData.tuftIds=[];mesh.count=0;mesh.visible=false;c.meshes[style]=mesh;c.group.add(mesh);totalBatches++;totalTriangles+=geometry.index.count/3*tufts.length;
  }
  const stats={...plan.stats,totalBatches,totalTriangles,chunks:chunks.size,visibleTufts:0,visibleBatches:0,visibleTriangles:0,fadeFar:budget.viewDistance,dynamicLights:0,shadowCasters:0,solidBlades:true};object.userData.environmentGrass=stats;
  const frustum=new THREE.Frustum(),projection=new THREE.Matrix4(),candidates=[],selectionChunks=[];const activeChunks=new Set(),maxCandidates=Math.max(1,Math.floor(budget.maxVisibleTufts)+1);let lastSelection=-Infinity,lastFocus=null,lastCameraQuaternion=null;
  let trailCursor=0,lastActor=null;
  function update({time=0,focus,camera,actorPosition,actorRadius=.65,actorFeet=[],actorGround,force=false}={}){
    uniforms.uGrassFeetCount.value=actorPosition?Math.min(2,actorFeet.length):0;
    for(let i=0;i<uniforms.uGrassFeetCount.value;i++){const f=actorFeet[i];uniforms.uGrassFeet.value[i*2].set(f.heel.x,f.heel.y,f.heel.z,f.radius);uniforms.uGrassFeet.value[i*2+1].set(f.toe.x,f.toe.y,f.toe.z,f.radius);}
    if(actorPosition&&Number.isFinite(actorPosition.x+actorPosition.z)){
      if(!lastActor||Math.hypot(actorPosition.x-lastActor.x,actorPosition.z-lastActor.z)>=GRASS_CONTACT.sampleDistance){trailCursor=(trailCursor+1)%8;lastActor={x:actorPosition.x,z:actorPosition.z};}
      uniforms.uGrassTrail.value[trailCursor].set(actorPosition.x,actorPosition.z,time,Math.max(.2,actorRadius)+.4);
    }
    uniforms.uGrassTime.value=Number.isFinite(time)?time:0;if(!focus||!Number.isFinite(focus.x+focus.z))return;
    uniforms.uGrassFocus.value.set(focus.x,focus.z);
    const cameraMoved=!!camera&&(!lastCameraQuaternion||camera.quaternion.angleTo(lastCameraQuaternion)>.1);
    if(!force&&!cameraMoved&&time>=lastSelection&&time-lastSelection<.25&&lastFocus&&Math.hypot(focus.x-lastFocus.x,focus.z-lastFocus.z)<4)return;
    lastSelection=time;lastFocus={x:focus.x,z:focus.z};
    if(camera){camera.updateMatrixWorld();lastCameraQuaternion=camera.quaternion.clone();projection.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);frustum.setFromProjectionMatrix(projection);}
    // Selecting a dense forest used to scan every chunk in the whole map and
    // clear every batch. A chunk can reach the view circle only when its fixed
    // source cell is nearby (with the widest authored tuft as a conservative
    // margin), so query only those rows/cells. Sorting by construction order
    // preserves the legacy Map traversal tie order exactly.
    for(const c of activeChunks){c.group.visible=false;for(const style of['grass','reed','shrub']){const mesh=c.meshes[style];if(!mesh)continue;mesh.count=0;mesh.visible=false;mesh.userData.tuftIds.length=0;}}
    activeChunks.clear();selectionChunks.length=0;
    const selectionRadius=budget.viewDistance+widestTuftRadius,minimumX=Math.floor((focus.x-selectionRadius)/budget.chunkSize),maximumX=Math.floor((focus.x+selectionRadius)/budget.chunkSize),minimumZ=Math.floor((focus.z-selectionRadius)/budget.chunkSize),maximumZ=Math.floor((focus.z+selectionRadius)/budget.chunkSize);
    for(let iz=minimumZ;iz<=maximumZ;iz++){const row=chunksByRow.get(iz);if(!row)continue;for(const c of row)if(c.ix>=minimumX&&c.ix<=maximumX)selectionChunks.push(c);}
    selectionChunks.sort((a,b)=>a.order-b.order);
    candidates.length=0;let candidateOrder=0;
    for(const c of selectionChunks){
      const b=c.bounds,minDistance=Math.hypot(Math.max(b.min.x-focus.x,0,focus.x-b.max.x),Math.max(b.min.z-focus.z,0,focus.z-b.max.z));
      if(minDistance>budget.viewDistance||(camera&&!frustum.intersectsBox(b)))continue;
      for(const style of['grass','reed','shrub'])for(const tuft of c.byStyle[style]){const d=Math.hypot(tuft.x-focus.x,tuft.z-focus.z);if(d<budget.viewDistance){tuft._selectionDistance=d;tuft._selectionOrder=candidateOrder++;retainNearestGrassCandidate(candidates,tuft,maxCandidates);}}
    }
    sortNearestGrassCandidates(candidates);
    stats.visibleTufts=0;stats.visibleBatches=0;stats.visibleTriangles=0;let cutoff=budget.viewDistance,budgetReached=false;
    for(const tuft of candidates){const d=tuft._selectionDistance;
      const c=tuft.chunk,mesh=c.meshes[tuft.style],triangles=mesh.geometry.index.count/3;
      if(stats.visibleTufts>=budget.maxVisibleTufts||stats.visibleTriangles+triangles>budget.maxVisibleTriangles){cutoff=d;budgetReached=true;break;}
      if(!mesh.visible&&stats.visibleBatches>=budget.maxVisibleBatches){cutoff=d;budgetReached=true;break;}
      if(!mesh.visible){mesh.visible=true;c.group.visible=true;activeChunks.add(c);stats.visibleBatches++;}
      const index=mesh.count++;mesh.instanceMatrix.array.set(tuft.matrix,index*16);mesh.geometry.attributes.grassSlope.setXY(index,tuft.slopeX||0,tuft.slopeZ||0);mesh.instanceColor.array.set(tuft.colorArray,index*3);mesh.userData.tuftIds.push(tuft.id);stats.visibleTufts++;stats.visibleTriangles+=triangles;
    }
    // The outermost chosen blades have zero height; crossing a chunk/budget boundary
    // therefore replaces invisible roots instead of abruptly popping whole patches.
    uniforms.uGrassFadeFar.value=budgetReached?Math.max(4,cutoff-.4):budget.viewDistance;
    uniforms.uGrassFadeNear.value=Math.min(budget.fadeStart,uniforms.uGrassFadeFar.value*.68);stats.fadeFar=uniforms.uGrassFadeFar.value;
    for(const c of activeChunks)for(const style of['grass','reed','shrub']){const mesh=c.meshes[style];if(mesh?.visible){mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.needsUpdate=true;mesh.geometry.attributes.grassSlope.needsUpdate=true;}}
  }
  return {object,stats,update,uniforms,limits:budget,dispose(){for(const c of chunks.values())for(const mesh of Object.values(c.meshes)){mesh.geometry.dispose();mesh.dispose()}for(const g of Object.values(geometries))g.dispose();material.dispose();object.clear();}};
}
