// A street can end beyond its final junction. Its two directional tails are
// independently usable for arrival/departure; there is no implicit U-turn.
export function createRoadTerminalEdges({approaches,lanePoint,laneRoad,vehicleFits,step=.3}){
  const lanes=[],connections=[];
  for(const a of approaches){
    if(a.nextJunctionId||a.bridgePeerId)continue;
    const start=a.progress+a.direction*a.entryDistance,end=a.direction>0?a.path.length:0,length=Math.abs(end-start);
    if(length<3)continue;
    for(const sense of ['outgoing','incoming'])for(const anchor of a[sense]){
      const heading=a.direction*(sense==='outgoing'?1:-1),base=lanePoint(a.path,start,heading,anchor.index);let best=[];
      search:for(const fade of [4,2,1])for(const inset of [0,.15,.3,.45,.5]){
        if(!inset&&fade!==4)continue;
        if(inset&&anchor.offset-inset<1.3)continue;
        const points=[],steps=Math.max(1,Math.ceil(length/step));
        for(let k=0;k<=steps;k++){
          const travelled=length*k/steps,p=lanePoint(a.path,start+(end-start)*k/steps,heading,anchor.index),u=Math.min(1,travelled/fade),ease=u*u*(3-2*u),offset=inset*ease;
          const q={x:p.x+(anchor.x-base.x)*(1-ease)+p.tz*offset,z:p.z+(anchor.z-base.z)*(1-ease)-p.tx*offset,yaw:Math.atan2(p.tx,p.tz)};
          if(!laneRoad(q.x,q.z)||!vehicleFits(q.x,q.z,q.yaw))break;
          if(points.length){const prev=points.at(-1),forward=(q.x-prev.x)*Math.sin(q.yaw)+(q.z-prev.z)*Math.cos(q.yaw);if(forward*(sense==='outgoing'?1:-1)<-1e-5)break;}
          points.push(q);
        }
        if(points.length>best.length)best=points;if(points.length===steps+1)break search;
      }
      const distance=best.reduce((sum,p,k)=>sum+(k?Math.hypot(p.x-best[k-1].x,p.z-best[k-1].z):0),0);
      if(distance<3)continue;
      const arrival=sense==='outgoing',last=best.at(-1),terminal={...last,tx:Math.sin(last.yaw),tz:Math.cos(last.yaw),id:`road-terminal:${anchor.id}`,index:anchor.index,offset:anchor.offset,approachId:a.id,junctionId:null,sense:arrival?'incoming':'outgoing',terminal:true,terminalKind:arrival?'arrival':'departure'};
      lanes.push(terminal);
      const edge={id:`road-tail:${anchor.id}`,kind:arrival?'terminal_arrival':'terminal_departure',fromLaneId:arrival?anchor.id:terminal.id,toLaneId:arrival?terminal.id:anchor.id,pathId:a.pathId,length:distance,component:a.component,terminalStop:arrival,points:arrival?best:best.reverse()};
      connections.push(edge);
      if(arrival){a.canStopAtRoadEnd=true;(a.terminalArrivalLaneIds??=[]).push(anchor.id);}
    }
  }
  return {lanes,connections};
}
