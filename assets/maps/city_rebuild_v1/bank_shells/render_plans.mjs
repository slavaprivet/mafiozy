import fs from 'node:fs';
const dir=new URL('./',import.meta.url),manifest=JSON.parse(fs.readFileSync(new URL('manifest.v1.json',dir),'utf8'));
const names={small:'Малый банк',medium:'Средний банк',large:'Большой банк'};
for(const bank of manifest.entries){
 const size=bank.canonicalGameplayId.split(':')[1],{width:w,depth:d}=bank.clearRoom;
 const s=Math.min(850/w,560/d),x0=(1000-w*s)/2,z0=125;
 const x=n=>x0+(n+w/2)*s,z=n=>z0+(n+d/2)*s;
 const rectangle=(r,fill)=>`<rect x="${x(r[0])}" y="${z(r[1])}" width="${(r[2]-r[0])*s}" height="${(r[3]-r[1])*s}" fill="${fill}"/>`;
 let svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="800" viewBox="0 0 1000 800"><rect width="1000" height="800" fill="#f7f3e9"/><g font-family="Arial,sans-serif" fill="#243737"><text x="55" y="48" font-size="30" font-weight="bold">${names[size]} · план помещений</text><text x="55" y="81" font-size="19">${w} × ${d} м внутри · стены и проходы · мебель позже</text>`;
 svg+=rectangle([-w/2,-d/2,w/2,d/2],'#ffffff');
 svg+=rectangle(bank.layout.vault.rect,'#d9e7e6');
 svg+=`<rect x="${x0}" y="${z0}" width="${w*s}" height="${d*s}" fill="none" stroke="#465c5b" stroke-width="7"/>`;
 for(const wall of bank.layout.wallRects)svg+=rectangle(wall.rect,wall.name.startsWith('Bank_Vault')?'#465c5b':'#8c826d');
 for(const room of bank.layout.roomLabels){
  const lines=room.label==='Доступ к хранилищу'?['Доступ к','хранилищу']:room.label==='Кабинет / архив'?['Кабинет /','архив']:room.label==='Комната отдыха'?['Комната','отдыха']:[room.label];
  svg+=`<text text-anchor="middle" font-size="17" x="${x(room.center[0])}" y="${z(room.center[2])-8*(lines.length-1)}">${lines.map((line,i)=>`<tspan x="${x(room.center[0])}" dy="${i?21:0}">${line}</tspan>`).join('')}</text>`;
 }
 svg+=`<path d="M${x(-1.41)},${z(d/2)} H${x(1.41)}" stroke="#ffffff" stroke-width="9"/><text x="500" y="${z(d/2)+35}" text-anchor="middle" font-size="20">Вход с улицы · дверь E</text><text x="55" y="770" font-size="16">Зонирование по world; хранилище встроено в заднюю часть банка и связано обычным проходом.</text></g></svg>`;
 fs.writeFileSync(new URL('../../../../docs/city-rebuild/bank_'+size+'_plan.svg',dir),svg);
}
console.log('Saved three bank floor plans from the actual authored wall rectangles.');
