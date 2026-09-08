import {subtractBoxFromGeometry} from './building_entry.mjs';
import {resolveRoomRect,createBuildingContentRoot} from './building_room_profiles.mjs';

const HOME_HASHES = {
  old_town_narrow_townhouse_v1:'fd0178400e608c44f4c7c8841d9a308e0ae2ec4db4df36033f04401f9b135067',
  eastside_garden_walkup_v1:'627e644d51f0488d67bc476498a0ae5404e522fa0c7a240c1ecd9f4b0d287f10',
  eastside_stepped_apartment_v1:'5af57644b8896f3062b69a26c10aa393b2a6364899b5ef71ab28aac6156ebbba',
  coastal_orchard_house_v1:'ac9b33396f0773823d74a517ec8764438bd8b2bd253110a0cf3806310f5b9f20',
  garden_lane_house_v1:'c15b6c3f8360a504a76f35e4b96510c18fb30a321db75651a8260bd965540c37',
  hillstep_chalet_v1:'26f0868537c6e95136cdf69f9d3a7a554b61b29e974fc1949cdd94f8819c8714',
  pine_ridge_cottage_v1:'0ee0526b4389a356006396310d796c69080ddcd976ecac24d7dd7c424e2a0da3',
  veranda_bungalow_v1:'8adf5797cf739c73bf5b3a7d0586406dade6f1a3b566c18cda2c0a510ba5aa5b',
  woodland_crosswing_house_v1:'060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b',
};
export const ADDITIONAL_ENTRY_PROFILES = Object.freeze({
  ...Object.fromEntries(Object.entries(HOME_HASHES).map(([id,sha256],i)=>[id,Object.freeze({sha256,
    leaf:i<3?'DoorLeaf':'PublicDoor',detailNames:i<3?[]:['PublicDoorKnob'],outward:1,
    roomHalfWidth:i===4?1.35:1.4,roomDepth:3.3,roomHeight:id==='veranda_bungalow_v1'?2.95:3.35,hardware:true})])),
  pawnshop:{sha256:'1a95f97569d94d162d2d0c4217e1435a2b9e5860a49a2d140d90e4d899d6232f',leaf:'Double oak door',detailNames:['Door handle','Door handle.001','Door brass split'],outward:1,split:true,roomHalfWidth:2,roomDepth:3.8,roomHeight:3.6},
  print_shop:{sha256:'ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97',leaf:'Burgundy entry door',detailNames:[],outward:1,roomHalfWidth:1.6,roomDepth:4,roomHeight:3.7,hardware:true},
  gun_shop:{sha256:'e97d6fac4097af61eaf45ad79d84caf5eadf5f167d3ff3acebfae72ff42d9755',leaf:'Armored public door',detailNames:['Door pull','Door pull.001','Door reinforcement','Door reinforcement.001'],outward:1,split:true,roomHalfWidth:2,roomDepth:3.8,roomHeight:3.6},
  bookmaker:{sha256:'cf7da54c2037182ca975bf5d08c291a8c7a41e7a1107c7f223b5522468ce8d70',leaf:'Glazed burgundy door',detailNames:['Door pull','Door pull.001','Door brass split'],outward:1,split:true,roomHalfWidth:1.9,roomDepth:3.8,roomHeight:3.6},
  nightclub:{sha256:'624967d9ad8e11bd105e314794af8371c67e8d0bd3a2d00855243b56371a9415',leaf:'DoorLeaf_Main',detailNames:['DoorGlowPanel'],detailPrefix:'CANON_DOOR_020_DoorGlowPanel_',outward:1,roomHalfWidth:1.8,roomDepth:3.6,roomHeight:3.4,hardware:true},
  civic_hall:{sha256:'81a289dc228032ae4bd0a7f610a06527f9eac36ca3ee8efdc1be312053e4ad3c',leaves:['CivicHall_DoorLeaf_Main_L','CivicHall_DoorLeaf_Main_R'],detailNames:['CivicHall_DoorGlass_L','CivicHall_DoorGlass_R','CivicHall_DoorHandle_L','CivicHall_DoorHandle_R'],detailPrefixes:['CANON_DOOR_021_CivicHall_DoorGlass_L_','CANON_DOOR_022_CivicHall_DoorGlass_R_'],outward:-1,floor:.94,roomHalfWidth:1.57,roomDepth:6.2,roomHeight:3.8,movePorticoColumns:true},
  hospital:{sha256:'542b901c3bd0abebf4ac8a3590cbf30047eb748abb7ab3216fa18ec6ecd780a8',leaves:['DOOR_HOSPITAL_PUBLIC_MAIN_GlassLeaf','DOOR_HOSPITAL_PUBLIC_MAIN_GlassLeaf.001'],detailNames:['DOOR_HOSPITAL_PUBLIC_MAIN_Handle','DOOR_HOSPITAL_PUBLIC_MAIN_Handle.001','DOOR_HOSPITAL_PUBLIC_MAIN_KickPlate','DOOR_HOSPITAL_PUBLIC_MAIN_KickPlate.001'],detailPrefixes:['CANON_DOOR_017_','CANON_DOOR_018_'],outward:-1,floor:.96,roomHalfWidth:2.4,roomDepth:4.8,roomHeight:3.4},
  glass_pavilion_small_v1:{sha256:'ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873',leaves:['Small_Public_Double_Door_GLASS_LEAF_L','Small_Public_Double_Door_GLASS_LEAF_R'],detailNames:['Small_Public_Double_Door_BRASS_PULL_L','Small_Public_Double_Door_BRASS_PULL_R','Small_Public_Double_Door_BURGUNDY_RAIL_L','Small_Public_Double_Door_BURGUNDY_RAIL_R'],outward:1,floor:.45,roomHalfWidth:2.4,roomDepth:3.15,roomHeight:3.8},
  compact_podium_glass_tower_v1:{sha256:'caa4b79ab28993e3a8c84054f5366de2df94a4d70ff76f7073d01dd73caea531',leaves:['Runtime_TowerDoor_Left','Runtime_TowerDoor_Right'],detailNames:[],outward:1,floor:.21,roomHalfWidth:2,roomDepth:5.6,roomHeight:3.5,mergedDoor:true},
});
const normalize = name => name.replace(/[.\[\]:/]/g,'').replace(/\s/g,'_');
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const attached=new WeakMap();

