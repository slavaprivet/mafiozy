// An isolated inspection scene. No game socket, persistence, NPC simulation or main mutation.
import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {loadHeroWalker} from './hero_walk.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
const $=id=>document.getElementById(id), M=4.1, root='/assets/maps/city_rebuild_v1/';
const scene=new THREE.Scene();scene.background=new THREE.Color('#bfd1d6');scene.fog=new THREE.Fog('#bfd1d6',180,550);
const camera=new THREE.PerspectiveCamera(45,innerWidth/innerHeight,.2,1500);
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;
$('viewport').append(renderer.domElement);
const pmrem=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();
const environment=pmrem.fromScene(room,.04);scene.environment=environment.texture;scene.environmentIntensity=.45;room.dispose();pmrem.dispose();
scene.add(new THREE.HemisphereLight('#e8f3ff','#889973',.8));
const sun=new THREE.DirectionalLight('#fff0d4',1.7);sun.position.set(-75,130,90);sun.castShadow=true;
sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});sun.shadow.bias=-.0003;sun.shadow.normalBias=.04;scene.add(sun,sun.target);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.maxPolarAngle=Math.PI*.48;controls.minDistance=12;controls.maxDistance=550;
controls.target.set(60*M,0,30*M);camera.position.copy(controls.target).add(new THREE.Vector3(45,75,95));
const loader=new GLTFLoader(),templates=new Map(),content=new THREE.Group();scene.add(content);
let topology=null,instances=[],bodies=[],loaded=0,failed=0,busy=false,walking=false,revision='',lastLoadAt=0,hero=null;
const errors=[];function fail(message){errors.push(message);$('errors').textContent=errors.slice(-3).join(' · ')}
function safeUrl(url){const u=new URL(url,location.origin);if(u.origin!==location.origin||!/^\/assets\/(maps\/city_rebuild_v1|buildings\/city_v3|decor\/civic_park_v2)\//.test(u.pathname))throw Error('Недопустимый URL модели');return u.href}
async function getJson(name,optional=false){const res=await fetch(root+name,{cache:'no-store'});if(optional&&res.status===404)return null;if(!res.ok)throw Error(name+': HTTP '+res.status);return res.json()}
async function template(binding){
 const key=binding.sha256;if(!key||!binding.url)throw Error('Нет хеша/URL модели');
 if(!templates.has(key))templates.set(key,(async()=>{const response=await fetch(safeUrl(binding.url));if(!response.ok)throw Error('GLB HTTP '+response.status);const bytes=await response.arrayBuffer();if(bytes.byteLength!==binding.bytes)throw Error('Размер GLB не совпал');const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),n=>n.toString(16).padStart(2,'0')).join('');if(digest!==key.toLowerCase())throw Error('Хеш GLB не совпал');const gltf=await loader.parseAsync(bytes,new URL('.',safeUrl(binding.url)).href);
 gltf.scene.traverse(node=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;
 if(node.isMesh){node.castShadow=true;node.receiveShadow=true;const mats=Array.isArray(node.material)?node.material:[node.material];for(const material of mats){if(material.transparent){material.depthWrite=false;material.side=THREE.FrontSide;material.forceSinglePass=true;material.envMapIntensity=.35}}}});
 return gltf.scene;})());return templates.get(key);
}
function clearContent(){while(content.children.length){const node=content.children.pop();node.parent=null;if(node.userData.owned)node.traverse(x=>{x.geometry?.dispose();if(x.material){for(const m of Array.isArray(x.material)?x.material:[x.material])m.dispose()}})}instances=[];bodies=[]}
function terrain(grid,protectedMask,asphalt){
 const palettes={0:'#525a5a',8:'#789274',9:'#c4c1ab',14:'#d9c698',16:'#4f9eb0',19:'#858e89'},vertices=new Map();
 for(let r=0;r<grid.length;r++)for(let c=0;c<grid[r].length;c++){const t=grid[r][c],key=protectedMask?.[r]?.[c]?'protected':t;const arr=vertices.get(key)||[];vertices.set(key,arr);const x=c*M,z=r*M,y=t===16?-.18:0;arr.push(x,y,z,x+M,y,z+M,x+M,y,z,x,y,z,x,y,z+M,x+M,y,z+M)}
 for(const [key,data] of vertices){const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(data,3));geo.computeVertexNormals();const water=key===16;const mat=new THREE.MeshStandardMaterial({color:key==='protected'?'#9a9990':palettes[key]||'#788275',roughness:water?.22:.88,metalness:water?.14:0});if(key===0&&asphalt?.baseColorFactor){mat.color.fromArray(asphalt.baseColorFactor);mat.roughness=asphalt.roughnessFactor??.8;mat.metalness=asphalt.metallicFactor??0}const mesh=new THREE.Mesh(geo,mat);mesh.receiveShadow=!water;mesh.userData.owned=true;content.add(mesh)}
}
function inPolygon(r,c,polygon){if(!polygon?.length)return false;let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if(((a[1]>r)!==(b[1]>r))&&(c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0]))inside=!inside}return inside}
function canWalk(x,z){const r=z/M,c=x/M,rr=Math.floor(r),cc=Math.floor(c);if(!topology?.walkableMask?.[rr]?.[cc])return false;for(const body of bodies){if(body.maxYM!==undefined&&body.maxYM<.05)continue;if(body.minYM!==undefined&&body.minYM>1.8)continue;if(inPolygon(r,c,body.polygonCR))return false}return true}
function focus(instance){const t=instance?.transform?.positionM||[60*M,0,30*M];const pos=new THREE.Vector3(t[0],0,t[2]);let landing=pos.clone().add(new THREE.Vector3(0,0,20));for(let radius=15;radius<60&&!circleFits(landing.x,landing.z,canWalk);radius+=5){for(let a=0;a<Math.PI*2;a+=Math.PI/6){const test=pos.clone().add(new THREE.Vector3(Math.sin(a)*radius,0,Math.cos(a)*radius));if(circleFits(test.x,test.z,canWalk)){landing=test;break}}}if(!circleFits(landing.x,landing.z,canWalk)){fail('Для этой точки не найден безопасный подход');return}controls.target.copy(landing);if(hero){hero.object.position.copy(landing);hero.reset();controls.target.y=1;camera.position.copy(landing).add(new THREE.Vector3(8,11,14))}else camera.position.copy(landing).add(new THREE.Vector3(35,50,65));controls.update()}
function records(data){return data?.instances||[]}
async function refresh(){if(busy)return;busy=true;$('status').textContent='Читаю свежую расстановку…';
 try{const [top,bld,dec]=await Promise.all([getJson('topology_for_placement.json'),getJson('buildings_placement.v1.json',true),getJson('decor_placement.v1.json',true)]);if(!Array.isArray(top.grid)||top.grid.length!==200)throw Error('Нет полной сетки: сцена не заменена');
 const nextRevision=JSON.stringify([top.sourceSha256,bld?.sourceFingerprint,bld?.instances,dec?.instances]);if(nextRevision===revision){$('status').textContent=`В сцене ${loaded} 3D-объектов. Расстановка не изменилась.`;return}
 // Stage models before touching the last visible generation. Failed GLBs never become boxes.
 const all=[...records(bld),...records(dec)],unique=new Map();for(const item of all)if(item.binding)unique.set(item.binding.sha256,item.binding);loaded=0;failed=0;
 const queue=[...unique.values()];await Promise.all(Array.from({length:Math.min(3,queue.length)},async()=>{while(queue.length){const binding=queue.shift();try{await template(binding)}catch(e){failed++;templates.delete(binding.sha256);fail(e.message)}$('status').textContent=`Загрузка моделей: ${templates.size}/${unique.size} типов…`}}));
 clearContent();topology=top;terrain(top.grid,top.protectedMask,dec?.surfaces?.[0]?.materialDescriptor);
 for(const item of all){if(!item.binding||!templates.has(item.binding.sha256))continue;const source=await templates.get(item.binding.sha256);const group=new THREE.Group(),visual=source.clone(true),t=item.transform||{},offset=t.modelLocalOffsetM||[0,0,0];visual.traverse(node=>{if((item.hideNodeNames||[]).includes(node.name))node.visible=false});visual.position.fromArray(offset);group.add(visual);group.position.fromArray(t.positionM||[item.c*M,0,item.r*M]);group.rotation.y=THREE.MathUtils.degToRad(t.yawDegrees||0);group.scale.setScalar(t.uniformScale??1);group.userData.instance=item;content.add(group);instances.push(group);bodies.push(...(item.collision?.worldBodies||[]));loaded++}
 const buildings=records(bld),select=$('district'),old=select.value;select.replaceChildren(new Option('Выбрать здание…',''));const byType=new Map();for(const item of buildings){const key=item.district||item.assetId||item.id;if(!byType.has(key))byType.set(key,item)}for(const [key,item] of byType){select.add(new Option(key,item.id))}select.value=old;
 select.onchange=()=>focus(buildings.find(x=>x.id===select.value));if(!revision&&buildings.length)focus(buildings[0]);revision=nextRevision;lastLoadAt=Date.now();
 $('status').textContent=`Установлено ${loaded} 3D-объектов: ${buildings.length} зданий, ${records(dec).length} элементов декора. ${failed?'Ошибок загрузки: '+failed+'.':'Хеши загруженных моделей проверены.'}`;
 document.body.dataset.rebuildProof=JSON.stringify({loaded,planned:all.length,buildings:buildings.length,decor:records(dec).length,failed,mode:'isolated_walk_preview',pendingHost:top.pendingHostSnapshot!==false});
 }catch(error){fail(error.message);$('status').textContent='Ожидаем проверенные файлы расстановки. Последняя сцена сохранена.'}finally{busy=false}}
