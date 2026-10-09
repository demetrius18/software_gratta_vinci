(async()=>{
'use strict';
const $=id=>document.getElementById(id);
const client=supabase.createClient(GV_CONFIG.url,GV_CONFIG.key);
let sede=null, items=[], ready=false;
const money=n=>Number(n||0).toLocaleString('it-IT',{style:'currency',currency:'EUR'});
const say=(s,err=false)=>{$('log').textContent=s;$('log').className=err?'error':'ok'};
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function render(){
$('items').innerHTML=items.length?'<table><thead><tr><th>Biglietto</th><th>Prezzo</th><th>Giacenza</th><th></th></tr></thead><tbody>'+items.map((x,i)=>`<tr><td>${esc(x.nome)}</td><td>${money(x.prezzo)}</td><td>${x.giacenza}</td><td><button data-remove="${i}">Rimuovi</button></td></tr>`).join('')+'</tbody></table>':'<p class="muted">Nessun modello inserito.</p>';
$('save').disabled=!(ready&&items.length&&$('confirm').checked);
}
$('items').onclick=e=>{let b=e.target.closest('[data-remove]');if(b){items.splice(Number(b.dataset.remove),1);render()}};
$('confirm').onchange=render;
$('add').onclick=()=>{let nome=$('name').value.trim(),prezzo=Number($('price').value),giacenza=Number($('qty').value);
if(!nome||!Number.isFinite(prezzo)||prezzo<=0||!Number.isSafeInteger(giacenza)||giacenza<0){say('Inserisci nome, prezzo positivo e giacenza valida.',true);return}
if(items.some(x=>x.nome.toLocaleLowerCase('it')===nome.toLocaleLowerCase('it'))){say('Modello già presente.',true);return}
items.push({nome,prezzo,giacenza,colore:'#2E4A73',immagine:null});$('name').value='';render()};
$('clear').onclick=()=>{items=[];$('backup').value='';$('preview').textContent='Anteprima svuotata';render()};
$('backup').onchange=async e=>{
try{const file=e.target.files[0];if(!file)return;if(file.size>25*1024*1024)throw Error('File troppo grande (massimo 25 MB).');
const data=JSON.parse(await file.text());if(!Array.isArray(data.games))throw Error('Il JSON non contiene games.');
const names=new Set();let parsed=data.games.map(g=>{
const nome=String(g.nome||'').trim(),prezzo=Number(g.prezzo),giacenza=Number(g.giacenza);
if(!nome||!Number.isFinite(prezzo)||prezzo<=0||!Number.isSafeInteger(giacenza)||giacenza<0)throw Error('Modello non valido: '+nome);
if(names.has(nome.toLowerCase()))throw Error('Modello duplicato: '+nome);names.add(nome.toLowerCase());
return {nome,prezzo,giacenza,colore:typeof (g.colore||g.color)==='string'?(g.colore||g.color):'#2E4A73',immagine:typeof g.immagine==='string'?g.immagine:null};
});
items=parsed;if(data.fondoIniziale!=null&&Number.isFinite(Number(data.fondoIniziale)))$('fund').value=Number(data.fondoIniziale);
$('preview').textContent=`${items.length} modelli caricati. ${Array.isArray(data.operations)?data.operations.length:0} operazioni storiche NON saranno importate.`;
render();
}catch(err){say('Backup non valido: '+err.message,true)}
};
async function count(table){let {count,error}=await client.from(table).select('*',{head:true,count:'exact'}).eq('sede_id',sede.id);if(error)throw error;return count}
async function check(){
ready=false;render();
try{let [g,o,a]=await Promise.all(['gv_games','gv_operations','gv_archivio'].map(count));
$('counts').textContent=`Modelli: ${g} · Operazioni: ${o} · Archivio: ${a}`;
ready=g===0&&o===0&&a===0;
if(!ready)say('Questa sede contiene già dati: inizializzazione bloccata per evitare sovrascritture.',true);
else say('Sede vuota: puoi inizializzarla.');
render();
}catch(err){say('Impossibile verificare la sede: '+err.message,true)}
}
$('refresh').onclick=check;
$('save').onclick=async()=>{
if(!ready||!items.length||!$('confirm').checked)return;
$('save').disabled=true;
try{
await check();if(!ready)throw Error('La sede non è più vuota.');
let fondo=Number($('fund').value);if(!Number.isFinite(fondo)||fondo<0)throw Error('Fondo iniziale non valido.');
// Non modificare le operazioni: questa procedura configura solo il catalogo iniziale.
const rows=items.map((x,i)=>({...x,sede_id:sede.id,ordine:i}));
const {error}=await client.from('gv_games').insert(rows);if(error)throw error;
const {error:fe}=await client.from('gv_settings').upsert({sede_id:sede.id,key:'fondo_iniziale',value:String(fondo)},{onConflict:'sede_id,key'});
if(fe)throw Error('Catalogo inserito, ma fondo non salvato: '+fe.message+'. Non ripetere l’importazione: contatta Admin.');
say('Configurazione salvata. Apri il gestionale: i dati verranno sincronizzati da Supabase.');
ready=false;render();
}catch(err){say('Salvataggio non completato: '+err.message,true);await check()}
};
try{
const {data:{user},error}=await client.auth.getUser();if(error||!user){location.replace('login.html');return}
const wanted=sessionStorage.getItem('gv_selected_sede');
const {data:members,error:me}=await client.from('gv_utenti_sedi').select('sede_id,ruolo').eq('user_id',user.id);
if(me)throw me;const member=(members||[]).find(m=>m.sede_id===wanted);
if(!member||member.ruolo!=='admin'){document.body.replaceChildren(Object.assign(document.createElement('h2'),{textContent:'Accesso riservato agli amministratori'}));return}
const {data:s,error:se}=await client.from('gv_sedi').select('id,nome,codice').eq('id',wanted).single();if(se)throw se;sede=s;
$('identity').textContent=`${user.email} · Admin · ${s.nome||s.codice}`;
await check();
}catch(err){$('identity').textContent='Errore accesso: '+err.message;say('Configurazione non disponibile.',true)}
})();