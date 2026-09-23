// Runtime presentation for the four audited street-lamp GLBs. The manager owns
// a bounded PointLight pool. Daylight removes its zero-radiance members from
// the renderer; night keeps a fixed signature as lamps enter camera range.
export const STREET_LAMP_PROFILES=Object.freeze({
 lamp_pine_v1:Object.freeze({sha256:'fe092a7d5833b2008fa90a54ae0580f03ee19d90f03dd26297ad54f0647b54c1',glows:1,opaque:Object.freeze({Lamp_Base_PINE:'District_Blue',Lamp_Lower_PINE:'Matte_Charcoal',Lamp_Upper_PINE:'Matte_Charcoal'})}),
 lamp_bellini_v1:Object.freeze({sha256:'81c8b123ded3e5b9f2230cf46f91b59ad13b65583b9b9617b9d4e861c63226f5',glows:1,opaque:Object.freeze({Lamp_Base_BELLINI:'District_Gold',Lamp_Lower_BELLINI:'Matte_Charcoal',Lamp_Upper_BELLINI:'Matte_Charcoal',Lamp_Arm_BELLINI:'Matte_Charcoal'})}),
 lamp_civic_double_v1:Object.freeze({sha256:'47ae1fe13f50413fde7ee6a2dc35126765b34ff10ab725bf5983fbaa789a9a89',glows:2,opaque:Object.freeze({Lamp_Base_CIVIC_DOUBLE:'District_Teal',Lamp_Lower_CIVIC_DOUBLE:'Matte_Charcoal',Lamp_Upper_CIVIC_DOUBLE:'Matte_Charcoal',Lamp_Arm_CIVIC_DOUBLE:'Matte_Charcoal'})}),
 lamp_foundry_v1:Object.freeze({sha256:'efed19a8fe04819321de8304e71f9c4e4ed892662e2844cb4bdbdcdb29492bb6',glows:1,opaque:Object.freeze({Lamp_Base_FOUNDRY:'District_Rust',Lamp_Lower_FOUNDRY:'Matte_Charcoal',Lamp_Upper_FOUNDRY:'Matte_Charcoal',Lamp_Arm_FOUNDRY:'Matte_Charcoal'})}),
});

// Retain the first nearest slots in stable fixture order. Distances are
// evaluated once per fixture, and the scratch arrays are reused by the caller.
export function selectNearestLightFixtures(fixtures,origin,limit,selected=[],distances=[]){
 selected.length=distances.length=0;
 for(const entry of fixtures){
  if(!entry.active)continue;
  const distance=entry.world.distanceToSquared(origin);
  let at=selected.length;
  if(at===limit&&distance>=distances[at-1])continue;
  while(at>0&&distance<distances[at-1])at--;
  const last=Math.min(selected.length,limit-1);
  for(let i=last;i>at;i--){selected[i]=selected[i-1];distances[i]=distances[i-1]}
  selected[at]=entry;distances[at]=distance;
 }
 return selected;
}

