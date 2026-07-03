#!/usr/bin/env bash
# Forensic collection helper (defensive, read-only where possible)
# Usage (example): sudo ./collect_forensics.sh --collector "Alice" --evidence-dir /mnt/forensics --disk-device /dev/sda --net-duration 300
#
# IMPORTANT:
# - Run only in authorized Incident Response context.
# - Do NOT reboot the host before memory capture if RAM evidence is required.
# - Write evidence to an external, write-protected or isolated storage when possible.
# - This script is provided as-is. Review and adapt to your environment.

set -euo pipefail
IFS=$'\n\t'

# Defaults (edit as needed)
COLLECTOR="${COLLECTOR:-unassigned}"
EVIDENCE_BASE="${EVIDENCE_BASE:-/forensics}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
HOSTNAME="$(hostname -s)"
EVIDENCE_DIR="${EVIDENCE_DIR:-${EVIDENCE_BASE}/${HOSTNAME}_${TIMESTAMP}}"
DISK_DEVICE="${DISK_DEVICE:-}"       # e.g. /dev/sda ; leave empty to skip disk imaging
NET_DURATION="${NET_DURATION:-300}"  # seconds for tcpdump capture (default 5min)
SKIP_MEM="${SKIP_MEM:-0}"            # set to 1 to skip memory dump
SKIP_NET="${SKIP_NET:-0}"            # set to 1 to skip network capture
SKIP_DISK="${SKIP_DISK:-1}"          # default skip disk imaging; set to 0 to enable (requires DISK_DEVICE)
EXTERNAL_MOUNT="${EXTERNAL_MOUNT:-}" # optional mountpoint to ensure evidence saved externally

usage() {
  cat <<EOF
Usage: sudo $0 [options]
Options:
  --collector NAME         Name/email of collector (required)
  --evidence-dir PATH      Override evidence directory (default: $EVIDENCE_DIR)
  --disk-device DEVICE     Device to image (e.g. /dev/sda). If omitted, disk imaging skipped.
  --net-duration SECONDS   tcpdump capture duration in seconds (default: $NET_DURATION)
  --skip-mem               Skip memory dump
  --skip-net               Skip network capture
  --no-skip-disk           Enable disk imaging (requires --disk-device)
  --external-mount PATH    Path that must be mounted and writable for evidence
  --help                   Show this help
EOF
  exit 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --collector) COLLECTOR="$2"; shift 2;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2;;
    --disk-device) DISK_DEVICE="$2"; SKIP_DISK=0; shift 2;;
    --net-duration) NET_DURATION="$2"; shift 2;;
    --skip-mem) SKIP_MEM=1; shift;;
    --skip-net) SKIP_NET=1; shift;;
    --no-skip-disk) SKIP_DISK=0; shift;;
    --external-mount) EXTERNAL_MOUNT="$2"; shift 2;;
    --help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

if [[ -z "$COLLECTOR" || "$COLLECTOR" == "unassigned" ]]; then
  echo "ERROR: --collector is required."
  usage
fi

if [[ -n "$EXTERNAL_MOUNT" && ! -d "$EXTERNAL_MOUNT" ]]; then
  echo "ERROR: external mount $EXTERNAL_MOUNT not present. Aborting."
  exit 2
fi

# Safety confirmation
cat <<EOF
FOR FORENSIC COLLECTION:
 Host:        $HOSTNAME
 Evidence Dir:$EVIDENCE_DIR
 Collector:   $COLLECTOR
 Disk image:  ${DISK_DEVICE:-(none)}
 Memory dump: $( [[ "$SKIP_MEM" -eq 1 ]] && echo "SKIPPED" || echo "ENABLED" )
 Net capture: $( [[ "$SKIP_NET" -eq 1 ]] && echo "SKIPPED" || echo "ENABLED (duration ${NET_DURATION}s)" )
IMPORTANT: Do NOT reboot the host if memory capture is required.
Continue? [y/N]
EOF
read -r CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
  echo "Aborted by user."
  exit 0
fi

mkdir -p -- "$EVIDENCE_DIR"
chmod 700 "$EVIDENCE_DIR"

COC_LOG="${EVIDENCE_DIR}/chain_of_custody.txt"
echo "Collector: $COLLECTOR" > "$COC_LOG"
echo "Host: $HOSTNAME" >> "$COC_LOG"
echo "Timestamp: $TIMESTAMP" >> "$COC_LOG"
echo "Command line: $0 $*" >> "$COC_LOG"
echo "Start TimeUTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$COC_LOG"
echo "----" >> "$COC_LOG"

