// NATIVE_SERVICE_INITIAL_START
// Initial placement only. Existing presented actors are never relocated.
const _nativeDepotInitial={anchors:null,loading:false,retryAt:0,bays:new Map()};
function _nativeDepotAnchors(){
 const now=performance.now();if(!_nativeDepotInitial.loading&&now>=_nativeDepotInitial.retryAt&&typeof fetch==='function'){
  _nativeDepotInitial.loading=true;_nativeDepotInitial.retryAt=now+15000;
  fetch('/assets/maps/city_rebuild_v1/buildings_placement.v1.json').then(r=>{if(!r.ok)throw Error('native placement unavailable');return r.json()}).then(data=>{
   const anchors=new Map();for(const kind of ['firetruck','tow']){const item=(data.instances||[]).find(i=>kind==='firetruck'?i.assetId==='fire_station':/^(junkyard|scrapyard|scrap_yard)$/.test(i.assetId||'')),p=item?.entry?.anchorRC;if(p&&Number.isFinite(p.r)&&Number.isFinite(p.c))anchors.set(kind,{...p,id:item.id});}_nativeDepotInitial.anchors=anchors;
  }).catch(()=>{}).finally(()=>{_nativeDepotInitial.loading=false;});
 }
 return _nativeDepotInitial.anchors;
}
function _nativeServiceBayAdmit(kind,p){
 if(!p||typeof _walkTrafficNavigationResolver!=='function')return false;
 if(serviceVehicles.some(v=>v.state!=='done'&&Math.hypot(v.y-p.r,v.x-p.c)<2.7)||CARS.some(v=>!v._towed&&Math.hypot(v.r-p.r,v.c-p.c)<2.7))return false;
 return _walkTrafficNavigationResolver({carId:'initial-depot-'+kind,from:p,to:p,halfLength:kind==='firetruck'?1.4:1.25,halfWidth:.6,roadsOnly:true})?.clear===true;
}
function _nativeServiceDepotBays(kind,count){
 if(typeof _walkTrafficNavigationResolver!=='function')return [];
 const anchor=_nativeDepotAnchors()?.get(kind);if(!anchor){document.documentElement.dataset[kind+'NativeDepot']='waiting-for-authored-native-entry';return [];}
 const cached=_nativeDepotInitial.bays.get(kind);if(cached?.anchorId===anchor.id&&cached.points.length>=count)return cached.points;
 const points=cached?.anchorId===anchor.id?cached.points:[],request={mode:'road-targets',carId:'initial-depot-'+kind,from:{r:anchor.r,c:anchor.c,angle:0},minDistance:1,maxDistance:10,halfLength:kind==='firetruck'?1.4:1.25,halfWidth:.6};
 for(const p of _walkTrafficNavigationResolver(request)?.points||[]){if(points.length>=count)break;if(points.every(b=>Math.hypot(b.r-p.r,b.c-p.c)>=2.7)&&_nativeServiceBayAdmit(kind,p))points.push({...p});}
 _nativeDepotInitial.bays.set(kind,{anchorId:anchor.id,points});document.documentElement.dataset[kind+'NativeDepot']=points.length?'admitted:'+points.length:'waiting-for-free-native-road';return points;
}
function _nativeBusInitialAdmit(){
 if(typeof _walkRendererActive!=='function'||!_walkRendererActive())return true;
 if(BUS._nativeInitialReady)return true;if(BUS._nativeInitialPresented)return false;
 if(typeof _walkTrafficNavigationResolver!=='function')return false;
 const request={carId:'city_bus',halfLength:1.65,halfWidth:.65,roadsOnly:true},from={r:BUS.r,c:BUS.c,angle:BUS.ang||0};
 const clear=p=>!CARS.some(v=>!v._towed&&Math.hypot(v.r-p.r,v.c-p.c)<3)&&!serviceVehicles.some(v=>v.state!=='done'&&Math.hypot(v.y-p.r,v.x-p.c)<3)&&_walkTrafficNavigationResolver({...request,from:p,to:p})?.clear===true;
 let point=clear(from)?from:null;
 if(!point){const stop=BUS_STOPS[0];for(const p of _walkTrafficNavigationResolver({...request,mode:'road-targets',from:{r:stop.r,c:stop.c,angle:0},minDistance:0,maxDistance:10})?.points||[])if(clear(p)){point=p;break;}}
 if(!point)return false;BUS.r=point.r;BUS.c=point.c;BUS.ang=point.angle;BUS.state='stopped';BUS._nativeInitialReady=true;return true;
}
// NATIVE_SERVICE_INITIAL_END
