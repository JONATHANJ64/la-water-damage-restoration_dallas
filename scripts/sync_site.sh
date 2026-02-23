#!/usr/bin/env bash
set -euo pipefail

# Sync output/<SITE_SLUG>/ -> deploy-vercel/site/
# Idempotent and safe. Requires rsync.

SITE_SLUG="${SITE_SLUG:-water-damage-restoration_dallas}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/output/${SITE_SLUG}"
DEST_DIR="${ROOT_DIR}/deploy-vercel/site"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "ERROR: source not found: ${SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
rsync -a --delete "${SOURCE_DIR}/" "${DEST_DIR}/"

echo "Synced ${SOURCE_DIR} -> ${DEST_DIR}"
