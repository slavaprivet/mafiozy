const DEFAULT_LIMITS=Object.freeze({chunkSize:24,viewDistance:28,maxObjects:1024,maxTriangles:4096});
const PALETTE=Object.freeze({
 soil:[0x756349,0x857252,0x646747],
 stone:[0x858374,0x727566,0x969181],
 leaf:[0xa29260,0x857549,0xb09a62],
 weed:[0x667a49,0x818b53,0x566d43],
});
const TAU=Math.PI*2;
const fract=value=>value-Math.floor(value);
const hash=(value,salt=0)=>fract(Math.sin((value+1)*12.9898+salt*78.233)*43758.5453);
const kindFor=value=>{const roll=hash(value,1);return roll<.1?'soil':roll<.25?'stone':roll<.55?'leaf':'weed'};
const trianglesFor=kind=>kind==='soil'||kind==='stone'?4:2;

export function createEnvironmentLawnGround({THREE,plan,limits={}}={}){
 if(!THREE||!Array.isArray(plan?.tufts))throw Error('Lawn ground requires THREE and grass placement plan');
 const budget={...DEFAULT_LIMITS,...limits},maxTriangles=Math.max(0,Math.floor(budget.maxTriangles)),maxVertices=maxTriangles*3;
 const positions=new Float32Array(maxVertices*3),normals=new Float32Array(maxVertices*3),colors=new Float32Array(maxVertices*3);
 const geometry=new THREE.BufferGeometry();
 geometry.setAttribute('position',new THREE.BufferAttribute(positions,3).setUsage(THREE.DynamicDrawUsage));
 geometry.setAttribute('normal',new THREE.BufferAttribute(normals,3).setUsage(THREE.DynamicDrawUsage));
 geometry.setAttribute('color',new THREE.BufferAttribute(colors,3).setUsage(THREE.DynamicDrawUsage));
 geometry.setDrawRange(0,0);
 const material=new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:1,metalness:0,side:THREE.DoubleSide});
 const mesh=new THREE.Mesh(geometry,material);mesh.name='LawnGroundDetails';mesh.castShadow=false;mesh.receiveShadow=true;mesh.frustumCulled=false;mesh.userData.worldBlastIgnore=true;mesh.userData.lawnGroundDetails=true;mesh.raycast=()=>{};
 const object=new THREE.Group();object.name='EnvironmentLawnGround';object.add(mesh);
 const chunks=new Map(),chunkSize=Math.max(8,budget.chunkSize);
 for(let index=0;index<plan.tufts.length;index++){
  const tuft=plan.tufts[index];if(tuft.zone!=='lawn'||tuft.style==='shrub')continue;
  const key=Math.floor(tuft.x/chunkSize)+','+Math.floor(tuft.z/chunkSize);if(!chunks.has(key))chunks.set(key,[]);chunks.get(key).push({tuft,index});
 }
 const stats={objects:0,triangles:0,draws:0,soil:0,stone:0,leaf:0,weed:0,maxObjects:budget.maxObjects,maxTriangles:budget.maxTriangles,dynamicLights:0,shadowCasters:0,collision:false,pickable:false};object.userData.environmentLawnGround=stats;
 const color=new THREE.Color(),candidates=[];let vertexCursor=0,lastFocus=null,disposed=false;
 const point=(tuft,yaw,x,y,z)=>({x:tuft.x+Math.cos(yaw)*x-Math.sin(yaw)*z,y:tuft.y+y,z:tuft.z+Math.sin(yaw)*x+Math.cos(yaw)*z});
 function writeTriangle(a,b,c,hex,tone=1){
  if(vertexCursor+3>maxVertices)return false;
  const abx=b.x-a.x,aby=b.y-a.y,abz=b.z-a.z,acx=c.x-a.x,acy=c.y-a.y,acz=c.z-a.z;
  let nx=aby*acz-abz*acy,ny=abz*acx-abx*acz,nz=abx*acy-aby*acx,length=Math.hypot(nx,ny,nz)||1;nx/=length;ny/=length;nz/=length;
  color.setHex(hex);const cr=Math.min(1,color.r*tone),cg=Math.min(1,color.g*tone),cb=Math.min(1,color.b*tone);
  for(const vertex of[a,b,c]){const offset=vertexCursor*3;positions[offset]=vertex.x;positions[offset+1]=vertex.y;positions[offset+2]=vertex.z;normals[offset]=nx;normals[offset+1]=ny;normals[offset+2]=nz;colors[offset]=cr;colors[offset+1]=cg;colors[offset+2]=cb;vertexCursor++;}
  return true;
 }
 function addGroundObject(candidate){
  const {tuft,detailIndex:detail,kind}=candidate,anchor={...tuft,x:candidate.x,z:candidate.z,y:tuft.y+(tuft.slopeX||0)*(candidate.x-tuft.x)+(tuft.slopeZ||0)*(candidate.z-tuft.z)},yaw=tuft.yaw+hash(detail,2)*TAU,palette=PALETTE[kind],hex=palette[Math.floor(hash(detail,3)*palette.length)%palette.length];
  if(kind==='soil'){
   const rx=.11+hash(detail,4)*.07,rz=.075+hash(detail,5)*.055,height=.036+hash(detail,6)*.025,center=point(anchor,yaw,0,height,0),ring=[];
   for(let side=0;side<4;side++){const angle=side*TAU/4,jitter=.82+hash(detail,10+side)*.24;ring.push(point(anchor,yaw,Math.cos(angle)*rx*jitter,.023,Math.sin(angle)*rz*jitter));}
   for(let side=0;side<4;side++)writeTriangle(ring[(side+1)%4],ring[side],center,hex,.9+side*.035);
  }else if(kind==='stone'){
   const rx=.065+hash(detail,4)*.045,rz=.05+hash(detail,5)*.04,height=.045+hash(detail,6)*.035,center=point(anchor,yaw,0,height,0),ring=[];
   for(let side=0;side<4;side++){const angle=side*TAU/4;ring.push(point(anchor,yaw,Math.cos(angle)*rx,.023,Math.sin(angle)*rz));}
   for(let side=0;side<4;side++)writeTriangle(ring[(side+1)%4],ring[side],center,hex,.9+side*.045);
  }else if(kind==='leaf'){
   const length=.075+hash(detail,4)*.055,width=.025+hash(detail,5)*.025,ring=[point(anchor,yaw,-length,.024,-width*.25),point(anchor,yaw,0,.031,width),point(anchor,yaw,length,.024,width*.15),point(anchor,yaw,0,.027,-width)];
   writeTriangle(ring[1],ring[0],ring[2],hex,.94);writeTriangle(ring[0],ring[3],ring[2],hex,.82);
  }else{
   const height=.055+hash(detail,4)*.055,width=.014+hash(detail,5)*.01;
   for(let blade=0;blade<2;blade++){const angle=yaw+blade*1.9,lean=(hash(detail,8+blade)-.5)*.055,rootA={x:anchor.x+Math.cos(angle+Math.PI/2)*width,y:anchor.y+.02,z:anchor.z+Math.sin(angle+Math.PI/2)*width},rootB={x:anchor.x-Math.cos(angle+Math.PI/2)*width,y:anchor.y+.02,z:anchor.z-Math.sin(angle+Math.PI/2)*width},tip={x:anchor.x+Math.cos(angle)*lean,y:anchor.y+height*(1-blade*.16),z:anchor.z+Math.sin(angle)*lean};writeTriangle(rootA,rootB,tip,hex,.86+blade*.09);}
  }
 }
 function clear(){vertexCursor=0;for(const key of['objects','triangles','draws','soil','stone','leaf','weed'])stats[key]=0;geometry.setDrawRange(0,0);mesh.visible=false;}
 function update({focus,triangleBudget=budget.maxTriangles,drawAllowed=true,force=false}={}){
  if(disposed)return;if(!focus||!Number.isFinite(focus.x+focus.z)||!drawAllowed||triangleBudget<4){clear();return;}
  if(!force&&lastFocus&&Math.hypot(focus.x-lastFocus.x,focus.z-lastFocus.z)<2.5)return;lastFocus={x:focus.x,z:focus.z};clear();
  const radius=Math.max(8,budget.viewDistance),minX=Math.floor((focus.x-radius)/chunkSize),maxX=Math.floor((focus.x+radius)/chunkSize),minZ=Math.floor((focus.z-radius)/chunkSize),maxZ=Math.floor((focus.z+radius)/chunkSize);candidates.length=0;
  for(let iz=minZ;iz<=maxZ;iz++)for(let ix=minX;ix<=maxX;ix++)for(const source of chunks.get(ix+','+iz)||[])for(let slot=0;slot<5;slot++){const detailIndex=source.index*5+slot,angle=hash(detailIndex,7)*TAU,offset=.05+hash(detailIndex,8)*.27,x=source.tuft.x+Math.cos(angle)*offset,z=source.tuft.z+Math.sin(angle)*offset,distance=Math.hypot(x-focus.x,z-focus.z);if(distance<=radius)candidates.push({...source,detailIndex,x,z,distance,kind:kindFor(detailIndex)});}
  candidates.sort((a,b)=>a.distance-b.distance||a.index-b.index);const allowedTriangles=Math.min(maxTriangles,Math.max(0,Math.floor(triangleBudget)));
  for(const candidate of candidates){const triangles=trianglesFor(candidate.kind);if(stats.objects>=budget.maxObjects||stats.triangles+triangles>allowedTriangles)break;addGroundObject(candidate);stats.objects++;stats.triangles+=triangles;stats[candidate.kind]++;}
  geometry.setDrawRange(0,vertexCursor);for(const attribute of Object.values(geometry.attributes)){attribute.clearUpdateRanges?.();attribute.addUpdateRange?.(0,vertexCursor*3);attribute.needsUpdate=true;}
  mesh.visible=vertexCursor>0;stats.draws=mesh.visible?1:0;
 }
 return {object,mesh,geometry,material,stats,limits:budget,update,dispose(){if(disposed)return;disposed=true;geometry.dispose();material.dispose();object.clear();}};
}
