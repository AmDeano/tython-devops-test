#!/usr/bin/env bash
# shellcheck disable=SC2029  # bghina les variables ytbdlo 3andi 9bel ma ymchiw f ssh
# deploy b SSH + docker compose 3la la VM dyal Proxmox (Option A)
# kaykhdem mn pc dyali wla mn GitHub Actions (job deploy)
#
# variables :
#   SSH_HOST (lazem)     IP dyal la VM
#   SSH_USER             user dyal deploy (par defaut : deploy)
#   SSH_PORT             port ssh (par defaut : 22)
#   IMAGE_TAG            tag li bghina ndeployiw (par defaut : latest)
#   DEPLOY_DIR           dossier f la VM (par defaut : /opt/tython)
#   GHCR_USER/GHCR_TOKEN bach la VM tpulli mn GHCR (ila les images privées)
#   WITH_MONITORING      1 bach n7ato prometheus/grafana m3aha (par defaut : 1)
#
# exemple : SSH_HOST=10.0.0.50 IMAGE_TAG=1.0.0 ./deploy/deploy.sh
set -euo pipefail

: "${SSH_HOST:?khass SSH_HOST}"
SSH_USER="${SSH_USER:-deploy}"
SSH_PORT="${SSH_PORT:-22}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/tython}"
WITH_MONITORING="${WITH_MONITORING:-1}"

SSH_OPTS=(-p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=10)
# f CI l cle kaytktb f ~/.ssh/id_deploy
[[ -f "$HOME/.ssh/id_deploy" ]] && SSH_OPTS+=(-i "$HOME/.ssh/id_deploy")
TARGET="${SSH_USER}@${SSH_HOST}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }

# ma kansiftoch l code kaml, ghir fichiers dyal infra (les images deja f GHCR)
# tar | ssh bach ma n7tajoch rsync f la VM
log "kansift fichiers dyal infra l ${TARGET}:${DEPLOY_DIR}"
tar -C "$ROOT_DIR" -czf - \
  docker-compose.prod.yml docker-compose.monitoring.yml nginx monitoring deploy/remote-deploy.sh \
  | ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p '$DEPLOY_DIR' && tar -xzf - -C '$DEPLOY_DIR'"

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  log "login GHCR f la VM"
  # token kaydouz f stdin, ma kayban la f ps la f historique
  printf '%s' "$GHCR_TOKEN" \
    | ssh "${SSH_OPTS[@]}" "$TARGET" "docker login ghcr.io -u '${GHCR_USER:?khass GHCR_USER}' --password-stdin" >/dev/null
fi

log "bdina deploy (tag ${IMAGE_TAG})"
ssh "${SSH_OPTS[@]}" "$TARGET" \
  "cd '$DEPLOY_DIR' && IMAGE_TAG='$IMAGE_TAG' WITH_MONITORING='$WITH_MONITORING' bash deploy/remote-deploy.sh"

log "safi tdeploya ✅"
