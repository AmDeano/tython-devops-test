#!/usr/bin/env bash
# had script kaytlanca F la VM (deploy.sh li kay3ayet lih)
# pull dyal les images, up, kanchofo healthchecks, w ila tfrga3 chi 7aja nrj3o l version l9dima
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE_TAG="${IMAGE_TAG:?khass IMAGE_TAG}"
WITH_MONITORING="${WITH_MONITORING:-1}"

[[ -f .env ]] || { echo "ERREUR : makaynch $(pwd)/.env (chof DEPLOYMENT.md)"; exit 1; }
chmod 600 .env

COMPOSE=(docker compose --env-file .env -f docker-compose.prod.yml)
[[ "$WITH_MONITORING" == "1" ]] && COMPOSE+=(-f docker-compose.monitoring.yml)

# version li khdama daba, bach nrj3o liha ila tra chi mouchkil
PREVIOUS_TAG="$(cat .deployed_tag 2>/dev/null || echo '')"

# nginx ma kaytl3ch bla certificat : ila mazal ma kaynch, ndiro wa7ed auto-signé
# (f lab bla domaine public kayb9a hwa, w f prod init-letsencrypt.sh kaybdlo b dyal let's encrypt)
ensure_cert() {
  local domain live
  domain="$(grep -E '^DOMAIN=' .env | cut -d= -f2-)"
  live="/etc/letsencrypt/live/${domain:?DOMAIN makaynch f .env}"
  "${COMPOSE[@]}" run --rm --no-deps --entrypoint sh certbot -c "
    [ -f $live/fullchain.pem ] || { mkdir -p $live && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout $live/privkey.pem -out $live/fullchain.pem -subj /CN=$domain && echo '==> certificat auto-signé tcrea'; }"
}

deploy_tag() {
  export IMAGE_TAG="$1"
  echo "==> pull dyal les images (tag $IMAGE_TAG)"
  "${COMPOSE[@]}" pull --quiet || return 1
  echo "==> docker compose up -d"
  # --wait : kaytsna 7ta ykono ga3 les healthchecks khdrin (db, backend, frontend, proxy)
  "${COMPOSE[@]}" up -d --remove-orphans --wait --wait-timeout 180 || return 1
}

ensure_cert

if deploy_tag "$IMAGE_TAG"; then
  echo "$IMAGE_TAG" > .deployed_tag
  echo "==> deploy mzyan ($IMAGE_TAG)"
  "${COMPOSE[@]}" ps
  # n7aydo les images l9dam (kter mn 7 iyam) bach ma y3mrch disque
  docker image prune -f --filter "until=168h" >/dev/null
else
  echo "!!! deploy dyal $IMAGE_TAG tfrga3"
  "${COMPOSE[@]}" logs --tail 50 --no-color || true
  if [[ -n "$PREVIOUS_TAG" ]]; then
    echo "==> rollback l $PREVIOUS_TAG"
    deploy_tag "$PREVIOUS_TAG"
  fi
  exit 1
fi
