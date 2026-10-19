import {makeWalkMapSurfacePaintCommand,WALK_MAP_EDITOR_SURFACES} from './walk_map_editor_document.mjs';

const MAX_STROKE_CELLS=100000;
function finite(value){return typeof value==='number'&&Number.isFinite(value);}
function clamp(value,min,max){return Math.min(max,Math.max(min,value));}
function cellKey(r,c){return `${r}:${c}`;}

export function createWalkMapSurfaceAdapter({rows=200,cols=180,metresPerCell=4.1,maxStrokeCells=MAX_STROKE_CELLS,idFactory=()=>globalThis.crypto?.randomUUID?.()??`surface-${Date.now().toString(36)}`,onPreview=()=>{},onCancel=()=>{}}={}){
 if(!Number.isInteger(rows)||rows<=0||!Number.isInteger(cols)||cols<=0||!finite(metresPerCell)||metresPerCell<=0)throw new Error('Invalid surface adapter map dimensions');
 if(!Number.isInteger(maxStrokeCells)||maxStrokeCells<=0||maxStrokeCells>MAX_STROKE_CELLS)throw new Error('Invalid surface stroke quota');
 let gesture=null;
 function requireGesture(){if(!gesture)throw new Error('No surface stroke is active');return gesture;}
 function addDisk(target,row,column,radiusCells,added=[]){
  const radius=Math.max(.05,radiusCells),minR=Math.floor(row-radius),maxR=Math.ceil(row+radius),minC=Math.floor(column-radius),maxC=Math.ceil(column+radius);
  for(let r=minR;r<=maxR;r++)for(let c=minC;c<=maxC;c++){
   if(r<0||c<0||r>=rows||c>=cols)continue;
   const dr=r+.5-row,dc=c+.5-column;if(dr*dr+dc*dc>(radius+.71)*(radius+.71))continue;
   const key=cellKey(r,c);if(target.has(key))continue;if(target.size>=maxStrokeCells)throw new Error(`Surface stroke exceeds ${maxStrokeCells} cells`);target.set(key,[r,c]);added.push(key);
  }
 }
 function clipSegment(from,to,padding){
  const dr=to.r-from.r,dc=to.c-from.c;let start=0,end=1;
  for(const [p,q] of [[-dr,from.r+padding],[dr,rows+padding-from.r],[-dc,from.c+padding],[dc,cols+padding-from.c]]){
   if(p===0){if(q<0)return null;continue}const ratio=q/p;if(p<0){if(ratio>end)return null;start=Math.max(start,ratio)}else{if(ratio<start)return null;end=Math.min(end,ratio)}
  }
  return {from:{r:from.r+dr*start,c:from.c+dc*start},to:{r:from.r+dr*end,c:from.c+dc*end}};
 }
 function addSegment(from,to){
  const clipped=clipSegment(from,to,gesture.radiusCells+1);if(!clipped)return;
  const dr=clipped.to.r-clipped.from.r,dc=clipped.to.c-clipped.from.c,length=Math.hypot(dr,dc),steps=Math.max(1,Math.ceil(length*2)),added=[];
  try{for(let index=0;index<=steps;index++){const t=index/steps;addDisk(gesture.cells,clipped.from.r+dr*t,clipped.from.c+dc*t,gesture.radiusCells,added)}}catch(error){for(const key of added)gesture.cells.delete(key);throw error}
 }
 function pointFromWorld(x,z){if(!finite(x)||!finite(z))throw new Error('Surface pointer requires finite world coordinates');return {r:z/metresPerCell,c:x/metresPerCell};}
 function snapshot(){
  const current=requireGesture(),cells=[...current.cells.values()].map(([r,c])=>[r,c]).sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
  return {id:current.id,materialId:current.materialId,mode:current.mode,shape:{type:'cells',cells},brush:{radiusM:current.radiusM}};
 }
 function begin({x,z,materialId='grass',mode='paint',radiusM=metresPerCell*.5,id=idFactory()}={}){
  if(gesture)throw new Error('A surface stroke is already active');
  if(!WALK_MAP_EDITOR_SURFACES.includes(materialId))throw new Error(`Unsupported surface material: ${materialId}`);
  if(!['paint','erase','restore'].includes(mode))throw new Error(`Unsupported surface mode: ${mode}`);
  if(!finite(radiusM)||radiusM<=0||radiusM>metresPerCell*24)throw new Error('Surface brush radius is invalid');
  const point=pointFromWorld(x,z);gesture={id:String(id),materialId,mode,radiusM,radiusCells:radiusM/metresPerCell,cells:new Map(),last:point};try{addDisk(gesture.cells,point.r,point.c,gesture.radiusCells);const result=snapshot();onPreview(result);return result}catch(error){gesture=null;throw error}
 }
 function move({x,z}={}){const current=requireGesture(),next=pointFromWorld(x,z);addSegment(current.last,next);current.last=next;const result=snapshot();onPreview(result);return result;}
 function cancel(reason='cancel'){if(!gesture)return false;const value=snapshot();gesture=null;onCancel(value,reason);return true;}
 function finish(){const stroke=snapshot();gesture=null;if(!stroke.shape.cells.length)throw new Error('Surface stroke has no cells');return makeWalkMapSurfacePaintCommand(stroke);}
 function setRadius(radiusM){const current=requireGesture();if(!finite(radiusM)||radiusM<=0||radiusM>metresPerCell*24)throw new Error('Surface brush radius is invalid');current.radiusM=radiusM;current.radiusCells=radiusM/metresPerCell;const result=snapshot();onPreview(result);return result;}
 return {get active(){return !!gesture},get radiusM(){return gesture?.radiusM??null},begin,move,finish,cancel,setRadius,preview:()=>gesture?snapshot():null,dispose:()=>cancel('dispose')};
}

export {MAX_STROKE_CELLS};
