export const WINDOW_PROFILES=Object.freeze({
 old_town_narrow_townhouse_v1:'fd0178400e608c44f4c7c8841d9a308e0ae2ec4db4df36033f04401f9b135067',
 eastside_garden_walkup_v1:'627e644d51f0488d67bc476498a0ae5404e522fa0c7a240c1ecd9f4b0d287f10',
 eastside_stepped_apartment_v1:'5af57644b8896f3062b69a26c10aa393b2a6364899b5ef71ab28aac6156ebbba',
 coastal_orchard_house_v1:'ac9b33396f0773823d74a517ec8764438bd8b2bd253110a0cf3806310f5b9f20',
 garden_lane_house_v1:'c15b6c3f8360a504a76f35e4b96510c18fb30a321db75651a8260bd965540c37',
 hillstep_chalet_v1:'26f0868537c6e95136cdf69f9d3a7a554b61b29e974fc1949cdd94f8819c8714',
 pine_ridge_cottage_v1:'0ee0526b4389a356006396310d796c69080ddcd976ecac24d7dd7c424e2a0da3',
 veranda_bungalow_v1:'8adf5797cf739c73bf5b3a7d0586406dade6f1a3b566c18cda2c0a510ba5aa5b',
 woodland_crosswing_house_v1:'060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b',
});

// Weld positions only for component discovery; authored UV/normal seams and
// material groups remain untouched in the replacement geometry.
const componentCache=new WeakMap();
function matrixKey(matrix){
 let key='';
 for(let index=0;index<matrix.elements.length;index++){if(index)key+=',';key+=Math.round(matrix.elements[index]*1e5)}
 return key;
}
function geometryComponents(T,geometry,matrix){
 const p=geometry?.attributes?.position,index=geometry?.index;if(!p)return[];
 let variants=componentCache.get(geometry);if(!variants)componentCache.set(geometry,variants=new Map());
 const key=matrixKey(matrix),cached=variants.get(key);if(cached)return cached;
 const parents=new Map(),keys=Array.from({length:p.count},(_,i)=>`${Math.round(p.getX(i)*10000)},${Math.round(p.getY(i)*10000)},${Math.round(p.getZ(i)*10000)}`);
 function find(k){if(!parents.has(k))parents.set(k,k);let r=k;while(parents.get(r)!==r)r=parents.get(r);while(k!==r){const next=parents.get(k);parents.set(k,r);k=next}return r}
 function join(a,b){a=find(a);b=find(b);if(a!==b)parents.set(b,a)}
 const faceCount=Math.floor((index?.count??p.count)/3),vi=(f,k)=>index?index.getX(f*3+k):f*3+k;
 for(let f=0;f<faceCount;f++){const a=keys[vi(f,0)];join(a,keys[vi(f,1)]);join(a,keys[vi(f,2)])}
 const groups=new Map();for(let f=0;f<faceCount;f++){const root=find(keys[vi(f,0)]);if(!groups.has(root))groups.set(root,{bounds:new T.Box3(),faces:[]});const group=groups.get(root);group.faces.push(f);for(let k=0;k<3;k++)group.bounds.expandByPoint(new T.Vector3().fromBufferAttribute(p,vi(f,k)).applyMatrix4(matrix))}
 const result=[...groups.values()];variants.set(key,result);return result;
}
export function componentBounds(T,geometry,matrix){return geometryComponents(T,geometry,matrix).map(component=>component.bounds)}

