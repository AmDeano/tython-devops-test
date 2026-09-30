#!/usr/bin/env bash
# kaytlanca f node dyal Proxmox (b root)
# kaycrea conteneur LXC Debian 12 fih docker (nesting=1, keyctl=1), user deploy b cle ssh
# mzyan mli Proxmox mnsab west VMware/VirtualBox w KVM (VT-x) ma khdamch
#
# exemple :
#   CTID=120 IP=192.168.1.60/24 GW=192.168.1.1 SSH_PUBKEY=/root/tython_deploy.pub ./create-lxc.sh
set -euo pipefail

CTID="${CTID:?khass CTID}"
NAME="${NAME:-tython-app}"
IP="${IP:?khass IP (ex: 192.168.1.60/24)}"
GW="${GW:?khass GW}"
SSH_PUBKEY="${SSH_PUBKEY:?khass SSH_PUBKEY (fichier .pub)}"
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-3072}"
DISK="${DISK:-20}"

[[ -f "$SSH_PUBKEY" ]] || { echo "ma l9itch $SSH_PUBKEY"; exit 1; }

# kanjibo akhir template debian 12 (smiya katbdl m3a les versions)
echo "==> template debian 12"
pveam update >/dev/null
TEMPLATE="$(pveam available --section system | awk '/debian-12-standard/ {print $2}' | sort -V | tail -1)"
[[ -n "$TEMPLATE" ]] || { echo "ma l9itch template debian-12"; exit 1; }
pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE" || pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"

echo "==> kancreyiw CT $CTID ($NAME)"
# nesting + keyctl : bach docker ykhdem west LXC unprivileged
pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE" \
  --hostname "$NAME" --cores "$CORES" --memory "$MEMORY" --swap 512 \
  --rootfs "$STORAGE:$DISK" \
  --net0 "name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GW" \
  --nameserver 1.1.1.1 \
  --unprivileged 1 --features nesting=1,keyctl=1 \
  --ssh-public-keys "$SSH_PUBKEY" \
  --onboot 1
pct start "$CTID"
sleep 5

# nfs l7aja li kaydirha cloud-init f la VM
echo "==> kansaliw docker + user deploy"
pct exec "$CTID" -- bash -euo pipefail -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq curl ca-certificates sudo >/dev/null
  curl -fsSL https://get.docker.com | sh >/dev/null
  mkdir -p /etc/docker
  echo "{\"log-driver\":\"json-file\",\"log-opts\":{\"max-size\":\"10m\",\"max-file\":\"3\"}}" > /etc/docker/daemon.json
  systemctl restart docker
  id deploy &>/dev/null || useradd -m -s /bin/bash -G docker,sudo deploy
  echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
  cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
  chown deploy:deploy /home/deploy/.ssh/authorized_keys
  # ssh : ghir b cle, root mamnou3
  printf "PermitRootLogin no\nPasswordAuthentication no\n" > /etc/ssh/sshd_config.d/99-hardening.conf
  systemctl restart ssh
  mkdir -p /opt/tython && chown deploy:deploy /opt/tython
  docker run --rm hello-world >/dev/null && echo "docker khdam"
'

echo "==> CT $CTID wajd : ssh deploy@${IP%/*}"
