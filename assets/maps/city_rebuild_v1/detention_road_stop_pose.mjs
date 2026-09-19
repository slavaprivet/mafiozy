// Body-facing poses on the near-side carriageway. Small measured insets keep
// the complete vehicle clear of the kerb; pedestrian handoff/intake stay fixed.
const kerbInsetM = Object.freeze({
 'REBUILD-DETENTION-southside': .20,
 'REBUILD-DETENTION-iron_harbor': .35,
 'REBUILD-DETENTION-chinatown': .25,
});
export function getDetentionRoadStopPose(site,{metresPerCell=4.1}={}){
 const r=site?.stopFootprint,yaw=site?.transform?.yawDegrees*Math.PI/180;
 if(!r||!Number.isFinite(yaw))return null;
 const inset=kerbInsetM[site.id]||0;
 return {x:(r.minC+r.maxC)*metresPerCell/2+Math.sin(yaw)*inset,
  z:(r.minR+r.maxR)*metresPerCell/2+Math.cos(yaw)*inset,yaw:yaw-Math.PI/2};
}
