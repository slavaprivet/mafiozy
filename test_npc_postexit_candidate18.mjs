// Pure staging helper: root owns production _civilianRouteTo.
export function stageCivilianExactTail(source){
 const before='return _setNpcRoute(n,[...(ok?n._route:[]),{r,c}],kind);';
 const after='return _setNpcRoute(n,ok&&Math.hypot(end.r-r,end.c-c)<1e-6?n._route:[...(ok?n._route:[]),{r,c}],kind);';
 if(source.includes(after))return source;
 if(!source.includes(before))throw Error('Civilian route return changed');
 return source.replace(before,after);
}
