#!/usr/bin/env bash
# shellcheck disable=SC1091  # .env est créé sur la VM, hors repo
# À lancer UNE fois sur la VM (dans /opt/tython) avant le premier déploiement HTTPS.
# nginx refuse de démarrer sans certificat : on crée un certificat auto-signé temporaire,
# on démarre nginx, on obtient le vrai certificat via le challenge HTTP-01, puis on recharge.
#
# Pré-requis : DNS du domaine pointant vers l'IP publique, ports 80/443 redirigés vers la VM.
# STAGING=1 pour tester contre l'environnement de test Let's Encrypt (pas de rate limit).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a; source .env; set +a
: "${DOMAIN:?DOMAIN manquant dans .env}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL manquant dans .env}"

COMPOSE=(docker compose --env-file .env -f docker-compose.prod.yml)
LIVE="/etc/letsencrypt/live/$DOMAIN"

echo "==> Certificat temporaire auto-signé pour $DOMAIN"
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "
  mkdir -p $LIVE &&
  [ -f $LIVE/fullchain.pem ] || openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout $LIVE/privkey.pem -out $LIVE/fullchain.pem -subj /CN=localhost"

echo "==> Démarrage de nginx"
"${COMPOSE[@]}" up -d proxy

echo "==> Suppression du certificat temporaire et demande Let's Encrypt"
STAGING_FLAG=""
[[ "${STAGING:-0}" == "1" ]] && STAGING_FLAG="--staging"
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "
  rm -rf /etc/letsencrypt/live/$DOMAIN /etc/letsencrypt/archive/$DOMAIN /etc/letsencrypt/renewal/$DOMAIN.conf &&
  certbot certonly --webroot -w /var/www/certbot $STAGING_FLAG \
    -d $DOMAIN --email $LETSENCRYPT_EMAIL --agree-tos --no-eff-email --non-interactive"

echo "==> Rechargement nginx"
"${COMPOSE[@]}" exec proxy nginx -s reload
echo "==> HTTPS actif sur https://$DOMAIN"
