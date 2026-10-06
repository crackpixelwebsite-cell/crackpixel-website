-- Run this once in Supabase: SQL Editor > New query > paste > Run
create table news(id bigint generated always as identity primary key,title text not null,author text,body text,created_at timestamptz default now());
create table threads(id bigint generated always as identity primary key,cat text not null,title text not null check(char_length(title)<=80),ign text not null check(char_length(ign)<=16),body text not null check(char_length(body)<=5000),created_at timestamptz default now());
create table replies(id bigint generated always as identity primary key,thread_id bigint not null references threads(id) on delete cascade,ign text not null check(char_length(ign)<=16),body text not null check(char_length(body)<=3000),created_at timestamptz default now());
create table staff(id bigint generated always as identity primary key,ign text not null,rank text not null,created_at timestamptz default now());
create table settings(key text primary key,value text not null);
create table admins(email text primary key);
create table apps(id bigint generated always as identity primary key,ign text not null,discord text,age int,answers jsonb,status text not null default 'pending',created_at timestamptz default now());

alter table news enable row level security;alter table threads enable row level security;alter table replies enable row level security;alter table staff enable row level security;alter table apps enable row level security;alter table settings enable row level security;alter table admins enable row level security;

-- who is an admin: only emails listed in the admins table (and confirmed). Regular registered players are NOT admins.
create or replace function public.is_admin() returns boolean language sql security definer stable set search_path=public,auth as $$
  select exists(select 1 from public.admins a join auth.users u on lower(u.email)=lower(a.email) where u.id=auth.uid() and u.email_confirmed_at is not null)
$$;
create or replace function public.apps_open() returns boolean language sql stable set search_path=public as $$
  select coalesce((select value from public.settings where key='apps_open')<>'false',true)
$$;
grant execute on function public.is_admin() to anon,authenticated;
grant execute on function public.apps_open() to anon,authenticated;

-- everyone can read the public site data; only logged-in admins can change news/staff
create policy "read news" on news for select using(true);
create policy "read staff" on staff for select using(true);
create policy "read threads" on threads for select using(true);
create policy "read replies" on replies for select using(true);
create policy "admin news" on news for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin staff" on staff for all to authenticated using(public.is_admin()) with check(public.is_admin());
-- players can post threads/replies/applications; only admins can delete or read applications
create policy "post threads" on threads for insert to anon,authenticated with check(true);
create policy "post replies" on replies for insert to anon,authenticated with check(true);
create policy "admin del threads" on threads for delete to authenticated using(public.is_admin());
create policy "admin del replies" on replies for delete to authenticated using(public.is_admin());
create policy "send app" on apps for insert to anon,authenticated with check(public.apps_open());
create policy "admin apps" on apps for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "read settings" on settings for select using(true);
create policy "admin settings" on settings for all to authenticated using(public.is_admin()) with check(public.is_admin());

insert into staff(ign,rank) values('NickSleeps','Owner');
insert into news(title,author,body) values('Crackpixel Network - Official Release','NickSleeps','The moment has finally arrived. Crackpixel is live.');

insert into settings(key,value) values('apps_open','true');
-- put YOUR admin account email here (create that user in Authentication > Users first)
insert into admins(email) values('crackpixelwebsite@gmail.com');


-- ===== Subusers + permissions (same as migration-subusers.sql) =====

-- 1) MAIN ADMIN: put 637's email here (he must register on the site first, then run this).
-- insert into admins(email) values('PUT-637-EMAIL-HERE') on conflict (email) do nothing;

-- 2) Staff: 637 = Gamemaster (shown under Admin on the staff page)
insert into staff(ign,rank) select '637','Gamemaster' where not exists(select 1 from staff where lower(ign)='637');

