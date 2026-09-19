// Fixed GPU pools. Vehicle damage owns ignition/explosion timing and authority.
// These world-upright billboards add no colliders, damage or secondary blasts.
const vertex=`
attribute vec4 particle;
uniform float uTime,uAge,uSince,uFade,uBurn,uSmoke,uBurst,uSize;
uniform vec3 uEngine,uCenter,uGround;
varying vec2 vUv;varying float vAlpha,vAge,vSeed;
void main(){
 vUv=uv;vSeed=particle.x;float a=particle.x*6.2831853,age=0.,alpha=1.;vec3 center=uEngine;vec2 size=vec2(1.);
 #if MODE == 0
 float life=.75+particle.y*.65;age=fract(max(0.,uSince-particle.w*.42)/life);alpha=uBurn*step(particle.w*.42,uSince)*sin(age*3.14159);
 center+=vec3(cos(a)*(.26+particle.z*.42)*uSize+sin(uTime*4.+a)*age*.16,.15+age*(1.25+particle.y*.75)*uSize,sin(a)*(.23+particle.z*.5)*uSize);
 size=vec2((.48+particle.z*.32)*(1.-age*.52),(.82+particle.y*.85)*(1.-age*.35))*uSize;
 #elif MODE == 1
 float life=3.4+particle.y*1.4;age=fract(max(0.,uSince-particle.w*2.2)/life);alpha=uSmoke*step(particle.w*2.2,uSince)*smoothstep(0.,.12,age)*(1.-smoothstep(.6,1.,age));
 center+=vec3(cos(a)*(.25+age*.65)+age*age*1.45,.3+age*(4.8+particle.z*1.8),sin(a)*(.28+age*.8)+sin(age*5.+a)*age*.45)*uSize;
 size=vec2(.65+age*(2.2+particle.y*.8))*uSize;
 #elif MODE == 2
 age=uAge;alpha=uBurst*step(0.,age)*(1.-smoothstep(.34,.92,age));float travel=pow(max(age,0.),.48);
 center=uCenter+vec3(cos(a)*travel*(.6+particle.y*1.3),.2+travel*(particle.z*1.55)+age*.6,sin(a)*travel*(.6+particle.y*1.3))*uSize;
 size=vec2((.5+travel*(1.25+particle.z*.85))*uSize);
 #elif MODE == 3
 age=uAge;alpha=uBurst*step(0.,age)*smoothstep(0.,.09,age)*(1.-smoothstep(.5,2.2,age));
 center=uGround+vec3(cos(a)*(1.+age*(1.4+particle.y*1.7)),.16+age*.20,sin(a)*(1.+age*(1.4+particle.y*1.7)))*uSize;
 size=vec2(.6+age*1.4,.30+age*.60)*uSize;
 #else
 float life=1.2+particle.y*1.8;age=fract(max(0.,uSince-particle.w)/life);alpha=uBurn*step(particle.w,uSince)*sin(age*3.14159);
 center+=vec3(cos(a)*age*(.4+particle.y),.4+age*(1.8+particle.z*2.)-age*age*.9,sin(a)*age*(.4+particle.z))*uSize;
 if(uBurst>.5&&uAge<1.6){age=uAge;alpha=step(0.,age)*(1.-smoothstep(.4,1.6,age));center=uCenter+vec3(cos(a)*age*(2.+particle.y*3.),.4+age*(3.+particle.z*3.)-3.*age*age,sin(a)*age*(2.+particle.y*3.))*uSize;}
 size=vec2(.015+particle.y*.015,.07+particle.z*.09)*uSize;
 #endif
 vAlpha=alpha*uFade;vAge=age;vec4 mv=viewMatrix*vec4(center,1.);mv.xy+=position.xy*size;gl_Position=projectionMatrix*mv;
}`;
const fragment=`
precision highp float;
uniform float uTime,uAge;
varying vec2 vUv;varying float vAlpha,vAge,vSeed;
float hash(vec3 p){p=fract(p*.3183099+vec3(.13,.71,.29));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){return noise(p)*.57+noise(p*2.07)*.28+noise(p*4.11)*.15;}
void main(){
 vec2 q=vUv*2.-1.;float alpha=vAlpha;vec3 color=vec3(1.);
 #if MODE == 0
 float n=fbm(vec3(q.x*3.+vSeed*23.,q.y*3.-uTime*3.,uTime*.45));float width=mix(.88,.18,vUv.y)+sin(vUv.y*9.-uTime*7.+vSeed*20.)*.12;
 float shape=(1.-smoothstep(width-.25,width+.18,abs(q.x)+(n-.5)*.55))*(1.-smoothstep(.55,1.,q.y))*smoothstep(-1.,-.7,q.y);
 float hot=clamp((1.-vUv.y)*.8+(1.-abs(q.x))*.5+n*.30,0.,1.);color=mix(vec3(.8,.025,.002),vec3(1.9,.43,.035),smoothstep(.18,.7,hot));color=mix(color,vec3(2.8,1.9,.53),smoothstep(.77,1.,hot));alpha*=shape*.82;
 #elif MODE == 1
 float n=fbm(vec3(q*2.7+vSeed*29.,uTime*.22));float r=length(q);float density=1.-smoothstep(.38,.99,r+(n-.5)*.48);float light=clamp(.23+n*.33-q.y*.055-q.x*.04,0.,1.);
 color=mix(vec3(.025,.029,.032),vec3(.24,.235,.22),light);color+=vec3(.1,.036,.006)*(1.-vAge)*density;alpha*=density*.43;
 #elif MODE == 2
 float n=fbm(vec3(q*3.+vSeed*31.,uTime*.8));float density=1.-smoothstep(.25,1.,length(q)+(n-.5)*.55);float hot=clamp(1.-vAge*.85-length(q)*.48+n*.35,0.,1.);
 color=mix(vec3(.48,.025,.003),vec3(2.3,.54,.045),smoothstep(.15,.7,hot));color=mix(color,vec3(3.5,2.6,1.3),smoothstep(.78,1.,hot));alpha*=density*.74;
 #elif MODE == 3
 float n=fbm(vec3(q*2.5+vSeed*13.,uTime*.2));alpha*=(1.-smoothstep(.22,1.,length(q)+(n-.5)*.35))*.22;color=vec3(.36,.325,.265)*( .8+n*.3);
 #else
 alpha*=(1.-smoothstep(.2,1.,abs(q.x)))*(1.-smoothstep(.25,1.,abs(q.y)));color=vec3(3.,.85,.10);
 #endif
 if(alpha<.006)discard;gl_FragColor=vec4(color,alpha);
 #include <colorspace_fragment>
}`;

