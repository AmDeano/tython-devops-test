#!/usr/bin/env bash
# shellcheck disable=SC2029  # expansion côté client voulue avant envoi SSH
# Déploiement SSH + Docker Compose sur la VM Proxmox (Option A).
# Utilisable depuis un poste développeur ou depuis GitHub Actions (job `deploy`).
#
# Variables :
#   SSH_HOST (requis)    IP/nom de la VM
#   SSH_USER             utilisateur de déploiement (défaut : deploy)
#   SSH_PORT             port SSH (défaut : 22)
#   IMAGE_TAG            tag des images à déployer (défaut : latest)
#   DEPLOY_DIR           répertoire sur la VM (défaut : /opt/tython)
#   GHCR_USER/GHCR_TOKEN identifiants lecture GHCR (optionnels si images publiques)
#   WITH_MONITORING      1 pour déployer aussi Prometheus/Grafana (défaut : 1)
#
# Exemple : SSH_HOST=10.0.0.50 IMAGE_TAG=1.0.0 ./deploy/deploy.sh
set -euo pipefail

: "${SSH_HOST:?SSH_HOST requis}"
SSH_USER="${SSH_USER:-deploy}"
SSH_PORT="${SSH_PORT:-22}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/tython}"
WITH_MONITORING="${WITH_MONITORING:-1}"

SSH_OPTS=(-p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=10)
[[ -f "$HOME/.ssh/id_deploy" ]] && SSH_OPTS+=(-i "$HOME/.ssh/id_deploy")
TARGET="${SSH_USER}@${SSH_HOST}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }

log "Copie des fichiers d'infrastructure vers ${TARGET}:${DEPLOY_DIR}"
tar -C "$ROOT_DIR" -czf - \
  docker-compose.prod.yml docker-compose.monitoring.yml nginx monitoring deploy/remote-deploy.sh \
  | ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p '$DEPLOY_DIR' && tar -xzf - -C '$DEPLOY_DIR'"

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  log "Authentification GHCR sur la VM"
  printf '%s' "$GHCR_TOKEN" \
    | ssh "${SSH_OPTS[@]}" "$TARGET" "docker login ghcr.io -u '${GHCR_USER:?GHCR_USER requis}' --password-stdin" >/dev/null
fi

log "Lancement du déploiement (tag ${IMAGE_TAG})"
ssh "${SSH_OPTS[@]}" "$TARGET" \
  "cd '$DEPLOY_DIR' && IMAGE_TAG='$IMAGE_TAG' WITH_MONITORING='$WITH_MONITORING' bash deploy/remote-deploy.sh"

log "Terminé ✅"
