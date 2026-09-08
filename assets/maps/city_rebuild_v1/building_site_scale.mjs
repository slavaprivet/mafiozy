// Resize an authored civic building inside its original yard. Geometry remains
// shared and unchanged: only transforms on the caller's private clone change.
const SITE_NAMES={
 hospital:/^(?:PAD_|ROUTE_|DROPOFF_|AmbulanceBay|AMBULANCE_BAY_|Hospital_(?:Planter|PublicBench|PublicBin)|SERVICE_EMERGENCY_TIEIN_SOCKET|CLEARANCE_HOSPITAL_(?:PUBLIC_ROUTE|ACCESSIBLE_ROUTE|EMERGENCY_ROUTE|SERVICE_ROUTE)|TERRAIN_DATUM_|SITE_ADAPTER_)/,
 civic_hall:/^(?:PAD_|FRONTAGE_|Public_Pedestrian_Band_|Emergency_Route_|SERVICE_CIVIC_HALL_|CivicHall_(?:Planter|PlazaBench))/,
};
const cache=new WeakMap();
export function isBuildingSiteNode(assetId,name){return SITE_NAMES[assetId]?.test(name)??false}
export function preserveBuildingSiteScale({THREE,visual,assetId,requestedScale=1.45,lotBounds=[-15,-15,15,15]}){
 if(cache.has(visual))return cache.get(visual);
 if(!SITE_NAMES[assetId])return null;
 if(!visual?.parent||!Number.isFinite(requestedScale)||requestedScale<1)throw Error('Site scale requires an attached private visual clone and scale >= 1');
 const parent=visual.parent,nodes=[];visual.traverse(n=>nodes.push(n));
 const visible=n=>{for(let p=n;p;p=p.parent)if(!p.visible)return false;return true};
 const site=n=>{for(let p=n;p&&p!==visual;p=p.parent)if(isBuildingSiteNode(assetId,p.name))return true;return false};
 const siteRoots=nodes.filter(n=>n!==visual&&isBuildingSiteNode(assetId,n.name)&&!site(n.parent));
 const previousScale=parent.scale.clone();parent.scale.set(1,previousScale.y,1);parent.updateWorldMatrix(true,true);
 const inverseParent=new THREE.Matrix4().copy(parent.matrixWorld).invert();
 const originalWorld=new Map(siteRoots.map(n=>[n,n.matrixWorld.clone()]));
 const originalTransforms=siteRoots.map(n=>[n,{position:n.position.clone(),quaternion:n.quaternion.clone(),scale:n.scale.clone(),matrix:n.matrix.clone(),matrixAutoUpdate:n.matrixAutoUpdate}]);
 const buildingBounds=new THREE.Box3();
 for(const n of nodes)if(n.isMesh&&visible(n)&&!site(n)){
  const matrix=new THREE.Matrix4().multiplyMatrices(inverseParent,n.matrixWorld);
  buildingBounds.union(new THREE.Box3().setFromBufferAttribute(n.geometry.attributes.position).applyMatrix4(matrix));
 }
 if(buildingBounds.isEmpty()){parent.scale.copy(previousScale);parent.updateWorldMatrix(true,true);throw Error('No visible building body for '+assetId)}
 const [minX,minZ,maxX,maxZ]=lotBounds;
 let knownScale=requestedScale;
 for(const [value,limit]of [[buildingBounds.min.x,minX],[buildingBounds.min.z,minZ],[buildingBounds.max.x,maxX],[buildingBounds.max.z,maxZ]])if(value!==0&&value*limit>0)knownScale=Math.min(knownScale,Math.abs(limit/value));
 // Leave a tiny numerical margin at an exact parcel boundary.
 if(knownScale<requestedScale)knownScale=Math.max(1,knownScale-1e-7);
 parent.scale.set(knownScale,previousScale.y,knownScale);parent.updateWorldMatrix(true,true);
 for(const n of siteRoots){
  n.parent.updateWorldMatrix(true,false);
  const local=new THREE.Matrix4().copy(n.parent.matrixWorld).invert().multiply(originalWorld.get(n));
  local.decompose(n.position,n.quaternion,n.scale);
  // Keep the complete matrix: nested rotations with nonuniform parent scale
  // can introduce shear which position/quaternion/scale alone cannot retain.
  n.matrix.copy(local);n.matrixAutoUpdate=false;n.updateWorldMatrix(false,true);
 }
 parent.updateWorldMatrix(true,true);
 // Return the final envelope in original site axes/metres (unscaled frame),
 // suitable for footprint planning even when the placement is yaw-rotated.
 const fullBounds=new THREE.Box3();
 for(const n of nodes)if(n.isMesh&&visible(n))fullBounds.union(new THREE.Box3().setFromBufferAttribute(n.geometry.attributes.position).applyMatrix4(new THREE.Matrix4().multiplyMatrices(inverseParent,n.matrixWorld)));
 if(fullBounds.min.x<minX-1e-5||fullBounds.min.z<minZ-1e-5||fullBounds.max.x>maxX+1e-5||fullBounds.max.z>maxZ+1e-5)throw Error('Enlarged '+assetId+' exceeds original yard envelope');
 const report={assetId,requestedScale,knownScale,bodyBoundsBefore:{min:buildingBounds.min.toArray(),max:buildingBounds.max.toArray()},fullBounds:{min:fullBounds.min.toArray(),max:fullBounds.max.toArray()},changedNames:siteRoots.map(n=>n.name),geometryUnchanged:true,
  restore(){for(const[n,state]of originalTransforms){n.position.copy(state.position);n.quaternion.copy(state.quaternion);n.scale.copy(state.scale);n.matrix.copy(state.matrix);n.matrixAutoUpdate=state.matrixAutoUpdate}parent.scale.copy(previousScale);parent.updateWorldMatrix(true,true);cache.delete(visual)}};
 cache.set(visual,report);return report;
}
