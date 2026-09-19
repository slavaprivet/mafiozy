const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const smooth=v=>{const t=clamp(v,0,1);return t*t*(3-2*t)};

// The native raster has three full asphalt rows beside this straight section.
// Keep both eastbound lanes, but centre the outer lane on its actual paved width.
// Blend before/after the horizontal span so authored bends retain one tangent.
export function waterfrontLaneInset(path,progress,direction,laneIndex){
 if(path.id!=='A-WATERFRONT-W'||direction!==1||laneIndex!==1)return 0;
 const span=path.segments.find(s=>Math.abs(s.a.z-617.05)<.01&&Math.abs(s.b.z-617.05)<.01&&s.tx>.999&&s.length>80);
 if(!span)return 0;
 return .78*smooth((progress-span.start+12)/12)*smooth((span.start+span.length+12-progress)/12);
}
