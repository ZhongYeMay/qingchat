-- Qingchat tables are separate from other apps in this Supabase project.
create table public.qing_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{4,24}$'),
  nickname text not null check (char_length(btrim(nickname)) between 1 and 24),
  signature text not null default '' check (char_length(signature) <= 120),
  color text not null default '#82b99b' check (color in ('#82b99b','#97b8d0','#c5a4c8','#e0b78c','#9faecc','#b3bf89')),
  created_at timestamptz not null default now()
);
create table public.qing_friendships (
  id uuid primary key default gen_random_uuid(),
  requester uuid not null references public.qing_profiles(id) on delete cascade,
  addressee uuid not null references public.qing_profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  check (requester <> addressee)
);
create unique index qing_friendships_pair on public.qing_friendships (least(requester,addressee), greatest(requester,addressee));
create index qing_friendships_requester on public.qing_friendships(requester,status);
create index qing_friendships_addressee on public.qing_friendships(addressee,status);
create table public.qing_messages (
  id bigint generated always as identity primary key,
  friendship_id uuid not null references public.qing_friendships(id) on delete cascade,
  sender_id uuid not null references public.qing_profiles(id) on delete cascade,
  client_id uuid not null,
  body text not null default '' check (char_length(body) <= 4000),
  image_path text,
  created_at timestamptz not null default now(),
  unique(sender_id,client_id),
  check ((image_path is null and char_length(btrim(body)) > 0) or (image_path is not null and body = '')),
  check (image_path is null or (image_path like friendship_id::text || '/' || sender_id::text || '/%' and char_length(image_path) < 200))
);
create index qing_messages_conversation on public.qing_messages(friendship_id,id desc);
create table public.qing_reads (
  friendship_id uuid not null references public.qing_friendships(id) on delete cascade,
  user_id uuid not null references public.qing_profiles(id) on delete cascade,
  last_read_id bigint not null default 0 check (last_read_id >= 0),
  primary key(friendship_id,user_id)
);
create index qing_reads_user on public.qing_reads(user_id);
alter table public.qing_profiles enable row level security;
alter table public.qing_friendships enable row level security;
alter table public.qing_messages enable row level security;
alter table public.qing_reads enable row level security;
revoke all on public.qing_profiles,public.qing_friendships,public.qing_messages,public.qing_reads from anon,authenticated;
grant select on public.qing_profiles,public.qing_friendships,public.qing_messages,public.qing_reads to authenticated;
grant insert(id,username,nickname,signature,color), update(username,nickname,signature,color) on public.qing_profiles to authenticated;
grant insert(requester,addressee), update(status) on public.qing_friendships to authenticated;
grant insert(friendship_id,sender_id,client_id,body,image_path) on public.qing_messages to authenticated;
grant usage on sequence public.qing_messages_id_seq to authenticated;
grant insert(friendship_id,user_id,last_read_id),update(last_read_id) on public.qing_reads to authenticated;
-- These are discoverable public profile fields; emails stay in auth.users.
create policy qing_profiles_discover on public.qing_profiles for select to authenticated using (true);
create policy qing_profiles_create on public.qing_profiles for insert to authenticated with check (id=(select auth.uid()));
create policy qing_profiles_edit on public.qing_profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy qing_friends_view on public.qing_friendships for select to authenticated using ((select auth.uid()) in (requester,addressee));
create policy qing_friends_request on public.qing_friendships for insert to authenticated with check (requester=(select auth.uid()) and status='pending');
create policy qing_friends_respond on public.qing_friendships for update to authenticated using (addressee=(select auth.uid()) and status='pending') with check (addressee=(select auth.uid()) and status in ('accepted','rejected'));
create policy qing_messages_view on public.qing_messages for select to authenticated using (exists(select 1 from public.qing_friendships f where f.id=friendship_id and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
create policy qing_messages_send on public.qing_messages for insert to authenticated with check (sender_id=(select auth.uid()) and exists(select 1 from public.qing_friendships f where f.id=friendship_id and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
create policy qing_reads_view on public.qing_reads for select to authenticated using (exists(select 1 from public.qing_friendships f where f.id=friendship_id and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
create policy qing_reads_create on public.qing_reads for insert to authenticated with check (user_id=(select auth.uid()) and exists(select 1 from public.qing_friendships f where f.id=friendship_id and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
create policy qing_reads_edit on public.qing_reads for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and exists(select 1 from public.qing_friendships f where f.id=friendship_id and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
-- Keep read receipts monotonic when multiple devices read concurrently.
create function public.qing_monotonic_read() returns trigger language plpgsql security invoker set search_path='' as $$ begin new.last_read_id=greatest(old.last_read_id,new.last_read_id); return new; end $$;
revoke all on function public.qing_monotonic_read() from public,anon,authenticated;
create trigger qing_reads_monotonic before update on public.qing_reads for each row execute function public.qing_monotonic_read();
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types) values ('qingchat-images','qingchat-images',false,5242880,array['image/png','image/jpeg','image/webp','image/gif']);
create policy qing_images_read on storage.objects for select to authenticated using (bucket_id='qingchat-images' and exists(select 1 from public.qing_friendships f where f.id::text=(storage.foldername(name))[1] and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
create policy qing_images_upload on storage.objects for insert to authenticated with check (bucket_id='qingchat-images' and (storage.foldername(name))[2]=(select auth.uid())::text and exists(select 1 from public.qing_friendships f where f.id::text=(storage.foldername(name))[1] and f.status='accepted' and (select auth.uid()) in (f.requester,f.addressee)));
alter publication supabase_realtime add table public.qing_profiles,public.qing_friendships,public.qing_messages,public.qing_reads;
