import {FIREARM_IDS,createWeaponFireState,weaponFireProfile} from './hero_weapon_fire.mjs';

// Local /walk inspection inventory, not a replacement for authoritative world
// ownership, receipts or persistence. Rendering/interaction range stays in the host.
// Lifetime is local monotonic session time, not multiplayer-authoritative save time.
export const WEAPON_DROP_LIFETIME_MS=5*60*1000;
const defaultNow=()=>globalThis.performance?.now?.()??Date.now();
const knownIds=new Set(FIREARM_IDS);
const copyState=state=>({...state});
const stowedState=state=>({...state,reloadRemaining:0,recoil:0,triggerHeld:false});
const validPosition=position=>position&&['x','y','z'].every(axis=>Number.isFinite(position[axis]));
const copyDrop=drop=>({...drop,position:{...drop.position},fireState:copyState(drop.fireState)});

function validFireState(state,id){
  if(!state||state.weaponId!==id||!knownIds.has(id))return false;
  const profile=weaponFireProfile(id);
  return Number.isInteger(state.magazine)&&state.magazine>=0&&state.magazine<=profile.magazineSize&&
    Number.isInteger(state.reserveAmmo)&&state.reserveAmmo>=0&&state.reserveAmmo<=9999&&
    Number.isSafeInteger(state.sequence)&&state.sequence>=0&&
    ['cooldown','reloadRemaining','recoil'].every(key=>Number.isFinite(state[key])&&state[key]>=0)&&
    typeof state.triggerHeld==='boolean';
}

export function createWeaponInventory({ownedIds=FIREARM_IDS,fireStates={},dropped=[],maxDrops=Infinity,now=defaultNow}={}){
  if(!Array.isArray(ownedIds)||ownedIds.some(id=>!knownIds.has(id))||new Set(ownedIds).size!==ownedIds.length)
    throw Error('Inventory requires unique known firearm ids');
  if(maxDrops!==Infinity&&(!Number.isSafeInteger(maxDrops)||maxDrops<0))throw Error('Invalid drop capacity');
  if(typeof now!=='function')throw Error('Inventory requires a clock function');
  const checkedTime=value=>{if(!Number.isFinite(value)||value<0)throw Error('Invalid inventory clock time');return value;};
  const clock=()=>checkedTime(now());
  const owned=new Map(),drops=new Map();
  for(const id of ownedIds){
    const state=fireStates[id]??createWeaponFireState(id);
    if(!validFireState(state,id))throw Error(`Invalid initial fire state: ${id}`);
    owned.set(id,stowedState(state));
  }
  if(!Array.isArray(dropped)||dropped.length>maxDrops)throw Error('Invalid initial drops');
  for(const drop of dropped){
    if(!drop||typeof drop.uid!=='string'||!drop.uid||drops.has(drop.uid)||!knownIds.has(drop.weaponId)||
      !validPosition(drop.position)||!Number.isFinite(drop.yaw)||!validFireState(drop.fireState,drop.weaponId))
      throw Error('Invalid initial drop');
    const droppedAt=drop.droppedAt===undefined?clock():checkedTime(drop.droppedAt),expiresAt=droppedAt+WEAPON_DROP_LIFETIME_MS;
    if(!Number.isFinite(expiresAt)||(drop.expiresAt!==undefined&&drop.expiresAt!==expiresAt))throw Error('Invalid initial drop expiry');
    drops.set(drop.uid,copyDrop({...drop,droppedAt,expiresAt,fireState:stowedState(drop.fireState)}));
  }
  let equippedId='none',serial=0;
  const equippedState=()=>equippedId==='none'?createWeaponFireState('none'):copyState(owned.get(equippedId));
  const result=(ok,extra={})=>({ok,equippedId,fireState:equippedState(),...extra});
  const checkedCurrent=state=>state===undefined||
    (equippedId==='none'?state?.weaponId==='none':validFireState(state,equippedId));
  const storeCurrent=(state,stow=true)=>{
    if(equippedId!=='none')owned.set(equippedId,(stow?stowedState:copyState)(state??owned.get(equippedId)));
  };

  return Object.freeze({
    get equippedId(){return equippedId;},
    getOwnedIds(){return FIREARM_IDS.filter(id=>owned.has(id));},
    getDropped(){return [...drops.values()].map(copyDrop);},
    // Explicit removal list lets the host dispose matching world meshes. Snapshots
    // deliberately do not silently expire items behind the renderer's back.
    expireDrops(atMs=clock()){
      const at=checkedTime(atMs),expired=[];
      for(const [uid,drop] of drops)if(at>=drop.expiresAt){drops.delete(uid);expired.push(copyDrop(drop));}
      return expired;
    },
    getFireState(id=equippedId){return id==='none'?createWeaponFireState('none'):owned.has(id)?copyState(owned.get(id)):null;},
    snapshot(){return {equippedId,ownedIds:FIREARM_IDS.filter(id=>owned.has(id)),fireStates:Object.fromEntries([...owned].map(([id,state])=>[id,copyState(state)])),dropped:[...drops.values()].map(copyDrop)};},
    updateFireState(state){
      if(!checkedCurrent(state)||state===undefined)return result(false,{reason:'invalid_fire_state'});
      storeCurrent(state,false);
      return result(true);
    },
    equip(id,currentFireState){
      if(id!=='none'&&!owned.has(id))return result(false,{reason:'not_owned'});
      if(!checkedCurrent(currentFireState))return result(false,{reason:'invalid_fire_state'});
      // Reselecting the same item is not a reload/trigger cancellation shortcut.
      storeCurrent(currentFireState,id!==equippedId);
      if(id!==equippedId&&id!=='none')owned.set(id,stowedState(owned.get(id)));
      equippedId=id;
      return result(true);
    },
    drop({position,yaw=0,fireState}={}){
      if(equippedId==='none')return result(false,{reason:'unarmed'});
      if(!validPosition(position)||!Number.isFinite(yaw))return result(false,{reason:'invalid_transform'});
      if(!checkedCurrent(fireState))return result(false,{reason:'invalid_fire_state'});
      // Never evict an existing world item to make room for a new drop.
      if(drops.size>=maxDrops)return result(false,{reason:'drop_limit'});
      const droppedAt=clock();
      let uid;do{uid=`weapon-drop-${++serial}`;}while(drops.has(uid));
      const drop={uid,weaponId:equippedId,position:{x:position.x,y:position.y,z:position.z},yaw,droppedAt,expiresAt:droppedAt+WEAPON_DROP_LIFETIME_MS,
        fireState:stowedState(fireState??owned.get(equippedId))};
      drops.set(uid,drop);owned.delete(equippedId);equippedId='none';
      return result(true,{drop:copyDrop(drop)});
    },
    pickup(uid,currentFireState){
      const drop=drops.get(uid);
      if(!drop)return result(false,{reason:'missing_drop'});
      // Check here as well as during host sweeps: a suspended/background tab must
      // never recover an already expired item before its next animation frame.
      if(clock()>=drop.expiresAt){drops.delete(uid);return result(false,{reason:'expired_drop',expired:[copyDrop(drop)]});}
      if(owned.has(drop.weaponId))return result(false,{reason:'already_owned'});
      if(!checkedCurrent(currentFireState))return result(false,{reason:'invalid_fire_state'});
      // E collects only. Choosing a weapon is an explicit later arsenal action;
      // neither fists nor a live trigger/reload on the held gun are interrupted.
      storeCurrent(currentFireState,false);
      owned.set(drop.weaponId,stowedState(drop.fireState));drops.delete(uid);
      return result(true,{drop:copyDrop(drop)});
    },
  });
}
