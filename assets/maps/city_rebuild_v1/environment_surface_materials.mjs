// World-space clay surfaces. No UVs, texture fetches, geometry animation or extra render passes.
const PRESETS=Object.freeze({
 grass:{color:'#748d68',roughness:.94,mode:0,bump:.006},
 ground:{color:'#819076',roughness:.94,mode:0,bump:.006},
 trail:{color:'#b8aa8c',roughness:.96,mode:1,bump:.008},
 asphalt:{color:'#525b59',roughness:.88,mode:2,bump:.002},
 paving:{color:'#c0bda7',roughness:.89,mode:3,bump:.006},
 sand:{color:'#cfbd96',roughness:.97,mode:4,bump:.021},
 water:{color:'#ffffff',roughness:.23,mode:5,bump:0}
});
const COMMON=`
varying vec3 vEnvironmentWorld;
uniform float environmentTime;
float environmentHash(vec2 p) {
 vec3 p3=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float environmentNoise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(environmentHash(i),environmentHash(i+vec2(1.,0.)),f.x),mix(environmentHash(i+vec2(0.,1.)),environmentHash(i+vec2(1.,1.)),f.x),f.y);
}
`;
const WATER_COMMON=`
varying float vEnvironmentDepth;
uniform vec3 environmentShallow;
uniform vec3 environmentDeep;
uniform vec3 environmentShore;
uniform vec4 environmentRipples[8];
float environmentWaveFilter(float phase) {
 // Phase radians per pixel; disappear before the pi-radian Nyquist limit.
 return 1.0-smoothstep(.55,2.40,fwidth(phase));
}
vec3 environmentWaterWarpTerm(vec2 point,vec2 direction,float phase,float amplitude) {
 // Height-independent domain warp and its exact spatial derivatives.
 float angle=dot(point,direction)+phase;
 return vec3(sin(angle)*amplitude,cos(angle)*amplitude*direction);
}
float environmentWaterCoverage(float depth,float shoreNoise,float depthAA) {
 // Actual terrain-clipped boundary has depth zero. Fresnel/foam must never
 // restore opacity there. Noise only varies transition width inside the lake.
 float feather=.14+.09*shoreNoise+clamp(depthAA,0.0,.06);
 return smoothstep(0.0,feather,depth);
}
vec3 environmentRippleAt(vec4 event,vec2 point,float footprint) {
 if(event.w<=0.0 || event.z<0.0 || event.z>4.5) return vec3(0.0);
 vec2 delta=point-event.xy;
 float radius=.08+event.z*1.35,width=.24+event.z*.10;
 float distanceSquared=dot(delta,delta),outer=radius+width*2.6,inner=max(0.0,radius-width*2.6);
 // Cull pixels outside the thin expanding annulus before sqrt/trigonometry.
 if(distanceSquared>outer*outer || distanceSquared<inner*inner) return vec3(0.0);
 float distanceToEvent=sqrt(max(distanceSquared,.000001)),travel=distanceToEvent-radius;
 float envelope=(1.0-smoothstep(width,width*2.6,abs(travel)))*(1.0-smoothstep(.15,4.5,event.z))/(1.0+distanceToEvent*.45);
 float filtered=1.0-smoothstep(.55,2.40,footprint*12.0);
 float phase=travel*12.0,amplitude=envelope*event.w*filtered;
 return vec3(delta/max(distanceToEvent,.001)*cos(phase)*amplitude*.065,(.5+.5*sin(phase))*amplitude*.026);
}
`;
export const WATER_RIPPLE_CAPACITY=8;
export const WATER_RIPPLE_MAX_AGE=4.5;
function inject(source,needle,code){if(!source.includes(needle))throw new Error('Environment material: unsupported Three shader chunk '+needle);return source.replace(needle,code)}

