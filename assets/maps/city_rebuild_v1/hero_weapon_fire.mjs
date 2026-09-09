const BALANCE=Object.freeze({
  pistol:{mode:'semi',cooldown:.38,range:8,spread:.035,projectileSpeed:26,color:'#ffea80',damage:24,recoil:1.3,magazineSize:12,reloadSeconds:1.4},
  nagan:{mode:'duelist',cooldown:.48,range:9.2,spread:.038,projectileSpeed:29,color:'#9edcff',damage:32,recoil:1.9,magazineSize:6,reloadSeconds:2.16,casing:'retained'},
  revolver:{mode:'semi',cooldown:.58,range:10.5,spread:.022,projectileSpeed:32,color:'#ffc15c',damage:86,recoil:2.8,magazineSize:6,reloadSeconds:2.25,casing:'retained'},
  pistol_heavy:{mode:'semi',cooldown:.46,range:11.2,spread:.026,projectileSpeed:25,color:'#ff8a32',damage:72,recoil:2.4,magazineSize:7,reloadSeconds:1.9},
  pistol_gold:{mode:'semi',cooldown:.24,range:11.5,spread:.020,projectileSpeed:32,color:'#ffd700',damage:48,recoil:1.5,magazineSize:15,reloadSeconds:1.35},
  shotgun:{mode:'pump',cooldown:.90,range:6.2,spread:.30,projectileSpeed:23,color:'#ffaa50',damage:76,recoil:3.8,magazineSize:6,reloadSeconds:2.45,pellets:7,casing:'pump',casingDelay:.34},
  smg:{mode:'auto',cooldown:.105,range:8,spread:.105,projectileSpeed:26,color:'#ffea80',damage:15,recoil:.8,magazineSize:30,reloadSeconds:1.8},
  tommy_gun:{mode:'auto',cooldown:.12,range:10,spread:.075,projectileSpeed:28,color:'#ffce70',damage:24,recoil:1,magazineSize:40,reloadSeconds:2.1},
  rifle:{mode:'auto',cooldown:.20,range:14,spread:.030,projectileSpeed:34,color:'#ffea80',damage:42,recoil:2,magazineSize:30,reloadSeconds:2.05},
  sniper:{mode:'bolt',cooldown:1.25,range:20,spread:.004,projectileSpeed:43,color:'#ff5050',damage:132,recoil:5,magazineSize:5,reloadSeconds:2.65,tracer:true},
  rpg:{mode:'single',cooldown:1.65,range:15,spread:.015,projectileSpeed:17,color:'#ff6020',damage:160,recoil:6,magazineSize:1,reloadSeconds:1.65,casing:'none',explosive:true},
});

// Cosmetic projectile shapes are preview metadata. Damage, hit admission and
// ammo remain authoritative in the host. Every inventory id keeps a distinct
// visual signature even where two items share the same balance family.
export const PROJECTILE_VISUALS=Object.freeze({
  nagan:Object.freeze({kind:'round',caliber:.009,length:.075,trail:.12,color:'#b7aa91'}),
  tt_pistol:Object.freeze({kind:'round',caliber:.007,length:.065,trail:.09,color:'#c7aa70'}),
  revolver:Object.freeze({kind:'round',caliber:.011,length:.085,trail:.14,color:'#c89658'}),
  deagle:Object.freeze({kind:'round',caliber:.012,length:.095,trail:.15,color:'#b88450'}),
  golden_colt:Object.freeze({kind:'round',caliber:.008,length:.07,trail:.12,color:'#d1ad55'}),
  sawn_off:Object.freeze({kind:'pellet',caliber:.0065,length:.04,trail:.045,color:'#b58b5e'}),
  shotgun:Object.freeze({kind:'pellet',caliber:.0055,length:.035,trail:.04,color:'#b7a07d'}),
  uzi:Object.freeze({kind:'round',caliber:.006,length:.06,trail:.075,color:'#b8a67e'}),
  golden_uzi:Object.freeze({kind:'round',caliber:.0065,length:.062,trail:.085,color:'#cfad58'}),
  ak74:Object.freeze({kind:'rifle',caliber:.007,length:.09,trail:.16,color:'#c39b61'}),
  m16:Object.freeze({kind:'rifle',caliber:.0065,length:.095,trail:.18,color:'#c6b38e'}),
  tommy_gun:Object.freeze({kind:'round',caliber:.008,length:.075,trail:.11,color:'#bf9968'}),
  sniper:Object.freeze({kind:'rifle',caliber:.0085,length:.12,trail:.28,color:'#b88b6c'}),
  rpg:Object.freeze({kind:'rocket',caliber:.07,length:.55,trail:.65,color:'#667048'}),
});

