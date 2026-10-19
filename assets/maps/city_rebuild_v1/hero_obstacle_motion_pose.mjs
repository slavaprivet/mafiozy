// Presentation adapter for the three obstacle motions selected by traversal
// physics. It reuses the proven ledge-hand solver without owning root motion.
import {applyTraversalPose} from './hero_traversal_pose.mjs';

const clamp01=value=>Math.max(0,Math.min(1,Number.isFinite(value)?value:0));
const smooth=(value,min=0,max=1)=>{const t=clamp01((value-min)/(max-min||1));return t*t*(3-2*t)};

export function sampleHeroObstacleMotion({kind='auto-step',progress=0,obstacleHeight=.2,leadSide='l',direction,edge,start,handL,handR,armed=false}={},out=null){
  if(!['auto-step','vault','mantle'].includes(kind))return null;
  progress=clamp01(progress);obstacleHeight=Math.max(0,Number.isFinite(obstacleHeight)?obstacleHeight:0);
  out=out&&typeof out==='object'?out:null;const sample=out||{};sample.kind=kind;sample.progress=progress;sample.obstacleHeight=obstacleHeight;
  sample.leadSide=leadSide==='r'?'r':'l';sample.direction=direction;sample.edge=edge;sample.start=start;
  sample.handL=handL;sample.handR=handR;sample.armed=!!armed;sample.phaseName=kind;
  sample.weaponPolicy=kind==='auto-step'?'carry-safe':'holster';return out?sample:Object.freeze(sample);
}

export function applyHeroObstacleMotionPose(THREE,context,sample){
  if(!THREE||!context?.bones||!sample||!['auto-step','vault','mantle'].includes(sample.kind))return false;
  if(sample.kind!=='auto-step')return applyTraversalPose(THREE,context,sample);
  const p=clamp01(sample.progress),up=smooth(p,0,.3),down=1-smooth(p,.55,1),lift=up*down;
  if(lift<=0)return true;
  const unit=context.targetHeight/1.9,height=Math.max(.04,Math.min(.32,sample.obstacleHeight/Math.max(unit,.001)));
  const amount=lift*smooth(height,.04,.32),lead=sample.leadSide,trail=lead==='l'?'r':'l',sign=lead==='l'?1:-1;
  context.rotateAdd('chest',.06*amount,0,-sign*.035*amount);
  context.rotateAdd('neck',-.035*amount);context.rotateAdd('head',-.025*amount);
  context.rotateAdd(`thigh_${lead}`,-.92*amount,0,-sign*.045*amount);
  context.rotateAdd(`shin_${lead}`,1.24*amount);context.rotateAdd(`foot_${lead}`,-.28*amount);
  context.rotateAdd(`thigh_${trail}`,-.18*amount);context.rotateAdd(`shin_${trail}`,.27*amount);
  // Compact counter-swing keeps an armed auto-step clear of the raised knee.
  if(!sample.armed){
    context.rotateAdd(`upperarm_${lead}`,-.2*amount,0,-sign*.08*amount);
    context.rotateAdd(`forearm_${lead}`,-.12*amount);
    context.rotateAdd(`upperarm_${trail}`,.16*amount,0,sign*.06*amount);
  }
  context.object.updateMatrixWorld(true);return true;
}