export function createVehicleFireFx(T,car,{scene=car.object.parent,groundHeight=()=>0}={}){
 const object=new T.Group();object.name='Vehicle_fire_plume';object.userData.crashDeform=false;(scene||car.object).add(object);
 const engine=new T.Vector3(),center=new T.Vector3(),ground=new T.Vector3(),localEngine=new T.Vector3();
 const bounds=car.hoodSpec?.engineBounds;localEngine.set(bounds?(bounds.min[0]+bounds.max[0])*.5:0,bounds?(bounds.min[1]+bounds.max[1])*.5:.8,bounds?(bounds.min[2]+bounds.max[2])*.5:1.0);
 const size=Math.max(.85,Math.min(1.55,Math.sqrt((car.profile?.width||2)/2))),uniforms={uTime:{value:0},uAge:{value:0},uSince:{value:0},uFade:{value:0},uBurn:{value:0},uSmoke:{value:0},uBurst:{value:0},uSize:{value:size},uEngine:{value:engine},uCenter:{value:center},uGround:{value:ground}};
 const counts=[24,32,18,16,32],meshes=[];let disposed=false,started=null,flames=0,active=false,updates=0;
 for(let mode=0;mode<counts.length;mode++){
  const base=new T.PlaneGeometry(1,1),geometry=new T.InstancedBufferGeometry();geometry.index=base.index.clone();for(const [key,a]of Object.entries(base.attributes))geometry.setAttribute(key,a.clone());base.dispose();
  const data=new Float32Array(counts[mode]*4);for(let i=0;i<counts[mode];i++){data.set([((i+1)*.61803398875+mode*.17)%1,((i+1)*.754877666)%1,((i+1)*.56984029)%1,i/counts[mode]],i*4)}
  geometry.setAttribute('particle',new T.InstancedBufferAttribute(data,4));geometry.instanceCount=counts[mode];
  const material=new T.ShaderMaterial({uniforms,defines:{MODE:mode},vertexShader:vertex,fragmentShader:fragment,transparent:true,depthWrite:false,depthTest:true,toneMapped:false,side:T.DoubleSide,blending:mode===4?T.AdditiveBlending:T.NormalBlending});material.forceSinglePass=true;
  const mesh=new T.Mesh(geometry,material);mesh.name=['Fire_tongues','Fire_smoke','Explosion_fireball','Explosion_ground_dust','Fire_embers'][mode];mesh.frustumCulled=false;mesh.raycast=()=>{};mesh.visible=false;mesh.renderOrder=mode===1?1:mode===3?0:2;object.add(mesh);meshes.push(mesh);
 }
 const light=new T.PointLight('#ff9d46',0,9,2);light.castShadow=false;light.visible=false;object.add(light);object.visible=false;
 function update(dt,state,time=0){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0||!Number.isFinite(time))throw Error('Invalid fire effect time');
  active=!!(state.smoking||state.burning||state.destroying||state.wrecked)&&(!state.wrecked||state.wreckAge<5);
  // A cold effect was already hidden by construction/reset or by the first
  // transition out of fire. Avoid repeatedly touching all five GPU meshes on
  // every later idle frame; activation below still restores every visibility.
  if(!active){if(object.visible){object.visible=false;light.visible=false;light.intensity=0;for(const m of meshes)m.visible=false}flames=0;started=null;return}
  if(started===null)started=time;updates++;object.visible=true;
  car.object.updateWorldMatrix(true,false);center.set(0,.65,0).applyMatrix4(car.object.matrixWorld);
  const bay=car.hood?.bay;if(bay){
   // The car root was refreshed just above. For the normal direct engine-bay
   // child this avoids walking back into that same parent a second time; keep
   // the full ancestor refresh for custom/nested bay hierarchies.
   bay.updateWorldMatrix(bay.parent!==car.object,false);engine.copy(localEngine).applyMatrix4(bay.matrixWorld)
  }else{engine.copy(localEngine).applyMatrix4(car.object.matrixWorld)}
  const surface=groundHeight(center.x,center.z);ground.set(center.x,(Number.isFinite(surface)?surface:center.y-.65)+.06,center.z);
  uniforms.uTime.value=time;uniforms.uSince.value=Math.max(0,time-started);uniforms.uAge.value=state.wrecked?state.wreckAge:-1;
  uniforms.uFade.value=state.wrecked?Math.min(1,Math.max(0,5-state.wreckAge)):1;
  uniforms.uBurn.value=state.burning?1:0;uniforms.uSmoke.value=state.smoking&&(!car.hood||state.burning)?1:0;uniforms.uBurst.value=state.wrecked&&!state.externalBlast?1:0;
  meshes[0].visible=meshes[4].visible=!!state.burning;meshes[1].visible=!!uniforms.uSmoke.value;meshes[2].visible=!!uniforms.uBurst.value&&state.wreckAge<.92;meshes[3].visible=!!uniforms.uBurst.value&&state.wreckAge<2.2;flames=meshes[0].visible?24:0;
  light.position.copy(engine);if(object.parent===car.object)car.object.worldToLocal(light.position);light.intensity=(state.burning?6.2+Math.sin(time*19)*.6+Math.sin(time*31)*.35:0)*uniforms.uFade.value+(uniforms.uBurst.value?Math.max(0,1-state.wreckAge/.25)*24:0);light.visible=light.intensity>.01;
 }
 function reset(){started=null;flames=0;active=false;updates=0;object.visible=false;uniforms.uFade.value=0;for(const m of meshes)m.visible=false;light.visible=false;light.intensity=0}
 function dispose(){if(disposed)return;reset();disposed=true;object.removeFromParent();for(const m of meshes){m.geometry.dispose();m.material.dispose()}}
 return{object,update,reset,dispose,stats:()=>({active,flames,smoke:meshes[1].visible?32:0,fireball:meshes[2].visible?18:0,dust:meshes[3].visible?16:0,embers:meshes[4].visible?32:0,drawCalls:meshes.filter(m=>m.visible).length,poolCapacity:122,worldUpright:true,updates})};
}