// Item ids remain the owner-facing ids. balanceId only selects the matching
// established world.html firing family; it never replaces inventory identity.
export const WEAPON_PROFILE_ALIASES=Object.freeze({
  nagan:'nagan',tt_pistol:'pistol',revolver:'revolver',deagle:'pistol_heavy',golden_colt:'pistol_gold',
  sawn_off:'shotgun',shotgun:'shotgun',uzi:'smg',golden_uzi:'smg',ak74:'rifle',m16:'rifle',
  tommy_gun:'tommy_gun',sniper:'sniper',rpg:'rpg',
});

export const FIREARM_IDS=Object.freeze(Object.keys(WEAPON_PROFILE_ALIASES));

// Angular presentation/trajectory tuning is per actual item, never per balance
// alias. Existing damage, cadence, magazine sizes and inventory ids stay intact.
export const WEAPON_HANDLING=Object.freeze(Object.fromEntries(Object.entries({
  nagan:{seed:11,recovery:.76,heatPerShot:.43,bloom:.43,pitchRise:.032,yawSweep:.012,yawFrequency:.91,moveSpread:.040,visualKick:1.02},
  tt_pistol:{seed:23,recovery:.59,heatPerShot:.36,bloom:.39,pitchRise:.024,yawSweep:.011,yawFrequency:.79,moveSpread:.034,visualKick:.88},
  revolver:{seed:37,recovery:.94,heatPerShot:.51,bloom:.52,pitchRise:.051,yawSweep:.017,yawFrequency:.69,moveSpread:.041,visualKick:1.16},
  deagle:{seed:41,recovery:.87,heatPerShot:.48,bloom:.56,pitchRise:.046,yawSweep:.018,yawFrequency:.86,moveSpread:.046,visualKick:1.13},
  golden_colt:{seed:53,recovery:.57,heatPerShot:.30,bloom:.32,pitchRise:.022,yawSweep:.010,yawFrequency:.74,moveSpread:.029,visualKick:.83},
  sawn_off:{seed:67,recovery:1.12,heatPerShot:.62,bloom:.17,pitchRise:.060,yawSweep:.025,yawFrequency:.65,moveSpread:.064,visualKick:1.22,pelletSpread:.78},
  shotgun:{seed:79,recovery:1.02,heatPerShot:.53,bloom:.14,pitchRise:.049,yawSweep:.018,yawFrequency:.72,moveSpread:.049,visualKick:1.12,pelletSpread:.51},
  uzi:{seed:83,recovery:.56,heatPerShot:.23,bloom:.43,pitchRise:.046,yawSweep:.037,yawFrequency:.81,moveSpread:.061,visualKick:.90},
  golden_uzi:{seed:97,recovery:.52,heatPerShot:.21,bloom:.35,pitchRise:.040,yawSweep:.029,yawFrequency:.76,moveSpread:.051,visualKick:.83},
  ak74:{seed:101,recovery:.73,heatPerShot:.30,bloom:.72,pitchRise:.064,yawSweep:.039,yawFrequency:.63,moveSpread:.061,visualKick:1.09},
  m16:{seed:113,recovery:.66,heatPerShot:.27,bloom:.55,pitchRise:.050,yawSweep:.026,yawFrequency:.71,moveSpread:.053,visualKick:.95},
  tommy_gun:{seed:127,recovery:.64,heatPerShot:.25,bloom:.49,pitchRise:.052,yawSweep:.034,yawFrequency:.58,moveSpread:.058,visualKick:1.02},
  sniper:{seed:139,recovery:1.46,heatPerShot:.74,bloom:.65,pitchRise:.061,yawSweep:.012,yawFrequency:.67,moveSpread:.081,visualKick:1.18},
  rpg:{seed:149,recovery:1.92,heatPerShot:.81,bloom:.45,pitchRise:.067,yawSweep:.021,yawFrequency:.61,moveSpread:.056,visualKick:1.20},
}).map(([id,value])=>[id,Object.freeze(value)])));