/** Exported for testing against the exact THREE.ShaderLib.standard source used by the game. */
export function patchEnvironmentSurfaceShader(shader,{kind,uniforms}){
 const preset=PRESETS[kind];if(!preset)throw new Error('Unknown environment surface '+kind);const water=kind==='water';
 Object.assign(shader.uniforms,uniforms);
 shader.vertexShader=inject(shader.vertexShader,'#include <common>',`#include <common>\nvarying vec3 vEnvironmentWorld;${water?'\nattribute float surfaceDepth;\nvarying float vEnvironmentDepth;':''}`);
 shader.vertexShader=inject(shader.vertexShader,'#include <worldpos_vertex>',`#include <worldpos_vertex>
 vec4 environmentPosition=vec4(transformed,1.0);
 #ifdef USE_BATCHING
  environmentPosition=batchingMatrix*environmentPosition;
 #endif
 #ifdef USE_INSTANCING
  environmentPosition=instanceMatrix*environmentPosition;
 #endif
 vEnvironmentWorld=(modelMatrix*environmentPosition).xyz;
 ${water?'vEnvironmentDepth=max(0.0,surfaceDepth);':''}`);
 shader.fragmentShader=inject(shader.fragmentShader,'#include <common>','#include <common>\n'+COMMON+(water?WATER_COMMON:''));
 if(water){
  shader.fragmentShader=inject(shader.fragmentShader,'#include <color_fragment>',`#include <color_fragment>
   float environmentDepth=max(0.0,vEnvironmentDepth);
   float environmentAbsorption=1.0-exp(-environmentDepth*.56);
   vec2 environmentWaterXZ=vEnvironmentWorld.xz;
   vec2 environmentFlow=vec2(environmentTime*.065,-environmentTime*.044);
   vec3 environmentWarpA=environmentWaterWarpTerm(environmentWaterXZ,vec2(.13,.08),environmentTime*.11,1.6);
   vec3 environmentWarpB=environmentWaterWarpTerm(environmentWaterXZ,vec2(-.07,.19),-environmentTime*.09,.65);
   vec3 environmentWarpC=environmentWaterWarpTerm(environmentWaterXZ,vec2(-.09,.115),-environmentTime*.08,1.3);
   vec3 environmentWarpD=environmentWaterWarpTerm(environmentWaterXZ,vec2(.17,.035),environmentTime*.12,.55);
   vec2 environmentWaterDomain=environmentWaterXZ+vec2(environmentWarpA.x+environmentWarpB.x,environmentWarpC.x+environmentWarpD.x);
   vec2 environmentDomainDx=vec2(1.0+environmentWarpA.y+environmentWarpB.y,environmentWarpC.y+environmentWarpD.y);
   vec2 environmentDomainDz=vec2(environmentWarpA.z+environmentWarpB.z,1.0+environmentWarpC.z+environmentWarpD.z);
   float environmentWaveA=dot(environmentWaterDomain,vec2(.8,.6))*.72+environmentTime*.61;
   float environmentWaveB=dot(environmentWaterDomain,vec2(-.42,.907))*1.31-environmentTime*.87;
   float environmentWaveC=dot(environmentWaterDomain,vec2(.96,-.28))*3.70+environmentTime*1.29;
   float environmentWaveD=dot(environmentWaterDomain,vec2(.28,.96))*6.25-environmentTime*1.71;
   float environmentWaveE=dot(environmentWaterDomain,vec2(-.91,.415))*10.5+environmentTime*2.08;
   float environmentWaveF=dot(environmentWaterDomain,vec2(.65,.76))*17.2-environmentTime*2.76;
   float environmentFootprint=max(length(dFdx(environmentWaterXZ)),length(dFdy(environmentWaterXZ)));
   float environmentFilterA=environmentWaveFilter(environmentWaveA),environmentFilterB=environmentWaveFilter(environmentWaveB);
   float environmentFilterC=environmentWaveFilter(environmentWaveC),environmentFilterD=environmentWaveFilter(environmentWaveD);
   float environmentFilterE=environmentWaveFilter(environmentWaveE),environmentFilterF=environmentWaveFilter(environmentWaveF);
   vec2 environmentDomainSlope=vec2(.8,.6)*cos(environmentWaveA)*.039*environmentFilterA
    +vec2(-.42,.907)*cos(environmentWaveB)*.036*environmentFilterB
    +vec2(.96,-.28)*cos(environmentWaveC)*.037*environmentFilterC
    +vec2(.28,.96)*cos(environmentWaveD)*.022*environmentFilterD
    +vec2(-.91,.415)*cos(environmentWaveE)*.011*environmentFilterE
    +vec2(.65,.76)*cos(environmentWaveF)*.006*environmentFilterF;
   // Chain rule: changing phase coordinates must also bend the shading normals.
   vec2 environmentWaveSlope=vec2(dot(environmentDomainDx,environmentDomainSlope),dot(environmentDomainDz,environmentDomainSlope));
   vec3 environmentDisturbance=vec3(0.0);
   ${Array.from({length:WATER_RIPPLE_CAPACITY},(_,i)=>`environmentDisturbance+=environmentRippleAt(environmentRipples[${i}],environmentWaterXZ,environmentFootprint);`).join('\n   ')}
   environmentWaveSlope=(environmentWaveSlope+environmentDisturbance.xy)*mix(.38,1.0,smoothstep(0.0,.70,environmentDepth));
   // World-oriented analytic sky tint: standard scene lighting still controls
   // all radiance. This is not a screen-space reflection or an emissive layer.
   vec3 environmentWaterNormal=normalize(vec3(-environmentWaveSlope.x,1.0,-environmentWaveSlope.y));
   vec3 environmentEye=normalize(cameraPosition-vEnvironmentWorld);
   float environmentFacing=clamp(dot(environmentWaterNormal,environmentEye),0.0,1.0);
   float environmentFresnel=.0204+.9796*pow(1.0-environmentFacing,5.0);
   vec3 environmentReflection=reflect(-environmentEye,environmentWaterNormal);
   vec3 environmentSkyTint=mix(vec3(.18,.28,.30),vec3(.10,.21,.29),smoothstep(0.0,.85,environmentReflection.y));
   float environmentShoreNoiseFade=1.0-smoothstep(.12,.45,environmentFootprint*.82);
   float environmentShoreNoise=mix(.5,environmentNoise(environmentWaterXZ*.82+environmentFlow),environmentShoreNoiseFade);
   float environmentShoreAA=max(fwidth(environmentDepth)*1.25,.006);
   float environmentCoverage=environmentWaterCoverage(environmentDepth,environmentShoreNoise,environmentShoreAA);
   float environmentShoreFront=.045+.035*environmentShoreNoise+.008*sin(environmentWaveA)*environmentFilterA;
   float environmentShoreBand=1.0-smoothstep(.012,.036+min(environmentShoreAA,.028),abs(environmentDepth-environmentShoreFront));
   float environmentFoam=environmentShoreBand*smoothstep(.60,.86,environmentShoreNoise+.05*sin(environmentWaveB)*environmentFilterB)*(1.0-smoothstep(.12,.28,environmentDepth))*.16;
   float environmentWetEdge=1.0-smoothstep(.025,.20,environmentDepth);
   // Sparse, softly broken shallow glints, not zero-contours of crossing waves.
   vec2 environmentCausticCoord=environmentWaterDomain*.68+environmentFlow*.4+vec2(37.2,-19.4);
   vec2 environmentCausticBreakCoord=environmentWaterDomain*1.49-environmentFlow*.55+vec2(-8.3,42.7);
   float environmentCausticField=environmentNoise(environmentCausticCoord);
   float environmentCausticBreak=environmentNoise(environmentCausticBreakCoord);
   float environmentCausticAA=max(fwidth(environmentCausticField),.025);
   float environmentCausticBreakAA=max(fwidth(environmentCausticBreak),.025);
   float environmentCausticFootprint=max(max(fwidth(environmentCausticCoord.x),fwidth(environmentCausticCoord.y)),max(fwidth(environmentCausticBreakCoord.x),fwidth(environmentCausticBreakCoord.y)));
   float environmentCausticFade=1.0-smoothstep(.12,.45,environmentCausticFootprint);
   float environmentCaustic=smoothstep(.67-environmentCausticAA,.87+environmentCausticAA,environmentCausticField)*smoothstep(.60-environmentCausticBreakAA,.84+environmentCausticBreakAA,environmentCausticBreak);
   environmentCaustic*=environmentCausticFade*smoothstep(.04,.20,environmentDepth)*(1.0-smoothstep(.40,1.15,environmentDepth))*smoothstep(.18,.55,environmentFacing)*.026;
   diffuseColor.rgb=mix(environmentShallow,environmentDeep,environmentAbsorption);
   diffuseColor.rgb=mix(diffuseColor.rgb,environmentSkyTint,environmentFresnel*.36);
   // The first translucent centimetres show dark wet sediment, not a white rim.
   // This stays inside the existing water surface; dry bank/physics are untouched.
   vec3 environmentWetSediment=mix(environmentShallow*.28,environmentShore*.16,.75);
   diffuseColor.rgb=mix(diffuseColor.rgb,environmentWetSediment,environmentWetEdge*.76);
   diffuseColor.rgb+=environmentShore*(environmentCaustic+environmentDisturbance.z);
   diffuseColor.rgb=mix(diffuseColor.rgb,environmentShore,environmentFoam);
   diffuseColor.a*=environmentCoverage*clamp(mix(.82,1.0,environmentAbsorption)+environmentFoam*.10+environmentFresnel*.12,0.0,1.0);
  `);
  shader.fragmentShader=inject(shader.fragmentShader,'#include <roughnessmap_fragment>',`#include <roughnessmap_fragment>
   roughnessFactor=clamp(roughnessFactor+.038*(1.0-environmentAbsorption)+.017*sin(environmentWaveB)*environmentFilterB+environmentFoam*.24,.18,.39);
  `);
  shader.fragmentShader=inject(shader.fragmentShader,'#include <normal_fragment_maps>',`#include <normal_fragment_maps>
   normal=normalize(normal+mat3(viewMatrix)*vec3(-environmentWaveSlope.x,0.0,-environmentWaveSlope.y));
  `);
 }else{
  shader.fragmentShader=inject(shader.fragmentShader,'#include <color_fragment>',`#include <color_fragment>
   vec2 environmentXZ=vEnvironmentWorld.xz;
   float environmentFootprint=max(length(dFdx(environmentXZ)),length(dFdy(environmentXZ)));
   float environmentBroad=environmentNoise(environmentXZ*.055);
   float environmentMottling=environmentNoise(environmentXZ*${preset.mode===0?'.24':preset.mode===2?'.19':'.53'}+vec2(17.3,9.1));
   float environmentRelief=(environmentMottling-.5)*.20;
   float environmentShade=1.0;
   ${preset.mode===0?`
    // Quiet soil under real grass blades: metres-wide tonal areas, no tiny bump carpet.
    environmentShade=.96+.095*(environmentBroad-.5)+.035*(environmentMottling-.5);
    #if !defined(USE_COLOR) && !defined(USE_COLOR_ALPHA)
     diffuseColor.rgb*=mix(vec3(.97,1.0,.96),vec3(1.025,1.0,.97),environmentBroad);
    #endif
   `:preset.mode===1?`
    vec2 environmentGrainCoord=environmentXZ*9.0;
    float environmentGrainFootprint=max(fwidth(environmentGrainCoord.x),fwidth(environmentGrainCoord.y));
    float environmentFineFade=1.0-smoothstep(.10,.40,environmentGrainFootprint);
    float environmentGrain=environmentNoise(environmentGrainCoord);
    environmentShade=.98+.09*(environmentBroad-.5)+.035*(environmentMottling-.5)+.012*(environmentGrain-.5)*environmentFineFade;
    environmentRelief+=(environmentGrain-.5)*.03*environmentFineFade;
   `:preset.mode===2?`
    // Aggregate is sub-centimetre relief and only survives at close viewing distances.
    vec2 environmentGrainCoord=environmentXZ*55.0;
    float environmentGrainFootprint=max(fwidth(environmentGrainCoord.x),fwidth(environmentGrainCoord.y));
    float environmentFineFade=1.0-smoothstep(.10,.40,environmentGrainFootprint);
    float environmentGrain=environmentNoise(environmentGrainCoord);
    float environmentWear=smoothstep(.57,.83,environmentMottling)*smoothstep(.30,.68,environmentBroad);
    environmentShade=.985+.035*(environmentBroad-.5)+.035*environmentWear+.035*(environmentGrain-.5)*environmentFineFade;
    environmentRelief=(environmentGrain-.5)*.10*environmentFineFade;
   `:preset.mode===3?`
    // Staggered limestone slabs: variation belongs to each stone, not a noise overlay.
    vec2 environmentTile=environmentXZ/vec2(1.45,.90);
    environmentTile.x+=mod(floor(environmentTile.y),2.0)*.5;
    vec2 environmentCell=floor(environmentTile),environmentLocal=fract(environmentTile);
    vec2 environmentEdge=min(environmentLocal,1.0-environmentLocal)*vec2(1.45,.90);
    float environmentDistance=min(environmentEdge.x,environmentEdge.y);
    float environmentAA=max(environmentFootprint*.7,.001);
    float environmentJoint=1.0-smoothstep(.004,.012+environmentAA,environmentDistance);
    float environmentBevel=1.0-smoothstep(.008,.034+environmentAA,environmentDistance);
    float environmentStoneFade=1.0-smoothstep(.08,.38,environmentFootprint);
    float environmentStoneTone=environmentHash(environmentCell+vec2(43.1,71.7))-.5;
    environmentShade=.99+.075*environmentStoneTone*environmentStoneFade+.022*(environmentBroad-.5)+.014*(environmentMottling-.5)-environmentJoint*.095*environmentStoneFade;
    environmentRelief=-environmentBevel*.45*environmentStoneFade;
   `:`
    float environmentSandPhase=environmentXZ.x*4.8+environmentXZ.y*.9+environmentMottling*1.6;
    float environmentSandRidge=sin(environmentSandPhase);
    float environmentSandFade=1.0-smoothstep(.30,1.30,fwidth(environmentSandPhase));
    environmentShade=.98+.08*(environmentBroad-.5)+.014*environmentSandRidge*environmentSandFade;
    environmentRelief+=environmentSandRidge*.07*environmentSandFade;
   `}
   diffuseColor.rgb*=environmentShade;
  `);
  shader.fragmentShader=inject(shader.fragmentShader,'#include <roughnessmap_fragment>',`#include <roughnessmap_fragment>
   roughnessFactor=clamp(roughnessFactor+(environmentMottling-.5)*.055,.75,1.0);
  `);
  shader.fragmentShader=inject(shader.fragmentShader,'#include <normal_fragment_maps>',`#include <normal_fragment_maps>
   vec3 environmentDx=dFdx(-vViewPosition),environmentDy=dFdy(-vViewPosition);
   vec3 environmentR1=cross(environmentDy,normal),environmentR2=cross(normal,environmentDx);
   float environmentDet=dot(environmentDx,environmentR1);
   vec3 environmentGradient=sign(environmentDet)*(dFdx(environmentRelief)*environmentR1+dFdy(environmentRelief)*environmentR2);
   normal=normalize(abs(environmentDet)*normal-environmentGradient*${preset.bump.toFixed(3)}+normal*1e-8);
  `);
 }
 return shader;
}

