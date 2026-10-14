// Presentation-only extraction of three_preview.js lines 5168-5188.
// The host owns the authoritative clock, weather, interiors and update timing.
const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const clamp01=value=>clamp(Number.isFinite(value)?value:0,0,1);
const smoothstep=(value,min,max)=>{const t=clamp01((value-min)/(max-min||1));return t*t*(3-2*t)};
const lerp=(a,b,t)=>a+(b-a)*t;
export const WALK_TIME_OF_DAY_POLL_INTERVAL_MS=250;
export const WALK_TIME_OF_DAY_SMOOTH_RATE=2.4;
const outputPalettes=new WeakMap();

export function isValidCityClock(clock){return !!clock&&typeof clock.hour==='number'&&typeof clock.minute==='number'&&Number.isFinite(clock.hour)&&Number.isFinite(clock.minute)&&Number.isInteger(clock.hour)&&Number.isInteger(clock.minute)&&clock.hour>=0&&clock.hour<=23&&clock.minute>=0&&clock.minute<=59}
function normalizeHour(hour,minute=0,offset=0){if(!isValidCityClock({hour,minute}))throw RangeError('City clock requires integer hour 0..23 and minute 0..59');if(typeof offset!=='number'||!Number.isFinite(offset))throw TypeError('Time-of-day offset must be a finite number');const value=hour+minute/60+offset;return ((value%24)+24)%24}
function setColor(out,source){out.copy(source);return out}
function colorLerp(out,a,b,t){return out.copy(a).lerp(b,t)}

function createPalette(THREE){return {
 daySky:new THREE.Color(0x3d7298),dawnSky:new THREE.Color(0xb66f63),duskSky:new THREE.Color(0xb2574d),nightSky:new THREE.Color(0x0a1930),
 dayGround:new THREE.Color(0x51473c),nightGround:new THREE.Color(0x324158),
 daySun:new THREE.Color(0xffe0ad),dawnSun:new THREE.Color(0xffb071),duskSun:new THREE.Color(0xff8c58),
};}
function createOutput(THREE){return {hour:12,daylight:1,dawn:0,dusk:0,warmth:0,night:0,lampsScheduledOn:false,lampPower:0,phase:'day',background:new THREE.Color(),fogColor:new THREE.Color(),fogDensity:.00305,ambientColor:new THREE.Color(),ambientGroundColor:new THREE.Color(),ambientIntensity:2.5,sunColor:new THREE.Color(),sunIntensity:3.5,sunOffset:new THREE.Vector3(),exposure:1.32,environmentIntensity:.82};}

function fillOutput(out,palette,{hour,daylight,dawn,dusk,weather='clear'}){
 daylight=clamp01(daylight);dawn=clamp01(dawn);dusk=clamp01(dusk);const warmth=Math.max(dawn*.72,dusk),night=1-daylight,lampsScheduledOn=hour<7||hour>=17,lampPower=lampsScheduledOn?Math.max(.48,night):0;
 colorLerp(out.background,palette.nightSky,palette.daySky,daylight);if(dawn>.001)out.background.lerp(palette.dawnSky,dawn*.42);if(dusk>.001)out.background.lerp(palette.duskSky,dusk*.5);setColor(out.fogColor,out.background);
 out.ambientColor.setRGB(.43+.35*daylight+.08*warmth,.51+.3*daylight+.035*warmth,.7+.18*daylight);colorLerp(out.ambientGroundColor,palette.nightGround,palette.dayGround,daylight);out.ambientIntensity=1.32+1.18*daylight+.08*warmth;
 setColor(out.sunColor,palette.daySun);if(dawn>.001)out.sunColor.lerp(palette.dawnSun,dawn);if(dusk>.001)out.sunColor.lerp(palette.duskSun,dusk);out.sunIntensity=.42+3.08*daylight+.16*warmth;out.sunOffset.set(Math.cos(hour/24*Math.PI*2)*75,16+daylight*74,Math.sin(hour/24*Math.PI*2)*65);
 out.hour=hour;out.daylight=daylight;out.dawn=dawn;out.dusk=dusk;out.warmth=warmth;out.night=night;out.lampsScheduledOn=lampsScheduledOn;out.lampPower=lampPower;out.exposure=1.16+daylight*.16+warmth*.035;out.environmentIntensity=.46+daylight*.36+warmth*.04;out.fogDensity=.00305+night*.00062+(weather==='rain'?.00048:weather==='snow'?.00025:0);out.phase=dawn>.15?'dawn':daylight>.62?'day':dusk>.15?'dusk':'night';return out;
}