const makeProfile=(id,balanceId)=>{
  const base=BALANCE[balanceId],automatic=base.mode==='auto';
  return Object.freeze({
    id,balanceId,mode:base.mode,automatic,cooldown:base.cooldown,range:base.range,spread:base.spread,
    projectileSpeed:base.projectileSpeed,color:base.color,damage:base.damage,recoil:base.recoil,
    recoilRecovery:Math.min(.34,.105+base.recoil*.027),magazineSize:base.magazineSize,
    reloadSeconds:base.reloadSeconds,pellets:base.pellets||1,casing:base.casing||'immediate',
    casingDelay:base.casingDelay||0,tracer:!!base.tracer,explosive:!!base.explosive,
    projectileVisual:PROJECTILE_VISUALS[id],handling:WEAPON_HANDLING[id],
  });
};

export const WEAPON_FIRE_PROFILES=Object.freeze(Object.fromEntries(
  Object.entries(WEAPON_PROFILE_ALIASES).map(([id,balanceId])=>[id,makeProfile(id,balanceId)]),
));

export function weaponFireProfile(id){
  if(id==='none'||id==null)return null;
  const profile=WEAPON_FIRE_PROFILES[id];
  if(!profile)throw Error(`Unknown firearm ${id}`);
  return profile;
}

const clampInteger=(value,min,max,fallback)=>{
  const number=Number(value);
  return Number.isFinite(number)?Math.max(min,Math.min(max,Math.floor(number))):fallback;
};

export function createWeaponFireState(id,options={}){
  const profile=weaponFireProfile(id);
  if(!profile)return {weaponId:'none',magazine:0,reserveAmmo:0,cooldown:0,reloadRemaining:0,recoil:0,sequence:0,triggerHeld:false};
  return {
    weaponId:id,
    magazine:clampInteger(options.magazine,0,profile.magazineSize,profile.magazineSize),
    reserveAmmo:clampInteger(options.reserveAmmo,0,9999,profile.magazineSize*3),
    cooldown:0,reloadRemaining:0,recoil:0,sequence:0,triggerHeld:false,
    sprayHeat:0,sprayShots:0,sprayRecoveryRemaining:0,lastRecoilYaw:0,lastRecoilScale:1,
  };
}

export function beginWeaponReload(state){
  const profile=weaponFireProfile(state.weaponId);
  if(!profile||state.reloadRemaining>0||state.magazine>=profile.magazineSize||state.reserveAmmo<=0)return {...state};
  return {...state,reloadRemaining:profile.reloadSeconds,triggerHeld:false};
}

function recoverSpray(state,dt){
  const before=Math.max(0,+state.sprayRecoveryRemaining||0);
  state.sprayRecoveryRemaining=Math.max(0,before-dt);
  state.sprayHeat=before>0?Math.max(0,+state.sprayHeat||0)*state.sprayRecoveryRemaining/before:0;
  state.sprayShots=state.sprayRecoveryRemaining>1e-8?Math.max(0,+state.sprayShots||0):0;
  if(!state.sprayShots){state.sprayHeat=0;state.sprayRecoveryRemaining=0;}
}

