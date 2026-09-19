import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8'),merc=readFileSync(new URL('./mercenary_walk.mjs',import.meta.url),'utf8');
test('only an accepted follow order triggers a gesture and clears the rally marker',()=>{
 let accepted=false,gestures=0,cleared=0;const source=merc.slice(merc.indexOf('onFollow:()=>')+'onFollow:'.length,merc.indexOf(',getActiveCommand:'));
 const follow=vm.runInNewContext('('+source+')',{host:{follow:()=>({ok:accepted})},selection:{setRally:()=>cleared++},onFollowGesture:()=>gestures++});
 follow();assert.equal(gestures,0);assert.equal(cleared,0);accepted=true;follow();assert.equal(gestures,1);assert.equal(cleared,1);
});
test('actual game gesture gate yields to shooting, reload, traversal, injury and weapon menus',()=>{
 const ctx={hero:{},walking:true,occupiedSeat:null,sourceVehicleActive:()=>false,transition:null,jump:null,heroBlast:null,verticalNavigation:{active:false},heroCustodyActive:false,heroCover:{active:false},busy:false,artistBusy:()=>false,artistSwimming:()=>false,hudInputBlocked:()=>false,arsenalOpen:()=>false,$:()=>({hidden:true}),heroPosture:{value:0},artistAction:{action:{type:'none'}},aiming:false,triggerHeld:false,triggerPressed:false,fireState:()=>({reloadRemaining:0}),worldHealthFrame:{snapshot:{dead:false}}};
 vm.createContext(ctx);vm.runInContext(walk.slice(walk.indexOf('function followGestureAllowed()'),walk.indexOf('function signalHeroFollow()'))+'this.allowed=followGestureAllowed;',ctx);
 assert.equal(ctx.allowed(),true);
 for(const key of ['occupiedSeat','transition','jump','heroBlast','heroCustodyActive','busy','aiming','triggerHeld','triggerPressed']){const old=ctx[key];ctx[key]=true;assert.equal(ctx.allowed(),false,key);ctx[key]=old;}
 for(const key of ['sourceVehicleActive','artistBusy','artistSwimming','hudInputBlocked','arsenalOpen']){ctx[key]=()=>true;assert.equal(ctx.allowed(),false,key);ctx[key]=()=>false;}
 ctx.fireState=()=>({reloadRemaining:.5});assert.equal(ctx.allowed(),false);ctx.fireState=()=>({reloadRemaining:0});ctx.worldHealthFrame.snapshot.dead=true;assert.equal(ctx.allowed(),false);
});
