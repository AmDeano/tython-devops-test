# Contribuer

## Stratégie de branches

| Branche     | Rôle                                          | Déployée sur | Protection                           |
| ----------- | --------------------------------------------- | ------------ | ------------------------------------ |
| `main`      | Code stable, toujours déployable              | production   | PR obligatoire, CI verte, 1 review   |
| `dev`       | Intégration des features en cours             | staging      | PR obligatoire, CI verte             |
| `feature/*` | Une feature / un correctif (`feature/login`)  | —            | aucune                               |
| `hotfix/*`  | Correctif urgent partant de `main`            | —            | aucune                               |

Flux normal :

```
feature/xyz ──PR──▶ dev ──PR (release)──▶ main ──tag vX.Y.Z──▶ release
```

- Une branche `feature/*` part **toujours** de `dev` à jour : `git switch dev && git pull && git switch -c feature/xyz`.
- Nommage : `feature/<sujet-court>`, `fix/<sujet>`, `hotfix/<sujet>`, en kebab-case.
- Un `hotfix/*` part de `main`, est mergé dans `main` **puis** reporté dans `dev`.

## Règles de merge (PR GitHub / MR GitLab)

- Aucun push direct sur `main` ni `dev` (branch protection GitHub).
- Une PR doit :
  - passer la CI (`lint`, `test`, `build`, `docker`, `smoke-test`) ;
  - être à jour avec sa branche cible ;
  - avoir au moins **1 approbation** pour `main` ;
  - rester petite et centrée sur un sujet.
- Méthode de merge :
  - `feature/*` → `dev` : **Squash and merge** (1 commit propre par feature) ;
  - `dev` → `main` : **Merge commit** (garde la trace de la release).
- Supprimer la branche après merge.
- Les PR se font **sur GitHub** (source de vérité). GitLab est un miroir en lecture : aucune MR n'y est mergée.

## Conventions de commits

Format inspiré de [Conventional Commits](https://www.conventionalcommits.org/) :

```
<type>(<scope optionnel>): <description à l'impératif, en minuscule>
```

| Type       | Usage                                  |
| ---------- | -------------------------------------- |
| `feat`     | nouvelle fonctionnalité                |
| `fix`      | correction de bug                      |
| `docs`     | documentation                          |
| `ci`       | pipelines GitHub Actions / GitLab CI   |
| `build`    | Dockerfile, compose, dépendances       |
| `refactor` | refactoring sans changement fonctionnel|
| `test`     | ajout / modification de tests          |
| `chore`    | maintenance                            |

Exemples : `feat(api): add messages endpoint`, `ci: push images to ghcr`, `fix(frontend): handle backend down`.

Un changement cassant est signalé par `!` : `feat(api)!: rename /messages to /posts`.

## Releases

Versionnement [SemVer](https://semver.org/lang/fr/) `vMAJEUR.MINEUR.CORRECTIF` :

1. PR `dev` → `main`, review, merge → déploiement **production** automatique.
2. Tag de la version sur `main` :
   ```bash
   git switch main && git pull
   git tag -a v1.0.0 -m "v1.0.0"
   git push origin v1.0.0
   ```
3. La CI construit les images `:1.0.0` et `:1.0`, puis crée la **GitHub Release** avec les notes générées.
4. Rollback : redéployer un tag précédent (`IMAGE_TAG=1.0.0 ./deploy/deploy.sh`).

## Avant d'ouvrir une PR

```bash
cd backend  && npm run lint && npm run format:check && npm test
cd frontend && npm run lint && npm run format:check && npm run build
docker compose up -d --build   # vérification locale
```
