-- Schéma de la liste de naissance.
-- À exécuter une fois dans Supabase : SQL Editor > New query > coller > Run.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- Tables
create table if not exists public.items (
  id         bigint generated always as identity primary key,
  name       text    not null,
  image_url  text,
  checked    boolean not null default false,
  position   integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

-- RLS activée et AUCUNE policy : les rôles anon/authenticated n'ont aucun
-- accès direct aux tables. Seules les fonctions ci-dessous (security definer)
-- peuvent les lire/écrire, et uniquement avec le bon mot de passe.
alter table public.items      enable row level security;
alter table public.app_config enable row level security;
revoke all on public.items, public.app_config from anon, authenticated;

-- ------------------------------------------------------------- Fonctions
-- Vérifie le mot de passe. En cas d'échec, on ralentit (anti force brute).
create or replace function public._password_ok(p text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  h text;
begin
  select value into h from public.app_config where key = 'password_hash';
  if h is not null and p is not null and h = crypt(p, h) then
    return true;
  end if;
  perform pg_sleep(1);
  return false;
end;
$$;

create or replace function public.verify_password(p text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select public._password_ok(p);
$$;

create or replace function public.get_items(p text)
returns table (id bigint, name text, image_url text, checked boolean)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  return query
    select i.id, i.name, i.image_url, i.checked
    from public.items i
    order by i.position, i.id;
end;
$$;

-- Coche uniquement (jamais de décochage : réservé à l'admin via le dashboard).
create or replace function public.check_item(p text, item_id bigint)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  update public.items set checked = true where id = item_id;
end;
$$;

-- Appelée chaque jour par GitHub Actions pour éviter la mise en pause
-- du projet Supabase gratuit. Ne renvoie aucune donnée.
create or replace function public.ping()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from public.items) or true;
$$;

-- ---------------------------------------------------------------- Droits
revoke execute on function public._password_ok(text) from public, anon, authenticated;
revoke execute on function public.verify_password(text) from public;
revoke execute on function public.get_items(text) from public;
revoke execute on function public.check_item(text, bigint) from public;
revoke execute on function public.ping() from public;

grant execute on function public.verify_password(text) to anon, authenticated;
grant execute on function public.get_items(text) to anon, authenticated;
grant execute on function public.check_item(text, bigint) to anon, authenticated;
grant execute on function public.ping() to anon, authenticated;
