#!/usr/bin/env bash
# À exécuter sur le nœud Proxmox (shell root).
# 1) crée un template cloud-init Debian 12 (une seule fois)
# 2) clone le template en VM applicative, injecte réseau + user-data, démarre.
#
# Exemple :
#   VMID=110 NAME=tython-prod IP=192.168.1.50/24 GW=192.168.1.1 ./create-vm.sh
set -euo pipefail

TEMPLATE_ID="${TEMPLATE_ID:-9000}"
VMID="${VMID:?VMID requis}"
NAME="${NAME:-tython-app}"
IP="${IP:?IP requise (ex: 192.168.1.50/24)}"
GW="${GW:?GW requise}"
STORAGE="${STORAGE:-local-lvm}"
SNIPPETS_STORAGE="${SNIPPETS_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-4096}"
DISK="${DISK:-30G}"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! qm status "$TEMPLATE_ID" &>/dev/null; then
  echo "==> Création du template cloud-init $TEMPLATE_ID"
  wget -q -O /tmp/debian-12.qcow2 "$IMAGE_URL"
  qm create "$TEMPLATE_ID" --name debian12-cloudinit --memory 2048 --cores 2 \
    --net0 "virtio,bridge=$BRIDGE" --scsihw virtio-scsi-pci --agent enabled=1 \
    --serial0 socket --vga serial0 --ostype l26
  qm importdisk "$TEMPLATE_ID" /tmp/debian-12.qcow2 "$STORAGE"
  qm set "$TEMPLATE_ID" --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0" \
    --ide2 "$STORAGE:cloudinit" --boot order=scsi0
  qm template "$TEMPLATE_ID"
  rm -f /tmp/debian-12.qcow2
fi

echo "==> Copie du user-data cloud-init dans les snippets"
SNIPPETS_DIR="$(pvesm path "$SNIPPETS_STORAGE:snippets/x" | xargs dirname)"
mkdir -p "$SNIPPETS_DIR"
cp "$SCRIPT_DIR/../cloud-init/user-data.yml" "$SNIPPETS_DIR/tython-user-data.yml"

echo "==> Clone $TEMPLATE_ID -> $VMID ($NAME)"
qm clone "$TEMPLATE_ID" "$VMID" --name "$NAME" --full true
qm set "$VMID" --cores "$CORES" --memory "$MEMORY" \
  --ipconfig0 "ip=$IP,gw=$GW" \
  --cicustom "user=$SNIPPETS_STORAGE:snippets/tython-user-data.yml" \
  --onboot 1
qm resize "$VMID" scsi0 "$DISK"
qm start "$VMID"

echo "==> VM $VMID démarrée. Attendre ~2-3 min que cloud-init installe Docker :"
echo "    ssh deploy@${IP%/*} 'cloud-init status --wait && docker --version'"
