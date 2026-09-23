import assert from 'node:assert/strict';
import {roofLadderDescriptor} from './roof_ladder.mjs';
import {createBuildingVerticalNavigation} from './building_vertical_navigation.mjs';

const ladder=roofLadderDescriptor({id:'input-contract',lower:{x:0,y:0,z:1},upper:{x:0,y:5,z:-.9},outward:{x:0,z:1}});
function host(position){
 const hero={object:{position:{...position},rotation:{y:0}},reset(){}};
 const nav=createBuildingVerticalNavigation({THREE:{},getHero:()=>hero,getEntries:()=>[{storeys:{ladder:{worldDescriptor:ladder}}}],getWeapon:()=>null,camera:{position:{add(){}}},controls:{target:{add(){}}},canOccupy:()=>true});
 return {nav,hero};
}

let {nav}=host(ladder.lower),candidate=nav.nearest();
assert.equal(candidate.end,'lower');
assert.equal(candidate.text,'E — подняться на крышу');
assert.equal(nav.slideDown(),false,'Ctrl cannot acquire ladder from ground');
assert.equal(nav.begin(candidate,{input:'Control'}),false,'non-E admission is rejected');
assert(nav.begin(candidate,{input:'E'}),'E begins lower ascent');
assert(nav.active&&nav.slideDown(),'Ctrl becomes slide only after E made ladder active');

({nav}=host({x:ladder.upper.x,y:ladder.upper.y,z:ladder.upper.z}));candidate=nav.nearest();
assert.equal(candidate.end,'upper');
assert.equal(candidate.text,'E — спуститься по лестнице');
assert.equal(nav.slideDown(),false,'Ctrl cannot acquire ladder from roof');
assert(nav.begin(candidate,{input:'E'}),'E begins ordinary upper descent');
assert(nav.active&&nav.slideDown(),'active descent can be accelerated by Ctrl');
assert(nav.cancel(),'E/cancel keeps the actor attached until a safe endpoint');

({nav}=host({x:0,y:0,z:-.9}));
assert.equal(nav.nearest(),null,'roof endpoint is not admitted through the floor');
console.log('PASS ladder inputs: E-only admission at both ends, Ctrl active-only, safe E cancel');
