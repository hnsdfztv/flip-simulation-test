#!/usr/bin/env bash
set -euo pipefail

# Paper-aligned defaults:
# - Linux 6.6.116 (built image)
# - AArch64 Cortex-A57
# - single vCPU + 4G RAM
# - QMP socket + GDB stub + 9p shared dir

QEMU_BIN=${QEMU_BIN:-/opt/qemu-7.1.0/bin/qemu-system-aarch64}
KERNEL_IMG=${KERNEL_IMG:-/home/yyc/tools/src/linux-6.6.116/arch/arm64/boot/Image}
BASE_IMG=${BASE_IMG:-/home/yyc/lava-qemu-flip/images/base-ubuntu-jammy-arm64.qcow2}
OVERLAY_IMG=${OVERLAY_IMG:-/home/yyc/lava-qemu-flip/images/overlay-seu.qcow2}
SEED_ISO=${SEED_ISO:-/home/yyc/lava-qemu-flip/images/seed-seu.iso}
SHARE_DIR=${SHARE_DIR:-/home/yyc/flip_simulation}
QMP_SOCK=${QMP_SOCK:-/tmp/qmp.sock}
MON_SOCK=${MON_SOCK:-/tmp/qemu_socket}
GDB_PORT=${GDB_PORT:-1234}
SSH_FWD_PORT=${SSH_FWD_PORT:-2222}

if [[ ! -x "$QEMU_BIN" ]]; then
  echo "QEMU binary not found: $QEMU_BIN" >&2
  exit 1
fi
if [[ ! -f "$KERNEL_IMG" ]]; then
  echo "Kernel image not found: $KERNEL_IMG" >&2
  exit 1
fi
if [[ ! -f "$BASE_IMG" ]]; then
  echo "Base qcow2 not found: $BASE_IMG" >&2
  exit 1
fi
if [[ ! -f "$OVERLAY_IMG" ]]; then
  echo "Overlay qcow2 not found: $OVERLAY_IMG" >&2
  exit 1
fi
if [[ ! -f "$SEED_ISO" ]]; then
  echo "Seed ISO not found: $SEED_ISO" >&2
  exit 1
fi
if [[ ! -d "$SHARE_DIR" ]]; then
  echo "Share dir not found: $SHARE_DIR" >&2
  exit 1
fi

rm -f "$QMP_SOCK" "$MON_SOCK"

exec "$QEMU_BIN" \
  -cpu cortex-a57 \
  -machine virt \
  -m 4G \
  -smp 1 \
  -nographic \
  -append "console=ttyAMA0 root=/dev/vdb1 rootwait rw" \
  -kernel "$KERNEL_IMG" \
  -drive if=none,file="$OVERLAY_IMG",format=qcow2,id=vdisk0 \
  -device virtio-blk-device,drive=vdisk0 \
  -drive if=none,file="$SEED_ISO",format=raw,id=seed0 \
  -device virtio-blk-device,drive=seed0 \
  -netdev user,id=eth0,hostfwd=tcp::${SSH_FWD_PORT}-:22 \
  -device virtio-net-device,netdev=eth0 \
  -device virtio-serial-pci \
  -device pvpanic-pci \
  -qmp unix:"$QMP_SOCK",server=on,wait=off \
  -monitor unix:"$MON_SOCK",server,nowait \
  -action shutdown=pause,panic=none \
  -virtfs local,path="$SHARE_DIR",mount_tag=host0,security_model=passthrough,id=host0 \
  -gdb tcp::${GDB_PORT} \
  -S
