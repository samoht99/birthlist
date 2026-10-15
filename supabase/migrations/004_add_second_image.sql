-- Migration : une seconde image (et son lien) par article.
-- À exécuter une fois dans Supabase (SQL Editor) sur une base déjà installée.
-- À lancer AVANT de merger la PR qui met à jour le site : l'ancien site
-- continue de fonctionner avec la nouvelle fonction (colonnes en plus ignorées).

alter table birthlist.items add column if not exists image_url_2 text;
alter table birthlist.items add column if not exists link_url_2  text;

-- Le type de retour change : il faut supprimer puis recréer la fonction.
drop function if exists birthlist.get_items(text);

create function birthlist.get_items(p text)
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

revoke execute on function birthlist.get_items(text) from public;
grant execute on function birthlist.get_items(text) to anon, authenticated;
