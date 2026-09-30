# Déploiement sur Proxmox

Méthode retenue : **Option C (cloud-init) pour provisionner la VM + Option A (SSH + Docker Compose) pour déployer**, automatisée par GitHub Actions (CD).

| Étape | Outil | Fichier |
| --- | --- | --- |
| Créer la VM | Proxmox `qm` + template cloud-init | `deploy/proxmox/create-vm.sh` |
| *ou* créer un LXC (lab sans KVM) | Proxmox `pct` | `deploy/proxmox/create-lxc.sh` |
| Bootstrap VM (Docker, user, pare-feu) | cloud-init | `deploy/cloud-init/user-data.yml` |
| Déployer une version | SSH + `docker compose` | `deploy/deploy.sh` → `deploy/remote-deploy.sh` |
| HTTPS | Let's Encrypt (certbot) | `deploy/init-letsencrypt.sh` |
| Stack de prod | Docker Compose | `docker-compose.prod.yml` (+ `docker-compose.monitoring.yml`) |

**Pourquoi ce choix ?** Une VM (plutôt qu'un LXC) isole complètement le noyau et évite les réglages `nesting/keyctl` nécessaires à Docker en LXC non privilégié. cloud-init rend la VM reproductible (détruire/recréer en 3 min). SSH + Compose reste simple, lisible et sans agent ; Ansible serait le prochain pas pour gérer plusieurs VM.

Environnements : **staging** (branche `dev`) et **production** (branche `main`), sur deux VM identiques (ou la même VM avec deux `DEPLOY_DIR`/domaines).

### Variante lab : Proxmox imbriqué dans VMware (LXC)

Pour la démonstration, Proxmox VE tourne lui-même dans une VM VMware Workstation. Sous Windows avec Docker Desktop/WSL2 (Hyper-V actif), VMware ne peut pas exposer VT-x au Proxmox imbriqué : les VM KVM sont impossibles, mais les **conteneurs LXC** fonctionnent (pas besoin de virtualisation matérielle). On déploie donc dans un LXC Debian 12 non privilégié avec `nesting=1,keyctl=1` pour Docker :

```bash
# sur le nœud Proxmox
CTID=120 IP=192.168.x.60/24 GW=192.168.x.2 SSH_PUBKEY=/root/tython_deploy.pub ./deploy/proxmox/create-lxc.sh
```

Sans domaine public, `remote-deploy.sh` génère automatiquement un **certificat auto-signé** : HTTPS, HSTS, headers et rate limit sont actifs, seul le certificat n'est pas reconnu par le navigateur. Le runner GitHub ne pouvant pas joindre ce réseau privé, le déploiement se lance depuis le poste (`deploy.sh`) ou via un *self-hosted runner*.

---

## 1. Provisionner la VM (sur le nœud Proxmox)

Pré-requis : un stockage autorisant le contenu *Snippets* (`Datacenter → Storage → local → Content → Snippets`).

1. Générer une paire de clés dédiée au déploiement (sur votre poste) :
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/tython_deploy -C deploy@tython -N ""
   ```
2. Coller la **clé publique** dans `deploy/cloud-init/user-data.yml` (`ssh_authorized_keys`).
3. Copier le dossier `deploy/` sur le nœud Proxmox puis :
   ```bash
   cd deploy/proxmox
   VMID=110 NAME=tython-prod    IP=192.168.1.50/24 GW=192.168.1.1 ./create-vm.sh
   VMID=111 NAME=tython-staging IP=192.168.1.51/24 GW=192.168.1.1 ./create-vm.sh   # optionnel
   ```
   Le script crée (une fois) le template `9000` à partir de l'image cloud Debian 12, le clone, configure réseau + user-data, redimensionne le disque et démarre la VM.
4. Vérifier le bootstrap :
   ```bash
   ssh -i ~/.ssh/tython_deploy deploy@192.168.1.50 'cloud-init status --wait && docker compose version && sudo ufw status'
   ```

cloud-init installe : Docker Engine + Compose, utilisateur `deploy` (clé SSH uniquement, groupe docker), SSH durci (pas de root, pas de mot de passe), UFW (22/80/443), fail2ban, unattended-upgrades, qemu-guest-agent, rotation des logs Docker au niveau du démon.

<details>
<summary>Sans cloud-init (VM Ubuntu/Debian installée à la main)</summary>

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo adduser --disabled-password deploy && sudo usermod -aG docker deploy
sudo mkdir -p /opt/tython && sudo chown deploy:deploy /opt/tython
# + ajouter la clé publique dans /home/deploy/.ssh/authorized_keys
```
</details>

## 2. Réseau

- Enregistrement DNS `A` : `app.example.com → IP publique`.
- Redirection NAT (box/pare-feu) des ports **80** et **443** vers la VM. Rien d'autre.
- Grafana/Prometheus ne sont **pas** exposés : accès par tunnel SSH
  `ssh -L 3001:127.0.0.1:3001 deploy@192.168.1.50` → <http://localhost:3001>.

## 3. Secrets sur la VM (une seule fois)

Le `.env` de production n'existe **que** sur la VM (jamais dans git, jamais dans la CI) :

```bash
ssh deploy@192.168.1.50
mkdir -p /opt/tython && cd /opt/tython
cat > .env <<'EOF'
POSTGRES_DB=tython
POSTGRES_USER=tython
POSTGRES_PASSWORD=<openssl rand -hex 24>
IMAGE_REGISTRY=ghcr.io/amdeano/tython-devops-test
IMAGE_TAG=latest
DOMAIN=app.example.com
LETSENCRYPT_EMAIL=admin@example.com
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<openssl rand -hex 16>
EOF
chmod 600 .env
```

> `IMAGE_REGISTRY` doit être en **minuscules** (contrainte des registres Docker).

## 4. Premier déploiement (manuel, depuis votre poste)

```bash
export SSH_HOST=192.168.1.50 SSH_USER=deploy
cp ~/.ssh/tython_deploy ~/.ssh/id_deploy        # deploy.sh utilise ~/.ssh/id_deploy s'il existe
# Si les packages GHCR sont privés : token GitHub avec le scope read:packages
export GHCR_USER=AmDeano GHCR_TOKEN=<token>

IMAGE_TAG=latest ./deploy/deploy.sh             # copie compose/nginx/monitoring, cert auto-signé si absent, pull, up --wait
ssh deploy@$SSH_HOST 'cd /opt/tython && bash deploy/init-letsencrypt.sh'   # avec domaine public : remplace par Let's Encrypt
```

Tester d'abord Let's Encrypt en mode test : `STAGING=1 bash deploy/init-letsencrypt.sh`.

`deploy.sh` :
1. envoie via `tar | ssh` les fichiers d'infra (`docker-compose.prod.yml`, `docker-compose.monitoring.yml`, `nginx/`, `monitoring/`, `deploy/remote-deploy.sh`) dans `/opt/tython` ;
2. `docker login ghcr.io` si un token est fourni ;
3. lance `remote-deploy.sh` sur la VM, qui :
   - crée un certificat auto-signé si aucun n'existe (nginx ne démarre pas sans) ;
   - `docker compose pull` du tag demandé ;
   - `docker compose up -d --remove-orphans --wait` (redémarre uniquement ce qui change, attend que **tous les healthchecks** soient verts) ;
   - en cas d'échec : affiche les logs et **rollback automatique** vers le tag précédent (`.deployed_tag`) ;
   - nettoie les images de plus de 7 jours.

## 5. Déploiement continu (GitHub Actions)

Le job `deploy` de `.github/workflows/ci.yml` exécute ce même `deploy.sh` après un pipeline vert :

- push `dev` → environnement GitHub **staging**
- push `main` (merge de PR) → environnement GitHub **production**
- tag d'image déployé : `sha-<commit>` (immuable, traçable)

Configuration GitHub :

1. *Settings → Environments* : créer `staging` et `production` (pour `production`, ajouter *Required reviewers* si on veut une validation manuelle).
2. Dans **chaque** environnement, secrets :
   | Secret | Valeur |
   | --- | --- |
   | `SSH_HOST` | IP de la VM (staging ou prod) |
   | `SSH_USER` | `deploy` |
   | `SSH_PORT` | `22` (optionnel) |
   | `SSH_PRIVATE_KEY` | contenu de `~/.ssh/tython_deploy` |
   | `SSH_KNOWN_HOSTS` | sortie de `ssh-keyscan -H <ip>` |
   | `GHCR_READ_TOKEN` | PAT `read:packages` (inutile si packages publics) |
3. *Settings → Variables* : `DEPLOY_ENABLED=true`, et `DOMAIN` par environnement.

Si le runner GitHub ne peut pas joindre la VM (réseau privé Proxmox), deux options :
- installer un **self-hosted runner** sur une machine du LAN et mettre `runs-on: self-hosted` dans le job `deploy` ;
- ou exposer SSH via un bastion / WireGuard / Tailscale.

## 6. Opérations courantes

```bash
cd /opt/tython
C="docker compose --env-file .env -f docker-compose.prod.yml -f docker-compose.monitoring.yml"

$C ps                                   # état + santé
$C logs -f --tail 100 backend           # logs
$C restart backend                      # redémarrage propre (SIGTERM → arrêt gracieux)
IMAGE_TAG=1.0.0 bash deploy/remote-deploy.sh   # rollback / déploiement d'une version précise
cat .deployed_tag                       # version en production

# Sauvegarde / restauration PostgreSQL
$C exec -T db pg_dump -U tython tython | gzip > backup-$(date +%F).sql.gz
gunzip -c backup-XXXX.sql.gz | $C exec -T db psql -U tython tython
```

Recommandé en complément : sauvegarde **vzdump** planifiée de la VM dans Proxmox (`Datacenter → Backup`) + `pg_dump` quotidien par cron.

## 7. Vérifications post-déploiement

```bash
curl -fsS https://app.example.com/health
curl -sI https://app.example.com | grep -Ei 'strict-transport|content-security|x-frame'
for i in $(seq 60); do curl -s -o /dev/null -w '%{http_code}\n' https://app.example.com/api/messages; done | sort | uniq -c   # des 429 apparaissent
nmap -Pn 192.168.1.50        # seuls 22, 80, 443 ouverts
```
