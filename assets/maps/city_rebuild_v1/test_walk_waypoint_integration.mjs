import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import vm from 'node:vm';
import {createExplorationWaypointVisual,reachedExplorationWaypoint} from './exploration_waypoint_visual.mjs';
import {boundedWaypoint} from './exploration_minimap.mjs';

const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const minimap=readFileSync(new URL('./exploration_minimap.mjs',import.meta.url),'utf8').replace(/\r/g,'');
function section(source,start,end){const a=source.indexOf(start),b=source.indexOf(end,a);assert.ok(a>=0&&b>a,`source section ${start}`);return source.slice(a,b)}
assert.match(walk,/import \{createExplorationWaypointVisual,reachedExplorationWaypoint\} from '\.\/exploration_waypoint_visual\.mjs'/);
assert.ok(walk.includes('onWaypointChange(point){showExplorationWaypoint(point)}'));
const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(45,16/9,.2,1500),hero={object:new THREE.Group()};
camera.position.set(10,10,40);camera.lookAt(10,5,20);camera.updateMatrixWorld();hero.object.position.set(10,4,30);
let now=0,drawCount=0;
const nodes=[],ctx={THREE,createExplorationWaypointVisual,reachedExplorationWaypoint,boundedWaypoint,scene,camera,hero,
 waypointVisual:null,waypointDistance:null,walking:true,occupiedSeat:null,transition:null,jump:null,
 document:{createElement:()=>({style:{},hidden:false,remove(){this.removed=true}}),body:{append:n=>nodes.push(n)}},
 performance:{now:()=>now},innerWidth:1280,innerHeight:720,groundHeight:()=>4,
 waypoint:null,root:{dataset:{}},world:{bounds:{minX:0,maxX:100,minZ:0,maxZ:100}},dirty:false,draw:()=>drawCount++};
vm.createContext(ctx);
vm.runInContext(section(walk,'function showExplorationWaypoint(','let npcMapCache='),ctx);
vm.runInContext(section(walk,'function updateWaypointDistance(','function clampLandscapeView('),ctx);
// Exercise the actual map setter and its walk callback, not an imitation of clearing state.
ctx.onWaypointChange=point=>ctx.showExplorationWaypoint(point);
vm.runInContext(section(minimap,'function setWaypoint(','function fit('),ctx);
ctx.explorationMap={expanded:false,setWaypoint:ctx.setWaypoint,get waypoint(){return ctx.waypoint}};
ctx.setWaypoint(null);assert.equal(nodes.length,0,'clearing an absent marker allocates nothing');
ctx.setWaypoint({x:10,z:20,name:'Точка'});
const visual=ctx.waypointVisual;assert.equal(visual.name,'Путевая метка');assert.equal(visual.parent,scene);assert.equal(visual.position.y,4);
ctx.updateWaypointDistance();assert.equal(ctx.waypointDistance.textContent,'10 м');assert.equal(ctx.waypointDistance.hidden,false);
const movingPin=visual.children.at(-1),before=movingPin.position.y;now=600;ctx.updateWaypointDistance();assert.notEqual(movingPin.position.y,before,'real pin animation is connected');
const materials=new Set(),geometries=new Set();visual.traverse(n=>{if(n.material)materials.add(n.material);if(n.geometry)geometries.add(n.geometry)});
assert.equal(materials.size,4,'all pin, halo and outline materials are represented');
hero.object.position.set(10,0,20);ctx.updateWaypointDistance();assert.ok(ctx.waypoint,'different floor keeps destination');
hero.object.position.set(11.3,4,20);ctx.updateWaypointDistance();assert.ok(ctx.waypoint,'nearby outside the 1.15 m halo keeps destination');
hero.object.position.set(10,4,20);
for(const [key,value] of [['occupiedSeat','driver'],['transition',{}],['jump',{}],['walking',false]]){
 const old=ctx[key];ctx[key]=value;ctx.updateWaypointDistance();assert.ok(ctx.waypoint,`${key} does not count as stepping onto marker`);ctx[key]=old;
}
ctx.explorationMap.expanded=true;ctx.updateWaypointDistance();
assert.equal(ctx.waypoint,null,'arrival clears the actual minimap state even with expanded map');
assert.equal(ctx.root.dataset.waypoint,'');assert.equal(visual.visible,false);assert.equal(ctx.waypointDistance.hidden,true);
ctx.explorationMap.expanded=false;ctx.setWaypoint({x:30,z:20});assert.equal(ctx.waypointVisual,visual,'subsequent destinations reuse the marker');
assert.equal(nodes.length,1);ctx.setWaypoint(null);assert.equal(visual.visible,false,'manual map clearing still hides the 3D marker');
let materialsDisposed=0,geometriesDisposed=0;
materials.forEach(m=>m.addEventListener('dispose',()=>materialsDisposed++));geometries.forEach(g=>g.addEventListener('dispose',()=>geometriesDisposed++));
vm.runInContext(section(walk,'if(waypointVisual){const materials=new Set();','waypointDistance?.remove();')+'waypointDistance?.remove();',ctx);
assert.equal(materialsDisposed,materials.size);assert.equal(geometriesDisposed,geometries.size);assert.equal(visual.parent,null);assert.equal(ctx.waypointDistance.removed,true);
assert.ok(drawCount>=5);
console.log('PASS actual walk/map waypoint hooks: low pin, animation, metre label, same-floor foot arrival, seat/jump guards, canonical clearing, reuse and full disposal');
