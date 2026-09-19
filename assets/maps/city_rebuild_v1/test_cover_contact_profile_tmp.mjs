import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {createVehicleRenderBatches} from './vehicle_render_batches.mjs';
import {vehicleCoverContact} from './hero_cover_contact.mjs';
const baselineContact=process.env.COVER_CONTACT_BASELINE?(await import(pathToFileURL(process.env.COVER_CONTACT_BASELINE))).vehicleCoverContact:null;
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
async function glb(relative){const b=fs.readFileSync(new URL(relative,import.meta.url));return new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');}
const hero=createHeroWalker({THREE:T,scene:(await glb('./hero_models/player_male.8130dfb1f7eb.glb')).scene}),c=hero.artistContext();
function pose(position,normal){hero.reset();hero.object.position.copy(position);hero.object.rotation.y=Math.atan2(normal.x,normal.z);hero.update(0,false,false,null,{aimYaw:hero.object.rotation.y},{posture:{target:'crouch',value:1}});}
function equal(a,b,label){assert.ok(a.gap===b.gap||Math.abs(a.gap-b.gap)<1e-8,label+' gap');assert.ok(Math.abs(a.distance-b.distance)<1e-8,label+' shift');assert.equal(a.rays,b.rays,label+' rays');}

const definition=ARTIST_VEHICLE_PROFILES.find(p=>p.id==='city_bus'),car=createArtistVehicle(T,RoundedBoxGeometry,await glb('./models/artist_vehicle_pack/'+definition.modelFile),definition);createVehicleRenderBatches({THREE:T,root:car.object,includeBody:true,includeDoors:true});car.object.updateMatrixWorld(true);pose(new T.Vector3(car.profile.halfWidth+.37,0,0),{x:1,z:0});
const costs=new Map(),original=T.Mesh.prototype.raycast;
T.Mesh.prototype.raycast=function(ray,hits){const start=performance.now();original.call(this,ray,hits);const elapsed=performance.now()-start;let item=costs.get(this.uuid);if(!item){item={name:this.name,triangles:(this.geometry.index?.count||this.geometry.attributes.position.count)/3,calls:0,ms:0};costs.set(this.uuid,item);}item.calls++;item.ms+=elapsed;};
for(let i=0;i<5;i++)vehicleCoverContact(T,c,car.object,{x:1,z:0});
console.log(JSON.stringify([...costs.values()].sort((a,b)=>b.ms-a.ms).slice(0,12)));
