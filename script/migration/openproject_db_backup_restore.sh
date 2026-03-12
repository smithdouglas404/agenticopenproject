#!/usr/bin/env bash
set -euo pipefail

# OpenProject package-install (DEB/RPM) helper for DB backup + restore.
#
# This script is intended for one-time safety snapshots before running
# data backfill/repair scripts.
#
# Requirements:
# - package-based OpenProject installation with `openproject` command
# - user can execute sudo for openproject/pg_dump/pg_restore/service
#
# Usage:
#   # 1) create DB backup
#   ./openproject_db_backup_restore.sh backup
#
#   # 2) restore from that backup (destructive to current DB content)
#   ./openproject_db_backup_restore.sh restore /var/db/openproject/backup/manual-db/postgresql-dump-YYYYmmddTHHMMSSZ.pgdump
#
#   # skip interactive confirmation
#   ./openproject_db_backup_restore.sh restore /path/to/dump.pgdump --yes
#
# Notes:
# - Restore uses: pg_restore --clean --if-exists --no-owner
# - Service is stopped before restore and started after restore
# - This script backs up the database only (not attachments/config)

BACKUP_DIR_DEFAULT="/var/db/openproject/backup/manual-db"
SERVICE_NAME_DEFAULT="openproject"

BACKUP_DIR="${BACKUP_DIR:-$BACKUP_DIR_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"

usage() {
  cat <<'USAGE'
Usage:
  openproject_db_backup_restore.sh backup
  openproject_db_backup_restore.sh restore <dump_file.pgdump> [--yes]

Environment overrides:
  BACKUP_DIR   Default: /var/db/openproject/backup/manual-db
  SERVICE_NAME Default: openproject
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $cmd" >&2
    exit 1
  fi
}

db_url() {
  sudo openproject config:get DATABASE_URL
}

backup_db() {
  local ts dump_file url
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  dump_file="${BACKUP_DIR}/postgresql-dump-${ts}.pgdump"
  url="$(db_url)"

  echo "Creating DB backup..."
  echo "  backup_dir: ${BACKUP_DIR}"
  echo "  dump_file : ${dump_file}"

  sudo mkdir -p "${BACKUP_DIR}"
  sudo pg_dump \
    --format=custom \
    --no-owner \
    --file "${dump_file}" \
    --dbname "${url}"

  # Integrity checksum for auditability.
  sudo sha256sum "${dump_file}" | sudo tee "${dump_file}.sha256" >/dev/null

  echo "Backup complete:"
  echo "  ${dump_file}"
  echo "  ${dump_file}.sha256"
}

confirm_restore() {
  local dump_file="$1"
  local reply
  echo "WARNING: This will overwrite the current OpenProject database with:"
  echo "  ${dump_file}"
  echo "Type RESTORE to continue:"
  read -r reply
  if [[ "${reply}" != "RESTORE" ]]; then
    echo "Aborted."
    exit 1
  fi
}

restore_db() {
  local dump_file="$1"
  local yes_flag="${2:-}"
  local url

  if [[ ! -f "${dump_file}" ]]; then
    echo "ERROR: dump file not found: ${dump_file}" >&2
    exit 1
  fi

  if [[ "${yes_flag}" != "--yes" ]]; then
    confirm_restore "${dump_file}"
  fi

  url="$(db_url)"

  echo "Stopping service: ${SERVICE_NAME}"
  sudo service "${SERVICE_NAME}" stop

  echo "Restoring DB from ${dump_file}"
  sudo pg_restore \
    --clean \
    --if-exists \
    --no-owner \
    --dbname "${url}" \
    "${dump_file}"

  echo "Starting service: ${SERVICE_NAME}"
  sudo service "${SERVICE_NAME}" start

  echo "Restore complete."
}

main() {
  require_cmd sudo
  require_cmd openproject
  require_cmd pg_dump
  require_cmd pg_restore
  require_cmd sha256sum
  require_cmd service

  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    backup)
      if [[ $# -ne 1 ]]; then
        usage
        exit 1
      fi
      backup_db
      ;;
    restore)
      if [[ $# -lt 2 || $# -gt 3 ]]; then
        usage
        exit 1
      fi
      restore_db "$2" "${3:-}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