log_action() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $COLLECTOR | $*" >> "$COC_LOG"
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Helper to safe-copy files preserving metadata
safe_copy() {
  src="$1"; dst="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp --preserve=mode,timestamps,ownership "$src" "$dst" 2>/dev/null || cp -p "$src" "$dst"
    log_action "COPIED $src -> $dst"
  else
    echo "MISSING: $src" >> "${EVIDENCE_DIR}/missing_files.txt"
  fi
}

# 1) Basic host info
log_action "Collecting host info"
{
  echo "==== hostname/uname/date ===="
  hostname -f 2>/dev/null || true
  uname -a 2>/dev/null || true
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true
} > "${EVIDENCE_DIR}/host_info_${TIMESTAMP}.txt"
log_action "WROTE host_info"

# 2) Volatile state: processes, network, open files
log_action "Collecting process and network state"
ps auxww > "${EVIDENCE_DIR}/ps_aux_${TIMESTAMP}.txt" 2>/dev/null || true
log_action "WROTE ps"
if command -v pstree >/dev/null 2>&1; then
  pstree -alp > "${EVIDENCE_DIR}/pstree_${TIMESTAMP}.txt" 2>/dev/null || true
fi
if command -v ss >/dev/null 2>&1; then
  ss -tulpen > "${EVIDENCE_DIR}/ss_${TIMESTAMP}.txt" 2>/dev/null || true
else
  netstat -tulpen > "${EVIDENCE_DIR}/netstat_${TIMESTAMP}.txt" 2>/dev/null || true
fi
if command -v lsof >/dev/null 2>&1; then
  lsof -nP > "${EVIDENCE_DIR}/lsof_${TIMESTAMP}.txt" 2>/dev/null || true
fi

# 3) Firewall rules and unit files
log_action "Collecting firewall + systemd unit info"
if command -v iptables-save >/dev/null 2>&1; then
  iptables-save > "${EVIDENCE_DIR}/iptables_${TIMESTAMP}.txt" 2>/dev/null || true
fi
if command -v nft >/dev/null 2>&1; then
  nft list ruleset > "${EVIDENCE_DIR}/nft_ruleset_${TIMESTAMP}.txt" 2>/dev/null || true
fi
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-unit-files --state=enabled > "${EVIDENCE_DIR}/systemd_enabled_${TIMESTAMP}.txt" 2>/dev/null || true
fi

# 4) Capture running listeners related to common services (example: vsftpd)
log_action "Checking for vsftpd binary and computing hash if present"
VSFTPD_PATH=""
if command -v vsftpd >/dev/null 2>&1; then
  VSFTPD_PATH="$(command -v vsftpd)"
elif [[ -x "/usr/sbin/vsftpd" ]]; then
  VSFTPD_PATH="/usr/sbin/vsftpd"
fi
if [[ -n "$VSFTPD_PATH" ]]; then
  safe_copy "$VSFTPD_PATH" "${EVIDENCE_DIR}/binaries/$(basename "$VSFTPD_PATH")"
  if [[ -f "${EVIDENCE_DIR}/binaries/$(basename "$VSFTPD_PATH")" ]]; then
    sha256 "${EVIDENCE_DIR}/binaries/$(basename "$VSFTPD_PATH")" > "${EVIDENCE_DIR}/binaries/$(basename "$VSFTPD_PATH").sha256"
    log_action "SHA256 for vsftpd computed"
  fi
fi

# 5) Copy critical configs (read-only copy)
log_action "Copying configuration files (read-only)"
safe_copy /etc/vsftpd.conf "${EVIDENCE_DIR}/etc/vsftpd.conf" || true
safe_copy /etc/ssh/sshd_config "${EVIDENCE_DIR}/etc/sshd_config" || true
safe_copy /etc/passwd "${EVIDENCE_DIR}/etc/passwd" || true
# /etc/shadow contains secrets; copy only if IR policy allows
if [[ -r /etc/shadow ]]; then
  safe_copy /etc/shadow "${EVIDENCE_DIR}/etc/shadow"
fi

# 6) Logs (tar a selection to avoid partial locking); adjust as necessary
log_action "Archiving logs (may be large)"
LOG_TAR="${EVIDENCE_DIR}/logs_${TIMESTAMP}.tar.gz"
tar -czf "$LOG_TAR" /var/log 2>/dev/null || true
log_action "WROTE $LOG_TAR"

