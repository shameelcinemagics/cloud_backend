-- ===== Roles (with "admin") =====
create table if not exists public.roles (
  id bigserial primary key,
  slug text unique not null,
  label text not null
);

insert into public.roles (slug, label)
values ('admin','Admin')
on conflict (slug) do nothing;

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict
);

-- ===== Pages =====
create table if not exists public.pages (
  id bigserial primary key,
  slug text unique not null,
  label text not null
);

insert into public.pages (slug, label) values
  ('dashboard','Dashboard'),
  ('machines','Machines'),
  ('products','Products'),
  ('inventory','Inventory'),
  ('sales','Sales'),
  ('finance','Finance'),
  ('support','Support'),
  ('marketing','Marketing / Signage'),
  ('users','Users'),
  ('settings','Settings')
on conflict (slug) do nothing;

-- ===== Per-user page permissions =====
-- perms_mask: 2 = View (R), 15 = Admin (CRUD), 0/NULL = none
create table if not exists public.user_page_perms (
  user_id uuid references auth.users(id) on delete cascade,
  page_id bigint references public.pages(id) on delete cascade,
  perms_mask int not null,
  primary key (user_id, page_id)
);

-- ===== Effective view =====
-- Anyone with role 'admin' has CRUD (15) on all pages.
create or replace view public.user_effective_page_perms as
with admins as (
  select ur.user_id
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.slug = 'admin'
)
select
  u.id as user_id,
  p.slug as page_slug,
  case when u.id in (select user_id from admins) then 15
       else coalesce(upp.perms_mask, 0) end as perms_mask
from auth.users u
cross join public.pages p
left join public.user_page_perms upp
  on upp.user_id = u.id and upp.page_id = p.id;

-- ===== RLS (enable on tables; views don’t get RLS) =====
alter table public.pages enable row level security;
alter table public.user_roles enable row level security;
alter table public.user_page_perms enable row level security;

-- Authenticated users can read page list
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='pages' and policyname='auth read pages'
  ) then
    create policy "auth read pages"
      on public.pages for select to authenticated using (true);
  end if;
end $$;
