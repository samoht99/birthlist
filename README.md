# Liste de naissance

Petit site statique (HTML/CSS/JS) hébergé sur GitHub Pages. Les données sont dans Supabase.

- Les invités ouvrent le lien, saisissent le mot de passe, voient la liste et **cochent** ce qu'ils ont acheté.
- Personne ne peut décocher depuis le site. Toutes les actions d'administration se font **directement dans la base Supabase**.

## Comment ça marche

- `index.html`, `style.css`, `app.js` : le site.
- `supabase/schema.sql` : tables et fonctions de la base.
- `.github/workflows/keepalive.yml` : appel quotidien qui évite la mise en pause du projet Supabase gratuit.

La sécurité repose sur la base : les tables sont verrouillées (RLS sans policy) et le site n'y accède que via des fonctions qui vérifient le mot de passe (stocké haché). L'URL et la clé `sb_publishable_…` présentes dans le code sont publiques par conception. **Ne jamais commiter** la clé `sb_secret_…`, le mot de passe de la base ni le mot de passe du site.

## Installation initiale (une seule fois)

1. Dans Supabase : **SQL Editor > New query**, coller le contenu de `supabase/schema.sql`, **Run**.
2. Définir le mot de passe du site (remplacer `MON_MOT_DE_PASSE`) :
   ```sql
   insert into public.app_config (key, value)
   values ('password_hash', extensions.crypt('MON_MOT_DE_PASSE', extensions.gen_salt('bf')))
   on conflict (key) do update set value = excluded.value;
   ```
3. Activer GitHub Pages : dépôt GitHub > **Settings > Pages** > Source : *Deploy from a branch*, branche `main`, dossier `/ (root)`.
4. Le site est alors disponible à `https://samoht99.github.io/birthlist/`.

## Actions d'administration

Toutes se font dans Supabase, **SQL Editor** (ou **Table Editor** pour les actions simples). Le dashboard a tous les droits : les restrictions du site ne s'y appliquent pas.

### Ajouter un article

```sql
insert into public.items (name, image_url, position)
values ('Poussette', 'https://exemple.com/poussette.jpg', 10);
```

- `image_url` est optionnelle (`null` pour aucune image).
- Les articles sont triés par `position` puis par `id` : donnez des valeurs croissantes (10, 20, 30…) pour pouvoir en insérer entre deux.

Plusieurs articles à la fois :

```sql
insert into public.items (name, image_url, position) values
  ('Lit bébé',  'https://exemple.com/lit.jpg', 20),
  ('Body 3 mois', null, 30);
```

### Décocher un article

```sql
update public.items set checked = false where id = 3;
```

Tout décocher : `update public.items set checked = false;`

### Voir la liste et l'état des cases

```sql
select id, name, checked from public.items order by position, id;
```

### Modifier ou supprimer un article

```sql
update public.items set name = 'Nouveau nom', image_url = 'https://…' where id = 3;
delete from public.items where id = 3;
```

### Changer le mot de passe du site

Relancer la requête de l'étape 2 avec le nouveau mot de passe. Les invités devront le ressaisir (au plus tard à la fermeture de leur onglet).

## Mise en pause de Supabase

Le workflow `keepalive.yml` appelle la base chaque jour. Si le projet est malgré tout mis en pause, le réactiver depuis le dashboard Supabase (les données sont conservées). GitHub désactive les workflows planifiés après 60 jours sans activité dans le dépôt : en cas d'avertissement, réactiver le workflow dans l'onglet **Actions**.

## Limites connues

- Le mot de passe est protégé contre la force brute par un délai d'1 s par tentative, pas par un blocage strict.
- Quelqu'un qui connaît le mot de passe peut cocher n'importe quel article, mais jamais décocher.
