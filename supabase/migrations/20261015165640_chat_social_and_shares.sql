-- Add social posts without changing existing chat data or permissions.
create table public.chat_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.qing_profiles(id) on delete cascade,
 body text not null default '' check(char_length(body)<=2000),
 visibility text not null default 'friends' check(visibility in ('friends','public')),
 image_paths text[] not null default '{}' check(cardinality(image_paths)<=4),
 repost_of uuid references public.chat_posts(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(char_length(btrim(body))>0 or cardinality(image_paths)>0 or repost_of is not null),
 check(repost_of is null or repost_of<>id)
);
create index chat_posts_author_time on public.chat_posts(author_id,created_at desc,id desc);
create index chat_posts_public_time on public.chat_posts(created_at desc,id desc) where visibility='public';
create index chat_posts_repost on public.chat_posts(repost_of) where repost_of is not null;
create index chat_posts_images on public.chat_posts using gin(image_paths);
alter table public.chat_posts enable row level security;
revoke all on public.chat_posts from anon,authenticated;
grant select,delete on public.chat_posts to authenticated;
grant insert(id,author_id,body,visibility,image_paths,repost_of) on public.chat_posts to authenticated;
create policy chat_posts_read on public.chat_posts for select to authenticated using (
 visibility='public' or author_id=(select auth.uid()) or exists(select 1 from public.qing_friendships f where f.status='accepted' and ((f.requester=(select auth.uid()) and f.addressee=author_id) or (f.addressee=(select auth.uid()) and f.requester=author_id)))
);
create policy chat_posts_create on public.chat_posts for insert to authenticated with check(author_id=(select auth.uid()));
create policy chat_posts_remove on public.chat_posts for delete to authenticated using(author_id=(select auth.uid()));
create function public.chat_validate_post() returns trigger language plpgsql security invoker set search_path='' as $$
declare path text; source public.chat_posts;
begin
 if auth.uid() is null or new.author_id<>auth.uid() then raise exception 'Sign in required'; end if;
 if (select count(*) from public.chat_posts where author_id=auth.uid() and created_at>now()-interval '1 hour')>=30 then raise exception 'Please wait before posting again'; end if;
 foreach path in array new.image_paths loop
  if path not like new.author_id::text||'/'||new.id::text||'/%' or char_length(path)>200 then raise exception 'Invalid image path'; end if;
 end loop;
 if new.repost_of is not null then
  select * into source from public.chat_posts where id=new.repost_of;
  if not found or source.visibility<>'public' or source.repost_of is not null then raise exception 'Only original public posts can be reposted'; end if;
 end if;
 return new;
end $$;
revoke all on function public.chat_validate_post() from public,anon,authenticated;
create trigger chat_posts_validate before insert on public.chat_posts for each row execute function public.chat_validate_post();
create table public.chat_likes (
 post_id uuid not null references public.chat_posts(id) on delete cascade,
 user_id uuid not null references public.qing_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(post_id,user_id)
);
create index chat_likes_user on public.chat_likes(user_id);
create table public.chat_comments (
 id uuid primary key default gen_random_uuid(),post_id uuid not null references public.chat_posts(id) on delete cascade,
 author_id uuid not null references public.qing_profiles(id) on delete cascade,
 body text not null check(char_length(btrim(body)) between 1 and 500),created_at timestamptz not null default now()
);
create index chat_comments_post_time on public.chat_comments(post_id,created_at);
create index chat_comments_author on public.chat_comments(author_id);
create table public.chat_follows (
 follower_id uuid not null references public.qing_profiles(id) on delete cascade,
 followed_id uuid not null references public.qing_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(follower_id,followed_id),check(follower_id<>followed_id)
);
create index chat_follows_followed on public.chat_follows(followed_id);
create table public.chat_bookmarks (
 post_id uuid not null references public.chat_posts(id) on delete cascade,
 user_id uuid not null references public.qing_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(post_id,user_id)
);
create index chat_bookmarks_user on public.chat_bookmarks(user_id,created_at desc);
alter table public.chat_likes enable row level security;
alter table public.chat_comments enable row level security;
alter table public.chat_follows enable row level security;
alter table public.chat_bookmarks enable row level security;
revoke all on public.chat_likes,public.chat_comments,public.chat_follows,public.chat_bookmarks from anon,authenticated;
grant select,delete on public.chat_likes,public.chat_comments,public.chat_follows,public.chat_bookmarks to authenticated;
grant insert(post_id,user_id) on public.chat_likes,public.chat_bookmarks to authenticated;
grant insert(post_id,author_id,body) on public.chat_comments to authenticated;
grant insert(follower_id,followed_id) on public.chat_follows to authenticated;
create policy chat_likes_view on public.chat_likes for select to authenticated using(exists(select 1 from public.chat_posts p where p.id=post_id));
create policy chat_likes_add on public.chat_likes for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.chat_posts p where p.id=post_id));
create policy chat_likes_remove on public.chat_likes for delete to authenticated using(user_id=(select auth.uid()));
create policy chat_comments_view on public.chat_comments for select to authenticated using(exists(select 1 from public.chat_posts p where p.id=post_id));
create policy chat_comments_add on public.chat_comments for insert to authenticated with check(author_id=(select auth.uid()) and exists(select 1 from public.chat_posts p where p.id=post_id));
create policy chat_comments_remove on public.chat_comments for delete to authenticated using(author_id=(select auth.uid()) or exists(select 1 from public.chat_posts p where p.id=post_id and p.author_id=(select auth.uid())));
create policy chat_follows_view on public.chat_follows for select to authenticated using(follower_id=(select auth.uid()));
create policy chat_follows_add on public.chat_follows for insert to authenticated with check(follower_id=(select auth.uid()));
create policy chat_follows_remove on public.chat_follows for delete to authenticated using(follower_id=(select auth.uid()));
create policy chat_bookmarks_view on public.chat_bookmarks for select to authenticated using(user_id=(select auth.uid()));
create policy chat_bookmarks_add on public.chat_bookmarks for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.chat_posts p where p.id=post_id));
create policy chat_bookmarks_remove on public.chat_bookmarks for delete to authenticated using(user_id=(select auth.uid()));
create function public.chat_post_stats(p_ids uuid[]) returns table(post_id uuid,likes bigint,comments bigint,reposts bigint,liked boolean,saved boolean)
language sql stable security invoker set search_path='' as $$
 select p.id,
 (select count(*) from public.chat_likes l where l.post_id=p.id),
 (select count(*) from public.chat_comments c where c.post_id=p.id),
 (select count(*) from public.chat_posts r where r.repost_of=p.id),
 exists(select 1 from public.chat_likes l where l.post_id=p.id and l.user_id=(select auth.uid())),
 exists(select 1 from public.chat_bookmarks b where b.post_id=p.id and b.user_id=(select auth.uid()))
 from public.chat_posts p where p.id=any(p_ids) and cardinality(p_ids)<=50;
