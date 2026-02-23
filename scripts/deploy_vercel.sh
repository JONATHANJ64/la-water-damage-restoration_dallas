#!/usr/bin/env bash
set -euo pipefail

# End-to-end deployment for static site on Vercel
# Idempotent: safe to run multiple times

SITE_SLUG="${SITE_SLUG:-water-damage-restoration_dallas}"
DOMAIN="${DOMAIN:-example.com}"
VERCEL_PROJECT_NAME="${VERCEL_PROJECT_NAME:-la-${SITE_SLUG}}"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_REPO="${GITHUB_REPO:-${VERCEL_PROJECT_NAME}}"
VERCEL_SCOPE="${VERCEL_SCOPE:-}"
VERCEL_SCOPE_FLAG=""
LEAD_CAPTURE_MODE="${LEAD_CAPTURE_MODE:-vercel}"
BACKEND_HOST="${BACKEND_HOST:-api.example.com}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_DIR="${ROOT_DIR}/deploy-vercel"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command $1" >&2; exit 1; }
}

require_cmd git
require_cmd gh
require_cmd vercel
require_cmd rsync
require_cmd python3

if [[ -z "${GITHUB_ORG}" ]]; then
  GITHUB_ORG="$(gh api user -q .login 2>/dev/null || true)"
fi
if [[ -z "${GITHUB_ORG}" ]]; then
  GITHUB_ORG="my-github-user"
fi

if [[ -n "${VERCEL_SCOPE}" ]]; then
  VERCEL_SCOPE_FLAG="--scope ${VERCEL_SCOPE}"
fi

# 1) Sync site
SITE_SLUG="${SITE_SLUG}" "${DEPLOY_DIR}/scripts/sync_site.sh"

# 2) Patch forms
MODE="${LEAD_CAPTURE_MODE}" SITE_SLUG="${SITE_SLUG}" BACKEND_HOST="${BACKEND_HOST}" "${DEPLOY_DIR}/scripts/patch_forms.sh"

# 3) Initialize git repo in deploy-vercel
if [[ ! -d "${DEPLOY_DIR}/.git" ]]; then
  git -C "${DEPLOY_DIR}" init
  git -C "${DEPLOY_DIR}" branch -M main
fi

# 4) Create or reuse GitHub repo
if ! gh repo view "${GITHUB_ORG}/${GITHUB_REPO}" >/dev/null 2>&1; then
  gh repo create "${GITHUB_ORG}/${GITHUB_REPO}" --public --confirm
fi

# 5) Commit and push
if git -C "${DEPLOY_DIR}" remote get-url origin >/dev/null 2>&1; then
  git -C "${DEPLOY_DIR}" remote set-url origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
else
  git -C "${DEPLOY_DIR}" remote add origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
fi

git -C "${DEPLOY_DIR}" add -A
if ! git -C "${DEPLOY_DIR}" diff --cached --quiet; then
  git -C "${DEPLOY_DIR}" commit -m "Deploy ${SITE_SLUG}"
fi

git -C "${DEPLOY_DIR}" push -u origin main

# 6) Create or reuse Vercel project
PROJECT_EXISTS="$(vercel project ls --json ${VERCEL_SCOPE_FLAG} 2>/dev/null | python3 - <<PY
import json, sys
try:
    data = json.load(sys.stdin)
    exists = any(p.get('name') == '${VERCEL_PROJECT_NAME}' for p in data)
    print('yes' if exists else 'no')
except Exception:
    print('no')
PY
)"

if [[ "${PROJECT_EXISTS}" != "yes" ]]; then
  vercel project add "${VERCEL_PROJECT_NAME}" ${VERCEL_SCOPE_FLAG}
fi

# 7) Link local directory to Vercel project
vercel link --project "${VERCEL_PROJECT_NAME}" ${VERCEL_SCOPE_FLAG} --yes

# 8) Attempt GitHub integration (non-fatal if unavailable)
vercel git connect ${VERCEL_SCOPE_FLAG} >/dev/null 2>&1 || true

# 9) Deploy to production without git metadata (avoid author permission errors)
TMP_DIR="$(mktemp -d)"
rsync -a --delete --exclude=".git" "${DEPLOY_DIR}/" "${TMP_DIR}/"
DEPLOY_URL="$(vercel --prod --cwd "${TMP_DIR}" ${VERCEL_SCOPE_FLAG} | tail -n1)"
rm -rf "${TMP_DIR}"

# 10) Add custom domain
vercel domains add "${DOMAIN}" ${VERCEL_SCOPE_FLAG} >/dev/null 2>&1 || true
vercel project domains add "${VERCEL_PROJECT_NAME}" "${DOMAIN}" ${VERCEL_SCOPE_FLAG} >/dev/null 2>&1 || true

# Output
printf "\nVercel Project: %s\n" "${VERCEL_PROJECT_NAME}"
printf "Vercel Deploy URL: %s\n" "${DEPLOY_URL}"
printf "Custom Domain: https://%s\n" "${DOMAIN}"
