// Presentation-only airborne sampler. The host owns collision, root motion,
// heading, action admission and weapon inventory. The host must restore its
// chosen base pose before calling applyHeroAirborneMotionPose.
const clamp01=value=>Math.max(0,Math.min(1,Number.isFinite(value)?value:0));
const smooth=(value,min=0,max=1)=>{const t=clamp01((value-min)/(max-min||1));return t*t*(3-2*t)};

export const HERO_AIRBORNE_PHASES=Object.freeze(['ascent','apex','fall','long-fall','landing']);

/**
 * Convert host-authoritative motion into a deterministic presentation sample.
 * `landingAge` is null until the first supported frame. Supplying the same
 * values (including after a dt=0 host tick) always produces the same sample.
 */
export function sampleHeroAirborneMotion({
  verticalVelocity=0,
  airborneAge=0,
  fallDistance=0,
  landingAge=null,
  landingDuration=.34,
  impactSpeed=0,
  armed=false,
}={},out=null){
  verticalVelocity=Number.isFinite(verticalVelocity)?verticalVelocity:0;
  airborneAge=Math.max(0,Number.isFinite(airborneAge)?airborneAge:0);
  fallDistance=Math.max(0,Number.isFinite(fallDistance)?fallDistance:0);
  landingDuration=Math.max(.12,Number.isFinite(landingDuration)?landingDuration:.34);
  impactSpeed=Math.max(0,Number.isFinite(impactSpeed)?impactSpeed:Math.max(0,-verticalVelocity));
  let phase,progress;
  if(Number.isFinite(landingAge)&&landingAge>=0){
    phase='landing';progress=clamp01(landingAge/landingDuration);
  }else if(verticalVelocity>.7){
    phase='ascent';progress=clamp01(1-verticalVelocity/7.5);
  }else if(verticalVelocity>-.9){
    phase='apex';progress=clamp01((.7-verticalVelocity)/1.6);
  }else if(fallDistance>=2.2||airborneAge>=.95){
    phase='long-fall';progress=clamp01(Math.max((fallDistance-2.2)/3.8,(airborneAge-.95)/.75));
  }else{
    phase='fall';progress=clamp01(Math.max(-verticalVelocity/8,fallDistance/2.2));
  }
  const severity=clamp01(Math.max(impactSpeed/11,fallDistance/5.5));
  out=out&&typeof out==='object'?out:null;const sample=out||{};sample.phase=phase;sample.progress=progress;sample.severity=severity;
  sample.verticalVelocity=verticalVelocity;sample.airborneAge=airborneAge;sample.fallDistance=fallDistance;
  sample.landingAge=Number.isFinite(landingAge)?Math.max(0,landingAge):null;
  sample.landingDuration=landingDuration;sample.weaponPolicy=armed?'holster':'none';
  return out?sample:Object.freeze(sample);
}

/** Apply rotations on top of the host's restored/base pose. Never moves root/yaw. */
export function applyHeroAirborneMotionPose(THREE,context,sample){
  if(!THREE||!context?.bones||!context.rotateAdd||!HERO_AIRBORNE_PHASES.includes(sample?.phase))return false;
  const p=clamp01(sample.progress),severity=clamp01(sample.severity);
  let chest=0,neck=0,head=0,spread=0,armLift=0,armBend=0,hip=0,knee=0,ankle=0,twist=0,weight=1;
  switch(sample.phase){
    case 'ascent': {
      const release=smooth(p,.08,1);chest=-.11+.08*release;neck=.06;head=.04;
      spread=.05+.08*release;armLift=.42-.17*release;armBend=.62-.19*release;
      hip=.68-.24*release;knee=1.02-.34*release;ankle=-.18;twist=.08*(1-release);break;
    }
    case 'apex': {
      const center=1-Math.abs(p*2-1);chest=-.025;neck=-.02;head=.03;
      spread=.31+.07*center;armLift=.5+.12*center;armBend=.35;
      hip=.28+.09*center;knee=.5+.1*center;ankle=-.08;twist=.035*(p*2-1);break;
    }
    case 'fall': {
      const brace=smooth(p,.05,1);chest=.06+.12*brace;neck=-.07;head=-.09;
      spread=.4+.14*brace;armLift=.62+.38*brace;armBend=.28+.2*brace;
      hip=.25+.28*brace;knee=.4+.46*brace;ankle=-.1-.09*brace;twist=-.055*brace;break;
    }
    case 'long-fall': {
      const brace=smooth(p,0,1);chest=.18+.11*brace;neck=-.13;head=-.16;
      spread=.56;armLift=1.05+.23*brace;armBend=.45;
      hip=.53+.18*brace;knee=.85+.2*brace;ankle=-.22;twist=-.085+.04*brace;break;
    }
    case 'landing': {
      const carry=1-smooth(p,0,1.5),compression=.5*smooth(p,0,.14)*(1-smooth(p,.22,1));
      const recover=1-smooth(p,.42,1);weight=Math.max(carry,compression,recover*.2);
      // Carry the pre-impact brace into the first supported frames. Severity
      // selects how much of the long-fall tuck remains, avoiding a one-frame
      // straightening snap before impact compression.
      chest=(.17+.15*severity)*compression+(.13+.13*severity)*carry;neck=-.08*compression-.05*severity*carry;head=-.1*compression-.06*severity*carry;
      spread=(.22+.3*severity)*carry+.08*compression;armLift=(.75+.47*severity)*carry+.24*compression;
      armBend=(.42+.03*severity)*carry+.58*compression;hip=((.35+.35*severity)*carry+(1.04+.2*severity)*compression);
      knee=(.52+.52*severity)*carry+(1.46+.18*severity)*compression;ankle=(-.18-.04*severity)*carry-.31*compression;twist=-.04*carry;break;
    }
  }
  const add=(name,x=0,y=0,z=0)=>context.rotateAdd(name,x*weight,y*weight,z*weight);
  add('chest',chest,twist,0);add('neck',neck,-twist*.38,0);add('head',head,-twist*.25,0);
  // Unequal legs and arms remove the rigid-pillar silhouette while retaining a
  // stable centre of mass. The sign is authored against the real GLB axes.
  for(const [side,sign] of [['l',1],['r',-1]]){
    const lead=sign*(sample.phase==='ascent'?1:sample.phase==='landing'?-1:.55);
    add(`upperarm_${side}`,-armLift*(1+lead*.11),0,sign*spread);
    add(`forearm_${side}`,-armBend*(1-lead*.12),0,sign*.035);
    add(`thigh_${side}`,-hip*(1-lead*.12),0,sign*.055);
    add(`shin_${side}`,knee*(1+lead*.1));
    add(`foot_${side}`,ankle*(1-lead*.08));
  }
  context.object.updateMatrixWorld(true);
  if(sample.phase==='landing')context.groundPose?.();
  return true;
}