function shotHandling(profile,state,input){
  const tune=profile.handling,heat=Math.min(1,Math.max(0,+state.sprayHeat||0));
  const shotIndex=Math.max(0,+state.sprayShots||0),posture=input.posture==='prone'?'prone':input.posture==='crouch'?'crouch':'stand';
  const stance=posture==='prone'?.38:posture==='crouch'?.65:1;
  const movement=input.running?1.7:input.moving?1:0;
  const accuracy=stance*(input.aiming?.48:1),kickScale=stance*(input.aiming?.70:1);
  // Burst-local seed repeats a learnable pattern after a full recovery. Global
  // sequence remains solely the persistent shot receipt id.
  const angle=tune.seed*.61803398875+(shotIndex+1)*2.39996322973;
  const handlingSpread=(profile.spread*tune.bloom*heat+tune.moveSpread*movement)*accuracy;
  // Blind fire has an angular error even on a recovered, stationary pistol.
  // Persistent sequence changes each attempt instead of repeating the same
  // first-shot offset after every pause. Posture cannot cancel this penalty.
  const blind=input.coverFire==='blind',coverSpread=blind?.09:0;
  const coverAngle=tune.seed*.754877666+(Math.max(0,+state.sequence||0)+1)*2.39996322973;
  const coverRadius=coverSpread*(.58+.42*(.5+.5*Math.sin(coverAngle*1.61803398875)));
  const coverYaw=Math.cos(coverAngle)*coverRadius,coverPitch=Math.sin(coverAngle)*coverRadius;
  const spread=handlingSpread+coverSpread;
  const rise=tune.pitchRise*heat*Math.min(1,.28+shotIndex*.11)*kickScale;
  const sweep=tune.yawSweep*heat*Math.sin(shotIndex*tune.yawFrequency+tune.seed*.11)*Math.min(1,shotIndex/5)*kickScale;
  return {posture,spread,heat,burstIndex:shotIndex,coverSpread,coverYaw,coverPitch,
    yaw:(sweep+Math.cos(angle)*handlingSpread*.72+coverYaw)||0,pitch:(rise+Math.sin(angle)*handlingSpread*.38+coverPitch)||0,
    visualScale:tune.visualKick*kickScale*(1+heat*.28),visualYaw:Math.sin((shotIndex+1)*tune.yawFrequency+tune.seed*.11),
    pelletSpread:profile.spread*(tune.pelletSpread||0)*accuracy};
}

function projectilePattern(profile,handling){
  const count=profile.pellets;
  return Array.from({length:count},(_,index)=>{
    // A recovered stationary single bullet (and the centre shotgun pellet)
    // hits the reticle exactly. Shotguns retain a symmetric physical pellet cone.
    const angle=(index-1)*Math.PI*2/Math.max(1,count-1)+profile.handling.seed*.17+handling.burstIndex*.37;
    const radius=index===0?0:handling.pelletSpread;
    return Object.freeze({
      index,yawOffset:handling.yaw+Math.cos(angle)*radius,pitchOffset:handling.pitch+Math.sin(angle)*radius,
      speed:profile.projectileSpeed,range:profile.range,color:profile.color,tracer:profile.tracer,
      explosive:profile.explosive,visualId:profile.id,visual:profile.projectileVisual,
    });
  });
}

// Crosshair uses the same next-shot calculation as the projectile, in radians.
// Spread is the angular cone envelope; recoilYaw/Pitch are the next shot centre.
export function sampleWeaponAccuracy(state,input={}){
  const profile=weaponFireProfile(state.weaponId);
  if(!profile)return Object.freeze({spread:0,recoilYaw:0,recoilPitch:0,heat:0,burstIndex:0,pelletSpread:0});
  const handling=shotHandling(profile,state,input);
  return Object.freeze({spread:handling.spread+handling.pelletSpread,recoilYaw:handling.yaw,recoilPitch:handling.pitch,
    heat:handling.heat,burstIndex:handling.burstIndex,pelletSpread:handling.pelletSpread,coverSpread:handling.coverSpread,coverYaw:handling.coverYaw,coverPitch:handling.coverPitch});
}

function makeShot(profile,sequence,input,handling){
  const casing=profile.casing==='none'||profile.casing==='retained'?null:Object.freeze({
    kind:'brass',delay:profile.casingDelay,side:'right',velocity:Object.freeze({right:1.65,up:2.2,forward:-.4}),
  });
  return Object.freeze({
    weaponId:profile.id,balanceId:profile.balanceId,sequence,shotId:`${profile.id}:${sequence}`,damage:profile.damage,mode:profile.mode,aiming:!!input.aiming,
    projectiles:Object.freeze(projectilePattern(profile,handling)),muzzleFlash:true,casing,
    handling:Object.freeze({posture:handling.posture,burstIndex:handling.burstIndex,heat:handling.heat,spread:handling.spread,yaw:handling.yaw,pitch:handling.pitch,coverSpread:handling.coverSpread,coverYaw:handling.coverYaw,coverPitch:handling.coverPitch}),
    recoil:Object.freeze({pitch:profile.recoil*handling.visualScale,yaw:handling.visualYaw*profile.recoil*.075*handling.visualScale,recovery:profile.recoilRecovery}),
  });
}

