import {createCarWorld,carFits} from './car_drive.mjs';
import {createLaneConnector} from './city_lane_connector.mjs';

/** The authored Old Town street narrows to one native asphalt row at c74/75.
 * Admit one direction only after its complete car hull fits existing asphalt.
 * This does not pave the adjacent footpath or shrink the vehicle collider.
 */
export function planOldTownNarrowPassage({approaches,topology,laneRoad,vehicleFits,metresPerCell=4.1}){
 const from=approaches.find(a=>a.roadId==='L-OL-H-011'&&a.junctionId==='street-junction-95'&&a.nextJunctionId==='street-junction-273'),to=approaches.find(a=>a.roadId==='L-OL-H-011'&&a.junctionId==='street-junction-273'&&a.nextJunctionId==='street-junction-95');
 if(!from||!to||from.direction!==1||to.direction!==-1||!from.outgoing[0]||!to.incoming[0])return null;
 const paving=createCarWorld(topology,[],metresPerCell,{surfaceAt:laneRoad}),pavingFits=(x,z,yaw)=>carFits(x,z,yaw,paving),first={...from.outgoing[0],x:from.center.x,z:from.center.z,offset:0,narrowCentered:true},last={...to.incoming[0],x:to.center.x,z:to.center.z,offset:0,narrowCentered:true};
 const curve=createLaneConnector({from:{x:first.x,z:first.z,yaw:Math.atan2(first.tx,first.tz)},to:{x:last.x,z:last.z,yaw:Math.atan2(last.tx,last.tz)},isRoad:laneRoad,poseAllowed:(x,z,yaw)=>pavingFits(x,z,yaw)&&vehicleFits(x,z,yaw),minRadius:4.3});
 if(!curve)return {from,to,pavingFits,curve:null,issue:{id:'one-way-narrow:L-OL-H-011:95:273',reason:'no_full_hull_asphalt_path'}};
 const id='one-way-narrow:L-OL-H-011:95:273';
 return {from,to,first,last,curve,pavingFits,metadata:{id,kind:'one_way_narrow_passage',roadId:from.roadId,pathId:from.pathId,direction:1,fromJunctionId:from.junctionId,toJunctionId:to.junctionId,fromApproachId:from.id,toApproachId:to.id,fromLaneId:first.id,toLaneId:last.id,points:curve.points,startM:from.progress+from.direction*from.entryDistance,endM:to.progress+to.direction*to.entryDistance,widthM:4.1,speedLimitKmh:10,rule:'one_way',reverseProhibited:true,minRadiusM:curve.minRadiusM}};
}
