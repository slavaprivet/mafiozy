import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createDemoCar,CAR} from './car_drive.mjs';
import {createArtistVehicle,ARTIST_VEHICLE_PROFILES} from './vehicle_fleet_models.mjs';
import {vehicleCoverContact} from './hero_cover_contact.mjs';
import {findCover,moveCover} from './hero_cover.mjs';
const baselineContact=process.env.COVER_CONTACT_BASELINE?(await import(pathToFileURL(process.env.COVER_CONTACT_BASELINE))).vehicleCoverContact:null;
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
async function glb(relative){const b=fs.readFileSync(new URL(relative,import.meta.url));return new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');}
let hero,c;
const cars=[{id:'kingswell',car:createDemoCar(T,RoundedBoxGeometry),profile:CAR}];
for(const profile of ARTIST_VEHICLE_PROFILES){const car=createArtistVehicle(T,RoundedBoxGeometry,await glb('./models/artist_vehicle_pack/'+profile.modelFile),profile);cars.push({id:profile.id,car,profile:car.profile});}
let validationRays=0,cases=0,maxRays=0,minReduction=Infinity,maxReduction=0;
const results=[];
for(const model of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
hero=createHeroWalker({THREE:T,scene:(await glb('./hero_models/'+model)).scene});c=hero.artistContext();
for(const {id,car,profile} of cars){
  car.object.updateMatrixWorld(true);
  for(const side of [-1,1])for(const along of [-.55,0,.55])for(const yaw of [0,.71]){
    car.object.rotation.y=yaw;car.object.position.set(0,0,0);car.object.updateMatrixWorld(true);
    hero.reset();const normal=new T.Vector3(side,0,0).applyAxisAngle(new T.Vector3(0,1,0),yaw);
    const position=new T.Vector3(side*(profile.halfWidth+.37),0,along).applyAxisAngle(new T.Vector3(0,1,0),yaw);
    hero.object.position.copy(position);hero.object.rotation.y=Math.atan2(normal.x,normal.z);
    hero.update(0,false,false,null,{},{posture:{target:'crouch',value:1}});
    const root=hero.object.position.clone();
    const contact=vehicleCoverContact(T,c,car.object,normal);
    if(baselineContact){const original=baselineContact(T,c,car.object,normal);assert.ok(Math.abs(contact.distance-original.distance)<1e-8,`${id} broadphase cannot change final body clearance`);assert.equal(contact.rays,original.rays);assert.ok(contact.gap===original.gap||Math.abs(contact.gap-original.gap)<1e-8,`${id} exact ray distance parity`);}
    assert.ok(Number.isFinite(contact.distance)&&contact.distance>=0&&contact.distance<=.48);
    assert.ok(contact.distance<=Math.max(0,contact.gap-.065)+1e-8);
    if(id==='kingswell'&&along===0&&yaw===0){
      const ray=new T.Raycaster(),p=new T.Vector3();let exactGap=Infinity;
      hero.object.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();
        for(let i=0;i<mesh.geometry.attributes.position.count;i++){
          p.fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,p);p.applyMatrix4(mesh.matrixWorld);
          ray.set(p,normal.clone().negate());ray.near=0;ray.far=contact.distance+.1;
          const hit=ray.intersectObject(car.object,true).find(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;const a=Array.isArray(h.object.material)?h.object.material:[h.object.material];return a.some(m=>(m.transmission||0)<.2&&(!m.transparent||m.opacity>.65));});
          validationRays++;if(hit)exactGap=Math.min(exactGap,hit.distance);
        }
      });
      assert.ok(exactGap-contact.distance>=.04,`${model} ${id}: exhaustive skin clearance ${exactGap-contact.distance}`);
    }
    if(contact.distance>0){minReduction=Math.min(minReduction,contact.distance);maxReduction=Math.max(maxReduction,contact.distance);}
    maxRays=Math.max(maxRays,contact.rays);
    c.visualPivot.position.add(new T.Vector3(contact.x,0,contact.z).applyQuaternion(hero.object.quaternion.clone().invert()));
    hero.object.updateMatrixWorld(true);
    assert.ok(hero.object.position.distanceTo(root)<1e-10,'contact cannot change collision root');
    const after=vehicleCoverContact(T,c,car.object,normal);
    if(contact.distance<.48&&contact.distance>1e-5)assert.ok(Math.abs(after.gap-.065)<.005,`${id} contact should sit against real mesh: ${after.gap}`);
    assert.ok(after.gap===null||after.gap>=.060,`${id} visual skin crossed car surface: ${after.gap}`);
    results.push({model,id,side,along,yaw,shift:contact.distance,gap:after.gap});cases++;
  }
}
}
// Vehicle-only admission retains the standard 36 cm collision clearance.
const body={id:'car',vehicle:true,minY:0,maxY:1.2,standOff:.37,polygon:[{x:0,z:0},{x:6,z:0},{x:6,z:2},{x:0,z:2}]};
const fits=p=>p.z<=-.36;
const cover=findCover({position:{x:3,y:0,z:-1},direction:{x:0,z:1},bodies:[body],canOccupy:fits});
assert.ok(cover);assert.equal(cover.anchor.z,-.37);assert.equal(moveCover(cover,.4,fits).anchor.z,-.37);
assert.equal(findCover({position:{x:3,y:0,z:-1},direction:{x:0,z:1},bodies:[{...body,standOff:.1}],canOccupy:fits}).anchor.z,-.37);
assert.equal(vehicleCoverContact(T,c,null,{x:1,z:0}).distance,0);
console.log(JSON.stringify({passed:true,cases,validationRays,minReduction,maxReduction,maxRays,results:results.filter(r=>r.id==='kingswell')}));
