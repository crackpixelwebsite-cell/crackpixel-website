-- Run this ONCE in Supabase > SQL Editor if you already ran the old schema.sql.
-- Adds: player accounts safely (only listed admin emails get admin power) + staff applications on/off.

create table if not exists settings(key text primary key,value text not null);
create table if not exists admins(email text primary key);
alter table settings enable row level security;
alter table admins enable row level security;

create or replace function public.is_admin() returns boolean language sql security definer stable set search_path=public,auth as $$
  select exists(select 1 from public.admins a join auth.users u on lower(u.email)=lower(a.email) where u.id=auth.uid() and u.email_confirmed_at is not null)
$$;
create or replace function public.apps_open() returns boolean language sql stable set search_path=public as $$
  select coalesce((select value from public.settings where key='apps_open')<>'false',true)
$$;
grant execute on function public.is_admin() to anon,authenticated;
grant execute on function public.apps_open() to anon,authenticated;

drop policy if exists "admin news" on news;
drop policy if exists "admin staff" on staff;
drop policy if exists "admin del threads" on threads;
drop policy if exists "admin del replies" on replies;
drop policy if exists "admin apps" on apps;
drop policy if exists "send app" on apps;
drop policy if exists "read settings" on settings;
drop policy if exists "admin settings" on settings;

create policy "admin news" on news for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin staff" on staff for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin del threads" on threads for delete to authenticated using(public.is_admin());
create policy "admin del replies" on replies for delete to authenticated using(public.is_admin());
create policy "admin apps" on apps for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "send app" on apps for insert to anon,authenticated with check(public.apps_open());
create policy "read settings" on settings for select using(true);
create policy "admin settings" on settings for all to authenticated using(public.is_admin()) with check(public.is_admin());

insert into settings(key,value) values('apps_open','true') on conflict (key) do nothing;
-- CHANGE this to the email of your admin account (the user you made in Authentication > Users):
insert into admins(email) values('crackpixelwebsite@gmail.com') on conflict (email) do nothing;
