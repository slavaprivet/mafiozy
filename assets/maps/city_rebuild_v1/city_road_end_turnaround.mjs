// Explicit forward-only manoeuvres at a real street end. The minimum radius is
// derived from the ordinary car's 2.65 m wheelbase / tan(.56 maximum steering).
import {createLaneConnector} from './city_lane_connector.mjs';
export function createRoadEndTurnarounds({approaches,terminalConnections,laneRoad,vehicleFits,minRadius=4.3}){
 const result=[],diagnostics=[],distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
 const length=points=>points.reduce((s,p,i)=>s+(i?distance(p,points[i-1]):0),0);
 for(const a of approaches){if(a.nextJunctionId||a.bridgePeerId||a.boundaryExit)continue;
  const arrivals=terminalConnections.filter(e=>e.kind==='terminal_arrival'&&e.fromLaneId.startsWith(a.id+':')),departures=terminalConnections.filter(e=>e.kind==='terminal_departure'&&e.toLaneId.startsWith(a.id+':'));let accepted=false;
  for(const arrival of arrivals)for(const departure of departures){const separation=distance(arrival.points[0],departure.points.at(-1));if(separation<minRadius*2)continue;
   search:for(let setback=3;setback<=18;setback+=1.5){let travelled=0,ai=arrival.points.length-1;while(ai>0&&travelled<setback){travelled+=distance(arrival.points[ai],arrival.points[ai-1]);ai--;}if(ai<2)continue;const p=arrival.points[ai],fx=Math.sin(p.yaw),fz=Math.cos(p.yaw);let bi=0,best=Infinity;for(let i=0;i<departure.points.length;i++){const q=departure.points[i],d=Math.abs((q.x-p.x)*fx+(q.z-p.z)*fz);if(d<best){best=d;bi=i;}}if(best>.7)continue;const q=departure.points[bi],span=distance(p,q);if(Math.cos(p.yaw-q.yaw)>-.98)continue;
    const curve=createLaneConnector({from:p,to:q,isRoad:laneRoad,poseAllowed:vehicleFits,minRadius,sampleStep:.15});if(!curve)continue;
    const prefix=arrival.points.slice(0,ai+1),points=[...prefix,...curve.points.slice(1),...departure.points.slice(bi+1)];result.push({id:`road-end-turnaround:${arrival.fromLaneId}>${departure.toLaneId}`,kind:'dead_end_turnaround',fromLaneId:arrival.fromLaneId,toLaneId:departure.toLaneId,pathId:a.pathId,component:a.component,points,length:length(points),minRadiusM:curve.minRadiusM,speedLimitKmh:5,controlProgressM:Math.max(0,length(prefix)-2.7),conflictingEdgeIds:departures.map(e=>e.id)});accepted=true;break search;
   }
  }
  if(arrivals.length&&departures.length)diagnostics.push({approachId:a.id,pathId:a.pathId,accepted,nominalWidthM:a.width,minimumTurnRadiusM:minRadius,minimumCarriagewayWidthM:minRadius*2+2.56,end:arrivals[0].points.at(-1)});
 }
 return {connections:result,diagnostics};
}
