-- Migration : déplace tables et fonctions du schéma public vers le schéma birthlist.
-- Les données sont conservées (les tables sont déplacées, pas recréées).
-- À exécuter une fois dans Supabase (SQL Editor), en une seule fois.
--
-- AVANT : Project Settings > Data API > Exposed schemas : ajouter "birthlist".
-- APRÈS : merger la PR qui met à jour le site (en-tête Content-Profile).
-- Entre les deux, le site affiche une erreur : prévoir quelques minutes.

begin;

create schema if not exists birthlist;
grant usage on schema birthlist to anon, authenticated;

-- ---------------------------------------------------------------- Tables
alter table public.items      set schema birthlist;
alter table public.app_config set schema birthlist;

-- ----------------------------------------------- Anciennes fonctions (public)
-- Leur code référence public.items / public.app_config : on les supprime et
-- on les recrée dans birthlist.
drop function if exists public.get_items(text);
drop function if exists public.check_item(text, bigint);
drop function if exists public.verify_password(text);
drop function if exists public.ping();
drop function if exists public._password_ok(text);

-- ------------------------------------------------------------- Fonctions
create function birthlist._password_ok(p text)
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

create function birthlist.verify_password(p text)
returns boolean
language sql
security definer
set search_path = birthlist, extensions
as $$
  select birthlist._password_ok(p);
$$;

create function birthlist.get_items(p text)
returns table (id bigint, name text, image_url text, link_url text, checked boolean)
language plpgsql
security definer
set search_path = birthlist, extensions
as $$
begin
  if not birthlist._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  return query
    select i.id, i.name, i.image_url, i.link_url, i.checked
    from birthlist.items i
    order by i.position, i.id;
end;
$$;

create function birthlist.check_item(p text, item_id bigint)
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

create function birthlist.ping()
returns boolean
language sql
security definer
set search_path = birthlist
as $$
  insert into birthlist.app_config (key, value)
  values ('last_ping', now()::text)
  on conflict (key) do update set value = excluded.value
  returning true;
$$;

-- ---------------------------------------------------------------- Droits
revoke all on birthlist.items, birthlist.app_config from anon, authenticated;

revoke execute on function birthlist._password_ok(text) from public, anon, authenticated;
revoke execute on function birthlist.verify_password(text) from public;
revoke execute on function birthlist.get_items(text) from public;
revoke execute on function birthlist.check_item(text, bigint) from public;
revoke execute on function birthlist.ping() from public;

grant execute on function birthlist.verify_password(text) to anon, authenticated;
grant execute on function birthlist.get_items(text) to anon, authenticated;
grant execute on function birthlist.check_item(text, bigint) to anon, authenticated;
grant execute on function birthlist.ping() to anon, authenticated;

commit;
