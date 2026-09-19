import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { DETENTION_NATIVE_MODEL, planDetentionNativeSites, createDetentionNativeEntry, detentionDestination, detentionLocalToWorld, detentionShellResourceStats } from '../../assets/maps/city_rebuild_v1/detention_native_sites.mjs';
import { createExplorationRailwayPlan } from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import { interiorMeshPoolResourceStats } from '../../assets/maps/city_rebuild_v1/interior_mesh_pool.mjs';

const root = new URL('../../', import.meta.url), dir = new URL('assets/maps/city_rebuild_v1/', root);
const inputs = ['assets/maps/city_rebuild_v1/topology_for_placement.json', 'outputs/interiors_spacious/sizes_final_candidate/spacious_sizes.candidate.json', 'assets/maps/city_rebuild_v1/decor_placement.v1.json', 'docs/city-rebuild/rebuild-ledger.generated.json'];
const read = p => JSON.parse(fs.readFileSync(new URL(p, root)));
const [topology, placement, decor, ledger] = inputs.map(read), rail = createExplorationRailwayPlan({ topology });
const planStart = performance.now(), plan = planDetentionNativeSites({topology,placement,decor,ledger,rail}), planningMs = performance.now() - planStart;
const vendor = process.env.MAFIOZY_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T = await import(pathToFileURL(vendor+'build/three.module.js')), {GLTFLoader} = await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const modelBytes = fs.readFileSync(new URL(DETENTION_NATIVE_MODEL.url.slice(1),root)), modelHash = createHash('sha256').update(modelBytes).digest('hex');
const source = (await new GLTFLoader().register(()=>({name:'CPU_DETENTION_QA',loadTexture:()=>Promise.resolve(new T.Texture())})).parseAsync(modelBytes.buffer.slice(modelBytes.byteOffset,modelBytes.byteOffset+modelBytes.byteLength),'')).scene;
const originalStats = drawStats(source), results = [], errors = [], entries = [];
const percentile=(values,f)=>values.slice().sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*f))];
function bench(fn){const times=[];for(let warm=0;warm<3;warm++)for(let i=0;i<2000;i++)fn(i);for(let pass=0;pass<12;pass++){const start=performance.now();for(let i=0;i<2000;i++)fn(i);times.push((performance.now()-start)*1000/2000);}return{unit:'microseconds_per_call',iterationsPerSample:2000,samples:12,p50:percentile(times,.5),p95:percentile(times,.95)};}

export function circlePolygon(x,z,poly,radius=.36){let inside=false,min=Infinity;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[j],b=poly[i],dx=b[0]-a[0],dz=b[1]-a[1];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])inside=!inside;const t=Math.max(0,Math.min(1,((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz||1)));min=Math.min(min,(x-a[0]-dx*t)**2+(z-a[1]-dz*t)**2);}return inside||min<(radius-1e-6)**2;}
function drawStats(node){let draws=0,triangles=0,meshes=0;node.traverse(n=>{if(!n.isMesh)return;for(let p=n;p;p=p.parent)if(!p.visible)return;meshes++;draws+=Array.isArray(n.material)?Math.max(1,n.geometry.groups.length):1;triangles+=(n.geometry.index?.count??n.geometry.attributes.position.count)/3*(n.isInstancedMesh?n.count:1);});return{draws,triangles,meshes};}
function surfaceHit(objects,x,z,y,direction){const ray=new T.Raycaster(new T.Vector3(x,y,z),new T.Vector3(0,direction,0),0,10);return ray.intersectObjects(objects,true).find(h=>{for(let p=h.object;p;p=p.parent)if(!p.visible)return false;return true;});}