function withoutFaces(T,source,removed){
 const attributes=Object.entries(source.attributes);if(attributes.some(([,a])=>a.isInterleavedBufferAttribute))throw Error('Residential window extraction requires ordinary attributes');
 const count=source.index?.count??source.attributes.position.count,output=Object.fromEntries(attributes.map(([name])=>[name,[]])),groups=[];let emitted=0,sourceGroup=0;
 const materialAt=offset=>{while(sourceGroup+1<source.groups.length&&offset>=source.groups[sourceGroup].start+source.groups[sourceGroup].count)sourceGroup++;const group=source.groups[sourceGroup];return group&&offset>=group.start&&offset<group.start+group.count?group.materialIndex:0};
 for(let offset=0;offset<count;offset+=3){if(removed.has(offset/3))continue;const start=emitted,materialIndex=materialAt(offset);for(let k=0;k<3;k++){const index=source.index?source.index.getX(offset+k):offset+k;for(const [name,a]of attributes)for(let c=0;c<a.itemSize;c++)output[name].push(a.getComponent(index,c));emitted++}const previous=groups.at(-1);if(previous?.materialIndex===materialIndex&&previous.start+previous.count===start)previous.count+=3;else groups.push({start,count:3,materialIndex})}
 const geometry=new T.BufferGeometry();for(const [name,a]of attributes)geometry.setAttribute(name,new T.BufferAttribute(new a.array.constructor(output[name]),a.itemSize,a.normalized));for(const group of groups)geometry.addGroup(group.start,group.count,group.materialIndex);geometry.name=`${source.name||'geometry'}_without_window_panels`;geometry.computeBoundingBox();geometry.computeBoundingSphere();return geometry;
}

// Subtract all non-overlapping window apertures in one source-triangle pass.
// The generic entry cutter rebuilds the complete mesh once per box; that is
// correct for a door, but forty windows would multiply work and freeze a frame.
function subtractBoxesFromGeometry(T,source,toReference,boxes){
 const attributes=Object.entries(source.attributes),position=source.attributes.position;if(!position||attributes.some(([,a])=>a.isInterleavedBufferAttribute))throw Error('Residential clipping requires ordinary attributes');
 const output=Object.fromEntries(attributes.map(([name])=>[name,[]])),groups=[],count=source.index?.count??position.count;let emitted=0,sourceGroup=0;
 const planes=box=>[[0,box.min.x,1],[0,box.max.x,-1],[1,box.min.y,1],[1,box.max.y,-1],[2,box.min.z,1],[2,box.max.z,-1]],materialAt=offset=>{while(sourceGroup+1<source.groups.length&&offset>=source.groups[sourceGroup].start+source.groups[sourceGroup].count)sourceGroup++;const group=source.groups[sourceGroup];return group&&offset>=group.start&&offset<group.start+group.count?group.materialIndex:0};
 const vertex=index=>{const values=Object.fromEntries(attributes.map(([name,a])=>[name,Array.from({length:a.itemSize},(_,k)=>a.array[index*a.itemSize+k])])),reference=new T.Vector3().fromArray(values.position).applyMatrix4(toReference).toArray();return{values,reference}};
 const mix=(a,b,t)=>({values:Object.fromEntries(attributes.map(([name])=>[name,a.values[name].map((v,k)=>v+(b.values[name][k]-v)*t)])),reference:a.reference.map((v,k)=>v+(b.reference[k]-v)*t)});
 const split=(polygon,[axis,boundary,sign])=>{const inside=[],outside=[];for(let i=0;i<polygon.length;i++){const a=polygon[i],b=polygon[(i+1)%polygon.length],da=(a.reference[axis]-boundary)*sign,db=(b.reference[axis]-boundary)*sign;(da>=0?inside:outside).push(a);if((da>=0)!==(db>=0)){const crossing=mix(a,b,da/(da-db));inside.push(crossing);outside.push(crossing)}}return[inside,outside]};
 const intersects=(polygon,box)=>{const xs=polygon.map(v=>v.reference[0]),ys=polygon.map(v=>v.reference[1]),zs=polygon.map(v=>v.reference[2]);return Math.max(...xs)>=box.min.x&&Math.min(...xs)<=box.max.x&&Math.max(...ys)>=box.min.y&&Math.min(...ys)<=box.max.y&&Math.max(...zs)>=box.min.z&&Math.min(...zs)<=box.max.z};
 const subtract=(polygon,box)=>{let remaining=polygon,outside=[];for(const plane of planes(box)){if(remaining.length<3)break;const parts=split(remaining,plane);remaining=parts[0];if(parts[1].length>=3)outside.push(parts[1])}return outside};
 const emit=(polygon,materialIndex)=>{const start=emitted;for(let i=1;i<polygon.length-1;i++)for(const v of [polygon[0],polygon[i],polygon[i+1]]){for(const[name]of attributes)output[name].push(...v.values[name]);emitted++}if(emitted>start){const previous=groups.at(-1);if(previous?.materialIndex===materialIndex&&previous.start+previous.count===start)previous.count+=emitted-start;else groups.push({start,count:emitted-start,materialIndex})}};
 for(let offset=0;offset<count;offset+=3){let polygons=[[0,1,2].map(k=>vertex(source.index?source.index.getX(offset+k):offset+k))];for(const box of boxes){const next=[];for(const polygon of polygons)next.push(...(intersects(polygon,box)?subtract(polygon,box):[polygon]));polygons=next;if(!polygons.length)break}for(const polygon of polygons)emit(polygon,materialAt(offset))}
 const geometry=new T.BufferGeometry();for(const[name,a]of attributes)geometry.setAttribute(name,new T.BufferAttribute(new a.array.constructor(output[name]),a.itemSize,a.normalized));for(const group of groups)geometry.addGroup(group.start,group.count,group.materialIndex);geometry.name=`${source.name||'geometry'}_window_apertures`;geometry.computeBoundingBox();geometry.computeBoundingSphere();return geometry;
}

