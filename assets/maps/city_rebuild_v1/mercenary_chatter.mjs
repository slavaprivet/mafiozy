/** Local, bounded squad chatter. Authored text; optional system Russian TTS, no downloaded voices. */
export const MERCENARY_CHATTER_LINES=Object.freeze({
 hero:{follow:['Все ко мне!','За мной, ребята!','Держимся вместе!','Собрались, идём!'],rally:['Все сюда!','Занять эту точку!','Собраться здесь!','Сюда, держим место!']},
 common:{
  greeting:['Слушаю, босс.','Есть дело? Я рядом.','Всё спокойно. Что нужно?','На месте, босс.','Какой план?','Да, босс?','Далеко не ухожу.','Готовы продолжать?'],
  hire:['В деле, босс.','Работу сделаем.','На меня можно рассчитывать.','Теперь держимся вместе.'],
  ack:['Принято, босс.','Беру на себя.','Уже иду.','Будет сделано.','Вижу, разберусь.'],
  queued:['После этого займусь следующим.','Принято, это следующим.','Сделаю всё по порядку.'],
  done:['Готово, босс.','Дело сделано.','Можно двигаться дальше.','Здесь всё готово.'],
  failed:['Не получается пройти. Нужен другой подход.','Тут не подобраться, босс.','Проход закрыт. Ищу другой путь.'],
  hit:['Задело!','Ещё держусь!','Мне нужно укрытие!','Держусь, продолжаю!'],
  victory:['Угроза снята.','Чисто. Не расслабляемся.','За спиной спокойно.','Смотрим по сторонам.']
 },
 medic:{
  greeting:['Всё цело, босс?','Помощь нужна или просто проверяете?','Аптечка при мне. Слушаю.','Покажите, если где задело.','На ногах держитесь? Уже хорошо.','За вашим здоровьем присмотрю.'],
  banter:['Угадайте, кто потом будет вас зашивать.','Кто полезет первым — тому первую перевязку.','Ребята, лишних дырок в костюмах не надо.','За целые головы премия не положена?','Поберегите кулаки. Запасных у меня нет.','После дела всем бы выспаться. По моей части совет.'],
  idle:['Аптечка на месте. Лучше пусть не пригодится.','Босс, живыми возвращаться выгоднее.','Перевязки хватит на всех.','Держитесь рядом, если зацепит.','Пульс ровный. Пока всё спокойно.','Я за вашими спинами, не забывайте.'],
  walk:['Не растягивайте строй, я вас прикрою.','Иду следом. Берегите головы.','От меня далеко не уходите.','Все на ногах? Тогда идём.'],
  combat:['Не высовывайтесь, я рядом!','Прикройте, если кто упадёт!','Работаем аккуратно, ребята!','Держитесь, я вас вытащу!'],
  ack:['Сейчас окажу помощь.','Вижу раненого. Иду.','Прикройте подход к раненому.','Доберусь и поставлю на ноги.'],
  done:['Дышит. Поставили на ноги.','Жить будет. Дальше осторожнее.','Снова в строю, босс.','Помощь оказана.']
 },
 bruiser:{
  greeting:['Кому пожать руку покрепче, босс?','Я здесь. Скажите только слово.','Нужен разговор с пристрастием?','Всё под контролем, босс.','Кулаки целы, настроение рабочее.','Вас никто не обидел?'],
  banter:['Кто последний за дверью — тот её и закрывает.','Не спорьте. Тяжёлое всё равно нести мне.','У вас инструменты, а у меня убедительность.','За мой костюм не переживайте. Старый.','Давайте тихо. Шуметь я всегда успею.','После дела поедим? Работа голодная.'],
  idle:['Кулаки чешутся, но приказа подожду.','Босс, кому объяснить правила?','Сначала разговор. Если поймут.','Дверь крепкая? Посмотрим.','Я рядом. Пусть только сунутся.','Лишнего шума не будет. Если не попросят.'],
  walk:['Дорогу боссу.','Следом, никого не потеряем.','Тыл на мне.','Иду. Далеко не убегайте.'],
  combat:['Надаю всем по морде!','Сейчас поговорим поближе!','Не на тех нарвались!','К боссу не подойдёте!','Расступись, разберусь!'],
  ack:['Сейчас объясню доходчиво.','Это моя работа.','Дайте немного места.','Одного хорошего удара хватит.'],
  done:['Теперь проход свободен.','Вопрос закрыт.','Крепкая была. Недостаточно.','Готово. Кого ещё убедить?']
 },
 safecracker:{
  greeting:['Какой замок мешает, босс?','Инструменты готовы. Слушаю.','Есть что-нибудь интересное под замком?','Руки целы. Можно работать.','Дайте минуту тишины — и всё откроется.','Слушаю внимательно, босс.'],
  banter:['Ребята, сейф сначала мне покажите. Потом взрывайте.','Грубой силой можно. Но зачем портить хороший механизм?','Кто шумит над ухом, тот добычу последним считает.','С закрытой дверью разговор у меня короткий.','Надеюсь, внутри больше денег, чем пыли.','У каждого свой талант. Не трясите мой чемодан.'],
  idle:['У любого замка есть слабое место.','Тихая работа любит терпение.','В сейфах обычно интереснее, чем снаружи.','Главное — не дёргать раньше времени.','Инструменты проверены.','Хороший замок сразу видно.'],
  walk:['Иду. Инструменты со мной.','Без лишнего шума, босс.','Держу темп.','Не отстаю, всё при мне.'],
  combat:['Прикройте, мои руки ещё пригодятся!','За инструментами не прячусь!','Работаем чисто!','Не дадим себя прижать!'],
  ack:['Посмотрим, что у него внутри.','Разберусь с замком.','Прикройте. Тут нужна точность.','Подойду и займусь механизмом.'],
  done:['Замок сдался.','Открыто. Посмотрим на добычу.','Тихо и без лишних дырок.','Сейф наш, босс.']
 },
 engineer:{
  greeting:['Нужен проход, босс?','Горелка готова. Куда идти?','Что отключаем на этот раз?','Инструмент в порядке. Слушаю.','Покажите место — разберусь.','Свет пока оставить?'],
  banter:['Провода руками не трогать. Это для всех правило.','Кто опять наступил на шланг? Осторожнее.','Вам бы всё выбить. А можно аккуратно прорезать.','Если свет погаснет, не паникуйте. Это я.','В темноте меньше свидетелей. Только сами не споткнитесь.','После моей работы проход останется всем.'],
  idle:['Сетка, проводка — всё поправимо.','Проверю инструмент, пока тихо.','Электричество шуток не любит.','Лишний свет нам ни к чему.','Проход найдём. Или сделаем.','Баллон полный, инструмент готов.'],
  walk:['Горелка со мной. Иду.','Слежу за проходами.','Не отстаю, босс.','Весь инструмент на месте.'],
  combat:['Не дайте им зайти сбоку!','Прикрывайте, проход за мной!','Вот сейчас без фокусов!','Держу свою сторону!'],
  ack:['Прикройте, сейчас сделаю.','Подойду к нужному месту.','Вижу, где работать.','Это по моей части.'],
  done:['Путь открыт.','Готово, можно проходить.','Порядок. Инструмент убираю.','Работа закончена, босс.']
 },
 demolitions:{
  greeting:['Где нужен большой шум, босс?','Заряды на месте. Слушаю.','Работа найдётся — только покажите цель.','Взрыватель проверен. Жду приказа.','Рядом с целью потом не стойте.','Сначала выберем отход, босс.'],
  banter:['Ребята, рядом с моим чемоданом не курят.','Считайте до десяти подальше от машины.','Шум будет короткий. Обсуждений потом много.','Если я бегу — не спрашивайте, бегите тоже.','Кому-то отмычка, а мне надёжнее заряд.','После хлопка сразу не выглядывайте.'],
  idle:['С зарядом спешка ни к чему.','Сначала отход, потом большой шум.','Босс, держитесь подальше от моей работы.','Взрыватель проверен. Всё в порядке.','Здесь бы аккуратно, без лишних сюрпризов.','Заряд готов. Жду подходящую цель.'],
  walk:['Иду. Осторожнее с грузом.','Держусь рядом, босс.','Путь отхода тоже смотрю.','Не толпимся. Всем места хватит.'],
  combat:['Всех поджарю!','Сейчас им станет жарко!','Не лезьте под огонь!','Отсюда живыми уйдём!','Прикройте мой фланг!'],
  ack:['Заложу заряд и отойду.','Вижу цель. Готовлюсь.','Мне нужен свободный подход.','Сделаю. Только рядом не стойте.'],
  armed:['Заряд стоит! Всем отойти!','Заложено! Держитесь дальше!','Отходим, сейчас рванёт!','Заряд готов. Освободить место!'],
  done:['Вот теперь готово.','Цель разобрана, босс.','Больше не мешает.','Можно выдвигаться.']
 },
 tasks:{
  revive:['Держись. Сейчас помогу.','Спокойно, я здесь.','Прикройте меня, поднимаю бойца.','Сейчас снова будешь на ногах.'],
  intimidate:['Давай поговорим по-хорошему.','Ты босса услышал?','Советую не спорить.','Объяснять дважды не люблю.'],
  breach_door:['Отойдите от двери.','Сейчас будет открыто.','Один удар — и заходим.','Дверь держится на честном слове.'],
  unlock_safe:['Слушаю механизм. Не шумите.','Ещё немного, замок поддаётся.','Прикройте, работаю с сейфом.','Спокойно. Здесь нужна точность.'],
  unlock_door:['Разберусь с этим замком.','Без шума будет быстрее.','Секунду. Почти поддаётся.','Прикройте, пока открываю.'],
  cut_fence:['Режу. Не подходите к огню.','Сейчас сделаю проход.','Осталось немного сетки.','Прикройте, работаю горелкой.'],
  disable_power:['Сниму питание. Руками не трогать.','Сейчас здесь станет темнее.','Отключаю нужную линию.','Работаю со щитком. Прикройте.'],
  plant_bomb:['Ставлю заряд. Не мешайте.','Закреплю и отойду.','Тише. Работаю со взрывателем.','Путь отхода держите свободным.']
 }
});
const normalize=kind=>['shoot','alert','aim'].includes(kind)?'combat':kind;