$$;
revoke all on function public.chat_post_stats(uuid[]) from public,anon;
grant execute on function public.chat_post_stats(uuid[]) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-post-images','chat-post-images',false,5242880,array['image/png','image/jpeg','image/webp','image/gif']);
create policy chat_post_images_view on storage.objects for select to authenticated using(bucket_id='chat-post-images' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.chat_posts p where name=any(p.image_paths))));
create policy chat_post_images_upload on storage.objects for insert to authenticated with check(bucket_id='chat-post-images' and (storage.foldername(name))[1]=(select auth.uid())::text and cardinality(storage.foldername(name))=2);
create policy chat_post_images_delete_unused on storage.objects for delete to authenticated using(bucket_id='chat-post-images' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.chat_posts p where name=any(p.image_paths)));
-- Sharing is explicit: links expose only a selected snapshot, never a live conversation.
create table public.chat_shares (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.qing_profiles(id) on delete cascade,
 title text not null default '一段聊天记录' check(char_length(btrim(title)) between 1 and 80),
 message_ids bigint[] not null check(cardinality(message_ids) between 1 and 30),
 include_names boolean not null default false,snapshot jsonb not null,
 expires_at timestamptz not null default now()+interval '7 days',revoked boolean not null default false,
 created_at timestamptz not null default now()
);
create index chat_shares_owner on public.chat_shares(owner_id,created_at desc);
alter table public.chat_shares enable row level security;
revoke all on public.chat_shares from anon,authenticated;
grant select on public.chat_shares to authenticated;
grant insert(owner_id,title,message_ids,include_names,expires_at),update(revoked) on public.chat_shares to authenticated;
create policy chat_shares_owner_view on public.chat_shares for select to authenticated using(owner_id=(select auth.uid()));
create policy chat_shares_owner_create on public.chat_shares for insert to authenticated with check(owner_id=(select auth.uid()));
create policy chat_shares_owner_revoke on public.chat_shares for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()) and revoked=true);
create function public.chat_snapshot_share() returns trigger language plpgsql security invoker set search_path='' as $$
declare selected_count integer; conversations integer;
begin
 if auth.uid() is null or new.owner_id<>auth.uid() then raise exception 'Sign in required'; end if;
 if new.expires_at<=now() or new.expires_at>now()+interval '30 days 1 minute' then raise exception 'Invalid expiry'; end if;
 if (select count(*) from public.chat_shares where owner_id=auth.uid() and created_at>now()-interval '1 day')>=100 then raise exception 'Daily share limit reached'; end if;
 select count(*),count(distinct friendship_id) into selected_count,conversations from public.qing_messages where id=any(new.message_ids);
 if selected_count<>cardinality(new.message_ids) or conversations<>1 then raise exception 'Select readable messages from one conversation'; end if;
 select jsonb_agg(jsonb_build_object('sender',case when new.include_names then p.nickname when m.sender_id=new.owner_id then '我' else '对方' end,'body',m.body,'image_path',m.image_path,'created_at',m.created_at) order by m.id)
 into new.snapshot from public.qing_messages m join public.qing_profiles p on p.id=m.sender_id where m.id=any(new.message_ids);
 return new;
end $$;
revoke all on function public.chat_snapshot_share() from public,anon,authenticated;
create trigger chat_shares_snapshot before insert on public.chat_shares for each row execute function public.chat_snapshot_share();
alter publication supabase_realtime add table public.chat_posts,public.chat_likes,public.chat_comments,public.chat_follows,public.chat_bookmarks;
