// Keep the small authored garden inside its existing parcel when the walkup
// itself becomes wider. Only private copies of the two garden meshes change.
const leases=new WeakMap();
const GARDEN=new Set(['GardenWarmSoil','GardenMutedGreen']);
const overlap=(a,b,p=0)=>a[0]<b[2]+p&&a[2]>b[0]-p&&a[1]<b[3]+p&&a[3]>b[1]-p;
const area=r=>(r[2]-r[0])*(r[3]-r[1]);
function subtract(a,b){if(!overlap(a,b))return[a];const q=[Math.max(a[0],b[0]),Math.max(a[1],b[1]),Math.min(a[2],b[2]),Math.min(a[3],b[3])];return[[a[0],a[1],q[0],a[3]],[q[2],a[1],a[2],a[3]],[q[0],a[1],q[2],q[1]],[q[0],q[3],q[2],a[3]]].filter(r=>r[2]-r[0]>.08&&r[3]-r[1]>.08)}
function components(T,node,toVisual,sourceScale,sourceOffset){
 const a=node.geometry.attributes.position,parent=Array.from({length:a.count},(_,i)=>i),keys=new Map(),find=i=>{while(parent[i]!==i){parent[i]=parent[parent[i]];i=parent[i]}return i},join=(a,b)=>{parent[find(a)]=find(b)},point=new T.Vector3();
 for(let i=0;i<a.count;i++){point.fromBufferAttribute(a,i);const key=point.toArray().map(v=>Math.round(v*1e5)).join(',');if(keys.has(key))join(i,keys.get(key));else keys.set(key,i)}
 const count=node.geometry.index?.count??a.count,index=i=>node.geometry.index?node.geometry.index.getX(i):i;for(let i=0;i<count;i+=3){join(index(i),index(i+1));join(index(i),index(i+2))}
 const groups=new Map();for(let i=0;i<a.count;i++){const root=find(i);if(!groups.has(root))groups.set(root,[]);groups.get(root).push(i)}
 return[...groups.values()].map(indices=>{const positions=indices.map(i=>{const p=new T.Vector3().fromBufferAttribute(a,i).applyMatrix4(toVisual);p.x=(p.x+sourceOffset[0])*sourceScale[0];p.y+=sourceOffset[1];p.z=(p.z+sourceOffset[2])*sourceScale[1];return p}),box=new T.Box3().setFromPoints(positions);return{node,indices,positions,box,kind:node.material.name==='GardenWarmSoil'?'soil':'plant'}});
}