// Tower's authored doors are material components inside one merged GLB mesh.
// Extract only audited connected components, never a guessed EntranceAnchor.
function towerDoorParts(THREE,visual){
  const inverse=new THREE.Matrix4().copy(visual.matrixWorld).invert(),parts=[];
  visual.traverse(node=>{
    if(!node.isMesh||Array.isArray(node.material)||!['SmokedTealGlass','AgedBrass','BurgundyAccent'].includes(node.material.name))return;
    const geometry=node.geometry,position=geometry.attributes.position,toVisual=new THREE.Matrix4().multiplyMatrices(inverse,node.matrixWorld);
    const parent=Array.from({length:position.count},(_,i)=>i),keys=new Map();
    const find=i=>{while(parent[i]!==i){parent[i]=parent[parent[i]];i=parent[i]}return i};
    const join=(a,b)=>{parent[find(a)]=find(b)};
    for(let i=0;i<position.count;i++){const key=[position.getX(i),position.getY(i),position.getZ(i)].map(v=>Math.round(v*1e5)).join(',');if(keys.has(key))join(i,keys.get(key));else keys.set(key,i)}
    const count=geometry.index?.count??position.count,index=i=>geometry.index?geometry.index.getX(i):i;
    for(let i=0;i<count;i+=3){join(index(i),index(i+1));join(index(i+1),index(i+2))}
    const components=new Map();for(let i=0;i<count;i+=3){const root=find(index(i));if(!components.has(root))components.set(root,[]);components.get(root).push(index(i),index(i+1),index(i+2))}
    for(const indices of components.values()){
      const box=new THREE.Box3();for(const i of indices)box.expandByPoint(new THREE.Vector3().fromBufferAttribute(position,i).applyMatrix4(toVisual));
      const b=box,size=b.getSize(new THREE.Vector3()),center=b.getCenter(new THREE.Vector3());
      const glass=node.material.name==='SmokedTealGlass'&&Math.abs(size.x-1.38)<.05&&Math.abs(b.min.y-.12)<.04&&Math.abs(b.max.y-2.84)<.04&&center.z>6.7&&center.z<6.95;
      const handle=node.material.name==='AgedBrass'&&size.x<.1&&b.min.y>.99&&b.max.y<1.85&&b.min.z>6.98&&center.x>-3.4&&center.x<-2.6;
      const rail=node.material.name==='BurgundyAccent'&&b.min.x<-4.5&&b.max.x>-1.5&&b.min.y>.35&&b.max.y<.62&&b.min.z>6.85;
      if(!glass&&!handle&&!rail)continue;
      const component=geometry.clone();component.setIndex(indices);component.clearGroups();component.addGroup(0,indices.length,0);
      parts.push({geometry:component,material:node.material,matrix:toVisual,kind:glass?'glass':handle?'handle':'rail'});
    }
  });
  if(parts.filter(p=>p.kind==='glass').length!==2)throw Error('Tower door components changed; refusing an entrance at the incorrect anchor');
  const output=[];
  for(const[side,minX,maxX]of [['Left',-4.44,-3],['Right',-3,-1.56]]){
    const box=new THREE.Box3(new THREE.Vector3(minX,.1,6.72),new THREE.Vector3(maxX,2.88,7.1));
    const positions=[],normals=[],uvs=[],materials=[],groups=[];
    for(const part of parts){
      const clipped=subtractBoxFromGeometry(THREE,part.geometry,part.matrix,box,true);if(!clipped.attributes.position.count){clipped.dispose();continue}
      clipped.applyMatrix4(part.matrix);const offset=positions.length/3,position=clipped.attributes.position,normal=clipped.attributes.normal,uv=clipped.attributes.uv;
      for(let i=0;i<position.count;i++){positions.push(position.getX(i),position.getY(i),position.getZ(i));normals.push(normal?.getX(i)??0,normal?.getY(i)??0,normal?.getZ(i)??1);uvs.push(uv?.getX(i)??0,uv?.getY(i)??0)}
      groups.push([offset,position.count,materials.length]);materials.push(part.material);clipped.dispose();
    }
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('normal',new THREE.Float32BufferAttribute(normals,3));geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));for(const group of groups)geometry.addGroup(...group);geometry.computeBoundingBox();geometry.computeBoundingSphere();
    const mesh=new THREE.Mesh(geometry,materials);mesh.name='Runtime_TowerDoor_'+side;visual.add(mesh);output.push(mesh);
  }
  for(const part of parts)part.geometry.dispose();
  return output;
}

