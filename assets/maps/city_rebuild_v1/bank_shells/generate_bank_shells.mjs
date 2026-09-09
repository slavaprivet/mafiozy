// Deterministic, dependency-free GLB authoring for explicitly requested empty
// bank shells. These are /walk preview assets, never gameplay activation.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const positions=[],normals=[],indices=[];
for(const [normal,corners]of [
 [[1,0,0],[[.5,-.5,.5],[.5,-.5,-.5],[.5,.5,-.5],[.5,.5,.5]]],
 [[-1,0,0],[[-.5,-.5,-.5],[-.5,-.5,.5],[-.5,.5,.5],[-.5,.5,-.5]]],
 [[0,1,0],[[-.5,.5,.5],[.5,.5,.5],[.5,.5,-.5],[-.5,.5,-.5]]],
 [[0,-1,0],[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5]]],
 [[0,0,1],[[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]]],
 [[0,0,-1],[[.5,-.5,-.5],[-.5,-.5,-.5],[-.5,.5,-.5],[.5,.5,-.5]]],
]){const start=positions.length/3;for(const point of corners){positions.push(...point);normals.push(...normal)}indices.push(start,start+1,start+2,start,start+2,start+3)}
const vertex=Buffer.from(new Float32Array(positions).buffer),normal=Buffer.from(new Float32Array(normals).buffer),index=Buffer.from(new Uint16Array(indices).buffer),binary=Buffer.concat([vertex,normal,index]);
const materials=[
 {name:'Bank_Light_Limestone',pbrMetallicRoughness:{baseColorFactor:[.76,.7,.57,1],metallicFactor:0,roughnessFactor:.84}},
 {name:'Bank_Warm_Stone_Trim',pbrMetallicRoughness:{baseColorFactor:[.91,.85,.7,1],metallicFactor:0,roughnessFactor:.72}},
 {name:'Bank_Burgundy_Door',pbrMetallicRoughness:{baseColorFactor:[.20,.047,.045,1],metallicFactor:.15,roughnessFactor:.45}},
 {name:'Bank_Brass',pbrMetallicRoughness:{baseColorFactor:[.64,.43,.15,1],metallicFactor:.65,roughnessFactor:.31}},
 {name:'Bank_Slate_Roof',pbrMetallicRoughness:{baseColorFactor:[.15,.19,.2,1],metallicFactor:.05,roughnessFactor:.88}},
];
const entries=[];
for(const [size,width,depth]of [['small',18,14],['medium',26,20],['large',34,26]]){
 const id=`bank_${size}_shell_v1`,nodes=[],W=width/2,D=depth/2,wall=.3,front=D+.15;
 const add=(name,x,y,z,w,h,d,material)=>{nodes.push({name,mesh:material,translation:[x,y,z],scale:[w,h,d]});};
 add('Bank_Floor',0,0,0,width+.6,.2,depth+.6,1);
 add('Bank_Wall_Left',-W-.15,2.35,0,wall,4.5,depth+.6,0);
 add('Bank_Wall_Right',W+.15,2.35,0,wall,4.5,depth+.6,0);
 add('Bank_Wall_Rear',0,2.35,-D-.15,width,4.5,wall,0);
 const opening=3.16,frontWidth=W-opening/2;
 add('Bank_Wall_Front_Left',-(W+opening/2)/2,2.35,front,frontWidth,4.5,wall,0);
 add('Bank_Wall_Front_Right',(W+opening/2)/2,2.35,front,frontWidth,4.5,wall,0);
 add('Bank_Wall_Front_Header',0,3.97,front,opening,1.26,wall,0);
 add('Bank_Roof',0,4.79,0,width+.96,.38,depth+.96,4);
 add('Bank_Cornice_Front',0,4.56,D+.36,width+.84,.26,.28,1);
 add('Bank_Cornice_Rear',0,4.56,-D-.36,width+.84,.26,.28,1);
 add('Bank_Cornice_Left',-W-.36,4.56,0,.28,.26,depth+.84,1);
 add('Bank_Cornice_Right',W+.36,4.56,0,.28,.26,depth+.84,1);
 for(const x of [-W+.45,-W*.52,W*.52,W-.45]){
  add(`Bank_Pilaster_${x}`,x,2.25,D+.35,.36,4.3,.22,1);
  add(`Bank_Pilaster_Capital_${x}`,x,4.31,D+.38,.55,.2,.28,1);
 }
 add('Bank_Door_Frame_L',-1.51,1.7,front,.16,3.2,.29,3);
 add('Bank_Door_Frame_R',1.51,1.7,front,.16,3.2,.29,3);
 add('Bank_Door_Frame_Header',0,3.23,front,3.18,.18,.29,3);
 add('Bank_Door_L',-.71,1.6,front,1.4,3,.13,2);
 add('Bank_Door_R',.71,1.6,front,1.4,3,.13,2);
 add('Bank_Handle_L',-.16,1.49,front+.135,.065,.64,.11,3);
 add('Bank_Handle_R',.16,1.49,front+.135,.065,.64,.11,3);
 add('Bank_Sign_Plaque',0,3.86,D+.34,4.35,.56,.16,2);
 // A small geometric brass emblem makes the simple frontage legible without
 // embedding a font, texture, external image or a false claim of final art.
 for(const x of [-.3,0,.3])add(`Bank_Emblem_Column_${x}`,x,3.86,D+.44,.105,.28,.065,3);
 add('Bank_Emblem_Base',0,3.68,D+.44,.87,.065,.065,3);
 add('Bank_Emblem_Cap',0,4.04,D+.44,.87,.065,.065,3);
 // Copy the world.html / three_preview.js bank zoning proportions: public
 // lobby, rear staff / security / lounge strips and the two rear room splits.
 // The formerly separate vault scene fits inside the rear central strip here;
 // its depth is compacted explicitly, keeping the existing exterior envelope.
 const sourceCfg={small:{W:28,H:24,counterRow:15},medium:{W:36,H:30,counterRow:19},large:{W:44,H:36,counterRow:23}}[size];
 const sw=sourceCfg.W,sh=sourceCfg.H,archRow=sourceCfg.counterRow-4,staffEnd=sw*.38,loungeStart=sw*.62;
 const X=c=>-W+c/sw*width,Z=r=>-D+r/sh*depth,wallRects=[];
 const wallRect=(name,x0,z0,x1,z1,material=0)=>{add(name,(x0+x1)/2,2.35,(z0+z1)/2,x1-x0,4.5,z1-z0,material);wallRects.push({name,rect:[x0,z0,x1,z1],minY:.1,maxY:4.6})};
 const hWall=(name,c0,c1,r,material=0)=>{if(c1>c0)wallRect(name,X(c0),Z(r)-.12,X(c1),Z(r)+.12,material)};
 const vWall=(name,c,r0,r1,material=0)=>wallRect(name,X(c)-.12,Z(r0),X(c)+.12,Z(r1),material);
 const gaps=[[Math.max(.8,staffEnd*.23),Math.min(staffEnd-.4,staffEnd*.23+2.4)],[sw/2-3,sw/2+3],[loungeStart+.45,Math.min(sw-.6,loungeStart+2.85)]];
 let cursor=0;for(let i=0;i<gaps.length;i++){hWall(`Bank_Partition_Arch_${i}`,cursor,gaps[i][0],archRow);cursor=gaps[i][1]}
 hWall('Bank_Partition_Arch_End',cursor,sw,archRow);
 vWall('Bank_Partition_Staff_Security',staffEnd,0,archRow);
 vWall('Bank_Partition_Security_Lounge',loungeStart,0,archRow);
 const splits=[{name:'Staff',r:Math.max(5,Math.floor(archRow*.54)),c0:0,c1:staffEnd,door:staffEnd*.52},{name:'Lounge',r:Math.max(5,Math.floor(archRow*.58)),c0:loungeStart,c1:sw,door:(loungeStart+sw)/2}];
 for(const split of splits){const half=Math.max(1,1.15*sw/width/2);hWall(`Bank_Partition_${split.name}_Rear_L`,split.c0,split.door-half,split.r);hWall(`Bank_Partition_${split.name}_Rear_R`,split.door+half,split.c1,split.r)}
 const vaultRow=archRow*.60,vaultDoorHalf=1.05*sw/width;
 hWall('Bank_Vault_Front_L',staffEnd,sw/2-vaultDoorHalf,vaultRow,4);
 hWall('Bank_Vault_Front_R',sw/2+vaultDoorHalf,loungeStart,vaultRow,4);
 add('Bank_Vault_Door_Header',0,3.85,Z(vaultRow),2.1,1.5,.3,4);
 // Labels are metadata until furnishings and signs are authored separately.
 const roomLabels=[
  {id:'public_lobby',label:'Операционный зал',center:[0,.1,Z((archRow+sh)/2)]},
  {id:'staff_office',label:'Персонал',center:[X(staffEnd/2),.1,Z((splits[0].r+archRow)/2)]},
  {id:'archive_manager',label:'Кабинет / архив',center:[X(staffEnd/2),.1,Z(splits[0].r/2)]},
  {id:'security_approach',label:'Доступ к хранилищу',center:[0,.1,Z((vaultRow+archRow)/2)]},
  {id:'vault',label:'Хранилище',center:[0,.1,Z(vaultRow/2)]},
  {id:'staff_lounge',label:'Комната отдыха',center:[X((loungeStart+sw)/2),.1,Z((splits[1].r+archRow)/2)]},
  {id:'meeting_room',label:'Переговорная',center:[X((loungeStart+sw)/2),.1,Z(splits[1].r/2)]},
 ];
 const layout={source:'world.html _BINT/_isBlockedBankInterior and three_preview.js bank renderer',sourceConfig:sourceCfg,sourceVault:{width:Math.floor(sw*.26),depth:Math.floor(sh*.55)},mapping:'Lobby grid linearly mapped into authored hall. Rear divisions at .38/.62 width and counterRow-4; separate source vault scene nested in rear central strip, its depth compressed to .60*archRow. Continuous open 2.10m doorway; no teleport or gameplay activation.',wallCoordinateSpace:'original GLB visual local metres',wallRects,roomLabels,vault:{rect:[X(staffEnd)+.12,-D,X(loungeStart)-.12,Z(vaultRow)-.12],doorway:{center:[0,.1,Z(vaultRow)],width:2.1,height:3}},archRowM:Z(archRow),furnitureDeferred:true};
 const bounds={min:[Infinity,Infinity,Infinity],max:[-Infinity,-Infinity,-Infinity]};
 for(const n of nodes)for(let axis=0;axis<3;axis++){bounds.min[axis]=Math.min(bounds.min[axis],n.translation[axis]-n.scale[axis]/2);bounds.max[axis]=Math.max(bounds.max[axis],n.translation[axis]+n.scale[axis]/2)}
 const gltf={asset:{version:'2.0',generator:'Mafiozi empty bank shell generator v1'},scene:0,scenes:[{name:id,nodes:nodes.map((_,i)=>i)}],nodes,
  meshes:materials.map((m,material)=>({name:m.name,primitives:[{attributes:{POSITION:0,NORMAL:1},indices:2,material}]})),materials,
  buffers:[{byteLength:binary.length}],bufferViews:[{buffer:0,byteOffset:0,byteLength:vertex.length,target:34962},{buffer:0,byteOffset:vertex.length,byteLength:normal.length,target:34962},{buffer:0,byteOffset:vertex.length+normal.length,byteLength:index.length,target:34963}],
  accessors:[{bufferView:0,componentType:5126,count:24,type:'VEC3',min:[-.5,-.5,-.5],max:[.5,.5,.5]},{bufferView:1,componentType:5126,count:24,type:'VEC3'},{bufferView:2,componentType:5123,count:36,type:'SCALAR'}],extras:{previewOnly:true,canonicalGameplayId:`bank:${size}`,gameplayActive:false,artAcceptance:'basic_empty_shell_needs_visual_review'}};
 const raw=Buffer.from(JSON.stringify(gltf)),json=Buffer.concat([raw,Buffer.alloc((4-raw.length%4)%4,32)]),glb=Buffer.alloc(12+8+json.length+8+binary.length);
 glb.writeUInt32LE(0x46546c67,0);glb.writeUInt32LE(2,4);glb.writeUInt32LE(glb.length,8);glb.writeUInt32LE(json.length,12);glb.writeUInt32LE(0x4e4f534a,16);json.copy(glb,20);const offset=20+json.length;glb.writeUInt32LE(binary.length,offset);glb.writeUInt32LE(0x004e4942,offset+4);binary.copy(glb,offset+8);
 fs.writeFileSync(path.join(here,id+'.glb'),glb);
 entries.push({assetId:id,canonicalGameplayId:`bank:${size}`,gameplayActive:false,artAcceptance:'basic_empty_shell_needs_visual_review',role:'bank',binding:{lod:0,url:`/assets/maps/city_rebuild_v1/bank_shells/${id}.glb`,sha256:createHash('sha256').update(glb).digest('hex'),bytes:glb.length},visualBounds:bounds,dimensionsXYZ:bounds.max.map((v,i)=>v-bounds.min[i]),recenterXYZ:[0,0,0],publicDoorLocalXYZ:[0,.1,front],publicDoorEvidence:'authored Bank_Door_L/R bottom midpoint',frontSign:1,hideNodeNames:[],roomProfile:{source:'Authored empty bank shell; clear ground-floor hall',bounds:[-W-.3,-D-.3,W+.3,D+.3],inset:.3},doorProfile:{leaves:['Bank_Door_L','Bank_Door_R'],detailNames:['Bank_Handle_L','Bank_Handle_R'],outward:1,floor:.1,roomHalfWidth:W,roomDepth:depth,roomHeight:4.5},clearRoom:{width,depth,height:4.5,floorY:.1},doorBounds:{min:[-1.41,.1,front-.065],max:[1.41,3.1,front+.065]}});
 entries.at(-1).layout=layout;
}
fs.writeFileSync(path.join(here,'manifest.v1.json'),JSON.stringify({schema:'mafiozi.city-rebuild.bank-shells/v1',status:'BASIC_EMPTY_PREVIEW_SHELLS_REQUIRES_LIVE_QA',scope:'walk_same_scene_rooms_not_gameplay_activation',units:'metres',upAxis:'Y',frontAxis:'+Z',entries},null,2)+'\n');
console.log(JSON.stringify(entries.map(e=>({assetId:e.assetId,bytes:e.binding.bytes,sha256:e.binding.sha256,clearRoom:e.clearRoom})),null,2));