export function sampleWeaponRecoil(state){
  const profile=weaponFireProfile(state.weaponId);
  if(!profile)return Object.freeze({amount:0,normalized:0,pitch:0,yaw:0,weaponKick:0,bodyKick:0,cameraKick:0,recoilYaw:0});
  const amount=Math.max(0,+state.recoil||0),normalized=Math.min(1,amount/Math.max(.001,profile.recoil));
  const side=Number.isFinite(state.lastRecoilYaw)?state.lastRecoilYaw:(state.sequence&1)?-1:1;
  const scale=Number.isFinite(state.lastRecoilScale)?state.lastRecoilScale:1;
  return Object.freeze({amount,normalized,pitch:amount*.012*scale,yaw:side*amount*.0009*scale,weaponKick:normalized*scale,bodyKick:normalized*(profile.recoil>=3?.82:.52)*scale,cameraKick:normalized*Math.min(.045,.009+profile.recoil*.005)*scale,recoilYaw:side*normalized*scale});
}

export function stepWeaponFire(state,input={},dt=0){
  if(!Number.isFinite(dt)||dt<0||dt>5)throw Error('dt must be finite and between 0 and 5 seconds');
  const profile=weaponFireProfile(state.weaponId),held=!!input.triggerHeld,pressed=!!input.triggerPressed;
  if(!profile)return {state:{...state,triggerHeld:held},shots:[],dryFire:false,reloadStarted:false,reloadFinished:false};
  let next={...state},reloadStarted=false,reloadFinished=false,dryFire=false;
  next.recoil=Math.max(0,(+next.recoil||0)-dt*(profile.recoil/profile.recoilRecovery));
  next.cooldown=Math.max(-dt,Math.max(0,+next.cooldown||0)-dt);

  if(input.reload){
    const reloaded=beginWeaponReload(next);
    reloadStarted=reloaded.reloadRemaining>next.reloadRemaining;
    next=reloaded;
  }
  if(next.reloadRemaining>0){
    recoverSpray(next,dt);
    const before=next.reloadRemaining;
    next.reloadRemaining=Math.max(0,before-dt);
    if(before>0&&next.reloadRemaining===0){
      const wanted=profile.magazineSize-next.magazine,loaded=Math.min(wanted,next.reserveAmmo);
      next.magazine+=loaded;next.reserveAmmo-=loaded;reloadFinished=true;
    }
    next.triggerHeld=held;
    return {state:next,shots:[],dryFire:false,reloadStarted,reloadFinished};
  }

  const rising=pressed||(held&&!state.triggerHeld),continuous=profile.automatic&&held;
  const wantsShot=rising||continuous,shots=[];
  let sprayClock=0;
  if(wantsShot&&next.magazine<=0){
    dryFire=rising;
  }else if(wantsShot){
    const allowance=profile.automatic&&held?64:1;
    while(next.cooldown<=0&&next.magazine>0&&shots.length<allowance){
      const sequence=(+next.sequence||0)+1;
      // Recover up to each shot's actual time within a batched frame, not once
      // per rendering frame: low FPS cannot flatten a whole burst into one cone.
      const shotTime=Math.max(sprayClock,Math.min(dt,dt+next.cooldown));
      recoverSpray(next,shotTime-sprayClock);sprayClock=shotTime;
      const handling=shotHandling(profile,next,input);
      shots.push(makeShot(profile,sequence,input,handling));
      next.sequence=sequence;next.magazine-=1;next.cooldown+=profile.cooldown;
      next.recoil=Math.min(profile.recoil*2.15,next.recoil+profile.recoil);
      next.sprayHeat=Math.min(1,next.sprayHeat+profile.handling.heatPerShot);
      next.sprayShots+=1;next.sprayRecoveryRemaining=profile.handling.recovery;
      next.lastRecoilYaw=handling.visualYaw;next.lastRecoilScale=handling.visualScale;
      if(!continuous)break;
    }
  }
  recoverSpray(next,dt-sprayClock);
  next.cooldown=Math.max(0,next.cooldown);next.triggerHeld=held;
  return {state:next,shots,dryFire,reloadStarted,reloadFinished};
}
