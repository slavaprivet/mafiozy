import assert from 'node:assert/strict';
// Transform an extracted pickNpcWaypoint only. No production files are written.
export function neighborSliceCandidate18(source){
 assert(!source.includes('let neighborYield=false;'),'do not apply neighbor slicing twice');
 const start=source.indexOf('  let walkChoices=resolver?');
 const end=source.indexOf('  // Retain the already checked frontier',start);
 assert(start>=0&&end>start,'bounded wander expansion');
 let body=source.slice(start,end);
 const candidate="    if(cur.depth>=1){candidates.push(cur);if(resolver&&longWalk(cur)&&++walkChoices>=wanderChoiceTarget){walkReady=true;break;}}";
 assert(body.includes(candidate));
 body=body.replace(candidate,`    if(search.expandingNodeKey!==cur.key){
      search.expandingNodeKey=cur.key;search.nextDirection=0;
      if(cur.depth>=1){candidates.push(cur);if(resolver&&longWalk(cur)&&++walkChoices>=wanderChoiceTarget){walkReady=true;break;}}
    }`);
 const loop='    for(const [dr,dc] of dirs){';assert(body.includes(loop));
 body=body.replace(loop,`    let neighborYield=false;
    for(;search.nextDirection<dirs.length;search.nextDirection++){
      if(_npcRouteWorkExpired()){neighborYield=true;break;}
      const [dr,dc]=dirs[search.nextDirection];`);
 const tail='    }\n  }\n';assert(body.endsWith(tail));
 body=body.slice(0,-tail.length)+'    }\n    if(neighborYield)break; // Keep qi on this node and resume its remaining neighbors.\n  }\n';
 return source.slice(0,start)+body+source.slice(end);
}

export function historicalWholeNode18(source){
 const marker=`    if(search.expandingNodeKey!==cur.key){
      search.expandingNodeKey=cur.key;search.nextDirection=0;
      if(cur.depth>=1){candidates.push(cur);if(resolver&&longWalk(cur)&&++walkChoices>=wanderChoiceTarget){walkReady=true;break;}}
    }`;
 assert(source.includes(marker),'applied once-per-node candidate marker');
 let previous=source.replace(marker,'    if(cur.depth>=1){candidates.push(cur);if(resolver&&longWalk(cur)&&++walkChoices>=wanderChoiceTarget){walkReady=true;break;}}');
 const loop=`    let neighborYield=false;
    for(;search.nextDirection<dirs.length;search.nextDirection++){
      if(_npcRouteWorkExpired()){neighborYield=true;break;}
      const [dr,dc]=dirs[search.nextDirection];`;
 assert(previous.includes(loop));previous=previous.replace(loop,'    for(const [dr,dc] of dirs){');
 const tail='    if(neighborYield)break; // Keep qi on this node and resume its remaining neighbors.\n';
 assert(previous.includes(tail));return previous.replace(tail,'');
}