$('reload').onclick=refresh;
function setWalking(enabled){walking=enabled;$('walk').setAttribute('aria-pressed',String(walking));controls.enablePan=!walking;$('cross').style.display='none';if(walking&&hero){const shift=hero.object.position.clone().add(new THREE.Vector3(0,1,0)).sub(controls.target);controls.target.add(shift);camera.position.add(shift)}}
$('walk').onclick=()=>setWalking(!walking);
const keys=new Set();addEventListener('keydown',e=>{if(/INPUT|SELECT|TEXTAREA/.test(e.target.tagName))return;if(['KeyW','KeyA','KeyS','KeyD','ShiftLeft','ShiftRight'].includes(e.code)){keys.add(e.code);if(walking)e.preventDefault()}});addEventListener('keyup',e=>keys.delete(e.code));addEventListener('blur',()=>keys.clear());
const clock=new THREE.Clock();let lastCull=0,lastStats=0;
function frame(){requestAnimationFrame(frame);const dt=Math.min(clock.getDelta(),.04);if(document.hidden)return;
 let moved=false;const running=keys.has('ShiftLeft')||keys.has('ShiftRight');
 if(walking&&keys.size&&hero){const forward=controls.target.clone().sub(camera.position);forward.y=0;forward.normalize();const right=new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0));const delta=new THREE.Vector3();if(keys.has('KeyW'))delta.add(forward);if(keys.has('KeyS'))delta.sub(forward);if(keys.has('KeyD'))delta.add(right);if(keys.has('KeyA'))delta.sub(right);delta.normalize().multiplyScalar(dt*(running?5.8:3.2));const result=movePedestrian(hero.object.position,delta,canWalk);moved=result.moved;if(moved){const shift=new THREE.Vector3(result.x-hero.object.position.x,0,result.z-hero.object.position.z);hero.object.position.x=result.x;hero.object.position.z=result.z;hero.object.rotation.y=Math.atan2(shift.x,shift.z);controls.target.add(shift);camera.position.add(shift)}}
 hero?.update(dt,moved,running);
 controls.update();const now=performance.now();if(now-lastCull>250){for(const node of instances)node.visible=node.position.distanceToSquared(controls.target)<220*220;sun.position.copy(controls.target).add(new THREE.Vector3(-75,130,90));sun.target.position.copy(controls.target);lastCull=now}renderer.render(scene,camera);
 if(now-lastStats>1000){$('stats').textContent=`${hero?'Персонаж Художника 13 · ':''}Вызовы отрисовки: ${renderer.info.render.calls} · r ${Math.round(controls.target.z/M)}, c ${Math.round(controls.target.x/M)}`;if(hero)document.body.dataset.heroWalk=JSON.stringify({loaded:true,x:hero.object.position.x,z:hero.object.position.z,moving:moved,running,mode:'isolated_walk',height:hero.height});lastStats=now}
}
addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
async function start(){await refresh();if(!topology)return;try{hero=await loadHeroWalker({THREE,loader,targetHeight:1.9});scene.add(hero.object);focus(instances[0]?.userData.instance);setWalking(true);$('walk').textContent='Управлять персонажем';}catch(e){fail('Персонаж не загружен: '+e.message)}}
start();frame();setInterval(()=>{if(!document.hidden&&!busy)refresh()},15000);
