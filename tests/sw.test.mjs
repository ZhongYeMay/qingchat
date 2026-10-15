import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const callbacks={},opened=[],messages=[];let focused=false;
const client={url:'https://zhongyemay.github.io/qingchat/',focus:async()=>{focused=true},postMessage:m=>messages.push(m)};
const self={addEventListener:(name,callback)=>callbacks[name]=callback,skipWaiting(){},registration:{scope:'https://zhongyemay.github.io/qingchat/'},clients:{claim(){},matchAll:async()=>[client],openWindow:async u=>opened.push(u)}};
vm.runInNewContext(fs.readFileSync('sw.js','utf8'),{self,URL});
const id='11111111-1111-4111-8111-111111111111';let pending;callbacks.notificationclick({notification:{close(){},data:{friendshipId:id}},waitUntil:p=>pending=p});await pending;assert(focused);assert.equal(messages[0].friendshipId,id);assert.equal(opened.length,0);
self.clients.matchAll=async()=>[];callbacks.notificationclick({notification:{close(){},data:{friendshipId:id}},waitUntil:p=>pending=p});await pending;assert.equal(new URL(opened[0]).origin,'https://zhongyemay.github.io');assert.equal(new URL(opened[0]).searchParams.get('chat'),id);
callbacks.notificationclick({notification:{close(){},data:{friendshipId:'https://evil.example/'}},waitUntil:p=>pending=p});await pending;assert.equal(new URL(opened[1]).searchParams.has('chat'),false);console.log('PASS notification click focuses the chat or opens a scoped same-origin URL');
