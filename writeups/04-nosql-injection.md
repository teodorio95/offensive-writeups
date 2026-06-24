# 04 — NoSQL injection (query-operator manipulation)

| | |
|---|---|
| **Target** | OWASP Juice Shop @ `http://<mac-ip>:8081` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | OWASP A03:2021 — Injection (NoSQL) |
| **Tools** | Burp, curl |
| **Date** | 2026-06-23 |

## 1. Recon

Some Juice Shop features are backed by a Mongo-style store (MarsDB). The product
**reviews** API takes JSON the server feeds into a query. Capture in Burp:

```http
PATCH /rest/products/reviews HTTP/1.1
Content-Type: application/json
Authorization: Bearer <token>

{"id":"<reviewId>","message":"updated"}
```

The `id` is passed into a NoSQL query — if it's used as a **query object**
rather than a typed value, operators can be injected.

## 2. Vulnerability

NoSQL queries take **objects**, so user input that becomes part of the query can
smuggle **operators** (`$ne`, `$gt`, `$where`, …). Instead of changing data,
the input changes the query's *logic* — the NoSQL cousin of SQL injection.

## 3. Exploitation

**Manipulation — affect records you don't own.** Replace the scalar `id` with an
operator that matches *everything*:

```http
PATCH /rest/products/reviews HTTP/1.1
Content-Type: application/json
Authorization: Bearer <token>

{"id":{"$ne":-1},"message":"owned by NoSQLi"}
```

`{"$ne":-1}` ("not equal to -1") matches **all** reviews → your update is applied
to every review, including other users'.

**DoS variant — `$where` with a sleep:** inject a `$where` clause running a JS
loop/sleep so the query hangs, degrading the service.

```json
{"id":{"$where":"while(true){}"}}
```

> _evidence: ./assets/04-nosqli-mass-update.png + the solved "NoSQL
> Manipulation/DoS" challenge on the score board_

## 4. Impact

- **Integrity:** mass-modify data you don't own (here, every review).
- **Availability:** `$where` with heavy JS → denial of service.
- Depending on the sink, also **auth bypass / data exfiltration** via operators.

## 5. Remediation

- **Code fix:** never pass raw user input as a query object. **Cast to the
  expected type** (`id` is a string/number, not an object), **reject objects**
  where scalars are expected, and disable server-side JS (`$where`). Enforce a
  **schema** (e.g., Mongoose with `strictQuery`) and validate input:
  ```js
  if (typeof req.body.id !== "string") return res.sendStatus(400);
  ```
- **Shift-left (#2):** Semgrep flags user input flowing into query filters
  without type validation; DAST (ZAP) fuzzes the endpoint with operator payloads.
- **Platform (#1/#5):** least-privilege DB credentials limit blast radius;
  Hubble/Falco surface the abnormal request burst / DoS pattern.

## References

- OWASP Testing Guide — NoSQL Injection; "Pwning OWASP Juice Shop"
- OWASP A03:2021 — Injection