export function createMercenaryChatterDirector({clock=()=>Date.now(),random=Math.random,onLine=()=>{},onClear=()=>{},isHidden=()=>false,isSpeaking=()=>false}={}){
 const bags=new Map(),lastBySpeaker=new Map(),pending=[],stats={spoken:0,stale:0,budget:0,distant:0,duplicate:0,queued:0};let active=null,lastSequence=0,nextNpcAt=0,nextIdleAt=0,lastHeroAt=-Infinity,disposed=false;
 function choose(key,pool,first=false){let bag=bags.get(key);if(!bag||!bag.left.length){const left=Array.from({length:pool.length},(_,i)=>i);for(let i=left.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[left[i],left[j]]=[left[j],left[i]];}if(bag&&left.at(-1)===bag.last&&left.length>1)[left[0],left[left.length-1]]=[left.at(-1),left[0]];if(!bag&&first){const i=left.indexOf(0);[left[i],left[left.length-1]]=[left.at(-1),left[i]];}bag={left,last:bag?.last??-1};bags.set(key,bag);}bag.last=bag.left.pop();return pool[bag.last];}
 function clear(){if(active){active=null;onClear();}}
 function accept(event,deferred=false){
  const time=clock();if(disposed||!event||isHidden())return false;
  if(!Number.isFinite(event.at)||time-event.at>(deferred?4500:1500)||event.at-time>1000){stats.stale++;return false;}
  if(!deferred){if(!Number.isSafeInteger(event.seq)||event.seq<=lastSequence){stats.duplicate++;return false;}lastSequence=event.seq;}
  const hero=event.speakerId==='player',kind=normalize(event.kind),idle=kind==='idle'||kind==='walk';
  if(!hero&&(event.alive===false||event.distance>(idle?12:26))){stats.distant++;return false;}
  if((idle||kind==='greeting')&&(event.anyCombat||event.busy||idle&&time<nextIdleAt))return false;
  if(isSpeaking()){if(idle||deferred){stats.budget++;return false;}if(pending.length===2)pending.shift();pending.push(event);stats.queued++;return true;}
  if(hero){if(time-lastHeroAt<1700){stats.budget++;return false;}}
  else if(time<nextNpcAt||active&&time<active.until||time-(lastBySpeaker.get(event.speakerId)??-Infinity)<8000){stats.budget++;return false;}
  let pool,key;
  if(hero){pool=MERCENARY_CHATTER_LINES.hero[kind];key='hero:'+kind;}
  else if(kind==='task'){pool=MERCENARY_CHATTER_LINES.tasks[event.action];key='task:'+event.action;}
  else{const role=MERCENARY_CHATTER_LINES[event.profession],category=kind==='idle'&&event.peerCount>0&&random()<.34?'banter':kind;pool=role?.[category]||MERCENARY_CHATTER_LINES.common[category];key=event.profession+':'+category;}
  if(!pool?.length)return false;
  const text=choose(key,pool,hero),duration=Math.max(2200,Math.min(5000,text.length*64));clear();
  active={...event,text,kind,until:time+duration};lastBySpeaker.set(event.speakerId,time);nextNpcAt=time+Math.max(6000,duration+1200);if(hero)lastHeroAt=time;if(idle)nextIdleAt=time+22000;
  stats.spoken++;onLine(active);return true;
 }
 return {accept,clear,clearPending(){pending.length=0;},update(){if(isHidden()){pending.length=0;clear();return;}if(active&&clock()>=active.until&&!isSpeaking())clear();if(!isSpeaking()&&pending.length){const event=pending.shift();accept(event,true);}},get active(){return active;},stats:()=>({...stats,pending:pending.length}),dispose(){disposed=true;pending.length=0;clear();bags.clear();lastBySpeaker.clear();}};
}

