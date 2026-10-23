create table public.chat_invites (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.qing_profiles(id) on delete cascade,
 title text not null default '一起加入 Chat' check(char_length(btrim(title)) between 1 and 80),
 description text not null default '' check(char_length(description)<=400),
 byline text not null default '' check(char_length(byline)<=40),
 button_label text not null default '注册加入 Chat' check(char_length(btrim(button_label)) between 1 and 32),
 accent text not null default '#6750a4' check(accent ~ '^#[0-9a-fA-F]{6}$'),
 background text not null default '#f7f2fa' check(background ~ '^#[0-9a-fA-F]{6}$'),
 layout text not null default 'card' check(layout in ('card','split')),
 cover_path text check(cover_path is null or cover_path ~ ('^'||owner_id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$')),
 expires_at timestamptz not null default now()+interval '7 days',revoked boolean not null default false,created_at timestamptz not null default now()
);
create index chat_invites_owner_time on public.chat_invites(owner_id,created_at desc);
create index chat_invites_cover on public.chat_invites(cover_path) where cover_path is not null;
alter table public.chat_invites enable row level security;
revoke all on public.chat_invites from anon,authenticated;
grant select on public.chat_invites to authenticated;
grant insert(owner_id,title,description,byline,button_label,accent,background,layout,cover_path,expires_at),update(title,description,byline,button_label,accent,background,layout,cover_path,expires_at,revoked) on public.chat_invites to authenticated;
create policy chat_invites_owner_read on public.chat_invites for select to authenticated using(owner_id=(select auth.uid()));
create policy chat_invites_owner_create on public.chat_invites for insert to authenticated with check(owner_id=(select auth.uid()));
create policy chat_invites_owner_update on public.chat_invites for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create function public.chat_validate_invite() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null or new.owner_id<>auth.uid() then raise exception 'Sign in required'; end if;
 if new.expires_at<=now() or new.expires_at>now()+interval '30 days 1 minute' then
  -- Revocation must remain possible even after the invite expires.
  if not (tg_op='UPDATE' and new.revoked) then raise exception 'Invalid expiry'; end if;
 end if;
 if tg_op='INSERT' and (select count(*) from public.chat_invites where owner_id=auth.uid() and created_at>now()-interval '1 day')>=50 then raise exception 'Daily invite limit reached'; end if;
 if tg_op='UPDATE' and old.revoked and not new.revoked then raise exception 'Revoked invites cannot be reopened'; end if;
 return new;
end $$;
revoke all on function public.chat_validate_invite() from public,anon,authenticated;
create trigger chat_invites_validate before insert or update on public.chat_invites for each row execute function public.chat_validate_invite();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-invite-covers','chat-invite-covers',false,1048576,array['image/webp']);
create policy chat_invite_covers_owner_read on storage.objects for select to authenticated using(bucket_id='chat-invite-covers' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy chat_invite_covers_owner_upload on storage.objects for insert to authenticated with check(bucket_id='chat-invite-covers' and name ~ ('^'||(select auth.uid())::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'));
create policy chat_invite_covers_delete_unused on storage.objects for delete to authenticated using(bucket_id='chat-invite-covers' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.chat_invites where cover_path=name));
