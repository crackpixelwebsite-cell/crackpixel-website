# Crackpixel site

Files: `index.html` (whole site), `supabase/schema.sql` (fresh database), `supabase/migration-accounts.sql` (upgrade an existing database).

## 1. Supabase (free)
1. supabase.com > New project.
2. SQL Editor > paste `supabase/schema.sql` > Run. (Already ran the old one? Run `supabase/migration-accounts.sql` instead.)
3. Authentication > Users > Add user = your admin account. Use the same email you put in the `admins` table at the bottom of the SQL (default `crackpixelwebsite@gmail.com`). Pick a STRONG password - the admin email is easy to guess, so not `admin123`.
4. Authentication > Sign In / Providers: leave "Allow new users to sign up" **ON** (players register on the site). Only emails in the `admins` table get admin power, normal players cannot touch news, staff or applications.
5. Authentication > URL Configuration: set **Site URL** to your GitHub Pages link and add it under Redirect URLs (needed for the reset-password and confirm-email links).
6. Optional: Authentication > Sign In / Providers > Email > turn off "Confirm email" if you don't want players to confirm their email.
7. Project Settings > API: paste Project URL + **anon public** key into `var CFG={url:'',key:''}` in `index.html`. (Only the anon key, never service_role.)

## 2. GitHub Pages (free hosting)
1. Create a GitHub repo (e.g. `crackpixel-site`) and push this whole folder to the `main` branch.
2. Repo > Settings > Pages > **Source: GitHub Actions**.
3. Every push to `main` now deploys automatically (`.github/workflows/pages.yml`). Your site is at `https://<username>.github.io/<repo>/` and the admin panel at `.../admin/`.
4. Copy that URL into Supabase > Authentication > URL Configuration (**Site URL** + Redirect URLs).
5. Custom domain (optional): Settings > Pages > Custom domain, then add a DNS CNAME to `<username>.github.io`. Update the Supabase Site URL to the new domain.

Don't put `service_role` keys or passwords in the repo. The anon key already in `index.html` is public by design; security comes from the Row Level Security rules in `supabase/schema.sql`.

## Using the site
- Top right: **Log in / Register**. After logging in it shows your name and **Sign out** (admins also see **Admin**).
- Login uses email + password. "Forgot password?" emails a reset link.
- Admin panel (`#admin`): turn staff applications ON/OFF, review applications, manage staff, news and forum posts.

## Notes
- Empty CFG = demo mode (data only in your browser, demo admin `admin@demo.local` / `admin123`, no reset emails).
- Skins/heads come from mc-heads.net using the IGN.

## Admin panel
Open `/admin/` on the deployed site, for example `https://your-domain.com/admin/`. Sign in with the Supabase Authentication user whose email is also present in the `admins` table. The dashboard checks `public.is_admin()` before showing any admin controls.

## Admin panel
Open `/admin/` on the deployed site. Sign in with the Supabase Authentication user whose email is also present in the `admins` table. The panel checks `public.is_admin()` before showing admin controls.

## Subusers (limited admins)
Run `supabase/migration-subusers.sql` once in the SQL Editor (fresh installs already get it from `schema.sql`).
- **Main admin** = emails in the `admins` table. Register 637 on the site, then run `insert into admins(email) values('his-email');` (line 1 in the migration).
- In `/admin/` the main admin gets a **Subusers** tab: type a **registered** email, tick what they may do (Applications, Staff, News, Forums) and save. Unregistered emails are rejected.
- Subusers sign in at `/admin/` with their normal account and only see the tabs they were given. Only the main admin sees the Subusers tab.
- Staff page order: Owner, Dev, Admin, Gamemaster, Mod, Helper. 637 is added as Gamemaster.

## Setup checklist for subusers (do in this order)
1. Supabase > SQL Editor > run `supabase/migration-subusers.sql` (fixes "my_perms() failed ... schema cache").
2. 637 registers on the site with his email and confirms it.
3. SQL Editor: `insert into admins(email) values('637-email-here') on conflict (email) do nothing;` (637 = main admin).
4. Sign in at `/admin/` > **Subusers** tab > type a registered email, tick permissions, save.
