-- Migration : supprime la fonction ping() et son horodatage.
-- Le ping quotidien (GitHub Actions) n'est plus utilisé : le workflow a été supprimé.
-- À exécuter une fois dans Supabase (SQL Editor), APRÈS le merge qui supprime
-- le workflow (sinon le workflow du jour échouerait).

drop function if exists birthlist.ping();
delete from birthlist.app_config where key = 'last_ping';
