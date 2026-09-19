// Test-only reconstruction of the preceding eager DFS; never imported by game.
export function historicalEagerWander19(pick){
 const start=pick.indexOf('  // Native lazy DFS checks only');
 const middle=pick.indexOf('  }else{\n  for(;!walkReady',start);
 const end=pick.indexOf('  }\n  // Retain the already checked frontier',middle);
 if(start<0||middle<0||end<0)throw Error('Applied lazy DFS markers missing');
 return pick.slice(0,start)+pick.slice(middle+'  }else{\n'.length,end)+pick.slice(end+4);
}
