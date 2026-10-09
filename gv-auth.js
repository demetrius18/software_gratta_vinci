(async function(){
'use strict';
const status=document.createElement('div');
status.textContent='Verifica accesso e sede in corso…';
status.style.cssText='position:fixed;inset:0;background:#f7f8fa;z-index:99999;display:grid;place-items:center;font:600 17px system-ui;color:#24382b';
document.body.appendChild(status);
try{
 if(!window.supabase||!window.GV_CONFIG)throw Error('Librerie cloud non disponibili');
 const client=window.supabase.createClient(GV_CONFIG.url,GV_CONFIG.key);
 const {data:{user},error}=await client.auth.getUser();
 if(error||!user){location.replace('login.html');return;}
 const {data:membership,error:me}=await client.from('gv_utenti_sedi').select('sede_id,ruolo').eq('user_id',user.id);
 if(me)throw me;
 if(!membership?.length){location.replace('login.html?error=permessi');return;}
 const wanted=sessionStorage.getItem('gv_selected_sede');
 const allowed=membership.find(x=>String(x.sede_id)===wanted);
 if(!allowed){location.replace('login.html');return;}
 const {data:sede,error:se}=await client.from('gv_sedi').select('*').eq('id',allowed.sede_id).single();
 if(se)throw se;
 window.GV_AUTH={client,user,sede,ruolo:allowed.ruolo};
 const admin=String(allowed.ruolo).toLowerCase()==="admin";
 for(const id of ["gvDirezioneLink","gvDirezioneSeparator"]){const el=document.getElementById(id);if(el)el.hidden=!admin;}
 const label=document.getElementById('gvSedeLabel');if(label)label.textContent='Sede: '+(sede.nome||sede.name||sede.id);
 const script=document.createElement('script');script.src='app.js?v=6a7e6bb0';script.onload=()=>status.remove();script.onerror=()=>{status.textContent='Impossibile caricare app.js';};document.body.appendChild(script);
}catch(e){status.textContent='Accesso non riuscito: '+(e.message||e);}
})();
