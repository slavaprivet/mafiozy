import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {normalizeMapWaypoint,normalizeMapRoute,mapRouteDistance,mapRouteStatusText,createMapRouteRenderer,MAP_ROUTE_POINT_LIMIT,mapProjection,waypointScreenPosition,currentMapRegion} from './exploration_minimap.mjs';

const bounds={minX:0,maxX:200,minZ:0,maxZ:200};
const destination={x:90,z:80,id:'building:hotel-7',kind:'hotel',buildingId:'hotel-7',lotId:'lot-4',name:'Отель'};
const road=[{x:10,z:10},{x:10,z:60},{x:90,z:60},{x:90,z:80}];
class RecordedPath{
 constructor(){this.points=[]}
 moveTo(x,z){this.points.push([x,z])}
 lineTo(x,z){this.points.push([x,z])}
}
function context(){
 const ctx={strokes:[],path:[],dash:[],transforms:[],beginPath(){this.path=[]},moveTo(...p){this.path.push(p)},lineTo(...p){this.path.push(p)},setLineDash(value){this.dash=value.slice()},stroke(path){this.strokes.push({path,points:path?.points??this.path.slice(),dash:this.dash.slice(),color:this.strokeStyle,width:this.lineWidth})},translate(...p){this.transforms.push(['translate',...p])},scale(...p){this.transforms.push(['scale',...p])},save(){},restore(){},setTransform(){},fillRect(){},rotate(){},closePath(){},fill(){},fillText(){}};
 return ctx;
}

test('waypoint metadata survives bounds normalization without changing raw map-click selection',()=>{
 assert.deepEqual(normalizeMapWaypoint(destination,bounds),destination);
 const p={...destination,x:-10,z:500,polygon:[[1,2],[3,4]],source:{nested:true}};
 const result=normalizeMapWaypoint(p,bounds);
 assert.deepEqual(result,{...destination,x:0,z:200});
 assert.equal(p.x,-10);assert.equal(p.z,500);
 assert.deepEqual(normalizeMapWaypoint({x:20,z:30},bounds),{x:20,z:30,name:''});
 assert.equal(normalizeMapWaypoint(null,bounds),null);
 assert.equal(normalizeMapWaypoint({x:NaN,z:2},bounds),null);
});

test('route distance follows all road segments and invalid gaps never turn into straight shortcuts',()=>{
 assert.equal(mapRouteDistance(road),150);
 const route=normalizeMapRoute({status:'ready',points:road});
 assert.equal(route.distance,150);assert.equal(route.status,'ready');assert.deepEqual(route.points,road);
 assert.ok(Object.isFrozen(route)&&Object.isFrozen(route.points)&&Object.isFrozen(route.points[0]));
 assert.notEqual(route.points,road);
 const remaining=normalizeMapRoute({status:'ready',points:road,distance:132},route);
 assert.equal(remaining.distance,132);assert.equal(remaining.points,route.points,'distance-only progress reuses compiled geometry');
 assert.equal(normalizeMapRoute({status:'ready',points:road,distance:132},remaining),remaining);
 for(const points of [[],[road[0],{x:NaN,z:20},road[2]],Array.from({length:MAP_ROUTE_POINT_LIMIT+1},()=>road[0]),[{x:1e308,z:0},{x:-1e308,z:0}]]){
  assert.equal(normalizeMapRoute({status:'ready',points,distance:10}).status,'blocked');
 }
 assert.equal(normalizeMapRoute(null),null);
 assert.equal(normalizeMapRoute({status:'pending',points:road}).points.length,0);
 assert.equal(normalizeMapRoute({status:'blocked',points:road}).points.length,0);
});

test('route states distinguish road distance from the original walking marker',()=>{
 const origin={x:10,z:10};
 assert.equal(mapRouteStatusText(origin,destination,null),'До метки: 106 м · Отель');
 assert.equal(mapRouteStatusText(origin,destination,normalizeMapRoute({status:'pending'})),'Строю маршрут…');
 assert.equal(mapRouteStatusText(origin,destination,normalizeMapRoute({status:'blocked'})),'Нет доступного автомобильного пути');
 assert.equal(mapRouteStatusText(origin,destination,normalizeMapRoute({status:'ready',points:road})),'По дороге: 150 м · Отель');
});

test('cached solid amber route uses the exact polyline for every zoom and pan',()=>{
 const renderer=createMapRouteRenderer({Path2D:RecordedPath}),route=normalizeMapRoute({status:'ready',points:road}),ctx=context();
 for(const center of [{x:10,z:10},{x:47.7,z:81.2}])for(const mpp of [.4,1,4]){
  const projection=mapProjection({center,width:230,height:194,metresPerPixel:mpp});
  assert.equal(renderer.draw(ctx,route,projection,mpp),true);
  const stroke=ctx.strokes.at(-1),origin=projection.toScreen({x:0,z:0});
  assert.equal(stroke.color,'#f0c771');assert.deepEqual(stroke.dash,[]);assert.equal(stroke.width,3*mpp);
  assert.deepEqual(stroke.points,road.map(p=>[p.x,p.z]));
  assert.deepEqual(ctx.transforms.slice(-2),[['translate',origin.x,origin.y],['scale',1/mpp,1/mpp]]);
  for(const [x,z]of stroke.points){const screen=projection.toScreen({x,z});assert.ok(Math.abs(screen.x-(origin.x+x/mpp))<1e-8);assert.ok(Math.abs(screen.y-(origin.y+z/mpp))<1e-8)}
 }
 assert.deepEqual(renderer.stats(),{pathBuilds:1,draws:6,points:4});
 const projection=mapProjection({center:{x:0,z:0},width:230,height:194,metresPerPixel:1});
 const before=ctx.strokes.length;
 assert.equal(renderer.draw(ctx,normalizeMapRoute({status:'blocked'}),projection,1),false);
 assert.equal(renderer.draw(ctx,normalizeMapRoute({status:'pending'}),projection,1),false);
 assert.equal(ctx.strokes.length,before);
 renderer.clear();assert.equal(renderer.stats().points,0);
});