for(const instance of plan.instances){
  instance.binding.sha256=modelHash;instance.binding.bytes=modelBytes.length;
  const parent=new T.Group();parent.position.fromArray(instance.transform.positionM);parent.rotation.y=instance.transform.yawDegrees*Math.PI/180;parent.scale.setScalar(instance.transform.uniformScale);const visual=source.clone(true);parent.add(visual);parent.updateMatrixWorld(true);
  const started=performance.now(),entry=createDetentionNativeEntry({THREE:T,visual,instance}),constructionMs=performance.now()-started;entries.push(entry);
  const failures=[], fail=(kind,detail)=>{if(!failures.some(f=>f.kind===kind&&f.route===detail.route&&f.part===detail.part))failures.push({kind,...detail});};
  entry.setEntranceOpen(true);entry.setGateOpen(true);for(let i=0;i<10;i++)entry.update(.15);
  const bodies=entry.getCollisionBodies().map(b=>({...b,poly:b.polygonCR.map(([c,r])=>[c*4.1,r*4.1])}));
  const routes=[];
  for(const[name,path]of Object.entries(entry.routePoints())){
    let samples=0,minHeadroom=Infinity,maxRise=0,maxFloorGeometryError=0,previousY=null;const meshRays=new T.Raycaster();
    for(let seg=1;seg<path.length;seg++){
      const a=path[seg-1],b=path[seg],count=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])*instance.transform.uniformScale/.06);
      for(let k=0;k<=count;k++){
        const t=k/count,p=detentionLocalToWorld(instance,a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t),y=entry.floorHeight(p.x,p.z);samples++;
        if(y===null||!Number.isFinite(y)){fail('missing-floor',{route:name,point:p});continue;}
        if(previousY!==null){maxRise=Math.max(maxRise,Math.abs(y-previousY));if(Math.abs(y-previousY)>.28)fail('floor-step',{route:name,point:p,rise:Math.abs(y-previousY)});}previousY=y;
        const ceiling=entry.ceilingHeight({...p,y});if(ceiling!==null){minHeadroom=Math.min(minHeadroom,ceiling-y);if(ceiling-y<1.8)fail('headroom',{route:name,point:p,headroom:ceiling-y});}
        for(const body of bodies)if(body.maxYM>y+.12&&body.minYM<y+1.8&&circlePolygon(p.x,p.z,body.poly))fail('capsule-body',{route:name,point:p,part:body.detentionPart});
        const floorHit=surfaceHit([visual],p.x,p.z,y+.12,-1);if(!floorHit)fail('no-rendered-floor',{route:name,point:p});else{const error=Math.abs(floorHit.point.y-y);maxFloorGeometryError=Math.max(maxFloorGeometryError,error);if(error>.065)fail('floor-geometry-mismatch',{route:name,point:p,part:floorHit.object.name,error});}
        const ceilingHit=surfaceHit([visual],p.x,p.z,y+.13,1);if(ceilingHit&&ceilingHit.point.y-y<1.8-1e-5)fail('rendered-headroom',{route:name,point:p,part:ceilingHit.object.name,height:ceilingHit.point.y-y});
        // Sweep radial rays through the actual GLB/added surface at ankle,
        // torso and head; this detects omitted authored door decorations.
        for(const dy of [.2,.95,1.7])for(let angle=0;angle<8;angle++){
          meshRays.set(new T.Vector3(p.x,y+dy,p.z),new T.Vector3(Math.cos(angle*Math.PI/4),0,Math.sin(angle*Math.PI/4)));meshRays.near=0;meshRays.far=.36;
          const hit=meshRays.intersectObject(visual,true).find(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;return true;});if(hit)fail('rendered-capsule',{route:name,point:p,part:hit.object.name,height:dy});
        }
      }
    }
    routes.push({name,samples,minHeadroom:Number.isFinite(minHeadroom)?minHeadroom:null,maxRise,maxFloorGeometryError});
  }
  // The gate must actually detain a capsule when closed and free the same
  // threshold when opened; static decorative bars alone do not qualify.
  entry.setGateOpen(false);for(let i=0;i<10;i++)entry.update(.15);const q=detentionLocalToWorld(instance,-1.1,-.08),closed=entry.getCollisionBodies().some(b=>b.movingDoor&&b.detentionPart==='Решётка камеры'&&circlePolygon(q.x,q.z,b.polygonCR.map(([c,r])=>[c*4.1,r*4.1])));if(!closed)fail('gate-does-not-close',{});
  entry.setGateOpen(true);for(let i=0;i<10;i++)entry.update(.15);
  const partNames=new Set(entry.localBodies.map(b=>b.kind));for(const part of ['booking-counter','cell-bed-frame','cell-toilet-base','cell-bars'])if(!partNames.has(part))fail('missing-semantic-geometry',{part});
  const outside=new T.Vector3(-1000,0,-1000),floorPoint=entry.roomPoint();
  const cpu={idleUpdate:bench(()=>entry.update(1/60,outside)),animatedUpdate:bench(i=>{if(i%16===0)entry.setGateOpen((i/16)%2===0);entry.update(1/60,outside);}),floorQuery:bench(()=>entry.floorHeight(floorPoint.x,floorPoint.z)),cachedBodies:bench(()=>entry.getCollisionBodies())};
  entry.setGateOpen(true);for(let i=0;i<10;i++)entry.update(.15);
  const stats=drawStats(visual);const result={instanceId:instance.id,districtId:instance.districtId,constructionMs,cpu,original:originalStats,adapted:stats,staticBatch:entry.staticBatchStats,addedFurniture:entry.furnitureStats,pooledLightSources:entry.lightSources.map(light=>({name:light.name,localPosition:light.position.toArray(),intensity:light.intensity,distance:light.distance,castShadow:light.castShadow})),bodies:entry.getCollisionBodies().length,gateClosedBlocks:closed,routes,failures};results.push(result);errors.push(...failures.map(f=>({instanceId:instance.id,...f})));
}
const resourceStats=interiorMeshPoolResourceStats(T),shellResourceStats=detentionShellResourceStats(T);for(const entry of entries)entry.dispose();const afterDispose=interiorMeshPoolResourceStats(T),shellAfterDispose=detentionShellResourceStats(T);
if(afterDispose.references!==0||shellAfterDispose.references!==0)errors.push({kind:'mesh-resource-leak',afterDispose,shellAfterDispose});
if(plan.instances.length<3)errors.push({kind:'insufficient-sites',found:plan.instances.length});
const output=new URL('outputs/detention_native_sites_20260912/',root);fs.mkdirSync(output,{recursive:true});
const passed=new Set(results.filter(r=>!r.failures.length).map(r=>r.instanceId));
const registry={version:1,destinations:plan.instances.map(s=>detentionDestination(s,passed.has(s.id)))};
fs.writeFileSync(new URL('detention_destinations.v1.candidate.json',output),JSON.stringify(registry,null,2)+'\n');
fs.writeFileSync(new URL('detention_native_sites.candidate.json',output),JSON.stringify({version:1,instances:plan.instances},null,2)+'\n');
const report={status:errors.length?'FAILED_CPU_NATIVE_QA':'PASSED_CPU_NATIVE_GEOMETRY_ROUTE_QA',livePlacementWritten:false,liveRegistryWritten:false,planningMs,candidateCount:plan.candidateCount,searchCounts:plan.searchCounts,model:{url:DETENTION_NATIVE_MODEL.url,sha256:modelHash,bytes:modelBytes.length,bounds:DETENTION_NATIVE_MODEL.bounds,originalStats},inputs:inputs.map(p=>({path:p,sha256:createHash('sha256').update(fs.readFileSync(new URL(p,root))).digest('hex')})),moduleSha256:createHash('sha256').update(fs.readFileSync(new URL('detention_native_sites.mjs',dir))).digest('hex'),resourceStats,shellResourceStats,afterDispose,shellAfterDispose,results,errors,limitations:['CPU geometry and movement corridors only; no GPU scene or authenticated arrest gameplay was run.','Host must load the reviewed instance clones with createDetentionNativeEntry and register its bodies/floors before using nativeReady destinations.','Car occupancy is tested against static road masks and final map reservations; dynamic traffic occupancy remains the host responsibility.','Main police complex, marker and gameplay IDs remain unchanged.']};
fs.writeFileSync(new URL('detention_native_sites.report.json',output),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({status:report.status,planningMs,sites:results.map(r=>({id:r.instanceId,constructionMs:r.constructionMs,draws:r.adapted.draws,triangles:r.adapted.triangles,failures:r.failures})),errors:errors.length},null,2));if(errors.length)process.exitCode=1;
