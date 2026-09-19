import {createInteriorStaircase} from './interior_staircase.mjs';

// The room and output are in host metre axes. A rotated child maps local
// (x,z) to host (z,-x); every query and collision bound uses that same map.
export function createFittedStaircase(THREE,{rect,floorHeight=3.3,baseY=0,flightWidth=1.3,corner='back',side='center',orientation='auto'}={}){
 if(!rect||rect.length!==4||!rect.every(Number.isFinite)||rect[2]<=rect[0]||rect[3]<=rect[1])throw Error('Invalid fitted stair room');
 if(!['left','right','center'].includes(side))throw Error('Unknown staircase side');
 if(!['back','front'].includes(corner))throw Error('Unknown staircase corner');
 if(!['auto','unrotated','rotated'].includes(orientation))throw Error('Unknown staircase orientation');
 const requiredWidth=flightWidth*2+.18,requiredDepth=flightWidth*2+floorHeight/1.3;
 const possibilities=[{rotated:false,rect:rect.slice()},{rotated:true,rect:[-rect[3],rect[0],-rect[1],rect[2]]}].filter(p=>orientation==='auto'||p.rotated===(orientation==='rotated'));
 const variants=[{slope:.65,landingDepth:flightWidth,margin:.12,depth:requiredDepth,compact:false},{slope:.78,landingDepth:1.2,margin:.06,depth:2.4+floorHeight/1.56,compact:true}];
 let fit=null,variant=null;
 for(const v of variants){fit=possibilities.find(p=>p.rect[2]-p.rect[0]>=requiredWidth+v.margin*2-1e-7&&p.rect[3]-p.rect[1]>=v.depth+v.margin*2-1e-7);if(fit){variant=v;break}}
 if(!fit)throw Error(`No staircase orientation fits ${requiredWidth.toFixed(2)} x ${requiredDepth.toFixed(2)} metres plus margins`);
 const {margin,slope,landingDepth,depth}=variant;
 const origin={x:side==='left'?fit.rect[0]+margin:side==='right'?fit.rect[2]-margin-requiredWidth:(fit.rect[0]+fit.rect[2]-requiredWidth)/2,z:corner==='front'?fit.rect[3]-margin-depth:fit.rect[1]+margin};
 const source=createInteriorStaircase(THREE,{rect:fit.rect,floors:2,floorHeight,baseY,flightWidth,origin,slope,landingDepth});
 const toHost=p=>fit.rotated?{x:p.z,y:p.y,z:-p.x}:{...p};
 const toLocal=(x,z)=>fit.rotated?[-z,x]:[x,z];
 const mapRect=r=>fit.rotated?[r[1],-r[2],r[3],-r[0]]:r.slice();
 if(fit.rotated)source.group.rotation.y=Math.PI/2;
 source.group.name='Fitted_Interior_Staircase';
 source.group.updateMatrixWorld(true);
 const holeRects=source.holeRects.map(h=>({...h,rect:mapRect(h.rect)}));
 return {
  group:source.group,rotated:fit.rotated,compact:variant.compact,slope,footprint:mapRect(source.footprint),holeRect:holeRects[0].rect,holeRects,
  route:source.route.map(toHost),obstacles:source.obstacles.map(o=>({...o,rect:mapRect(o.rect)})),
  floorHeight,baseY,requiredSize:fit.rotated?{width:depth,depth:requiredWidth}:source.requiredSize,
  sampleFloor(x,z,referenceY=baseY){return source.sampleStairFloor(...toLocal(x,z),referenceY)},
  sampleCeiling(x,z,referenceY=baseY){return source.sampleStairCeiling(...toLocal(x,z),referenceY)},
  dispose:source.dispose,
 };
}
