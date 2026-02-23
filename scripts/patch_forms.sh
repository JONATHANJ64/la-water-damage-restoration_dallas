#!/usr/bin/env bash
set -euo pipefail

# Rewrite form action. Modes:
#   MODE=vercel (default): action="/api/lead"
#   MODE=backend: action="https://<BACKEND_HOST>/api/lead"
# Ensure hidden input site_slug exists in all forms.

MODE="${MODE:-vercel}"
SITE_SLUG="${SITE_SLUG:-water-damage-restoration_dallas}"
BACKEND_HOST="${BACKEND_HOST:-api.example.com}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE_DIR="${ROOT_DIR}/deploy-vercel/site"

if [[ ! -d "${SITE_DIR}" ]]; then
  echo "ERROR: site dir not found: ${SITE_DIR}" >&2
  exit 1
fi

export MODE SITE_SLUG BACKEND_HOST SITE_DIR
python3 - <<'PY'
import os, re

site_dir = os.environ["SITE_DIR"]
site_slug = os.environ["SITE_SLUG"]
mode = os.environ["MODE"].lower()
backend_host = os.environ["BACKEND_HOST"]

if mode == "backend":
    action_value = f"https://{backend_host}/api/lead"
else:
    action_value = "/api/lead"

html_files = []
for root, _, files in os.walk(site_dir):
    for f in files:
        if f.lower().endswith(".html"):
            html_files.append(os.path.join(root, f))

form_open_re = re.compile(r"<form\b[^>]*>", re.IGNORECASE)
action_any_re = re.compile(r"(\saction=)([\"'])([^\"']*)([\"'])", re.IGNORECASE)
site_slug_input_re = re.compile(r"<input\b[^>]*name=[\"']site_slug[\"'][^>]*>", re.IGNORECASE)

for path in html_files:
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()

    # Replace existing action or insert one if missing
    if action_any_re.search(content):
        content = action_any_re.sub(rf"\1\2{action_value}\4", content)
    else:
        content = re.sub(r"(<form\b)", rf"\1 action=\"{action_value}\"", content, count=1, flags=re.IGNORECASE)

    # Ensure site_slug hidden input exists inside each form
    def ensure_site_slug(form_html: str) -> str:
        if site_slug_input_re.search(form_html):
            return form_html
        m = form_open_re.search(form_html)
        if not m:
            return form_html
        insert = f"{m.group(0)}\n  <input type=\"hidden\" name=\"site_slug\" value=\"{site_slug}\" />"
        return form_html[:m.start()] + insert + form_html[m.end():]

    rebuilt = []
    last = 0
    for match in form_open_re.finditer(content):
        start = match.start()
        rebuilt.append(content[last:start])
        end_idx = content.find("</form>", match.end())
        if end_idx == -1:
            rebuilt.append(content[start:])
            last = len(content)
            break
        end_idx += len("</form>")
        form_block = content[start:end_idx]
        rebuilt.append(ensure_site_slug(form_block))
        last = end_idx
    rebuilt.append(content[last:])

    new_content = "".join(rebuilt)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_content)

print(f"Patched forms in {len(html_files)} HTML files")
PY
