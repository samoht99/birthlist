-- Schéma de la liste de naissance (schéma PostgreSQL "birthlist").
-- À exécuter une fois dans Supabase : SQL Editor > New query > coller > Run.
-- Ensuite : Project Settings > Data API > Exposed schemas : ajouter "birthlist".

create extension if not exists pgcrypto with schema extensions;

create schema if not exists birthlist;
grant usage on schema birthlist to anon, authenticated;

-- ---------------------------------------------------------------- Tables
create table if not exists birthlist.items (
  id         bigint generated always as identity primary key,
  name       text    not null,
  image_url  text,
  link_url   text,
  image_url_2 text,
  link_url_2  text,
  checked    boolean not null default false,
  position   integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists birthlist.app_config (
  key   text primary key,
  value text not null
);

-- RLS activée et AUCUNE policy : les rôles anon/authenticated n'ont aucun
-- accès direct aux tables. Seules les fonctions ci-dessous (security definer)
-- peuvent les lire/écrire, et uniquement avec le bon mot de passe.
alter table birthlist.items      enable row level security;
alter table birthlist.app_config enable row level security;
revoke all on birthlist.items, birthlist.app_config from anon, authenticated;

-- ------------------------------------------------------------- Fonctions
-- Vérifie le mot de passe. En cas d'échec, on ralentit (anti force brute).
create or replace function birthlist._password_ok(p text)
returns boolean
language plpgsql
security definer
set search_path = birthlist, extensions
as $$
declare
  h text;
begin
  select value into h from birthlist.app_config where key = 'password_hash';
  if h is not null and p is not null and h = crypt(p, h) then
    return true;
  end if;
  perform pg_sleep(1);
  return false;
end;
$$;

create or replace function birthlist.verify_password(p text)
returns boolean
language sql
security definer
set search_path = birthlist, extensions
as $$
  select birthlist._password_ok(p);
$$;

create or replace function birthlist.get_items(p text)
returns table (
  id bigint, name text,
  image_url text, link_url text,
  image_url_2 text, link_url_2 text,
  checked boolean
)
language plpgsql
security definer
set search_path = birthlist, extensions
as $$
begin
  if not birthlist._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  return query
    select i.id, i.name,
           i.image_url, i.link_url,
           i.image_url_2, i.link_url_2,
           i.checked
    from birthlist.items i
    order by i.position, i.id;
end;
$$;

-- Coche uniquement (jamais de décochage : réservé à l'admin via le dashboard).
create or replace function birthlist.check_item(p text, item_id bigint)
returns void
language plpgsql
security definer
set search_path = birthlist, extensions
as $$
begin
  if not birthlist._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  update birthlist.items set checked = true where id = item_id;
end;
$$;

-- ---------------------------------------------------------------- Droits
revoke execute on function birthlist._password_ok(text) from public, anon, authenticated;
revoke execute on function birthlist.verify_password(text) from public;
revoke execute on function birthlist.get_items(text) from public;
revoke execute on function birthlist.check_item(text, bigint) from public;

grant execute on function birthlist.verify_password(text) to anon, authenticated;
grant execute on function birthlist.get_items(text) to anon, authenticated;
grant execute on function birthlist.check_item(text, bigint) to anon, authenticated;
