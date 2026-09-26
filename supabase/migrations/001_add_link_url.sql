-- Migration : ajoute la colonne link_url (lien vers la page du produit).
-- À exécuter une fois dans Supabase (SQL Editor) sur une base déjà installée.
-- Les installations neuves utilisent directement schema.sql.

alter table public.items add column if not exists link_url text;

-- Le type de retour change : il faut supprimer puis recréer la fonction.
drop function if exists public.get_items(text);

create function public.get_items(p text)
returns table (id bigint, name text, image_url text, link_url text, checked boolean)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public._password_ok(p) then
    raise exception 'invalid_password';
  end if;
  return query
    select i.id, i.name, i.image_url, i.link_url, i.checked
    from public.items i
    order by i.position, i.id;
end;
$$;

revoke execute on function public.get_items(text) from public;
grant execute on function public.get_items(text) to anon, authenticated;
