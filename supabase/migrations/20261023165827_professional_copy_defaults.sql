-- Update defaults only. Preserve all existing user-authored records.
alter table public.chat_invites alter column title set default 'Chat 注册邀请';
alter table public.chat_invites alter column button_label set default '注册 Chat 账号';
alter table public.chat_shares alter column title set default '聊天记录分享';
