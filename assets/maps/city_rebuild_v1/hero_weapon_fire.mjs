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

const makeProfile=(id,balanceId)=>{
  const base=BALANCE[balanceId],automatic=base.mode==='auto';
  return Object.freeze({
    id,balanceId,mode:base.mode,automatic,cooldown:base.cooldown,range:base.range,spread:base.spread,
    projectileSpeed:base.projectileSpeed,color:base.color,damage:base.damage,recoil:base.recoil,
    recoilRecovery:Math.min(.34,.105+base.recoil*.027),magazineSize:base.magazineSize,
    reloadSeconds:base.reloadSeconds,pellets:base.pellets||1,casing:base.casing||'immediate',
    casingDelay:base.casingDelay||0,tracer:!!base.tracer,explosive:!!base.explosive,
    projectileVisual:PROJECTILE_VISUALS[id],
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
  };
}

export function beginWeaponReload(state){
  const profile=weaponFireProfile(state.weaponId);
  if(!profile||state.reloadRemaining>0||state.magazine>=profile.magazineSize||state.reserveAmmo<=0)return {...state};
  return {...state,reloadRemaining:profile.reloadSeconds,triggerHeld:false};
}

function projectilePattern(profile,sequence,aiming){
  const spread=profile.spread*(aiming?.32:1),count=profile.pellets;
  return Array.from({length:count},(_,index)=>{
    // A fixed sunflower pattern is deterministic, symmetric enough for a
    // readable low-poly muzzle cone, and changes orientation each shot.
    const radius=count===1?.62:Math.sqrt(index/Math.max(1,count-1));
    const angle=index*2.399963229728653+sequence*1.324717957244746;
    return Object.freeze({
      index,yawOffset:Math.cos(angle)*spread*radius,pitchOffset:Math.sin(angle)*spread*radius,
      speed:profile.projectileSpeed,range:profile.range,color:profile.color,tracer:profile.tracer,
      explosive:profile.explosive,visualId:profile.id,visual:profile.projectileVisual,
    });
  });
}

function makeShot(profile,sequence,aiming){
  const yawSign=(sequence&1)?-1:1;
  const casing=profile.casing==='none'||profile.casing==='retained'?null:Object.freeze({
    kind:'brass',delay:profile.casingDelay,side:'right',velocity:Object.freeze({right:1.65,up:2.2,forward:-.4}),
  });
  return Object.freeze({
    weaponId:profile.id,balanceId:profile.balanceId,sequence,shotId:`${profile.id}:${sequence}`,damage:profile.damage,mode:profile.mode,aiming:!!aiming,
    projectiles:Object.freeze(projectilePattern(profile,sequence,aiming)),muzzleFlash:true,casing,
    recoil:Object.freeze({pitch:profile.recoil*(aiming?.68:1),yaw:yawSign*profile.recoil*.075,recovery:profile.recoilRecovery}),
  });
}

export function sampleWeaponRecoil(state){
  const profile=weaponFireProfile(state.weaponId);
  if(!profile)return Object.freeze({amount:0,normalized:0,pitch:0,yaw:0,weaponKick:0,bodyKick:0,cameraKick:0,recoilYaw:0});
  const amount=Math.max(0,+state.recoil||0),normalized=Math.min(1,amount/Math.max(.001,profile.recoil));
  const side=(state.sequence&1)?-1:1;
  return Object.freeze({amount,normalized,pitch:amount*.012,yaw:side*amount*.0009,weaponKick:normalized,bodyKick:normalized*(profile.recoil>=3?.82:.52),cameraKick:normalized*Math.min(.045,.009+profile.recoil*.005),recoilYaw:side*normalized});
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
  if(wantsShot&&next.magazine<=0){
    dryFire=rising;
  }else if(wantsShot){
    const allowance=profile.automatic&&held?64:1;
    while(next.cooldown<=0&&next.magazine>0&&shots.length<allowance){
      const sequence=(+next.sequence||0)+1;
      shots.push(makeShot(profile,sequence,!!input.aiming));
      next.sequence=sequence;next.magazine-=1;next.cooldown+=profile.cooldown;
      next.recoil=Math.min(profile.recoil*2.15,next.recoil+profile.recoil);
      if(!continuous)break;
    }
  }
  next.cooldown=Math.max(0,next.cooldown);next.triggerHeld=held;
  return {state:next,shots,dryFire,reloadStarted,reloadFinished};
}