const applications=new WeakMap(),geometryCache=new WeakMap(),cacheRecords=new Set(),bundles=new WeakMap();let cacheHits=0,cacheMisses=0;
function signature(matrix,cuts,suffix){const n=value=>Math.round(value*1e5);return`${suffix}|${matrix.elements.map(n).join(',')}|${cuts.map(c=>[c.min.x,c.min.y,c.min.z,c.max.x,c.max.y,c.max.z].map(n).join(',')).join(';')}`}
function acquireGeometry(source,key,create){let variants=geometryCache.get(source);if(!variants)geometryCache.set(source,variants=new Map());let record=variants.get(key);if(record){record.refs++;cacheHits++;return record}record={source,key,geometry:create(),refs:1,variants};variants.set(key,record);cacheRecords.add(record);cacheMisses++;return record}
function releaseGeometry(record){if(--record.refs>0)return;record.variants.delete(record.key);record.geometry.dispose();cacheRecords.delete(record)}
function acquireBundle(T){let bundle=bundles.get(T);if(bundle){bundle.refs++;return bundle}const dark=new T.MeshStandardMaterial({name:'Residential deep interior',color:'#172525',roughness:.94}),reveal=new T.MeshStandardMaterial({name:'Residential stone reveal',color:'#65716c',roughness:.86}),brass=new T.MeshStandardMaterial({name:'Residential muted brass frame',color:'#8a704a',metalness:.46,roughness:.38}),curtain=new T.MeshStandardMaterial({name:'Residential burgundy curtain',color:'#56353b',roughness:1}),glass=new T.MeshPhysicalMaterial({name:'Residential DeepGlass',color:'#416f73',transparent:true,opacity:.28,roughness:.16,metalness:.14,clearcoat:.85,clearcoatRoughness:.1,envMapIntensity:.86,depthWrite:false,side:T.DoubleSide});glass.userData.breakableGlass=true;bundle={refs:1,geometry:new T.BoxGeometry(1,1,1),materials:{dark,reveal,brass,curtain,glass}};bundles.set(T,bundle);return bundle}
function releaseBundle(T,bundle){if(--bundle.refs>0)return;bundle.geometry.dispose();for(const material of Object.values(bundle.materials))material.dispose();bundles.delete(T)}

