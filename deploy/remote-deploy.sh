#!/usr/bin/env bash
# Exécuté SUR la VM par deploy.sh. Pull des images, redémarrage propre, vérification
# de santé et rollback automatique vers le tag précédent en cas d'échec.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG requis}"
WITH_MONITORING="${WITH_MONITORING:-1}"

[[ -f .env ]] || { echo "ERREUR : $(pwd)/.env absent (voir DEPLOYMENT.md)"; exit 1; }
chmod 600 .env

COMPOSE=(docker compose --env-file .env -f docker-compose.prod.yml)
[[ "$WITH_MONITORING" == "1" ]] && COMPOSE+=(-f docker-compose.monitoring.yml)

PREVIOUS_TAG="$(cat .deployed_tag 2>/dev/null || echo '')"

deploy_tag() {
  export IMAGE_TAG="$1"
  echo "==> Pull des images (tag $IMAGE_TAG)"
  "${COMPOSE[@]}" pull --quiet || return 1
  echo "==> docker compose up -d"
  # --wait : attend que les healthchecks soient au vert (db, backend, frontend, proxy).
  "${COMPOSE[@]}" up -d --remove-orphans --wait --wait-timeout 180 || return 1
}

if deploy_tag "$IMAGE_TAG"; then
  echo "$IMAGE_TAG" > .deployed_tag
  echo "==> Déploiement OK ($IMAGE_TAG)"
  "${COMPOSE[@]}" ps
  docker image prune -f --filter "until=168h" >/dev/null
else
  echo "!!! Échec du déploiement de $IMAGE_TAG"
  "${COMPOSE[@]}" logs --tail 50 --no-color || true
  if [[ -n "$PREVIOUS_TAG" ]]; then
    echo "==> Rollback vers $PREVIOUS_TAG"
    deploy_tag "$PREVIOUS_TAG"
  fi
  exit 1
fi
