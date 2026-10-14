import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_KEY } from '../src/config.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const run=Date.now().toString(36);
const password=crypto.randomUUID()+'aA!';
const accounts=[];
const clients=[];
function ok(r){assert.equal(r.error,null,JSON.stringify(r.error));return r.data}
const existing=fs.existsSync('.test-accounts.json')?JSON.parse(fs.readFileSync('.test-accounts.json')):[];
if(!existing.length){
 for(let i=0;i<3;i++){
  const client=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
  const email=`qingchat-test-${run}-${i}@example.com`;
  const data=ok(await client.auth.signUp({email,password}));
  assert(data.session,'Test project must allow automatic confirmation for test accounts');
  const account={email,password,id:data.user.id};existing.push(account);
  fs.writeFileSync('.test-accounts.json',JSON.stringify(existing),{mode:0o600});
  ok(await client.from('qing_profiles').insert({id:account.id,username:`test_${run}_${i}`,nickname:`测试${i}`,color:'#82b99b'}));
  await client.auth.signOut();
 }
}
for(const account of existing){
 const c=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
 ok(await c.auth.signInWithPassword({email:account.email,password:account.password}));
 accounts.push(account);clients.push(c);
}
const [a,b,c]=clients,[ua,ub,uc]=accounts;
let friend=ok(await a.from('qing_friendships').select('*').eq('requester',ua.id).eq('addressee',ub.id).maybeSingle());
let r;
if(!friend){
 friend=ok(await a.from('qing_friendships').insert({requester:ua.id,addressee:ub.id}).select().single());
 r=await a.from('qing_messages').insert({friendship_id:friend.id,sender_id:ua.id,body:'before acceptance',client_id:crypto.randomUUID()});assert(r.error,'Cannot message before acceptance');
 r=await a.from('qing_friendships').update({status:'accepted'}).eq('id',friend.id).select();assert(r.error||r.data.length===0,'Requester cannot self-accept');
 ok(await b.from('qing_friendships').update({status:'accepted'}).eq('id',friend.id).select().single());
}
const message=ok(await a.from('qing_messages').insert({friendship_id:friend.id,sender_id:ua.id,body:'真实消息测试 👋',client_id:crypto.randomUUID()}).select().single());
assert.equal(ok(await b.from('qing_messages').select('*').eq('friendship_id',friend.id)).length>0,true);
assert.equal(ok(await c.from('qing_messages').select('*').eq('friendship_id',friend.id)).length,0);
r=await c.from('qing_messages').insert({friendship_id:friend.id,sender_id:uc.id,body:'intrusion',client_id:crypto.randomUUID()});assert(r.error,'Outsider cannot send');
r=await b.from('qing_messages').insert({friendship_id:friend.id,sender_id:ua.id,body:'forged',client_id:crypto.randomUUID()});assert(r.error,'Cannot forge sender');
r=await b.from('qing_profiles').update({nickname:'hijacked'}).eq('id',ua.id).select();assert(r.error||r.data.length===0,'Cannot update another profile');
r=await b.from('qing_friendships').update({requester:uc.id}).eq('id',friend.id);assert(r.error,'Cannot change friendship owner');
const anon=createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:false}});r=await anon.from('qing_messages').select('*');assert(r.error||r.data.length===0,'Anonymous cannot read messages');
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2l8AAAAASUVORK5CYII=','base64');
const path=`${friend.id}/${ua.id}/${crypto.randomUUID()}.png`;
ok(await a.storage.from('qingchat-images').upload(path,png,{contentType:'image/png'}));
ok(await b.storage.from('qingchat-images').createSignedUrl(path,60));
r=await c.storage.from('qingchat-images').createSignedUrl(path,60);assert(r.error,'Outsider cannot access images');
r=await c.storage.from('qingchat-images').upload(`${friend.id}/${uc.id}/test.png`,png,{contentType:'image/png'});assert(r.error,'Outsider cannot upload images');
accounts[0].imagePath=path;accounts[0].friendshipId=friend.id;fs.writeFileSync('.test-accounts.json',JSON.stringify(accounts),{mode:0o600});
r=await b.rpc('qing_mark_read',{p_friendship:friend.id,p_last_id:message.id});ok(r);const read=ok(await a.from('qing_reads').select('*').eq('user_id',ub.id).eq('friendship_id',friend.id).single());assert.equal(read.last_read_id,message.id);ok(await b.rpc('qing_mark_read',{p_friendship:friend.id,p_last_id:0}));assert.equal(ok(await a.from('qing_reads').select('*').eq('user_id',ub.id).eq('friendship_id',friend.id).single()).last_read_id,message.id);r=await c.rpc('qing_mark_read',{p_friendship:friend.id,p_last_id:message.id});assert(r.error,'Outsider cannot mark read');console.log('PASS read receipts and monotonic cross-device updates');
await Promise.all(clients.map(async c=>{await c.removeAllChannels();await c.auth.signOut()}));
console.log('PASS history, sender protection, private images, outsider and anonymous isolation');