export function sampleWalkTimeOfDay(THREE,{hour=12,minute=0,offset=0,weather='clear'}={},out=null,palette=null){
 if(!THREE?.Color||!THREE?.Vector3)throw Error('walk time of day requires THREE Color and Vector3');out=out&&typeof out==='object'?out:createOutput(THREE);if(!palette){palette=outputPalettes.get(out);if(!palette){palette=createPalette(THREE);outputPalettes.set(out,palette)}}const normalized=normalizeHour(hour,minute,offset),sunHeight=Math.sin((normalized-6)/24*Math.PI*2),daylight=smoothstep(sunHeight,-.2,.4),dawn=1-smoothstep(Math.abs(normalized-6.35),.15,1.85),dusk=1-smoothstep(Math.abs(normalized-18.65),.15,2.05);return fillOutput(out,palette,{hour:normalized,daylight,dawn,dusk,weather});
}

export function applyWalkTimeOfDay(frame,{scene,ambient,sun,renderer,sunOffsetVector,interiorLightingActive=false}={}){
 if(!frame||interiorLightingActive)return false;
 if(scene?.background?.isColor)scene.background.copy(frame.background);
 const fog=scene?.fog;if(fog?.color?.isColor){fog.color.copy(frame.fogColor);if(fog.isFogExp2&&Number.isFinite(frame.fogDensity))fog.density=frame.fogDensity;}
 if(ambient){ambient.color?.copy?.(frame.ambientColor);ambient.groundColor?.copy?.(frame.ambientGroundColor);ambient.intensity=frame.ambientIntensity;}
 if(sun){sun.color?.copy?.(frame.sunColor);sun.intensity=frame.sunIntensity;}
 if(renderer)renderer.toneMappingExposure=frame.exposure;
 if(scene)scene.environmentIntensity=frame.environmentIntensity;
 sunOffsetVector?.copy?.(frame.sunOffset);return true;
}

export function createWalkTimeOfDay({THREE,initialHour=12,initialMinute=0,timeOffset=0,smoothingRate=WALK_TIME_OF_DAY_SMOOTH_RATE,weather='clear'}={}){
 if(!THREE?.Color||!THREE?.Vector3)throw Error('walk time of day requires THREE');const palette=createPalette(THREE),target=createOutput(THREE),output=createOutput(THREE),interval=WALK_TIME_OF_DAY_POLL_INTERVAL_MS,rate=Math.max(0,Number.isFinite(smoothingRate)?smoothingRate:WALK_TIME_OF_DAY_SMOOTH_RATE),initial=isValidCityClock({hour:initialHour,minute:initialMinute})?{hour:initialHour,minute:initialMinute}:{hour:12,minute:0};
 let hour=initial.hour,minute=initial.minute,qaOffset=typeof timeOffset==='number'&&Number.isFinite(timeOffset)?timeOffset:0,currentWeather=weather,nextSampleAt=-Infinity,lastAt=null,ready=false,samples=0,acceptedSamples=0,rejectedSamples=0,disposed=false;
 function accept(clock){if(!isValidCityClock(clock))return false;hour=clock.hour;minute=clock.minute;return true}
 function update(nowMs,clockSource=null,options={}){if(disposed)return output;nowMs=Number.isFinite(nowMs)?nowMs:0;if(nowMs>=nextSampleAt){nextSampleAt=nowMs+interval;samples++;let clock=null;try{clock=typeof clockSource==='function'?clockSource():clockSource}catch{}if(accept(clock))acceptedSamples++;else rejectedSamples++}if(typeof options.weather==='string')currentWeather=options.weather;sampleWalkTimeOfDay(THREE,{hour,minute,offset:qaOffset,weather:currentWeather},target,palette);const dt=lastAt===null?0:Math.min(.1,Math.max(0,(nowMs-lastAt)/1000));lastAt=nowMs;if(!ready){output.daylight=target.daylight;output.dawn=target.dawn;output.dusk=target.dusk;ready=true}else{const ease=1-Math.exp(-dt*rate);output.daylight=lerp(output.daylight,target.daylight,ease);output.dawn=lerp(output.dawn,target.dawn,ease);output.dusk=lerp(output.dusk,target.dusk,ease)}return fillOutput(output,palette,{hour:target.hour,daylight:output.daylight,dawn:output.dawn,dusk:output.dusk,weather:currentWeather})}
 function reset(clock=initial,nowMs=0){if(disposed)return output;hour=initial.hour;minute=initial.minute;accept(clock);nextSampleAt=-Infinity;lastAt=null;ready=false;samples=acceptedSamples=rejectedSamples=0;return update(nowMs,clock,{weather:currentWeather})}
 function setOffset(hours){if(typeof hours!=='number'||!Number.isFinite(hours))throw TypeError('QA time offset must be a finite number');qaOffset=hours;return qaOffset}
 return {update,reset,setOffset,apply(frame,targets){return disposed?false:applyWalkTimeOfDay(frame,targets)},dispose(){disposed=true},get output(){return output},get target(){return target},get stats(){return {sampleIntervalMs:interval,smoothingRate:rate,samples,acceptedSamples,rejectedSamples,nextSampleAt,lastAt,qaOffset,disposed}}};
}
