// Snapshot presentation only: no hit synthesis, HP inspection or particle bursts.
export function createWorldBloodMarks({THREE,scene,groundHeight,allowGround=()=>true,worldScale=4.1,capacity=48}={}){
 if(!THREE||!scene||typeof groundHeight!=='function'||!(worldScale>0))throw Error('Blood marks need scene and ground sampler');
 capacity=Math.max(1,Math.min(48,Math.floor(capacity)||48));
 const positions=[],addDisc=(x,y,r,segments)=>{for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,edge=t=>r*(.91+.10*Math.sin(t*3)+.06*Math.cos(t*7));positions.push(x,y,0,x+Math.cos(a)*edge(a),y+Math.sin(a)*edge(a),0,x+Math.cos(b)*edge(b),y+Math.sin(b)*edge(b),0);}};
 addDisc(0,0,.8,18);addDisc(.82,.24,.12,7);addDisc(-.64,.69,.10,7);addDisc(.37,-.87,.07,6);
 const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.computeVertexNormals();
 const fades=new THREE.InstancedBufferAttribute(new Float32Array(capacity),1);geometry.setAttribute('bloodFade',fades);
 const material=new THREE.MeshBasicMaterial({color:0x791421,transparent:true,opacity:.88,depthWrite:false,depthTest:true,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1,side:THREE.DoubleSide});
 material.onBeforeCompile=shader=>{shader.vertexShader=shader.vertexShader.replace('#include <common>','#include <common>\nattribute float bloodFade; varying float vBloodFade;').replace('#include <begin_vertex>','#include <begin_vertex>\nvBloodFade = bloodFade;');shader.fragmentShader=shader.fragmentShader.replace('#include <common>','#include <common>\nvarying float vBloodFade;').replace('#include <color_fragment>','#include <color_fragment>\ndiffuseColor.a *= vBloodFade;');};
 material.customProgramCacheKey=()=> 'world-blood-marks-v1';
 const mesh=new THREE.InstancedMesh(geometry,material,capacity);mesh.name='World_Source_Blood_Marks';mesh.count=0;mesh.visible=false;mesh.frustumCulled=false;mesh.raycast=()=>{};mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);fades.setUsage(THREE.DynamicDrawUsage);scene.add(mesh);
 const transform=new THREE.Object3D(),rows=new Map(),hiddenSpaceKeys=new Set();let disposed=false,syncCount=0,active=0,groundQueries=0,clock=0;
 const finite=Number.isFinite;
 const keyOf=s=>[s.r,s.c,s.radius,s.rot||0,s.max,s.trail?1:0,finite(s.elevation)?s.elevation:'',s.space||''].join('|');
 function sync(snapshot=[],{time=clock,exterior=true}={}){
  if(disposed)return;if(!finite(time))throw Error('Invalid blood presentation time');clock=time;syncCount++;
  const incoming=new Map();for(const src of Array.isArray(snapshot)?snapshot:[]){if(incoming.size>=capacity)break;if(!src||src.soot||src.crater||!finite(src.r)||!finite(src.c)||!finite(src.radius)||src.radius<=0||!finite(src.life)||src.life<=0||!finite(src.max)||src.max<=0)continue;const key=keyOf(src);if(!incoming.has(key))incoming.set(key,src);}
  for(const key of hiddenSpaceKeys)if(!incoming.has(key))hiddenSpaceKeys.delete(key);
  if(!exterior){for(const key of incoming.keys())hiddenSpaceKeys.add(key);rows.clear();mesh.count=active=0;mesh.visible=false;return;}
  for(const key of rows.keys())if(!incoming.has(key))rows.delete(key);
  for(const [key,src]of incoming){
   // Legacy marks have no space/height. Never reproject a seen interior mark
   // onto an unrelated exterior coordinate after walking through a door.
   if(hiddenSpaceKeys.has(key)||src.space&&src.space!=='world'&&src.space!=='exterior')continue;
   let row=rows.get(key);if(row){if(src.life!==row.sourceLife){row.sourceLife=src.life;row.at=time;}continue;}
   const x=src.c*worldScale,z=src.r*worldScale,exactHeight=finite(src.elevation);
   if(!exactHeight&&!allowGround(x,z))continue;
   const floor=exactHeight?src.elevation:groundHeight(x,z);groundQueries+=Number(!exactHeight);if(!finite(floor))continue;
   row={key,x,z,y:floor+.018,rotation:src.rot||0,scale:Math.max(.20,Math.min(1.65,src.radius*.105)),trail:!!src.trail,sourceLife:src.life,max:src.max,at:time};rows.set(key,row);
  }
  update(time);
 }
 function update(time=clock){
  if(disposed)return;if(!finite(time))throw Error('Invalid blood presentation time');clock=time;let count=0;
  for(const row of rows.values()){
   const remaining=Math.max(0,row.sourceLife-Math.max(0,time-row.at)*1000);if(!remaining)continue;
   transform.position.set(row.x,row.y,row.z);transform.rotation.set(-Math.PI/2,0,row.rotation);transform.scale.set(row.scale*(row.trail?.72:1),row.scale*(row.trail?1.42:1),1);transform.updateMatrix();mesh.setMatrixAt(count,transform.matrix);
   // Source owns lifetime. Smooth disappearance only consumes that lifetime.
   fades.array[count++]=Math.min(1,remaining/Math.min(2200,row.max));
  }
  const changed=count!==active;mesh.count=active=count;mesh.visible=count>0;
  if(count||changed){mesh.instanceMatrix.needsUpdate=true;fades.needsUpdate=true;}
 }
 function dispose(){if(disposed)return;disposed=true;rows.clear();hiddenSpaceKeys.clear();mesh.count=active=0;mesh.removeFromParent();geometry.dispose();material.dispose();}
 return {sync,update,dispose,object:mesh,stats:()=>({active,tracked:rows.size,capacity,drawCalls:active?1:0,syncCount,groundQueries,disposed})};
}