function voiceGender(voice){const explicit=String(voice?.gender||'').toLowerCase();if(['female','male'].includes(explicit))return explicit;const name=String(voice?.name||'').toLowerCase();if(/(?:irina|elena|milena|katya|anna|alena|svetlana|female|женск|ирина|елена|милена|катя|анна|алёна|светлана)/.test(name))return 'female';if(/(?:pavel|dmitri|dmitry|yuri|maxim|male|мужск|павел|дмитрий|юрий|максим)/.test(name))return 'male';return null;}
export function selectMercenaryVoice(voices,gender){const desired=Number(gender)===1?'female':'male',matching=voices.filter(v=>voiceGender(v)===desired);return matching.find(v=>v.localService)||matching[0]||voices.find(v=>v.localService)||voices[0];}

export function createMercenarySpeech({window:win=globalThis.window,document:doc=globalThis.document,getVolume=()=>.5}={}){
 const synth=win?.speechSynthesis,Utterance=win?.SpeechSynthesisUtterance;let unlocked=false,owned=null,disposed=false;
 const stats={played:0,unavailable:0,locked:0,muted:0,busy:0,lastVoice:null,genderMatched:false};
 function stop(){if(owned){try{synth?.cancel();}catch{}owned=null;}}
 const unlock=e=>{if(e?.isTrusted)unlocked=true;};doc?.addEventListener?.('keydown',unlock,true);doc?.addEventListener?.('pointerdown',unlock,true);
 function speak(line){
  if(disposed||doc?.hidden)return false;const volume=Math.max(0,Math.min(1,Number(getVolume())||0));if(!volume){stats.muted++;return false;}if(!unlocked){stats.locked++;return false;}
  if(!synth||!Utterance){stats.unavailable++;return false;}
  if(owned||synth.speaking||synth.pending){stats.busy++;return false;}
  const voices=synth.getVoices().filter(v=>/^ru(?:-|_)/i.test(v.lang)||String(v.lang).toLowerCase()==='ru');if(!voices.length){stats.unavailable++;return false;}
  const utterance=new Utterance(line.text);utterance.lang='ru-RU';utterance.voice=selectMercenaryVoice(voices,line.gender);stats.lastVoice=utterance.voice.name||null;stats.genderMatched=voiceGender(utterance.voice)===(Number(line.gender)===1?'female':'male');utterance.volume=volume;utterance.rate=line.speakerId==='player'?.99:.97;utterance.pitch=1;
  utterance.onend=utterance.onerror=()=>{if(owned===utterance)owned=null;};owned=utterance;
  try{synth.speak(utterance);stats.played++;return true;}catch{owned=null;stats.unavailable++;return false;}
 }
 return {speak,stop,get speaking(){return !!owned;},update(){if(doc?.hidden||!(Number(getVolume())>0))stop();},stats:()=>({...stats}),dispose(){disposed=true;stop();doc?.removeEventListener?.('keydown',unlock,true);doc?.removeEventListener?.('pointerdown',unlock,true);}};
}

