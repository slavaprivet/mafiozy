/** Source-only inventory of preserved landmarks. Does NOT admit editing or render substitutes. */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const T=await import(pathToFileURL(path.join(process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor','build/three.module.js')).href);
assert.equal(T.REVISION,'180');
const sources={};
function read(name){const raw=fs.readFileSync(path.join(root,name));sources[name]=sha(raw);return raw.toString('utf8');}
read('tools/godot/export_map_editor_protected_landmarks.mjs');
const preview=read('three_preview.js'),world=read('world.html');
const catalog=JSON.parse(read('godot/mafiozi_walk/data/map_editor/catalog.json'));
const topology=JSON.parse(read('assets/maps/city_rebuild_v1/topology_for_placement.json'));
let output=path.join(root,'outputs/map_editor_protected_landmarks_source');
for(let i=2;i<process.argv.length;i++){assert.equal(process.argv[i],'--output');output=path.resolve(process.argv[++i]);}
assert(output.startsWith(path.join(root,'outputs')+path.sep));
fs.mkdirSync(path.join(output,'buffers'),{recursive:true});
const recipes={};
function slice(name,text,start,end){const a=text.indexOf(start),b=text.indexOf(end,a+start.length);assert(a>=0&&b>a,name);const code=text.slice(a,b);recipes[name]={source:text===preview?'three_preview.js':'world.html',sha256:sha(code),code};return code;}
const constants=slice('layout',world,'const JAIL_ISLAND_LAYOUT =','function _prisonConvoyVehicleStop');
const jailObject=slice('jailSnapshot',world,'      jail:{','      lair:lairZone?');
const boxCode=slice('box',preview,'      const box =','      // BoxGeometry normally');
const outlineCode=slice('outline',preview,'      const outline =','      const detailMat=');
// Outline end is located by the exact closing declaration, not neighboring implementation names.
recipes.outline.code=outlineCode.slice(0,outlineCode.indexOf('\n      };')+10);
recipes.outline.sha256=sha(recipes.outline.code);
const labelCode=slice('labelSprite',preview,"      const labelSprite=",'      // Exterior names are physical');
recipes.labelSprite.code=labelCode.slice(0,labelCode.indexOf('\n      };')+10);
recipes.labelSprite.sha256=sha(recipes.labelSprite.code);
const bridgeCode=slice('bridge',preview,'        const bridgeWidth=','      if(worldSnapshot?.coast)');
recipes.bridge.code=bridgeCode.slice(0,bridgeCode.lastIndexOf('\n      }'));
recipes.bridge.sha256=sha(recipes.bridge.code);
const prisonCode=slice('prison',preview,'          const visual=jail.visual||{}','        const lair=worldSnapshot.landmarks.lair');
recipes.prison.code=prisonCode.slice(0,prisonCode.lastIndexOf('\n        }'));
recipes.prison.sha256=sha(recipes.prison.code);
slice('mainlandDecorator',preview,"        }else if(kind==='police'){","        }else if(kind==='garage'");
slice('genericSuppression',preview,'      const defsFromSnapshot=','      const buildingDefs=');
slice('colliderOracle',world,'function _prisonIslandCollisionAt','function _inPrisonIslandRestrictedZone');
const bridgeCollisionStart=world.indexOf('return r>=CITY_BRIDGE_R0+.34');
assert(bridgeCollisionStart>0);
recipes.bridgeCollision={source:'world.html',code:world.slice(world.lastIndexOf('function ',bridgeCollisionStart),world.indexOf('\n}',bridgeCollisionStart)+2)};
recipes.bridgeCollision.sha256=sha(recipes.bridgeCollision.code);
const origin=catalog.map?.originM??catalog.originM??[0,0,0];
const coord=catalog.coordinateSystem??{};
const scale=4.1;
const originC=(coord.originM??origin)[0]/scale,originR=(coord.originM??origin)[2]/scale;
assert(Number.isFinite(originR)&&Number.isFinite(originC));
// Drawing is deliberately deferred: no bitmap or approximate font measurements are exported.
// All source geometry dimensions are independent of measureText; only unexported Canvas font size uses it.
const canvases=[];
const document={createElement(kind){assert.equal(kind,'canvas');const canvas={width:0,height:0};const ctx=new Proxy({}, {get(o,key){if(key==='measureText')return ()=>({width:0});if(key==='createLinearGradient'||key==='createRadialGradient')return ()=>({addColorStop(){}});return o[key]??(()=>{});},set(o,k,v){o[k]=v;return true;}});canvas.getContext=()=>ctx;canvases.push(canvas);return canvas;}};
const surfaceCode=slice('surfaceTextures',preview,'      const surfaceTextureCache=','      // One shared vertex-wind');
const textureContext=vm.createContext({THREE:T,document,renderer:{capabilities:{getMaxAnisotropy:()=>16}},scene:new T.Scene()});
vm.runInContext(surfaceCode+';globalThis.exactTextures={cityEnvironment,asphaltTexture,concreteTexture};',textureContext);
const {cityEnvironment:envTexture,asphaltTexture,concreteTexture}=textureContext.exactTextures;
const textureNames=new Map([[envTexture,'cityEnvironment'],[asphaltTexture,'asphaltTexture'],[concreteTexture,'concreteTexture']]);
const context=vm.createContext({THREE:T,document,WORLD_SCALE:scale,originR,originC,scene:new T.Scene(),renderer:{capabilities:{getMaxAnisotropy:()=>16},domElement:{dataset:{}}},cityEnvironment:envTexture,asphaltTexture,concreteTexture,batchStaticOutlines:true,staticOutlineGeometries:[],sharedOutlineMaterial:new T.LineBasicMaterial({color:0x0a111b,transparent:true,opacity:.78}),prisonAlarmBeacons:[],prisonReleaseGate:null,prisonReleaseGateLight:null,prisonVehicleLockGate:null,Math});
const scalarSource=['JAIL_CENTER_R','JAIL_RADIUS_TILES','CITY_CANAL_C0','CITY_BRIDGE_R0','EAST_EXPANSION_R1'].map(name=>{const m=world.match(new RegExp('const '+name+' =[^;]+;'));assert(m,name);return m[0];}).join('\n');
recipes.scalarConstants={source:'world.html',code:scalarSource,sha256:sha(scalarSource)};
vm.runInContext(scalarSource+constants+';globalThis.layout=JAIL_ISLAND_LAYOUT;globalThis.station=JAIL_POLICE_STATION_3D;globalThis.vehicleGate=JAIL_VEHICLE_GATE_3D;globalThis.jail=({'+jailObject+'}).jail;',context);
const canalDeclaration=world.match(/const canal=\{c0:CITY_CANAL_C0[^;]+;/)?.[0];assert(canalDeclaration);
recipes.canalSnapshot={source:'world.html',code:canalDeclaration,sha256:sha(canalDeclaration)};
vm.runInContext('{'+canalDeclaration+'globalThis.originalCanal=canal;}',context);
context.worldSnapshot={canal:context.originalCanal,landmarks:{jail:context.jail}};
vm.runInContext(boxCode+recipes.outline.code+recipes.labelSprite.code+';const canal=worldSnapshot.canal,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;',context);
const buffers=new Map(),geometries=[],materials=[],textures=[],parts=[],geometryIds=new Map(),materialIds=new Map(),textureIds=new Map();
function buffer(a,itemSize=1,normalized=false){const bytes=Buffer.from(a.buffer,a.byteOffset,a.byteLength),hash=sha(bytes);if(!buffers.has(hash)){const file=`buffers/${hash}.bin`;fs.writeFileSync(path.join(output,file),bytes);buffers.set(hash,{sha256:hash,file,bytes:bytes.length});}return {buffer:hash,arrayType:a.constructor.name,itemSize,normalized,count:a.length/itemSize};}
function texture(t){if(textureIds.has(t))return textureIds.get(t);const id=`texture-${textures.length}`;textureIds.set(t,id);textures.push({id,sourceDependency:textureNames.get(t)??'originalCanvas',status:'HOLD_EXACT_PIXELS_AND_SOURCE_SAMPLER_ADMISSION',width:t.image?.width??null,height:t.image?.height??null,colorSpace:t.colorSpace,flipY:t.flipY,generateMipmaps:t.generateMipmaps,minFilter:t.minFilter,magFilter:t.magFilter,wrapS:t.wrapS,wrapT:t.wrapT,anisotropy:t.anisotropy,mapping:t.mapping,repeat:t.repeat.toArray(),offset:t.offset.toArray(),recipeOwner:context.exportOwner});return id;}
function material(m){if(materialIds.has(m))return materialIds.get(m);const id=`material-${materials.length}`;materialIds.set(m,id);const data={id,type:m.type,properties:{},textures:{}};for(const [k,v]of Object.entries(m)){if(v?.isTexture)data.textures[k]=texture(v);else if(v?.isColor)data.properties[k]={linear:v.toArray()};else if(v===null||['number','boolean','string'].includes(typeof v)){if(!['uuid','id','version','name'].includes(k))data.properties[k]=Number.isFinite(v)||typeof v!=='number'?v:null;}}materials.push(data);return id;}
function geometry(g){if(geometryIds.has(g))return geometryIds.get(g);const id=`geometry-${geometries.length}`;geometryIds.set(g,id);const attrs={};for(const[k,a]of Object.entries(g.attributes)){attrs[k]=a.isInterleavedBufferAttribute?{...buffer(a.data.array,a.itemSize,a.normalized),count:a.count,stride:a.data.stride,offset:a.offset,interleaved:true}:buffer(a.array,a.itemSize,a.normalized);}geometries.push({id,type:g.type,attributes:attrs,index:g.index?buffer(g.index.array):null,groups:g.groups,drawRange:{start:g.drawRange.start,count:Number.isFinite(g.drawRange.count)?g.drawRange.count:null}});return id;}
function harvest(owner){context.scene.updateMatrixWorld(true);const ownerParts=[];context.scene.traverse(o=>{if(!o.isMesh&&!o.isLineSegments&&!o.isSprite&&!o.isLight)return;const p={id:`${owner}/part:${ownerParts.length}`,owner,type:o.type,name:o.name,worldMatrix:o.matrixWorld.toArray(),visible:o.visible,castShadow:o.castShadow,receiveShadow:o.receiveShadow,renderOrder:o.renderOrder,layers:o.layers.mask};if(o.geometry)p.geometry=geometry(o.geometry);if(o.material)p.materials=(Array.isArray(o.material)?o.material:[o.material]).map(material);if(o.isInstancedMesh){p.count=o.count;p.matrices=buffer(o.instanceMatrix.array,16);if(o.instanceColor)p.colors=buffer(o.instanceColor.array,3);}if(o.isLight){p.light={colorLinear:o.color.toArray(),intensity:o.intensity,distance:o.distance??null,decay:o.decay??null,angle:o.angle??null,penumbra:o.penumbra??null,target:o.target?.matrixWorld.toArray()??null};}parts.push(p);ownerParts.push(p);});for(const g of context.staticOutlineGeometries){parts.push({id:`${owner}/outline:${ownerParts.length}`,owner,type:'LineSegments',geometry:geometry(g),materials:[material(context.sharedOutlineMaterial)],worldMatrix:new T.Matrix4().toArray(),visible:true,castShadow:false,receiveShadow:false,renderOrder:0,layers:1});ownerParts.push(parts.at(-1));}return ownerParts;}
context.exportOwner='protected-landmarks:red-bridge';vm.runInContext('{'+recipes.bridge.code+'}',context);const bridgeParts=harvest(context.exportOwner);
const seawallGeometryIds=geometries.filter(g=>g.type==='BoxGeometry'&&g.attributes.position.count===24).filter(g=>{const original=[...geometryIds].find(([,id])=>id===g.id)[0];return original.parameters.width===.45*scale&&original.parameters.depth===150*scale&&original.parameters.height===1.15;}).map(g=>g.id);
const seawallParts=bridgeParts.filter(p=>seawallGeometryIds.includes(p.geometry));assert.equal(seawallParts.length,2);
for(const p of seawallParts)p.detachedDependency='full-canal-seawall-not-bridge-span';
context.scene=new T.Scene();context.staticOutlineGeometries=[];context.exportOwner='protected-landmarks:police-island';vm.runInContext('{'+recipes.prison.code+'}',context);const prisonParts=harvest(context.exportOwner);
function bounds(list){const box=new T.Box3();for(const p of list){if(!p.geometry||p.type==='Sprite')continue;const g=[...geometryIds].find(([,id])=>id===p.geometry)[0],a=g.attributes.position;const base=new T.Matrix4().fromArray(p.worldMatrix),count=p.count??1,inst=new T.Matrix4(),m=new T.Matrix4(),v=new T.Vector3();const raw=p.matrices?fs.readFileSync(path.join(output,buffers.get(p.matrices.buffer).file)):null;const floats=raw?new Float32Array(raw.buffer,raw.byteOffset,raw.length/4):null;for(let i=0;i<count;i++){m.copy(base);if(floats)m.multiply(inst.fromArray(floats,i*16));for(let j=0;j<a.count;j++){v.fromBufferAttribute(a,j).applyMatrix4(m);box.expandByPoint(v);}}}return {min:box.min.toArray(),max:box.max.toArray()};}
const locked={ownerRequired:true,editable:false,movable:false,cloneable:false,availableUnlock:false,acceptance:'INVENTORY_ONLY_NOT_NATIVE_OR_LIVE_ADMITTED'};
const records=[{...locked,key:'protected-landmarks:red-bridge',canonicalGameId:null,sourceTopologyCrossingId:'XR-RED-01',keyDerivation:'three_preview.js original premium bridge source branch',anchorGridRC:[51.5,90],factoryRecipe:'bridge',parts:bridgeParts.map(p=>p.id),boundsWorld:bounds(bridgeParts),collisionRecipe:'bridgeCollision',dependencies:['canal','road navigation','water','cityEnvironment','asphaltTexture']},{...locked,key:'protected-landmarks:police-island',canonicalGameId:'police',canonicalIdNamespace:'world.html POI.id (not editor or server custody identifier)',keyDerivation:'three_preview.js worldSnapshot.landmarks.jail',anchorGridRC:[76,89.5],authorityAnchorGridRC:[76,76],factoryRecipe:'prison',parts:prisonParts.map(p=>p.id),boundsWorld:bounds(prisonParts),collisionRecipe:'colliderOracle',layout:context.layout,policeStation:context.station,vehicleGate:context.vehicleGate,sourceSnapshot:context.jail,dependencies:['world.html authority','personal release timer','police interior','convoy','staff NPC navigation','water','concreteTexture']},{...locked,key:'protected-landmarks:police-mainland-source',canonicalGameId:'police',anchorGridRC:[76,76],factoryRecipe:'mainlandDecorator',parts:[],status:'SOURCE_RECIPE_ONLY_GENERIC_MASS_SUPPRESSED_BY_CURRENT_JAIL_OWNER',suppressionRecipe:'genericSuppression'}];
records[0].bridgeSpanBoundsWorld=bounds(bridgeParts.filter(p=>!p.detachedDependency));records[0].detachedDependencies=seawallParts.map(p=>p.id);
const crossings=[];function collectCrossing(v){if(!v||typeof v!=='object')return;if(v.id==='XR-RED-01')crossings.push(v);for(const q of Object.values(v))collectCrossing(q);}collectCrossing(topology);assert.equal(crossings.length,1);assert.equal(crossings[0].style,'premium_red_suspension');assert.deepEqual(crossings[0].centerline_grid_cr,[[78.25,51.5],[101.75,51.5]]);records[0].sourceTopologyDescriptor=crossings[0];
const manifest={schema:'mafiozi.protected-landmarks-source/v1',threeRevision:T.REVISION,worldScale:scale,originGridRC:[originR,originC],sourceReceipts:sources,records,recipes,parts,geometries,materials,textures,buffers:[...buffers.values()],holds:['No native scene admission','No authority or navigation adapter','No Canvas/environment/asphalt/concrete raster substitutes','Mainland generic building is suppressed by jail in original source']};
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
let checks=0;for(const p of parts){assert(p.worldMatrix.every(Number.isFinite));checks+=16;}for(const g of geometries)for(const a of [...Object.values(g.attributes),...(g.index?[g.index]:[])]){const desc=buffers.get(a.buffer),raw=fs.readFileSync(path.join(output,desc.file));assert.equal(sha(raw),a.buffer);assert.equal(raw.length,desc.bytes);checks+=2;}
// Oracle against live ORIGINAL Three geometry arrays, including interleaved Sprite storage.
for(const [original,id]of geometryIds){const exported=geometries.find(g=>g.id===id);for(const [name,a]of Object.entries(original.attributes)){const descriptor=exported.attributes[name],raw=fs.readFileSync(path.join(output,buffers.get(descriptor.buffer).file)),array=a.isInterleavedBufferAttribute?a.data.array:a.array;assert(raw.equals(Buffer.from(array.buffer,array.byteOffset,array.byteLength)));checks+=array.length;if(a.isInterleavedBufferAttribute){assert.equal(descriptor.stride,a.data.stride);assert.equal(descriptor.offset,a.offset);checks+=2;}}if(original.index){const raw=fs.readFileSync(path.join(output,buffers.get(exported.index.buffer).file)),a=original.index.array;assert(raw.equals(Buffer.from(a.buffer,a.byteOffset,a.byteLength)));checks+=a.length;}}
assert.equal(context.jail.visual.widthTiles,18);assert.equal(context.jail.visual.depthTiles,30);assert.equal(context.layout.solidRects.length,9);assert(records.every(r=>r.ownerRequired&&!r.availableUnlock&&!r.movable));checks+=6;
const report={checks,parts:parts.length,bridgeParts:bridgeParts.length,prisonParts:prisonParts.length,geometries:geometries.length,materials:materials.length,texturesHold:textures.length,manifestSha256:sha(fs.readFileSync(path.join(output,'manifest.json'))),scope:'CPU exact original source execution, no native/GPU/live acceptance'};
fs.writeFileSync(path.join(output,'CPU_REPORT.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
