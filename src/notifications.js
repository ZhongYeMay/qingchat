const KEY='chat-system-notifications';
export function createNotifications({toast,onOpenChat}){
 let prefs;try{prefs=JSON.parse(localStorage.getItem(KEY)||'{}')}catch{prefs={}}
 if(!prefs||typeof prefs!=='object')prefs={};
 let registration=null;const shown=new Map();
 const supported='Notification'in window&&'serviceWorker'in navigator&&isSecureContext;
 const button=document.getElementById('enable-notifications'),status=document.getElementById('notification-status'),preview=document.getElementById('notification-preview'),test=document.getElementById('test-notification');
 preview.selected=prefs.preview!==false;
 function save(){try{localStorage.setItem(KEY,JSON.stringify(prefs))}catch{toast('通知偏好未能保存')}}
 function render(){const permission=supported?Notification.permission:'unsupported';status.textContent=!supported?'此浏览器暂不支持系统通知。iPhone/iPad 请先添加到主屏幕。':permission==='denied'?'通知已被浏览器阻止，请在网站权限中允许通知。':prefs.enabled&&permission==='granted'?'已开启：网页保持打开时，在后台提醒新消息。':'开启后，网页在后台时也会显示系统通知。';button.textContent=prefs.enabled&&permission==='granted'?'关闭系统通知':'开启系统通知';button.disabled=!supported||permission==='denied';test.disabled=!prefs.enabled||permission!=='granted';}
 async function register(){if(!supported)return null;if(registration)return registration;try{await navigator.serviceWorker.register(new URL('sw.js',document.baseURI),{scope:new URL('./',document.baseURI).pathname});registration=await Promise.race([navigator.serviceWorker.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Service worker timeout')),8000))]);return registration}catch{return null}}
 async function show(title,body,friendshipId,tag){if(!supported||Notification.permission!=='granted'||!prefs.enabled)return false;const data={friendshipId,url:new URL('./',document.baseURI).href};try{const r=await register();if(r){await r.showNotification(title,{body,tag,icon:new URL('assets/icon-192.png',document.baseURI).href,badge:new URL('assets/icon-192.png',document.baseURI).href,data});return true}const n=new Notification(title,{body,tag,data});n.onclick=()=>{window.focus();if(friendshipId)onOpenChat(friendshipId);n.close()};return true}catch{toast('浏览器未能显示通知，请检查系统和网站通知权限');return false}}
 button.onclick=async()=>{if(prefs.enabled&&Notification.permission==='granted'){prefs.enabled=false;save();render();return}const result=await Notification.requestPermission();prefs.enabled=result==='granted';save();render();if(prefs.enabled){await register();toast('系统通知已开启')}};
 preview.onchange=()=>{prefs.preview=preview.selected;save()};test.onclick=()=>show('Chat 通知已就绪','收到新消息时，会在这里提醒你。',null,'chat-test');
 navigator.serviceWorker?.addEventListener('message',e=>{if(e.data?.type==='OPEN_CHAT'&&typeof e.data.friendshipId==='string')onOpenChat(e.data.friendshipId)});
 render();if(supported)register();
 return {notify:async(friend)=>{const m=friend.last;if(!m||!prefs.enabled||!document.hidden||shown.get(friend.id)>=m.id)return;shown.set(friend.id,m.id);const body=prefs.preview===false?'你收到一条新消息':m.image_path?'[图片]':m.body.slice(0,120);const notify=()=>show(friend.profile?.nickname||'Chat 新消息',body,friend.id,'chat-'+friend.id);if(navigator.locks){await navigator.locks.request('chat-notification-'+friend.id+'-'+m.id,{ifAvailable:true},async lock=>{if(!lock)return;const k='chat-notified-'+friend.id;try{if(Number(localStorage.getItem(k))>=m.id)return;localStorage.setItem(k,String(m.id))}catch{}await notify()})}else await notify()},render,clear:()=>shown.clear()};
}