export function createEnvironmentSurfaceMaterials({THREE}={}){
 if(!THREE?.MeshStandardMaterial)throw new Error('THREE is required');
 const cache=new Map(),timeUniform={value:0},depthGeometries=new WeakSet();let epoch=null,disposed=false,preparedMeshes=0,preparedWaterVertices=0,waterRippleCount=0;
 const rippleVectors=Array.from({length:WATER_RIPPLE_CAPACITY},()=>new THREE.Vector4(0,0,-1,0));
 const sharedUniforms={environmentTime:timeUniform,environmentShallow:{value:new THREE.Color('#428c82')},environmentDeep:{value:new THREE.Color('#124d5e')},environmentShore:{value:new THREE.Color('#bbcbb7')},environmentRipples:{value:rippleVectors}};
 function materialFor(kind,options={}){
  if(disposed)throw new Error('Environment surfaces already disposed');const preset=PRESETS[kind];if(!preset)throw new Error('Unknown environment surface '+kind);
  const vertexColors=!!options.vertexColors,color=options.color??(vertexColors?'#ffffff':preset.color),side=options.side??(kind==='trail'?THREE.DoubleSide:THREE.FrontSide),key=JSON.stringify([kind,vertexColors,color,side]);if(cache.has(key))return cache.get(key);
  const water=kind==='water',material=new THREE.MeshStandardMaterial({color,roughness:preset.roughness,metalness:water?.02:0,vertexColors,side,transparent:water,opacity:water?.92:1,depthWrite:!water,polygonOffset:kind==='trail',polygonOffsetFactor:kind==='trail'?-1:0,polygonOffsetUnits:kind==='trail'?-1:0});
  material.name='Environment surface · '+kind;material.userData.environmentSurface=true;material.userData.surfaceKind=kind;material.userData.environmentRevision=water?6:3;material.envMapIntensity=water?.7:1;material.defaultAttributeValues={surfaceDepth:[2.5]};
  material.onBeforeCompile=shader=>patchEnvironmentSurfaceShader(shader,{kind,uniforms:sharedUniforms});material.customProgramCacheKey=()=>`environment-surface-v${water?6:3}:${kind}:${vertexColors?1:0}`;cache.set(key,material);return material;
 }
 function prepareMesh(mesh,{kind,depthAt,vertexColors=!!mesh?.geometry?.getAttribute('color'),...options}={}){
  if(!mesh?.geometry?.getAttribute('position'))throw new Error('Environment surface requires mesh position geometry');
  if(kind==='water'&&!depthGeometries.has(mesh.geometry)){
   mesh.updateWorldMatrix(true,false);const position=mesh.geometry.getAttribute('position'),values=new Float32Array(position.count),p=new THREE.Vector3();
   for(let i=0;i<position.count;i++){p.fromBufferAttribute(position,i).applyMatrix4(mesh.matrixWorld);const value=depthAt?depthAt(p.x,p.z,p.y):2.5,depth=typeof value==='number'?value:value?.depth??0;values[i]=Number.isFinite(depth)?Math.max(0,Math.min(50,depth)):0}
   mesh.geometry.setAttribute('surfaceDepth',new THREE.Float32BufferAttribute(values,1));depthGeometries.add(mesh.geometry);preparedWaterVertices+=position.count;
  }
  mesh.material=materialFor(kind,{vertexColors,...options});mesh.userData.environmentSurface=kind;mesh.userData.surfaceKind=kind;
  if(kind==='water'){mesh.castShadow=false;mesh.receiveShadow=true;mesh.renderOrder=1}
  preparedMeshes++;return mesh;
 }
 function update(timeSeconds){if(disposed||!Number.isFinite(timeSeconds))return;if(epoch===null)epoch=timeSeconds;timeUniform.value=Math.max(0,timeSeconds-epoch)}
 /** Presentation-only: caller owns ripple events and advances age in seconds.
  * Reads at most eight input records; invalid, expired or zero-strength slots
  * are disabled. Reuses uniform storage and never changes water geometry. */
 function setWaterRipples(events=[]){
  if(disposed)return 0;waterRippleCount=0;
  for(let i=0;i<WATER_RIPPLE_CAPACITY;i++){
   const event=Array.isArray(events)?events[i]:null,valid=event&&Number.isFinite(event.x)&&Number.isFinite(event.z)&&Number.isFinite(event.age)&&event.age>=0&&event.age<=WATER_RIPPLE_MAX_AGE&&Number.isFinite(event.strength)&&event.strength>0;
   if(valid){rippleVectors[i].set(event.x,event.z,event.age,Math.min(2,event.strength));waterRippleCount++;}else rippleVectors[i].set(0,0,-1,0);
  }
  return waterRippleCount;
 }
 function dispose(){if(disposed)return;disposed=true;for(const material of cache.values())material.dispose();cache.clear()}
 return {materialFor,prepareMesh,update,setWaterRipples,dispose,get waterMaterial(){return materialFor('water')},get stats(){return {materials:cache.size,preparedMeshes,preparedWaterVertices,time:timeUniform.value,waterRipples:waterRippleCount,waterRippleCapacity:WATER_RIPPLE_CAPACITY,passesPerMesh:1,textureFetches:0,extraLights:0}}};
}
