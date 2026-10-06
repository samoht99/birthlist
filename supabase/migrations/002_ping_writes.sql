-- Migration : le ping quotidien fait une vraie écriture en base.
-- Un simple select n'a pas suffi à Supabase pour considérer le projet comme actif.
-- À exécuter une fois dans Supabase (SQL Editor) sur une base déjà installée.

create or replace function public.ping()
returns boolean
language sql
security definer
set search_path = public
as $$
  insert into public.app_config (key, value)
  values ('last_ping', now()::text)
  on conflict (key) do update set value = excluded.value
  returning true;
$$;

revoke execute on function public.ping() from public;
grant execute on function public.ping() to anon, authenticated;
