import type { VercelRequest, VercelResponse } from "@vercel/node";

type Lead = {
  site_slug?: string;
  name?: string;
  email?: string;
  phone?: string;
  service?: string;
  city?: string;
  message?: string;
  pageUrl?: string;
  utm?: Record<string, string | undefined>;
};

function isEmail(s?: string) {
  return !!s && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

function parseBody(req: VercelRequest): Lead {
  const ct = req.headers["content-type"] || "";
  if (typeof req.body === "string") {
    if (ct.includes("application/json")) {
      try {
        return JSON.parse(req.body) as Lead;
      } catch {
        return {} as Lead;
      }
    }
    if (ct.includes("application/x-www-form-urlencoded")) {
      const params = new URLSearchParams(req.body);
      return Object.fromEntries(params.entries()) as Lead;
    }
  }
  return (req.body || {}) as Lead;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "METHOD_NOT_ALLOWED" });
  }

  const body = parseBody(req);

  if (!body.name && !body.phone && !body.email) {
    return res.status(400).json({ ok: false, error: "MISSING_CONTACT" });
  }

  if (body.email && !isEmail(body.email)) {
    return res.status(400).json({ ok: false, error: "INVALID_EMAIL" });
  }

  const payload = {
    ...body,
    receivedAt: new Date().toISOString(),
    ip: req.headers["x-forwarded-for"] || req.socket.remoteAddress,
    userAgent: req.headers["user-agent"],
  };

  const webhook = process.env.LEAD_WEBHOOK_URL;

  try {
    if (webhook) {
      const r = await fetch(webhook, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!r.ok) {
        const t = await r.text().catch(() => "");
        return res
          .status(502)
          .json({ ok: false, error: "WEBHOOK_FAILED", detail: t.slice(0, 200) });
      }
    } else {
      console.log("LEAD_CAPTURED", payload);
    }

    return res.status(200).json({ ok: true });
  } catch {
    return res.status(500).json({ ok: false, error: "SERVER_ERROR" });
  }
}