function subtractRectangle(polygon,rect){
  let inside=polygon;
  const result=[];
  for(const[axis,boundary,sign]of [[0,rect[0],1],[0,rect[2],-1],[1,rect[1],1],[1,rect[3],-1]]){
    if(inside.length<3)break;
    const next=[],outside=[];
    for(let i=0;i<inside.length;i++){
      const a=inside[i],b=inside[(i+1)%inside.length],da=(a[axis]-boundary)*sign,db=(b[axis]-boundary)*sign;
      (da>=0?next:outside).push(a);
      if((da>=0)!==(db>=0)){const t=da/(da-db),p=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];next.push(p);outside.push(p)}
    }
    if(outside.length>=3)result.push(outside);inside=next;
  }
  return result;
}

export function createAdditionalBuildingEntry({THREE,visual,instance,metresPerCell=4.1}){
  if(attached.has(visual))return attached.get(visual);
  const bank=instance?.role==='bank_shell'&&/^bank_(small|medium|large)_shell_v1$/.test(instance.assetId);
  const profile=bank?instance.bankDoorProfile:ADDITIONAL_ENTRY_PROFILES[instance?.assetId];
  if(!profile||instance.binding?.sha256!==profile.sha256||instance.binding?.lod!==0)return null;
  visual.updateWorldMatrix(true,true);
  const extracted=profile.mergedDoor?towerDoorParts(THREE,visual):[];
  visual.updateWorldMatrix(true,true);
  const nodes=[];visual.traverse(n=>{if(n.isMesh)nodes.push(n)});
  const find=name=>{const n=nodes.find(n=>normalize(n.name)===normalize(name));if(!n)throw Error(`Entrance ${instance.assetId}: missing ${name}`);return n};
  const initialLeaves=(profile.leaves??[profile.leaf]).map(find),details=profile.detailNames.map(find);
  for(const prefix of profile.detailPrefixes??(profile.detailPrefix?[profile.detailPrefix]:[]))for(const n of nodes)if(normalize(n.name).startsWith(normalize(prefix))&&!/DEEP_INTERIO|FURNITUR|WARM_SCO/.test(n.name))details.push(n);
  const inverseVisual=new THREE.Matrix4().copy(visual.matrixWorld).invert();
  const nodeToVisual=node=>new THREE.Matrix4().multiplyMatrices(inverseVisual,node.matrixWorld);
  const initialBox=new THREE.Box3();for(const node of initialLeaves)initialBox.union(new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(nodeToVisual(node)));
  const center=initialBox.getCenter(new THREE.Vector3());
  const floorLocal=profile.floor??initialBox.min.y+.015;
  const space=new THREE.Group();space.name='Runtime_Physical_Entry_'+instance.assetId;space.position.set(center.x,floorLocal,center.z);space.rotation.y=profile.outward===-1?Math.PI:0;visual.add(space);space.updateWorldMatrix(true,true);
  const inverseSpace=new THREE.Matrix4().copy(space.matrixWorld).invert();
  const referenceMatrix=node=>new THREE.Matrix4().multiplyMatrices(inverseSpace,node.matrixWorld);
  const boxOf=node=>new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(referenceMatrix(node));
  const orderedLeaves=initialLeaves.slice().sort((a,b)=>boxOf(a).getCenter(new THREE.Vector3()).x-boxOf(b).getCenter(new THREE.Vector3()).x);
  const leaf=orderedLeaves[0],leafBox=new THREE.Box3();for(const node of orderedLeaves)leafBox.union(boxOf(node));
  const halfWidth=(leafBox.max.x-leafBox.min.x)/2+.035,doorHeight=leafBox.max.y;
  const roomLayout=resolveRoomRect(THREE,instance.assetId,visual,space,bank?instance.bankRoomProfile:null),roomRect=roomLayout.rect;
  const [roomMinX,roomMinZ,roomMaxX,roomMaxZ]=roomRect,roomWidth=roomMaxX-roomMinX,roomDepth=roomMaxZ-roomMinZ;
  const roomHalfWidth=Math.max(Math.abs(roomMinX),Math.abs(roomMaxX)),depth=-roomMinZ,height=profile.roomHeight;
  const roomCenterX=(roomMinX+roomMaxX)/2,roomCenterZ=(roomMinZ+roomMaxZ)/2;
  const baseWorldY=space.localToWorld(new THREE.Vector3()).y,rampLength=Math.max(2.2,baseWorldY*4.5);
  const corridorRect=[-halfWidth,Math.min(-.48,roomMaxZ-.1),halfWidth,rampLength+.04];
  const roomBox=new THREE.Box3(new THREE.Vector3(roomMinX,-.6,roomMinZ),new THREE.Vector3(roomMaxX,height,roomMaxZ));
  const doorBox=new THREE.Box3(new THREE.Vector3(-halfWidth,-Math.max(.6,baseWorldY+.1),corridorRect[1]),new THREE.Vector3(halfWidth,doorHeight+.04,rampLength+.04));
  const originalGeometry=[],originalTransforms=[],ownedGeometry=extracted.map(n=>n.geometry),ownedMaterial=[];
  const restoreGeometry=(node,newGeometry)=>{originalGeometry.push([node,node.geometry]);node.geometry=newGeometry;ownedGeometry.push(newGeometry)};
  const doorNodes=new Set([...orderedLeaves,...details]);
  if(profile.floor!==undefined)for(const node of doorNodes){
    const b=boxOf(node);if(b.min.y<-.005){
      const below=new THREE.Box3(new THREE.Vector3(-100,-100,-100),new THREE.Vector3(100,-.005,100));
      restoreGeometry(node,subtractBoxFromGeometry(THREE,node.geometry,referenceMatrix(node),below));
    }
  }
  if(profile.movePorticoColumns)for(const node of nodes){
    if(/^CivicHall_(PorticoColumn|ColumnFoot|ColumnCapital)(002|003)$/.test(normalize(node.name))){
      originalTransforms.push([node,{parent:node.parent,position:node.position.clone(),quaternion:node.quaternion.clone(),scale:node.scale.clone()}]);
      node.position.x+=Math.sign(node.position.x)*.95;node.updateWorldMatrix(true,true);
    }
  }
  let clipped=0;
  for(const node of nodes){
    if(doorNodes.has(node)||!node.visible)continue;
    if(bank&&/^Bank_(Partition|Vault)_/.test(node.name))continue;
    // Authored window display pockets remain visual facade content. Door fake
    // backdrops are deliberately not in this exception: the entrance is real.
    if(/^Small_Interior_/.test(node.name)||/^CANON_WINDOW.*(?:INTERIO|FURNITUR|WARM_)/.test(node.name))continue;
    let isVisible=true;for(let p=node.parent;p&&p!==visual;p=p.parent)if(!p.visible)isVisible=false;
    if(!isVisible)continue;
    const b=boxOf(node);if(!b.intersectsBox(roomBox)&&!b.intersectsBox(doorBox))continue;
    let geometry=node.geometry,temporary=null;
    if(b.intersectsBox(roomBox)){geometry=subtractBoxFromGeometry(THREE,geometry,referenceMatrix(node),roomBox);temporary=geometry}
    if(b.intersectsBox(doorBox)){geometry=subtractBoxFromGeometry(THREE,geometry,referenceMatrix(node),doorBox);temporary?.dispose()}
    restoreGeometry(node,geometry);clipped++;
  }
  const innerWall=new THREE.MeshStandardMaterial({color:'#b7aaa0',roughness:.88,side:THREE.DoubleSide});
  const floorMat=new THREE.MeshStandardMaterial({color:'#58423a',roughness:.84});
  const brass=new THREE.MeshStandardMaterial({color:'#b18a50',metalness:.56,roughness:.34});
  const lampMat=new THREE.MeshStandardMaterial({color:'#ffe2a6',emissive:'#ffb75c',emissiveIntensity:.7,roughness:.4});
  ownedMaterial.push(innerWall,floorMat,brass,lampMat);
  function box(name,x,y,z,w,h,d,material,parent=space){const geometry=new THREE.BoxGeometry(w,h,d);ownedGeometry.push(geometry);const n=new THREE.Mesh(geometry,material);n.name=name;n.position.set(x,y,z);n.castShadow=true;n.receiveShadow=true;parent.add(n);return n}
  box('Entry_Interior_Floor',roomCenterX,-.04,roomCenterZ,roomWidth,.08,roomDepth,floorMat);
  box('Entry_Interior_Left',roomMinX-.045,height/2,roomCenterZ,.09,height,roomDepth,innerWall);
  box('Entry_Interior_Right',roomMaxX+.045,height/2,roomCenterZ,.09,height,roomDepth,innerWall);
  box('Entry_Interior_Rear',roomCenterX,height/2,roomMinZ-.045,roomWidth,height,.09,innerWall);
  for(const[a,b]of [[roomMinX,Math.min(-halfWidth,roomMaxX)],[Math.max(halfWidth,roomMinX),roomMaxX]])if(b>a)box('Entry_Interior_Front',(a+b)/2,height/2,roomMaxZ+.04,b-a,height,.08,innerWall);
  const corridorDepth=Math.max(0,-roomMaxZ);
  if(corridorDepth>0){
    box('Entry_Corridor_Floor',0,-.04,-corridorDepth/2,halfWidth*2,.08,corridorDepth+.02,floorMat);
    for(const sign of [-1,1])box('Entry_Corridor_Wall',sign*(halfWidth+.045),(doorHeight+.04)/2,-corridorDepth/2,.09,doorHeight+.04,corridorDepth,innerWall);
    box('Entry_Corridor_Ceiling',0,doorHeight+.08,-corridorDepth/2,halfWidth*2,.08,corridorDepth,innerWall);
  }
  if(height>doorHeight+.06)box('Entry_Interior_Header',0,(height+doorHeight+.04)/2,roomMaxZ+.04,halfWidth*2,height-doorHeight-.04,.08,innerWall);
  box('Entry_Interior_Ceiling',roomCenterX,height+.04,roomCenterZ,roomWidth,.08,roomDepth,innerWall);
  const contentRoot=createBuildingContentRoot(THREE,space,instance,new THREE.Vector3(roomCenterX,0,roomCenterZ));
  for(let i=0,count=Math.max(1,Math.ceil(roomDepth/6));i<count;i++){
    const z=roomMinZ+roomDepth*(i+.5)/count;
    box('Entry_Warm_Fixture',roomCenterX,height-.08,z,.34,.09,.34,lampMat);
    const light=new THREE.PointLight('#ffd2a0',8,Math.max(7,roomWidth),2);light.position.set(roomCenterX,height-.22,z);space.add(light);
  }
  const rampGeometry=new THREE.BufferGeometry();rampGeometry.setAttribute('position',new THREE.Float32BufferAttribute([
    -halfWidth,0,0,halfWidth,-baseWorldY,rampLength,halfWidth,0,0,
    -halfWidth,0,0,-halfWidth,-baseWorldY,rampLength,halfWidth,-baseWorldY,rampLength,
  ],3));rampGeometry.computeVertexNormals();ownedGeometry.push(rampGeometry);const ramp=new THREE.Mesh(rampGeometry,floorMat);ramp.name='Entry_Continuous_Ramp';ramp.receiveShadow=true;space.add(ramp);
  const recordTransform=node=>{originalTransforms.push([node,{parent:node.parent,position:node.position.clone(),quaternion:node.quaternion.clone(),scale:node.scale.clone()}])};
  const hinges=[],panels=[];
  const split=!!profile.split||orderedLeaves.length>1;
  let rightLeaf=orderedLeaves[1]??null;
  if(profile.split){
    rightLeaf=leaf.clone();rightLeaf.name=leaf.name+'_Right_Leaf';leaf.parent.add(rightLeaf);rightLeaf.updateWorldMatrix(true,false);space.attach(rightLeaf);
    const leftRemoval=new THREE.Box3(new THREE.Vector3(0,-100,-100),new THREE.Vector3(100,100,100));
    const rightRemoval=new THREE.Box3(new THREE.Vector3(-100,-100,-100),new THREE.Vector3(0,100,100));
    const original=leaf.geometry;
    restoreGeometry(leaf,subtractBoxFromGeometry(THREE,original,referenceMatrix(leaf),leftRemoval));
    rightLeaf.geometry=subtractBoxFromGeometry(THREE,original,referenceMatrix(leaf),rightRemoval);ownedGeometry.push(rightLeaf.geometry);
  }
  for(let index=0;index<(split?2:1);index++){
    const hinge=new THREE.Group();hinge.name='Entry_Hinge_'+index;hinge.position.set(index===0?leafBox.min.x:leafBox.max.x,0,0);space.add(hinge);hinge.updateWorldMatrix(true,false);hinges.push(hinge);
    const panel=index===0?leaf:rightLeaf;if(index===0||orderedLeaves.includes(panel))recordTransform(panel);hinge.attach(panel);panels.push(panel);
    for(const detail of details){const b=boxOf(detail),side=b.getCenter(new THREE.Vector3()).x>=0?1:0;if(!split||side===index){recordTransform(detail);hinge.attach(detail)}}
    if(profile.hardware){
      const width=split?halfWidth:halfWidth*2,handleX=index===0?width-.19:-width+.19;
      const geometry=new THREE.CapsuleGeometry(.025,.24,4,8);ownedGeometry.push(geometry);const pull=new THREE.Mesh(geometry,brass);pull.name='Entry_Brass_Pull';pull.position.set(handleX,Math.min(1.08,doorHeight*.48),.15);hinge.add(pull);
      for(const y of [.92,1.2])box('Entry_Handle_Mount',handleX,y,.11,.1,.1,.08,brass,hinge);
      for(const y of [.28,doorHeight-.25]){const g=new THREE.CylinderGeometry(.035,.035,.15,10);ownedGeometry.push(g);const pin=new THREE.Mesh(g,brass);pin.name='Entry_Brass_Hinge';pin.position.set(index===0?.018:-.018,y,.09);hinge.add(pin)}
      // Thin inset brass accents keep the existing clay door colour/silhouette.
      const direction=index===0?1:-1;
      for(const xx of [.11,width-.11])box('Entry_Leaf_Inset_Border',direction*xx,doorHeight*.52,.075,.022,doorHeight*.69,.018,brass,hinge);
      for(const yy of [doorHeight*.175,doorHeight*.865])box('Entry_Leaf_Inset_Border',direction*width/2,yy,.075,width-.2,.022,.018,brass,hinge);
    }
  }
  space.updateWorldMatrix(true,true);
  const polygonBody=(polygon,minYM,maxYM)=>({polygonCR:polygon.map(([x,z])=>{const p=space.localToWorld(new THREE.Vector3(x,0,z));return[p.x/metresPerCell,p.z/metresPerCell]}),minYM,maxYM,buildingEntryId:instance.id});
  const staticBodies=[];
  if(bank)for(const wall of instance.bankLayout.wallRects){
    const [x0,z0,x1,z1]=wall.rect,points=[[x0,z0],[x1,z0],[x1,z1],[x0,z1]].map(([x,z])=>visual.localToWorld(new THREE.Vector3(x,0,z)));
    staticBodies.push({polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:visual.localToWorld(new THREE.Vector3(0,wall.minY,0)).y,maxYM:visual.localToWorld(new THREE.Vector3(0,wall.maxY,0)).y,buildingEntryId:instance.id,bankPartition:wall.name});
  }
  for(const source of instance.collision?.worldBodies??[]){
    let polygons=[source.polygonCR.map(([c,r])=>{const p=space.worldToLocal(new THREE.Vector3(c*metresPerCell,0,r*metresPerCell));return[p.x,p.z]})];
    for(const rect of [roomRect,corridorRect])polygons=polygons.flatMap(p=>subtractRectangle(p,rect));
    staticBodies.push(...polygons.map(p=>polygonBody(p,source.minYM,source.maxYM)));
  }
  // Solid boundaries of the new room; source envelopes preserve the rest.
  const roomWallRects=[[roomMinX-.1,roomMinZ-.1,roomMinX,roomMaxZ],[roomMaxX,roomMinZ-.1,roomMaxX+.1,roomMaxZ],[roomMinX,roomMinZ-.1,roomMaxX,roomMinZ],
    [roomMinX,roomMaxZ,Math.min(-halfWidth,roomMaxX),roomMaxZ+.1],[Math.max(halfWidth,roomMinX),roomMaxZ,roomMaxX,roomMaxZ+.1],
    [-halfWidth-.1,roomMaxZ,-halfWidth,0],[halfWidth,roomMaxZ,halfWidth+.1,0]];
  for(const r of roomWallRects)if(r[2]>r[0]&&r[3]>r[1])staticBodies.push(polygonBody([[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]],baseWorldY,baseWorldY+height));
  let fraction=0,target=0,disposed=false,collisionBodies=null;
  // Placement transforms are fixed for this generation. Avoid 72 recursive
  // matrix updates/inversions for every footprint sample during walking.
  const local=point=>new THREE.Vector3(point.x,point.y??baseWorldY,point.z).applyMatrix4(inverseSpace);
  // Fixed placement: reject distant floor/ceiling samples before allocating
  // vectors and applying the inverse transform. Include room, doorway and ramp.
  const sampleBounds=new THREE.Box3(new THREE.Vector3(Math.min(roomMinX,-halfWidth)-1e-5,-1,Math.min(roomMinZ,corridorRect[1])-1e-5),new THREE.Vector3(Math.max(roomMaxX,halfWidth)+1e-5,height+1,Math.max(roomMaxZ,rampLength+.04)+1e-5)).applyMatrix4(space.matrixWorld);
  const flatPlacement=Math.abs(inverseSpace.elements[4])+Math.abs(inverseSpace.elements[6])<1e-12;
  const outsideSample=(x,z)=>flatPlacement&&(x<sampleBounds.min.x||x>sampleBounds.max.x||z<sampleBounds.min.z||z>sampleBounds.max.z);
  const occupied=point=>{if(!point)return false;const p=local(point);return Math.abs(p.x)<halfWidth+.4&&p.z>-(split?halfWidth:halfWidth*2)-.4&&p.z<.65};
  const report={assetId:instance.assetId,instanceId:instance.id,status:'physical-entry-needs-live-review',sameScene:true,gameplayActive:false,openFraction:0,clippedMeshes:clipped,floorY:baseWorldY,room:{halfWidth:roomHalfWidth,depth,height,minX:roomMinX,maxX:roomMaxX,minZ:roomMinZ,maxZ:roomMaxZ,width:roomWidth,usableDepth:roomDepth,area:roomWidth*roomDepth,source:roomLayout.source},contentRootId:contentRoot.name,openingWidth:halfWidth*2};
  const inRoom=p=>p.x>=roomMinX-1e-6&&p.x<=roomMaxX+1e-6&&p.z>=roomMinZ-1e-6&&p.z<=roomMaxZ+1e-6;
  const inCorridor=p=>Math.abs(p.x)<=halfWidth+1e-6&&p.z>=corridorRect[1]-1e-6&&p.z<=1e-6;
  const api={visual,object:space,instance,report,contentRoot,
    proximity(point,distance=2.45){const p=local(point),d=Math.hypot(p.x,p.z);return Math.abs(p.x)<Math.max(1.2,halfWidth+.5)&&Math.abs(p.y)<2&&d<distance?{distance:d,anchor:space.localToWorld(new THREE.Vector3(0,Math.min(2,doorHeight),.15)),action:target?'Закрыть дверь':'Открыть дверь',fraction,opening:!!target,instanceId:instance.id}:null},
    interact(point){if(!api.proximity(point))return{accepted:false,reason:'out-of-range'};if(target&&occupied(point))return{accepted:false,reason:'door-sweep-occupied'};target=target?0:1;return{accepted:true,opening:!!target}},
    update(dt,point){if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid entry timestep');if(!target&&fraction>0&&occupied(point))target=1;const previous=fraction;fraction+=clamp(target-fraction,-Math.min(dt,.1)/.65,Math.min(dt,.1)/.65);if(previous===fraction)return;collisionBodies=null;const eased=fraction*fraction*(3-2*fraction);hinges.forEach((h,i)=>{h.rotation.y=(i===0?1:-1)*eased*Math.PI/2});space.updateWorldMatrix(true,true);report.openFraction=fraction},
    // Read-only cache, invalidated by actual hinge motion (including reopening
    // when a person enters the closing sweep), never by a proximity query.
    getCollisionBodies(){if(collisionBodies)return collisionBodies;const result=staticBodies.slice();for(const panel of panels){if(!panel.geometry.boundingBox)panel.geometry.computeBoundingBox();const b=panel.geometry.boundingBox,points=[[b.min.x,b.min.z],[b.max.x,b.min.z],[b.max.x,b.max.z],[b.min.x,b.max.z]].map(([x,z])=>panel.localToWorld(new THREE.Vector3(x,b.min.y,z)));result.push({polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseWorldY-.05,maxYM:baseWorldY+doorHeight,buildingEntryId:instance.id,movingDoor:true})}collisionBodies=result;return collisionBodies},
    containsInterior(point){const p=local(point);return inRoom(p)||(inCorridor(p)&&p.z<-.18)},
    floorHeight(x,z){if(outsideSample(x,z))return null;const p=local({x,z});if(inRoom(p)||inCorridor(p))return baseWorldY;if(Math.abs(p.x)<=halfWidth+1e-6&&p.z>=-1e-6&&p.z<=rampLength+1e-6)return baseWorldY*clamp(1-p.z/rampLength,0,1);return null},
    ceilingHeight(point){if(outsideSample(point.x,point.z))return null;const p=local(point);return inRoom(p)?baseWorldY+height:inCorridor(p)?baseWorldY+doorHeight+.04:null},
    approachPoint(){return space.localToWorld(new THREE.Vector3(0,-baseWorldY,Math.min(2.1,rampLength-.1)))},
    roomPoint(){return space.localToWorld(new THREE.Vector3(0,0,-Math.min(depth-.6,2.4)))},
    roomCenterPoint(){return space.localToWorld(new THREE.Vector3(roomCenterX,0,roomCenterZ))},
    vaultPoint:bank?()=>visual.localToWorld(new THREE.Vector3(...instance.bankLayout.roomLabels.find(r=>r.id==='vault').center)):null,
    dispose(){if(disposed)return;disposed=true;for(const[node,state]of originalTransforms){state.parent.add(node);node.position.copy(state.position);node.quaternion.copy(state.quaternion);node.scale.copy(state.scale)}for(const[node,geometry]of originalGeometry.slice().reverse())node.geometry=geometry;space.removeFromParent();for(const node of extracted)node.removeFromParent();for(const geometry of ownedGeometry)geometry.dispose();for(const material of ownedMaterial)material.dispose();attached.delete(visual)},
  };
  attached.set(visual,api);return api;
}
