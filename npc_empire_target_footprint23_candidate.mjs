// Isolated candidate only. Not imported by world or Walk.
export function empireTargetFootprintCandidate23(nearestSource,{ordered=true}={}){
 const direct='_npcBodyPassable(r,c,_empireBossPassable)',nearby='_npcBodyPassable(rr,cc,_empireBossPassable)';
 if(!nearestSource.includes(direct)||!nearestSource.includes(nearby))throw new Error('Unexpected nearest empire target source');
 let nearest=nearestSource.replace(direct,'_empireTargetFootprintPassable23(r,c)').replace(nearby,'_empireTargetFootprintPassable23(rr,cc)');
 if(ordered){
  const start=nearest.indexOf('  for(let radius=1;radius<=12;radius++)'),end=nearest.indexOf('  return best;',start);
  if(start<0||end<0)throw new Error('Unexpected finite nearest target loop');
  nearest=nearest.slice(0,start)+`  for(let radius=1;radius<=12&&radius-.5<bestD;radius++){
    const ring=[];
    for(let dr=-radius;dr<=radius;dr++)for(let dc=-radius;dc<=radius;dc++){
      if(Math.abs(dr)!==radius&&Math.abs(dc)!==radius)continue;
      const rr=Math.floor(r+dr)+.5,cc=Math.floor(c+dc)+.5,d=Math.hypot(rr-r,cc-c);
      if(d<bestD)ring.push({r:rr,c:cc,d});
    }
    ring.sort((a,b)=>a.d-b.d||a.r-b.r||a.c-b.c);
    for(const point of ring)if(_empireTargetFootprintPassable23(point.r,point.c)){best={r:point.r,c:point.c};bestD=point.d;break;}
  }
`+nearest.slice(end);
 }
 return `function _empireTargetFootprintPassable23(r,c){
 if(!_npcBodyPassable(r,c,_empireBossPassable))return false;
 if(typeof _walkNpcNavigationResolver!=='function')return true;
 const point={r,c},sweep=_walkNpcNavigationResolver({mode:'sweep',from:point,to:point,radius:.18});
 return !(sweep?.swept===true&&sweep.blocked);
}
`+nearest;
}