// staticPlacement is opt-in for a fixed walk generation. Call
// invalidatePlacement() after any lamp/scene transform or ground-height change.
// Focus, day/night intensity and nearest-light assignment still update each frame.
export function createStreetLighting({THREE:T,scene,maxLights=8,maxFixtures=192,activeDistance=34,groundHeight,staticPlacement=false,lightIntensity=18,lightDistance=15}={}){
 if(!T?.PointLight||!scene?.add)throw Error('THREE and scene required');maxLights=Math.max(1,Math.min(16,Math.floor(maxLights)));maxFixtures=Math.max(maxLights,Math.min(384,Math.floor(maxFixtures)));activeDistance=Math.max(4,+activeDistance||34);
 const applications=new WeakMap(),fixtures=[],freeSlots=Array.from({length:maxFixtures},(_,i)=>maxFixtures-1-i),matrix=new T.Matrix4(),rotation=new T.Quaternion().setFromAxisAngle(new T.Vector3(1,0,0),-Math.PI/2),identity=new T.Quaternion(),scale=new T.Vector3(),sceneInverse=new T.Matrix4(),world=new T.Vector3();let disposed=false,night=0,placementDirty=true,activeFixtureCount=0,activeLightCount=0;
 const glass=new T.MeshPhysicalMaterial({name:'StreetLamp_ClearGlass',color:0xb8d8d2,transparent:true,opacity:.34,transmission:.48,thickness:.08,roughness:.14,metalness:.08,clearcoat:1,clearcoatRoughness:.08,depthWrite:false,side:T.DoubleSide});glass.userData.breakableGlass=true;
 const bulbMaterial=new T.MeshStandardMaterial({name:'StreetLamp_SmallBulb',color:0xffe3a7,emissive:0xffba58,emissiveIntensity:.04,roughness:.3,metalness:.04}),bulbGeometry=new T.SphereGeometry(.075,9,6),groundGeometry=new T.CircleGeometry(1,28),groundMaterial=new T.MeshBasicMaterial({name:'StreetLamp_GroundIllumination',color:0xd3a65b,transparent:true,opacity:0,depthWrite:false,toneMapped:true,side:T.DoubleSide});
 const ground=new T.InstancedMesh(groundGeometry,groundMaterial,maxFixtures);ground.name='StreetLamp_GroundLightPool';ground.userData.breakableGlass=false;ground.frustumCulled=false;ground.raycast=()=>{};const bulbs=new T.InstancedMesh(bulbGeometry,bulbMaterial,maxFixtures);bulbs.name='StreetLamp_SmallBulbPool';bulbs.userData.breakableGlass=false;bulbs.frustumCulled=false;bulbs.raycast=()=>{};scene.add(ground,bulbs);const zero=new T.Matrix4().makeScale(0,0,0);for(let i=0;i<maxFixtures;i++){ground.setMatrixAt(i,zero);bulbs.setMatrixAt(i,zero)}ground.instanceMatrix.needsUpdate=bulbs.instanceMatrix.needsUpdate=true;
 const lights=Array.from({length:maxLights},(_,i)=>{const light=new T.PointLight(0xffc978,0,lightDistance,2);light.name=`StreetLamp_PooledLight_${i}`;light.castShadow=false;light.visible=false;light.userData.fixedStreetLightPool=true;scene.add(light);return light});
 const nearest=[],nearestDistances=[],defaultOrigin=new T.Vector3();
 function prepare(visual,instance={}){
  if(disposed)return null;if(applications.has(visual))return applications.get(visual);const profile=STREET_LAMP_PROFILES[instance.assetId];if(!profile||String(instance.binding?.sha256||'').toLowerCase()!==profile.sha256||instance.binding?.lod!==0)return null;if(!visual?.traverse)throw Error('Cloned lamp visual required');
  visual.updateWorldMatrix(true,true);const inverse=visual.matrixWorld.clone().invert(),replacements=[],entries=[],glows=[];visual.traverse(node=>{if(node.isMesh&&/^Glow_/.test(node.name))glows.push(node)});if(glows.length!==profile.glows)throw Error(`${instance.assetId}: expected ${profile.glows} authored glow meshes, found ${glows.length}`);
  for(const glow of glows){if(!freeSlots.length)break;glow.geometry.computeBoundingBox();const localMatrix=new T.Matrix4().multiplyMatrices(inverse,glow.matrixWorld),center=glow.geometry.boundingBox.getCenter(new T.Vector3()).applyMatrix4(localMatrix),size=glow.geometry.boundingBox.getSize(new T.Vector3()),slot=freeSlots.pop();replacements.push({glow,material:glow.material,breakable:glow.userData.breakableGlass});glow.material=glass;glow.userData.breakableGlass=true;glow.castShadow=false;
   const bulbScale=Math.max(.72,Math.min(1.25,Math.min(size.x,size.y,size.z)/.3)),entry={visual,glow,local:center,world:new T.Vector3(),slot,bulbScale,active:true};fixtures.push(entry);entries.push(entry);activeFixtureCount++}
  const report={assetId:instance.assetId,fixtures:entries.length,glassMeshes:glows.length,status:entries.length===profile.glows?'applied-needs-live-review':'fixture-capacity-exhausted'};let ended=false;const api={visual,fixtures:entries,report,dispose(){if(ended)return;ended=true;placementDirty=true;for(const entry of entries){if(entry.active){entry.active=false;activeFixtureCount--}freeSlots.push(entry.slot);ground.setMatrixAt(entry.slot,zero);bulbs.setMatrixAt(entry.slot,zero);const index=fixtures.indexOf(entry);if(index>=0)fixtures.splice(index,1)}ground.instanceMatrix.needsUpdate=bulbs.instanceMatrix.needsUpdate=true;for(const item of replacements){item.glow.material=item.material;if(item.breakable===undefined)delete item.glow.userData.breakableGlass;else item.glow.userData.breakableGlass=item.breakable}applications.delete(visual)}};applications.set(visual,api);placementDirty=true;return api;
 }
 function update(settings={}){
  if(disposed)return;const focus=settings?.isVector3?settings:settings.focus,amount=settings?.isVector3?1:settings.night??settings.intensity??1;night=Math.max(0,Math.min(1,Number.isFinite(amount)?amount:1));const updatePlacement=!staticPlacement||placementDirty;
  // A fixed walk placement never changes any lamp transform between frames.
  // Avoid recursively updating the entire city scene just to reuse the cached
  // fixture positions; this preserves the exact rendered light assignment.
  if(updatePlacement){scene.updateWorldMatrix(true,false);sceneInverse.copy(scene.matrixWorld).invert();}
  if(updatePlacement){for(const entry of fixtures)if(entry.active){entry.visual.localToWorld(entry.world.copy(entry.local));world.copy(entry.world).applyMatrix4(sceneInverse);matrix.compose(world,identity,scale.setScalar(entry.bulbScale));bulbs.setMatrixAt(entry.slot,matrix);const y=typeof groundHeight==='function'?groundHeight(entry.world.x,entry.world.z):settings.groundY??0;world.set(entry.world.x,y+.018,entry.world.z).applyMatrix4(sceneInverse);matrix.compose(world,rotation,scale.setScalar(3.8));ground.setMatrixAt(entry.slot,matrix)}ground.instanceMatrix.needsUpdate=bulbs.instanceMatrix.needsUpdate=true;placementDirty=false}groundMaterial.opacity=.16*night;bulbMaterial.emissiveIntensity=.04+night*1.65;
  // In daylight the pools are completely invisible and every PointLight has
  // zero intensity.  Selecting the closest 176 fixtures per render frame
  // cannot affect the image; defer that work until night is actually enabled.
  if(night<=0){for(const light of lights){light.intensity=0;light.visible=false}activeLightCount=0;return stats()}
  for(const light of lights)light.visible=true;
  const origin=focus?.isVector3?focus:defaultOrigin;selectNearestLightFixtures(fixtures,origin,lights.length,nearest,nearestDistances);activeLightCount=0;for(let i=0;i<lights.length;i++){const light=lights[i],entry=nearest[i],distance=entry?Math.sqrt(nearestDistances[i]):Infinity,falloff=distance<activeDistance?1-Math.pow(distance/activeDistance,2):0;if(entry){light.position.copy(entry.world);light.position.y-=.08}light.intensity=entry?lightIntensity*night*Math.max(0,falloff):0;if(light.intensity>0)activeLightCount++}
  return stats();
 }
 function stats(){
  return{fixtures:activeFixtureCount,activeLights:activeLightCount,fixedLights:lights.length,rendererLights:night>0?lights.length:0,night,maxFixtures,activeGroundPools:activeFixtureCount};
 }
 function dispose(){if(disposed)return;disposed=true;for(const entry of [...fixtures])applications.get(entry.visual)?.dispose();for(const light of lights)light.removeFromParent();ground.removeFromParent();bulbs.removeFromParent();ground.dispose();bulbs.dispose();groundGeometry.dispose();groundMaterial.dispose();bulbGeometry.dispose();bulbMaterial.dispose();glass.dispose()}
 return{prepare,update,stats,dispose,invalidatePlacement(){placementDirty=true},lights,ground,bulbs,materials:Object.freeze({glass,bulb:bulbMaterial,ground:groundMaterial})};
}
