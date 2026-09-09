import {createLandscapePlan} from './landscape_plan.mjs';

/** Static indexed terrain chunks. Physics samples the same diagonal as these triangles. */
export function createLandscapeTerrain({THREE,plan=createLandscapePlan()}={}){
 const object=new THREE.Group();object.name='Landscape · леса, озёра и хребет';object.userData.landscape=true;
 const ownedGeometries=[],ownedMaterials=[];
 const material=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.94,metalness:0});ownedMaterials.push(material);
 const {xs,zs,heights}=plan.grid,nx=xs.length,chunkCells=40;
 const colors={grass:new THREE.Color('#738c69'),meadow:new THREE.Color('#879b74'),rock:new THREE.Color('#a09f92'),trail:new THREE.Color('#b3a58a'),shore:new THREE.Color('#c4bd9d')};
 const mixed=new THREE.Color();
 function vertexColor(x,z,y){const variation=.5+.5*Math.sin(x*.047+z*.016)*Math.cos(z*.036),slope=plan.slopeAt(x,z),p=plan.pathAt(x,z);mixed.copy(colors.grass).lerp(colors.meadow,variation*.55);if(y>26||slope>.42)mixed.lerp(colors.rock,Math.min(.9,Math.max((y-26)/27,(slope-.42)*1.4)));for(const l of plan.lakes){const r=plan.lakeRadius(l,x,z);if(r<1.24)mixed.lerp(colors.shore,Math.max(0,1-Math.abs(r-1)*4))}if(p.path)mixed.lerp(colors.trail,Math.max(0,Math.min(1,(p.path.width/2+2-p.distance)/3)));return [mixed.r,mixed.g,mixed.b]}
 let triangleCount=0,chunkCount=0;
 for(let j0=0;j0<zs.length-1;j0+=chunkCells)for(let i0=0;i0<xs.length-1;i0+=chunkCells){
  const i1=Math.min(i0+chunkCells,xs.length-1),j1=Math.min(j0+chunkCells,zs.length-1),w=i1-i0+1,positions=[],normals=[],color=[],indices=[];
  for(let j=j0;j<=j1;j++)for(let i=i0;i<=i1;i++){const x=xs[i],z=zs[j],y=heights[j*nx+i],dx=(plan.groundHeight(x+.5,z)-plan.groundHeight(x-.5,z)),dz=(plan.groundHeight(x,z+.5)-plan.groundHeight(x,z-.5)),len=Math.hypot(dx,1,dz);positions.push(x,y,z);normals.push(-dx/len,1/len,-dz/len);color.push(...vertexColor(x,z,y))}
  for(let j=j0;j<j1;j++)for(let i=i0;i<i1;i++){if(plan.insideCity((xs[i]+xs[i+1])/2,(zs[j]+zs[j+1])/2))continue;const a=(j-j0)*w+i-i0,b=a+1,c=a+w,d=c+1;indices.push(a,d,b,a,c,d)}
  if(!indices.length)continue;
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('normal',new THREE.Float32BufferAttribute(normals,3));g.setAttribute('color',new THREE.Float32BufferAttribute(color,3));g.setIndex(indices);g.computeBoundingSphere();ownedGeometries.push(g);
  const mesh=new THREE.Mesh(g,material);mesh.name='Ландшафт '+i0+':'+j0;mesh.receiveShadow=true;mesh.userData.landscapeGround=true;object.add(mesh);triangleCount+=indices.length/3;chunkCount++;
 }
 const waterMaterial=new THREE.MeshStandardMaterial({color:'#467f86',roughness:.24,metalness:.2,transparent:true,opacity:.88,depthWrite:false});ownedMaterials.push(waterMaterial);
 for(const lake of plan.lakes){
  const positions=[];
  function clippedTriangle(points){let result=[];for(let i=0;i<points.length;i++){const a=points[i],b=points[(i+1)%points.length],ai=a[1]<=lake.level,bi=b[1]<=lake.level;if(ai)result.push(a);if(ai!==bi){const t=(lake.level-a[1])/(b[1]-a[1]);result.push([a[0]+(b[0]-a[0])*t,lake.level,a[2]+(b[2]-a[2])*t])}}for(let i=1;i<result.length-1;i++)for(const v of [result[0],result[i],result[i+1]])positions.push(v[0],lake.level+.008,v[2])}
  for(let j=0;j<zs.length-1;j++){if(zs[j]<lake.z-lake.rz*1.3||zs[j]>lake.z+lake.rz*1.3)continue;for(let i=0;i<xs.length-1;i++){if(xs[i]<lake.x-lake.rx*1.3||xs[i]>lake.x+lake.rx*1.3)continue;const a=[xs[i],heights[j*nx+i],zs[j]],b=[xs[i+1],heights[j*nx+i+1],zs[j]],c=[xs[i],heights[(j+1)*nx+i],zs[j+1]],d=[xs[i+1],heights[(j+1)*nx+i+1],zs[j+1]];clippedTriangle([a,d,b]);clippedTriangle([a,c,d])}}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.computeVertexNormals();g.computeBoundingSphere();ownedGeometries.push(g);const mesh=new THREE.Mesh(g,waterMaterial);mesh.name=lake.name;mesh.renderOrder=1;mesh.userData.landscapeWater=true;object.add(mesh);triangleCount+=positions.length/9;
 }
 // Thin continuous ribbons make winding trails legible between the 4 m terrain samples.
 const ribbonPositions=[],ribbonColors=[],roadColor=new THREE.Color('#aea089'),trailColor=new THREE.Color('#b9ae92');
 for(const path of plan.paths){const pairs=[];for(let i=0;i<path.points.length;i++){const q=path.points[i],a=path.points[Math.max(0,i-1)],b=path.points[Math.min(path.points.length-1,i+1)],length=Math.hypot(b.x-a.x,b.z-a.z)||1,nx=-(b.z-a.z)/length,nz=(b.x-a.x)/length,half=path.width*.43;pairs.push([-1,1].map(s=>{const x=q.x+nx*half*s,z=q.z+nz*half*s;return [x,plan.groundHeight(x,z)+.035,z]}))}const color=path.drive?roadColor:trailColor;for(let i=1;i<pairs.length;i++){if(!plan.contains(path.points[i].x,path.points[i].z))continue;for(const v of [pairs[i-1][0],pairs[i][0],pairs[i-1][1],pairs[i-1][1],pairs[i][0],pairs[i][1]]){ribbonPositions.push(...v);ribbonColors.push(color.r,color.g,color.b)}}}
 const ribbonGeometry=new THREE.BufferGeometry();ribbonGeometry.setAttribute('position',new THREE.Float32BufferAttribute(ribbonPositions,3));ribbonGeometry.setAttribute('color',new THREE.Float32BufferAttribute(ribbonColors,3));ribbonGeometry.computeVertexNormals();ribbonGeometry.computeBoundingSphere();ownedGeometries.push(ribbonGeometry);const ribbonMaterial=new THREE.MeshStandardMaterial({vertexColors:true,roughness:1,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1,side:THREE.DoubleSide});ownedMaterials.push(ribbonMaterial);const ribbon=new THREE.Mesh(ribbonGeometry,ribbonMaterial);ribbon.name='Лесные дороги и пешеходные тропы';ribbon.userData.landscapeTrail=true;ribbon.receiveShadow=true;object.add(ribbon);triangleCount+=ribbonPositions.length/9;
 object.userData.report={chunkCount,triangleCount,lakeCount:plan.lakes.length,pathCount:plan.paths.length};
 return {...plan,plan,object,report:object.userData.report,dispose(){for(const g of ownedGeometries)g.dispose();for(const m of ownedMaterials)m.dispose();object.removeFromParent()}};
}