export function preserveBuildingGardenSiteScale({THREE:T,visual,instance,metresPerCell=4.1}={}){
 const policy=instance?.gardenSitePolicy;if(!policy)return null;if(leases.has(visual))return leases.get(visual);
 if(instance.assetId!=='eastside_garden_walkup_v1'||!visual?.parent)throw Error('Garden site policy only supports the audited garden walkup');
 const sourceScale=policy.sourceHorizontalScale,sourceOffset=policy.sourceModelLocalOffsetM,targetScale=instance.transform.horizontalScale,targetOffset=instance.transform.modelLocalOffsetM;
 if(!sourceScale?.every(Number.isFinite)||!sourceOffset?.every(Number.isFinite)||!targetScale?.every(Number.isFinite))throw Error('Garden policy needs measured source and target transforms');
 visual.updateWorldMatrix(true,true);const inverseVisual=visual.matrixWorld.clone().invert(),garden=[],all=[];
 visual.traverse(n=>{if(n.isMesh&&!Array.isArray(n.material)&&n.geometry?.attributes.position){all.push(n);if(GARDEN.has(n.material.name))garden.push(n)}});
 if(garden.length!==2)throw Error('Audited soil and green garden mesh pair changed');
 const records=garden.map(node=>({node,source:node.geometry,toVisual:new T.Matrix4().multiplyMatrices(inverseVisual,node.matrixWorld)}));
 const pieces=records.flatMap(r=>components(T,r.node,r.toVisual,sourceScale,sourceOffset));
 const rawBounds=policy.sourceBoundsVisual,site=[(rawBounds.min[0]+sourceOffset[0])*sourceScale[0],(rawBounds.min[2]+sourceOffset[2])*sourceScale[1],(rawBounds.max[0]+sourceOffset[0])*sourceScale[0],(rawBounds.max[2]+sourceOffset[2])*sourceScale[1]],inset=.055;
 const room=[(-1.49+targetOffset[0])*targetScale[0],(-7.36+targetOffset[2])*targetScale[1],(1.49+targetOffset[0])*targetScale[0],(7.36+targetOffset[2])*targetScale[1]];
 const front={x:(.48+targetOffset[0])*targetScale[0],half:(1.17*targetScale[0])/2+.38},rear={x:(-.45+targetOffset[0])*targetScale[0],half:(.89*targetScale[0])/2+.38};
 let zones=[[site[0]+inset,site[1]+inset,site[2]-inset,room[1]-.085],[site[0]+inset,room[3]+.085,site[2]-inset,site[3]-inset]];
 zones=zones.flatMap(r=>subtract(r,r[1]>room[3]?[front.x-front.half,r[1]-.1,front.x+front.half,r[3]+.1]:[rear.x-rear.half,r[1]-.1,rear.x+rear.half,r[3]+.1])).filter(r=>area(r)>.03).sort((a,b)=>area(b)-area(a));
 if(!zones.length)throw Error('Widened walkup has no garden placement area outside its entrances');
 const restorations=[],placed=[],soilBoxes=[],plantBoxes=[];
 for(const r of records){r.node.geometry=r.source.clone();restorations.push(r);}
 function write(piece,rect){
  const record=records.find(r=>r.node===piece.node),inverseNode=record.toVisual.clone().invert(),a=piece.node.geometry.attributes.position,sx=(rect[2]-rect[0])/Math.max(.0001,piece.box.max.x-piece.box.min.x),sz=(rect[3]-rect[1])/Math.max(.0001,piece.box.max.z-piece.box.min.z);
  piece.indices.forEach((index,j)=>{const p=piece.positions[j].clone();p.x=rect[0]+(p.x-piece.box.min.x)*sx;p.z=rect[1]+(p.z-piece.box.min.z)*sz;p.x=p.x/targetScale[0]-targetOffset[0];p.y-=targetOffset[1];p.z=p.z/targetScale[1]-targetOffset[2];p.applyMatrix4(inverseNode);a.setXYZ(index,p.x,p.y,p.z)});
  placed.push({kind:piece.kind,rect,minY:piece.box.min.y,maxY:piece.box.max.y,vertices:piece.indices.length});
 }
 const soils=pieces.filter(p=>p.kind==='soil');
 soils.forEach((p,i)=>{const z=zones[i%zones.length],division=Math.ceil(soils.length/zones.length),row=Math.floor(i/zones.length),span=(z[2]-z[0])/division,rect=[z[0]+span*row,z[1],z[0]+span*(row+1)-.012,z[3]];write(p,rect);soilBoxes.push(rect)});
 const plants=pieces.filter(p=>p.kind==='plant').sort((a,b)=>(b.box.max.x-b.box.min.x)*(b.box.max.z-b.box.min.z)-(a.box.max.x-a.box.min.x)*(a.box.max.z-a.box.min.z));
 // Each original connected shrub survives. Scale horizontal spread only when
 // needed to fit its new bed; height, material, triangles and part count stay.
 for(const piece of plants){let target=null;const originalW=piece.box.max.x-piece.box.min.x,originalD=piece.box.max.z-piece.box.min.z;
  for(const scale of[1,.85,.7,.55,.4,.3,.22,.15]){if(target)break;const w=Math.max(.07,originalW*scale),d=Math.max(.07,originalD*scale);for(const z of zones){if(target)break;for(let x=z[0];x+w<=z[2]+1e-6&&!target;x+=.08)for(let zz=z[1];zz+d<=z[3]+1e-6;zz+=.08){const rr=[x,zz,x+w,zz+d];if(!plantBoxes.some(b=>overlap(rr,b,.025))){target=rr;break}}}}
  if(!target){for(const r of restorations){r.node.geometry.dispose();r.node.geometry=r.source}throw Error('All authored garden shrubs must fit; refusing to drop a component')}
  write(piece,target);plantBoxes.push(target);
 }
 for(const r of records){r.node.geometry.attributes.position.needsUpdate=true;r.node.geometry.computeVertexNormals();r.node.geometry.computeBoundingBox();r.node.geometry.computeBoundingSphere()}
 visual.updateWorldMatrix(true,true);const p=new T.Vector3(),inverseParent=visual.parent.matrixWorld.clone().invert(),fullBounds=new T.Box3();
 for(const n of all){let visible=true;for(let parent=n;parent;parent=parent.parent)if(!parent.visible)visible=false;if(!visible||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name))continue;const toParent=new T.Matrix4().multiplyMatrices(inverseParent,n.matrixWorld),a=n.geometry.attributes.position;for(let i=0;i<a.count;i++){p.fromBufferAttribute(a,i).applyMatrix4(toParent);p.x*=targetScale[0];p.z*=targetScale[1];fullBounds.expandByPoint(p)}}
 const bounds=[fullBounds.min.x,fullBounds.min.z,fullBounds.max.x,fullBounds.max.z];
 if(bounds[0]<site[0]-1e-4||bounds[1]<site[1]-1e-4||bounds[2]>site[2]+1e-4||bounds[3]>site[3]+1e-4){for(const r of restorations){r.node.geometry.dispose();r.node.geometry=r.source}throw Error('Widened walkup body exceeds its original measured garden envelope')}
 const world=(x,y,z)=>visual.parent.localToWorld(new T.Vector3(x/targetScale[0],y,z/targetScale[1]));
 const collisionBodies=placed.filter(p=>p.kind==='plant'&&p.maxY-p.minY>.2).map(p=>{const r=p.rect,points=[[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]].map(([x,z])=>world(x,p.minY,z)),low=world(0,p.minY,0),high=world(0,p.maxY,0);return{polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:low.y,maxYM:high.y,buildingEntryId:instance.id,gardenSite:true}});
 let disposed=false;const report={assetId:instance.assetId,site,bodyRect:room,gardenZones:zones,placed,fullBounds:bounds,plants:plants.length,soilParts:soils.length,drawsBefore:garden.length,drawsAfter:garden.length,vertices:pieces.reduce((n,p)=>n+p.indices.length,0),geometrySourceUnchanged:true,collisionBodies,restore(){if(disposed)return;disposed=true;for(const r of restorations){r.node.geometry.dispose();r.node.geometry=r.source}leases.delete(visual)}};leases.set(visual,report);return report;
}
