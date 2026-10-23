-- Preserve existing chat links; extend snapshots to original posts and custom cards.
alter table public.chat_shares
 add column kind text not null default 'chat' check(kind in ('chat','post')),
 add column source_post_id uuid references public.chat_posts(id) on delete cascade,
 add column description text not null default '' check(char_length(description)<=240),
 add column byline text not null default '' check(char_length(byline)<=40),
 add column accent text not null default '#6750a4' check(accent ~ '^#[0-9a-fA-F]{6}$'),
 add column cover_index integer not null default -1 check(cover_index between -1 and 29);
alter table public.chat_shares alter column message_ids set default '{}';
alter table public.chat_shares drop constraint chat_shares_message_ids_check;
alter table public.chat_shares add constraint chat_shares_source_check check(
 (kind='chat' and cardinality(message_ids) between 1 and 30 and source_post_id is null)
 or (kind='post' and cardinality(message_ids)=0 and source_post_id is not null));
create index chat_shares_source_post on public.chat_shares(source_post_id) where source_post_id is not null;
grant insert(kind,source_post_id,description,byline,accent,cover_index) on public.chat_shares to authenticated;
create or replace function public.chat_snapshot_share() returns trigger language plpgsql security invoker set search_path='' as $$
declare selected_count integer; conversations integer; post public.chat_posts; original public.chat_posts;
 item public.chat_posts; sender text; paths text[]; n integer;
begin
 if auth.uid() is null or new.owner_id<>auth.uid() then raise exception 'Sign in required'; end if;
 if new.expires_at<=now() or new.expires_at>now()+interval '30 days 1 minute' then raise exception 'Invalid expiry'; end if;
 if (select count(*) from public.chat_shares where owner_id=auth.uid() and created_at>now()-interval '1 day')>=100 then raise exception 'Daily share limit reached'; end if;
 if new.kind='chat' then
  select count(*),count(distinct friendship_id) into selected_count,conversations from public.qing_messages where id=any(new.message_ids);
  if selected_count<>cardinality(new.message_ids) or conversations<>1 then raise exception 'Select readable messages from one conversation'; end if;
  select jsonb_agg(jsonb_build_object('sender',case when new.include_names then p.nickname when m.sender_id=new.owner_id then '我' else '对方' end,'body',m.body,'image_path',m.image_path,'image_bucket','qingchat-images','created_at',m.created_at) order by m.id)
  into new.snapshot from public.qing_messages m join public.qing_profiles p on p.id=m.sender_id where m.id=any(new.message_ids);
 elsif new.kind='post' then
  select * into post from public.chat_posts where id=new.source_post_id;
  if not found or (post.visibility<>'public' and post.author_id<>auth.uid()) then raise exception 'Only share public posts or your own posts'; end if;
  new.snapshot='[]'::jsonb;
  -- A repost can include only the readable original public post, never comments.
  for item in select * from public.chat_posts where id=post.id or (id=post.repost_of and visibility='public') order by (id=post.id) desc loop
   select case when new.include_names then nickname else '动态作者' end into sender from public.qing_profiles where id=item.author_id;
   paths=item.image_paths;
   for n in 1..greatest(cardinality(paths),1) loop
    new.snapshot=new.snapshot||jsonb_build_array(jsonb_build_object('sender',sender,'body',case when n=1 then item.body else '' end,'image_path',paths[n],'image_bucket','chat-post-images','created_at',item.created_at));
   end loop;
  end loop;
 else raise exception 'Invalid share type';
 end if;
 if new.cover_index>=0 and (new.cover_index>=jsonb_array_length(new.snapshot) or coalesce(new.snapshot->new.cover_index->>'image_path','')='') then raise exception 'Select a shared image as the cover'; end if;
 return new;
end $$;
revoke all on function public.chat_snapshot_share() from public,anon,authenticated;
