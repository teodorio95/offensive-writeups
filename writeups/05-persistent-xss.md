# 05 — Persistent (stored) XSS via the API

| | |
|---|---|
| **Target** | OWASP Juice Shop @ `http://<mac-ip>:8081` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | OWASP A03:2021 — Injection (Cross-Site Scripting) |
| **Tools** | Burp, browser |
| **Date** | 2026-06-23 |

## 1. Recon

The UI sanitizes some inputs client-side — but the **REST API** behind it may
not. The trick to *stored* XSS is to **bypass the client and POST straight to the
API**, so an unsanitized payload is persisted and later rendered to every viewer.

Candidate sinks: product fields (`/api/Products`), the order/feedback comment,
etc. Capture a legitimate request in Burp first to learn the shape.

## 2. Vulnerability

Stored XSS happens when attacker input is **saved** and later **rendered without
output encoding**. Relying on **client-side** sanitization is the root cause:
anything that talks to the API directly skips it entirely.

## 3. Exploitation

POST the payload directly to the API (not via the form), e.g. into a product:

```http
POST /api/Products HTTP/1.1
Content-Type: application/json
Authorization: Bearer <token>

{"name":"xss","description":"<iframe src=\"javascript:alert(`xss`)\">","price":1}
```

When any user opens the page that renders that field, the `<iframe>` executes —
**persistently**, for everyone, until the record is cleaned.

> _evidence: ./assets/05-stored-xss-alert.png (the alert firing for a normal
> user) + the solved "API-only / Stored XSS" challenge on the score board_

## 4. Impact

Persistent XSS runs attacker JS in **every victim's browser**: session/token
theft, account takeover, keylogging, defacement, drive-by actions performed as
the victim. Worse than reflected XSS because no per-victim lure is needed.

## 5. Remediation

- **Code fix:** **output-encode** on render (context-aware) and **sanitize on
  the server**, never only client-side. Treat all stored content as untrusted on
  the way out. Add a **Content-Security-Policy** so injected inline scripts can't
  run:
  ```
  Content-Security-Policy: default-src 'self'; script-src 'self'; frame-src 'none'
  ```
- **Shift-left (#2):** Semgrep flags unescaped rendering of user data; ZAP (DAST)
  detects reflected/stored XSS and a missing CSP header — gating the build.
- **Platform (#1):** CSP at the ingress + network egress default-deny limits what
  injected JS can exfiltrate to.

## References

- OWASP XSS Prevention Cheat Sheet; "Pwning OWASP Juice Shop" — XSS challenges
- OWASP A03:2021 — Injection
