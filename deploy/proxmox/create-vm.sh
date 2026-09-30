#!/usr/bin/env bash
# kaytlanca f node dyal Proxmox (b root)
# 1) kaycrea template cloud-init dyal Debian 12 (marra wa7da)
# 2) kayclonih VM jdida, kay7et reseau + user-data w kayt3alha
#
# exemple :
#   VMID=110 NAME=tython-prod IP=192.168.1.50/24 GW=192.168.1.1 ./create-vm.sh
set -euo pipefail

TEMPLATE_ID="${TEMPLATE_ID:-9000}"
VMID="${VMID:?khass VMID}"
NAME="${NAME:-tython-app}"
IP="${IP:?khass IP (ex: 192.168.1.50/24)}"
GW="${GW:?khass GW}"
STORAGE="${STORAGE:-local-lvm}"
SNIPPETS_STORAGE="${SNIPPETS_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-4096}"
DISK="${DISK:-30G}"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ila template deja kayn ma n3awdoch nsaybouh
if ! qm status "$TEMPLATE_ID" &>/dev/null; then
  echo "==> kancreyiw template cloud-init $TEMPLATE_ID"
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

# khass storage "local" ykon fih contenu Snippets m activé
echo "==> kancopiw user-data dyal cloud-init f snippets"
SNIPPETS_DIR="$(pvesm path "$SNIPPETS_STORAGE:snippets/x" | xargs dirname)"
mkdir -p "$SNIPPETS_DIR"
cp "$SCRIPT_DIR/../cloud-init/user-data.yml" "$SNIPPETS_DIR/tython-user-data.yml"

echo "==> clone $TEMPLATE_ID -> $VMID ($NAME)"
qm clone "$TEMPLATE_ID" "$VMID" --name "$NAME" --full true
qm set "$VMID" --cores "$CORES" --memory "$MEMORY" \
  --ipconfig0 "ip=$IP,gw=$GW" \
  --cicustom "user=$SNIPPETS_STORAGE:snippets/tython-user-data.yml" \
  --onboot 1
qm resize "$VMID" scsi0 "$DISK"
qm start "$VMID"

echo "==> VM $VMID tl3at. tsna chi 2-3 min 7ta cloud-init ysali docker :"
echo "    ssh deploy@${IP%/*} 'cloud-init status --wait && docker --version'"
