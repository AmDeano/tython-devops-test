#!/usr/bin/env bash
# shellcheck disable=SC1091  # .env kaytcrea f la VM, machi f repo
# kanlanciwh MARRA WA7DA f la VM (f /opt/tython) 9bel awel deploy b https
# nginx ma kaybghich ytl3 bla certificat, donc :
#   1) ndiro certificat auto-signé mo2a9at
#   2) nlanciw nginx
#   3) njibo certificat s7i7 mn let's encrypt (challenge http-01) w n3awdo nchargiw nginx
#
# khass : DNS dyal domaine kaypointi 3la IP publique, w ports 80/443 m7wlin l la VM
# STAGING=1 bach ntestiw m3a staging dyal let's encrypt (bla rate limit)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a; source .env; set +a
: "${DOMAIN:?DOMAIN makaynch f .env}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL makaynch f .env}"

COMPOSE=(docker compose --env-file .env -f docker-compose.prod.yml)
LIVE="/etc/letsencrypt/live/$DOMAIN"

echo "==> certificat auto-signé mo2a9at l $DOMAIN"
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "
  mkdir -p $LIVE &&
  [ -f $LIVE/fullchain.pem ] || openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout $LIVE/privkey.pem -out $LIVE/fullchain.pem -subj /CN=localhost"

echo "==> kanlanciw nginx"
"${COMPOSE[@]}" up -d proxy

echo "==> kan7aydo lmo2a9at w kantlbo certificat mn let's encrypt"
STAGING_FLAG=""
[[ "${STAGING:-0}" == "1" ]] && STAGING_FLAG="--staging"
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "
  rm -rf /etc/letsencrypt/live/$DOMAIN /etc/letsencrypt/archive/$DOMAIN /etc/letsencrypt/renewal/$DOMAIN.conf &&
  certbot certonly --webroot -w /var/www/certbot $STAGING_FLAG \
    -d $DOMAIN --email $LETSENCRYPT_EMAIL --agree-tos --no-eff-email --non-interactive"

echo "==> reload dyal nginx"
"${COMPOSE[@]}" exec proxy nginx -s reload
echo "==> https khdam : https://$DOMAIN"
