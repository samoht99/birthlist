# Liste de naissance

Petit site statique (HTML/CSS/JS) hébergé sur GitHub Pages. Les données sont dans Supabase.

- Les invités ouvrent le lien, saisissent le mot de passe, voient la liste et **cochent** ce qu'ils ont acheté.
- Personne ne peut décocher depuis le site. Toutes les actions d'administration se font **directement dans la base Supabase**.

## Comment ça marche

- `index.html`, `style.css`, `app.js` : le site.
- `supabase/schema.sql` : tables et fonctions de la base (installation neuve).
- `supabase/migrations/` : scripts à exécuter, dans l'ordre, sur une base déjà installée (ex. `001_add_link_url.sql`).
- `.github/workflows/keepalive.yml` : appel quotidien qui évite la mise en pause du projet Supabase gratuit.

La sécurité repose sur la base : les tables sont verrouillées (RLS sans policy) et le site n'y accède que via des fonctions qui vérifient le mot de passe (stocké haché). L'URL et la clé `sb_publishable_…` présentes dans le code sont publiques par conception. **Ne jamais commiter** la clé `sb_secret_…`, le mot de passe de la base ni le mot de passe du site.

## Installation initiale (une seule fois)

1. Dans Supabase : **SQL Editor > New query**, coller le contenu de `supabase/schema.sql`, **Run**. Les tables et fonctions sont dans le schéma `birthlist` (pas `public`).
   Puis **Project Settings > Data API > Exposed schemas** : ajouter `birthlist`, sinon le site n'a pas accès à l'API.
2. Définir le mot de passe du site (remplacer `MON_MOT_DE_PASSE`) :
   ```sql
   insert into birthlist.app_config (key, value)
   values ('password_hash', extensions.crypt('MON_MOT_DE_PASSE', extensions.gen_salt('bf')))
   on conflict (key) do update set value = excluded.value;
   ```
3. Activer GitHub Pages : dépôt GitHub > **Settings > Pages** > Source : *Deploy from a branch*, branche `main`, dossier `/ (root)`.
4. Le site est alors disponible à `https://samoht99.github.io/birthlist/`.

## Actions d'administration

Toutes se font dans Supabase, **SQL Editor** (ou **Table Editor** pour les actions simples). Le dashboard a tous les droits : les restrictions du site ne s'y appliquent pas.

### Ajouter un article

```sql
insert into birthlist.items (name, image_url, link_url, position)
values ('Poussette', 'images/poussette.jpg', 'https://boutique.com/poussette', 10);
```

- `image_url` est optionnelle (`null` pour aucune image).
- `link_url` est optionnelle (`null` pour aucun lien). Si elle est renseignée, le nom **et** l'image de l'article deviennent cliquables et ouvrent la page dans un nouvel onglet. Seuls les liens `https://` et `http://` sont acceptés.
- Les articles sont triés par `position` puis par `id` : donnez des valeurs croissantes (10, 20, 30…) pour pouvoir en insérer entre deux.

Plusieurs articles à la fois :

```sql
insert into birthlist.items (name, image_url, link_url, position) values
  ('Lit bébé',  'images/lit-bebe.jpg', 'https://boutique.com/lit', 20),
  ('Body 3 mois', null, null, 30),
  ('Veilleuse', 'https://exemple.com/veilleuse.jpg', null, 40);
```

Ajouter ou changer le lien d'un article existant :

```sql
update birthlist.items set link_url = 'https://boutique.com/nouveau-lien' where id = 3;
```

### Ajouter les images des articles

1. Placer le fichier dans le dossier `images/` du dépôt (GitHub : **Add file > Upload files**, ou copie locale puis `git add`, `git commit`, `git push`). GitHub Pages met le site à jour en une ou deux minutes.
2. Dans `image_url`, indiquer le **chemin relatif, sans slash initial** : `images/poussette.jpg`.
   - `/images/poussette.jpg` ne fonctionne **pas** (le site est servi sous `/birthlist/`).
   - Une URL complète (`https://…`) fonctionne aussi : les deux modes peuvent être mélangés.
3. Conseils : environ 400 px de côté, JPG de moins de 100 Ko, nom de fichier en minuscules, sans espaces ni accents (`body-blanc.jpg`).

Le dépôt étant public, ces images sont accessibles à qui connaît leur URL, même sans le mot de passe du site.

Changer l'image d'un article existant :

```sql
update birthlist.items set image_url = 'images/nouvelle.jpg' where id = 3;
```

### Décocher un article

```sql
update birthlist.items set checked = false where id = 3;
```

Tout décocher : `update birthlist.items set checked = false;`

### Voir la liste et l'état des cases

```sql
select id, name, checked from birthlist.items order by position, id;
```

### Modifier ou supprimer un article

```sql
update birthlist.items set name = 'Nouveau nom', image_url = 'https://…' where id = 3;
delete from birthlist.items where id = 3;
```

### Changer le mot de passe du site

Relancer la requête de l'étape 2 avec le nouveau mot de passe. Les invités devront le ressaisir (au plus tard à la fermeture de leur onglet).

## Mise en pause de Supabase

Le workflow `keepalive.yml` appelle chaque jour la fonction `ping`, qui écrit un horodatage (`last_ping`) dans la table `app_config`. Une simple lecture n'avait pas suffi à Supabase pour considérer le projet comme actif. Pour vérifier : `select * from birthlist.app_config where key = 'last_ping';`. Si le projet est malgré tout mis en pause, le réactiver depuis le dashboard Supabase (les données sont conservées). GitHub désactive les workflows planifiés après 60 jours sans activité dans le dépôt : en cas d'avertissement, réactiver le workflow dans l'onglet **Actions**.

## Limites connues

- Le mot de passe est protégé contre la force brute par un délai d'1 s par tentative, pas par un blocage strict.
- Quelqu'un qui connaît le mot de passe peut cocher n'importe quel article, mais jamais décocher.