-- 3) Subusers table (only the main admin can read/remove; adding goes through add_subuser())
create table if not exists subadmins(email text primary key,perms text[] not null default '{}',created_at timestamptz default now());
alter table subadmins enable row level security;
drop policy if exists "admin read subadmins" on subadmins;
drop policy if exists "admin delete subadmins" on subadmins;
create policy "admin read subadmins" on subadmins for select to authenticated using(public.is_admin());
create policy "admin delete subadmins" on subadmins for delete to authenticated using(public.is_admin());

-- 4) Permission check: main admin has everything; subusers only what is ticked (apps / staff / news / forums)
create or replace function public.has_perm(p text) returns boolean language sql security definer stable set search_path=public,auth as $$
  select public.is_admin() or exists(select 1 from public.subadmins s join auth.users u on lower(u.email)=lower(s.email) where u.id=auth.uid() and u.email_confirmed_at is not null and p=any(s.perms))
$$;
create or replace function public.my_perms() returns text[] language sql security definer stable set search_path=public,auth as $$
  select case when public.is_admin() then array['apps','staff','news','forums','subusers']
  else coalesce((select s.perms from public.subadmins s join auth.users u on lower(u.email)=lower(s.email) where u.id=auth.uid() and u.email_confirmed_at is not null),'{}'::text[]) end
$$;

-- 5) Add / update a subuser. Fails if the email is not registered.
create or replace function public.add_subuser(p_email text,p_perms text[]) returns void language plpgsql security definer set search_path=public,auth as $$
declare e text:=lower(trim(p_email));
begin
  if not public.is_admin() then raise exception 'Only the main admin can manage subusers.'; end if;
  if not exists(select 1 from auth.users where lower(email)=e) then raise exception 'That email is not registered on the site yet. Ask them to register first.'; end if;
  if exists(select 1 from public.admins where lower(email)=e) then raise exception 'That email is already a main admin.'; end if;
  p_perms:=array(select distinct x from unnest(coalesce(p_perms,'{}'::text[])) x where x=any(array['apps','staff','news','forums']));
  insert into public.subadmins(email,perms) values(e,p_perms) on conflict(email) do update set perms=excluded.perms;
end $$;

-- 6) List subusers with their in-game name (main admin only)
create or replace function public.list_subusers() returns table(email text,perms text[],ign text,created_at timestamptz) language plpgsql security definer stable set search_path=public,auth as $$
begin
  if not public.is_admin() then raise exception 'Only the main admin can manage subusers.'; end if;
  return query select s.email,s.perms,(u.raw_user_meta_data->>'ign')::text,s.created_at from public.subadmins s left join auth.users u on lower(u.email)=lower(s.email) order by s.created_at;
end $$;

revoke execute on function public.add_subuser(text,text[]) from public,anon;
revoke execute on function public.list_subusers() from public,anon;
grant execute on function public.has_perm(text) to anon,authenticated;
grant execute on function public.my_perms() to anon,authenticated;
grant execute on function public.add_subuser(text,text[]) to authenticated;
grant execute on function public.list_subusers() to authenticated;

-- 7) Re-point the table policies from "admin only" to "has permission"
drop policy if exists "admin news" on news;
drop policy if exists "admin staff" on staff;
drop policy if exists "admin del threads" on threads;
drop policy if exists "admin del replies" on replies;
drop policy if exists "admin apps" on apps;
drop policy if exists "admin settings" on settings;
create policy "admin news" on news for all to authenticated using(public.has_perm('news')) with check(public.has_perm('news'));
create policy "admin staff" on staff for all to authenticated using(public.has_perm('staff')) with check(public.has_perm('staff'));
create policy "admin del threads" on threads for delete to authenticated using(public.has_perm('forums'));
create policy "admin del replies" on replies for delete to authenticated using(public.has_perm('forums'));
create policy "admin apps" on apps for all to authenticated using(public.has_perm('apps')) with check(public.has_perm('apps'));
create policy "admin settings" on settings for all to authenticated using(public.has_perm('apps')) with check(public.has_perm('apps'));

-- 8) Make Supabase see the new functions immediately (fixes 'not found in the schema cache')
notify pgrst, 'reload schema';
