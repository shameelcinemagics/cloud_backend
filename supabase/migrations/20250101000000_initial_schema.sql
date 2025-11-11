-- Migration: Initial Schema
-- Created: 2025-01-01
-- Description: Creates core tables for roles, pages, and permissions with RLS policies

-- ===== Migration Tracking Table =====
create table if not exists public.schema_migrations (
  version text primary key,
  applied_at timestamp with time zone default now(),
  description text
);

-- Record this migration
insert into public.schema_migrations (version, description)
values ('20250101000000', 'Initial schema - roles, pages, permissions')
on conflict (version) do nothing;

-- ===== Roles Table =====
create table if not exists public.roles (
  id bigserial primary key,
  slug text unique not null,
  label text not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create index for faster lookups
create index if not exists idx_roles_slug on public.roles(slug);

-- Insert default admin role
insert into public.roles (slug, label)
values ('admin', 'Admin')
on conflict (slug) do nothing;

-- ===== User Roles Table =====
create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  created_at timestamp with time zone default now()
);

-- Create index for faster lookups
create index if not exists idx_user_roles_user_id on public.user_roles(user_id);
create index if not exists idx_user_roles_role_id on public.user_roles(role_id);

-- ===== Pages Table =====
create table if not exists public.pages (
  id bigserial primary key,
  slug text unique not null,
  label text not null,
  description text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create index for faster lookups
create index if not exists idx_pages_slug on public.pages(slug);

-- Insert default pages
insert into public.pages (slug, label) values
  ('dashboard', 'Dashboard'),
  ('machines', 'Machines'),
  ('products', 'Products'),
  ('inventory', 'Inventory'),
  ('sales', 'Sales'),
  ('finance', 'Finance'),
  ('support', 'Support'),
  ('marketing', 'Marketing / Signage'),
  ('users', 'Users'),
  ('settings', 'Settings')
on conflict (slug) do nothing;

-- ===== User Page Permissions Table =====
-- perms_mask: Bitmask for permissions (C:1, R:2, U:4, D:8)
-- Example: 2 = Read only, 15 = Full CRUD
create table if not exists public.user_page_perms (
  user_id uuid references auth.users(id) on delete cascade,
  page_id bigint references public.pages(id) on delete cascade,
  perms_mask int not null check (perms_mask >= 0 and perms_mask <= 15),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  primary key (user_id, page_id)
);

-- Create indexes for faster lookups
create index if not exists idx_user_page_perms_user_id on public.user_page_perms(user_id);
create index if not exists idx_user_page_perms_page_id on public.user_page_perms(page_id);

-- ===== Effective Permissions View =====
-- This view calculates the effective permissions for each user on each page
-- Users with 'admin' role automatically get full CRUD (15) on all pages
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
  p.id as page_id,
  case
    when u.id in (select user_id from admins) then 15
    else coalesce(upp.perms_mask, 0)
  end as perms_mask
from auth.users u
cross join public.pages p
left join public.user_page_perms upp
  on upp.user_id = u.id and upp.page_id = p.id;

-- ===== Row Level Security (RLS) =====
-- Enable RLS on all tables
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.pages enable row level security;
alter table public.user_page_perms enable row level security;
alter table public.schema_migrations enable row level security;

-- ===== RLS Policies =====

-- Roles: Authenticated users can read all roles
drop policy if exists "Authenticated users can read roles" on public.roles;
create policy "Authenticated users can read roles"
  on public.roles for select
  to authenticated
  using (true);

-- User Roles: Users can read their own role assignments
drop policy if exists "Users can read their own roles" on public.user_roles;
create policy "Users can read their own roles"
  on public.user_roles for select
  to authenticated
  using (auth.uid() = user_id);

-- Pages: Authenticated users can read all pages
drop policy if exists "Authenticated users can read pages" on public.pages;
create policy "Authenticated users can read pages"
  on public.pages for select
  to authenticated
  using (true);

-- User Page Permissions: Users can read their own permissions
drop policy if exists "Users can read their own permissions" on public.user_page_perms;
create policy "Users can read their own permissions"
  on public.user_page_perms for select
  to authenticated
  using (auth.uid() = user_id);

-- Schema Migrations: Only service role can access
drop policy if exists "Service role can manage migrations" on public.schema_migrations;
create policy "Service role can manage migrations"
  on public.schema_migrations for all
  to service_role
  using (true);

-- ===== Functions for Triggers =====

-- Function to update updated_at timestamp
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Triggers to automatically update updated_at
drop trigger if exists update_roles_updated_at on public.roles;
create trigger update_roles_updated_at
  before update on public.roles
  for each row
  execute function public.update_updated_at_column();

drop trigger if exists update_pages_updated_at on public.pages;
create trigger update_pages_updated_at
  before update on public.pages
  for each row
  execute function public.update_updated_at_column();

drop trigger if exists update_user_page_perms_updated_at on public.user_page_perms;
create trigger update_user_page_perms_updated_at
  before update on public.user_page_perms
  for each row
  execute function public.update_updated_at_column();

-- ===== Audit Log Table (Optional) =====
create table if not exists public.audit_logs (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete set null,
  table_name text not null,
  action text not null, -- INSERT, UPDATE, DELETE
  old_data jsonb,
  new_data jsonb,
  created_at timestamp with time zone default now()
);

create index if not exists idx_audit_logs_user_id on public.audit_logs(user_id);
create index if not exists idx_audit_logs_created_at on public.audit_logs(created_at);

alter table public.audit_logs enable row level security;

-- Only admins can view audit logs
drop policy if exists "Admins can read audit logs" on public.audit_logs;
create policy "Admins can read audit logs"
  on public.audit_logs for select
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid() and r.slug = 'admin'
    )
  );

-- ===== Grant Permissions =====
-- Grant usage on sequences
grant usage on all sequences in schema public to authenticated;
grant usage on all sequences in schema public to service_role;

-- Grant execute on functions
grant execute on function public.update_updated_at_column() to authenticated;
grant execute on function public.update_updated_at_column() to service_role;

-- Comments for documentation
comment on table public.roles is 'User roles (e.g., admin, manager)';
comment on table public.user_roles is 'Associates users with roles';
comment on table public.pages is 'Application pages/resources that can have permissions';
comment on table public.user_page_perms is 'Per-user page permissions using bitmask (C:1, R:2, U:4, D:8)';
comment on table public.schema_migrations is 'Tracks applied database migrations';
comment on table public.audit_logs is 'Audit trail for sensitive operations';
comment on view public.user_effective_page_perms is 'Calculated effective permissions for users (admins get full access)';
