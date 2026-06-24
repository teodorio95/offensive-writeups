# 03 — JWT forgery (auth bypass via token tampering)

| | |
|---|---|
| **Target** | OWASP Juice Shop @ `http://<mac-ip>:8081` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | OWASP A07:2021 — Identification & Authentication Failures |
| **Tools** | Browser devtools, Burp, [jwt.io](https://jwt.io) / `jwt_tool` |
| **Date** | 2026-06-23 |

## 1. Recon

After logging in, the API returns a **JWT** used as the bearer token. Grab it
from the `Authorization: Bearer <token>` header (Burp) or `localStorage`. A JWT
has three base64url parts: `header.payload.signature`. Decode the header:

```json
{ "typ": "JWT", "alg": "RS256" }
```

So the server signs tokens with **RS256** (RSA private key). The matching
**public key is shipped/known** — that's the crack we'll exploit.

## 2. Vulnerability

JWT verification is only safe if the server **pins the algorithm** and verifies
the signature with the right key. Two classic flaws Juice Shop demonstrates:

- **`alg: none`** — if the server accepts an "unsigned" token, anyone can forge claims.
- **RS256 → HS256 key confusion** — if the server verifies with whatever the
  header says, an attacker signs an **HS256** token using the **public** key as
  the HMAC secret (the public key is, by definition, public).

## 3. Exploitation

**Unsigned-token variant (`alg: none`):** craft a token, set header
`{"alg":"none","typ":"JWT"}`, payload with the victim's identity, empty signature:

```json
header:  {"alg":"none","typ":"JWT"}
payload: {"data":{"email":"jwtn3d@juice-sh.op"},"iat":...}
signature: (empty)
```

Send it as `Authorization: Bearer <header>.<payload>.` — if accepted, you're
authenticated as a user that never logged in.

**Key-confusion variant (RS256→HS256):** take the server's RSA **public key**,
sign a forged payload with **HS256** using that public key as the secret:

```bash
# pseudo: HMAC-SHA256 over header.payload using the PUBLIC key as the key
jwt_tool <token> -X k -pk public.pem        # key-confusion attack mode
```

> _evidence: ./assets/03-jwt-forged-token.png (forged token accepted) and the
> solved "Forged ... JWT" challenge on the score board_

## 4. Impact

Full authentication bypass / impersonation **without credentials** — forge a
token for any user (including admin), bypassing login entirely. Tokens are the
keys to every authenticated API call.

## 5. Remediation

- **Code fix:** verify the signature with a **fixed, server-side algorithm** —
  never trust `alg` from the token. Reject `none`. For RS256, verify only with
  the RSA **public** key and **disallow HS256** for these tokens. Validate
  `exp`, `iss`, `aud`. Use a vetted library configured with an allow-list:
  ```js
  jwt.verify(token, publicKey, { algorithms: ["RS256"] }); // never ["none","HS256"]
  ```
- **Shift-left (#2):** Semgrep rules flag `jwt.verify` without a pinned
  `algorithms` allow-list and use of `alg: none`.
- **Platform (#1):** short token TTLs + rotated signing keys (stored as secrets,
  not in the image — see supply chain #3); egress default-deny limits what a
  forged session can reach.

## References

- OWASP JWT Cheat Sheet; "Pwning OWASP Juice Shop" — JWT challenges
- CVE-class: JWT `alg:none` & RS256/HS256 key confusion