// Run the real UI setter and painter bodies with a command-recording Canvas.
// This exercises route/waypoint transitions without duplicating the UI logic.
const source=readFileSync(new URL('./exploration_minimap.mjs',import.meta.url),'utf8');
const setterSource=source.slice(source.indexOf('  function setRoute('),source.indexOf('  function fit('));
const painterSource=source.slice(source.indexOf('  function draw(force=false)'),source.indexOf('  function setRoute('));
function painter(){
 const ctx=context(),root={hidden:false,dataset:{},querySelector:()=>({style:{}})},status={textContent:''};
 const make=new Function('helpers','state',`
  const {normalizeMapWaypoint,normalizeMapRoute,mapRouteStatusText,createMapRouteRenderer,mapProjection,waypointScreenPosition,currentMapRegion}=helpers;
  const {ctx,root,status,RecordedPath}=state;
  const world={bounds:${JSON.stringify(bounds)},districts:[],regions:[]},position={x:10,z:10},heading={},clear={},actors=[],vehicles=[],trains=[];
  const width=230,height=194,dpr=1,yaw=0,expanded=false;
  let route=null,waypoint=null,disposed=false,lastDraw=-Infinity,lastStatus='',dirty=false,markers=0,callbackRoute;
  const routeRenderer=createMapRouteRenderer({Path2D:RecordedPath});
  const projection=()=>mapProjection({center:position,width,height,metresPerPixel:1});
  const drawBase=()=>{},marker=()=>{markers++},clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
  const onWaypointChange=()=>{callbackRoute=route};
  ${painterSource}${setterSource}
  return {setRoute,setWaypoint,draw,get waypoint(){return waypoint},get route(){return route},get callbackRoute(){return callbackRoute},get markers(){return markers},stats:()=>routeRenderer.stats()};
 `);
 return{...{ctx,root,status},api:make({normalizeMapWaypoint,normalizeMapRoute,mapRouteStatusText,createMapRouteRenderer,mapProjection,waypointScreenPosition,currentMapRegion},{ctx,root,status,RecordedPath})};
}

test('actual minimap setters keep the marker while switching ready/pending/blocked/walking, and clear route on a new target',()=>{
 const h=painter();h.api.setWaypoint(destination);assert.deepEqual(h.api.waypoint,destination);
 assert.ok(h.ctx.strokes.some(s=>s.color==='#f0c771'&&s.dash.length===2),'ordinary waypoint still has its original walking guide');
 for(const status of ['pending','blocked','ready']){
  h.ctx.strokes=[];h.api.setRoute({status,points:road,distance:150});
  const amber=h.ctx.strokes.filter(s=>s.color==='#f0c771');
  assert.equal(amber.length,status==='ready'?1:0,'no straight line is fabricated for route status '+status);
  if(status==='ready')assert.deepEqual(amber[0].points,road.map(p=>[p.x,p.z]));
  assert.deepEqual(h.api.waypoint,destination);assert.ok(h.api.markers>0);
 }
 h.ctx.strokes=[];h.api.setRoute(null);
 assert.equal(h.api.route,null);assert.deepEqual(h.api.waypoint,destination);
 assert.ok(h.ctx.strokes.some(s=>s.color==='#f0c771'&&s.dash.length===2));
 h.api.setRoute({status:'ready',points:road});h.api.setWaypoint({...destination,id:'other',x:60});
 assert.equal(h.api.route,null);assert.equal(h.api.callbackRoute,null,'route reset is visible before host waypoint callback');
 assert.equal(h.root.dataset.route,'');
 h.api.setWaypoint(null);assert.equal(h.api.waypoint,null);assert.equal(h.api.route,null);
 h.api.setRoute({status:'ready',points:road});assert.equal(h.api.route,null,'late route without a marker is ignored');
});

test('maximum-size routes compile once and repeated cached draws have constant JS work',t=>{
 const points=Array.from({length:MAP_ROUTE_POINT_LIMIT},(_,i)=>({x:i,z:(i%4)*8}));
 const normalizeTimes=[];let route;
 for(let i=0;i<35;i++){const start=performance.now();route=normalizeMapRoute({status:'ready',points});normalizeTimes.push(performance.now()-start)}
 const renderer=createMapRouteRenderer({Path2D:RecordedPath}),ctx=context(),projection=mapProjection({center:{x:0,z:0},width:230,height:194,metresPerPixel:1}),times=[];
 renderer.draw(ctx,route,projection,1);
 for(let i=0;i<400;i++){const start=performance.now();renderer.draw(ctx,route,projection,1);times.push(performance.now()-start)}
 assert.deepEqual(renderer.stats(),{pathBuilds:1,draws:401,points:MAP_ROUTE_POINT_LIMIT});
 const summarize=list=>{list.sort((a,b)=>a-b);return{p50Ms:+list[Math.floor(list.length*.5)].toFixed(5),p95Ms:+list[Math.floor(list.length*.95)].toFixed(5)}};
 t.diagnostic(JSON.stringify({points:points.length,normalizeCpu:summarize(normalizeTimes),cachedPathDispatchCpu:summarize(times),scope:'CPU geometry/Canvas-command dispatch only; native Canvas rasterization and loaded-game FPS not measured'}));
});
