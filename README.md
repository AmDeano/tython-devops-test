# Tython DevOps Demo

[![CI/CD](https://github.com/<github-user>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<github-user>/<repo>/actions/workflows/ci.yml)

Chaîne DevOps complète **build → test → packaging → déploiement → monitoring** pour une application web minimale :

- **Frontend** : React 18 + Vite, servi par nginx (non-root)
- **Backend** : Node.js 22 + Express (`/health`, `/health/ready`, `/metrics`, `/api/messages`)
- **Base de données** : PostgreSQL 16
- **CI/CD** : GitHub Actions (+ GitLab CI en miroir)
- **Déploiement** : VM Proxmox (cloud-init) + SSH + Docker Compose
- **Observabilité** : Prometheus + Grafana + node-exporter + cAdvisor, healthchecks, rotation des logs

## Architecture

```
                    Internet
                       │ 80/443
             ┌─────────▼─────────┐
             │  proxy (nginx)    │  TLS Let's Encrypt, rate limit, headers sécurité
             └─────────┬─────────┘          (prod uniquement)
       réseau frontend │
             ┌─────────▼─────────┐
             │ frontend (nginx)  │  SPA React + relais /api → backend
             └─────────┬─────────┘
             ┌─────────▼─────────┐        ┌──────────────┐
             │ backend (Express) │◀───────│  Prometheus  │──▶ Grafana (127.0.0.1:3001)
             └─────────┬─────────┘ scrape └──────────────┘
       réseau backend  │ (internal: true, aucun accès externe)
             ┌─────────▼─────────┐
             │   db (Postgres)   │  volume db-data
             └───────────────────┘
```

Seul le point d'entrée HTTP est publié. PostgreSQL et le backend ne sont **jamais** exposés sur l'hôte.

## Structure

```
.
├── backend/                  API Express + Dockerfile multi-stage + tests (node:test)
├── frontend/                 React/Vite + Dockerfile multi-stage + nginx.conf
├── db/                       Image PostgreSQL + schéma init.sql
├── nginx/                    Reverse proxy de prod (template, headers, rate limit)
├── monitoring/               Config Prometheus (+ alertes) et Grafana (provisioning + dashboard)
├── deploy/
│   ├── deploy.sh             Déploiement SSH + docker compose (local ou CI)
│   ├── remote-deploy.sh      Exécuté sur la VM : pull, up --wait, rollback
│   ├── init-letsencrypt.sh   Premier certificat HTTPS
│   ├── proxmox/create-vm.sh  Template cloud-init + clone de VM sur Proxmox
│   └── cloud-init/           user-data (Docker, user deploy, UFW, SSH durci)
├── docker-compose.yml             Stack locale (build depuis les sources)
├── docker-compose.prod.yml        Stack prod (images GHCR + proxy TLS)
├── docker-compose.monitoring.yml  Overlay monitoring (local ou prod)
├── .github/workflows/ci.yml       CI/CD GitHub Actions
├── .github/workflows/mirror-gitlab.yml  Synchronisation GitHub → GitLab
├── .gitlab-ci.yml                 Pipeline GitLab (bonus)
├── .env.example
├── CONTRIBUTING.md  DEPLOYMENT.md
```

## Démarrage local

Pré-requis : Docker + Docker Compose v2 (Node 22 uniquement pour développer hors Docker).

```bash
cp .env.example .env              # puis changer les mots de passe
docker compose up -d --build
```

- Application : <http://localhost:8080> (port modifiable via `FRONTEND_PORT` dans `.env`)
- Santé : <http://localhost:8080/health>

Avec le monitoring :

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
```

- Grafana : <http://localhost:3001> (identifiants `GRAFANA_ADMIN_*` du `.env`) → dossier **Tython** → dashboard « Vue d'ensemble »
- Prometheus : <http://localhost:9090/targets>

## Commandes utiles

| Commande | Rôle |
| --- | --- |
| `docker compose ps` | état + santé des conteneurs |
| `docker compose logs -f backend` | logs du backend |
| `docker compose down` | arrêt (données conservées) |
| `docker compose down -v` | arrêt + suppression des volumes |
| `docker compose exec db psql -U tython tython` | console SQL |
| `cd backend && npm ci && npm test` | tests backend |
| `cd backend && npm run lint` / `cd frontend && npm run lint` | ESLint |
| `cd frontend && npm run dev` | frontend en dev (proxy vers `localhost:3000`) |

## CI/CD (GitHub Actions)

`.github/workflows/ci.yml` :

| Déclencheur | Jobs |
| --- | --- |
| `pull_request` → `dev` | lint (ESLint + Prettier, front + back) · tests backend · build front/back · build Docker (sans push) · smoke test compose |
| `push` → `main` | idem + push GHCR (`latest`, `main`, `sha-…`) + déploiement **production** |
| `push` → `dev` | idem + push GHCR (`dev`, `sha-…`) + déploiement **staging** |
| tag `vX.Y.Z` | images `X.Y.Z` / `X.Y` + GitHub Release |

Le job **smoke-test** lance la vraie stack `docker compose` dans le runner et vérifie `/health`, `/health/ready` et un aller-retour API → base.

Le job **deploy** ne s'exécute que si la variable de repo `DEPLOY_ENABLED=true` (voir [DEPLOYMENT.md](DEPLOYMENT.md)) : la CI reste verte tant qu'aucun serveur n'est configuré.

Images publiées : `ghcr.io/<owner>/<repo>/{backend,frontend,db}`.

## Synchronisation GitHub ↔ GitLab

- **GitHub est la source de vérité** : PR, reviews, merges et tags s'y font.
- Le workflow `mirror-gitlab.yml` pousse **toutes les branches et tags** vers GitLab à chaque push (et supprime les branches supprimées, `--prune`).
- Sur GitLab, `.gitlab-ci.yml` exécute un pipeline équivalent (lint/test/build + images dans le registry GitLab) : double validation et plan de repli si GitHub est indisponible.
- On ne pousse jamais directement sur GitLab (protéger les branches côté GitLab : *Allowed to push* = Maintainers seulement, utilisé par le token de mirroring) → pas de divergence possible.

Configuration : créer un *Project Access Token* GitLab (rôle Maintainer, scope `write_repository`), puis dans GitHub → *Settings → Secrets → Actions* :
`GITLAB_MIRROR_URL=https://gitlab.com/<user>/<repo>.git` et `GITLAB_TOKEN=<token>`.

> Alternative : le *pull mirroring* natif de GitLab (*Settings → Repository → Mirroring repositories*), mais il est réservé à GitLab Premium et s'exécute avec un délai. Le workflow GitHub Actions est retenu car gratuit, immédiat, versionné et visible dans les logs de CI.

Branches, merges, commits et releases : voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Sécurité

- Aucun secret dans le repo : `.env` ignoré par git, `.env.example` fourni, secrets CI dans *GitHub Secrets / Environments*.
- Le backend lit toute sa config dans l'environnement et refuse de démarrer si une variable DB manque.
- Compose : chaque service ne reçoit que les variables dont il a besoin ; `${VAR:?}` bloque le démarrage si un secret manque.
- Images multi-stage, **non-root** (`node`, `nginx-unprivileged`), `read_only`, `cap_drop: ALL`, `no-new-privileges`, limites mémoire (prod).
- Réseau `backend` `internal: true` : la base n'a ni port publié ni accès Internet.
- `/metrics` non exposé publiquement ; Grafana/Prometheus liés à `127.0.0.1`.
- Reverse proxy : HTTPS Let's Encrypt (renouvellement auto), HSTS, CSP, X-Frame-Options, rate limit (`10 r/s` sur `/api`), `server_tokens off`, `helmet` côté Express.
- VM : SSH par clé uniquement, root désactivé, UFW (22/80/443), fail2ban, mises à jour de sécurité automatiques.

## Observabilité

- **Healthchecks** Docker sur chaque service (`/health` liveness, `/health/ready` readiness DB, `pg_isready`) + `restart: unless-stopped` + `depends_on: condition: service_healthy`.
- **Logs** : driver `json-file` avec rotation (`10m × 3–5 fichiers`), logs backend en JSON.
- **Métriques** : Prometheus scrape le backend (`prom-client` : latence, requêtes par route/statut, mémoire), node-exporter (VM), cAdvisor (conteneurs). Dashboard Grafana provisionné automatiquement + 3 règles d'alerte (backend down, taux de 5xx, disque).

## Preuves

Dans [`docs/preuves/`](docs/preuves/) :

- `verifications-locales.log` : lint, tests, build, stack compose saine, API fonctionnelle, cibles Prometheus `up`.
- Captures à ajouter : pipeline GitHub Actions vert, application accessible, dashboard Grafana.