export function createMercenaryChatter({host,window:win=globalThis.window,document:doc=globalThis.document,clock=()=>Date.now(),random=Math.random,onCaption=null}={}){
 if(!host?.bindChatter||!doc?.createElement)return {update(){},dispose(){},stats:()=>({unavailable:true})};
 const caption=onCaption?null:doc.createElement('div');if(caption){caption.dataset.walkHud='mercenary-chatter';caption.dataset.mercenaryChatter='true';caption.setAttribute('role','status');caption.style.cssText='position:fixed;left:50%;bottom:118px;transform:translateX(-50%);max-width:min(420px,75vw);padding:9px 15px;background:rgba(15,24,23,.88);border:1px solid rgba(190,211,194,.45);border-radius:9px;color:#f1f2e7;font:600 15px/1.35 system-ui,sans-serif;text-align:center;pointer-events:none;z-index:36;display:none;';doc.body.append(caption);}
 const speech=createMercenarySpeech({window:win,document:doc,getVolume:()=>host.getChatterSettings?.().volume??((Number(win?.MafioziSettings?.volume)||0)/100)});
 const director=createMercenaryChatterDirector({clock,random,isHidden:()=>doc.hidden===true,isSpeaking:()=>speech.speaking,onLine:line=>{onCaption?.(line);if(caption){caption.textContent=(line.name?line.name+': ':'')+line.text;caption.style.display='block';}speech.speak(line);},onClear:()=>{onCaption?.(null);if(caption){caption.style.display='none';caption.textContent='';}}});
 const unbind=host.bindChatter(event=>director.accept(event));let nextUpdate=0,disposed=false;
 return {update(){if(disposed)return;const now=clock();if(now<nextUpdate)return;nextUpdate=now+250;speech.update();if(!(Number(host.getChatterSettings?.().volume??((Number(win?.MafioziSettings?.volume)||0)/100))>0))director.clearPending();director.update();const current=director.active;if(current&&current.speakerId!=='player'){const member=host.getMember(current.speakerId);if(!member||member.hp<=0||member.dead){speech.stop();director.clearPending();director.clear();}}},get active(){return director.active;},stats:()=>({...director.stats(),audio:speech.stats()}),dispose(){if(disposed)return;disposed=true;unbind?.();director.dispose();speech.dispose();caption?.remove();}};
}
