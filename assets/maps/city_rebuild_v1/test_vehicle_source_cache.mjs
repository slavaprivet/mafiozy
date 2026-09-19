import assert from 'node:assert/strict';
import {ARTIST_VEHICLE_PROFILES,loadArtistFleetModels,loadArtistVehicleSource,releaseArtistVehicleSourceCache} from './vehicle_fleet_models.mjs';
import {createWorldTrafficPresentation} from './world_traffic_presentation.mjs';

const releases=new Map(),loads=[];
const vec=()=>({x:0,y:0,z:0,set(x,y,z){this.x=x;this.y=y;this.z=z;}});
const source=url=>({url,traverse(fn){fn({geometry:{dispose(){releases.set(url,(releases.get(url)||0)+1);}},material:{dispose(){}}});},removeFromParent(){}});
const actor=()=>({position:vec(),rotation:{y:0},userData:{},traverse(){},removeFromParent(){}});
const loader={async loadAsync(url){loads.push(url);return {scene:source(url)}}};
const playerSources=new Map(),trafficSources=[];
const factory=(_THREE,_RoundedBox,input,profile)=>{
 const id=typeof profile==='string'?profile:profile.id;
 if(typeof profile==='string')trafficSources.push(input);else playerSources.set(id,input);
 // This root represents the vehicle's private cloned render resources. It is
 // never the immutable source root handed to this factory.
 return {object:actor(),profile:{halfWidth:1,halfLength:2,height:2,bounds:{min:[-1,0,-2],max:[1,2,2]}},update(){}};
};

await loadArtistFleetModels({THREE:{},loader,RoundedBox:class{},vehicleFactory:factory});
assert.equal(loads.length,ARTIST_VEHICLE_PROFILES.length,'fleet parses each authored GLB once');
const presentation=createWorldTrafficPresentation({loader,scene:{add(){}},vehicleFactory:factory});
presentation.sync([{id:'world-sedan',r:1,c:2,ang:0,model:'sedan'}]);
await presentation.whenIdle();presentation.update(1/60);
assert.equal(loads.length,ARTIST_VEHICLE_PROFILES.length,'traffic reuses the fleet parsed scene: no second download or GLTF parse');
assert.equal(trafficSources[0],playerSources.get('compact_sedan'),'both consumers see the exact immutable source scene');
assert.notEqual(presentation.getActor('world-sedan').object,trafficSources[0],'traffic actor retains a private render root');
presentation.dispose();
assert.equal([...releases.values()].reduce((sum,count)=>sum+count,0),ARTIST_VEHICLE_PROFILES.length,'each cached source releases its geometry exactly once');
releaseArtistVehicleSourceCache(loader);
assert.equal([...releases.values()].reduce((sum,count)=>sum+count,0),ARTIST_VEHICLE_PROFILES.length,'repeat cache release cannot dispose source twice');

let concurrentLoads=0,resolveConcurrent;
const concurrentLoader={loadAsync(){concurrentLoads++;return new Promise(resolve=>{resolveConcurrent=resolve;});}};
const left=loadArtistVehicleSource({loader:concurrentLoader,url:'concurrent.glb'}),right=loadArtistVehicleSource({loader:concurrentLoader,url:'concurrent.glb'});
await Promise.resolve();assert.equal(concurrentLoads,1,'two simultaneous consumers begin one GLTF parse');
const shared=source('concurrent.glb');resolveConcurrent({scene:shared});
assert.equal(await left,await right,'concurrent consumers receive the same immutable source');
releaseArtistVehicleSourceCache(concurrentLoader);

let attempts=0;
const retryLoader={async loadAsync(){attempts++;if(attempts===1)throw Error('temporary source failure');return {scene:source('retry.glb')}}};
await assert.rejects(loadArtistVehicleSource({loader:retryLoader,url:'retry.glb'}),/temporary source failure/);
assert.ok(await loadArtistVehicleSource({loader:retryLoader,url:'retry.glb'}),'a failed source is evicted so later startup retry remains possible');
assert.equal(attempts,2);releaseArtistVehicleSourceCache(retryLoader);
console.log(JSON.stringify({passed:true,checks:['fleet-traffic-shared-parse','no-duplicate-download','private-actor-root','single-source-release','concurrent-dedup','failed-source-retry'],loads:loads.length,sources:ARTIST_VEHICLE_PROFILES.length}));