# 7) Crontabs and startup scripts
log_action "Collecting crontabs and startup items"
crontab -l > "${EVIDENCE_DIR}/crontab_root_${TIMESTAMP}.txt" 2>/dev/null || echo "no crontab for root" > "${EVIDENCE_DIR}/crontab_root_${TIMESTAMP}.txt"
for u in $(cut -d: -f1 /etc/passwd); do
  crontab -u "$u" -l > "${EVIDENCE_DIR}/crontab_${u}_${TIMESTAMP}.txt" 2>/dev/null || true
done
safe_copy /etc/rc.local "${EVIDENCE_DIR}/etc/rc.local" || true
cp -a /etc/init.d "${EVIDENCE_DIR}/etc_initd_backup" 2>/dev/null || true
cp -a /etc/systemd/system "${EVIDENCE_DIR}/etc_systemd_system_backup" 2>/dev/null || true

# 8) Network capture (bounded)
if [[ "$SKIP_NET" -eq 0 ]]; then
  if command -v tcpdump >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    PCAP_FILE="${EVIDENCE_DIR}/net_${TIMESTAMP}.pcap"
    log_action "Starting tcpdump for ${NET_DURATION}s -> $PCAP_FILE"
    timeout "${NET_DURATION}" tcpdump -i any -s 0 -w "$PCAP_FILE" 2> "${EVIDENCE_DIR}/tcpdump_stderr_${TIMESTAMP}.txt" || true
    log_action "tcpdump finished"
  else
    echo "tcpdump or timeout not available; skipping network capture" >> "${EVIDENCE_DIR}/notes.txt"
  fi
fi

# 9) Memory dump (if AVML present)
if [[ "$SKIP_MEM" -eq 0 ]]; then
  if command -v avml >/dev/null 2>&1; then
    MEM_FILE="${EVIDENCE_DIR}/mem_${TIMESTAMP}.avml"
    log_action "Running avml to collect memory -> $MEM_FILE"
    avml -o "$MEM_FILE"
    log_action "avml finished"
  else
    echo "avml not found. To capture memory, use AVML or LiME. Example (AVML): avml -o /forensics/${HOSTNAME}_mem_${TIMESTAMP}.avml" >> "${EVIDENCE_DIR}/notes.txt"
    echo "If using LiME, copy lime.ko appropriate to kernel and run insmod lime.ko path=... format=lime" >> "${EVIDENCE_DIR}/notes.txt"
  fi
fi

# 10) Optional disk imaging (dangerous/slow) - confirm again
if [[ "$SKIP_DISK" -eq 0 && -n "$DISK_DEVICE" ]]; then
  echo "DISK IMAGING requested for device: $DISK_DEVICE"
  echo "This is a potentially long and I/O heavy operation. Are you sure? [y/N]"
  read -r IMG_CONFIRM
  if [[ "${IMG_CONFIRM,,}" == "y" ]]; then
    IMAGE_FILE="${EVIDENCE_DIR}/disk_${TIMESTAMP}.dd"
    log_action "Starting disk image of $DISK_DEVICE -> $IMAGE_FILE"
    # Use dd with read-errors tolerated and moderate block size
    dd if="$DISK_DEVICE" of="$IMAGE_FILE" bs=4M conv=sync,noerror status=progress 2> "${EVIDENCE_DIR}/dd_stderr_${TIMESTAMP}.txt" || true
    log_action "Disk image completed (if dd returned successfully)"
    # compute hash
    if [[ -f "$IMAGE_FILE" ]]; then
      sha256 "$IMAGE_FILE" > "${IMAGE_FILE}.sha256" || true
      log_action "SHA256 for disk image computed"
    fi
  else
    echo "Disk imaging skipped by user." >> "${EVIDENCE_DIR}/notes.txt"
  fi
fi

# 11) Compute SHA256 for all collected files
log_action "Computing SHA256 checksums for evidence files"
find "$EVIDENCE_DIR" -type f ! -name "*.sha256" -print0 | while IFS= read -r -d '' f; do
  sumfile="${f}.sha256"
  if [[ ! -f "$sumfile" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$f" > "$sumfile" 2>/dev/null || true
    else
      shasum -a 256 "$f" > "$sumfile" 2>/dev/null || true
    fi
    log_action "HASHED $f"
  fi
done

# 12) Final packaging (optional)
echo
echo "Collection complete. Evidence directory: $EVIDENCE_DIR"
echo "Verify SHA256 files (.sha256) and move evidence to secure storage. Do not modify evidence files."
echo "Chain-of-custody log: $COC_LOG"
log_action "Collection finished"

# Print summary of evidence files
echo "Summary of top-level files:"
ls -lah -- "$EVIDENCE_DIR" | sed -n '1,200p'

exit 0