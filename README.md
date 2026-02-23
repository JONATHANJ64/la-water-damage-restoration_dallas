# Deploy Vercel (Static + Serverless Lead Capture)

## Overview
This folder contains an idempotent, CLI-driven workflow to deploy a static site to Vercel, attach a custom domain, patch form actions to `/api/lead`, and validate `robots.txt` + `sitemap.xml`.

## Files
- `deploy-vercel/site/` static site files (synced from `output/<SITE_SLUG>/`)
- `deploy-vercel/scripts/sync_site.sh` syncs static site into `deploy-vercel/site/`
- `deploy-vercel/scripts/patch_forms.sh` updates form `action` and injects `site_slug`
- `deploy-vercel/scripts/deploy_vercel.sh` end-to-end deploy
- `deploy-vercel/vercel.json` Vercel static routing + cache headers (allows `/api/*`)
- `deploy-vercel/.env.example` env var template
- `api/lead.ts` Vercel serverless function for lead capture

## Environment
Copy `.env.example` to `.env` and export variables:

```bash
set -a
source deploy-vercel/.env
set +a
```

## DNS Records (for example.com)
Apex domain (root):
- Type: `A`
- Name: `@`
- Value: `76.76.21.21`

WWW subdomain:
- Type: `CNAME`
- Name: `www`
- Value: `cname.vercel-dns.com`

DNS validation:
```bash
dig +short A example.com
dig +short CNAME www.example.com
```

## Search Console Manual Steps
1. Go to Google Search Console.
2. Add a property as **Domain**: `example.com`.
3. Verify via DNS TXT record (copy value from Search Console into your DNS provider).
4. After verification, submit sitemap: `https://example.com/sitemap.xml`.

## Optional Automation Stub (Search Console)
```bash
ACCESS_TOKEN="$(gcloud auth print-access-token)"
SITE_URL="https://example.com/"
SITEMAP_URL="https://example.com/sitemap.xml"

curl -sS -X PUT \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://searchconsole.googleapis.com/webmasters/v3/sites/${SITE_URL//\//%2F}/sitemaps/${SITEMAP_URL//\//%2F}"
```

## Verification
```bash
curl -sS -o /dev/null -w "robots.txt HTTP %{http_code}\n" https://example.com/robots.txt
curl -sS -o /dev/null -w "sitemap.xml HTTP %{http_code}\n" https://example.com/sitemap.xml
curl -sS https://example.com/sitemap.xml | head -n 5
```