export function residentialWindowCacheStats(){return{entries:cacheRecords.size,refs:[...cacheRecords].reduce((sum,r)=>sum+r.refs,0),hits:cacheHits,misses:cacheMisses}}

export function applyResidentialWindows({THREE:T,visual,instance}){
 if(applications.has(visual))return applications.get(visual);
 if(WINDOW_PROFILES[instance?.assetId]!==instance?.binding?.sha256||instance?.binding?.lod!==0)return null;
 if(!T?.InstancedMesh||!visual?.traverse)throw Error('THREE and a cloned residential visual are required');
 visual.updateWorldMatrix(true,true);const inverse=visual.matrixWorld.clone().invert(),nodes=[];visual.traverse(n=>{if(n.isMesh&&n.visible&&!n.isSkinnedMesh&&!Array.isArray(n.material))nodes.push(n)});
 const matrix=n=>new T.Matrix4().multiplyMatrices(inverse,n.matrixWorld),windowLayers=nodes.filter(n=>/(?:DeepGlass|WarmInterior)$/.test(n.material?.name)||(n.material?.name==='WindowWarm'&&/^(Front|Rear|Side).*Window\d+$/.test(n.name))),deepLayers=windowLayers.filter(n=>/DeepGlass$/.test(n.material?.name)),primaryLayers=new Set(deepLayers.length?deepLayers:windowLayers),panes=[],candidateComponents=new Map();let preservedComponents=0;
 for(const node of windowLayers){const transform=matrix(node),selected=[];for(const component of geometryComponents(T,node.geometry,transform)){const bounds=component.bounds,size=bounds.getSize(new T.Vector3());if(size.y<.35||Math.max(size.x,size.z)<.3){preservedComponents++;continue}selected.push(component);if(primaryLayers.has(node)){const axis=size.x<size.z?'x':'z',center=bounds.getCenter(new T.Vector3()),sign=center[axis]<0?-1:1,normal=new T.Vector3();normal[axis]=sign;const origin=center.clone();origin[axis]=sign>0?bounds.max[axis]:bounds.min[axis];const width=axis==='z'?size.x:size.z,height=size.y,cut=bounds.clone();cut.min.y+=.015;cut.max.y-=.015;cut.min[axis]=origin[axis]-(sign>0?.73:.06);cut.max[axis]=origin[axis]+(sign>0?.06:.73);panes.push({node,origin,normal,width,height,cut,faces:component.faces})}}if(selected.length)candidateComponents.set(node,selected)}
 if(!panes.length)return null;
 const originals=[],acquired=[],group=new T.Group();group.name='Recessed_Residential_Windows';group.userData.breakableGlass=false;let localCacheHits=0,localCacheMisses=0;
 const acquire=(node,key,create)=>{const before=cacheHits,record=acquireGeometry(node.geometry,key,create);if(cacheHits>before)localCacheHits++;else localCacheMisses++;originals.push([node,node.geometry]);acquired.push(record);node.geometry=record.geometry};
 // Remove only selected connected pane components. Tiny WarmInterior porch
 // lamps sharing the same mesh/material stay visible and retain their IDs.
 for(const [node,components]of candidateComponents){const transform=matrix(node),faces=new Set(components.flatMap(component=>component.faces)),key=signature(transform,[],`components:${[...faces].join(',')}`);acquire(node,key,()=>withoutFaces(T,node.geometry,faces))}
 // Cut the opaque facade behind each pane. The result is cached by shared GLB
 // template geometry and local reference transform, so repeated city clones do
 // not repeat the expensive polygon clipping work.
 for(const node of nodes){if(candidateComponents.has(node))continue;const transform=matrix(node);node.geometry.computeBoundingBox();const bounds=node.geometry.boundingBox.clone().applyMatrix4(transform),cuts=panes.filter(pane=>bounds.intersectsBox(pane.cut)).map(pane=>pane.cut);if(!cuts.length)continue;const key=signature(transform,cuts,`cuts:${instance.assetId}:${node.name}`);acquire(node,key,()=>subtractBoxesFromGeometry(T,node.geometry,transform,cuts))}
 const bundle=acquireBundle(T),{dark,reveal,brass,curtain,glass}=bundle.materials,batches=new Map(),ownedInstances=[];
 function add(material,w,h,d,x,y,z,frame){const transform=new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion(),new T.Vector3(w,h,d));transform.premultiply(frame);if(!batches.has(material))batches.set(material,[]);batches.get(material).push(transform)}
 for(const [i,pane]of panes.entries()){const frame=new T.Matrix4().compose(pane.origin,new T.Quaternion().setFromUnitVectors(new T.Vector3(0,0,1),pane.normal),new T.Vector3(1,1,1)),w=pane.width,h=pane.height;add(dark,w*.94,h*.94,.045,0,0,-.69,frame);for(const x of [-w/2,w/2])add(reveal,.045,h,.68,x,0,-.34,frame);for(const y of [-h/2,h/2])add(reveal,w,.045,.68,0,y,-.34,frame);add(curtain,w*.2,h*.82,.035,(i%2?1:-1)*w*.34,0,-.5,frame);add(reveal,w*.44,.055,.17,0,-h*.3,-.51,frame);for(const x of [-w/2,w/2])add(brass,.045,h,.028,x,0,.008,frame);for(const y of [-h/2,h/2])add(brass,w,.045,.028,0,y,.008,frame);add(brass,.025,h,.025,0,0,.01,frame);add(brass,w,.022,.025,0,0,.01,frame);add(glass,w*.965,h*.965,.012,0,0,-.022,frame)}
 for(const [material,transforms]of batches){const mesh=new T.InstancedMesh(bundle.geometry,material,transforms.length);mesh.name=material===glass?'ResidentialWindow_DeepGlass':material===dark?'ResidentialWindow_DeepRecess':'ResidentialWindow_Frame_And_Interior';mesh.userData.breakableGlass=material===glass;for(let i=0;i<transforms.length;i++)mesh.setMatrixAt(i,transforms[i]);mesh.receiveShadow=true;mesh.castShadow=material!==glass;mesh.computeBoundingBox();mesh.computeBoundingSphere();mesh.userData.worldBlastStaticBounds=true;group.add(mesh);ownedInstances.push(mesh)}visual.add(group);
 const porchLamps=[];visual.traverse(node=>{if(/PorchLamp/i.test(node.name))porchLamps.push(node)});const report={assetId:instance.assetId,windows:panes.length,clippedMeshes:originals.length,preservedComponents,porchLamps:porchLamps.length,cacheHits:localCacheHits,cacheMisses:localCacheMisses,status:'applied-needs-live-review'};
 let disposed=false;const api={report,group,panes,glass:group.getObjectByName('ResidentialWindow_DeepGlass'),dispose(){if(disposed)return;disposed=true;group.removeFromParent();for(const mesh of ownedInstances)mesh.dispose();ownedInstances.length=0;for(const [node,geometry]of originals)node.geometry=geometry;for(const record of acquired)releaseGeometry(record);releaseBundle(T,bundle);applications.delete(visual)}};applications.set(visual,api);return api;
}

// Optional frame-budget adapter. It runs at most the work that fits the caller's
// budget after completing one item; cache hits make subsequent clones cheap.
export function createResidentialWindowQueue({budgetMs=5,now=()=>globalThis.performance?.now?.()??Date.now()}={}){const jobs=[];return{enqueue(args){const job={args,done:false,result:null,error:null};jobs.push(job);return job},update(limit=budgetMs){const start=now();let completed=0;while(jobs.length&&(completed===0||now()-start<limit)){const job=jobs.shift();try{job.result=applyResidentialWindows(job.args)}catch(error){job.error=error}job.done=true;completed++}return completed},get pending(){return jobs.length}}}
