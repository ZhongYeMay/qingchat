self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('notificationclick',event=>{
 event.notification.close();const id=event.notification.data?.friendshipId;
 event.waitUntil((async()=>{const url=new URL('./',self.registration.scope);if(typeof id==='string'&&/^[0-9a-f-]{36}$/i.test(id))url.searchParams.set('chat',id);const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});const client=windows.find(c=>c.url.startsWith(self.registration.scope));if(client){await client.focus();if(id)client.postMessage({type:'OPEN_CHAT',friendshipId:id})}else await self.clients.openWindow(url.href)})());
});
